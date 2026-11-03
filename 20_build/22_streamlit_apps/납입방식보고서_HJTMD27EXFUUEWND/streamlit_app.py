# 납입방식별 활동회원현황 대시보드 (MSTR_ODS 활동회원 로직 기반)
# Co-authored with CoCo
import os
import calendar
import streamlit as st
import pandas as pd

st.set_page_config(page_title="납입방식별 활동회원현황", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

SETLE_CD_MAP = {
    "1": "자동이체",
    "2": "신용카드",
    "4": "회비통장",
    "5": "휴대폰",
    "8": "OCR",
    "12": "네이버페이",
}
# 결제정보 없는 회원(SETLE_CD=0)은 회비통장(4)으로 분류
SETLE_CD_FALLBACK = "4"
SETLE_ORDER = ["1", "2", "5", "4", "8", "12"]

EXCLUDED_MEMBERS_2025 = [
    ("1846164", 202503),
    ("1860931", 202504),
    ("1860972", 202504),
    ("1721918", 202510),
    ("1945685", 202512),
    ("1894701", 202512),
]


@st.cache_data(ttl=600)
def load_active_by_setle(year, month, exclude_fake=False, use_latest_setle=True):
    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = []
    if exclude_fake and year == 2025:
        excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int]
    exclude_clause = (
        f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})"
        if excluded_mbers else ""
    )

    month_start = f"{year}-{month:02d}-01"
    last_day = calendar.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"

    # 최신 결제정보(비교표용) vs 기준월 시점 결제정보(상세표용)
    if use_latest_setle:
        setle_where = ""
    else:
        setle_where = f"WHERE FRST_REGIST_DT <= DATEADD(DAY, 1, DATEADD(MONTH, 1, '{month_start}'::DATE))"

    sql = f"""
    WITH
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID,
               CASE WHEN CPR_DIV_CD = '1' THEN 'I' WHEN CPR_DIV_CD = '2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),

    STATUS_HISTORY AS (
        SELECT MBER_NO, BF_STAT_CD, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT, 'YYYYMM') = '{strd_mt}'
    ),

    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE
                   WHEN H.CHN_STAT_CD IS NULL THEN
                       CASE
                           WHEN M.MBER_STAT_CD::VARCHAR = '12' THEN '1'
                           WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                               CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                           ELSE M.MBER_STAT_CD::VARCHAR
                       END
                   WHEN H.CHN_STAT_CD::VARCHAR = '12' THEN '1'
                   ELSE H.CHN_STAT_CD::VARCHAR
               END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO = H.MBER_NO AND H.RNUM = 1
        LEFT JOIN (
            SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL
        ) X ON M.MBER_NO = X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT, 'YYYYMM') <= '{strd_mt}'
    ),

    SETLE_UNION AS (
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, SETLE_CD, SETLE_STAT_CD, FRST_REGIST_DT
        FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
        UNION ALL
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, SETLE_CD, SETLE_STAT_CD, REGIST_DT AS FRST_REGIST_DT
        FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
    ),

    SETLE_MONTH AS (
        SELECT MBER_NO, CPR_DIV_CD, SETLE_CD, SETLE_STAT_CD
        FROM (
            SELECT MBER_NO, CPR_DIV_CD, SETLE_CD, SETLE_STAT_CD,
                   ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM
            FROM SETLE_UNION
            {setle_where}
        ) WHERE RNUM = 1
    ),

    PAY_MONTH AS (
        SELECT SPNSR_NO, SPNSR_BSNS_NO,
               SUM(CASE WHEN TO_CHAR(PAY_DE, 'YYYYMM') = '{strd_mt}' THEN PAY_AMT ELSE 0 END) AS PAY_AMT
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
        WHERE USE_YN = 'Y' AND PRCS_STAT_CD = 'S' AND PAY_STAT_CD = 'S'
          AND MBRFEE_DIV_CD = 'E' AND RETUN_MBRFEE_KEY IS NULL
          AND PAY_DE <= '{month_end}'::DATE
        GROUP BY SPNSR_NO, SPNSR_BSNS_NO
    ),

    LAST_DSCNTC AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC
        WHERE SPNSR_DSCNTC_DE <= '{month_31}'
    ),

    LAST_RE_SPNSR AS (
        SELECT MBER_NO, RE_SPNSR_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR
        WHERE RE_SPNSR_DE <= '{month_31}'
    ),

    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE
                   WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   WHEN D.SPNSR_DSCNTC_DE > R.RE_SPNSR_DE THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   WHEN R.RE_SPNSR_DE < TO_CHAR('{month_end}'::DATE, 'YYYYMMDD') THEN '{month_end}'::DATE
                   ELSE TO_DATE(R.RE_SPNSR_DE, 'YYYYMMDD')
               END AS ACTUAL_DT
        FROM LAST_DSCNTC D
        LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO = R.MBER_NO AND R.RNUM = 1
        WHERE D.RNUM = 1
    ),

    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT S.MBER_NO
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO = B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD') <= '{month_31}'
          AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231') > '{month_31}'
    ),

    ACTIVE_MEMBER AS (
        SELECT M.MBER_NO
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO = L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO = A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE
              AND COALESCE(A.ACTUAL_DT, '9999-12-31'::DATE)
              {exclude_clause}
    ),

    ACTIVE_HISTORY AS (
        SELECT A.OCCRRNC_DE, A.SPNSR_NO, A.SPNSR_BSNS_NO, A.SER_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        WHERE A.OCCRRNC_DE <= '{month_31}'
    ),

    ACTIVE_FACT AS (
        SELECT
            A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO,
            CASE WHEN COALESCE(ST.SETLE_CD::VARCHAR, '0') = '0' THEN '4'
                 ELSE ST.SETLE_CD::VARCHAR END AS SETLE_CD,
            COALESCE(ST.CPR_DIV_CD, 'I') AS CPR_DIV_CD,
            A.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT
        FROM ACTIVE_HISTORY A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO = AM.MBER_NO
        JOIN MEMBER_MONTH M ON A.MBER_NO = M.MBER_NO
        JOIN BUSINESS_DIM B ON A.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON A.MBER_NO = S.MBER_NO AND A.SPNSR_NO = S.SPNSR_NO
        LEFT JOIN SETLE_MONTH ST ON A.MBER_NO = ST.MBER_NO AND B.CPR_DIV_CD = ST.CPR_DIV_CD
        LEFT JOIN PAY_MONTH P ON A.SPNSR_NO = P.SPNSR_NO AND A.SPNSR_BSNS_NO = P.SPNSR_BSNS_NO
        WHERE A.RNUM = 1 AND A.SUM_AMT > 0
    )

    SELECT
        SETLE_CD,
        CPR_DIV_CD,
        COUNT(DISTINCT MBER_NO) AS ACTIVE_MEMBERS,
        SUM(SPNSR_AMT_CNT) AS ACTIVE_CASES
    FROM ACTIVE_FACT
    WHERE CPR_DIV_CD = 'I'
    GROUP BY SETLE_CD, CPR_DIV_CD
    ORDER BY SETLE_CD
    """
    return conn.query(sql)


