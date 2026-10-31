"""탭 5: 홈페이지 유입 (GA4 웹) — 마감월 단위 조회

조회 방식
- 조회 옵션은 '마감월' 1개 (2026년 8월 ~ 지난달). 기준기간 = 선택월 1일 ~ 말일
- ① 기준일 = 선택월 말일, 누적 = 2026-08-01 ~ 말일 / ② 2026년 8월 ~ 선택월 월별 추이

데이터 로드 방식 (관리자 요청)
- 원천 GN_DW.BRONZE_BIGQUERY."events_YYYYMMDD" 샤드에서 2026-08-01 ~ 선택월 말일만
  임시테이블(TEMPORARY TABLE, GN_DW.LAB.TMP_GA_WEB_<랜덤>)로 CREATE → ①~④ 집계 → finally 에서 즉시 DROP
- 확정(프리징) 값은 앱 전역 캐시(st.cache_resource)에 월별 보관 → 이후 조회는 재집계 없이 즉시 표시
  (앱 재시작 시 캐시가 비워져 첫 조회 때 1회 재집계)
- 쿼리는 비동기 실행. '집계 중단' 버튼 → SYSTEM$CANCEL_QUERY 로 Snowflake 쿼리 취소 + 임시테이블 DROP
- 모든 쿼리 앞에 /* GA_HOMEPAGE_TAB5 */ 주석 → Query History 에서 검색 가능
"""
import html
import re
import time
import uuid
from datetime import date, timedelta

import altair as alt
import pandas as pd
import streamlit as st

TMP_SCHEMA = "GN_DW.LAB"
START_MONTH = date(2026, 8, 1)  # 이 달부터 집계 (이전 데이터는 만들지 않음)
TOP_N = 30
CONV_EVENTS = ("정기후원",)  # 전환 이벤트
SHARD_RE = re.compile(r"^events_(\d{8})$")
TAG = "/* GA_HOMEPAGE_TAB5 */ "

C_PC, C_MOBILE = "#1E66D0", "#14A3A3"
C_MEMBER, C_NONMEMBER = "#1E66D0", "#7B4FC9"
C_ARROW = "#E53935"


@st.cache_data(ttl=3600, show_spinner=False)
def t5_shard_dates(_conn):
    """적재된 GA 일별 샤드 날짜 목록 (오름차순)"""
    df = _conn.query(
        "SELECT TABLE_NAME FROM GN_DW.INFORMATION_SCHEMA.TABLES "
        "WHERE TABLE_SCHEMA = 'BRONZE_BIGQUERY' AND STARTSWITH(TABLE_NAME, 'events_')",
        ttl=0,
    )
    return sorted(
        date(int(m[1][:4]), int(m[1][4:6]), int(m[1][6:]))
        for m in (SHARD_RE.match(t) for t in df["TABLE_NAME"])
        if m
    )


@st.cache_resource(show_spinner=False)
def t5_frozen():
    """마감월 확정값 저장소 (앱 전역, 모든 사용자 공유). {월 1일(date): {kpi, monthly, member, pages}}"""
    return {}


def _month_end(m):
    return (m.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)


def _closed_months(shards):
    """조회 가능한 마감월: START_MONTH ~ 지난달 중 말일까지 샤드가 적재된 달 (최신순)"""
    out, m = [], START_MONTH
    while _month_end(m) < date.today() and _month_end(m) <= shards[-1]:
        out.append(m)
        m = _month_end(m) + timedelta(days=1)
    return out[::-1]


