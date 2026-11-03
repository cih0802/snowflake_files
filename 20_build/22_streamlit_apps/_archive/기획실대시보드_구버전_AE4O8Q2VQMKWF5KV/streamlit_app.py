import os
from datetime import date, timedelta
import streamlit as st
import pandas as pd

st.set_page_config(page_title="주간개발보고 대시보드", layout="wide")
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

# ─── 공통 유틸 ───
def monday_of_week(d):
    return d - timedelta(days=d.weekday())

def build_week_options(year=2026):
    options = {}
    d = date(year, 1, 5)
    while d.year == year:
        mon = monday_of_week(d)
        sun = mon + timedelta(days=6)
        if sun > date.today():
            break
        m = mon.month
        week_in_month = (mon.day - 1) // 7 + 1
        label = f"{m}월 {week_in_month}주차 ({mon.strftime('%m/%d')}~{sun.strftime('%m/%d')})"
        options[label] = (mon, sun)
        d += timedelta(days=7)
    return options

DAYS_KR = ["월","화","수","목","금","토","일"]

# ─── 탭 구성 ───
tab1, tab2, tab3, tab4, tab5 = st.tabs(["1. 주간캠페인별 개발", "2. 후원사업별 주차별 개발", "3. 전체 개발실적 현황", "4. 국내 사단사업장 회원개발", "5. 홈페이지 유입"])

# ═══════════════════════════════════════════════════════
# 탭 1: 주간 캠페인별 개발
# ═══════════════════════════════════════════════════════
with tab1:
    st.markdown("### 주간 캠페인별 개발(건)")
    week_options = build_week_options()
    week_labels = list(week_options.keys())

    c1, c2 = st.columns([2, 3])
    with c1:
        mode = st.radio("기간 설정", ["주차 선택", "직접 입력"], horizontal=True, key="t1_mode")
    with c2:
        if mode == "주차 선택":
            default_idx = len(week_labels) - 1 if week_labels else 0
            selected_label = st.selectbox("주차", week_labels, index=default_idx, key="t1_wk")
            tw_start_date, tw_end_date = week_options[selected_label]
        else:
            dc1, dc2 = st.columns(2)
            with dc1:
                tw_start_date = st.date_input("시작일", value=date(2026, 10, 6), key="t1_s")
            with dc2:
                tw_end_date = st.date_input("종료일", value=date(2026, 10, 12), key="t1_e")

    prev_start_date = tw_start_date - timedelta(days=7)
    prev_end_date = tw_end_date - timedelta(days=7)
    ytd_start = date(tw_start_date.year, 1, 1)
    TW_S = int(tw_start_date.strftime("%Y%m%d"))
    TW_E = int(tw_end_date.strftime("%Y%m%d"))
    PW_S = int(prev_start_date.strftime("%Y%m%d"))
    PW_E = int(prev_end_date.strftime("%Y%m%d"))
    YTD_S = int(ytd_start.strftime("%Y%m%d"))

    @st.cache_data(ttl=600)
    def load_weekly_campaign(_tw_s, _tw_e, _pw_s, _pw_e, _ytd_s):
        sql = f"""
        WITH base AS (
            SELECT
                CASE
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT = '디지털' THEN '디지털'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('뉴미디어','방송','영상광고','재송출') THEN '미디어'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('대면모금','오프라인','교육기관','지역개발') THEN '오프라인'
                END AS channel_group,
                COALESCE(MKTG_CMPGN_NM_AT_EVENT, '(미지정)') AS campaign_name,
                DATE_SK, DEV_CNT
            FROM GN_DW.GOLD.FACT_MEMBER_EVENT
            WHERE DEV_CNT > 0
              AND MBER_INFLOW_PATH_NM_AT_EVENT IN ('디지털','뉴미디어','방송','영상광고','재송출','대면모금','오프라인','교육기관','지역개발')
              AND DATE_SK BETWEEN {_ytd_s} AND {_tw_e}
        )
        SELECT channel_group, campaign_name,
            ROUND(SUM(CASE WHEN DATE_SK BETWEEN {_tw_s} AND {_tw_e} THEN DEV_CNT ELSE 0 END)) AS this_week,
            ROUND(SUM(CASE WHEN DATE_SK BETWEEN {_pw_s} AND {_pw_e} THEN DEV_CNT ELSE 0 END)) AS prev_week,
            ROUND(SUM(DEV_CNT)) AS ytd_cum
        FROM base
        GROUP BY channel_group, campaign_name
        HAVING this_week > 0
        ORDER BY channel_group, this_week DESC
        """
        return conn.query(sql)

    with st.spinner("주간 캠페인별 개발 데이터 조회 중..."):
        wk_df = load_weekly_campaign(TW_S, TW_E, PW_S, PW_E, YTD_S)

    if wk_df.empty:
        st.warning("해당 기간 데이터가 없습니다.")
    else:
        wk_df["diff"] = wk_df["THIS_WEEK"] - wk_df["PREV_WEEK"]
        st.caption(
            f"주간: {tw_start_date.strftime('%-m/%-d')}({DAYS_KR[tw_start_date.weekday()]})~"
            f"{tw_end_date.strftime('%-m/%-d')}({DAYS_KR[tw_end_date.weekday()]}) | "
            f"전주: {prev_start_date.strftime('%-m/%-d')}({DAYS_KR[prev_start_date.weekday()]})~"
            f"{prev_end_date.strftime('%-m/%-d')}({DAYS_KR[prev_end_date.weekday()]}) | "
            f"누계: 연초~{tw_end_date.strftime('%-m/%-d')}"
        )
        CHANNEL_COLORS = {
            '디지털': ('#2196F3', '💻'), '미디어': ('#FF9800', '📺'), '오프라인': ('#E91E63', '🏢'),
        }
        def render_channel_table(df_ch, channel_name):
            color, icon = CHANNEL_COLORS[channel_name]
            st.markdown(
                f'<div style="background:{color};color:white;padding:6px 12px;'
                f'border-radius:6px;font-weight:bold;text-align:center;margin-bottom:8px;">'
                f'{icon} {channel_name}</div>', unsafe_allow_html=True,
            )
            total_tw = int(df_ch["THIS_WEEK"].sum())
            total_diff = int(df_ch["diff"].sum())
            total_ytd = int(df_ch["YTD_CUM"].sum())
            rows_html = ""
            for _, r in df_ch.iterrows():
                tw, d, ytd = int(r["THIS_WEEK"]), int(r["diff"]), int(r["YTD_CUM"])
                if d > 0:
                    dh = f'<span style="color:#D32F2F;">▲ {abs(d):,}</span>'
                elif d < 0:
                    dh = f'<span style="color:#1565C0;">▼ {abs(d):,}</span>'
                else:
                    dh = '<span style="color:#888;">-</span>'
                rows_html += (
                    f'<tr><td style="text-align:left;padding:4px 6px;">{r["CAMPAIGN_NAME"]}</td>'
                    f'<td style="text-align:right;padding:4px 6px;">{tw:,}</td>'
                    f'<td style="text-align:right;padding:4px 6px;">{dh}</td>'
                    f'<td style="text-align:right;padding:4px 6px;">{ytd:,}</td></tr>'
                )
            if total_diff > 0:
                tdh = f'<span style="color:#D32F2F;">▲ {abs(total_diff):,}</span>'
            elif total_diff < 0:
                tdh = f'<span style="color:#1565C0;">▼ {abs(total_diff):,}</span>'
            else:
                tdh = '<span>-</span>'
            html = f"""
            <table style="width:100%;border-collapse:collapse;font-size:12px;">
            <thead><tr style="background:#f5f5f5;border-bottom:2px solid #ddd;">
                <th style="text-align:left;padding:6px;">캠페인명</th>
                <th style="text-align:right;padding:6px;">주간 개발<br>(건)</th>
                <th style="text-align:right;padding:6px;">전주대비<br>개발(건)</th>
                <th style="text-align:right;padding:6px;">주간 누계<br>개발(건)</th>
            </tr></thead>
            <tbody>{rows_html}</tbody>
            <tfoot><tr style="background:#333;color:white;font-weight:bold;">
                <td style="padding:6px;">합계</td>
                <td style="text-align:right;padding:6px;">{total_tw:,}</td>
                <td style="text-align:right;padding:6px;">{tdh}</td>
                <td style="text-align:right;padding:6px;">{total_ytd:,}</td>
            </tr></tfoot></table>"""
            st.markdown(html, unsafe_allow_html=True)

        col1, col2, col3 = st.columns(3)
        for col, ch in zip([col1, col2, col3], ['디지털', '미디어', '오프라인']):
            with col:
                render_channel_table(wk_df[wk_df["CHANNEL_GROUP"] == ch].reset_index(drop=True), ch)