def get_prev_month(year, month):
    if month == 1:
        return year - 1, 12
    return year, month - 1


def build_comparison_table(cur_df, prev_df, yoy_df):
    rows = []
    for code in SETLE_ORDER:
        label = SETLE_CD_MAP[code]
        cur_row = cur_df[cur_df["SETLE_CD"] == code]
        prev_row = prev_df[prev_df["SETLE_CD"] == code]
        yoy_row = yoy_df[yoy_df["SETLE_CD"] == code]

        c_members = int(cur_row["ACTIVE_MEMBERS"].values[0]) if len(cur_row) > 0 else 0
        c_cases = float(cur_row["ACTIVE_CASES"].values[0]) if len(cur_row) > 0 else 0.0
        p_members = int(prev_row["ACTIVE_MEMBERS"].values[0]) if len(prev_row) > 0 else 0
        p_cases = float(prev_row["ACTIVE_CASES"].values[0]) if len(prev_row) > 0 else 0.0
        y_members = int(yoy_row["ACTIVE_MEMBERS"].values[0]) if len(yoy_row) > 0 else 0
        y_cases = float(yoy_row["ACTIVE_CASES"].values[0]) if len(yoy_row) > 0 else 0.0

        rows.append({
            "code": code,
            "label": label,
            "c_members": c_members,
            "c_cases": c_cases,
            "p_members": p_members,
            "p_cases": p_cases,
            "y_members": y_members,
            "y_cases": y_cases,
        })

    total_c_m = sum(r["c_members"] for r in rows)
    total_c_c = sum(r["c_cases"] for r in rows)
    total_p_m = sum(r["p_members"] for r in rows)
    total_p_c = sum(r["p_cases"] for r in rows)
    total_y_m = sum(r["y_members"] for r in rows)
    total_y_c = sum(r["y_cases"] for r in rows)

    for r in rows:
        r["c_m_pct"] = (r["c_members"] / total_c_m * 100) if total_c_m > 0 else 0.0
        r["c_c_pct"] = (r["c_cases"] / total_c_c * 100) if total_c_c > 0 else 0.0
        r["mom_m_diff"] = r["c_members"] - r["p_members"]
        r["mom_c_diff"] = r["c_cases"] - r["p_cases"]
        r["mom_m_rate"] = ((r["c_members"] - r["p_members"]) / r["p_members"] * 100) if r["p_members"] > 0 else 0.0
        r["mom_c_rate"] = ((r["c_cases"] - r["p_cases"]) / r["p_cases"] * 100) if r["p_cases"] > 0 else 0.0
        r["yoy_m_diff"] = r["c_members"] - r["y_members"]
        r["yoy_c_diff"] = r["c_cases"] - r["y_cases"]
        r["yoy_m_rate"] = ((r["c_members"] - r["y_members"]) / r["y_members"] * 100) if r["y_members"] > 0 else 0.0
        r["yoy_c_rate"] = ((r["c_cases"] - r["y_cases"]) / r["y_cases"] * 100) if r["y_cases"] > 0 else 0.0

    total = {
        "label": "합계",
        "c_members": total_c_m, "c_cases": total_c_c,
        "c_m_pct": 100.0, "c_c_pct": 100.0,
        "mom_m_diff": total_c_m - total_p_m,
        "mom_c_diff": total_c_c - total_p_c,
        "mom_m_rate": ((total_c_m - total_p_m) / total_p_m * 100) if total_p_m > 0 else 0.0,
        "mom_c_rate": ((total_c_c - total_p_c) / total_p_c * 100) if total_p_c > 0 else 0.0,
        "yoy_m_diff": total_c_m - total_y_m,
        "yoy_c_diff": total_c_c - total_y_c,
        "yoy_m_rate": ((total_c_m - total_y_m) / total_y_m * 100) if total_y_m > 0 else 0.0,
        "yoy_c_rate": ((total_c_c - total_y_c) / total_y_c * 100) if total_y_c > 0 else 0.0,
    }

    return rows, total