def _shard_union(shard_dates, s, e):
    """기간 [s, e] 샤드를 평탄화해 UNION ALL.
    샤드 테이블명은 INFORMATION_SCHEMA 에서 읽은 날짜로만 만듦 → 사용자 입력이 식별자에 들어가지 않음"""
    parts = [
        f"""SELECT TO_DATE("event_date",'YYYYMMDD') AS EVENT_DT, "user_pseudo_id" AS USER_PSEUDO_ID,
            "user_id"::STRING AS USER_ID,
            "user_pseudo_id" || '-' || FILTER("event_params", x -> x:key::string='ga_session_id')[0]:value:int_value::string AS SESSION_KEY,
            "event_name" AS EVENT_NAME,
            FILTER("event_params", x -> x:key::string='page_title')[0]:value:string_value::string AS PAGE_TITLE,
            "device":category::string AS DEVICE_CATEGORY,
            FILTER("event_params", x -> x:key::string='engagement_time_msec')[0]:value:int_value::number AS ENGAGEMENT_TIME_MSEC
        FROM GN_DW.BRONZE_BIGQUERY."events_{d:%Y%m%d}" WHERE "platform" = 'WEB'"""
        for d in shard_dates
        if s <= d <= e
    ]
    if not parts:
        parts = ["""SELECT NULL::DATE AS EVENT_DT, NULL::STRING AS USER_PSEUDO_ID, NULL::STRING AS USER_ID,
            NULL::STRING AS SESSION_KEY, NULL::STRING AS EVENT_NAME, NULL::STRING AS PAGE_TITLE,
            NULL::STRING AS DEVICE_CATEGORY, NULL::NUMBER AS ENGAGEMENT_TIME_MSEC WHERE FALSE"""]
    return "\nUNION ALL\n".join(parts)


def _steps(tmp, shard_dates, ms, me):
    """(이름, SQL, 파라미터, 결과키) 목록. 결과키 None = 결과 없음 (CREATE)"""
    conv = ",".join(["?"] * len(CONV_EVENTS))
    return [
        ("원천 GA 데이터 임시테이블 적재", f"CREATE TEMPORARY TABLE {tmp} AS {_shard_union(shard_dates, START_MONTH, me)}", None, None),
        ("① 방문자수 집계", f"""
            SELECT
              COUNT(DISTINCT USER_PSEUDO_ID) AS CUM,
              COUNT(DISTINCT IFF(EVENT_DT >= ?::DATE, USER_PSEUDO_ID, NULL)) AS MTD,
              COUNT(DISTINCT IFF(EVENT_DT >= DATEADD(day, -6, ?::DATE), USER_PSEUDO_ID, NULL)) AS WK,
              COUNT(DISTINCT IFF(EVENT_DT = ?::DATE, USER_PSEUDO_ID, NULL)) AS DAY
            FROM {tmp}""", [ms, me, me], "kpi"),
        ("② 월별 추이 집계", f"""
            SELECT DATE_TRUNC('month', EVENT_DT) AS MONTH_DT,
              COUNT(DISTINCT USER_PSEUDO_ID) AS TOTAL,
              COUNT(DISTINCT IFF(DEVICE_CATEGORY = 'desktop', USER_PSEUDO_ID, NULL)) AS PC,
              COUNT(DISTINCT IFF(DEVICE_CATEGORY IN ('mobile','tablet'), USER_PSEUDO_ID, NULL)) AS MOBILE
            FROM {tmp} GROUP BY 1 ORDER BY 1""", None, "monthly"),
        ("③ 회원·비회원 집계", f"""
            WITH sess AS (
              SELECT SESSION_KEY, USER_PSEUDO_ID,
                     MAX(IFF(USER_ID IS NOT NULL, 1, 0)) AS IS_MEMBER,
                     SUM(COALESCE(ENGAGEMENT_TIME_MSEC, 0)) / 1000.0 AS ENGAGE_SEC,
                     MAX(IFF(EVENT_NAME IN ({conv}), 1, 0)) AS IS_CONV
              FROM {tmp} WHERE EVENT_DT BETWEEN ? AND ? AND SESSION_KEY IS NOT NULL GROUP BY 1, 2
            ), visitor AS (
              SELECT USER_PSEUDO_ID, IS_MEMBER, COUNT(*) AS SESS_CNT FROM sess GROUP BY 1, 2
            ), v AS (
              SELECT IS_MEMBER, COUNT_IF(SESS_CNT >= 2) / NULLIF(COUNT(*), 0) AS REVISIT FROM visitor GROUP BY 1
            )
            SELECT s.IS_MEMBER, COUNT(*) AS SESSIONS, AVG(s.ENGAGE_SEC) AS AVG_SEC, AVG(s.IS_CONV) AS CONV,
                   ANY_VALUE(v.REVISIT) AS REVISIT
            FROM sess s LEFT JOIN v ON v.IS_MEMBER = s.IS_MEMBER
            GROUP BY 1""", list(CONV_EVENTS) + [ms, me], "member"),
        ("④ 페이지별 조회수 집계", f"""
            WITH pv AS (SELECT COALESCE(PAGE_TITLE, '(제목 없음)') AS PAGE_NAME, SESSION_KEY FROM {tmp}
                        WHERE EVENT_DT BETWEEN ? AND ? AND EVENT_NAME IN ('page_view', 'screen_view'))
            SELECT 0 AS IS_TOP, NULL AS PAGE_NAME, COUNT(*) AS VIEWS, COUNT(DISTINCT SESSION_KEY) AS SESSIONS FROM pv
            UNION ALL
            SELECT * FROM (SELECT 1, PAGE_NAME, COUNT(*) AS VIEWS, COUNT(DISTINCT SESSION_KEY) FROM pv
                           GROUP BY 2 ORDER BY VIEWS DESC LIMIT {TOP_N})""", [ms, me], "pages"),
    ]