# ═══════════════════════════════════════════════════════
# 탭 2: 후원사업별 주차별 개발
# ═══════════════════════════════════════════════════════
with tab2:
    st.markdown("### 후원사업별 주차별 개발 실적")

    # ─── 부서/구분 마스터 (DIM 테이블 생성 전까지 인메모리) ───
    DEPT_ORDER = ['나눔마케팅본부', '회원실', '기타', '대면모금', '시도본부 및 지부']
    GUBUN_LIST = ['국내사업(사단)', '해외아동결연', '해외프로젝트', '기타사업', '국내사업(사복)']

    TEAM_DEPT_MAP = {
        '매체운영팀': '나눔마케팅본부', '마케팅기획1팀': '나눔마케팅본부',
        '마케팅기획2팀': '나눔마케팅본부', '컬쳐콘텐츠팀': '나눔마케팅본부',
        '회원참여팀': '회원실',
        'ESG팀': '기타', '사회공헌협력팀': '기타',
        '소셜펀딩팀': '대면모금', '캠페인기획2팀': '대면모금',
        '교육기관': '시도본부 및 지부', '지역사회': '시도본부 및 지부',
    }

    CUR_YEAR = date.today().year
    yc, mc = st.columns(2)
    with yc:
        sel_year = st.selectbox("연도 선택", list(range(CUR_YEAR, 2024, -1)), index=0, key="t2_year")
    with mc:
        sel_month = st.selectbox("월 선택", list(range(1, 13)), index=min(date.today().month - 1, 11), key="t2_month")

    # 해당 월의 주차 수 계산 (1일~말일, 7일 단위)
    import calendar
    last_day = calendar.monthrange(sel_year, sel_month)[1]
    max_weeks = (last_day - 1) // 7 + 1

    @st.cache_data(ttl=600)
    def load_biz_weekly(year, month, max_w):
        month_start = year * 10000 + month * 100 + 1
        month_end = year * 10000 + month * 100 + last_day
        prev_year = year - 1
        prev_month_start = prev_year * 10000 + month * 100 + 1
        prev_last_day = calendar.monthrange(prev_year, month)[1]
        prev_month_end_full = prev_year * 10000 + month * 100 + prev_last_day

        sql = f"""
        WITH raw_events AS (
            SELECT
                f.MEMBER_DK,
                f.DATE_SK,
                f.DEV_CNT,
                f.MBER_INFLOW_PATH_NM_AT_EVENT,
                s.SPONSORSHIP_GROUP4_NAME,
                s.CPR_DIV_NM
            FROM GN_DW.GOLD.FACT_MEMBER_EVENT f
            JOIN GN_DW.GOLD.DIM_SPONSORSHIP s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
            WHERE f.DVLP_DIV_CD IN ('1','2','4')
              AND f.DATE_SK BETWEEN {month_start} AND {month_end}
        ),
        net_per_member AS (
            SELECT
                MEMBER_DK, DATE_SK,
                MAX(MBER_INFLOW_PATH_NM_AT_EVENT) AS MBER_INFLOW_PATH_NM_AT_EVENT,
                MAX(SPONSORSHIP_GROUP4_NAME) AS SPONSORSHIP_GROUP4_NAME,
                MAX(CPR_DIV_NM) AS CPR_DIV_NM,
                SUM(DEV_CNT) AS NET_CNT
            FROM raw_events
            GROUP BY MEMBER_DK, DATE_SK
            HAVING SUM(DEV_CNT) > 0
        ),
        dept_map AS (
            SELECT
                DATE_SK,
                NET_CNT AS DEV_CNT,
                CASE
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('디지털','뉴미디어','방송','영상광고','재송출') THEN '나눔마케팅본부'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT = '콜개발' THEN '회원실'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('기타 기업개발','일시') THEN '기타'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT = '대면모금' THEN '대면모금'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('오프라인','교육기관','지역개발') THEN '시도본부 및 지부'
                    ELSE '기타'
                END AS DEPT,
                CASE
                    WHEN SPONSORSHIP_GROUP4_NAME = '결연' THEN '해외아동결연'
                    WHEN SPONSORSHIP_GROUP4_NAME = '국내' AND CPR_DIV_NM = '사단' THEN '국내사업(사단)'
                    WHEN SPONSORSHIP_GROUP4_NAME = '국내' AND CPR_DIV_NM = '사복' THEN '국내사업(사복)'
                    WHEN SPONSORSHIP_GROUP4_NAME = '해외프로젝트' THEN '해외프로젝트'
                    WHEN SPONSORSHIP_GROUP4_NAME = '기타' AND CPR_DIV_NM = '사복' THEN '국내사업(사복)'
                    ELSE '기타사업'
                END AS GUBUN
            FROM net_per_member
        ),
        max_date AS (
            SELECT MAX(DATE_SK) AS MAX_DATE_SK FROM dept_map
        ),
        prev_raw AS (
            SELECT
                f.MEMBER_DK, f.DATE_SK, f.DEV_CNT,
                f.MBER_INFLOW_PATH_NM_AT_EVENT,
                s.SPONSORSHIP_GROUP4_NAME, s.CPR_DIV_NM
            FROM GN_DW.GOLD.FACT_MEMBER_EVENT f
            JOIN GN_DW.GOLD.DIM_SPONSORSHIP s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
            CROSS JOIN max_date md
            WHERE f.DVLP_DIV_CD IN ('1','2','4')
              AND f.DATE_SK BETWEEN {prev_month_start}
                  AND {prev_year} * 10000 + {month} * 100 + (md.MAX_DATE_SK % 100)
        ),
        prev_net AS (
            SELECT
                MAX(MBER_INFLOW_PATH_NM_AT_EVENT) AS MBER_INFLOW_PATH_NM_AT_EVENT,
                MAX(SPONSORSHIP_GROUP4_NAME) AS SPONSORSHIP_GROUP4_NAME,
                MAX(CPR_DIV_NM) AS CPR_DIV_NM,
                SUM(DEV_CNT) AS NET_CNT
            FROM prev_raw
            GROUP BY MEMBER_DK, DATE_SK
            HAVING SUM(DEV_CNT) > 0
        ),
        prev_year_data AS (
            SELECT
                CASE
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('디지털','뉴미디어','방송','영상광고','재송출') THEN '나눔마케팅본부'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT = '콜개발' THEN '회원실'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('기타 기업개발','일시') THEN '기타'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT = '대면모금' THEN '대면모금'
                    WHEN MBER_INFLOW_PATH_NM_AT_EVENT IN ('오프라인','교육기관','지역개발') THEN '시도본부 및 지부'
                    ELSE '기타'
                END AS DEPT,
                CASE
                    WHEN SPONSORSHIP_GROUP4_NAME = '결연' THEN '해외아동결연'
                    WHEN SPONSORSHIP_GROUP4_NAME = '국내' AND CPR_DIV_NM = '사단' THEN '국내사업(사단)'
                    WHEN SPONSORSHIP_GROUP4_NAME = '국내' AND CPR_DIV_NM = '사복' THEN '국내사업(사복)'
                    WHEN SPONSORSHIP_GROUP4_NAME = '해외프로젝트' THEN '해외프로젝트'
                    WHEN SPONSORSHIP_GROUP4_NAME = '기타' AND CPR_DIV_NM = '사복' THEN '국내사업(사복)'
                    ELSE '기타사업'
                END AS GUBUN,
                ROUND(SUM(NET_CNT)) AS PREV_YR_CNT
            FROM prev_net
            GROUP BY 1, 2
        ),
        weekly AS (
            SELECT
                DEPT, GUBUN,
                FLOOR((DATE_SK % 100 - 1) / 7) + 1 AS WEEK_NUM,
                ROUND(SUM(DEV_CNT)) AS DEV_CNT
            FROM dept_map
            GROUP BY DEPT, GUBUN, WEEK_NUM
        )
        SELECT
            w.DEPT, w.GUBUN, w.WEEK_NUM, w.DEV_CNT,
            p.PREV_YR_CNT,
            m.MAX_DATE_SK
        FROM weekly w
        LEFT JOIN prev_year_data p ON w.DEPT = p.DEPT AND w.GUBUN = p.GUBUN
        CROSS JOIN max_date m
        ORDER BY w.DEPT, w.GUBUN, w.WEEK_NUM
        """
        return conn.query(sql)

    with st.spinner("후원사업별 주차별 개발 데이터 조회 중..."):
        biz_df = load_biz_weekly(sel_year, sel_month, max_weeks)

    if biz_df.empty:
        st.warning("해당 월 데이터가 없습니다.")
    else:
        # ─── 피벗 테이블 구성 ───
        dept_order_map = {d: i for i, d in enumerate(DEPT_ORDER)}
        gubun_order_map = {g: i for i, g in enumerate(GUBUN_LIST)}

        # 주차별 피벗
        pivot = biz_df.pivot_table(
            index=['DEPT', 'GUBUN'], columns='WEEK_NUM', values='DEV_CNT',
            aggfunc='sum', fill_value=0
        ).reset_index()

        # 전년동월
        prev_yr = biz_df.drop_duplicates(subset=['DEPT', 'GUBUN'])[['DEPT', 'GUBUN', 'PREV_YR_CNT']].copy()
        prev_yr['PREV_YR_CNT'] = prev_yr['PREV_YR_CNT'].fillna(0)
        pivot = pivot.merge(prev_yr, on=['DEPT', 'GUBUN'], how='left')
        pivot['PREV_YR_CNT'] = pivot['PREV_YR_CNT'].fillna(0)

        # 주차 컬럼 이름 정리
        week_cols = sorted([c for c in pivot.columns if isinstance(c, (int, float)) and c > 0])
        pivot['합계'] = pivot[week_cols].sum(axis=1)
        pivot['전년동월증감'] = pivot['합계'] - pivot['PREV_YR_CNT']

        # 정렬
        pivot['dept_ord'] = pivot['DEPT'].map(dept_order_map).fillna(99)
        pivot['gubun_ord'] = pivot['GUBUN'].map(gubun_order_map).fillna(99)
        pivot = pivot.sort_values(['dept_ord', 'gubun_ord']).reset_index(drop=True)

        # ─── HTML 테이블 렌더링 ───
        def week_date_range(year, month, week_num):
            s_day = (int(week_num) - 1) * 7 + 1
            e_day = min(s_day + 6, calendar.monthrange(year, month)[1])
            return f"{month}/{s_day:02d}~{month}/{e_day:02d}"

        week_headers = "".join(
            f'<th style="text-align:right;padding:4px 8px;">{int(w)}주<br><span style="font-weight:normal;font-size:10px;">{week_date_range(sel_year, sel_month, w)}</span></th>'
            for w in week_cols
        )
        header_html = f"""
        <tr style="background:#4a4a4a;color:white;">
            <th style="padding:4px 8px;text-align:left;">부서</th>
            <th style="padding:4px 8px;text-align:left;">구분</th>
            {week_headers}
            <th style="text-align:right;padding:4px 8px;">합계</th>
            <th style="text-align:right;padding:4px 8px;">전년동월</th>
            <th style="text-align:right;padding:4px 8px;">증감</th>
        </tr>"""

        body_html = ""
        prev_dept = None
        dept_subtotals = {}

        for _, row in pivot.iterrows():
            dept = row['DEPT']
            gubun = row['GUBUN']

            # 부서 소계 누적
            if dept not in dept_subtotals:
                dept_subtotals[dept] = {w: 0 for w in week_cols}
                dept_subtotals[dept]['합계'] = 0
                dept_subtotals[dept]['전년동월'] = 0
                dept_subtotals[dept]['증감'] = 0
            for w in week_cols:
                dept_subtotals[dept][w] += int(row.get(w, 0))
            dept_subtotals[dept]['합계'] += int(row['합계'])
            dept_subtotals[dept]['전년동월'] += int(row['PREV_YR_CNT'])
            dept_subtotals[dept]['증감'] += int(row['전년동월증감'])

            # 부서 변경 시 이전 부서 소계 삽입
            if prev_dept is not None and dept != prev_dept:
                st_vals = "".join(f'<td style="text-align:right;padding:4px 8px;">{dept_subtotals[prev_dept][w]:,}</td>' for w in week_cols)
                st_total = dept_subtotals[prev_dept]['합계']
                st_prev = dept_subtotals[prev_dept]['전년동월']
                st_diff = dept_subtotals[prev_dept]['증감']
                diff_color = "color:#D32F2F;" if st_diff > 0 else ("color:#1565C0;" if st_diff < 0 else "")
                diff_sym = "▲" if st_diff > 0 else ("▼" if st_diff < 0 else "")
                body_html += (
                    f'<tr style="background:#e8e8e8;font-weight:bold;">'
                    f'<td style="padding:4px 8px;">{prev_dept} 소계</td><td></td>'
                    f'{st_vals}'
                    f'<td style="text-align:right;padding:4px 8px;">{st_total:,}</td>'
                    f'<td style="text-align:right;padding:4px 8px;">{st_prev:,}</td>'
                    f'<td style="text-align:right;padding:4px 8px;{diff_color}">{diff_sym} {abs(st_diff):,}</td>'
                    f'</tr>'
                )

            prev_dept = dept

            # 데이터 행
            week_vals = "".join(f'<td style="text-align:right;padding:4px 8px;">{int(row.get(w, 0)):,}</td>' for w in week_cols)
            total_val = int(row['합계'])
            prev_val = int(row['PREV_YR_CNT'])
            diff_val = int(row['전년동월증감'])
            diff_color = "color:#D32F2F;" if diff_val > 0 else ("color:#1565C0;" if diff_val < 0 else "")
            diff_sym = "▲" if diff_val > 0 else ("▼" if diff_val < 0 else "")

            dept_display = dept if (body_html == "" or dept != prev_dept) else ""
            body_html += (
                f'<tr>'
                f'<td style="padding:4px 8px;">{dept}</td>'
                f'<td style="padding:4px 8px;">{gubun}</td>'
                f'{week_vals}'
                f'<td style="text-align:right;padding:4px 8px;font-weight:bold;">{total_val:,}</td>'
                f'<td style="text-align:right;padding:4px 8px;">{prev_val:,}</td>'
                f'<td style="text-align:right;padding:4px 8px;{diff_color}">{diff_sym} {abs(diff_val):,}</td>'
                f'</tr>'
            )

        # 마지막 부서 소계
        if prev_dept and prev_dept in dept_subtotals:
            st_vals = "".join(f'<td style="text-align:right;padding:4px 8px;">{dept_subtotals[prev_dept][w]:,}</td>' for w in week_cols)
            st_total = dept_subtotals[prev_dept]['합계']
            st_prev = dept_subtotals[prev_dept]['전년동월']
            st_diff = dept_subtotals[prev_dept]['증감']
            diff_color = "color:#D32F2F;" if st_diff > 0 else ("color:#1565C0;" if st_diff < 0 else "")
            diff_sym = "▲" if st_diff > 0 else ("▼" if st_diff < 0 else "")
            body_html += (
                f'<tr style="background:#e8e8e8;font-weight:bold;">'
                f'<td style="padding:4px 8px;">{prev_dept} 소계</td><td></td>'
                f'{st_vals}'
                f'<td style="text-align:right;padding:4px 8px;">{st_total:,}</td>'
                f'<td style="text-align:right;padding:4px 8px;">{st_prev:,}</td>'
                f'<td style="text-align:right;padding:4px 8px;{diff_color}">{diff_sym} {abs(st_diff):,}</td>'
                f'</tr>'
            )

        # 전체 합계
        grand = {w: sum(dept_subtotals[d][w] for d in dept_subtotals) for w in week_cols}
        grand_total = sum(dept_subtotals[d]['합계'] for d in dept_subtotals)
        grand_prev = sum(dept_subtotals[d]['전년동월'] for d in dept_subtotals)
        grand_diff = grand_total - grand_prev
        gd_color = "color:#D32F2F;" if grand_diff > 0 else ("color:#1565C0;" if grand_diff < 0 else "")
        gd_sym = "▲" if grand_diff > 0 else ("▼" if grand_diff < 0 else "")
        gv = "".join(f'<td style="text-align:right;padding:4px 8px;">{grand[w]:,}</td>' for w in week_cols)
        body_html += (
            f'<tr style="background:#333;color:white;font-weight:bold;">'
            f'<td style="padding:4px 8px;">합계</td><td></td>'
            f'{gv}'
            f'<td style="text-align:right;padding:4px 8px;">{grand_total:,}</td>'
            f'<td style="text-align:right;padding:4px 8px;">{grand_prev:,}</td>'
            f'<td style="text-align:right;padding:4px 8px;{gd_color}">{gd_sym} {abs(grand_diff):,}</td>'
            f'</tr>'
        )

        max_date_sk = int(biz_df["MAX_DATE_SK"].iloc[0])
        max_date_str = f"{max_date_sk // 10000}년 {(max_date_sk % 10000) // 100}월 {max_date_sk % 100}일"
        st.caption(f"{sel_year}년 {sel_month}월 | 전년동월: {sel_year-1}년 {sel_month}월 | 출처: FACT_MEMBER_EVENT × DIM_SPONSORSHIP | 순액기준(MSTR 방식)")
        st.caption(f"📅 데이터 기준: {max_date_str}까지 반영")
        st.markdown(
            f'<table style="width:100%;border-collapse:collapse;font-size:12px;">'
            f'<thead>{header_html}</thead><tbody>{body_html}</tbody></table>',
            unsafe_allow_html=True,
        )

        # ─── 하단: 후원사업별 요약 (구분 기준 전체 부서 합산) ───
        st.markdown("---")
        st.markdown("#### 후원사업별 요약")

        gubun_summary = pivot.groupby('GUBUN').agg(
            {**{w: 'sum' for w in week_cols}, '합계': 'sum', 'PREV_YR_CNT': 'sum', '전년동월증감': 'sum'}
        ).reindex(GUBUN_LIST).fillna(0)

        gs_header = "".join(
            f'<th style="text-align:right;padding:4px 8px;">{int(w)}주<br><span style="font-weight:normal;font-size:10px;">{week_date_range(sel_year, sel_month, w)}</span></th>'
            for w in week_cols
        )
        gs_body = ""
        for gubun in GUBUN_LIST:
            if gubun not in gubun_summary.index:
                continue
            r = gubun_summary.loc[gubun]
            wv = "".join(f'<td style="text-align:right;padding:4px 8px;">{int(r.get(w, 0)):,}</td>' for w in week_cols)
            t = int(r['합계'])
            p = int(r['PREV_YR_CNT'])
            d = int(r['전년동월증감'])
            dc = "color:#D32F2F;" if d > 0 else ("color:#1565C0;" if d < 0 else "")
            ds = "▲" if d > 0 else ("▼" if d < 0 else "")
            gs_body += (
                f'<tr><td style="padding:4px 8px;font-weight:bold;">{gubun}</td>'
                f'{wv}'
                f'<td style="text-align:right;padding:4px 8px;font-weight:bold;">{t:,}</td>'
                f'<td style="text-align:right;padding:4px 8px;">{p:,}</td>'
                f'<td style="text-align:right;padding:4px 8px;{dc}">{ds} {abs(d):,}</td></tr>'
            )
        # 요약 합계
        gs_gv = "".join(f'<td style="text-align:right;padding:4px 8px;">{int(gubun_summary[w].sum()):,}</td>' for w in week_cols)
        gs_gt = int(gubun_summary['합계'].sum())
        gs_gp = int(gubun_summary['PREV_YR_CNT'].sum())
        gs_gd = gs_gt - gs_gp
        gs_dc = "color:#D32F2F;" if gs_gd > 0 else ("color:#1565C0;" if gs_gd < 0 else "")
        gs_ds = "▲" if gs_gd > 0 else ("▼" if gs_gd < 0 else "")
        gs_body += (
            f'<tr style="background:#333;color:white;font-weight:bold;">'
            f'<td style="padding:4px 8px;">합계</td>'
            f'{gs_gv}'
            f'<td style="text-align:right;padding:4px 8px;">{gs_gt:,}</td>'
            f'<td style="text-align:right;padding:4px 8px;">{gs_gp:,}</td>'
            f'<td style="text-align:right;padding:4px 8px;{gs_dc}">{gs_ds} {abs(gs_gd):,}</td></tr>'
        )

        st.markdown(
            f'<table style="width:100%;border-collapse:collapse;font-size:12px;">'
            f'<thead><tr style="background:#4a4a4a;color:white;">'
            f'<th style="padding:4px 8px;text-align:left;">구분</th>'
            f'{gs_header}'
            f'<th style="text-align:right;padding:4px 8px;">합계</th>'
            f'<th style="text-align:right;padding:4px 8px;">전년동월</th>'
            f'<th style="text-align:right;padding:4px 8px;">증감</th>'
            f'</tr></thead><tbody>{gs_body}</tbody></table>',
            unsafe_allow_html=True,
        )