def render_html_table(rows, total, sel_year, sel_month):
    prev_y, prev_m = get_prev_month(sel_year, sel_month)
    yoy_y = sel_year - 1

    hdr_bg = "#4472C4"
    hdr2_bg = "#5B9BD5"
    th_style = (
        f"background:{hdr_bg};color:#fff;text-align:center;padding:6px 8px;"
        "font-size:12px;font-weight:bold;border:1px solid #ddd;"
    )
    th2_style = (
        f"background:{hdr2_bg};color:#fff;text-align:center;padding:4px 6px;"
        "font-size:11px;font-weight:bold;border:1px solid #ddd;"
    )
    td_style = "text-align:right;padding:4px 8px;font-size:12px;border:1px solid #ddd;"
    td_label = "text-align:center;padding:4px 8px;font-size:12px;font-weight:bold;border:1px solid #ddd;background:#F2F2F2;"
    total_style = "text-align:right;padding:4px 8px;font-size:12px;font-weight:bold;border:1px solid #ddd;background:#D9E2F3;"
    total_label = "text-align:center;padding:4px 8px;font-size:12px;font-weight:bold;border:1px solid #ddd;background:#D9E2F3;"

    def fmt_int(v):
        return f"{int(v):,}"

    def fmt_float(v):
        return f"{v:,.1f}"

    def fmt_pct(v):
        return f"{v:.1f}"

    def fmt_diff(v, is_float=False):
        if is_float:
            sign = "+" if v > 0 else ""
            return f'{sign}{v:,.1f}'
        sign = "+" if v > 0 else ""
        return f'{sign}{int(v):,}'

    def fmt_rate(v):
        sign = "+" if v > 0 else ""
        return f'{sign}{v:.1f}'

    def color_cell(val, td_base, is_float=False):
        color = ""
        if val > 0:
            color = "color:#0000CC;"
        elif val < 0:
            color = "color:#CC0000;"
        return f'<td style="{td_base}{color}">'

    html = '<div style="overflow-x:auto;">'
    html += '<table style="border-collapse:collapse;width:auto;white-space:nowrap;">'

    # Row 1: 그룹 헤더
    html += "<thead><tr>"
    html += f'<th rowspan="2" style="{th_style}min-width:80px;">납입방식</th>'
    html += f'<th colspan="4" style="{th_style}">{sel_year}년 {sel_month}월 기준</th>'
    html += f'<th colspan="4" style="{th_style}">전월 대비 ({prev_y}.{prev_m:02d})</th>'
    html += f'<th colspan="4" style="{th_style}">전년동월 대비 ({yoy_y}.{sel_month:02d})</th>'
    html += "</tr>"

    # Row 2: 세부 헤더
    html += "<tr>"
    for _ in range(3):
        html += f'<th style="{th2_style}">활동회원(명)</th>'
        html += f'<th style="{th2_style}">활동회원(건)</th>'
        html += f'<th style="{th2_style}">명 구성비(%)</th>' if _ == 0 else f'<th style="{th2_style}">명 증감율(%)</th>'
        html += f'<th style="{th2_style}">건 구성비(%)</th>' if _ == 0 else f'<th style="{th2_style}">건 증감율(%)</th>'
    html += "</tr></thead>"

    html += "<tbody>"
    for r in rows:
        html += "<tr>"
        html += f'<td style="{td_label}">{r["label"]}</td>'
        # 당월
        html += f'<td style="{td_style}">{fmt_int(r["c_members"])}</td>'
        html += f'<td style="{td_style}">{fmt_float(r["c_cases"])}</td>'
        html += f'<td style="{td_style}">{fmt_pct(r["c_m_pct"])}</td>'
        html += f'<td style="{td_style}">{fmt_pct(r["c_c_pct"])}</td>'
        # 전월 대비
        html += color_cell(r["mom_m_diff"], td_style)
        html += f'{fmt_diff(r["mom_m_diff"])}</td>'
        html += color_cell(r["mom_c_diff"], td_style, True)
        html += f'{fmt_diff(r["mom_c_diff"], True)}</td>'
        html += color_cell(r["mom_m_rate"], td_style)
        html += f'{fmt_rate(r["mom_m_rate"])}</td>'
        html += color_cell(r["mom_c_rate"], td_style)
        html += f'{fmt_rate(r["mom_c_rate"])}</td>'
        # 전년동월 대비
        html += color_cell(r["yoy_m_diff"], td_style)
        html += f'{fmt_diff(r["yoy_m_diff"])}</td>'
        html += color_cell(r["yoy_c_diff"], td_style, True)
        html += f'{fmt_diff(r["yoy_c_diff"], True)}</td>'
        html += color_cell(r["yoy_m_rate"], td_style)
        html += f'{fmt_rate(r["yoy_m_rate"])}</td>'
        html += color_cell(r["yoy_c_rate"], td_style)
        html += f'{fmt_rate(r["yoy_c_rate"])}</td>'
        html += "</tr>"

    # 합계
    t = total
    html += "<tr>"
    html += f'<td style="{total_label}">합계</td>'
    html += f'<td style="{total_style}">{fmt_int(t["c_members"])}</td>'
    html += f'<td style="{total_style}">{fmt_float(t["c_cases"])}</td>'
    html += f'<td style="{total_style}">{fmt_pct(t["c_m_pct"])}</td>'
    html += f'<td style="{total_style}">{fmt_pct(t["c_c_pct"])}</td>'

    for prefix in ["mom", "yoy"]:
        for key, is_f in [("m_diff", False), ("c_diff", True), ("m_rate", False), ("c_rate", False)]:
            full_key = f"{prefix}_{key}"
            val = t[full_key]
            c = ""
            if val > 0:
                c = "color:#0000CC;"
            elif val < 0:
                c = "color:#CC0000;"
            html += f'<td style="{total_style}{c}">'
            if "rate" in key:
                html += fmt_rate(val)
            elif is_f:
                html += fmt_diff(val, True)
            else:
                html += fmt_diff(val)
            html += "</td>"

    html += "</tr></tbody></table></div>"
    return html