def _cancel(conn, month):
    """'집계 중단' 콜백: 실행 중인 Snowflake 쿼리 취소. 이어지는 rerun 이 집계 루프를 끊고 finally 에서 DROP"""
    st.session_state.setdefault("t5_stopped", set()).add(month)
    qid = st.session_state.pop("t5_qid", None)
    if qid:
        conn.session().sql("SELECT SYSTEM$CANCEL_QUERY(?)", params=[qid]).collect()


def _resume(month):
    st.session_state.setdefault("t5_stopped", set()).discard(month)


def _run_month(conn, shard_dates, ms):
    """임시테이블 CREATE → ①~④ 집계 → DROP. 성공 시 결과 dict, 실패 시 None"""
    me = _month_end(ms)
    session = conn.session()  # 같은 세션에서 CREATE/집계/DROP
    tmp = f"{TMP_SCHEMA}.TMP_GA_WEB_{uuid.uuid4().hex[:12].upper()}"  # 동시 접속 충돌 방지
    steps = _steps(tmp, shard_dates, ms, me)
    box = st.container(border=True)
    status = box.empty()
    box.button("집계 중단", on_click=_cancel, args=(conn, ms), type="primary", key="t5_stop")
    t0, out = time.time(), {}
    try:
        for i, (label, sql, params, key) in enumerate(steps, 1):
            job = session.sql(TAG + sql, params=params).collect_nowait()
            st.session_state["t5_qid"] = job.query_id
            while not job.is_done():
                status.markdown(
                    f"**{ms:%Y년 %m월}** 집계 중 · {i}/{len(steps)} {label} · 경과 {int(time.time() - t0)}초  \n"
                    f"<span style='font-size:11px;color:#888;'>8월부터 선택월까지 원천을 읽으므로 달이 늘수록 오래 걸립니다 · "
                    f"쿼리 ID {job.query_id}</span>",
                    unsafe_allow_html=True,
                )
                time.sleep(1)
            if key is None:
                job.result()
            else:
                out[key] = job.result(result_type="pandas")
        out["kpi"] = out["kpi"].iloc[0].to_dict()
        return out
    except Exception as ex:  # 취소 포함. Streamlit rerun/stop 신호는 BaseException 이라 여기서 잡히지 않음
        if ms in st.session_state.get("t5_stopped", set()):
            return None
        st.error(f"집계 중 오류가 발생했습니다: {ex}")
        return None
    finally:
        st.session_state.pop("t5_qid", None)
        session.sql(f"{TAG}DROP TABLE IF EXISTS {tmp}").collect()  # 작업 종료(완료·중단·오류) 시 즉시 삭제
        box.empty()


# ─── 서식 ───
def _num(v):
    return "-" if v is None or pd.isna(v) else f"{v:,.0f}"


def _pct(v):
    return "-" if v is None or pd.isna(v) else f"{v * 100:.2f}%"


def _mmss(sec):
    if sec is None or pd.isna(sec):
        return "-"
    sec = int(round(sec))
    return f"{sec // 60:02d}:{sec % 60:02d}"


def _man(v):
    return f"{v / 10000:,.1f}만" if v >= 10000 else f"{v:,.0f}"