# ═══════════════════════════════════════════════════════
# 탭 3: 전체 개발실적 현황 (법인별 / 후원사업별 누계 실적·목표·달성률)
# ═══════════════════════════════════════════════════════
with tab3:
    st.markdown("### 전체 개발실적 현황")

    # ─── 행 구성 마스터 ───
    T3_NANUM = ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀"]
    T3_HQ_ETC = ["회원참여팀", "사회공헌협력팀", "기타"]
    T3_BRANCH = ["교육기관", "지역사회"]
    T3_FACE = ["대면모금"]
    T3_SABOK = ["사복본부/지부"]
    T3_SADAN_TEAMS = T3_NANUM + T3_HQ_ETC + T3_BRANCH + T3_FACE
    T3_ALL_TEAMS = T3_SADAN_TEAMS + T3_SABOK
    T3_DISPLAY = {"교육기관": "지부-교육기관", "지역사회": "지부-지역사회"}
    T3_TYPES = ["신규", "증액", "재후원"]

    # 부서 매핑 (조직개편 전 명칭 포함: 소셜펀딩부→대면모금, ESG팀→사회공헌협력팀)
    T3_TEAM_CASE = """
        CASE
            WHEN o.DEPARTMENT IN ('매체운영팀','마케팅기획1팀','마케팅기획2팀','컬쳐콘텐츠팀','회원참여팀') THEN o.DEPARTMENT
            WHEN o.DEPARTMENT IN ('사회공헌협력팀','ESG팀') THEN '사회공헌협력팀'
            WHEN o.DEPARTMENT IN ('캠페인기획2팀','소셜펀딩팀','소셜펀딩부') THEN '대면모금'
            WHEN CONTAINS(o.ACMSLT_DIV_GROUP_NM, '사복') THEN '사복본부/지부'
            WHEN o.ACMSLT_DIV_GROUP_NM IN ('지부','시도본부')
                THEN IFF(f.MBER_INFLOW_PATH_NM_AT_EVENT = '교육기관', '교육기관', '지역사회')
            ELSE '기타'
        END
    """

    @st.cache_data(ttl=3600)
    def t3_max_date():
        df = conn.query("SELECT MAX(DATE_SK) AS D FROM GN_DW.GOLD.FACT_MEMBER_EVENT WHERE DVLP_DIV_CD IN ('1','2','4')")
        d = int(df["D"].iloc[0])
        return date(d // 10000, d // 100 % 100, d % 100)

    @st.cache_data(ttl=600)
    def t3_load_actual(cur_s, cur_e, prev_s, prev_e):
        sql = f"""
        SELECT
            IFF(f.DATE_SK >= ?, 'CUR', 'PREV') AS PERIOD,
            {T3_TEAM_CASE} AS TEAM,
            CASE f.DVLP_DIV_CD WHEN '1' THEN '신규' WHEN '2' THEN '증액' ELSE '재후원' END AS DTYPE,
            s.CPR_DIV_NM AS CPR,
            CASE WHEN s.SPONSORSHIP_GROUP4_NAME IN ('국내','결연','해외프로젝트') THEN s.SPONSORSHIP_GROUP4_NAME ELSE '기타' END AS BIZ,
            SUM(f.DEV_CNT) AS CNT
        FROM GN_DW.GOLD.FACT_MEMBER_EVENT f
        JOIN GN_DW.GOLD.DIM_SPONSORSHIP s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
        LEFT JOIN GN_DW.GOLD.DIM_ORG o ON f.ORG_SK = o.ORG_SK
        WHERE f.DVLP_DIV_CD IN ('1','2','4')
          AND (f.DATE_SK BETWEEN ? AND ? OR f.DATE_SK BETWEEN ? AND ?)
        GROUP BY ALL
        """
        df = conn.query(sql, params=[cur_s, cur_s, cur_e, prev_s, prev_e])
        df["CNT"] = df["CNT"].astype(float)
        return df

    @st.cache_data(ttl=3600)
    def t3_load_target(year, month):
        sql = """
        SELECT
            CASE WHEN SRC_TEAM_NM = '캠페인기획2팀' THEN '대면모금' ELSE SRC_TEAM_NM END AS TEAM,
            CASE WHEN SRC_SPONSOR_BIZ_NM IN ('국내','결연','해외프로젝트') THEN SRC_SPONSOR_BIZ_NM ELSE '기타' END AS BIZ,
            SUM(IFF(CAL_MONTH <= ?, ANNUAL_GOAL_CNT, 0)) AS YTD_GOAL,
            SUM(ANNUAL_GOAL_CNT) AS YEAR_GOAL
        FROM GN_DW.GOLD.WIDE_TARGET_BIZ
        WHERE CAL_YEAR = ? AND GOAL_TYPE_NM = '회원개발'
        GROUP BY ALL
        """
        df = conn.query(sql, params=[month, year])
        df[["YTD_GOAL", "YEAR_GOAL"]] = df[["YTD_GOAL", "YEAR_GOAL"]].astype(float)
        return df

    def t3_clear_cache():
        t3_max_date.clear()
        t3_load_actual.clear()
        t3_load_target.clear()

    # ─── 기준일 선택 ───
    fc1, fc2 = st.columns([2, 5], vertical_alignment="bottom")
    with fc1:
        max_d = t3_max_date()
        as_of = st.date_input("기준일", value=max_d, max_value=max_d, key="t3_asof")
    with fc2:
        st.button("최신 데이터 다시 불러오기", on_click=t3_clear_cache, key="t3_refresh")

    yr, mo = as_of.year, as_of.month
    prev_month_end = (date(yr - 1, mo + 1, 1) if mo < 12 else date(yr, 1, 1)) - timedelta(days=1)
    CUR_S, CUR_E = yr * 10000 + 101, int(as_of.strftime("%Y%m%d"))
    PREV_S, PREV_E = (yr - 1) * 10000 + 101, int(prev_month_end.strftime("%Y%m%d"))
    st.caption(
        f"실적: {yr}.01.01 ~ {as_of:%Y.%m.%d} 누계 · 목표: 1~{mo}월 누계 · "
        f"전년 동월 누계: {yr-1}.01.01 ~ {prev_month_end:%Y.%m.%d} · 법인은 회원 후원사업 법인(사단/사복) 기준"
    )

    with st.spinner("전체 개발실적 조회 중..."):
        act = t3_load_actual(CUR_S, CUR_E, PREV_S, PREV_E)
        tgt = t3_load_target(yr, mo)

    cur = act[act["PERIOD"] == "CUR"]
    prev = act[act["PERIOD"] == "PREV"]

    def a_sum(df, teams, dtype=None, cpr=None, biz=None):
        m = df["TEAM"].isin(teams)
        if dtype:
            m &= df["DTYPE"] == dtype
        if cpr:
            m &= df["CPR"] == cpr
        if biz:
            m &= df["BIZ"].isin(biz if isinstance(biz, list) else [biz])
        return float(df.loc[m, "CNT"].sum())

    def t_sum(teams, col, biz=None):
        m = tgt["TEAM"].isin(teams)
        if biz:
            m &= tgt["BIZ"].isin(biz if isinstance(biz, list) else [biz])
        return float(tgt.loc[m, col].sum())

    def rate(a, t):
        return a / t if t else None

    def fmt_n(v, dec=0):
        if v is None or abs(v) < 0.05:
            return "-"
        return f"{v:,.{dec}f}"

    def fmt_r(v):
        return "-" if v is None else f"{v:.0%}"

    def rate_color(v):
        if v is None:
            return ""
        return "color:#D32F2F;" if v < 0.9 else ("color:#1565C0;" if v >= 1 else "")

    # ─── KPI ───
    tot = a_sum(cur, T3_ALL_TEAMS)
    tot_sadan = a_sum(cur, T3_ALL_TEAMS, cpr="사단")
    tot_goal = t_sum(T3_ALL_TEAMS, "YTD_GOAL")
    tot_year_goal = t_sum(T3_ALL_TEAMS, "YEAR_GOAL")
    tot_prev = a_sum(prev, T3_ALL_TEAMS)
    k1, k2, k3, k4 = st.columns(4)
    k1.metric("총 개발건 (사단+사복)", f"{tot:,.0f}")
    k2.metric(f"{mo}월 누계목표 달성률", fmt_r(rate(tot, tot_goal)), f"사단 {fmt_r(rate(tot_sadan, tot_goal))}", delta_color="off")
    k3.metric("전년 동월 누계 대비", f"{tot - tot_prev:+,.0f}", fmt_r(rate(tot - tot_prev, tot_prev)))
    k4.metric("연목표 대비 달성률", fmt_r(rate(tot, tot_year_goal)), f"기준일 {as_of:%m/%d}", delta_color="off")

    # ─── 표1. 법인별 회원개발 실적 ───
    st.markdown("#### 1. 법인별 회원개발 실적")
    show_detail = st.toggle("신규/증액/재후원 상세 보기", value=True, key="t3_detail")

    TH = "padding:4px 6px;border:1px solid #999;text-align:center;"
    TD = "padding:3px 6px;border:1px solid #ccc;text-align:right;"
    TL = "padding:3px 6px;border:1px solid #ccc;text-align:left;"
    STYLE_SUB = "background:#e8e8e8;font-weight:bold;"
    STYLE_MID = "background:#cfe2f3;font-weight:bold;"
    STYLE_TOT = "background:#333;color:white;font-weight:bold;"

    def t1_cells(teams, dtype=None, with_goal=True):
        a_all = a_sum(cur, teams, dtype)
        a_sd = a_sum(cur, teams, dtype, cpr="사단")
        a_sb = a_sum(cur, teams, dtype, cpr="사복")
        p_all = a_sum(prev, teams, dtype)
        g = t_sum(teams, "YTD_GOAL") if with_goal else None
        gy = t_sum(teams, "YEAR_GOAL") if with_goal else None
        r_all, r_sd = (rate(a_all, g), rate(a_sd, g)) if with_goal else (None, None)
        r_txt = (lambda r: fmt_r(r)) if with_goal else (lambda r: "")
        return (
            f'<td style="{TD}">{fmt_n(a_all)}</td><td style="{TD}">{fmt_n(g)}</td>'
            f'<td style="{TD}{rate_color(r_all)}">{r_txt(r_all)}</td><td style="{TD}">{fmt_n(gy)}</td>'
            f'<td style="{TD}">{fmt_n(p_all)}</td>'
            f'<td style="{TD}">{fmt_n(a_sd, 1)}</td><td style="{TD}">{fmt_n(g)}</td>'
            f'<td style="{TD}{rate_color(r_sd)}">{r_txt(r_sd)}</td><td style="{TD}">{fmt_n(gy)}</td>'
            f'<td style="{TD}">{fmt_n(a_sb)}</td>'
        )

    t1_rows = []

    def add_team(team):
        name = T3_DISPLAY.get(team, team)
        if show_detail:
            for i, dt in enumerate(T3_TYPES):
                first = f'<td rowspan="3" style="{TL}font-weight:bold;">{name}</td>' if i == 0 else ""
                t1_rows.append(f'<tr>{first}<td style="{TL}">{dt}</td>{t1_cells([team], dt, with_goal=False)}</tr>')
        t1_rows.append(f'<tr style="{STYLE_SUB}"><td colspan="2" style="{TL}">{name} 소계</td>{t1_cells([team])}</tr>')

    def add_sum(label, teams, style):
        t1_rows.append(f'<tr style="{style}"><td colspan="2" style="{TL}">{label}</td>{t1_cells(teams)}</tr>')

    for t in T3_NANUM:
        add_team(t)
    add_sum("나눔마케팅본부 소계", T3_NANUM, STYLE_MID)
    for t in T3_HQ_ETC:
        add_team(t)
    add_sum("본부 소계", T3_NANUM + T3_HQ_ETC, STYLE_MID)
    for t in T3_BRANCH:
        add_team(t)
    add_sum("지부 소계", T3_BRANCH, STYLE_MID)
    add_team("대면모금")
    add_sum("사단 총계", T3_SADAN_TEAMS, STYLE_MID)
    add_sum("사복 본부/지부", T3_SABOK, STYLE_SUB)
    add_sum("사단+사복 총계", T3_ALL_TEAMS, STYLE_TOT)

    t1_head = (
        f'<tr style="background:#4a4a4a;color:white;">'
        f'<th rowspan="2" colspan="2" style="{TH}">구분</th>'
        f'<th colspan="4" style="{TH}">통합(사단법인+사회복지법인)</th>'
        f'<th rowspan="2" style="{TH}">참고_전년 동월<br>누계 실적</th>'
        f'<th colspan="4" style="{TH}">사단법인 소속회원</th>'
        f'<th style="{TH}">사회복지법인 소속회원</th></tr>'
        f'<tr style="background:#6a6a6a;color:white;">'
        + "".join(f'<th style="{TH}">{h}</th>' for h in
                  [f"{mo}월 누계 실적(건)", f"{mo}월 누계 목표", "달성률", "연목표(1-12월)",
                   f"{mo}월 누계 실적(건)", f"{mo}월 누계 목표", "달성률", "연목표(1-12월)", f"{mo}월 누계 실적(건)"])
        + "</tr>"
    )
    st.markdown(
        f'<div style="overflow-x:auto;"><table style="width:100%;border-collapse:collapse;font-size:12px;">'
        f"<thead>{t1_head}</thead><tbody>{''.join(t1_rows)}</tbody></table></div>",
        unsafe_allow_html=True,
    )
    st.caption(
        f"* 법인별 누계실적은 개발소속 기준이 아닌 회원이 속한 법인 기준. "
        f"(통합) 연목표 대비 달성율 {fmt_r(rate(tot, tot_year_goal))} · (사단) 연목표 대비 달성율 {fmt_r(rate(tot_sadan, tot_year_goal))}. "
        "목표는 부서 소계 단위로만 관리되어 신규/증액/재후원 행에는 표시하지 않음. '연사업' 열은 정의 확인 전까지 제외."
    )

    # ─── 표2. 후원사업별 회원 개발 실적 ───
    st.markdown("#### 2. 후원사업별 회원 개발 실적")
    t2_mode = st.radio("구분", [f"{mo}월 누계 실적", f"{mo}월 누계 목표", f"{mo}월 누계 달성율"],
                       horizontal=True, key="t3_t2mode", label_visibility="collapsed")
    T2_COLS = [("합계(사복+사단)", None, None), ("사복 소계", "사복", None), ("사단 소계", "사단", None), ("국내(사단)", "사단", "국내"),
               ("해외(소계)", "사단", ["결연", "해외프로젝트"]), ("결연", "사단", "결연"),
               ("프젝", "사단", "해외프로젝트"), ("기타(소계)", "사단", "기타")]

    def t2_value(teams, cpr, biz):
        a = a_sum(cur, teams, cpr=cpr, biz=biz)
        g = t_sum(teams, "YTD_GOAL", biz=biz) if cpr in ("사단", None) else 0.0
        if t2_mode.endswith("실적"):
            return fmt_n(a), ""
        if t2_mode.endswith("목표"):
            return fmt_n(g), ""
        r = rate(a, g)
        return ("" if r is None else fmt_r(r)), rate_color(r)

    t2_rows = []
    t2_items = [(T3_DISPLAY.get(t, t).replace("지부-", ""), [t]) for t in T3_ALL_TEAMS] + [("소계", T3_ALL_TEAMS)]
    for i, (label, teams) in enumerate(t2_items):
        style = STYLE_TOT if label == "소계" else ("background:#f5f5f5;" if i % 2 else "")
        cells = ""
        for _, cpr, biz in T2_COLS:
            v, c = t2_value(teams, cpr, biz)
            cells += f'<td style="{TD}{c}">{v}</td>'
        t2_rows.append(f'<tr style="{style}height:28px;"><td style="{TL}white-space:nowrap;">{label}</td>{cells}</tr>')
    T2_NOWRAP = "white-space:nowrap;overflow:hidden;text-overflow:ellipsis;"
    t2_w = f"{100 / (len(T2_COLS) + 1):.4f}%"
    t2_colgroup = "".join(f'<col style="width:{t2_w};">' for _ in range(len(T2_COLS) + 1))
    st.markdown(
        f'<div style="overflow-x:auto;"><table style="width:100%;table-layout:fixed;border-collapse:collapse;font-size:12px;">'
        f'<colgroup>{t2_colgroup}</colgroup>'
        f'<thead><tr style="background:#4a4a4a;color:white;height:28px;"><th style="{TH}{T2_NOWRAP}">구분</th>'
        + "".join(f'<th style="{TH}{T2_NOWRAP}" title="{c[0]}">{c[0]}</th>' for c in T2_COLS)
        + f"</tr></thead><tbody>{''.join(t2_rows)}</tbody></table></div>",
        unsafe_allow_html=True,
    )

    # ─── 자동 요약 문장 ───
    st.markdown("#### 주간 회원개발 실적 공유")
    groups = [("나눔마케팅본부", T3_NANUM), ("회원참여팀", ["회원참여팀"]), ("지부", T3_BRANCH), ("대면모금", T3_FACE)]
    prog = ", ".join(f"{n}({fmt_r(rate(a_sum(cur, t), t_sum(t, 'YTD_GOAL')))})" for n, t in groups)
    yoy_parts = []
    for n, t in groups:
        c_, p_ = a_sum(cur, t), a_sum(prev, t)
        yoy_parts.append(f"{n} {fmt_r(rate(c_ - p_, p_))}({c_ - p_:+,.0f}건)")
    st.info(
        f"{as_of.month}/{as_of.day} 기준 총 {tot:,.0f}건 개발 되어 누계 목표 대비 {fmt_r(rate(tot, tot_goal))} 달성. "
        f"(사단법인 {tot_sadan:,.0f}건 누계 목표 대비 {fmt_r(rate(tot_sadan, tot_goal))})\n\n"
        f"{mo}월 누계 목표 대비 진행율 : {prog}.\n\n"
        f"전년 동월 누계 대비 : {', '.join(yoy_parts)}."
    )

# ═══════════════════════════════════════════════════════
# 탭 4: 국내 사단사업장 회원개발 (지부/시도본부 + 본부 대면모금)
# ═══════════════════════════════════════════════════════
T4_HQ_DEPTS = ("캠페인기획2팀", "소셜펀딩팀", "소셜펀딩부")
T4_SITES = [
    "서울인천권역본부", "서울남부사업본부", "서울북부사업본부", "인천사업본부",
    "경기강원권역본부", "경기남부사업본부", "경기동부사업본부", "경기2사업본부", "강원지부",
    "충청권역본부", "대전충북사업본부", "호남권역본부", "전북지부",
    "영남권역본부", "대구사업본부", "경북사업본부", "경남사업본부", "울산지부",
]
T4_EDU = ["E_FAMILY", "E_KID_ETC", "E_HOPE", "E_ELEM_ETC", "E_TEEN", "E_ETC"]
T4_REG = ["R_UNIV", "R_SHOP", "R_CHURCH", "R_NEW", "R_INTL", "R_MANUAL", "R_STREET", "R_ETC"]
T4_BR = T4_EDU + T4_REG
T4_ALL = T4_BR + ["HQ"]
T4_SADAN_BIZ = [
    "해외아동결연", "보건의료지원사업", "해외교육지원사업", "식수위생지원사업", "해외지역개발사업",
    "재난구호지원사업", "전체사업지원", "희망학교지원사업", "좋은이웃", "국내아동권리보호사업(사단법인)",
]
T4_SABOK_BIZ = ["국내아동권리보호사업(사회복지법인)", "국내사업"]

# 행 구분: 본부 대면모금 → 교육기관(캠페인별) → 지역개발(캠페인별). 지역사회(수기)는 원천 구분이 없어 0 고정.
T4_ROW_CASE = f"""
    CASE
        WHEN o.DEPARTMENT IN {T4_HQ_DEPTS} THEN 'HQ'
        WHEN f.MBER_INFLOW_PATH_NM_AT_EVENT = '교육기관' THEN CASE
            WHEN f.PARENT_CAMPAIGN_NAME_AT_EVENT = '교육기관(기타) 캠페인' THEN 'E_ETC'
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '유아캠페인'
                THEN IFF(f.MKTG_CMPGN_NM_AT_EVENT = '가족그림편지쓰기대회', 'E_FAMILY', 'E_KID_ETC')
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '초등캠페인'
                THEN IFF(f.MKTG_CMPGN_NM_AT_EVENT = '희망편지쓰기대회', 'E_HOPE', 'E_ELEM_ETC')
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '청소년캠페인' THEN 'E_TEEN'
            ELSE 'E_ETC'
        END
        ELSE CASE
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '대학생캠페인' OR f.PARENT_CAMPAIGN_NAME_AT_EVENT = '대학생 캠페인' THEN 'R_UNIV'
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '좋은이웃가게' THEN 'R_SHOP'
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '교회캠페인' THEN 'R_CHURCH'
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '신규기획사업' THEN 'R_NEW'
            WHEN f.CMPGN_CTGR_NM_AT_EVENT = '가두캠페인' THEN 'R_STREET'
            WHEN c.CAMPAIGN_NAME ILIKE '%국제교류%' THEN 'R_INTL'
            ELSE 'R_ETC'
        END
    END
"""
T4_FROM = f"""
    FROM GN_DW.GOLD.FACT_MEMBER_EVENT f
    JOIN GN_DW.GOLD.DIM_ORG o ON f.ORG_SK = o.ORG_SK
    LEFT JOIN GN_DW.GOLD.DIM_SPONSORSHIP s ON f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
    LEFT JOIN GN_DW.GOLD.DIM_CAMPAIGN c ON f.CAMPAIGN_SK = c.CAMPAIGN_SK
    WHERE f.DVLP_DIV_CD IN ('1','2','4')
      AND f.DATE_SK BETWEEN ? AND ?
      AND (o.ACMSLT_DIV_GROUP_NM IN ('지부','시도본부') OR o.DEPARTMENT IN {T4_HQ_DEPTS})
"""


@st.cache_data(ttl=3600)
def t4_max_date():
    df = conn.query("SELECT MAX(DATE_SK) AS D FROM GN_DW.GOLD.FACT_MEMBER_EVENT WHERE DVLP_DIV_CD IN ('1','2','4')")
    d = int(df["D"].iloc[0])
    return date(d // 10000, d // 100 % 100, d % 100)


@st.cache_data(ttl=600)
def t4_load_grain(start_sk, end_sk, pyd_s, pyd_e):
    # 연·월·행구분·사업장·후원사업 단위 집계 (PYD = 전년 1/1~전년 동일자 누계)
    sql = f"""
    SELECT
        FLOOR(f.DATE_SK / 10000) AS Y,
        FLOOR(f.DATE_SK / 100) % 100 AS M,
        {T4_ROW_CASE} AS ROWKEY,
        IFF(o.DEPARTMENT IN {T4_HQ_DEPTS}, '본부', o.DEPARTMENT) AS SITE,
        COALESCE(s.SPONSORSHIP_NAME, '(미지정)') AS BIZ,
        SUM(f.DEV_CNT) AS CNT,
        SUM(IFF(f.DATE_SK BETWEEN ? AND ?, f.DEV_CNT, 0)) AS PYD
    {T4_FROM}
    GROUP BY ALL
    """
    df = conn.query(sql, params=[pyd_s, pyd_e, start_sk, end_sk])
    df[["Y", "M"]] = df[["Y", "M"]].astype(int)
    df[["CNT", "PYD"]] = df[["CNT", "PYD"]].astype(float)
    return df


@st.cache_data(ttl=600)
def t4_load_daily(start_sk, end_sk):
    sql = f"""
    SELECT f.DATE_SK, {T4_ROW_CASE} AS ROWKEY, SUM(f.DEV_CNT) AS CNT
    {T4_FROM}
    GROUP BY ALL
    """
    df = conn.query(sql, params=[start_sk, end_sk])
    df["DATE_SK"] = df["DATE_SK"].astype(int)
    df["CNT"] = df["CNT"].astype(float)
    return df


@st.cache_data(ttl=3600)
def t4_load_target(year):
    # SITE: 사업장별 월목표 / BIZ: 교육기관(EDU)·지역사회(REG)·대면모금(HQ) 월목표
    sql = """
    SELECT 'SITE' AS KIND, ORG_DEPARTMENT AS NM, CAL_MONTH AS M, SUM(GOAL_CNT) AS G
    FROM GN_DW.GOLD.WIDE_TARGET_DEV
    WHERE CAL_YEAR = ?
    GROUP BY ALL
    UNION ALL
    SELECT 'BIZ',
        CASE SRC_TEAM_NM WHEN '교육기관' THEN 'EDU' WHEN '지역사회' THEN 'REG' ELSE 'HQ' END,
        CAL_MONTH, SUM(ANNUAL_GOAL_CNT)
    FROM GN_DW.GOLD.WIDE_TARGET_BIZ
    WHERE CAL_YEAR = ? AND GOAL_TYPE_NM = '회원개발' AND SRC_TEAM_NM IN ('교육기관','지역사회','캠페인기획2팀')
    GROUP BY ALL
    """
    df = conn.query(sql, params=[year, year])
    df["M"] = df["M"].astype(int)
    df["G"] = df["G"].astype(float)
    return df


def t4_clear_cache():
    t4_max_date.clear()
    t4_load_grain.clear()
    t4_load_daily.clear()
    t4_load_target.clear()


def render_tab4():
    import calendar

    # ─── 서식 ───
    TH = "padding:3px 4px;border:1px solid #999;text-align:center;font-weight:bold;"
    TD = "padding:3px 5px;border:1px solid #ccc;text-align:right;white-space:nowrap;"
    TL = "padding:3px 5px;border:1px solid #ccc;text-align:left;word-break:keep-all;"
    HEAD = "background:#4a4a4a;color:white;"
    HEAD2 = "background:#6a6a6a;color:white;"
    HEAD_CUR = "background:#fff2cc;color:#000;"
    STYLE_SUB = "background:#e8e8e8;font-weight:bold;"
    STYLE_TOT = "background:#cfcfcf;font-weight:bold;"
    KEY = "border-left:2px solid #E53935;border-right:2px solid #E53935;"

    def render_table(head, body, ncols, widths=None):
        # 열 폭: widths(%) 지정 시 그대로, 없으면 모든 열 동일 폭 (좁은 화면은 가로 스크롤)
        widths = widths or [100 / ncols] * ncols
        cols = "".join(f'<col style="width:{w:.4f}%;">' for w in widths)
        st.markdown(
            f'<div style="overflow-x:auto;"><table style="width:100%;min-width:{ncols * 62}px;table-layout:fixed;'
            f'border-collapse:collapse;font-size:11px;word-break:keep-all;"><colgroup>{cols}</colgroup>'
            f"<thead>{head}</thead><tbody>{''.join(body)}</tbody></table></div>",
            unsafe_allow_html=True,
        )

    def n(v):
        if v is None or abs(v) < 0.5:
            return "-"
        return f"({abs(v):,.0f})" if v < 0 else f"{v:,.0f}"

    def rate(a, t):
        return a / t if t else None

    def p(r):
        if r is None:
            return "-"
        return f"({abs(r):.0%})" if r < 0 else f"{r:.0%}"

    def td(v, style=""):
        return f'<td style="{TD}{style}">{v}</td>'

    def section(title, note):
        st.markdown(
            f'<div style="background:#d9ead3;padding:5px 10px;margin:14px 0 4px 0;display:flex;'
            f'justify-content:space-between;font-weight:bold;font-size:13px;">'
            f'<span>{title}</span><span style="font-weight:normal;font-size:11px;">{note} · 단위 (건)</span></div>',
            unsafe_allow_html=True,
        )

    # ─── 기준일 ───
    max_d = t4_max_date()
    default_d = max_d - timedelta(days=(max_d.weekday() + 1) % 7)  # 직전 일요일
    hc1, hc2, hc3 = st.columns([5, 2, 1.3], vertical_alignment="bottom")
    with hc2:
        as_of = st.date_input("실적 기준일", value=default_d, max_value=max_d, key="t4_asof")
    with hc3:
        st.button("새로고침", on_click=t4_clear_cache, key="t4_refresh")
    yr, mo = as_of.year, as_of.month
    with hc1:
        st.markdown(f"### {yr}년 국내 사단사업장 회원개발 현황 보고")

    month_first = date(yr, mo, 1)
    month_last = date(yr, mo, calendar.monthrange(yr, mo)[1])
    weeks = []
    w = monday_of_week(month_first)
    while w <= month_last:
        weeks.append((w, w + timedelta(days=6)))
        w += timedelta(days=7)
    this_w = monday_of_week(as_of)
    prev_w = this_w - timedelta(days=7)
    py_same = date(yr - 1, mo, min(as_of.day, calendar.monthrange(yr - 1, mo)[1]))
    py_month_end = date(yr - 1, mo, calendar.monthrange(yr - 1, mo)[1])
    sk = lambda d: int(d.strftime("%Y%m%d"))

    with st.spinner("국내 사단사업장 회원개발 조회 중..."):
        g = t4_load_grain(sk(date(yr - 4, 1, 1)), sk(as_of), sk(date(yr - 1, 1, 1)), sk(py_same))
        daily = t4_load_daily(sk(min(prev_w, weeks[0][0])), sk(as_of))
        tgt = t4_load_target(yr)

    st.caption(
        f"실적 기준일 {as_of:%Y.%m.%d}({DAYS_KR[as_of.weekday()]}) · 당월 {mo}/1~{as_of:%m/%d} · 누계 {yr}.01.01~{as_of:%m.%d} · "
        f"전년 동월(마감) {yr-1}.01.01~{py_month_end:%m.%d} · 전년 동일 {yr-1}.01.01~{py_same:%m.%d} · "
        f"출처: FACT_MEMBER_EVENT × DIM_ORG × DIM_CAMPAIGN × DIM_SPONSORSHIP"
    )

    def gs(keys, y, m=None, m_le=None, sites=None, col="CNT", bizs=None):
        mk = g["ROWKEY"].isin(keys) & (g["Y"] == y)
        if m is not None:
            mk &= g["M"] == m
        if m_le is not None:
            mk &= g["M"] <= m_le
        if sites is not None:
            mk &= g["SITE"].isin(sites)
        if bizs is not None:
            mk &= g["BIZ"].isin(bizs)
        return float(g.loc[mk, col].sum())

    def ds(keys, s, e):
        mk = daily["ROWKEY"].isin(keys) & daily["DATE_SK"].between(sk(s), sk(e))
        return float(daily.loc[mk, "CNT"].sum())

    def tg(kind, names, m=None, m_le=None):
        mk = (tgt["KIND"] == kind) & tgt["NM"].isin(names)
        if m is not None:
            mk &= tgt["M"] == m
        if m_le is not None:
            mk &= tgt["M"] <= m_le
        return float(tgt.loc[mk, "G"].sum())

    # 목표 키 → BIZ 목표 이름 (소계·합계 행만 목표 보유)
    TGT_KEYS = {"EDU": ["EDU"], "REG": ["REG"], "BR": ["EDU", "REG"], "HQ": ["HQ"], "ALL": ["EDU", "REG", "HQ"]}

    # ═════ 표 1. 개발 현황 ═════
    section(f"1. {yr}년 개발 현황", "* 본부 가두 캠페인 포함")
    T1_ROWS = [
        # (구분, 세부, 행키, 종류, 목표키)
        ("유아 캠페인", "가족그림", ["E_FAMILY"], "d", None),
        ("유아 캠페인", "유아기타", ["E_KID_ETC"], "d", None),
        ("초등 캠페인", "희망편지", ["E_HOPE"], "d", None),
        ("초등 캠페인", "초등기타", ["E_ELEM_ETC"], "d", None),
        ("청소년 캠페인", "", ["E_TEEN"], "d", None),
        ("교육기관(기타)", "", ["E_ETC"], "d", None),
        ("교육기관 소계", "", T4_EDU, "sub", "EDU"),
        ("대학생 캠페인", "", ["R_UNIV"], "d", None),
        ("좋은이웃가게", "", ["R_SHOP"], "d", None),
        ("교회 캠페인", "", ["R_CHURCH"], "d", None),
        ("신규기획사업", "", ["R_NEW"], "d", None),
        ("국제교류 자매결연사업", "", ["R_INTL"], "d", None),
        ("지역사회(수기)", "", ["R_MANUAL"], "d", None),
        ("가두 캠페인", "", ["R_STREET"], "d", None),
        ("지역사회(기타)", "", ["R_ETC"], "d", None),
        ("지역개발 소계", "", T4_REG, "sub", "REG"),
        ("지부 합계", "", T4_BR, "br", "BR"),
        ("본부", "기업오프라인", ["HQ"], "hq", "HQ"),
        ("총계", "", T4_ALL, "tot", "ALL"),
    ]
    branch_span = 16  # 유아~지역개발 소계
    past_years = [yr - 3, yr - 2, yr - 1]

    def t1_cells(keys, tkey):
        has_t = tkey is not None
        t_names = TGT_KEYS.get(tkey, [])
        out = "".join(td(n(gs(keys, y))) for y in past_years)
        # 당월
        mt = tg("BIZ", t_names, m=mo) if has_t else None
        out += td(n(mt))
        for ws, we in weeks:
            if ws > as_of:
                out += td("-")
            else:
                out += td(n(ds(keys, max(ws, month_first), min(we, as_of, month_last))))
        ma = gs(keys, yr, m=mo)
        out += td(n(ma), KEY) + td(p(rate(ma, mt)) if has_t else "")
        # 누계
        yt = tg("BIZ", t_names, m_le=mo) if has_t else None
        ya = gs(keys, yr)
        out += td(n(yt)) + td(n(ya), KEY) + td(p(rate(ya, yt)) if has_t else "")
        # 연목표
        ft = tg("BIZ", t_names) if has_t else None
        out += td(n(ft)) + td(p(rate(ya, ft)) if has_t else "")
        # 전년 동월(마감) / 전년 동일
        for pv in (gs(keys, yr - 1, m_le=mo), gs(keys, yr - 1, col="PYD")):
            out += td(n(pv)) + td(n(ya - pv)) + td(p(rate(ya - pv, pv)))
        # 전주/금주
        pw, tw = ds(keys, prev_w, prev_w + timedelta(days=6)), ds(keys, this_w, as_of)
        out += td(n(pw)) + td(n(tw)) + td(n(tw - pw)) + td(p(rate(tw - pw, pw)))
        return out

    t1_body = []
    for i, (gb, sb, keys, kind, tkey) in enumerate(T1_ROWS):
        style = STYLE_TOT if kind in ("br", "tot") else (STYLE_SUB if kind == "sub" else "")
        lab = ""
        if i == 0:
            lab += f'<td rowspan="{branch_span}" style="{TL}text-align:center;font-weight:bold;background:#fff;">지부</td>'
        if kind == "d":
            if sb:
                if i == 0 or T1_ROWS[i - 1][0] != gb:
                    lab += f'<td rowspan="2" style="{TL}">{gb}</td>'
                lab += f'<td style="{TL}">{sb}</td>'
            else:
                lab += f'<td colspan="2" style="{TL}">{gb}</td>'
        elif kind == "sub":
            lab += f'<td colspan="2" style="{TL}">{gb}</td>'
        elif kind == "hq":
            lab += f'<td style="{TL}text-align:center;font-weight:bold;">{gb}</td><td colspan="2" style="{TL}">{sb}</td>'
        else:
            lab += f'<td colspan="3" style="{TL}text-align:center;">{gb}</td>'
        t1_body.append(f'<tr style="{style}">{lab}{t1_cells(keys, tkey)}</tr>')

    nw = len(weeks)
    week_th = "".join(
        f'<th style="{TH}{HEAD_CUR}">{k + 1}주차<br><span style="font-weight:normal;">{ws:%m%d}~{we:%m%d}</span></th>'
        for k, (ws, we) in enumerate(weeks)
    )
    t1_head = (
        f'<tr style="{HEAD}">'
        f'<th rowspan="3" colspan="3" style="{TH}">구분</th>'
        f'<th colspan="3" rowspan="2" style="{TH}">연도별 최종 개발 현황</th>'
        f'<th colspan="{nw + 8}" style="{TH}">{yr}년</th>'
        f'<th colspan="3" rowspan="2" style="{TH}">전년 동월(마감) 누계 대비<br>(~{py_month_end:%y.%m.%d})</th>'
        f'<th colspan="3" rowspan="2" style="{TH}">전년 동일(마감) 누계 대비<br>(~{py_same:%y.%m.%d})</th>'
        f'<th colspan="4" rowspan="2" style="{TH}">컨텐츠별 증감 현황</th></tr>'
        f'<tr style="{HEAD2}">'
        f'<th colspan="{nw + 3}" style="{TH}">{mo}월 · 당월 목표 기준</th>'
        f'<th colspan="3" style="{TH}">누계 목표 기준</th>'
        f'<th colspan="2" style="{TH}">사업장 연목표 기준</th></tr>'
        f'<tr style="{HEAD2}">'
        + "".join(f'<th style="{TH}">{y}년</th>' for y in past_years)
        + f'<th style="{TH}">월목표</th>{week_th}'
        f'<th style="{TH}{KEY}">당월 실적</th><th style="{TH}">달성률</th>'
        f'<th style="{TH}">누계목표</th><th style="{TH}{KEY}">개발건</th><th style="{TH}">달성률</th>'
        f'<th style="{TH}">연목표</th><th style="{TH}">달성률</th>'
        + f'<th style="{TH}">개발건</th><th style="{TH}">증감건</th><th style="{TH}">증감율</th>' * 2
        + f'<th style="{TH}">전주<br>{prev_w:%m%d}~{prev_w + timedelta(days=6):%m%d}</th>'
        f'<th style="{TH}">금주<br>{this_w:%m%d}~{as_of:%m%d}</th>'
        f'<th style="{TH}">증감(건)</th><th style="{TH}">증감(%)</th></tr>'
    )
    render_table(t1_head, t1_body, nw + 24)
    st.caption(
        "*지역사회(기타) : 지역 네트워크 포함 · 국제교류 자매결연사업 = 지역사회(기타) 중 캠페인명 '국제교류' · "
        "지역사회(수기) = 원천 구분 없음(0) · 본부 기업오프라인 = 본부 대면모금 · 가두 캠페인 = 지부 가두(본부 대면모금 제외) · "
        "목표/달성률은 소계·합계 행만 표시 · 주차 실적은 당월 일자만 집계"
    )

    # ═════ 표 2. 사업장별 개발 현황 ═════
    section("2. 사업장별 개발 현황", "* 본부 가두 캠페인 제외")
    t2_body = []
    t2_tot = {}
    for site in T4_SITES + ["합계"]:
        is_tot = site == "합계"
        sites = T4_SITES if is_tot else [site]
        mt, yt, ft = tg("SITE", sites, m=mo), tg("SITE", sites, m_le=mo), tg("SITE", sites)
        ma, ya = gs(T4_BR, yr, m=mo, sites=sites), gs(T4_BR, yr, sites=sites)
        ea, ra = gs(T4_EDU, yr, sites=sites), gs(T4_REG, yr, sites=sites)
        # 사업장별 교육/지역 목표는 원천에 없어 합계 행만 교육기관/지역사회 목표 사용
        et = tg("BIZ", ["EDU"]) if is_tot else None
        rt = tg("BIZ", ["REG"]) if is_tot else None
        if is_tot:
            t2_tot = {"ma": ma, "ya": ya, "yt": yt, "ft": ft}
        cells = (
            td(n(mt)) + td(n(ma), KEY) + td(p(rate(ma, mt)))
            + td(n(yt)) + td(n(ya), KEY) + td(p(rate(ya, yt)))
            + td(n(ft)) + td(p(rate(ya, ft)))
            + td(n(et)) + td(n(ea)) + td(p(rate(ea, et)))
            + td(n(rt)) + td(n(ra)) + td(p(rate(ra, rt)))
        )
        t2_body.append(f'<tr style="{STYLE_TOT if is_tot else ""}"><td style="{TL}">{site}</td>{cells}</tr>')
    t2_head = (
        f'<tr style="{HEAD}"><th rowspan="3" style="{TH}">사업장명</th>'
        f'<th colspan="8" style="{TH}">목표 대비 진행율</th>'
        f'<th colspan="3" rowspan="2" style="{TH}">교육시장</th><th colspan="3" rowspan="2" style="{TH}">지역개발</th></tr>'
        f'<tr style="{HEAD_CUR}"><th colspan="3" style="{TH}">당월 목표 대비 달성율</th>'
        f'<th colspan="3" style="{TH}">누계 목표 대비 달성율</th><th colspan="2" style="{TH}">연목표 대비 달성율</th></tr>'
        f'<tr style="{HEAD2}"><th style="{TH}">당월목표</th><th style="{TH}{KEY}">당월 실적</th><th style="{TH}">달성율</th>'
        f'<th style="{TH}">누계목표</th><th style="{TH}{KEY}">누계 실적</th><th style="{TH}">달성율</th>'
        f'<th style="{TH}">연목표</th><th style="{TH}">달성율</th>'
        + f'<th style="{TH}">연목표</th><th style="{TH}">누계실적</th><th style="{TH}">달성율</th>' * 2
        + "</tr>"
    )
    render_table(t2_head, t2_body, 15)
    st.caption("* 교육시장/지역개발 연목표는 사업장별 원천 목표가 없어 합계 행에만 교육기관·지역사회 목표 표시")

    # ═════ 표 3. 월별 개발 현황 ═════
    section("3. 월별 개발 현황", "* 본부 가두 캠페인 제외")
    T3Y = [yr - 3, yr - 2, yr - 1]
    T3_EDU_COLS = [("유아", ["E_FAMILY", "E_KID_ETC"]), ("초등", ["E_HOPE", "E_ELEM_ETC"]), ("청소년", ["E_TEEN"]),
                   ("기타", ["E_ETC"]), ("소계", T4_EDU)]
    T3_REG_COLS = [("대학생", ["R_UNIV"]), ("좋은이웃가게", ["R_SHOP"]), ("교회", ["R_CHURCH"]), ("신규기획", ["R_NEW"]),
                   ("가두", ["R_STREET"]), ("기타", ["R_INTL", "R_MANUAL", "R_ETC"]), ("소계", T4_REG)]
    t3_body = []
    for m in list(range(1, 13)) + [None]:
        is_tot = m is None
        label = "총계" if is_tot else f"{m}월"
        mm = dict(m_le=mo) if is_tot else dict(m=m)
        cells = ""
        for y in T3Y:
            ym = {} if is_tot else dict(m=m)
            cells += td(n(gs(T4_BR, y, **ym))) + td(n(gs(T4_EDU, y, **ym))) + td(n(gs(T4_REG, y, **ym)))
        if (not is_tot) and m > mo:
            cells += td("-", KEY) + "".join(td("-") for _ in range(len(T3_EDU_COLS) + len(T3_REG_COLS) + 4))
        else:
            c_all, p_all = gs(T4_BR, yr, **mm), gs(T4_BR, yr - 1, **mm)
            cells += td(n(c_all), KEY)
            cells += "".join(td(n(gs(k, yr, **mm))) for _, k in T3_EDU_COLS + T3_REG_COLS)
            cells += (td(n(c_all - p_all)) + td(n(gs(T4_EDU, yr, **mm) - gs(T4_EDU, yr - 1, **mm)))
                      + td(n(gs(T4_REG, yr, **mm) - gs(T4_REG, yr - 1, **mm))) + td(p(rate(c_all - p_all, p_all))))
        t3_body.append(f'<tr style="{STYLE_TOT if is_tot else ""}"><td style="{TL}text-align:center;">{label}</td>{cells}</tr>')
    t3_head = (
        f'<tr style="{HEAD}"><th rowspan="3" style="{TH}">구분</th>'
        + "".join(f'<th colspan="3" rowspan="2" style="{TH}">{y}년</th>' for y in T3Y)
        + f'<th colspan="{1 + len(T3_EDU_COLS) + len(T3_REG_COLS)}" style="{TH}{HEAD_CUR}">{yr}년</th>'
        f'<th colspan="4" rowspan="2" style="{TH}">전년 동월 대비 증감 현황</th></tr>'
        f'<tr style="{HEAD2}"><th rowspan="2" style="{TH}{KEY}">총계</th>'
        f'<th colspan="{len(T3_EDU_COLS)}" style="{TH}">교육시장</th><th colspan="{len(T3_REG_COLS)}" style="{TH}">지역개발</th></tr>'
        f'<tr style="{HEAD2}">'
        + f'<th style="{TH}">합계</th><th style="{TH}">교육시장</th><th style="{TH}">지역개발</th>' * len(T3Y)
        + "".join(f'<th style="{TH}">{c}</th>' for c, _ in T3_EDU_COLS + T3_REG_COLS)
        + f'<th style="{TH}">합계</th><th style="{TH}">교육시장</th><th style="{TH}">지역개발</th><th style="{TH}">증감율(%)</th></tr>'
    )
    render_table(t3_head, t3_body, 1 + 3 * len(T3Y) + 1 + len(T3_EDU_COLS) + len(T3_REG_COLS) + 4)
    st.caption(f"* 전년 동월 대비는 {yr - 1}년 같은 월(전체 월) 기준, 총계는 1~{mo}월 합산 비교 · 지역개발 기타 = 국제교류 + 지역사회(수기·기타)")

    # ═════ 표 4. 후원사업별 개발 현황 ═════
    section("4. 후원사업별 개발 현황", "* 본부 가두 캠페인 제외 · 범위: 지부(교육기관+지역사회)")
    t4_year = st.selectbox("표 4 연도", list(range(yr, yr - 5, -1)), index=0, key="t4_t4year")
    last_m = mo if t4_year == yr else 12
    other_biz = sorted(set(g.loc[g["Y"] == t4_year, "BIZ"]) - set(T4_SADAN_BIZ + T4_SABOK_BIZ))
    other_biz = [b for b in other_biz if abs(gs(T4_BR, t4_year, bizs=[b])) >= 0.5]
    sadan_tot = gs(T4_BR, t4_year, bizs=T4_SADAN_BIZ)
    T4_ROWS = ([(b, [b], "d") for b in T4_SADAN_BIZ] + [("사단법인 소계", T4_SADAN_BIZ, "sub")]
               + [(b, [b], "d2") for b in T4_SABOK_BIZ]
               + [(f"{b} (미분류)", [b], "d2") for b in other_biz]
               + [("총계", T4_SADAN_BIZ + T4_SABOK_BIZ + other_biz, "tot")])
    t4_body = []
    for label, bizs, kind in T4_ROWS:
        style = STYLE_TOT if kind == "tot" else (STYLE_SUB if kind == "sub" else "")
        tot_v = gs(T4_BR, t4_year, bizs=bizs)
        cells = td(n(tot_v), KEY)
        cells += "".join(td("-") if m > last_m else td(n(gs(T4_BR, t4_year, m=m, bizs=bizs))) for m in range(1, 13))
        cells += td(p(rate(tot_v, sadan_tot)) if kind in ("d", "sub") else "-")
        t4_body.append(f'<tr style="{style}"><td style="{TL}">{label}</td>{cells}</tr>')
    t4_head = (
        f'<tr style="{HEAD}"><th rowspan="2" style="{TH}">사업명</th><th colspan="13" style="{TH}{HEAD_CUR}">{t4_year}년</th>'
        f'<th rowspan="2" style="{TH}">사업 비중(%)</th></tr>'
        f'<tr style="{HEAD2}"><th style="{TH}{KEY}">총계</th>'
        + "".join(f'<th style="{TH}">{m}월</th>' for m in range(1, 13)) + "</tr>"
    )
    # 사업명 18% · 총계 7% · 1~12월 각 5.75% · 사업 비중 6%
    render_table(t4_head, t4_body, 15, widths=[18, 7] + [5.75] * 12 + [6])
    st.caption("* 사업 비중 = 사단법인 소계 대비 비중 · 지부 합계(표 1~3)와 동일 범위")

    # ═════ 정합성 체크 ═════
    br_ytd = gs(T4_BR, yr)
    br_mon = gs(T4_BR, yr, m=mo)
    checks = [
        ("표1 당월 실적 = 주차 합계", br_mon,
         sum(ds(T4_BR, max(a, month_first), min(b, as_of, month_last)) for a, b in weeks if a <= as_of)),
        ("표1 지부 합계 누계 = 표2 합계 누계 실적", br_ytd, t2_tot["ya"]),
        ("표1 지부 합계 당월 = 표2 합계 당월 실적", br_mon, t2_tot["ma"]),
        ("표1 지부 누계목표 = 표2 합계 누계목표", tg("BIZ", ["EDU", "REG"], m_le=mo), t2_tot["yt"]),
        ("표1 지부 연목표 = 표2 합계 연목표", tg("BIZ", ["EDU", "REG"]), t2_tot["ft"]),
        ("표3 총계 = 표1 지부 합계 누계", sum(gs(T4_BR, yr, m=m) for m in range(1, mo + 1)), br_ytd),
    ]
    if t4_year == yr:
        checks.append(("표4 총계 = 표1 지부 합계 누계", gs(T4_BR, yr, bizs=T4_SADAN_BIZ + T4_SABOK_BIZ + other_biz), br_ytd))
    with st.expander("정합성 체크"):
        st.dataframe(
            pd.DataFrame(
                [(nm, round(a), round(b), "일치" if abs(a - b) < 0.5 else f"불일치 ({a - b:+,.0f})") for nm, a, b in checks],
                columns=["항목", "값 A", "값 B", "결과"],
            ),
            hide_index=True, use_container_width=True,
        )


with tab4:
    render_tab4()

# ═══════════════════════════════════════════════════════
# 탭 5: 홈페이지 유입 (GA4) — tab5_homepage.py
# ═══════════════════════════════════════════════════════
from tab5_homepage import render_tab5

with tab5:
    render_tab5(conn)