# --- 사이드바: 조회 조건 ---
with st.sidebar:
    st.header("조회 조건")
    sel_year = st.selectbox("년도", options=[2026, 2025, 2024, 2023], index=0)
    sel_month = st.selectbox("월", options=list(range(1, 13)), index=5, format_func=lambda x: f"{x}월")

    st.divider()
    exclude_fake = st.toggle(
        "허수회원 제외",
        value=True if sel_year == 2025 else False,
        help=(
            "2025년 고액허수회원/직원테스트 6명 제외\n\n"
            "• 1846164 — 3월, 599건 (고액허수)\n"
            "• 1860931 — 4월, 4건 (직원테스트)\n"
            "• 1860972 — 4월, 2건 (직원테스트)\n"
            "• 1721918 — 10월, 2,952건 (고액허수)\n"
            "• 1945685 — 12월, 10건 (고액허수)\n"
            "• 1894701 — 12월, 480건 (고액허수)"
        ),
    )

    st.divider()
    st.subheader("진행 메모")
    if "report_memo" not in st.session_state:
        st.session_state.report_memo = ""
    st.session_state.report_memo = st.text_area(
        "보고서 진행 상황을 메모하세요",
        value=st.session_state.report_memo,
        height=120,
        placeholder="예: 6월 데이터 검증 완료, 7월 집계 진행중...",
    )