def _compare(m, nm, up_word, down_word):
    if m is None or nm is None or pd.isna(m) or pd.isna(nm) or m == 0 or nm == 0:
        return "-"
    if m >= nm:
        return f'<span style="color:{C_ARROW}">▲</span> 회원이 {m / nm:,.2f}배 {up_word}'
    return f'<span style="color:{C_ARROW}">▼</span> 회원이 {nm / m:,.2f}배 {down_word}'


def _section(title):
    st.markdown(
        f'<div style="font-weight:700;font-size:16px;border-left:4px solid {C_PC};padding-left:8px;margin:4px 0 8px 0;">{title}</div>',
        unsafe_allow_html=True,
    )


def _note(text):
    st.markdown(f'<div style="font-size:11px;color:#666;margin-top:4px;">{text}</div>', unsafe_allow_html=True)


def _card(label, value, sub, color):
    return (
        f'<div style="border:1px solid #e3e6ea;border-radius:10px;padding:12px 14px;margin-bottom:10px;">'
        f'<div style="font-size:12px;color:#555;"><span style="display:inline-block;width:10px;height:10px;'
        f'border-radius:50%;background:{color};margin-right:6px;"></span>{label}</div>'
        f'<div style="font-size:26px;font-weight:700;margin-top:4px;">{value}'
        f'<span style="font-size:13px;font-weight:400;margin-left:3px;">명</span></div>'
        f'<div style="font-size:11px;color:#888;">{sub}</div></div>'
    )


# ─── 렌더 ───
def render_tab5(conn):
    st.markdown("### 홈페이지 유입 (GA4 웹)")

    shards = t5_shard_dates(conn)
    months = _closed_months(shards) if shards else []
    if not months:
        st.info(f"조회 가능한 마감월이 없습니다. {START_MONTH:%Y년 %m월}부터 말일이 지난 달만 조회됩니다.")
        return

    f1, _ = st.columns([1, 3])
    with f1:
        ms = st.selectbox("조회 월 (마감월)", months, index=0, format_func=lambda d: f"{d:%Y년 %m월}", key="t5_month")
    me = _month_end(ms)
    period = f"기간: {ms:%Y.%m.%d} ~ {me:%Y.%m.%d}"
    have = set(shards)
    missing = [ms + timedelta(days=i) for i in range((me - ms).days + 1) if ms + timedelta(days=i) not in have]
    if missing:
        st.warning("원천 GA 데이터에 없는 날짜가 있어 해당 일은 집계에서 빠집니다: " + ", ".join(f"{d:%m/%d}" for d in missing))

    frozen = t5_frozen()
    if ms not in frozen:
        if ms in st.session_state.get("t5_stopped", set()):
            st.warning(f"{ms:%Y년 %m월} 집계를 중단했습니다.")
            st.button("다시 집계", on_click=_resume, args=(ms,), key="t5_resume")
            return
        data = _run_month(conn, shards, ms)
        if data is None:
            if ms in st.session_state.get("t5_stopped", set()):
                st.rerun()
            return
        frozen[ms] = data
    data = frozen[ms]

    # 배치: ① → ② → ③ → ④ (모두 전체 폭, 세로 순서)
    sec1, sec2, sec3, sec4 = st.container(), st.container(), st.container(), st.container()

    # ① 홈페이지 유입수
    with sec1:
        _section("① 홈페이지 유입수")
        k = data["kpi"]
        c1, c2, c3, c4 = st.columns(4)
        c1.markdown(_card("누적 방문자수 (8월 이후)", _num(k["CUM"]), f"{START_MONTH:%Y.%m.%d} ~ {me:%m.%d}", C_PC), unsafe_allow_html=True)
        c2.markdown(_card("월별 방문자수", _num(k["MTD"]), f"{ms:%m.%d} ~ {me:%m.%d}", C_MOBILE), unsafe_allow_html=True)
        c3.markdown(_card("주간 방문자수", _num(k["WK"]), f"{me - timedelta(days=6):%m.%d} ~ {me:%m.%d} (말일 포함 최근 7일)", C_NONMEMBER), unsafe_allow_html=True)
        c4.markdown(_card("일자별 방문자수", _num(k["DAY"]), f"{me:%Y.%m.%d} (말일)", "#F2A900"), unsafe_allow_html=True)
        _note(
            f"※ 기준일 {me:%Y.%m.%d} (선택월 말일) · 방문자 = 기간별 중복 제외 순 방문자(user_pseudo_id) · "
            f"누적은 {START_MONTH:%Y년 %m월} 이후 데이터만 집계 · GA 속성 시간대 기준(KST 가정)"
        )

    # ② 월별 유입 누적
    with sec2:
        _section(f"② 월별 홈페이지 유입 누적 ({START_MONTH:%Y.%m} ~ {ms:%Y.%m})")
        mon = data["monthly"].copy()
        mon["M"] = pd.to_datetime(mon["MONTH_DT"]).dt.strftime("%Y.%m")
        long = mon.melt(id_vars="M", value_vars=["PC", "MOBILE"], var_name="S", value_name="V")
        long["시리즈"] = long["S"].map({"PC": "PC 유입", "MOBILE": "모바일 유입"})
        long["값"] = long["V"].apply(lambda v: f"{v:,.0f}명")
        color = alt.Scale(domain=["PC 유입", "모바일 유입"], range=[C_PC, C_MOBILE])
        x = alt.X("M:O", title=None, axis=alt.Axis(labelAngle=0))
        y = alt.Y("V:Q", title="순 방문자", axis=alt.Axis(labelExpr="datum.value >= 10000 ? format(datum.value/10000, ',.0f') + '만' : format(datum.value, ',')"))
        lines = alt.Chart(long).mark_line(point=True, strokeWidth=2.5).encode(
            x=x, y=y, color=alt.Color("시리즈:N", scale=color, legend=alt.Legend(orient="top", title=None)),
            tooltip=[alt.Tooltip("시리즈"), alt.Tooltip("M", title="월"), alt.Tooltip("값")],
        )
        peaks = long.sort_values("V").groupby("S").tail(1).copy()
        peaks["라벨"] = "최고 " + peaks["V"].apply(_man)
        labels = alt.Chart(peaks).mark_text(dy=-12, fontWeight="bold").encode(
            x=x, y=y, text="라벨:N", color=alt.Color("시리즈:N", scale=color, legend=None)
        )
        st.altair_chart((lines + labels).properties(height=320), use_container_width=True)
        _note(
            "※ 전체 유입수는 중복을 제외한 순 방문자 기준입니다. 모바일 = mobile + tablet · "
            "PC와 모바일로 모두 방문한 사람은 양쪽에 집계되므로 두 선의 합이 전체 방문자보다 클 수 있습니다."
        )

    # ③ 회원 vs 비회원
    with sec3:
        _section("③ 총 세션수 · 체류시간 · 전환율 · 재방문율 (회원 vs 비회원)")
        dm = data["member"]
        g = {int(r.IS_MEMBER): r for r in dm.itertuples()}
        m, nm = g.get(1), g.get(0)
        get = lambda r, a: getattr(r, a) if r is not None else None
        msess, nsess = get(m, "SESSIONS") or 0, get(nm, "SESSIONS") or 0
        tot = msess + nsess
        share = lambda x: f" ({x / tot * 100:.2f}%)" if tot else ""
        rows = [
            ("방문 수(세션)", f"{_num(msess)}{share(msess)}", f"{_num(nsess)}{share(nsess)}", _compare(msess, nsess, "더 많음", "더 적음")),
            ("평균 체류 시간", _mmss(get(m, "AVG_SEC")), _mmss(get(nm, "AVG_SEC")), _compare(get(m, "AVG_SEC"), get(nm, "AVG_SEC"), "김", "짧음")),
            ("전환율", _pct(get(m, "CONV")), _pct(get(nm, "CONV")), _compare(get(m, "CONV"), get(nm, "CONV"), "높음", "낮음")),
            ("재방문율", _pct(get(m, "REVISIT")), _pct(get(nm, "REVISIT")), _compare(get(m, "REVISIT"), get(nm, "REVISIT"), "높음", "낮음")),
        ]
        th = "padding:8px;border-bottom:2px solid #ccc;text-align:center;font-size:13px;"
        td = "padding:8px;border-bottom:1px solid #eee;text-align:center;font-size:13px;"
        body = "".join(
            f'<tr><td style="{td}text-align:left;font-weight:600;">{a}</td><td style="{td}color:{C_MEMBER};font-weight:600;">{b}</td>'
            f'<td style="{td}color:{C_NONMEMBER};font-weight:600;">{c}</td><td style="{td}">{d}</td></tr>'
            for a, b, c, d in rows
        )
        st.markdown(
            f'<table style="width:100%;border-collapse:collapse;"><thead><tr><th style="{th}">지표</th>'
            f'<th style="{th}color:{C_MEMBER};">회원 유입</th><th style="{th}color:{C_NONMEMBER};">비회원 유입</th>'
            f'<th style="{th}">비교</th></tr></thead><tbody>{body}</tbody></table>',
            unsafe_allow_html=True,
        )
        _note(
            f"※ {period} · 회원 세션 = 세션 내 user_id가 1회 이상 존재(로그인 전 이벤트 포함) · "
            "체류시간 = 세션당 engagement_time 합계 평균 · 전환율 = '정기후원' 이벤트 발생 세션 ÷ 전체 세션 · "
            "재방문율 = 기간 내 세션 2회 이상 방문자 ÷ 전체 방문자 · 비교 = 회원 ÷ 비회원"
        )

    # ④ 페이지별 조회수 / 세션수
    with sec4:
        _section(f"④ 페이지 제목 및 화면 클래스별 조회수 / 세션수 (상위 {TOP_N})")
        pg = data["pages"]
        total = pg[pg["IS_TOP"] == 0].iloc[0]
        top = pg[pg["IS_TOP"] == 1].sort_values("VIEWS", ascending=False)
        vmax = top["VIEWS"].max() if len(top) else 0
        smax = top["SESSIONS"].max() if len(top) else 0

        def bar(v, mx, c):
            w = (v / mx * 100) if mx else 0
            return (
                f'<div style="display:flex;align-items:center;gap:6px;justify-content:flex-end;">'
                f'<span>{v:,.0f}</span><div style="width:70px;background:#f0f2f5;height:8px;border-radius:4px;">'
                f'<div style="width:{w:.1f}%;background:{c};height:8px;border-radius:4px;"></div></div></div>'
            )

        th = "padding:6px;border-bottom:2px solid #ccc;font-size:12px;"
        td = "padding:5px 6px;border-bottom:1px solid #eee;font-size:12px;"
        ell = "max-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"
        rows = [
            f'<tr style="background:#f5f7fa;font-weight:700;"><td style="{td}text-align:center;"></td>'
            f'<td style="{td}">합계</td><td style="{td}text-align:right;">{_num(total.VIEWS)}</td>'
            f'<td style="{td}text-align:right;">{_num(total.SESSIONS)}</td></tr>'
        ]
        for i, r in enumerate(top.itertuples(), 1):
            name = html.escape(str(r.PAGE_NAME))
            rows.append(
                f'<tr><td style="{td}text-align:center;color:#888;">{i}</td>'
                f'<td style="{td}{ell}" title="{name}">{name}</td>'
                f'<td style="{td}">{bar(r.VIEWS, vmax, C_PC)}</td><td style="{td}">{bar(r.SESSIONS, smax, C_MOBILE)}</td></tr>'
            )
        st.markdown(
            f'<div style="max-height:420px;overflow-y:auto;"><table style="width:100%;table-layout:fixed;border-collapse:collapse;">'
            f'<colgroup><col style="width:8%"><col style="width:48%"><col style="width:22%"><col style="width:22%"></colgroup>'
            f'<thead style="position:sticky;top:0;background:white;"><tr><th style="{th}">순번</th>'
            f'<th style="{th}text-align:left;">페이지 제목 및 화면 클래스</th><th style="{th}text-align:right;">조회수</th>'
            f'<th style="{th}text-align:right;">세션수</th></tr></thead><tbody>{"".join(rows)}</tbody></table></div>',
            unsafe_allow_html=True,
        )
        _note(
            f"※ {period} · 조회수 = page_view(+screen_view) 이벤트 수 · 세션수 = 해당 페이지를 1회 이상 조회한 고유 세션 · "
            "한 세션이 여러 페이지를 보므로 페이지별 세션수의 합은 합계와 다를 수 있음 · 현재 웹만 수집되어 앱 화면 클래스는 없음"
        )

    _note("※ 마감월 확정값은 앱 캐시에 보관되어 재조회 시 즉시 표시됩니다. 앱이 재시작되면 첫 조회 때 1회 다시 집계합니다.")