# --- 메인 ---
st.title("1. 납입방식별 활동회원현황")
st.markdown("*사단법인 기준 · MSTR_ODS 활동회원 로직 재현*")

prev_year, prev_month = get_prev_month(sel_year, sel_month)
yoy_year = sel_year - 1

with st.spinner("납입방식별 활동회원 집계 중... (소요시간 약 1~3분)"):
    # 1번 표: 최신 결제정보 기준 (동일 분류로 증감 비교)
    cur_df = load_active_by_setle(sel_year, sel_month, exclude_fake, use_latest_setle=True)
    prev_df = load_active_by_setle(prev_year, prev_month, exclude_fake, use_latest_setle=True)
    yoy_df = load_active_by_setle(yoy_year, sel_month, exclude_fake, use_latest_setle=True)
    # 상세표: 해당 월 시점 결제정보 기준 (당시 실제 스냅샷)
    prev_detail_df = load_active_by_setle(prev_year, prev_month, exclude_fake, use_latest_setle=False)
    yoy_detail_df = load_active_by_setle(yoy_year, sel_month, exclude_fake, use_latest_setle=False)

for df in [cur_df, prev_df, yoy_df, prev_detail_df, yoy_detail_df]:
    df["SETLE_CD"] = df["SETLE_CD"].astype(str).str.strip()

if not cur_df.empty:
    rows, total = build_comparison_table(cur_df, prev_df, yoy_df)
    html = render_html_table(rows, total, sel_year, sel_month)
    st.markdown(html, unsafe_allow_html=True)
    st.caption(
        f"출처: BRONZE_CRM — MSTR_ODS 원천 기반 F_MM_SPNSR_ACT 재현 "
        f"(사단법인, 납입방식별, 기준월: {sel_year}-{sel_month:02d})"
    )
    st.markdown(
        '<div style="font-size:11px;color:#555;line-height:1.6;">'
        "※ 납입방식별 활동회원은 데이터 마감 시점을 기준으로 추출되므로 실제 회원 명수 및 건수는 CRM과 상이할 수 있음.<br>"
        "※ 사단법인 및 사회복지법인 통합회원의 경우 각 법인별 납입방식에 회원 명수가 중복으로 포함됨.<br>"
        "※ 사단법인 납입방식 중 네이버페이는 2019년 3월 신규 추가되었음."
        "</div>", unsafe_allow_html=True
    )

    # --- 전월 / 전년동월 상세 표 (expander) ---
    def render_detail_table(df, title_year, title_month):
        df = df.copy()
        df["SETLE_CD"] = df["SETLE_CD"].astype(str).str.strip()
        detail_rows = []
        for code in SETLE_ORDER:
            row = df[df["SETLE_CD"] == code]
            m = int(row["ACTIVE_MEMBERS"].values[0]) if len(row) > 0 else 0
            c = float(row["ACTIVE_CASES"].values[0]) if len(row) > 0 else 0.0
            detail_rows.append({"label": SETLE_CD_MAP[code], "members": m, "cases": c})

        tot_m = sum(r["members"] for r in detail_rows)
        tot_c = sum(r["cases"] for r in detail_rows)

        hdr_bg = "#4472C4"
        th = (f"background:{hdr_bg};color:#fff;text-align:center;padding:6px 8px;"
              "font-size:12px;font-weight:bold;border:1px solid #ddd;")
        td = "text-align:right;padding:4px 8px;font-size:12px;border:1px solid #ddd;"
        td_l = "text-align:center;padding:4px 8px;font-size:12px;font-weight:bold;border:1px solid #ddd;background:#F2F2F2;"
        tot_s = "text-align:right;padding:4px 8px;font-size:12px;font-weight:bold;border:1px solid #ddd;background:#D9E2F3;"
        tot_l = "text-align:center;padding:4px 8px;font-size:12px;font-weight:bold;border:1px solid #ddd;background:#D9E2F3;"

        h = '<table style="border-collapse:collapse;width:auto;white-space:nowrap;">'
        h += f'<thead><tr><th style="{th}min-width:80px;">납입방식</th>'
        h += f'<th style="{th}">활동회원(명)</th><th style="{th}">활동회원(건)</th>'
        h += f'<th style="{th}">명 구성비(%)</th><th style="{th}">건 구성비(%)</th></tr></thead><tbody>'

        for r in detail_rows:
            m_pct = (r["members"] / tot_m * 100) if tot_m > 0 else 0.0
            c_pct = (r["cases"] / tot_c * 100) if tot_c > 0 else 0.0
            h += f'<tr><td style="{td_l}">{r["label"]}</td>'
            h += f'<td style="{td}">{r["members"]:,}</td>'
            h += f'<td style="{td}">{r["cases"]:,.1f}</td>'
            h += f'<td style="{td}">{m_pct:.1f}</td>'
            h += f'<td style="{td}">{c_pct:.1f}</td></tr>'

        h += f'<tr><td style="{tot_l}">합계</td>'
        h += f'<td style="{tot_s}">{tot_m:,}</td>'
        h += f'<td style="{tot_s}">{tot_c:,.1f}</td>'
        h += f'<td style="{tot_s}">100.0</td><td style="{tot_s}">100.0</td></tr>'
        h += "</tbody></table>"
        return h

    with st.expander(f"전월 상세 ({prev_year}년 {prev_month}월) — ODS 재계산 기준"):
        st.markdown(render_detail_table(prev_detail_df, prev_year, prev_month), unsafe_allow_html=True)
        st.caption("⚠ ODS 재계산 기준: 결제정보 스냅샷(D_MM_MBER_SETLE_STRD_MT_INFO) 미이관으로 live 테이블 기준 재계산. 납입방식별 소폭 차이 가능 (합계 일치)")

    with st.expander(f"전년동월 상세 ({yoy_year}년 {sel_month}월) — ODS 재계산 기준"):
        st.markdown(render_detail_table(yoy_detail_df, yoy_year, sel_month), unsafe_allow_html=True)
        st.caption("⚠ ODS 재계산 기준: 결제정보 스냅샷(D_MM_MBER_SETLE_STRD_MT_INFO) 미이관으로 live 테이블 기준 재계산. 납입방식별 소폭 차이 가능 (합계 일치)")

    # ===== 1) 활동회원(건) 월별 비교 =====
    st.divider()
    st.subheader("1) 활동회원(건) 월별 비교")

    with st.spinner("월별 활동회원(건) 집계 중... (소요시간 약 3~10분)"):
        monthly_data = {}
        monthly_data_yoy = {}
        # 전년 12월 (1월 전월대비용)
        dec_prev_df = load_active_by_setle(sel_year - 1, 12, exclude_fake, use_latest_setle=True)
        dec_prev_df["SETLE_CD"] = dec_prev_df["SETLE_CD"].astype(str).str.strip()
        for m in range(1, sel_month + 1):
            monthly_data[m] = load_active_by_setle(sel_year, m, exclude_fake, use_latest_setle=True)
            monthly_data_yoy[m] = load_active_by_setle(yoy_year, m, exclude_fake, use_latest_setle=True)
        for m in monthly_data:
            monthly_data[m]["SETLE_CD"] = monthly_data[m]["SETLE_CD"].astype(str).str.strip()
            monthly_data_yoy[m]["SETLE_CD"] = monthly_data_yoy[m]["SETLE_CD"].astype(str).str.strip()

    def get_cases(data_dict, month, setle_cd):
        if month not in data_dict:
            return None
        df = data_dict[month]
        row = df[df["SETLE_CD"] == setle_cd]
        return float(row["ACTIVE_CASES"].values[0]) if len(row) > 0 else 0.0

    def get_total_cases(data_dict, month):
        if month not in data_dict:
            return None
        return float(data_dict[month]["ACTIVE_CASES"].sum())

    # HTML 렌더링 — 1번표와 동일한 색상 체계
    border = "border:1px solid #ddd;"
    border_thick_r = "border-right:2px solid #333;"
    hdr_s = f"background:#4472C4;color:#fff;text-align:center;padding:4px 6px;font-size:11px;font-weight:bold;{border}"
    cat_s = f"background:#5B9BD5;color:#fff;text-align:center;padding:4px 6px;font-size:11px;font-weight:bold;{border}{border_thick_r}"
    lbl_s = f"background:#F2F2F2;text-align:center;padding:4px 6px;font-size:11px;{border}"
    td_n = f"text-align:right;padding:4px 6px;font-size:11px;{border}"
    tot_row_s = f"background:#D9E2F3;text-align:right;padding:4px 6px;font-size:11px;font-weight:bold;{border}"
    tot_lbl_s = f"background:#D9E2F3;text-align:center;padding:4px 6px;font-size:11px;font-weight:bold;{border}"
    comp_s = f"background:#FFF2CC;text-align:right;padding:4px 6px;font-size:11px;{border}"
    comp_lbl_s = f"background:#FFF2CC;text-align:center;padding:4px 6px;font-size:11px;font-weight:bold;{border}"
    comp_sum_s = f"background:#D9D9D9;text-align:right;padding:4px 6px;font-size:11px;font-weight:bold;{border}"

    def fmt_v(v):
        if v is None:
            return "-"
        return f"{v:,.1f}"

    def fmt_diff(v):
        if v is None:
            return "-"
        return f"{v:,.1f}"

    num_methods = len(SETLE_ORDER)
    total_rows = num_methods + 3  # 납입방식 6개 + 사단법인계 + 전월대비 + 전년동월대비

    h = '<div style="overflow-x:auto;">'
    h += '<table style="border-collapse:collapse;white-space:nowrap;border:2px solid #333;">'

    # 헤더
    h += "<thead><tr>"
    h += f'<th style="{hdr_s}{border_thick_r}min-width:50px;">구분</th>'
    h += f'<th style="{hdr_s}{border_thick_r}min-width:70px;">납입방식</th>'
    for m in range(1, 13):
        h += f'<th style="{hdr_s}min-width:90px;">{m}월</th>'
    h += f'<th style="{hdr_s}{border_thick_r}min-width:100px;">합계</th>'
    h += "</tr></thead><tbody>"

    # 납입방식 행 (연도 셀 병합)
    for idx, code in enumerate(SETLE_ORDER):
        label = SETLE_CD_MAP[code]
        h += "<tr>"
        if idx == 0:
            h += f'<td rowspan="{num_methods}" style="{cat_s}vertical-align:middle;">{sel_year}년</td>'
        h += f'<td style="{lbl_s}">{label}</td>'
        row_sum = 0.0
        has_data = False
        for m in range(1, 13):
            v = get_cases(monthly_data, m, code)
            h += f'<td style="{td_n}">{fmt_v(v)}</td>'
            if v is not None:
                row_sum += v
                has_data = True
        h += f'<td style="{td_n}font-weight:bold;">{fmt_v(row_sum) if has_data else "-"}</td>'
        h += "</tr>"

    # 사단법인 계
    h += "<tr>"
    h += f'<td colspan="2" style="{tot_lbl_s}">사단법인 계</td>'
    grand_sum = 0.0
    has_grand = False
    for m in range(1, 13):
        v = get_total_cases(monthly_data, m)
        h += f'<td style="{tot_row_s}">{fmt_v(v)}</td>'
        if v is not None:
            grand_sum += v
            has_grand = True
    h += f'<td style="{tot_row_s}">{fmt_v(grand_sum) if has_grand else "-"}</td>'
    h += "</tr>"

    # 전월 대비
    h += "<tr>"
    h += f'<td colspan="2" style="{comp_lbl_s}">전월 대비</td>'
    mom_sum = 0.0
    has_mom = False
    for m in range(1, 13):
        cur_v = get_total_cases(monthly_data, m)
        if m == 1:
            prev_v = float(dec_prev_df["ACTIVE_CASES"].sum()) if not dec_prev_df.empty else None
        else:
            prev_v = get_total_cases(monthly_data, m - 1)
        if cur_v is not None and prev_v is not None:
            diff = cur_v - prev_v
            h += f'<td style="{comp_s}">{fmt_diff(diff)}</td>'
            mom_sum += diff
            has_mom = True
        else:
            h += f'<td style="{comp_s}">-</td>'
    h += f'<td style="{comp_sum_s}">{fmt_diff(mom_sum) if has_mom else "-"}</td>'
    h += "</tr>"

    # 전년도 동월 대비
    h += "<tr>"
    h += f'<td colspan="2" style="{comp_lbl_s}">전년도 동월 대비</td>'
    yoy_sum = 0.0
    has_yoy = False
    for m in range(1, 13):
        cur_v = get_total_cases(monthly_data, m)
        yoy_v = get_total_cases(monthly_data_yoy, m)
        if cur_v is not None and yoy_v is not None:
            diff = cur_v - yoy_v
            h += f'<td style="{comp_s}">{fmt_diff(diff)}</td>'
            yoy_sum += diff
            has_yoy = True
        else:
            h += f'<td style="{comp_s}">-</td>'
    h += f'<td style="{comp_sum_s}">{fmt_diff(yoy_sum) if has_yoy else "-"}</td>'
    h += "</tr>"

    h += "</tbody></table></div>"
    st.markdown(h, unsafe_allow_html=True)
    st.caption(
        f"출처: BRONZE_CRM — MSTR_ODS 원천 기반 F_MM_SPNSR_ACT 재현 "
        f"(사단법인, 납입방식별, {sel_year}년 1~{sel_month}월 · 최신 결제정보 기준)"
    )

else:
    st.warning("해당 기준월의 활동회원 데이터가 없습니다.")
