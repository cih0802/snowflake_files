# 주간중단보고 대시보드 — 사단법인 중단회원 주간 현황 (GOLD 레이어 기반)
# Co-authored with CoCo
import streamlit as st
import pandas as pd
import os
import calendar
import datetime
import html as html_lib
import altair as alt
import streamlit.components.v1 as stc

EXCLUDED_MEMBERS_2025 = [
    ("1846164", 202503),
    ("1860931", 202504),
    ("1860972", 202504),
    ("1721918", 202510),
    ("1945685", 202512),
    ("1894701", 202512),
]

KOREAN_HOLIDAYS = {
    2024: [datetime.date(2024,1,1),datetime.date(2024,2,9),datetime.date(2024,2,10),datetime.date(2024,2,11),datetime.date(2024,2,12),datetime.date(2024,3,1),datetime.date(2024,5,5),datetime.date(2024,5,6),datetime.date(2024,5,15),datetime.date(2024,6,6),datetime.date(2024,8,15),datetime.date(2024,9,16),datetime.date(2024,9,17),datetime.date(2024,9,18),datetime.date(2024,10,3),datetime.date(2024,10,9),datetime.date(2024,12,25)],
    2025: [datetime.date(2025,1,1),datetime.date(2025,1,28),datetime.date(2025,1,29),datetime.date(2025,1,30),datetime.date(2025,3,1),datetime.date(2025,3,3),datetime.date(2025,5,5),datetime.date(2025,5,6),datetime.date(2025,6,6),datetime.date(2025,8,15),datetime.date(2025,10,3),datetime.date(2025,10,5),datetime.date(2025,10,6),datetime.date(2025,10,7),datetime.date(2025,10,8),datetime.date(2025,10,9),datetime.date(2025,12,25)],
    2026: [datetime.date(2026,1,1),datetime.date(2026,2,16),datetime.date(2026,2,17),datetime.date(2026,2,18),datetime.date(2026,3,1),datetime.date(2026,3,2),datetime.date(2026,5,5),datetime.date(2026,5,24),datetime.date(2026,5,25),datetime.date(2026,6,6),datetime.date(2026,8,15),datetime.date(2026,8,17),datetime.date(2026,9,24),datetime.date(2026,9,25),datetime.date(2026,9,26),datetime.date(2026,10,3),datetime.date(2026,10,5),datetime.date(2026,10,9),datetime.date(2026,12,25)],
}

# =====================================================
# 기본 설정
# =====================================================
st.set_page_config(page_title="주간중단보고", layout="wide", initial_sidebar_state="expanded")

st.markdown("""<style>
    /* === 전체 배경 === */
    .stApp {background-color:#f0f2f6 !important;}
    .block-container {padding-top:0.6rem !important; padding-bottom:0 !important; max-width:100% !important;}

    /* === 카드 스타일 공통 === */
    .card {background:#fff; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.06); padding:16px 20px; margin-bottom:12px;}
    .card-header {font-size:14px; font-weight:700; color:#2C3E50; margin-bottom:10px; padding-bottom:6px; border-bottom:2px solid #27ae60;}

    /* === 제목 === */
    h1 {font-size:1.5rem !important; margin:0 0 0.2rem 0 !important; color:#2C3E50 !important; font-weight:700 !important;}
    h2 {font-size:1.1rem !important; margin:0.5rem 0 0.2rem 0 !important; border:none !important; padding:0 !important; color:#2C3E50 !important;}
    h3 {font-size:0.95rem !important; margin:0.3rem 0 0.1rem 0 !important; color:#34495E !important;}

    /* === 탭 — 포스트잇 스타일 (초록 배경) === */
    .stTabs {margin-top:8px !important;}
    .stTabs [data-baseweb="tab-list"] {
        gap:0; background:transparent !important; border-bottom:none !important;
        padding:0 !important; box-shadow:none !important; align-items:flex-end;
    }
    .stTabs [data-baseweb="tab"] {
        border-radius:8px 8px 0 0 !important; font-size:13px !important; font-weight:600 !important; 
        padding:10px 40px !important; min-width:180px !important;
        color:#fff !important; background:#85c9a8 !important; border:none !important;
        margin-right:3px !important; position:relative; top:1px;
        transition: all 0.15s ease;
    }
    .stTabs [data-baseweb="tab"]:hover {background:#5fb88a;}
    .stTabs [aria-selected="true"] {
        background:#1a9c6e !important; color:#fff !important;
        border-radius:8px 8px 0 0;
        box-shadow:0 -2px 6px rgba(0,0,0,0.08);
        font-weight:700;
    }
    .stTabs [data-baseweb="tab-highlight"] {display:none !important;}
    .stTabs [data-baseweb="tab-border"] {display:none !important;}
    .stTabs [data-baseweb="tab-panel"] {
        background:#fff; border-radius:0 8px 8px 8px;
        box-shadow:0 2px 8px rgba(0,0,0,0.05); padding:16px 20px;
    }

    /* === selectbox — 컴팩트 === */
    .stSelectbox label {font-size:0.75rem !important; color:#8e99a4 !important; font-weight:600 !important; text-transform:uppercase !important; letter-spacing:0.5px !important; margin-bottom:2px !important;}
    .stSelectbox > div > div {border-radius:8px !important; border:1px solid #e0e4e8 !important; background:#fff !important;}
    .stSelectbox > div > div:hover {border-color:#1a9c6e !important;}

    /* === 기타 === */
    .stCaption {font-size:0.75rem !important; margin-top:0 !important; padding-top:0 !important; color:#95a5a6 !important;}
    div[data-testid="stVerticalBlock"] > div {gap:0.2rem !important;}
    .stMarkdown p {margin-bottom:0.15rem !important;}
    [data-testid="stExpander"] summary {font-size:0.75rem !important; color:#888 !important;}

    /* === 테이블 === */
    table {font-size:13px !important; border-radius:0; overflow:hidden;}
    /* 표 헤더 — 기본값만 지정, 표별 인라인 색·선이 우선 (하단 데이터 표는 #A9C1DD 헤더 + 1px 회색 격자) */
    [data-testid="stMarkdownContainer"] table th {
        background:#F4F6F8; color:#2C3E50 !important; font-weight:700 !important;
        border-bottom:1px solid #D5DCE4;
        padding:7px 6px !important;
    }

    /* === 섹션 헤더 === */
    .section-header {background:none; color:#2C3E50; padding:0 0 6px 0; font-size:20px; font-weight:800; border-bottom:2px solid #2C3E50; border-radius:0; margin:18px 0 12px 0; letter-spacing:-0.2px;}
    .section-header span {color:#7f8c8d !important; opacity:1 !important;}
    .sub-header {font-size:14px; font-weight:700; color:#34495E; margin:14px 0 6px 0; padding:0;}
    .chart-header {background:none; color:#34495E; padding:0; font-size:14px; font-weight:700; border-radius:0; margin:12px 0 6px 0;}
</style>""", unsafe_allow_html=True)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

# =====================================================
# 상단 조회조건 (가로 배치)
# =====================================================

def calc_week_ranges(y, m):
    first_date = datetime.date(y, m, 1)
    _, days_in_month = calendar.monthrange(y, m)
    last_date = datetime.date(y, m, days_in_month)
    days_to_sunday = (6 - first_date.weekday()) % 7
    if days_to_sunday == 0 and first_date.weekday() != 6:
        days_to_sunday = 7
    first_sun = first_date + datetime.timedelta(days=days_to_sunday)
    if first_sun > last_date:
        first_sun = last_date
    weeks = [(first_date, first_sun)]
    current_start = first_sun + datetime.timedelta(days=1)
    while current_start <= last_date:
        days_to_next_sun = (6 - current_start.weekday()) % 7
        if days_to_next_sun == 0:
            days_to_next_sun = 7
        current_end = current_start + datetime.timedelta(days=days_to_next_sun)
        if current_end > last_date:
            current_end = last_date
        weeks.append((current_start, current_end))
        current_start = current_end + datetime.timedelta(days=1)
    if len(weeks) > 5:
        weeks[4] = (weeks[4][0], weeks[-1][1])
        weeks = weeks[:5]
    return weeks

filter_col1, filter_col2, filter_col3, filter_col4 = st.columns([1, 1, 1, 4])
with filter_col1:
    year = st.selectbox("조회년도", [2026, 2025, 2024], index=0)
with filter_col2:
    month_sel = st.selectbox("조회월", ["선택하세요"] + list(range(1, 13)), index=0)
# 필터 행 바로 아래 안내 (컬럼 생성 직후 배치 → 조회주차 칸까지 포함한 행 아래에 표시)
st.markdown('<div style="font-size:15px;color:#7f8c8d;margin:-6px 0 8px 0;">'
            '※ 데이터 조회량에 따라 보고서 로딩에 시간이 소요될 수 있습니다.</div>', unsafe_allow_html=True)

if month_sel == "선택하세요":
    st.info("조회월과 조회주차를 선택하면 대시보드가 표시됩니다.")
    st.stop()

month = month_sel
week_ranges = calc_week_ranges(year, month)
total_weeks = len(week_ranges)
week_options = list(range(1, total_weeks + 1))

with filter_col3:
    week_sel = st.selectbox("조회주차", ["선택하세요"] + week_options, index=0)

if week_sel == "선택하세요":
    st.info("조회주차를 선택하면 대시보드가 표시됩니다.")
    st.stop()

week_no = week_sel

w_start, w_end = week_ranges[week_no - 1]

# 3개년 동월 미니 달력 — 조회주차 기간 강조 (필터 오른쪽 공란)
def render_mini_calendar(cy, cm, wk_no, is_main):
    y_ranges = calc_week_ranges(cy, cm)
    rng = y_ranges[wk_no - 1] if wk_no <= len(y_ranges) else None
    hl_bg = "#1a9c6e" if is_main else "#5dade2"
    cell = "width:20px;height:16px;text-align:center;font-size:10px;padding:0;"
    h = (f'<div style="background:#fff;border:1px solid {"#1a9c6e" if is_main else "#dfe4ea"};border-radius:8px;'
         f'padding:4px 6px;box-shadow:0 1px 3px rgba(0,0,0,0.06);">')
    _period = f'{rng[0].month}/{rng[0].day}~{rng[1].month}/{rng[1].day}' if rng else '해당 주차 없음'
    h += (f'<div style="font-size:11px;font-weight:700;color:#2C3E50;text-align:center;margin-bottom:2px;">'
          f'{cy}년 {cm}월 <span style="font-weight:600;color:{hl_bg};">({_period})</span></div>')
    h += '<table style="border-collapse:collapse;margin:0 auto;font-size:10px !important;border-radius:0;">'
    h += '<tr>' + ''.join(
        f'<th style="{cell}background:transparent !important;color:{"#e74c3c" if d == "일" else "#8e99a4"} !important;font-weight:600;border:none !important;">{d}</th>'
        for d in ["월", "화", "수", "목", "금", "토", "일"]) + '</tr>'
    for wk in calendar.Calendar(firstweekday=0).monthdatescalendar(cy, cm):
        h += '<tr>'
        for d in wk:
            if d.month != cm:
                h += f'<td style="{cell}border:none;"></td>'
                continue
            in_rng = rng is not None and rng[0] <= d <= rng[1]
            if in_rng:
                sty = f"background:{hl_bg};color:#fff;font-weight:700;"
            else:
                sty = f"color:{'#e74c3c' if d.weekday() == 6 else '#34495E'};"
            h += f'<td style="{cell}{sty}border:none;">{d.day}</td>'
        h += '</tr>'
    h += '</table></div>'
    return h

with filter_col4:
    _cal_html = ('<div style="text-align:right;"><div style="display:inline-block;text-align:left;">'
                 '<div style="display:flex;gap:10px;align-items:flex-start;">')
    for _cy in [year - 2, year - 1, year]:
        _cal_html += render_mini_calendar(_cy, month, week_no, _cy == year)
    _cal_html += '</div>'
    # 폭 0 + min-width 100% → 달력 줄 너비에 맞춰 줄바꿈
    _cal_html += ('<div style="width:0;min-width:100%;box-sizing:border-box;margin-top:5px;padding:4px 8px;'
                  'background:#F7F9FC;border:1px solid #E1E7EF;border-radius:6px;'
                  'font-size:10.5px;color:#7f8c8d;line-height:1.6;display:flex;align-items:flex-start;gap:6px;">'
                  '<b style="color:#2C3E50;white-space:nowrap;">🗓 주차산정규칙 —</b>'
                  '<div style="display:flex;flex-wrap:wrap;column-gap:10px;">'
                  '<span style="white-space:nowrap;"><b>1주차</b> 매월 1일~첫 번째 일요일</span>'
                  '<span style="white-space:nowrap;"><b>2주차~</b> 월요일~일요일</span>'
                  '<span style="white-space:nowrap;"><b>마지막 주차</b> 월말일까지</span>'
                  '<span style="white-space:nowrap;"><b>익월 1주차</b> 매월 1일부터 새로 시작</span>'
                  '</div></div>')
    _cal_html += '</div></div>'
    st.markdown(_cal_html, unsafe_allow_html=True)

# =====================================================
# 제목
# =====================================================
st.markdown(f'<div style="font-size:38px;font-weight:800;color:#2C3E50;letter-spacing:-0.5px;'
            f'line-height:1.3;margin:22px 0 10px 0;padding-bottom:8px;border-bottom:3px solid #2C3E50;">'
            f'{year}년 {month}월 {week_no}주차 주간중단보고</div>', unsafe_allow_html=True)
_notice_items = [
    ("범위", "사단법인 중단회원 현황으로, 통합회원 중 <b>사단법인 후원사업 회원의 중단 명·건은 미포함</b>됩니다."),
    ("기준", "CRM 현황 기준으로 회원 활동에 따라 움직이는 수치이며, <b>실제 월별 마감수치와 상이</b>합니다."),
    ("중단율", "주간 중단율은 개발(전월 활동 회원 건 포함) 대비 중단 비율로, 기준 수치는 매주 회원 활동에 따라 변동되는 "
             "<b style=\"color:#c0392b;\">유동적인 값</b>임을 참고하시기 바랍니다."),
]
if week_no == 1:
    _notice_items.append(("미납중단", "신규회원의 미납중단은 <b>가입 후 5개월 미납 시 자동중단</b>되는 것으로 <b>6월부터 발생</b>합니다."))

_notice_html = ('<div style="background:#F7F9FC;border:1px solid #E1E7EF;border-left:5px solid #2C3E50;'
                'border-radius:8px;padding:14px 18px;margin:6px 0 10px 0;">'
                '<div style="font-size:14px;font-weight:700;color:#2C3E50;margin-bottom:8px;">📌 보고서 참고사항</div>')
for _tag, _txt in _notice_items:
    _notice_html += ('<div style="display:flex;align-items:flex-start;gap:10px;margin:5px 0;font-size:14px;'
                     'line-height:1.6;color:#34495E;">'
                     f'<span style="flex:0 0 64px;text-align:center;background:#2C3E50;color:#fff;font-size:12px;'
                     f'font-weight:600;border-radius:4px;padding:2px 0;margin-top:2px;">{_tag}</span>'
                     f'<span>{_txt}</span></div>')
_notice_html += '</div>'
st.markdown(_notice_html, unsafe_allow_html=True)
st.markdown('<div style="height:12px"></div>', unsafe_allow_html=True)

# =====================================================
# 공통 변수
# =====================================================
year1 = year
year2 = year - 1
year3 = year - 2
all_years = [year1, year2, year3]
y1, y2, y3 = year1, year2, year3

dscntc_from = w_start.strftime("%Y%m%d")
dscntc_to = w_end.strftime("%Y%m%d")

def get_same_week_range(target_year, ref_month, ref_week_no):
    y_ranges = calc_week_ranges(target_year, ref_month)
    if ref_week_no <= len(y_ranges):
        return y_ranges[ref_week_no - 1]
    else:
        return y_ranges[-1]

# =====================================================
# SQL 조각
# =====================================================
WEEK_SQL = """LEAST(
    CASE
        WHEN DAY(CANCEL_DT) <= (CASE WHEN DAYOFWEEKISO(DATE_TRUNC('MONTH', CANCEL_DT)) = 7 THEN 1
                                     ELSE 8 - DAYOFWEEKISO(DATE_TRUNC('MONTH', CANCEL_DT)) END)
        THEN 1
        ELSE 1 + CEIL((DAY(CANCEL_DT) - (CASE WHEN DAYOFWEEKISO(DATE_TRUNC('MONTH', CANCEL_DT)) = 7 THEN 1
                                               ELSE 8 - DAYOFWEEKISO(DATE_TRUNC('MONTH', CANCEL_DT)) END)) / 7.0)::INT
    END,
    5)"""

WEEK_SQL_OCCUR = """LEAST(
    CASE
        WHEN DAY(TO_DATE(OCCRRNC_DE, 'YYYYMMDD')) <= (CASE WHEN DAYOFWEEKISO(DATE_TRUNC('MONTH', TO_DATE(OCCRRNC_DE, 'YYYYMMDD'))) = 7 THEN 1
                                     ELSE 8 - DAYOFWEEKISO(DATE_TRUNC('MONTH', TO_DATE(OCCRRNC_DE, 'YYYYMMDD'))) END)
        THEN 1
        ELSE 1 + CEIL((DAY(TO_DATE(OCCRRNC_DE, 'YYYYMMDD')) - (CASE WHEN DAYOFWEEKISO(DATE_TRUNC('MONTH', TO_DATE(OCCRRNC_DE, 'YYYYMMDD'))) = 7 THEN 1
                                               ELSE 8 - DAYOFWEEKISO(DATE_TRUNC('MONTH', TO_DATE(OCCRRNC_DE, 'YYYYMMDD'))) END)) / 7.0)::INT
    END,
    5)"""

# =====================================================
# 데이터 로드 함수
# =====================================================
@st.cache_data(ttl=600)
def load_weekly_stop(years, month_val, rsn_filter=""):
    years_str = ",".join(str(y) for y in years)
    month_str = f"{month_val:02d}"
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    sql = f"""
    WITH
    CTE_BASE AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
               TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD') AS CANCEL_DT,
               YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')) AS CANCEL_YEAR
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
        WHERE SUBSTRING(A.SPNSR_DSCNTC_DE, 5, 2) = '{month_str}'
          AND LEFT(A.SPNSR_DSCNTC_DE, 4) IN ({years_str})
          AND B.MBER_STAT_CD = '12'
          AND B.CPR_DIV_CD = 'I'
          AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
               OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
          {rsn_clause}
    ),
    CTE_WITH_WEEK AS (
        SELECT *, {WEEK_SQL} AS WEEK_OF_MONTH FROM CTE_BASE
    ),
    CTE_TBL1 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE, CANCEL_DT, CANCEL_YEAR, WEEK_OF_MONTH
        FROM (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CANCEL_YEAR, WEEK_OF_MONTH
                                          ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM CTE_WITH_WEEK
        ) WHERE RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y'
          AND SUBSTRING(A.SPNSR_DSCNTC_DE, 5, 2) = '{month_str}'
          AND LEFT(A.SPNSR_DSCNTC_DE, 4) IN ({years_str})
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    )
    SELECT T1.CANCEL_YEAR AS YEAR, T1.WEEK_OF_MONTH,
           ROUND(SUM(COALESCE(T2.SPNSR_AMT, 0)) / 10000.0, 1) AS STOP_CNT
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    GROUP BY T1.CANCEL_YEAR, T1.WEEK_OF_MONTH
    ORDER BY T1.CANCEL_YEAR, T1.WEEK_OF_MONTH
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_dev_weekly(years, month_val):
    years_str = ",".join(str(y) for y in years)
    month_str = f"{month_val:02d}"
    sql = f"""
    WITH new_rejoin_base AS (
        SELECT A.OCCRRNC_DE, SUM(A.SPNSR_AMT) OVER (
                PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)) AS MAMT,
            A.SPNSR_NO, A.SPNSR_BSNS_NO, A.SER_NO, A.MBER_NO, A.SPNSR_BSNS_ID, A.SPNSR_AMT, A.DVLP_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
            ON A.SPNSR_NO = B.SPNSR_NO AND A.SPNSR_BSNS_NO = B.SPNSR_BSNS_NO
            AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231') > LEFT(A.OCCRRNC_DE, 6) || '31'
        WHERE SUBSTRING(A.OCCRRNC_DE, 5, 2) = '{month_str}'
          AND LEFT(A.OCCRRNC_DE, 4) IN ({years_str}) AND A.DVLP_DIV_CD IN ('1', '4')
    ),
    new_rejoin AS (
        SELECT OCCRRNC_DE, SPNSR_NO, SPNSR_BSNS_NO, SER_NO, MBER_NO, SPNSR_BSNS_ID, SPNSR_AMT
        FROM new_rejoin_base WHERE MAMT > 0
    ),
    change_base AS (
        SELECT A.OCCRRNC_DE,
            SUM(CASE WHEN A.DVLP_DIV_CD IN ('2','3') THEN A.SPNSR_AMT ELSE 0 END)
                OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)) AS SAMT,
            SUM(A.SPNSR_AMT) OVER (PARTITION BY A.MBER_NO, LEFT(A.OCCRRNC_DE, 6)) AS MAMT,
            A.SPNSR_NO, A.SPNSR_BSNS_NO, A.SER_NO, A.MBER_NO, A.SPNSR_BSNS_ID, A.SPNSR_AMT, A.DVLP_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        WHERE SUBSTRING(A.OCCRRNC_DE, 5, 2) = '{month_str}'
          AND LEFT(A.OCCRRNC_DE, 4) IN ({years_str}) AND A.DVLP_DIV_CD IN ('2', '3', '5')
    ),
    change_member AS (
        SELECT SUM(CASE WHEN C.DVLP_DIV_CD = '3' THEN C.SPNSR_AMT ELSE 0 END)
                OVER (PARTITION BY C.MBER_NO, LEFT(C.OCCRRNC_DE, 6)) AS DAMT, C.*
        FROM change_base C WHERE C.MAMT > 0
          AND ((C.SAMT > 0 AND C.DVLP_DIV_CD = '2') OR (C.SAMT < 0 AND C.DVLP_DIV_CD = '3'))
    ),
    change_running AS (
        SELECT SUM(C.SAMT) OVER (
                PARTITION BY C.MBER_NO, LEFT(C.OCCRRNC_DE, 6) ORDER BY C.OCCRRNC_DE, C.SER_NO) AS AAMT, C.*
        FROM change_member C WHERE C.DVLP_DIV_CD = '2'
    ),
    change_alloc AS (
        SELECT ROW_NUMBER() OVER (
                PARTITION BY LEFT(C.OCCRRNC_DE, 6), C.SPNSR_NO, C.SPNSR_BSNS_NO ORDER BY C.SER_NO) AS RNUM,
            CASE WHEN C.MAMT <= C.SAMT AND C.AAMT + C.DAMT <= C.MAMT THEN C.AAMT + C.DAMT
                 WHEN C.MAMT > C.SAMT AND C.AAMT + C.DAMT <= C.SAMT THEN C.AAMT + C.DAMT
                 WHEN C.MAMT <= C.SAMT THEN C.MAMT ELSE C.SAMT END AS RAMT, C.*
        FROM change_running C WHERE C.AAMT - ABS(C.DAMT) > 0
    ),
    increase AS (
        SELECT OCCRRNC_DE, SPNSR_NO, SPNSR_BSNS_NO, SER_NO, MBER_NO, SPNSR_BSNS_ID, RAMT AS SPNSR_AMT
        FROM change_alloc WHERE RNUM = 1
    ),
    transformed AS (SELECT * FROM new_rejoin UNION ALL SELECT * FROM increase)
    SELECT CAST(LEFT(T.OCCRRNC_DE, 4) AS INTEGER) AS YEAR,
        {WEEK_SQL_OCCUR.replace('OCCRRNC_DE', 'T.OCCRRNC_DE')} AS WEEK_OF_MONTH,
        ROUND(SUM(T.SPNSR_AMT) / 10000.0, 1) AS DEV_CNT
    FROM transformed T
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO BIZ ON T.SPNSR_BSNS_ID = BIZ.SPNSR_BSNS_ID
    WHERE COALESCE(CASE BIZ.CPR_DIV_CD WHEN '1' THEN 'I' WHEN '2' THEN 'S' ELSE BIZ.CPR_DIV_CD END, '0') = 'I'
    GROUP BY 1, 2 ORDER BY 1, 2
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_prev_month_active(years, month_val):
    rows = []
    for y in years:
        if month_val > 1:
            prev_m = month_val - 1
            _, prev_last_day = calendar.monthrange(y, prev_m)
            prev_month_end = f"{y}{prev_m:02d}{prev_last_day:02d}"
        else:
            prev_month_end = f"{y - 1}1231"
        sql = f"""
        WITH
        BUSINESS_DIM AS (
            SELECT SPNSR_BSNS_ID, CASE WHEN CPR_DIV_CD = '1' THEN 'I' WHEN CPR_DIV_CD = '2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
            FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
        ),
        HAS_LIVE_SPONSOR AS (
            SELECT DISTINCT S.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO = B.SPNSR_NO
            WHERE TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD') <= '{prev_month_end}'
              AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231') > '{prev_month_end}'
        ),
        ACTIVE_HISTORY AS (
            SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
                   SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
                   ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A WHERE A.OCCRRNC_DE <= '{prev_month_end}'
        ),
        ACTIVE_FACT AS (
            SELECT A.MBER_NO, BD.CPR_DIV_CD, A.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT
            FROM ACTIVE_HISTORY A
            JOIN HAS_LIVE_SPONSOR HL ON A.MBER_NO = HL.MBER_NO
            JOIN BUSINESS_DIM BD ON A.SPNSR_BSNS_ID = BD.SPNSR_BSNS_ID
            WHERE A.RNUM = 1 AND A.SUM_AMT > 0
        )
        SELECT {y} AS YEAR, ROUND(SUM(SPNSR_AMT_CNT), 1) AS ACTIVE_CNT FROM ACTIVE_FACT WHERE CPR_DIV_CD = 'I'
        """
        rows.append(conn.query(sql))
    return pd.concat(rows, ignore_index=True)


# =====================================================
# KPI 부서 필터 — CRM tabStatOrg 실적 조직도(VIRTUAL_YN='Y') 기준
#   부서 조회: DEPT_SQL 하나로 전체 계층·이름 검색 공용 (원천 TM_CM_DEPT_INFO, 조회 전용)
#   dept_sel: "" = 부서 필터 없음(전사) / "코드,코드,..." = 선택(하위 포함 시 확장) DEPT_ID 집합
#   보고서 귀속 컬럼: 후원 실적부서 ACMSLT_DEPT_CD (기존 사용 컬럼 유지 — DW→ODS 귀속 규칙 미검증)
# =====================================================
DEPT_SQL = """
WITH RECURSIVE
PARAMS AS (
    SELECT 'Y'::VARCHAR AS VIRTUAL_YN, ?::VARCHAR AS SEARCH_DEPT_NM
),
DEPT_BASE AS (
    SELECT DEPT_ID, UPPER_DEPT_ID, DEPT_NM, SORT_ORDR, USE_YN, ACMSLT_DEPT_YN, ACMSLT_UPPER_DEPT_ID
    FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO
),
DEPT_CTE (
    DEPT_ID, UPPER_DEPT_ID, DEPT_NM, DEPT_ORDER, DEPT_PATH, SORT_ORDR, USE_YN, LVL, ENABLE,
    ACMSLT_DEPT_YN, ACMSLT_UPPER_DEPT_ID, DEPT_ID_PATH
) AS (
    SELECT D.DEPT_ID, D.UPPER_DEPT_ID, D.DEPT_NM,
           CAST(D.DEPT_ID AS VARCHAR) AS DEPT_ORDER,
           CAST(D.DEPT_NM AS VARCHAR) AS DEPT_PATH,
           D.SORT_ORDR, D.USE_YN, 1 AS LVL, 1 AS ENABLE, D.ACMSLT_DEPT_YN, D.ACMSLT_UPPER_DEPT_ID,
           CAST('|' || D.DEPT_ID || '|' AS VARCHAR) AS DEPT_ID_PATH
    FROM DEPT_BASE D
    WHERE D.UPPER_DEPT_ID = 'ZV000000' AND D.USE_YN = 'Y'
    UNION ALL
    SELECT D.DEPT_ID, D.UPPER_DEPT_ID, D.DEPT_NM,
           CAST(C.DEPT_ORDER || ' > ' || LEFT(D.DEPT_ID, 8) AS VARCHAR),
           CAST(CASE WHEN RTRIM(C.DEPT_PATH) = '' THEN D.DEPT_NM ELSE C.DEPT_PATH || ' > ' || D.DEPT_NM END AS VARCHAR),
           D.SORT_ORDR, D.USE_YN, C.LVL + 1, 1, D.ACMSLT_DEPT_YN, D.ACMSLT_UPPER_DEPT_ID,
           CAST(C.DEPT_ID_PATH || D.DEPT_ID || '|' AS VARCHAR)
    FROM DEPT_CTE C
    JOIN DEPT_BASE D ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
    WHERE D.DEPT_ID <> 'ZC000029'
      AND POSITION('|' || D.DEPT_ID || '|' IN C.DEPT_ID_PATH) = 0
)
SELECT 0 AS CHK, C.DEPT_ID, C.UPPER_DEPT_ID, U.DEPT_NM AS UPPER_DEPT_NM, C.DEPT_NM, C.DEPT_PATH, C.DEPT_ORDER,
       C.SORT_ORDR, C.USE_YN, C.LVL, C.ENABLE, C.ACMSLT_DEPT_YN, C.ACMSLT_UPPER_DEPT_ID,
       A.DEPT_NM AS ACMSLT_UPPER_DEPT_NM, C.ACMSLT_UPPER_DEPT_ID AS TREE_PARENT_ID, C.DEPT_ID_PATH, P.VIRTUAL_YN
FROM DEPT_CTE C
CROSS JOIN PARAMS P
LEFT JOIN DEPT_BASE U ON C.UPPER_DEPT_ID = U.DEPT_ID
LEFT JOIN DEPT_BASE A ON C.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
WHERE NULLIF(P.SEARCH_DEPT_NM, '') IS NULL
   OR (C.DEPT_NM ILIKE '%' || P.SEARCH_DEPT_NM || '%' AND C.LVL = 5)
ORDER BY C.DEPT_ORDER
"""


@st.cache_data(ttl=3600)
def load_performance_departments(search_name=""):
    """CRM 실적 조직도 조회 — 검색어 없음: 전체 계층 / 검색어: 전체 계층 구성 후 이름 일치 AND LVL=5 (? 바인딩)"""
    return conn.session().sql(DEPT_SQL, params=[search_name or ""]).to_pandas()


def expand_dept_codes(selected_ids, include_children):
    """선택 DEPT_ID → 필터 코드 집합(중복 제거). 하위 포함은 검색어 없는 전체 계층의 DEPT_ID_PATH 로 확장(자기 자신 포함)"""
    sel = list(dict.fromkeys(selected_ids))
    if not include_children:
        return sel
    full = load_performance_departments("")
    paths = full["DEPT_ID_PATH"].astype(str)
    hit = paths.apply(lambda p: any(f"|{c}|" in p for c in sel))
    return list(dict.fromkeys(sel + full.loc[hit, "DEPT_ID"].tolist()))


def _dept_cond(col, dept_sel):
    """귀속 컬럼 col 에 대한 단일 코드 집합 조건 — 선택 없음이면 조건 없음 (코드는 조직도 조회 결과 값만 사용)"""
    if not dept_sel:
        return ""
    codes = ",".join("'" + c.replace("'", "''") + "'" for c in dict.fromkeys(dept_sel.split(",")))
    return f"AND {col} IN ({codes})"


@st.cache_data(ttl=600)
def load_stop_by_dept_mapping(dt_from, dt_to):
    """진단용: 주간 사단 중단건(load_dscntc_detail 과 같은 금액 기준)을 실적부서 코드별로 — 조직도 미매핑 확인"""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, B.ACMSLT_DEPT_CD, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY 1, 2, 3
    )
    SELECT T2.ACMSLT_DEPT_CD AS DEPT_CD, COUNT(DISTINCT T1.MBER_NO) AS MBER_CNT,
           ROUND(SUM(T2.SPNSR_AMT) / 10000.0, 1) AS STOP_CNT
    FROM CTE_TBL1 T1
    JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    GROUP BY 1
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_dscntc_detail(sel_year, dt_from, dt_to, rsn_filter="", rsn_exclude="", dept_sel=""):
    base_year = str(sel_year)
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    rsn_exclude_clause = f"AND A.DSCNTC_RSN_CD NOT IN ({rsn_exclude})" if rsn_exclude else ""
    same_month_clause = """AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))"""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12'
              {same_month_clause}
              {rsn_clause}
              {rsn_exclude_clause}
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE, SUM(SPNSR_AMT) AS SPNSR_AMT FROM (
            SELECT A.SPNSR_AMT, A.SPNSR_DSCNTC_DE, B.MBER_NO
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
            WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND A.SPNSR_DSCNTC_RSN_CD = '7'
              {_dept_cond('B.ACMSLT_DEPT_CD', dept_sel)}
        ) A GROUP BY MBER_NO, SPNSR_DSCNTC_DE
    ),
    DSCNTC_DETAIL AS (
        SELECT T1.MBER_NO, COALESCE(T2.SPNSR_AMT, 0) AS SPNSR_AMT,
            CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING
        FROM CTE_TBL1 T1
        LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
        WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
          {"AND T2.MBER_NO IS NOT NULL" if dept_sel else ""}
    )
    SELECT NEW_EXISTING, COUNT(DISTINCT MBER_NO) AS DSCNTC_MEMBERS,
           ROUND(SUM(SPNSR_AMT) / 10000.0, 1) AS DSCNTC_CNT
    FROM DSCNTC_DETAIL GROUP BY NEW_EXISTING ORDER BY NEW_EXISTING DESC
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_dscntc_detail_history(sel_year, dt_from, dt_to, rsn_filter="", rsn_exclude=""):
    """중단 이력 기준 집계 — MBER_STAT_CD 필터 없이 중단 시점 이력만으로 집계"""
    base_year = str(sel_year)
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    rsn_exclude_clause = f"AND A.DSCNTC_RSN_CD NOT IN ({rsn_exclude})" if rsn_exclude else ""
    same_month_clause = """AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))"""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.CPR_DIV_CD = 'I'
              {same_month_clause}
              {rsn_clause}
              {rsn_exclude_clause}
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE, SUM(SPNSR_AMT) AS SPNSR_AMT FROM (
            SELECT A.SPNSR_AMT, A.SPNSR_DSCNTC_DE, B.MBER_NO
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
            WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND A.SPNSR_DSCNTC_RSN_CD = '7'
        ) A GROUP BY MBER_NO, SPNSR_DSCNTC_DE
    ),
    DSCNTC_DETAIL AS (
        SELECT T1.MBER_NO, COALESCE(T2.SPNSR_AMT, 0) AS SPNSR_AMT,
            CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING
        FROM CTE_TBL1 T1
        LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
        WHERE C.CPR_DIV_CD = 'I'
    )
    SELECT NEW_EXISTING, COUNT(DISTINCT MBER_NO) AS DSCNTC_MEMBERS,
           ROUND(SUM(SPNSR_AMT) / 10000.0, 1) AS DSCNTC_CNT
    FROM DSCNTC_DETAIL GROUP BY NEW_EXISTING ORDER BY NEW_EXISTING DESC
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_dscntc_detail_list(sel_year, dt_from, dt_to, rsn_filter="", rsn_exclude=""):
    """중단회원 개별 리스트 조회 (다운로드용)"""
    base_year = str(sel_year)
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    rsn_exclude_clause = f"AND A.DSCNTC_RSN_CD NOT IN ({rsn_exclude})" if rsn_exclude else ""
    same_month_clause = """AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))"""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE, DSCNTC_RSN_CD FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE, A.DSCNTC_RSN_CD,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12'
              {same_month_clause}
              {rsn_clause}
              {rsn_exclude_clause}
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE, SUM(SPNSR_AMT) AS SPNSR_AMT, COUNT(*) AS SPNSR_CNT FROM (
            SELECT A.SPNSR_AMT, A.SPNSR_DSCNTC_DE, B.MBER_NO
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
            WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND A.SPNSR_DSCNTC_RSN_CD = '7'
        ) A GROUP BY MBER_NO, SPNSR_DSCNTC_DE
    )
    SELECT T1.MBER_NO AS "회원번호",
           TO_CHAR(C.FRST_REGIST_DT, 'YYYY-MM-DD') AS "가입일자",
           T1.SPNSR_DSCNTC_DE AS "중단일자",
           COALESCE(R.DTL_CD_NM, T1.DSCNTC_RSN_CD) AS "중단사유",
           CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규회원' ELSE '기존회원' END AS "회원구분",
           COALESCE(T2.SPNSR_CNT, 0) AS "중단건수",
           COALESCE(T2.SPNSR_AMT, 0) AS "중단금액",
           COALESCE(D.CMPGN_NM, C.CMPGN_CD) AS "가입캠페인"
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
    LEFT JOIN GN_DW.SILVER.CRM_CODE R ON T1.DSCNTC_RSN_CD = R.DTL_CD_ID AND R.CD_ID = 'MM005'
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D ON C.CMPGN_CD = D.CMPGN_CD
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    ORDER BY T1.SPNSR_DSCNTC_DE, T1.MBER_NO
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_monthly_unpaid_by_week(years, target_week_no):
    years_str = ",".join(str(y) for y in years)
    sql = f"""
    WITH
    CTE_BASE AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
               TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD') AS CANCEL_DT,
               YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')) AS CANCEL_YEAR,
               MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')) AS CANCEL_MONTH
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
        WHERE LEFT(A.SPNSR_DSCNTC_DE, 4) IN ({years_str})
          AND B.MBER_STAT_CD = '12'
          AND B.CPR_DIV_CD = 'I'
          AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
               OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
          AND A.DSCNTC_RSN_CD IN ('14','16')
    ),
    CTE_WITH_WEEK AS (
        SELECT *, {WEEK_SQL} AS WEEK_OF_MONTH FROM CTE_BASE
    ),
    CTE_TBL1 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE, CANCEL_DT, CANCEL_YEAR, CANCEL_MONTH, WEEK_OF_MONTH
        FROM (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CANCEL_YEAR, CANCEL_MONTH, WEEK_OF_MONTH
                                          ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM CTE_WITH_WEEK
        ) WHERE RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y'
          AND LEFT(A.SPNSR_DSCNTC_DE, 4) IN ({years_str})
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    )
    SELECT T1.CANCEL_YEAR AS YEAR, T1.CANCEL_MONTH AS MONTH,
           ROUND(SUM(COALESCE(T2.SPNSR_AMT, 0)) / 10000.0, 1) AS STOP_CNT
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    WHERE T1.WEEK_OF_MONTH = {target_week_no}
    GROUP BY T1.CANCEL_YEAR, T1.CANCEL_MONTH
    ORDER BY T1.CANCEL_YEAR, T1.CANCEL_MONTH
    """
    return conn.query(sql)


def _dev_transformed_cte(years_str, month_str):
    """개발건(신규/재가입 + 증액) 산출 CTE — 마지막 CTE명: transformed"""
    return f"""new_rejoin_base AS (
        SELECT A.OCCRRNC_DE, SUM(A.SPNSR_AMT) OVER (
                PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)) AS MAMT,
            A.SPNSR_NO, A.SPNSR_BSNS_NO, A.SER_NO, A.MBER_NO, A.SPNSR_BSNS_ID, A.SPNSR_AMT, A.DVLP_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
            ON A.SPNSR_NO = B.SPNSR_NO AND A.SPNSR_BSNS_NO = B.SPNSR_BSNS_NO
            AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231') > LEFT(A.OCCRRNC_DE, 6) || '31'
        WHERE SUBSTRING(A.OCCRRNC_DE, 5, 2) = '{month_str}'
          AND LEFT(A.OCCRRNC_DE, 4) IN ({years_str}) AND A.DVLP_DIV_CD IN ('1', '4')
    ),
    new_rejoin AS (
        SELECT OCCRRNC_DE, SPNSR_NO, SPNSR_BSNS_NO, SER_NO, MBER_NO, SPNSR_BSNS_ID, SPNSR_AMT, DVLP_DIV_CD
        FROM new_rejoin_base WHERE MAMT > 0
    ),
    change_base AS (
        SELECT A.OCCRRNC_DE,
            SUM(CASE WHEN A.DVLP_DIV_CD IN ('2','3') THEN A.SPNSR_AMT ELSE 0 END)
                OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)) AS SAMT,
            SUM(A.SPNSR_AMT) OVER (PARTITION BY A.MBER_NO, LEFT(A.OCCRRNC_DE, 6)) AS MAMT,
            A.SPNSR_NO, A.SPNSR_BSNS_NO, A.SER_NO, A.MBER_NO, A.SPNSR_BSNS_ID, A.SPNSR_AMT, A.DVLP_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        WHERE SUBSTRING(A.OCCRRNC_DE, 5, 2) = '{month_str}'
          AND LEFT(A.OCCRRNC_DE, 4) IN ({years_str}) AND A.DVLP_DIV_CD IN ('2', '3', '5')
    ),
    change_member AS (
        SELECT SUM(CASE WHEN C.DVLP_DIV_CD = '3' THEN C.SPNSR_AMT ELSE 0 END)
                OVER (PARTITION BY C.MBER_NO, LEFT(C.OCCRRNC_DE, 6)) AS DAMT, C.*
        FROM change_base C WHERE C.MAMT > 0
          AND ((C.SAMT > 0 AND C.DVLP_DIV_CD = '2') OR (C.SAMT < 0 AND C.DVLP_DIV_CD = '3'))
    ),
    change_running AS (
        SELECT SUM(C.SAMT) OVER (
                PARTITION BY C.MBER_NO, LEFT(C.OCCRRNC_DE, 6) ORDER BY C.OCCRRNC_DE, C.SER_NO) AS AAMT, C.*
        FROM change_member C WHERE C.DVLP_DIV_CD = '2'
    ),
    change_alloc AS (
        SELECT ROW_NUMBER() OVER (
                PARTITION BY LEFT(C.OCCRRNC_DE, 6), C.SPNSR_NO, C.SPNSR_BSNS_NO ORDER BY C.SER_NO) AS RNUM,
            CASE WHEN C.MAMT <= C.SAMT AND C.AAMT + C.DAMT <= C.MAMT THEN C.AAMT + C.DAMT
                 WHEN C.MAMT > C.SAMT AND C.AAMT + C.DAMT <= C.SAMT THEN C.AAMT + C.DAMT
                 WHEN C.MAMT <= C.SAMT THEN C.MAMT ELSE C.SAMT END AS RAMT, C.*
        FROM change_running C WHERE C.AAMT - ABS(C.DAMT) > 0
    ),
    increase AS (
        SELECT OCCRRNC_DE, SPNSR_NO, SPNSR_BSNS_NO, SER_NO, MBER_NO, SPNSR_BSNS_ID, RAMT AS SPNSR_AMT, '2' AS DVLP_DIV_CD
        FROM change_alloc WHERE RNUM = 1
    ),
    transformed AS (SELECT * FROM new_rejoin UNION ALL SELECT * FROM increase)"""


@st.cache_data(ttl=600)
def load_dev_weekly_by_type(years, month_val, dept_sel=""):
    years_str = ",".join(str(y) for y in years)
    month_str = f"{month_val:02d}"
    dept_join = ("LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR SP ON T.SPNSR_NO = SP.SPNSR_NO"
                 if dept_sel else "")
    sql = f"""
    WITH {_dev_transformed_cte(years_str, month_str)}
    SELECT CAST(LEFT(T.OCCRRNC_DE, 4) AS INTEGER) AS YEAR,
        {WEEK_SQL_OCCUR.replace('OCCRRNC_DE', 'T.OCCRRNC_DE')} AS WEEK_OF_MONTH,
        CASE WHEN T.DVLP_DIV_CD = '1' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING,
        ROUND(SUM(T.SPNSR_AMT) / 10000.0, 1) AS DEV_CNT
    FROM transformed T
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO BIZ ON T.SPNSR_BSNS_ID = BIZ.SPNSR_BSNS_ID
    {dept_join}
    WHERE COALESCE(CASE BIZ.CPR_DIV_CD WHEN '1' THEN 'I' WHEN '2' THEN 'S' ELSE BIZ.CPR_DIV_CD END, '0') = 'I'
      {_dept_cond('SP.ACMSLT_DEPT_CD', dept_sel)}
    GROUP BY 1, 2, 3 ORDER BY 1, 2, 3
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_campaign_stop_by_type(sel_year, dt_from, dt_to, dept_sel=""):
    """주차 기간 마케팅캠페인별 중단건 (신규/기존 구분) — KPI Top3용 (전주·전년 동주차 비교는 기간만 바꿔 재호출)"""
    base_year = str(sel_year)
    sql = f"""
    WITH CTE_TBL1 AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        -- 본부/지부: 회원통계보고서 회원개발 1-1(classify_dept)과 동일 — 실적부서명 기준
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE,
               CASE WHEN DI.DEPT_NM LIKE '%회원%'
                      OR DI.DEPT_NM IN ('캠페인기획2팀', '소셜펀딩부', '사회공헌협력팀', 'ESG팀',
                                        '매체운영팀', '마케팅기획1팀', '마케팅기획2팀', '컬쳐콘텐츠팀')
                    THEN '본부' ELSE '지부' END AS HQ_DIV,
               COALESCE(DI.DEPT_NM, '부서 미지정') AS TEAM_NM,
               SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO DI ON B.ACMSLT_DEPT_CD = DI.DEPT_ID
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
          {_dept_cond('B.ACMSLT_DEPT_CD', dept_sel)}
        GROUP BY 1, 2, 3, 4
    ),
    STOP_CAMP AS (
        SELECT CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING,
               COALESCE(T2.HQ_DIV, '지부') AS HQ_DIV,
               COALESCE(T2.TEAM_NM, '부서 미지정') AS TEAM_NM,
               COALESCE(SC.MK_CMPGN_NM, '미분류') AS MK_CMPGN,
               -- 드릴다운 상세: CRM 세부캠페인명 / 가두캠페인은 세부캠페인명 속 업체 키워드
               CASE WHEN COALESCE(SC.MK_CMPGN_NM, '') <> '가두캠페인' THEN COALESCE(SC.CMPGN_NM, '미분류')
                    WHEN SC.CMPGN_NM LIKE '%F2F네트워크코리아%' THEN 'F2F네트워크코리아'
                    WHEN SC.CMPGN_NM LIKE '%에스이커머스%' OR SC.CMPGN_NM LIKE '%SE커머스%' THEN '에스이커머스'
                    WHEN SC.CMPGN_NM LIKE '%헬퍼스하이%' THEN '헬퍼스하이'
                    WHEN SC.CMPGN_NM LIKE '%아이비마케팅%' THEN '아이비마케팅'
                    WHEN SC.CMPGN_NM LIKE '%웨이메이커%' THEN '웨이메이커'
                    WHEN SC.CMPGN_NM LIKE '%세이유어드림%' THEN '세이유어드림'
                    WHEN SC.CMPGN_NM LIKE '%세일즈웍스%' THEN '세일즈웍스'
                    WHEN SC.CMPGN_NM LIKE '%그린컴퍼니%' THEN '그린컴퍼니'
                    WHEN SC.CMPGN_NM LIKE '%올포유%' THEN '올포유'
                    ELSE '업체 미표기' END AS DETAIL,
               SUM(COALESCE(T2.SPNSR_AMT, 0)) / 10000.0 AS STOP_CNT
        FROM CTE_TBL1 T1
        LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
        -- 중단회원 캠페인 = 가입캠페인(회원정보 CMPGN_CD)
        LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN SC ON C.CMPGN_CD = SC.CMPGN_CD
        WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
          {"AND T2.MBER_NO IS NOT NULL" if dept_sel else ""}
        GROUP BY 1, 2, 3, 4, 5
    )
    SELECT NEW_EXISTING, HQ_DIV, TEAM_NM, MK_CMPGN, DETAIL, ROUND(STOP_CNT, 1) AS STOP_CNT
    FROM STOP_CAMP
    ORDER BY NEW_EXISTING, HQ_DIV, STOP_CNT DESC
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_stop_paid_cnt_by_team(sel_year, dt_from, dt_to, dept_sel=""):
    """주차 중단 후원별 중단 전 납입 횟수 (후원 기준) — 팀별 TOP 표용
    납입 횟수 = 해당 후원(SPNSR_NO)에서 중단일까지 납입 성공한 회비월 수 (USE_YN/PRCS/PAY_STAT = Y/S/S)"""
    base_year = str(sel_year)
    sql = f"""
    WITH MBR AS (
        -- 중단 대상 회원: load_campaign_stop_by_type 의 CTE_TBL1 과 동일 조건
        SELECT DISTINCT A.MBER_NO
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
        WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND B.MBER_STAT_CD = '12'
          AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
               OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
    ),
    STOP_SP AS (
        SELECT B.SPNSR_NO, B.MBER_NO, MAX(A.SPNSR_DSCNTC_DE) AS DSCNTC_DE,
               CASE WHEN DI.DEPT_NM LIKE '%회원%'
                      OR DI.DEPT_NM IN ('캠페인기획2팀', '소셜펀딩부', '사회공헌협력팀', 'ESG팀',
                                        '매체운영팀', '마케팅기획1팀', '마케팅기획2팀', '컬쳐콘텐츠팀')
                    THEN '본부' ELSE '지부' END AS HQ_DIV,
               COALESCE(DI.DEPT_NM, '부서 미지정') AS TEAM_NM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        JOIN MBR M ON B.MBER_NO = M.MBER_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO DI ON B.ACMSLT_DEPT_CD = DI.DEPT_ID
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
          {_dept_cond('B.ACMSLT_DEPT_CD', dept_sel)}
        GROUP BY 1, 2, 4, 5
    )
    SELECT CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING,
           S.HQ_DIV, S.TEAM_NM, S.SPNSR_NO,
           COUNT(DISTINCT P.MBRFEE_MT) AS PAID_CNT
    FROM STOP_SP S
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON S.MBER_NO = C.MBER_NO
    LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT P
           ON P.SPNSR_NO = S.SPNSR_NO AND P.USE_YN = 'Y' AND P.PRCS_STAT_CD = 'S' AND P.PAY_STAT_CD = 'S'
          AND P.PAY_DE <= TO_DATE(S.DSCNTC_DE, 'YYYYMMDD')
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    GROUP BY 1, 2, 3, 4
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_prev_month_active_by_type(years, month_val, dept_sel=""):
    rows = []
    for y in years:
        if month_val > 1:
            prev_m = month_val - 1
            prev_y = y
        else:
            prev_m = 12
            prev_y = y - 1
        strd_mt = f"{prev_y}{prev_m:02d}"
        strd_mt_int = int(strd_mt)
        _, last_day = calendar.monthrange(prev_y, prev_m)
        month_start = f"{prev_y}-{prev_m:02d}-01"
        month_end = f"{prev_y}-{prev_m:02d}-{last_day:02d}"
        month_31 = f"{strd_mt}31"
        excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if prev_y == 2025 else []
        exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""
        sql = f"""
        WITH
        DEPT_MAP AS (
            SELECT E.DEPT_ID AS SRC_DEPT_ID, B.DEPT_ID AS DEPT4_ID
            FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
            JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
            JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
            JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
            JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO E ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
            WHERE A.UPPER_DEPT_ID = 'ZV000000' AND C.DEPT_ID <> 'ZC000029'
        ),
        DEPT4_DIM AS (
            SELECT B.DEPT_ID AS DEPT4_ID, B.DEPT_NM AS DEPT4_NM, B.SORT_ORDR
            FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
            JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
            WHERE A.UPPER_DEPT_ID = 'ZV000000' AND A.USE_YN = 'Y'
            UNION ALL SELECT 'Z~', '없음', 999
        ),
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
                WHERE FRST_REGIST_DT <= DATEADD(DAY, 1, DATEADD(MONTH, 1, '{month_start}'::DATE))
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
            SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO,
                CASE
                    WHEN LEFT(TO_CHAR(M.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{prev_y}'
                     AND LEFT(TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{prev_y}'
                    THEN '1' ELSE '2'
                END AS NEW_OLD_DIV_CD,
                COALESCE(MAP.DEPT4_ID, 'Z~') AS DEPT4_ID,
                COALESCE(ST.CPR_DIV_CD, 'I') AS CPR_DIV_CD,
                A.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT,
                CASE WHEN TRY_CAST(M.MBER_STAT_CD AS INTEGER) BETWEEN 2 AND 11 THEN 'Y' ELSE 'N' END AS NPY_YN,
                COALESCE(P.PAY_AMT, 0) AS PAY_AMT
            FROM ACTIVE_HISTORY A
            JOIN ACTIVE_MEMBER AM ON A.MBER_NO = AM.MBER_NO
            JOIN MEMBER_MONTH M ON A.MBER_NO = M.MBER_NO
            JOIN BUSINESS_DIM B ON A.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON A.MBER_NO = S.MBER_NO AND A.SPNSR_NO = S.SPNSR_NO
            LEFT JOIN SETLE_MONTH ST ON A.MBER_NO = ST.MBER_NO AND B.CPR_DIV_CD = ST.CPR_DIV_CD
            LEFT JOIN DEPT_MAP MAP ON COALESCE(S.ACMSLT_DEPT_CD, 'Z~') = MAP.SRC_DEPT_ID
            LEFT JOIN PAY_MONTH P ON A.SPNSR_NO = P.SPNSR_NO AND A.SPNSR_BSNS_NO = P.SPNSR_BSNS_NO
            WHERE A.RNUM = 1 AND A.SUM_AMT > 0
              {_dept_cond('S.ACMSLT_DEPT_CD', dept_sel)}
        ),
        ACTIVE_AGG AS (
            SELECT NEW_OLD_DIV_CD, CPR_DIV_CD,
                   SUM(SPNSR_AMT_CNT) AS WJXBFS2
            FROM ACTIVE_FACT
            GROUP BY NEW_OLD_DIV_CD, CPR_DIV_CD
        )
        SELECT {y} AS YEAR,
            CASE NEW_OLD_DIV_CD WHEN '1' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING,
            ROUND(WJXBFS2, 1) AS ACTIVE_CNT
        FROM ACTIVE_AGG
        WHERE CPR_DIV_CD = 'I'
        """
        rows.append(conn.query(sql))
    return pd.concat(rows, ignore_index=True)


# 가입경로 묶음 — 공통브랜드(CMMN_BRND_NM) → 보고서 가입경로 (모든 가입경로 조회에 공통 적용)
BRAND_GROUP_SQL = """CASE COALESCE(MB.CMMN_BRND_NM, '미분류')
        WHEN '방송' THEN '방송 및 영상광고' WHEN '재송출' THEN '방송 및 영상광고'
        WHEN '영상광고' THEN '방송 및 영상광고' WHEN '뉴미디어' THEN '방송 및 영상광고'
        WHEN '회원 온라인개발' THEN '회원' WHEN '회원 오프라인개발' THEN '회원'
        WHEN '회원 콜개발' THEN '회원' WHEN '회원 기타' THEN '회원'
        WHEN '콜개발' THEN '마케팅콜개발'
        ELSE COALESCE(MB.CMMN_BRND_NM, '미분류') END"""
# 공통브랜드 미지정 캠페인 보정 — CRM 캠페인에 공통브랜드가 없을 때만 캠페인명으로 가입경로 지정 (CRM 브랜드 등록 시 불필요)
BRAND_UNSET_SQL = """CASE D.CMPGN_NM
        WHEN '정기_통합_2026_삼방송_SBS_참전용사' THEN '방송 및 영상광고'
        WHEN '정기_통합_2026_재송출_연합뉴스TV_참전용사' THEN '방송 및 영상광고'
        WHEN '정기_통합_2026_DABLE_인천' THEN '디지털'
        WHEN '정기_통합_2026_DABLE_대전충북' THEN '디지털'
        WHEN '정기_통합_2026_DABLE_경기' THEN '디지털'
        WHEN '정기_통합_2026_OKCASHBAG' THEN '디지털'
        WHEN '정기_통합_2026_지역후원운영이사회_지역행사' THEN '지역개발'
        WHEN '정기_통합_2026_신규기획사업_잇플리마켓A' THEN '지역개발' END"""
# 표시 순서 (목록 외 가입경로는 뒤에 표시)
BRAND_ORDER = ["디지털", "방송 및 영상광고", "마케팅콜개발", "교육기관", "지역개발", "대면모금", "회원", "기업"]
# 화면·다운로드에서 제외하는 가입경로 (일시후원 브랜드)
BRAND_HIDDEN = {"일시"}


# =====================================================
# 공통브랜드별 중단현황 데이터 로드 함수
# =====================================================
@st.cache_data(ttl=600)
def load_brand_stop(sel_year, dt_from, dt_to, rsn_filter=""):
    base_year = str(sel_year)
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12' AND B.CPR_DIV_CD = 'I'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
              {rsn_clause}
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    ),
    BRND_LOOKUP AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    MEMBER_BRAND AS (
        SELECT S.MBER_NO, COALESCE(BL.CMMN_BRND_NM, {BRAND_UNSET_SQL}, '미분류') AS CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.MBER_NO ORDER BY S.FRST_REGIST_DT DESC) AS RNUM
        -- 중단회원(회원번호 매칭)의 가입캠페인 기준
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO S
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D ON S.CMPGN_CD = D.CMPGN_CD
        LEFT JOIN BRND_LOOKUP BL ON D.CMMN_BRND = BL.CMMN_BRND
        WHERE S.MBER_NO IN (SELECT MBER_NO FROM CTE_TBL1)
    )
    SELECT {BRAND_GROUP_SQL} AS BRAND,
           CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING,
           COUNT(DISTINCT T1.MBER_NO) AS DSCNTC_MEMBERS,
           ROUND(SUM(COALESCE(T2.SPNSR_AMT, 0)) / 10000.0, 1) AS DSCNTC_CNT
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
    LEFT JOIN MEMBER_BRAND MB ON T1.MBER_NO = MB.MBER_NO AND MB.RNUM = 1
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    GROUP BY BRAND, NEW_EXISTING
    ORDER BY DSCNTC_CNT DESC
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_high_value_members(sel_year, dt_from, dt_to, rsn_filter="", threshold=20):
    """고액 중단 회원 (threshold건 이상) 조회"""
    base_year = str(sel_year)
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12' AND B.CPR_DIV_CD = 'I'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
              {rsn_clause}
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    ),
    BRND_LOOKUP AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    MEMBER_BRAND AS (
        SELECT S.MBER_NO, COALESCE(BL.CMMN_BRND_NM, {BRAND_UNSET_SQL}, '미분류') AS CMMN_BRND_NM,
               SC.CMPGN_CTGR_NM, SC.MK_CMPGN_NM,
               ROW_NUMBER() OVER (PARTITION BY S.MBER_NO ORDER BY S.FRST_REGIST_DT DESC) AS RNUM
        -- 중단회원(회원번호 매칭)의 가입캠페인 기준
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO S
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D ON S.CMPGN_CD = D.CMPGN_CD
        LEFT JOIN BRND_LOOKUP BL ON D.CMMN_BRND = BL.CMMN_BRND
        LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN SC ON S.CMPGN_CD = SC.CMPGN_CD
        WHERE S.MBER_NO IN (SELECT MBER_NO FROM CTE_TBL1)
    )
    SELECT T1.MBER_NO,
           CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규' ELSE '기존' END AS NEW_EXISTING,
           {BRAND_GROUP_SQL} AS BRAND,
           ROUND(COALESCE(T2.SPNSR_AMT, 0) / 10000.0, 1) AS DSCNTC_CNT,
           COALESCE(MB.CMPGN_CTGR_NM, '미분류') AS CMPGN_CTGR,
           COALESCE(MB.MK_CMPGN_NM, '미분류') AS MK_CMPGN
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
    LEFT JOIN MEMBER_BRAND MB ON T1.MBER_NO = MB.MBER_NO AND MB.RNUM = 1
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    HAVING DSCNTC_CNT >= {threshold}
    ORDER BY DSCNTC_CNT DESC
    """
    return conn.query(sql)


def render_high_value_remarks(sel_year, dt_from, dt_to, rsn_filter="", threshold=20):
    """고액 중단 회원 비고 HTML 생성"""
    hv_df = load_high_value_members(sel_year, dt_from, dt_to, rsn_filter=rsn_filter, threshold=threshold)
    label = "미납중단" if rsn_filter else "중단"
    if hv_df.empty:
        return f'<div style="background:#fafafa;border:1px solid #BFBFBF;border-top:none;padding:10px 14px;font-size:12px;color:#7f8c8d;">비고) 고액 {label} {threshold}건 이상 회원 없음</div>'
    hv_df["DSCNTC_CNT"] = pd.to_numeric(hv_df["DSCNTC_CNT"], errors='coerce').fillna(0)
    count = len(hv_df)
    lines = [f'<b>*고액 {label} {threshold}건 이상 회원({count}명)</b>']
    for i, (_, r) in enumerate(hv_df.iterrows(), 1):
        cnt_val = float(r["DSCNTC_CNT"])
        lines.append(f'{i}){r["NEW_EXISTING"]}/{r["BRAND"]}/{cnt_val:,.1f}건/{r["CMPGN_CTGR"]}/{r["MK_CMPGN"]}')
    html = '<div style="background:#fefce8;border:1px solid #BFBFBF;border-top:none;padding:10px 14px;font-size:12px;line-height:1.8;color:#2C3E50;border-radius:0 0 8px 8px;">'
    html += '<br>'.join(lines)
    html += '</div>'
    return html


@st.cache_data(ttl=600)
def load_brand_join_year_breakdown(sel_year, dt_from, dt_to, rsn_filter=""):
    """가입경로별 중단회원의 가입연도 분포 조회"""
    base_year = str(sel_year)
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12' AND B.CPR_DIV_CD = 'I'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
              {rsn_clause}
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    ),
    BRND_LOOKUP AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    MEMBER_BRAND AS (
        SELECT S.MBER_NO, COALESCE(BL.CMMN_BRND_NM, {BRAND_UNSET_SQL}, '미분류') AS CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.MBER_NO ORDER BY S.FRST_REGIST_DT DESC) AS RNUM
        -- 중단회원(회원번호 매칭)의 가입캠페인 기준
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO S
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D ON S.CMPGN_CD = D.CMPGN_CD
        LEFT JOIN BRND_LOOKUP BL ON D.CMMN_BRND = BL.CMMN_BRND
        WHERE S.MBER_NO IN (SELECT MBER_NO FROM CTE_TBL1)
    )
    SELECT {BRAND_GROUP_SQL} AS BRAND,
           YEAR(C.FRST_REGIST_DT) AS JOIN_YEAR,
           COUNT(DISTINCT T1.MBER_NO) AS MEMBERS,
           ROUND(SUM(COALESCE(T2.SPNSR_AMT, 0)) / 10000.0, 1) AS DSCNTC_CNT
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
    LEFT JOIN MEMBER_BRAND MB ON T1.MBER_NO = MB.MBER_NO AND MB.RNUM = 1
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    GROUP BY BRAND, JOIN_YEAR
    ORDER BY BRAND, JOIN_YEAR DESC
    """
    return conn.query(sql)


def build_brand_remarks(sel_year, dt_from, dt_to, rsn_filter=""):
    """가입경로별 비고 텍스트 생성 — 가입연도 분포"""
    bdf = load_brand_join_year_breakdown(sel_year, dt_from, dt_to, rsn_filter=rsn_filter)
    if bdf.empty:
        return {}
    bdf["MEMBERS"] = pd.to_numeric(bdf["MEMBERS"], errors='coerce').fillna(0).astype(int)
    bdf["DSCNTC_CNT"] = pd.to_numeric(bdf["DSCNTC_CNT"], errors='coerce').fillna(0)
    bdf["JOIN_YEAR"] = pd.to_numeric(bdf["JOIN_YEAR"], errors='coerce').fillna(0).astype(int)
    remarks = {}
    short_year = str(sel_year)[2:]
    for brand in bdf["BRAND"].unique():
        sub = bdf[bdf["BRAND"] == brand]
        total_cnt = float(sub["DSCNTC_CNT"].sum())
        total_m = int(sub["MEMBERS"].sum())
        if total_cnt <= 0:
            remarks[brand] = "-"
            continue
        cur = sub[sub["JOIN_YEAR"] == sel_year]
        cur_cnt = float(cur["DSCNTC_CNT"].sum()) if not cur.empty else 0.0
        cur_m = int(cur["MEMBERS"].sum()) if not cur.empty else 0
        cur_pct = round(cur_cnt / total_cnt * 100, 1)
        prev = sub[sub["JOIN_YEAR"] < sel_year]
        prev_cnt = float(prev["DSCNTC_CNT"].sum()) if not prev.empty else 0.0
        prev_pct = round(prev_cnt / total_cnt * 100, 1)
        if not prev.empty:
            min_yr = str(int(prev["JOIN_YEAR"].min()))[2:]
            max_yr = str(int(prev["JOIN_YEAR"].max()))[2:]
            prev_label = f"{min_yr}~{max_yr}년" if min_yr != max_yr else f"{min_yr}년"
        else:
            prev_label = "이전"
        txt = f"{short_year}년 가입 {cur_pct}%({cur_m}명,{cur_cnt:,.1f}건)"
        if prev_pct > 0:
            txt += f" / {prev_label} {prev_pct}%"
        remarks[brand] = txt
    return remarks


def render_brand_table(brand_df, remarks=None, popup_key=None):
    """공통브랜드별 중단현황 HTML 테이블 생성 (CMMN_BRND_NM 고유값 기준)"""
    brand_df = brand_df[~brand_df["BRAND"].isin(BRAND_HIDDEN)] if not brand_df.empty else brand_df
    if brand_df.empty:
        return '<div style="color:#95a5a6;padding:10px;">데이터가 없습니다.</div>'
    brand_df = brand_df.copy()
    brand_df["DSCNTC_MEMBERS"] = pd.to_numeric(brand_df["DSCNTC_MEMBERS"], errors='coerce').fillna(0).astype(int)
    brand_df["DSCNTC_CNT"] = pd.to_numeric(brand_df["DSCNTC_CNT"], errors='coerce').fillna(0)
    # 공통브랜드별 집계 (그룹핑 없이 CMMN_BRND_NM 그대로 사용)
    brands = brand_df.groupby("BRAND").agg(
        total_m=("DSCNTC_MEMBERS", "sum"),
        total_c=("DSCNTC_CNT", "sum")
    ).reset_index()
    brands["sort_key"] = brands["BRAND"].apply(lambda b: BRAND_ORDER.index(b) if b in BRAND_ORDER else 99)
    brands = brands.sort_values("sort_key")
    grand_total_m = int(brands["total_m"].sum())
    grand_total_c = float(brands["total_c"].sum())
    rows = []
    for _, br in brands.iterrows():
        bname = br["BRAND"]
        sub = brand_df[brand_df["BRAND"] == bname]
        new_r = sub[sub["NEW_EXISTING"] == "신규회원"]
        exist_r = sub[sub["NEW_EXISTING"] == "기존회원"]
        new_c = float(new_r["DSCNTC_CNT"].sum()) if not new_r.empty else 0.0
        exist_c = float(exist_r["DSCNTC_CNT"].sum()) if not exist_r.empty else 0.0
        rows.append({
            "brand": bname,
            "members": int(br["total_m"]),
            "cnt": float(br["total_c"]),
            "pct": round(br["total_c"] / grand_total_c * 100, 1) if grand_total_c > 0 else 0,
            "new_cnt": new_c,
            "exist_cnt": exist_c,
        })
    # HTML
    hdr_sty = 'background:#A9C1DD;color:#222;padding:7px 10px;border:1px solid #BFBFBF;text-align:center;font-size:12px;'
    html = '<table style="width:100%;border-collapse:collapse;font-size:13px;border-radius:8px;overflow:hidden;">'
    html += '<thead><tr>'
    html += f'<th style="{hdr_sty}">가입경로</th>'
    html += f'<th style="{hdr_sty}">중단(명)</th>'
    html += f'<th style="{hdr_sty}">중단(건)</th>'
    html += f'<th style="{hdr_sty}">구성비(%)</th>'
    html += f'<th style="{hdr_sty}">신규중단(건)</th>'
    html += f'<th style="{hdr_sty}">기존중단(건)</th>'
    if remarks is not None:
        html += f'<th style="{hdr_sty}">비고</th>'
    html += '</tr></thead><tbody>'
    for r in rows:
        html += '<tr>'
        if popup_key:
            # 가입경로 클릭 → 캠페인별 상세 팝업 (render_brand_popup_script 가 처리)
            html += (f'<td data-bpop="{html_lib.escape(popup_key)}|{html_lib.escape(r["brand"])}" title="클릭 시 캠페인별 상세보기" '
                     f'style="padding:6px 10px;border:1px solid #BFBFBF;text-align:left;cursor:pointer;color:#1B4F8A;'
                     f'font-weight:700;text-decoration:underline;">{html_lib.escape(r["brand"])} 🔍</td>')
        else:
            html += f'<td style="padding:6px 10px;border:1px solid #BFBFBF;text-align:left;">{r["brand"]}</td>'
        html += f'<td style="padding:6px 10px;border:1px solid #BFBFBF;text-align:right;">{r["members"]:,}</td>'
        html += f'<td style="padding:6px 10px;border:1px solid #BFBFBF;text-align:right;">{r["cnt"]:,.1f}</td>'
        html += f'<td style="padding:6px 10px;border:1px solid #BFBFBF;text-align:right;">{r["pct"]:.1f}%</td>'
        html += f'<td style="padding:6px 10px;border:1px solid #BFBFBF;text-align:right;">{r["new_cnt"]:,.1f}</td>'
        html += f'<td style="padding:6px 10px;border:1px solid #BFBFBF;text-align:right;">{r["exist_cnt"]:,.1f}</td>'
        if remarks is not None:
            rmk = remarks.get(r["brand"], "-")
            html += f'<td style="padding:6px 10px;border:1px solid #BFBFBF;text-align:left;font-size:11px;color:#555;max-width:280px;">{rmk}</td>'
        html += '</tr>'
    # 합계행
    tot_new = sum(r["new_cnt"] for r in rows)
    tot_exist = sum(r["exist_cnt"] for r in rows)
    tot_sty = 'background:#F2F2F2;color:#222;font-weight:bold;padding:6px 10px;border:1px solid #BFBFBF;'
    html += f'<tr><td style="{tot_sty}text-align:left;">합계</td>'
    html += f'<td style="{tot_sty}text-align:right;">{grand_total_m:,}</td>'
    html += f'<td style="{tot_sty}text-align:right;">{grand_total_c:,.1f}</td>'
    html += f'<td style="{tot_sty}text-align:right;">100%</td>'
    html += f'<td style="{tot_sty}text-align:right;">{tot_new:,.1f}</td>'
    html += f'<td style="{tot_sty}text-align:right;">{tot_exist:,.1f}</td>'
    if remarks is not None:
        html += f'<td style="{tot_sty}text-align:left;"></td>'
    html += '</tr></tbody></table>'
    return html


@st.cache_data(ttl=600)
def load_brand_popup_members(sel_year, dt_from, dt_to, rsn_filter=""):
    """가입경로 팝업용 중단회원 단위 데이터 — load_brand_stop 과 같은 대상·가입경로 규칙
    + 신규/기존 · 가입연도 · 성별/연령대(DIM_MEMBER, 현재 기준) · 납입방식(최신 사단 결제, PM030) · 후원기간(가입~중단, 개월)"""
    base_year = str(sel_year)
    rsn_clause = f"AND A.DSCNTC_RSN_CD IN ({rsn_filter})" if rsn_filter else ""
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12' AND B.CPR_DIV_CD = 'I'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
              {rsn_clause}
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    ),
    BRND_LOOKUP AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    MEMBER_BRAND AS (
        SELECT S.MBER_NO, COALESCE(BL.CMMN_BRND_NM, {BRAND_UNSET_SQL}, '미분류') AS CMMN_BRND_NM, SC.CMPGN_CTGR_NM, SC.MK_CMPGN_NM,
               ROW_NUMBER() OVER (PARTITION BY S.MBER_NO ORDER BY S.FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO S
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D ON S.CMPGN_CD = D.CMPGN_CD
        LEFT JOIN BRND_LOOKUP BL ON D.CMMN_BRND = BL.CMMN_BRND
        LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN SC ON S.CMPGN_CD = SC.CMPGN_CD
        WHERE S.MBER_NO IN (SELECT MBER_NO FROM CTE_TBL1)
    ),
    PAY AS (  -- 회원 최신 사단 결제수단
        SELECT P.MBER_NO, COALESCE(PC.DTL_CD_NM, '미상') AS PAY_NM
        FROM (SELECT MBER_NO, SETLE_CD, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SETLE_KEY DESC) AS RN
              FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
              WHERE CPR_DIV_CD IN ('I', '1') AND MBER_NO IN (SELECT MBER_NO FROM CTE_TBL1)) P
        LEFT JOIN GN_DW.SILVER.CRM_CODE PC ON PC.CD_ID = 'PM030' AND PC.DTL_CD_ID = P.SETLE_CD
        WHERE P.RN = 1
    )
    SELECT {BRAND_GROUP_SQL} AS BRAND,
           COALESCE(MB.CMPGN_CTGR_NM, '미분류') AS CONTENTS,
           COALESCE(MB.MK_CMPGN_NM, '미분류') AS MK_CMPGN,
           CASE WHEN LEFT(TO_CHAR(C.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{base_year}' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING,
           YEAR(C.FRST_REGIST_DT) AS JOIN_YEAR,
           COALESCE(DM.GENDER_NAME, '미상') AS GENDER,
           COALESCE(DM.AGE_BAND, '미상') AS AGE_BAND,
           COALESCE(PY.PAY_NM, '미상') AS PAY_NM,
           DATEDIFF(MONTH, C.FRST_REGIST_DT, TO_DATE(T1.SPNSR_DSCNTC_DE, 'YYYYMMDD')) AS SPAN_MON,
           ROUND(COALESCE(T2.SPNSR_AMT, 0) / 10000.0, 1) AS DSCNTC_CNT
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
    LEFT JOIN MEMBER_BRAND MB ON T1.MBER_NO = MB.MBER_NO AND MB.RNUM = 1
    LEFT JOIN GN_DW.GOLD.DIM_MEMBER DM ON DM.MEMBER_DK = LPAD(T1.MBER_NO::VARCHAR, 7, '0')
    LEFT JOIN PAY PY ON T1.MBER_NO = PY.MBER_NO
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    """
    return conn.query(sql)


AGE_ORDER = ["10대 미만", "10대", "20대", "30대", "40대", "50대", "60대", "70대", "80대 이상", "미상"]
SPAN_BINS = [(0, 3, "3개월 미만"), (3, 6, "3~6개월"), (6, 12, "6~12개월"), (12, 24, "1~2년"),
             (24, 36, "2~3년"), (36, 60, "3~5년"), (60, 10 ** 6, "5년 이상")]


def _span_label(m):
    if pd.isna(m):
        return "미상"
    for lo, hi, lb in SPAN_BINS:
        if lo <= m < hi:
            return lb
    return "미상"


def build_brand_popup_payload(mem_df, sel_year):
    """가입경로별 팝업 데이터 — 표(캠페인카테고리×마케팅캠페인 신규/기존/합계건·구성비·가입연도 비고) + 캠페인별 4종 분포(회원 수)"""
    if mem_df.empty:
        return {}
    d = mem_df.copy()
    d = d[~d["BRAND"].isin(BRAND_HIDDEN)]
    d["DSCNTC_CNT"] = pd.to_numeric(d["DSCNTC_CNT"], errors="coerce").fillna(0)
    d["JOIN_YEAR"] = pd.to_numeric(d["JOIN_YEAR"], errors="coerce")
    d["SPAN"] = pd.to_numeric(d["SPAN_MON"], errors="coerce").map(_span_label)
    short = lambda y: f"'{str(int(y))[2:]}" if pd.notna(y) else "미상"

    def dist(sub, col, order=None):
        vc = sub[col].fillna("미상").value_counts()
        keys = [k for k in (order or []) if k in vc.index] + [k for k in vc.index if not order or k not in order]
        return [[str(k), int(vc[k])] for k in keys]

    out = {}
    for brand, b in d.groupby("BRAND"):
        b_tot = float(b["DSCNTC_CNT"].sum())
        rows, camps = [], {}
        g = (b.assign(new=b["DSCNTC_CNT"].where(b["NEW_EXISTING"] == "신규회원", 0.0),
                      ex=b["DSCNTC_CNT"].where(b["NEW_EXISTING"] == "기존회원", 0.0))
              .groupby(["CONTENTS", "MK_CMPGN"], as_index=False)
              .agg(new=("new", "sum"), ex=("ex", "sum"), tot=("DSCNTC_CNT", "sum"), m=("DSCNTC_CNT", "size"))
              .sort_values("tot", ascending=False))
        for _, r in g.iterrows():
            x = b[(b["CONTENTS"] == r["CONTENTS"]) & (b["MK_CMPGN"] == r["MK_CMPGN"])]
            yr = x.groupby("JOIN_YEAR", dropna=False).agg(m=("DSCNTC_CNT", "size"), c=("DSCNTC_CNT", "sum")).sort_values("c", ascending=False)
            parts = [f"{short(y)}년 {int(v.m)}명·{v.c:,.1f}건({v.c / r['tot'] * 100 if r['tot'] else 0:.0f}%)"
                     for y, v in yr.head(3).iterrows()]
            if len(yr) > 3:
                rest = yr.iloc[3:]
                parts.append(f"그 외 {int(rest.m.sum())}명·{rest.c.sum():,.1f}건({rest.c.sum() / r['tot'] * 100 if r['tot'] else 0:.0f}%)")
            rows.append([r["CONTENTS"], r["MK_CMPGN"], round(r["new"], 1), round(r["ex"], 1), round(r["tot"], 1),
                         round(r["tot"] / b_tot * 100, 1) if b_tot else 0, " · ".join(parts)])
        for mk, x in b.groupby("MK_CMPGN"):
            camps[mk] = {"m": int(len(x)), "c": round(float(x["DSCNTC_CNT"].sum()), 1),
                         "gender": dist(x, "GENDER", ["여자", "남자"]), "age": dist(x, "AGE_BAND", AGE_ORDER),
                         "pay": dist(x, "PAY_NM"), "span": dist(x, "SPAN", [lb for *_, lb in SPAN_BINS] + ["미상"])}
        order = sorted(camps, key=lambda k: -camps[k]["c"])
        allc = {"m": int(len(b)), "c": round(b_tot, 1),
                "gender": dist(b, "GENDER", ["여자", "남자"]), "age": dist(b, "AGE_BAND", AGE_ORDER),
                "pay": dist(b, "PAY_NM"), "span": dist(b, "SPAN", [lb for *_, lb in SPAN_BINS] + ["미상"])}
        out[brand] = {"rows": rows, "camps": camps, "order": order, "all": allc,
                      "tot": [round(float(b.loc[b["NEW_EXISTING"] == "신규회원", "DSCNTC_CNT"].sum()), 1),
                              round(float(b.loc[b["NEW_EXISTING"] == "기존회원", "DSCNTC_CNT"].sum()), 1),
                              round(b_tot, 1), int(len(b))]}
    return out


def render_brand_popup_script(popup_key, payload, title):
    """가입경로 셀(data-bpop) 클릭 → 팝업: 마케팅캠페인 버튼(그래프 4종 갱신) + 캠페인별 중단 표 — 화면별 popup_key 로 데이터 구분"""
    import json
    stc.html("""<script>
(function(){
var doc=window.parent.document;
doc._bpData=doc._bpData||{};
doc._bpData[%s]={title:%s,data:%s};
var ov=doc.getElementById('bp-popup-overlay');
if(!ov){
  ov=doc.createElement('div');ov.id='bp-popup-overlay';
  ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%%;height:100%%;z-index:99999;background:rgba(0,0,0,0.35);justify-content:center;align-items:flex-start;padding-top:50px;';
  ov.innerHTML='<div id="bp-popup-box" style="background:#fff;border-radius:12px;box-shadow:0 8px 40px rgba(0,0,0,0.2);max-width:1150px;width:95%%;max-height:88vh;overflow-y:auto;"></div>';
  doc.body.appendChild(ov);
  ov.addEventListener('click',function(e){if(e.target===ov)ov.style.display='none';});
}
if(doc._bpBound)return;doc._bpBound=true;
function esc(t){return String(t).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function fmt(v){return Number(v).toLocaleString('ko-KR',{minimumFractionDigits:1,maximumFractionDigits:1});}
var COL={gender:'#5B7DB1',age:'#1a9c6e',pay:'#E67E22',span:'#8E44AD'};
function bars(title,list,color){
  var tot=list.reduce(function(a,b){return a+b[1];},0)||1;
  var h='<div style="border:1px solid #D5DCE4;border-radius:8px;padding:8px 12px;"><div style="font-weight:800;font-size:13px;margin-bottom:6px;color:#2C3E50;">'+title+'</div>';
  list.forEach(function(it){var p=it[1]/tot*100;
    h+='<div style="display:flex;align-items:center;gap:6px;font-size:12px;margin:3px 0;"><span style="width:84px;text-align:right;color:#34495E;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">'+esc(it[0])+'</span>'
     +'<span style="flex:1;background:#EEF1F4;border-radius:3px;height:14px;position:relative;"><span style="position:absolute;left:0;top:0;height:14px;border-radius:3px;background:'+color+';width:'+p.toFixed(1)+'%%;"></span></span>'
     +'<span style="width:92px;color:#2C3E50;white-space:nowrap;">'+it[1].toLocaleString()+'명 ('+p.toFixed(0)+'%%)</span></div>';});
  return h+'</div>';
}
function charts(B,brand,mk){
  var c=mk?B.camps[mk]:B.all;if(!c)return '';
  var nm=mk?esc(mk)+' (마케팅캠페인)':esc(brand)+' 전체';
  var h='<div style="display:flex;align-items:center;gap:10px;margin:4px 0 8px 0;"><span style="font-weight:800;font-size:14px;color:#1B4F8A;">📊 '+nm+' 중단회원 특성 <span style="font-weight:600;font-size:12px;color:#7f8c8d;">('+c.m.toLocaleString()+'명 · '+fmt(c.c)+'건)</span></span>'
   +(mk?'<span data-bpmk="" style="cursor:pointer;padding:2px 10px;border-radius:12px;font-size:12px;font-weight:700;border:1px solid #1B4F8A;color:#1B4F8A;">↩ '+esc(brand)+' 전체 보기</span>':'')+'</div>';
  h+='<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">';
  h+=bars('성별',c.gender,COL.gender)+bars('연령대 (현재 기준)',c.age,COL.age)+bars('납입방식 (최신 결제수단)',c.pay,COL.pay)+bars('후원기간 (가입~중단)',c.span,COL.span);
  return h+'</div>';
}
function render(key,brand,mk){
  var P=doc._bpData[key];if(!P)return;var B=P.data[brand];if(!B)return;
  mk=mk||'';
  var box=doc.getElementById('bp-popup-box');
  var th='padding:6px 8px;border:1px solid #BFBFBF;background:#A9C1DD;color:#222;font-size:12px;text-align:center;';
  var td='padding:5px 8px;border:1px solid #BFBFBF;font-size:12px;';
  var h='<div style="background:#2C3E50;color:#fff;padding:12px 18px;border-radius:12px 12px 0 0;display:flex;justify-content:space-between;align-items:center;">'
   +'<span style="font-weight:800;font-size:16px;">🔍 '+esc(brand)+' 중단 상세 · '+esc(P.title)+'</span><span id="bp-close" style="cursor:pointer;font-size:20px;">✕</span></div><div style="padding:14px 18px;">';
  h+='<div style="font-size:12px;color:#5D6D7E;margin-bottom:6px;">그래프는 가입경로 전체 기준 · 아래 표의 마케팅캠페인명을 클릭하면 해당 캠페인 기준으로 바뀝니다</div>'+charts(B,brand,mk);
  h+='<table style="width:100%%;border-collapse:collapse;margin-top:14px;"><thead><tr><th style="'+th+'">캠페인카테고리</th><th style="'+th+'">마케팅캠페인</th>'
   +'<th style="'+th+'">신규중단(건)</th><th style="'+th+'">기존중단(건)</th><th style="'+th+'">합계중단(건)</th><th style="'+th+'">구성비(%%)</th>'
   +'<th style="'+th+'">비고 (중단회원 가입연도: 명·건·구성비)</th></tr></thead><tbody>';
  B.rows.forEach(function(r){var on=r[1]===mk;
    h+='<tr style="'+(on?'background:#FFF8DC;':'')+'"><td style="'+td+'">'+esc(r[0])+'</td>'
     +'<td data-bpmk="'+esc(r[1])+'" style="'+td+'cursor:pointer;color:#1B4F8A;text-decoration:underline;font-weight:700;">'+esc(r[1])+'</td>'
     +'<td style="'+td+'text-align:right;">'+fmt(r[2])+'</td><td style="'+td+'text-align:right;">'+fmt(r[3])+'</td>'
     +'<td style="'+td+'text-align:right;font-weight:700;">'+fmt(r[4])+'</td><td style="'+td+'text-align:right;">'+r[5].toFixed(1)+'%%</td>'
     +'<td style="'+td+'font-size:11px;color:#555;">'+esc(r[6])+'</td></tr>';});
  var t=B.tot;
  h+='<tr style="background:#F2F2F2;font-weight:700;"><td style="'+td+'" colspan="2">합계 ('+t[3].toLocaleString()+'명)</td><td style="'+td+'text-align:right;">'+fmt(t[0])+'</td>'
   +'<td style="'+td+'text-align:right;">'+fmt(t[1])+'</td><td style="'+td+'text-align:right;">'+fmt(t[2])+'</td><td style="'+td+'text-align:right;">100%%</td><td style="'+td+'"></td></tr>';
  h+='</tbody></table><div style="margin-top:6px;font-size:11px;color:#95a5a6;">※ 그래프는 중단 회원 수 기준 · 연령대는 현재 기준 · 납입방식은 회원의 최신 사단 결제수단</div></div>';
  box.innerHTML=h;box._k=key;box._b=brand;ov.style.display='flex';
  doc.getElementById('bp-close').onclick=function(){ov.style.display='none';};
}
doc.addEventListener('click',function(e){
  var c=e.target.closest('[data-bpop]');
  if(c){var v=c.getAttribute('data-bpop'),i=v.indexOf('|');render(v.slice(0,i),v.slice(i+1));return;}
  var m=e.target.closest('#bp-popup-box [data-bpmk]');
  if(m){var bx=doc.getElementById('bp-popup-box');render(bx._k,bx._b,m.getAttribute('data-bpmk'));}
});
})();
</script>""" % (json.dumps(popup_key), json.dumps(title, ensure_ascii=False), json.dumps(payload, ensure_ascii=False)), height=0)


def calc_day_info(start_date, end_date):
    total = (end_date - start_date).days + 1
    weekdays = weekends = holidays_on_weekday = 0
    year_holidays = set(KOREAN_HOLIDAYS.get(start_date.year, []))
    current = start_date
    while current <= end_date:
        if current.weekday() < 5:
            if current in year_holidays:
                holidays_on_weekday += 1
            else:
                weekdays += 1
        else:
            weekends += 1
        current += datetime.timedelta(days=1)
    return {"total": total, "weekdays": weekdays, "weekends": weekends,
            "holidays": holidays_on_weekday, "non_working": weekends + holidays_on_weekday}


@st.cache_data(ttl=600)
def load_top3_campaigns(_sel_year, dt_from, dt_to):
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12' AND B.CPR_DIV_CD = 'I'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    )
    SELECT COALESCE(D.CMPGN_NM, C.CMPGN_CD, '미분류') AS CAMPAIGN_NAME,
           ROUND(SUM(COALESCE(T2.SPNSR_AMT, 0)) / 10000.0, 1) AS DSCNTC_CNT
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO C ON T1.MBER_NO = C.MBER_NO
    LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D ON C.CMPGN_CD = D.CMPGN_CD
    WHERE C.MBER_STAT_CD = '12' AND C.CPR_DIV_CD = 'I'
    GROUP BY CAMPAIGN_NAME
    ORDER BY DSCNTC_CNT DESC
    LIMIT 3
    """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_dscntc_by_reason(_sel_year, dt_from, dt_to):
    sql = f"""
    WITH
    CTE_TBL1 AS (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE, A.DSCNTC_RSN_CD FROM (
            SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE, A.DSCNTC_RSN_CD,
                   ROW_NUMBER() OVER (PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
            WHERE A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
              AND B.MBER_STAT_CD = '12' AND B.CPR_DIV_CD = 'I'
              AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                   OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))
        ) A WHERE A.RNUM = 1
    ),
    CTE_TBL2 AS (
        SELECT B.MBER_NO, A.SPNSR_DSCNTC_DE, SUM(A.SPNSR_AMT) AS SPNSR_AMT
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y' AND A.SPNSR_DSCNTC_DE BETWEEN '{dt_from}' AND '{dt_to}'
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
        GROUP BY B.MBER_NO, A.SPNSR_DSCNTC_DE
    )
    SELECT COALESCE(R.DTL_CD_NM, T1.DSCNTC_RSN_CD) AS REASON_NAME,
           ROUND(SUM(COALESCE(T2.SPNSR_AMT, 0)) / 10000.0, 1) AS DSCNTC_CNT
    FROM CTE_TBL1 T1
    LEFT JOIN CTE_TBL2 T2 ON T1.MBER_NO = T2.MBER_NO AND T1.SPNSR_DSCNTC_DE = T2.SPNSR_DSCNTC_DE
    LEFT JOIN GN_DW.SILVER.CRM_CODE R ON T1.DSCNTC_RSN_CD = R.DTL_CD_ID AND R.CD_ID = 'MM005'
    GROUP BY REASON_NAME
    ORDER BY DSCNTC_CNT DESC
    """
    return conn.query(sql)
# =====================================================
stop_df = load_weekly_stop(all_years, month)
stop_df_unpaid = load_weekly_stop(all_years, month, rsn_filter="'14','16'")
dev_df = load_dev_weekly(all_years, month)
active_df = load_prev_month_active(all_years, month)

def normalize_stop(df):
    if not df.empty:
        df["WEEK_OF_MONTH"] = pd.to_numeric(df["WEEK_OF_MONTH"], errors='coerce').fillna(0).astype(int)
        df["YEAR"] = pd.to_numeric(df["YEAR"], errors='coerce').fillna(0).astype(int)
        df["STOP_CNT"] = pd.to_numeric(df["STOP_CNT"], errors='coerce').fillna(0)
    return df

stop_df = normalize_stop(stop_df)
stop_df_unpaid = normalize_stop(stop_df_unpaid)
if not stop_df_unpaid.empty:
    stop_df_unpaid = stop_df_unpaid[stop_df_unpaid["WEEK_OF_MONTH"] == 1].copy()

if not dev_df.empty:
    dev_df["WEEK_OF_MONTH"] = pd.to_numeric(dev_df["WEEK_OF_MONTH"], errors='coerce').fillna(0).astype(int)
    dev_df["YEAR"] = pd.to_numeric(dev_df["YEAR"], errors='coerce').fillna(0).astype(int)
    dev_df["DEV_CNT"] = pd.to_numeric(dev_df["DEV_CNT"], errors='coerce').fillna(0)

# =====================================================
# 공용 HTML 표 렌더링 함수
# =====================================================
def render_11_html_table(rows, y1, y2, y3, subtitle=""):
    gubun_label = f'구분<br>{subtitle}' if subtitle else '구분'
    html = """<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:0;">
    <thead>
        <tr>
            <th rowspan="2" style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">{gubun}</th>
            <th colspan="3" style="background:#A9C1DD;padding:6px;border:1px solid #BFBFBF;text-align:center;">{y1}년도</th>
            <th colspan="3" style="background:#A9C1DD;padding:6px;border:1px solid #BFBFBF;text-align:center;">{y2}년도</th>
            <th colspan="3" style="background:#A9C1DD;padding:6px;border:1px solid #BFBFBF;text-align:center;">{y3}년도</th>
            <th colspan="3" style="background:#A9C1DD;padding:6px;border:1px solid #BFBFBF;text-align:center;">전년대비 증감</th>
            <th colspan="3" style="background:#A9C1DD;padding:6px;border:1px solid #BFBFBF;text-align:center;">전전년대비 증감</th>
        </tr>
        <tr>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">중단(명)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">중단(건)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">구성비(%)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">중단(명)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">중단(건)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">구성비(%)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">중단(명)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">중단(건)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">구성비(%)</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">명</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">건</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">건증감</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">명</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">건</th>
            <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">건증감</th>
        </tr>
    </thead>
    <tbody>""".format(y1=y1, y2=y2, y3=y3, gubun=gubun_label)
    for r in rows:
        is_total = r["구분"] == "합계(명)/합계(건)"
        bg = "background:#F2F2F2;color:#222;font-weight:bold;" if is_total else ""
        html += f'<tr style="{bg}">'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{bg}">{r["구분"]}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y1}년_중단(명)"]:,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y1}년_중단(건)"]:,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y1}년_구성비(%)"]:.0f}%</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y2}년_중단(명)"]:,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y2}년_중단(건)"]:,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y2}년_구성비(%)"]:.0f}%</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y3}년_중단(명)"]:,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y3}년_중단(건)"]:,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r[f"{y3}년_구성비(%)"]:.0f}%</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r["전년대비_증감(명)"]:+,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r["전년대비_증감(건)"]:+,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r["전년대비_건증감(%)"]:+.0f}%</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r["전전년대비_증감(명)"]:+,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r["전전년대비_증감(건)"]:+,.0f}</td>'
        html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{r["전전년대비_건증감(%)"]:+.0f}%</td>'
        html += '</tr>'
    html += "</tbody></table>"
    return html


def build_section1_data(rsn_filter="", rsn_exclude="", dept_sel=""):
    year_data_frst = {}
    for yy in all_years:
        if yy == year:
            yf, yt = dscntc_from, dscntc_to
        else:
            s, e = get_same_week_range(yy, month, week_no)
            yf, yt = s.strftime("%Y%m%d"), e.strftime("%Y%m%d")
        if rsn_filter:
            wr = calc_week_ranges(yy, month)
            s1, e1 = wr[0]
            yf, yt = s1.strftime("%Y%m%d"), e1.strftime("%Y%m%d")
        y_df = load_dscntc_detail(yy, yf, yt, rsn_filter, rsn_exclude, dept_sel)
        if not y_df.empty:
            new_r = y_df[y_df["NEW_EXISTING"] == "신규회원"]
            exist_r = y_df[y_df["NEW_EXISTING"] == "기존회원"]
            new_m = int(new_r["DSCNTC_MEMBERS"].sum()) if len(new_r) > 0 else 0
            new_c = float(new_r["DSCNTC_CNT"].sum()) if len(new_r) > 0 else 0.0
            exist_m = int(exist_r["DSCNTC_MEMBERS"].sum()) if len(exist_r) > 0 else 0
            exist_c = float(exist_r["DSCNTC_CNT"].sum()) if len(exist_r) > 0 else 0.0
        else:
            new_m, new_c, exist_m, exist_c = 0, 0.0, 0, 0.0
        year_data_frst[yy] = {"new_m": new_m, "new_c": new_c, "exist_m": exist_m, "exist_c": exist_c,
                               "total_m": new_m + exist_m, "total_c": new_c + exist_c}
    return year_data_frst


def build_combined_rows(year_data):
    rows = []
    for cat, mk, ck in [("신규", "new_m", "new_c"), ("기존", "exist_m", "exist_c"), ("합계(명)/합계(건)", "total_m", "total_c")]:
        row = {"구분": cat}
        for yy in all_years:
            row[f"{yy}년_중단(명)"] = year_data[yy][mk]
            row[f"{yy}년_중단(건)"] = year_data[yy][ck]
            total_c = year_data[yy]["total_c"]
            row[f"{yy}년_구성비(%)"] = round(year_data[yy][ck] / total_c * 100) if total_c > 0 else 0.0
        row["전년대비_증감(명)"] = year_data[y1][mk] - year_data[y2][mk]
        row["전년대비_증감(건)"] = round(year_data[y1][ck] - year_data[y2][ck])
        y2_val = year_data[y2][ck]
        row["전년대비_건증감(%)"] = round((year_data[y1][ck] - y2_val) / y2_val * 100) if y2_val > 0 else 0.0
        row["전전년대비_증감(명)"] = year_data[y1][mk] - year_data[y3][mk]
        row["전전년대비_증감(건)"] = round(year_data[y1][ck] - year_data[y3][ck])
        y3_val = year_data[y3][ck]
        row["전전년대비_건증감(%)"] = round((year_data[y1][ck] - y3_val) / y3_val * 100) if y3_val > 0 else 0.0
        rows.append(row)
    return rows


def build_section12_data(rsn_filter="", dept_sel=""):
    year_data_12 = {}
    is_last_week = (week_no == total_weeks)
    for yy in all_years:
        cum_from_dt = datetime.date(yy, month, 1)
        if rsn_filter:
            wr = calc_week_ranges(yy, month)
            _, cum_to_dt = wr[0]
        elif yy == year:
            cum_to_dt = w_end
        else:
            yr = calc_week_ranges(yy, month)
            if is_last_week:
                _, cum_to_dt = yr[-1]
            elif week_no <= len(yr):
                _, cum_to_dt = yr[week_no - 1]
            else:
                _, cum_to_dt = yr[-1]
        y_df = load_dscntc_detail(yy, cum_from_dt.strftime("%Y%m%d"), cum_to_dt.strftime("%Y%m%d"), rsn_filter, dept_sel=dept_sel)
        if not y_df.empty:
            new_r = y_df[y_df["NEW_EXISTING"] == "신규회원"]
            exist_r = y_df[y_df["NEW_EXISTING"] == "기존회원"]
            new_m = int(new_r["DSCNTC_MEMBERS"].sum()) if len(new_r) > 0 else 0
            new_c = float(new_r["DSCNTC_CNT"].sum()) if len(new_r) > 0 else 0.0
            exist_m = int(exist_r["DSCNTC_MEMBERS"].sum()) if len(exist_r) > 0 else 0
            exist_c = float(exist_r["DSCNTC_CNT"].sum()) if len(exist_r) > 0 else 0.0
        else:
            new_m, new_c, exist_m, exist_c = 0, 0.0, 0, 0.0
        year_data_12[yy] = {"new_m": new_m, "new_c": new_c, "exist_m": exist_m, "exist_c": exist_c,
                             "total_m": new_m + exist_m, "total_c": new_c + exist_c}
    return year_data_12


# =====================================================
# 스마트 레이블 차트
# =====================================================
def _build_stacked_label_df(chart_df, val_col, fmt_func):
    data_range = chart_df[val_col].max() - chart_df[val_col].min()
    gap = max(data_range * 0.045, 0.001)
    label_rows = []
    for wk in chart_df["주차라벨"].unique():
        wk_data = chart_df[chart_df["주차라벨"] == wk].sort_values(val_col, ascending=False).reset_index(drop=True)
        max_val = wk_data[val_col].max()
        for i, (_, row) in enumerate(wk_data.iterrows()):
            label_rows.append({
                "주차라벨": wk,
                "년도": row["년도"],
                "라벨": f"{row['년도'][:4]}년 {fmt_func(row[val_col])}",
                "label_y": max_val + gap * (len(wk_data) - i),
            })
    return pd.DataFrame(label_rows)


def _make_chart(chart_df, val_col, y_title, y_fmt, fmt_func, wk_order, yr_list):
    cr = ["#27ae60", "#3498db", "#95a5a6"]
    base = alt.Chart(chart_df).encode(
        x=alt.X("주차라벨:N", title="주차", sort=wk_order,
            axis=alt.Axis(labelAngle=0, labelFontSize=11, titleFontSize=12, labelPadding=8)),
        y=alt.Y(f"{val_col}:Q", title=y_title,
            axis=alt.Axis(format=y_fmt, titleFontSize=12, labelFontSize=11),
            scale=alt.Scale(zero=False)),
        color=alt.Color("년도:N", scale=alt.Scale(domain=yr_list, range=cr),
            legend=alt.Legend(title=None, orient="top", direction="horizontal",
                labelFontSize=11, symbolSize=120, symbolStrokeWidth=2)))
    line = base.mark_line(strokeWidth=2.5, point=alt.OverlayMarkDef(size=60, filled=True))
    label_df = _build_stacked_label_df(chart_df, val_col, fmt_func)
    labels = alt.Chart(label_df).mark_text(
        fontSize=10, fontWeight="bold", baseline="bottom", dy=-4
    ).encode(
        x=alt.X("주차라벨:N", sort=wk_order),
        y=alt.Y("label_y:Q"),
        text=alt.Text("라벨:N"),
        color=alt.Color("년도:N", scale=alt.Scale(domain=yr_list, range=["#1e8449", "#2471a3", "#717d7e"]),
            legend=None)
    )
    y_max = label_df["label_y"].max()
    data_range = chart_df[val_col].max() - chart_df[val_col].min()
    y_upper = y_max + data_range * 0.05
    ch = alt.layer(line, labels).properties(width="container", height=380).encode(
        y=alt.Y(f"{val_col}:Q", title=y_title,
            axis=alt.Axis(format=y_fmt, titleFontSize=12, labelFontSize=11),
            scale=alt.Scale(zero=False, domainMax=y_upper))
    ).configure_view(strokeWidth=0)
    return ch


def render_section2_and_3(s_df, d_df, a_df, wk_no, tab_label="", skip_section2=False):
    stop_by_week_all = s_df.groupby(["YEAR", "WEEK_OF_MONTH"]).agg(STOP_CNT=("STOP_CNT", "sum")).reset_index()
    stop_by_week = stop_by_week_all[stop_by_week_all["WEEK_OF_MONTH"] <= wk_no].copy()

    all_week_cols = ["1주차", "2주차", "3주차", "4주차", "5주차"]

    if not skip_section2:
        st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="section-header">2. 동월 주차별 중단(건) 현황(미납중단 포함) <span style="font-size:11px;font-weight:400;opacity:0.8;margin-left:10px;">*각 주차별 중단건 클릭 시 세부사항을 확인할 수 있습니다.</span></div>', unsafe_allow_html=True)
        if not stop_by_week.empty:
            pivot_week = stop_by_week.pivot(index="YEAR", columns="WEEK_OF_MONTH", values="STOP_CNT").fillna(0)
            for w in range(1, 6):
                if w not in pivot_week.columns:
                    pivot_week[w] = 0
            pivot_week = pivot_week[[1, 2, 3, 4, 5]]
            pivot_week.columns = all_week_cols
            pivot_week["합계"] = pivot_week.sum(axis=1)
            # 데이터 없는 주차(wk_no 이후)는 빈칸 처리
            for w in range(wk_no + 1, 6):
                col = f"{w}주차"
                pivot_week[col] = None
            pivot_week = pivot_week.reset_index()
            pivot_week["YEAR"] = pivot_week["YEAR"].apply(lambda x: f"{int(x)}년")
            pivot_week = pivot_week.rename(columns={"YEAR": "년도"})

            def style_wk(df):
                def rc(row):
                    label = row["년도"]
                    if f"{year1}년" in label:
                        return ["background-color:#eafaf1;font-weight:600"] * len(row)
                    elif f"{year2}년" in label:
                        return ["background-color:#fff"] * len(row)
                    elif f"{year3}년" in label:
                        return ["background-color:#fff"] * len(row)
                    return [""] * len(row)
                return df.style.apply(rc, axis=1)

            num_cols = [c for c in pivot_week.columns if c != "년도"]
            fmt = {c: "{:,.0f}" for c in num_cols}
            styled_week = style_wk(pivot_week).format(fmt, na_rep="").set_table_attributes(
                'style="font-size:13px;border-collapse:collapse;"')
            st.markdown(styled_week.hide(axis="index").to_html(), unsafe_allow_html=True)

            st.markdown('<div class="chart-header">주차별 중단(건) 추이</div>', unsafe_allow_html=True)
            chart_df = stop_by_week.copy()
            chart_df["년도"] = chart_df["YEAR"].astype(str) + "년"
            chart_df["주차라벨"] = chart_df["WEEK_OF_MONTH"].apply(lambda w: f"{int(w)}주차")
            wk_order = [f"{w}주차" for w in range(1, 6)]
            yr_list = [f"{y}년" for y in [year1, year2, year3]]
            ch = _make_chart(chart_df, "STOP_CNT", "중단(건)", ",.0f",
                lambda v: f"{v:,.0f}", wk_order, yr_list)
            st.altair_chart(ch, use_container_width=True)
        else:
            st.info("데이터가 없습니다.")

    st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
    st.markdown('<div class="section-header">3. 동월 주차별 중단율 추이(미납중단 포함) <span style="font-size:11px;font-weight:400;opacity:0.8;margin-left:10px;">*각 주차별 중단율 클릭 시 세부사항을 확인할 수 있습니다.</span></div>', unsafe_allow_html=True)
    # st.caption("중단율(%) = 중단(건) / (개발건 + 전월말 활동회원건) × 100")
    rate_rows = []
    for yy in all_years:
        active_row = a_df[a_df["YEAR"] == yy]
        active_cnt = float(active_row["ACTIVE_CNT"].values[0]) if not active_row.empty else 0
        y_stop = stop_by_week[stop_by_week["YEAR"] == yy] if not stop_by_week.empty else pd.DataFrame()
        y_dev = d_df[d_df["YEAR"] == yy]
        if not y_stop.empty:
            for _, row in y_stop.iterrows():
                w = int(row["WEEK_OF_MONTH"])
                s_cnt = float(row["STOP_CNT"])
                dev_row = y_dev[y_dev["WEEK_OF_MONTH"] == w]
                d_cnt = float(dev_row["DEV_CNT"].values[0]) if not dev_row.empty else 0
                denom = d_cnt + active_cnt
                rate = round(s_cnt / denom * 100, 2) if denom > 0 else 0
                rate_rows.append({"년도": int(yy), "주차": w, "중단율(%)": rate})
    r_df = pd.DataFrame(rate_rows)
    if not r_df.empty:
        pivot_rate = r_df.pivot(index="년도", columns="주차", values="중단율(%)")
        for w in range(1, 6):
            if w not in pivot_rate.columns:
                pivot_rate[w] = None
        pivot_rate = pivot_rate[[1, 2, 3, 4, 5]]
        pivot_rate.columns = all_week_cols
        # 데이터 없는 주차는 이미 None
        for w in range(wk_no + 1, 6):
            col = f"{w}주차"
            pivot_rate[col] = None
        pivot_rate = pivot_rate.reset_index()
        pivot_rate["년도"] = pivot_rate["년도"].apply(lambda x: f"{int(x)}년")
        def style_rt(df):
            def rs(row):
                label = row["년도"]
                if f"{year1}년" in label:
                    return ["background-color:#eafaf1;font-weight:600"] * len(row)
                elif f"{year2}년" in label:
                    return ["background-color:#fff"] * len(row)
                elif f"{year3}년" in label:
                    return ["background-color:#fff"] * len(row)
                return [""] * len(row)
            return df.style.apply(rs, axis=1)
        nc = [c for c in pivot_rate.columns if c != "년도"]
        styled_rate = style_rt(pivot_rate).format({c: "{:.2f}%" for c in nc}, na_rep="").set_table_attributes(
            'style="font-size:13px;border-collapse:collapse;"')
        st.markdown(styled_rate.hide(axis="index").to_html(), unsafe_allow_html=True)

        st.markdown('<div class="chart-header">주차별 중단율 추이</div>', unsafe_allow_html=True)
        cdf = r_df.copy()
        cdf["년도"] = cdf["년도"].astype(str) + "년"
        cdf["주차라벨"] = cdf["주차"].apply(lambda w: f"{int(w)}주차")
        wk_order = [f"{w}주차" for w in range(1, 6)]
        yr_list = [f"{y}년" for y in [year1, year2, year3]]

        # 주차별 연도 데이터 구성
        wk_yr_rate = {}
        for wl in wk_order:
            wk_yr_rate[wl] = {}
            for yr_name in yr_list:
                m = cdf[(cdf["주차라벨"] == wl) & (cdf["년도"] == yr_name)]
                wk_yr_rate[wl][yr_name] = float(m["중단율(%)"].iloc[0]) if not m.empty else None

        # SVG 차트
        dot_c3 = {yr_list[0]: "#27ae60", yr_list[1]: "#3498db", yr_list[2]: "#95a5a6"}
        cw3, ch3 = 1100, 300
        pl3, pr3, pt3, pb3 = 80, 40, 55, 45
        pw3 = cw3 - pl3 - pr3
        ph3 = ch3 - pt3 - pb3

        vals3 = [v for wl in wk_order for yr_name in yr_list for v in ([wk_yr_rate[wl][yr_name]] if wk_yr_rate[wl][yr_name] is not None else [])]
        if vals3:
            r_min, r_max = min(vals3), max(vals3)
        else:
            r_min, r_max = 0, 1
        r_range = r_max - r_min if r_max != r_min else r_max * 0.1
        r_lo = max(0, r_min - r_range * 0.4)
        r_hi = r_max + r_range * 0.6

        # Y축 눈금
        r_step = round(r_range / 4, 1) if r_range > 0.4 else round(r_range / 4, 2)
        if r_step == 0:
            r_step = 0.1
        r_ticks = []
        rt = round(r_lo // r_step * r_step, 2)
        while rt <= r_hi:
            if rt >= r_lo:
                r_ticks.append(round(rt, 2))
            rt = round(rt + r_step, 2)

        def to_x3(idx):
            return pl3 + (idx + 0.5) * pw3 / 5
        def to_y3(val):
            return pt3 + ph3 - (val - r_lo) / (r_hi - r_lo) * ph3

        svg3 = f'<div style="border:1px solid #BFBFBF;padding:8px;width:100%;">'
        svg3 += f'<div style="text-align:center;font-size:14px;font-weight:bold;margin-bottom:4px;">동월 주차별 중단율(%) 추이</div>'
        svg3 += f'<svg viewBox="0 0 {cw3} {ch3}" width="100%" preserveAspectRatio="xMidYMid meet" style="font-family:sans-serif;">'

        for yt in r_ticks:
            py = to_y3(yt)
            svg3 += f'<line x1="{pl3}" y1="{py}" x2="{cw3 - pr3}" y2="{py}" stroke="#E0E0E0" stroke-width="1"/>'
            svg3 += f'<text x="{pl3 - 6}" y="{py + 4}" text-anchor="end" font-size="10" fill="#666">{yt:.2f}%</text>'

        for i, wl in enumerate(wk_order):
            px = to_x3(i)
            svg3 += f'<text x="{px}" y="{ch3 - pb3 + 18}" text-anchor="middle" font-size="11" fill="#555">{wl}</text>'

        for yr_name in yr_list:
            for i, wl in enumerate(wk_order):
                if yr_name == yr_list[0]:
                    continue
                val = wk_yr_rate[wl].get(yr_name)
                if val is not None:
                    px = to_x3(i)
                    py = to_y3(val)
                    c = dot_c3[yr_name]
                    svg3 += f'<circle cx="{px}" cy="{py}" r="6" fill="{c}" />'
                    tgt_y = (py + 18) if yr_name == yr_list[2] else (py - 12)
                    svg3 += f'<text x="{px}" y="{tgt_y}" text-anchor="middle" font-size="10" font-weight="bold" fill="{c}">{val:.2f}%</text>'

        svg3 += '</svg>'
        svg3 += '<div style="display:flex;justify-content:center;gap:16px;margin-top:4px;font-size:11px;">'
        for yr_name in yr_list:
            svg3 += f'<span><span style="display:inline-block;width:10px;height:10px;background:{dot_c3[yr_name]};border-radius:50%;margin-right:3px;vertical-align:middle;"></span>{yr_name}</span>'
        svg3 += '</div></div>'
        st.markdown(svg3, unsafe_allow_html=True)
    else:
        st.info("중단율 계산 데이터가 없습니다.")



# =====================================================
# 경영진용 차트 (회원통계보고서 스타일 — 당해년도 강조 그룹 막대)
# =====================================================
def render_exec_chart(data, x_order, yr_list, title, y_title, is_rate=False):
    """data: {x라벨: {연도라벨: 값}} / yr_list[0] = 당해년도"""
    rows = []
    for x in x_order:
        cur = data.get(x, {}).get(yr_list[0])
        for yr in yr_list:
            v = data.get(x, {}).get(yr)
            if v is None or (isinstance(v, float) and pd.isna(v)):
                continue
            prev = data.get(x, {}).get(yr_list[1]) if len(yr_list) > 1 else None
            rows.append({"구분": x, "연도": yr, "값": float(v),
                         "전년대비": (float(cur) - float(prev)) if (yr == yr_list[0] and cur is not None and prev is not None) else None})
    if not rows:
        st.info("데이터가 없습니다.")
        return
    cdf = pd.DataFrame(rows)
    fmt = ".2f" if is_rate else ",.0f"
    suffix = "%" if is_rate else ""
    cdf["라벨"] = cdf["값"].apply(lambda v: f"{v:{fmt}}{suffix}")
    yr_order = list(reversed(yr_list))  # 과거 → 당해 순서로 배치
    palette = {yr_list[0]: "#1a9c6e"}
    for yr, c in zip(yr_list[1:], ["#A9B4C2", "#D5D8DC"]):
        palette[yr] = c
    color = alt.Color("연도:N", sort=yr_order,
                      scale=alt.Scale(domain=yr_order, range=[palette[y] for y in yr_order]),
                      legend=alt.Legend(orient="top", title=None, labelFontSize=12, symbolType="square", symbolSize=140))
    x_enc = alt.X("구분:N", sort=x_order, scale=alt.Scale(domain=x_order), title=None,
                  axis=alt.Axis(labelFontSize=13, labelAngle=0, labelFontWeight="bold", labelColor="#2C3E50", ticks=False, domain=False))
    y_enc = alt.Y("값:Q", title=y_title,
                  axis=alt.Axis(labelFontSize=11, format=fmt, titleFontSize=12, grid=True, gridColor="#EEF1F4", domain=False, ticks=False),
                  scale=alt.Scale(nice=True, zero=not is_rate))
    tips = [alt.Tooltip("구분:N", title="기간"), alt.Tooltip("연도:N"), alt.Tooltip("값:Q", format=fmt, title=y_title),
            alt.Tooltip("전년대비:Q", format=("+.2f" if is_rate else "+,.0f"), title=f"전년 대비{'(%p)' if is_rate else '(건)'}")]
    bars = alt.Chart(cdf).mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4, size=26).encode(
        x=x_enc, xOffset=alt.XOffset("연도:N", sort=yr_order), y=y_enc, color=color, tooltip=tips)
    cur_lbl = alt.Chart(cdf[cdf["연도"] == yr_list[0]]).mark_text(
        dy=-8, fontSize=13, fontWeight="bold", color="#1a7f5a").encode(
        x=alt.X("구분:N", sort=x_order), xOffset=alt.XOffset("연도:N", sort=yr_order), y="값:Q", text="라벨:N")
    oth_lbl = alt.Chart(cdf[cdf["연도"] != yr_list[0]]).mark_text(
        dy=-6, fontSize=10, color="#8e99a4").encode(
        x=alt.X("구분:N", sort=x_order), xOffset=alt.XOffset("연도:N", sort=yr_order), y="값:Q", text="라벨:N")
    st.markdown(f'<div style="font-weight:800;font-size:15px;color:#2C3E50;border-left:4px solid #1a9c6e;'
                f'padding:2px 0 2px 10px;margin:14px 0 4px 0;">{title}'
                f'<span style="font-size:11px;font-weight:500;color:#8e99a4;margin-left:8px;">'
                f'■ {yr_list[0]} 강조 · 막대에 마우스를 올리면 전년 대비 증감 표시</span></div>', unsafe_allow_html=True)
    ch = (bars + oth_lbl + cur_lbl).properties(height=320).configure_view(strokeWidth=0)
    st.altair_chart(ch, use_container_width=True)


# =====================================================
# 경영진 KPI 스트립 (섹션 1: 1-1 ~ 1-3, 2) 요약)
# =====================================================
def calc_weekly_total_rate(wk_data):
    """주간 중단율(합계) = 주간 중단건 / (해당 주차 개발건 + 전월말 활동회원건) × 100"""
    rates = {}
    for yy in all_years:
        d = dev_df[(dev_df["YEAR"] == yy) & (dev_df["WEEK_OF_MONTH"] == week_no)] if not dev_df.empty else pd.DataFrame()
        a = active_df[pd.to_numeric(active_df["YEAR"], errors="coerce") == yy] if not active_df.empty else pd.DataFrame()
        dev = float(d["DEV_CNT"].sum()) if not d.empty else 0.0
        act = float(pd.to_numeric(a["ACTIVE_CNT"], errors="coerce").fillna(0).sum()) if not a.empty else 0.0
        denom = dev + act
        rates[yy] = round(wk_data[yy]["total_c"] / denom * 100, 2) if denom > 0 else 0.0
    return rates


def _kpi_delta(cur, base, unit="건", is_pp=False):
    """중단 지표: 증가=빨강(악화), 감소=파랑(개선) — 증감값은 굵게, 증감률은 작게 한 줄 표시"""
    diff = cur - base
    if is_pp:
        txt, sub = f"{diff:+.2f}%p", ""
    else:
        pct = (diff / base * 100) if base else 0.0
        txt = f"{diff:+,.0f}{unit}"
        sub = f'<span style="font-size:12px;font-weight:600;opacity:.8;margin-left:4px;">({pct:+.1f}%)</span>'
    color = "#e74c3c" if diff > 0 else ("#2e86de" if diff < 0 else "#7f8c8d")
    arrow = "▲" if diff > 0 else ("▼" if diff < 0 else "—")
    return f'<span style="color:{color};font-weight:800;white-space:nowrap;">{arrow} {txt}{sub}</span>'


def _kpi_cum_to(yy):
    """월 누계 종료일 — build_section12_data 와 동일 규칙"""
    if yy == year:
        return w_end
    yr = calc_week_ranges(yy, month)
    if week_no == total_weeks or week_no > len(yr):
        return yr[-1][1]
    return yr[week_no - 1][1]


def _sum_cnt(df, seg=None):
    if df.empty:
        return 0.0
    if seg:
        df = df[df["NEW_EXISTING"] == seg]
    return float(pd.to_numeric(df["DSCNTC_CNT"], errors="coerce").fillna(0).sum())


def calc_kpi_rates(wk_data, cum_data, dept_sel=""):
    """중단율 = 중단건 / (개발건 + 전월말 활동회원건) × 100 — 주간/월누계/신규/기존"""
    dev_t = load_dev_weekly_by_type(all_years, month, dept_sel).copy()
    act_t = load_prev_month_active_by_type(all_years, month, dept_sel).copy()
    if not dev_t.empty:
        dev_t["YEAR"] = pd.to_numeric(dev_t["YEAR"], errors="coerce").astype(int)
        dev_t["WEEK_OF_MONTH"] = pd.to_numeric(dev_t["WEEK_OF_MONTH"], errors="coerce").astype(int)
        dev_t["DEV_CNT"] = pd.to_numeric(dev_t["DEV_CNT"], errors="coerce").fillna(0)
    if not act_t.empty:
        act_t["YEAR"] = pd.to_numeric(act_t["YEAR"], errors="coerce").astype(int)
        act_t["ACTIVE_CNT"] = pd.to_numeric(act_t["ACTIVE_CNT"], errors="coerce").fillna(0)
    rate = lambda s, d: round(s / d * 100, 2) if d > 0 else 0.0
    out = {}
    for yy in all_years:
        def dev(seg=None, cum=False):
            if dev_t.empty:
                return 0.0
            m = dev_t["YEAR"] == yy
            m &= (dev_t["WEEK_OF_MONTH"] <= week_no) if cum else (dev_t["WEEK_OF_MONTH"] == week_no)
            if cum and week_no == total_weeks:
                m = dev_t["YEAR"] == yy
            if seg:
                m &= dev_t["NEW_EXISTING"] == seg
            return float(dev_t.loc[m, "DEV_CNT"].sum())
        def act(seg=None):
            if act_t.empty:
                return 0.0
            m = act_t["YEAR"] == yy
            if seg:
                m &= act_t["NEW_EXISTING"] == seg
            return float(act_t.loc[m, "ACTIVE_CNT"].sum())
        out[yy] = {
            "wk": rate(wk_data[yy]["total_c"], dev() + act()),
            "cum": rate(cum_data[yy]["total_c"], dev(cum=True) + act()),
            "new": rate(wk_data[yy]["new_c"], dev("신규회원") + act("신규회원")),
            "exist": rate(wk_data[yy]["exist_c"], dev("기존회원") + act("기존회원")),
        }
    return out


def calc_kpi_unpaid(dept_sel=""):
    """미납중단(14,16) — 월(조회월 1일~) / 연 누계(1월 1일~), 종료일은 조회주차 종료일"""
    out = {}
    for yy in all_years:
        to_s = _kpi_cum_to(yy).strftime("%Y%m%d")
        m_df = load_dscntc_detail(yy, datetime.date(yy, month, 1).strftime("%Y%m%d"), to_s, rsn_filter="'14','16'", dept_sel=dept_sel)
        y_df = load_dscntc_detail(yy, datetime.date(yy, 1, 1).strftime("%Y%m%d"), to_s, rsn_filter="'14','16'", dept_sel=dept_sel)
        out[yy] = {"month": _sum_cnt(m_df), "ytd": _sum_cnt(y_df)}
    return out


# 위험 판정 기준: 이번 주 중단율 ÷ 최근 3년 동주차 평균 중단율 (비율)
#   중단율 하나만 사용 — 회원 규모 변화 영향 없음, 중단건 이중 반영 없음, 1주차도 같은 주차끼리 비교
#   구간은 2024.1~2026.10 주간 실적(168주) 시뮬레이션으로 위험 연 약 7회 수준에 맞춤 — 재산정 시 기준 근거 문구도 함께 갱신
KPI_GRADE_BANDS = [(1.50, "danger"), (1.25, "warn"), (1.10, "watch")]   # 이상(>=) 기준, 미만은 양호
KPI_BASE_YEARS = 3


def _prev_cmp_period():
    """직전 비교주차 (연, 월, 주차, 시작일, 종료일) — 2~5주차는 전주, 1주차는 전월 1주차"""
    if week_no > 1:
        py, pm, pw = year, month, week_no - 1
        s, e = week_ranges[pw - 1]
    else:
        py, pm = (year, month - 1) if month > 1 else (year - 1, 12)
        pw = 1
        s, e = calc_week_ranges(py, pm)[0]
    return py, pm, pw, s, e


def calc_kpi_prev_week(dept_sel=""):
    """직전 비교주차 중단건·중단율 — 2~5주차는 전주, 1주차는 미납중단 집중 주차라 전월 1주차"""
    py, pm, pw, s, e = _prev_cmp_period()
    df = load_dscntc_detail(py, s.strftime("%Y%m%d"), e.strftime("%Y%m%d"), dept_sel=dept_sel)
    stop = _sum_cnt(df)
    dev_t = load_dev_weekly_by_type([py], pm, dept_sel)
    act_t = load_prev_month_active_by_type([py], pm, dept_sel)
    dev = 0.0
    if not dev_t.empty:
        wk = pd.to_numeric(dev_t["WEEK_OF_MONTH"], errors="coerce")
        dev = float(pd.to_numeric(dev_t.loc[wk == min(pw, 5), "DEV_CNT"], errors="coerce").fillna(0).sum())
    act = float(pd.to_numeric(act_t["ACTIVE_CNT"], errors="coerce").fillna(0).sum()) if not act_t.empty else 0.0
    denom = dev + act
    return {"label": f"{pm}월 {pw}주차", "stop": stop, "rate": round(stop / denom * 100, 2) if denom > 0 else 0.0}


# 판정 기준 참고자료 — 2024.1~2026.10 주간 실적 168주에 현행 등급 기준을 적용한 결과 (2026-10-27 산출, 기준 재산정 시 갱신)
KPI_GRADE_HISTORY = {2024: (28, 11, 8, 12), 2025: (36, 6, 12, 6), 2026: (26, 15, 5, 3)}   # (양호, 관심, 주의, 위험)
KPI_DANGER_WEEKS = [  # (연, 월, 주차, 이번 주 중단율 %, 최근 3년 동주차 평균 %, 비율)
    (2024, 1, 1, 0.648, 0.341, 1.90), (2024, 1, 2, 0.317, 0.206, 1.54), (2024, 3, 5, 0.144, 0.091, 1.58),
    (2024, 4, 1, 0.621, 0.359, 1.73), (2024, 6, 5, 0.143, 0.086, 1.66), (2024, 7, 1, 0.642, 0.417, 1.54),
    (2024, 8, 1, 0.503, 0.333, 1.51), (2024, 9, 5, 0.200, 0.116, 1.73), (2024, 10, 1, 0.550, 0.351, 1.57),
    (2024, 10, 2, 0.191, 0.113, 1.69), (2024, 11, 5, 0.133, 0.082, 1.61), (2024, 12, 5, 0.337, 0.213, 1.58),
    (2025, 2, 5, 0.188, 0.080, 2.34), (2025, 6, 5, 0.194, 0.116, 1.68), (2025, 8, 5, 0.163, 0.098, 1.67),
    (2025, 9, 1, 0.644, 0.386, 1.67), (2025, 12, 1, 0.652, 0.434, 1.50), (2025, 12, 2, 0.296, 0.150, 1.97),
    (2026, 2, 5, 0.226, 0.132, 1.71), (2026, 3, 5, 0.230, 0.151, 1.52), (2026, 8, 5, 0.202, 0.133, 1.52),
]


# 위험 주차 상세 — 주차별 중단사유 1·2위(비중 %) · 신규/기존 중단 각 마케팅캠페인 1위(해당 구분 내 비중 %)
#   (load_dscntc_by_reason / load_campaign_stop_by_type 기준, 2026-10-27 산출 · '-' = 해당 주차 신규 중단 없음)
KPI_DANGER_DETAIL = {
    (2024, 1, 1): ('장기미납', 57, '개인(경제적)사유', 27, '-', 0, '희망편지쓰기대회', 24),
    (2024, 1, 2): ('개인(경제적)사유', 77, '다른곳지원', 7, '-', 0, '희망편지쓰기대회', 25),
    (2024, 3, 5): ('개인(경제적)사유', 94, '명의변경', 2, '유어턴(1기)', 51, '희망편지쓰기대회', 27),
    (2024, 4, 1): ('장기미납', 72, '개인(경제적)사유', 17, '유어턴(2기)', 28, '희망편지쓰기대회', 24),
    (2024, 6, 5): ('개인(경제적)사유', 95, '다른곳지원', 2, '희망편지쓰기대회', 32, '희망편지쓰기대회', 30),
    (2024, 7, 1): ('장기미납', 72, '개인(경제적)사유', 22, '희망편지쓰기대회', 18, '희망편지쓰기대회', 21),
    (2024, 8, 1): ('장기미납', 85, '개인(경제적)사유', 10, '유어턴(1기)', 14, '희망편지쓰기대회', 23),
    (2024, 9, 5): ('개인(경제적)사유', 96, '명의변경', 1, '희망편지쓰기대회', 22, '희망편지쓰기대회', 29),
    (2024, 10, 1): ('장기미납', 74, '개인(경제적)사유', 14, '희망편지쓰기대회', 24, '희망편지쓰기대회', 23),
    (2024, 10, 2): ('개인(경제적)사유', 95, '다른곳지원', 2, '위기가정(선아)', 24, '희망편지쓰기대회', 30),
    (2024, 11, 5): ('개인(경제적)사유', 95, '명의변경', 2, '희망편지쓰기대회', 19, '희망편지쓰기대회', 31),
    (2024, 12, 5): ('개인(경제적)사유', 71, '만18세아동퇴소', 23, '희망편지쓰기대회', 15, '희망편지쓰기대회', 30),
    (2025, 2, 5): ('개인(경제적)사유', 94, '명의변경', 4, '유어턴(2기)', 36, '희망편지쓰기대회', 25),
    (2025, 6, 5): ('개인(경제적)사유', 94, '다른곳지원', 2, '희망편지쓰기대회', 26, '희망편지쓰기대회', 26),
    (2025, 8, 5): ('개인(경제적)사유', 92, '기타', 5, '보호종료(반쪽자립)', 16, '희망편지쓰기대회', 25),
    (2025, 9, 1): ('장기미납', 72, '개인(경제적)사유', 21, '유어턴(2기)', 22, '희망편지쓰기대회', 21),
    (2025, 12, 1): ('장기미납', 64, '개인(경제적)사유', 23, '유어턴(2기)', 15, '희망편지쓰기대회', 19),
    (2025, 12, 2): ('개인(경제적)사유', 65, '만18세아동퇴소', 31, '유어턴(2기)', 13, '희망편지쓰기대회', 30),
    (2026, 2, 5): ('개인(경제적)사유', 93, '명의변경', 3, '유어턴(2기)', 32, '희망편지쓰기대회', 22),
    (2026, 3, 5): ('개인(경제적)사유', 83, '아동퇴소', 4, '유어턴(2기)', 23, '희망편지쓰기대회', 23),
    (2026, 8, 5): ('개인(경제적)사유', 96, '명의변경', 1, '가족그림편지쓰기대회', 17, '희망편지쓰기대회', 19),
}


def calc_kpi_base_rate(dept_sel=""):
    """최근 3년(전년~3년 전) 동주차 주간 중단율 — calc_kpi_rates 의 주간 중단율과 같은 산식(중단건 ÷ (주차 개발 + 전월 활동))"""
    out = {}
    for yy in range(year - 1, year - 1 - KPI_BASE_YEARS, -1):
        s_, e_ = get_same_week_range(yy, month, week_no)
        stop = _sum_cnt(load_dscntc_detail(yy, s_.strftime("%Y%m%d"), e_.strftime("%Y%m%d"), dept_sel=dept_sel))
        dev_t = load_dev_weekly_by_type([yy], month, dept_sel)
        act_t = load_prev_month_active_by_type([yy], month, dept_sel)
        dev = 0.0
        if not dev_t.empty:
            wk = pd.to_numeric(dev_t["WEEK_OF_MONTH"], errors="coerce")
            dev = float(pd.to_numeric(dev_t.loc[wk == week_no, "DEV_CNT"], errors="coerce").fillna(0).sum())
        act = float(pd.to_numeric(act_t["ACTIVE_CNT"], errors="coerce").fillna(0).sum()) if not act_t.empty else 0.0
        out[yy] = round(stop / (dev + act) * 100, 2) if dev + act > 0 else 0.0
    return out


def _risk_level(ratio):
    """주간 중단율 등급 — 최근 3년 동주차 평균 대비 비율: 1.50 이상 위험 / 1.25 주의 / 1.10 관심 / 그 미만 양호"""
    if ratio is None:
        return "ok"
    for th, lv in KPI_GRADE_BANDS:
        if ratio >= th - 1e-9:
            return lv
    return "ok"


# 등급별 표시: (이모지, 라벨, 진한색, 연한 배경, 글자색, 라벨 애니메이션, 이모지 애니메이션, 박스 애니메이션)
KPI_GRADE_STYLE = {
    "ok":     ("✅", "양호", "#1a9c6e", "#E8F6EF", "#145A32", "animation:kpiOkPulse 2.4s ease-in-out infinite;", "",
               "animation:kpiOkGlow 2.4s ease-in-out infinite;"),
    "watch":  ("👀", "관심", "#F1C40F", "#FEF9E7", "#7D6608", "animation:kpiWatchPulse 1.8s ease-in-out infinite;",
               "animation:kpiBlink 1.8s ease-in-out infinite;", "animation:kpiWatchGlow 1.8s ease-in-out infinite;"),
    "warn":   ("⚠️", "주의", "#E67E22", "#FDEBD0", "#7E3F0B", "animation:kpiWarnShake 1.6s ease-in-out infinite;", "",
               "animation:kpiWarnGlow 1.6s ease-in-out infinite;"),
    "danger": ("🚨", "위험", "#e74c3c", "#FDEDEC", "#922B21", "animation:kpiDangerPulse 1s ease-in-out infinite;",
               "animation:kpiSiren .8s steps(1) infinite;", ""),
}


def _risk_badge(level):
    emo, lbl, main, light, txt, anim, emo_anim, _ = KPI_GRADE_STYLE[level]
    bg, fg = (main, "#fff") if level in ("warn", "danger") else (light, txt)
    return (f'<span style="display:inline-block;margin-left:8px;padding:2px 10px;border-radius:12px;'
            f'background:{bg};color:{fg};border:1px solid {main};font-size:13px;font-weight:900;{anim}">'
            f'<span style="display:inline-block;{emo_anim}">{emo}</span> {lbl}</span>')


def _camp_detail_html(raw, mk):
    """클릭 시 펼침: CRM 세부캠페인명(가두캠페인은 업체 키워드) 중단건 Top3 — raw 는 STOP_CNT 숫자화된 원본 행"""
    det = (raw[raw["MK_CMPGN"] == mk].groupby("DETAIL", as_index=False)["STOP_CNT"].sum()
           .query("STOP_CNT > 0").sort_values("STOP_CNT", ascending=False).head(3))
    hdr = "업체 키워드" if mk == "가두캠페인" else "CRM 세부캠페인명"
    h = ('<div style="margin:6px 0 2px 0;padding:6px 10px;background:#F8F9FB;border-left:3px solid #e74c3c;'
         'border-radius:4px;font-size:13px;font-weight:600;color:#34495E;">'
         f'<div style="font-size:12px;color:#7f8c8d;font-weight:700;margin-bottom:2px;">{hdr} 중단건 Top3</div>')
    for j, (_, x) in enumerate(det.iterrows(), 1):
        h += (f'<div style="display:flex;justify-content:space-between;gap:10px;padding:2px 0;">'
              f'<span>{j}. {html_lib.escape(str(x["DETAIL"]))}</span>'
              f'<b style="white-space:nowrap;">{x["STOP_CNT"]:,.0f}건</b></div>')
    return h + '</div>'


def _help_tip(label, body):
    """열 제목 + ❓ — 물음표 클릭 시 설명 말풍선 펼침 (다시 클릭하면 닫힘)"""
    return ('<span style="display:inline-flex;align-items:center;gap:3px;">' + label +
            '<details style="display:inline-block;position:relative;">'
            '<summary style="list-style:none;cursor:pointer;display:inline-flex;align-items:center;justify-content:center;'
            'width:16px;height:16px;border-radius:50%;background:#2E86DE;color:#fff;font-size:11px;font-weight:900;">?</summary>'
            '<div style="position:absolute;right:0;top:20px;z-index:20;width:190px;padding:6px 9px;background:#fff;'
            'border:1px solid #2E86DE;border-radius:6px;box-shadow:0 3px 10px rgba(0,0,0,.15);text-align:left;'
            'font-size:12px;font-weight:500;color:#2C3E50;line-height:1.5;white-space:normal;">' + body +
            '</div></details></span>')


PAID_AVG_HELP = ('중단 전까지 회비를 <b>평균 몇 번</b> 냈는지<br>'
                 '<span style="color:#7f8c8d;">예) 2번·4번·12번 → 평균 6회</span><br>'
                 '<span style="color:#7f8c8d;font-size:11px;">※ 캠페인은 가입캠페인 기준</span>')

PAID_LOW_HELP = ('<b>3번 이하</b>만 내고 중단한 비율<br>'
                 '<span style="color:#7f8c8d;">예) 10건 중 4건 → 40%</span><br>'
                 '<span style="color:#e74c3c;">30% 이상은 빨간색</span><br>'
                 '<span style="color:#7f8c8d;font-size:11px;">※ 캠페인은 가입캠페인 기준</span>')


def _render_team_html(camp_df, prev_df, yoy_df, seg, hq, top_n, prev_lbl, yoy_lbl, paid_df=None):
    """팀별 중단 Top N (신규/기존 × 본부/지부) — 팀 클릭: 마케팅캠페인 Top3 → 캠페인 클릭: CRM 세부캠페인 Top3
    paid_df: 중단 후원별 중단 전 납입 횟수(후원 기준) — 팀별 평균 납입·3회 이하 비중 표시"""
    hq_lbl = "본부" if hq == "본부" else "지부(본부외)"
    title = (f'<div style="margin-top:10px;font-size:15px;font-weight:800;color:#34495E;">🏢 {hq_lbl} '
             f'<span style="font-size:12px;color:#7f8c8d;font-weight:700;">팀별 Top{top_n}</span></div>')
    num = lambda df: df.assign(STOP_CNT=pd.to_numeric(df["STOP_CNT"], errors="coerce").fillna(0))
    sel = lambda df: num(df[(df["NEW_EXISTING"] == seg) & (df["HQ_DIV"] == hq)]) if not df.empty else df
    raw = sel(camp_df)
    t = raw.groupby("TEAM_NM", as_index=False)["STOP_CNT"].sum() if not raw.empty else raw
    if not t.empty:
        t = t[t["STOP_CNT"] > 0]
    if t.empty:
        return title + '<div style="font-size:13px;color:#95a5a6;margin-top:4px;">팀 데이터 없음</div>'
    base = lambda df: (sel(df).groupby("TEAM_NM")["STOP_CNT"].sum().to_dict() if not df.empty else {})
    prev_map, yoy_map = base(prev_df), base(yoy_df)
    t = t.sort_values("STOP_CNT", ascending=False).head(top_n)
    # 팀별 중단 전 납입 횟수 (후원 기준) — 평균 / 3회 이하 중단 비중
    paid = {}
    if paid_df is not None and not paid_df.empty:
        p = paid_df[(paid_df["NEW_EXISTING"] == seg) & (paid_df["HQ_DIV"] == hq)]
        if not p.empty:
            p = p.assign(PAID_CNT=pd.to_numeric(p["PAID_CNT"], errors="coerce").fillna(0))
            g = p.groupby("TEAM_NM")["PAID_CNT"]
            paid = {k: (v.mean(), (v <= 3).mean() * 100) for k, v in g}
    def _team_camps(team):
        tr = raw[raw["TEAM_NM"] == team]
        c = (tr.groupby("MK_CMPGN", as_index=False)["STOP_CNT"].sum()
             .query("STOP_CNT > 0").sort_values("STOP_CNT", ascending=False).head(3))
        h = ('<div style="margin:6px 0 2px 0;padding:6px 10px;background:#F8F9FB;border-left:3px solid #2E86DE;'
             'border-radius:4px;font-size:13px;font-weight:600;color:#34495E;">'
             '<div style="font-size:12px;color:#7f8c8d;font-weight:700;margin-bottom:2px;">마케팅캠페인 중단건 Top3 (클릭 시 세부)</div>')
        for j, (_, x) in enumerate(c.iterrows(), 1):
            h += ('<details style="padding:2px 0;"><summary style="cursor:pointer;display:flex;justify-content:space-between;gap:10px;">'
                  f'<span>{j}. {html_lib.escape(str(x["MK_CMPGN"]))} <span style="font-size:11px;color:#2E86DE;">▾</span></span>'
                  f'<b style="white-space:nowrap;">{x["STOP_CNT"]:,.0f}건</b></summary>'
                  f'{_camp_detail_html(tr, x["MK_CMPGN"])}</details>')
        return h + '</div>'

    th = 'style="padding:5px 6px;font-size:13px;color:#7f8c8d;font-weight:700;border-bottom:2px solid #DDE3EA;'
    html = (title + '<table style="width:100%;border-collapse:collapse;margin-top:4px;">'
            f'<tr><th {th}text-align:left;">팀 <span style="font-weight:600;font-size:11px;">(클릭 시 캠페인)</span></th>'
            f'<th {th}text-align:right;">주차중단건</th>'
            f'<th {th}text-align:right;">{_help_tip("평균 납입", PAID_AVG_HELP)}</th>'
            f'<th {th}text-align:right;">{_help_tip("3회↓ 중단", PAID_LOW_HELP)}</th>'
            f'<th {th}text-align:right;">{prev_lbl} 대비</th><th {th}text-align:right;">{yoy_lbl} 대비</th></tr>')
    for i, (_, r) in enumerate(t.iterrows()):
        fs, fw, bg = ("18px", "900", "background:#FFF3C4;") if i == 0 else ("15px", "700", "")
        td = f'style="padding:6px;font-size:{fs};font-weight:{fw};color:#2C3E50;border-bottom:1px solid #EEF1F4;vertical-align:top;{bg}'
        dtd = f'style="padding:6px;font-size:13px;border-bottom:1px solid #EEF1F4;vertical-align:top;{bg}'
        name = (f'<details><summary style="cursor:pointer;">{"🚨 " if i == 0 else ""}{i + 1}. {html_lib.escape(str(r["TEAM_NM"]))} '
                f'<span style="font-size:11px;color:#2E86DE;">▾</span></summary>{_team_camps(r["TEAM_NM"])}</details>')
        avg_p, low_p = paid.get(r["TEAM_NM"], (None, None))
        avg_txt = f"{avg_p:,.1f}회" if avg_p is not None else "-"
        low_txt = (f'<span style="color:{"#e74c3c" if low_p >= 30 else "#2C3E50"};font-weight:800;">{low_p:.0f}%</span>'
                   if low_p is not None else "-")
        html += (f'<tr><td {td}text-align:left;">{name}</td>'
                 f'<td {td}text-align:right;">{r["STOP_CNT"]:,.0f}</td>'
                 f'<td {dtd}text-align:right;font-weight:700;">{avg_txt}</td>'
                 f'<td {dtd}text-align:right;">{low_txt}</td>'
                 f'<td {dtd}text-align:right;">{_kpi_delta(r["STOP_CNT"], prev_map.get(r["TEAM_NM"], 0.0))}</td>'
                 f'<td {dtd}text-align:right;">{_kpi_delta(r["STOP_CNT"], yoy_map.get(r["TEAM_NM"], 0.0))}</td></tr>')
    return html + '</table>'


def _render_top3_html(camp_df, prev_df, yoy_df, seg, hq, prev_lbl, yoy_lbl):
    """중단 캠페인 Top3 (신규/기존 × 본부/지부) — 이번 주 중단건 + 전주(1주차는 전월 1주차)·전년 동주차 동일 캠페인 대비 증감"""
    medals = ["🚨 ", "", ""]  # 중단은 부정 지표 — 1위만 경보 이모지 표시
    hq_lbl = "본부" if hq == "본부" else "지부(본부외)"
    title = f'<div style="margin-top:10px;font-size:15px;font-weight:800;color:#34495E;">🏢 {hq_lbl}</div>'
    sel = lambda df: df[(df["NEW_EXISTING"] == seg) & (df["HQ_DIV"] == hq)] if not df.empty else df
    raw = sel(camp_df).copy()
    if not raw.empty:
        raw["STOP_CNT"] = pd.to_numeric(raw["STOP_CNT"], errors="coerce").fillna(0)
    # 마케팅캠페인 단위 합계 (원본은 세부캠페인/업체 키워드 단위)
    d = raw.groupby("MK_CMPGN", as_index=False)["STOP_CNT"].sum() if not raw.empty else raw
    if not d.empty:
        d = d[d["STOP_CNT"] > 0]
    if d.empty:
        return title + '<div style="font-size:13px;color:#95a5a6;margin-top:4px;">캠페인 데이터 없음</div>'

    def _base(df):
        b = sel(df)
        if b.empty:
            return {}
        b = b.assign(STOP_CNT=pd.to_numeric(b["STOP_CNT"], errors="coerce").fillna(0))
        return b.groupby("MK_CMPGN")["STOP_CNT"].sum().to_dict()

    def _detail_html(mk):
        return _camp_detail_html(raw, mk)

    prev_map, yoy_map = _base(prev_df), _base(yoy_df)
    d = d.sort_values("STOP_CNT", ascending=False).head(3)
    th = 'style="padding:5px 6px;font-size:13px;color:#7f8c8d;font-weight:700;border-bottom:2px solid #DDE3EA;'
    html = (title +
            '<table style="width:100%;border-collapse:collapse;margin-top:4px;">'
            f'<tr><th {th}text-align:left;">마케팅캠페인명 <span style="font-weight:600;font-size:11px;">(클릭 시 상세)</span></th>'
            f'<th {th}text-align:right;">주차중단건</th>'
            f'<th {th}text-align:right;">{prev_lbl} 대비</th><th {th}text-align:right;">{yoy_lbl} 대비</th></tr>')
    for i, (_, r) in enumerate(d.iterrows()):
        if i == 0:
            fs, fw, bg = "20px", "900", "background:#FFF3C4;"
        else:
            fs, fw, bg = "15px", "700", ""
        td = f'style="padding:6px;font-size:{fs};font-weight:{fw};color:#2C3E50;border-bottom:1px solid #EEF1F4;vertical-align:top;{bg}'
        dtd = f'style="padding:6px;font-size:13px;border-bottom:1px solid #EEF1F4;vertical-align:top;{bg}'
        name = (f'<details><summary style="cursor:pointer;">{medals[i]}{html_lib.escape(str(r["MK_CMPGN"]))} '
                f'<span style="font-size:11px;color:#2E86DE;">▾</span></summary>{_detail_html(r["MK_CMPGN"])}</details>')
        html += (f'<tr><td {td}text-align:left;">{name}</td>'
                 f'<td {td}text-align:right;">{r["STOP_CNT"]:,.0f}</td>'
                 f'<td {dtd}text-align:right;">{_kpi_delta(r["STOP_CNT"], prev_map.get(r["MK_CMPGN"], 0.0))}</td>'
                 f'<td {dtd}text-align:right;">{_kpi_delta(r["STOP_CNT"], yoy_map.get(r["MK_CMPGN"], 0.0))}</td></tr>')
    return html + '</table>'


def _dept_label(r):
    """선택 항목 표시: 부서명 (코드) · 경로 — 미사용 부서는 표시만 (숨기거나 선택 불가로 만들지 않음)"""
    return f'{"[미사용] " if r["USE_YN"] == "N" else ""}{r["DEPT_NM"]} ({r["DEPT_ID"]}) · {r["DEPT_PATH"]}'


def render_dept_filter():
    """KPI 박스 전용 부서 필터 — CRM 실적 조직도 검색·선택 → (dept_sel 코드 집합, 표시명) 반환, 미선택이면 ("", "")"""
    # 필터 영역 강조 스타일 — st.container(key=) 가 부여하는 .st-key-kpi_dept_box 로 범위 한정
    st.markdown("""<style>
    .st-key-kpi_dept_box {background:#EEF4FB;border:2px solid #2E86DE;border-radius:12px;padding:12px 18px 6px 18px;margin:10px 0;}
    .st-key-kpi_dept_box [data-testid="stWidgetLabel"] p {font-size:17px !important;font-weight:800 !important;color:#1B4F8A !important;}
    .st-key-kpi_dept_box [data-baseweb="select"] > div {min-height:48px;font-size:16px !important;font-weight:700;
        border:2px solid #2E86DE !important;background:#fff;}
    </style>""", unsafe_allow_html=True)
    box = st.container(key="kpi_dept_box")
    box.markdown('<div style="font-size:20px;font-weight:900;color:#1B4F8A;">🏢 부서별 드릴다운 '
                 '<span style="font-size:14px;font-weight:600;color:#5D6D7E;">— CRM 실적 조직도 기준 · 아래 KPI 박스에만 적용됩니다</span></div>',
                 unsafe_allow_html=True)
    c1, c2, c3 = box.columns([2, 5, 1.3])
    with c1:
        search = st.text_input("① 부서명 검색", key="kpi_dept_q", placeholder="비우면 전체 조직도").strip()
    full = load_performance_departments("")
    res = load_performance_departments(search) if search else full
    labels = {r["DEPT_ID"]: _dept_label(r) for _, r in full.iterrows()}
    # 선택값은 DEPT_ID — 검색어를 바꿔도 이미 고른 부서는 선택 유지 (상위 노드 자동 추가 없음)
    chosen = st.session_state.get("kpi_dept_sel", [])
    options = list(dict.fromkeys(res["DEPT_ID"].tolist() + [c for c in chosen if c in labels]))
    with c2:
        sel = st.multiselect(f"② 부서 선택 (검색 결과 {len(res):,}건)", options, format_func=lambda i: labels.get(i, i),
                             key="kpi_dept_sel", placeholder="선택하지 않으면 전사 기준")
    with c3:
        inc = st.checkbox("하위 부서 포함", value=True, key="kpi_dept_inc")
    if search and res.empty:
        box.caption("검색 결과가 없습니다. 검색어를 지우면 전체 조직도가 표시됩니다.")
    codes = expand_dept_codes(sel, inc) if sel else []
    with box.expander("🔎 부서 조회 진단", expanded=False):
        st.markdown(f"- 검색어: `{search or '(없음 · 전체)'}` · 검색 결과 **{len(res):,}건** (전체 조직도 {len(full):,}건)\n"
                    f"- 선택 부서: {', '.join(sel) if sel else '없음 (부서 필터 미적용)'}\n"
                    f"- 하위 부서 포함: {'예' if inc else '아니오'} · 적용 부서 코드 **{len(codes):,}개**")
        mp = load_stop_by_dept_mapping(dscntc_from, dscntc_to)
        if not mp.empty:
            mp["STOP_CNT"] = pd.to_numeric(mp["STOP_CNT"], errors="coerce").fillna(0)
            known = set(full["DEPT_ID"])
            un = mp[~mp["DEPT_CD"].isin(known)]
            st.markdown(f"- 이번 주 중단 중 **실적 조직도에 없는 실적부서**(코드 없음 포함): "
                        f"{len(un):,}개 코드 · **{un['STOP_CNT'].sum():,.1f}건** / 전체 {mp['STOP_CNT'].sum():,.1f}건 "
                        "— 전사 합계에는 포함되며, 부서 선택 시에는 제외됩니다")
            if sel:
                st.markdown(f"- 선택 부서 이번 주 중단: **{mp.loc[mp['DEPT_CD'].isin(codes), 'STOP_CNT'].sum():,.1f}건**")
    if not sel:
        return "", ""
    names = [full.loc[full["DEPT_ID"] == c, "DEPT_NM"].iloc[0] if c in labels else c for c in sel]
    tag = ", ".join(names[:3]) + (f" 외 {len(names) - 3}개" if len(names) > 3 else "")
    return ",".join(codes), tag + (" (하위 포함)" if inc else "")


def render_kpi_strip(wk_data, cum_data):
    # 부서 선택 시 KPI 박스만 부서 기준으로 재조회 (아래 표·차트는 전사 기준 유지)
    #   화면 순서: 헤드라인·판정 박스(top_box) → 부서 필터 → KPI 카드 — 필터 값을 먼저 읽고 top_box 를 나중에 채움
    top_box = st.container()
    dept_sel, dept_path = render_dept_filter()
    if dept_sel:
        wk_data = build_section1_data(dept_sel=dept_sel)
        cum_data = build_section12_data(dept_sel=dept_sel)
    cur, p1 = wk_data[y1], wk_data[y2]
    rates = calc_kpi_rates(wk_data, cum_data, dept_sel)
    unpaid = calc_kpi_unpaid(dept_sel)
    prev = calc_kpi_prev_week(dept_sel)
    camp_df = load_campaign_stop_by_type(year, dscntc_from, dscntc_to, dept_sel)
    # 캠페인 비교: 직전 비교주차(1주차는 전월 1주차) · 전년 동주차 — 신규/기존 판정은 각 기간의 연도 기준
    _cpy, _, _, _cps, _cpe = _prev_cmp_period()
    camp_prev_df = load_campaign_stop_by_type(_cpy, _cps.strftime("%Y%m%d"), _cpe.strftime("%Y%m%d"), dept_sel)
    _cys, _cye = get_same_week_range(y2, month, week_no)
    camp_yoy_df = load_campaign_stop_by_type(y2, _cys.strftime("%Y%m%d"), _cye.strftime("%Y%m%d"), dept_sel)
    r1, r2, r3 = rates[y1], rates[y2], rates[y3]
    # 비교 라벨: 짧은 이름 + 작은 회색 보조표기(연도/주차)
    cmp_lbl = lambda nm, sub: f'{nm}<span style="font-size:11px;color:#95a5a6;font-weight:600;margin-left:3px;">{sub}</span>'
    lbl_y2, lbl_y3 = cmp_lbl("전년", f"'{str(y2)[-2:]}"), cmp_lbl("전전년", f"'{str(y3)[-2:]}")
    vs = lambda c, b2, b3, pp=False: [(lbl_y2, _kpi_delta(c, b2, is_pp=pp)), (lbl_y3, _kpi_delta(c, b3, is_pp=pp))]

    # 위험 판정: 이번 주 중단율 ÷ 최근 3년 동주차 평균 중단율 — 양호/관심/주의/위험
    is_w1 = week_no == 1
    prev_nm = "전월 1주차" if is_w1 else "전주"
    wow_pp, yoy_pp = r1["wk"] - prev["rate"], r1["wk"] - r2["wk"]
    base_rates = calc_kpi_base_rate(dept_sel)
    base_avg = sum(base_rates.values()) / len(base_rates) if base_rates else 0.0
    risk_ratio = r1["wk"] / base_avg if base_avg > 0 else None
    risk = _risk_level(risk_ratio)
    lbl_prev = cmp_lbl("전월 1주" if is_w1 else "전주", prev["label"].replace("월 ", "/").replace("주차", "주"))
    base_txt = " · ".join(f"{yy}년 {v:.2f}%" for yy, v in base_rates.items())
    ratio_txt = f"{risk_ratio:.2f}배" if risk_ratio is not None else "-"
    risk_detail = (f'<b>주간 중단율</b> {r1["wk"]:.2f}% &nbsp;÷&nbsp; 최근 3년 동주차 평균 {base_avg:.2f}% '
                   f'= <b style="font-size:20px;">{ratio_txt}</b>'
                   f'<div style="font-size:13px;color:#5D6D7E;">최근 3년 동주차: {base_txt}'
                   f' &nbsp;·&nbsp; 참고: 전년 동주차 대비 {yoy_pp:+.2f}%p · {prev_nm} 대비 {wow_pp:+.2f}%p</div>')

    # 카드: (제목, [(소제목, 값, 부가설명, 증감행)], 하단 html)
    cards = [
        ("중단", [
            ("이번 주", f'{cur["total_c"]:,.0f}<small>건</small>', f'{cur["total_m"]:,}명',
             [(lbl_prev, _kpi_delta(cur["total_c"], prev["stop"]))]
             + vs(cur["total_c"], p1["total_c"], wk_data[y3]["total_c"])),
            ("월 누계", f'{cum_data[y1]["total_c"]:,.0f}<small>건</small>', f'{month}월 1일~{week_no}주차',
             vs(cum_data[y1]["total_c"], cum_data[y2]["total_c"], cum_data[y3]["total_c"])),
        ], ""),
        ("중단율", [
            ("주간" + ("" if dept_sel else _risk_badge(risk)), f'{r1["wk"]:.2f}<small>%</small>', "개발+전월활동 대비",
             [(lbl_prev, _kpi_delta(r1["wk"], prev["rate"], is_pp=True)),
              (lbl_y2, _kpi_delta(r1["wk"], r2["wk"], is_pp=True)),
              (lbl_y3, _kpi_delta(r1["wk"], r3["wk"], is_pp=True))]),
            ("월 누계", f'{r1["cum"]:.2f}<small>%</small>', f'{month}월 1일~{week_no}주차', vs(r1["cum"], r2["cum"], r3["cum"], True)),
        ], ""),
        ("미납중단", [
            ("월", f'{unpaid[y1]["month"]:,.0f}<small>건</small>', f'{month}월 1일~{week_no}주차',
             vs(unpaid[y1]["month"], unpaid[y2]["month"], unpaid[y3]["month"])),
            ("연 누계", f'{unpaid[y1]["ytd"]:,.0f}<small>건</small>', f'1월 1일~{month}월 {week_no}주차',
             vs(unpaid[y1]["ytd"], unpaid[y2]["ytd"], unpaid[y3]["ytd"])),
        ], ""),
    ]
    seg_cards = [
        ("신규회원", [
            ("중단", f'{cur["new_c"]:,.0f}<small>건</small>', f'전체의 {(cur["new_c"] / cur["total_c"] * 100) if cur["total_c"] else 0:.0f}%',
             vs(cur["new_c"], p1["new_c"], wk_data[y3]["new_c"])),
            ("중단율", f'{r1["new"]:.2f}<small>%</small>', "신규 개발+전월활동 대비", vs(r1["new"], r2["new"], r3["new"], True)),
        ], ""),
        ("기존회원", [
            ("중단", f'{cur["exist_c"]:,.0f}<small>건</small>', f'전체의 {(cur["exist_c"] / cur["total_c"] * 100) if cur["total_c"] else 0:.0f}%',
             vs(cur["exist_c"], p1["exist_c"], wk_data[y3]["exist_c"])),
            ("중단율", f'{r1["exist"]:.2f}<small>%</small>', "기존 개발+전월활동 대비", vs(r1["exist"], r2["exist"], r3["exist"], True)),
        ], ""),
    ]
    # 신규/기존 마케팅캠페인 Top3 — KPI 카드와 분리된 별도 박스
    camp_prev_lbl = "전월 1주" if is_w1 else "전주"
    camp_boxes = [(f'{seg[:2]}중단 캠페인 TOP3',
                   "".join(_render_top3_html(camp_df, camp_prev_df, camp_yoy_df, seg, hq, camp_prev_lbl, "전년 동주")
                           for hq in ("본부", "지부")))
                  for seg in ("신규회원", "기존회원")]

    # 한 줄 헤드라인
    diff = cur["total_c"] - p1["total_c"]
    trend = "증가" if diff > 0 else ("감소" if diff < 0 else "동일")
    head_c = "#e74c3c" if diff > 0 else "#2e86de"
    dept_tag = (f'<span style="display:inline-block;margin-right:8px;padding:2px 10px;border-radius:6px;'
                f'background:#2C3E50;color:#fff;font-size:15px;font-weight:800;">{html_lib.escape(dept_path)}</span>'
                if dept_sel else "")
    headline = (f'{dept_tag}{year}년 {month}월 {week_no}주차 중단은 <b>{cur["total_c"]:,.0f}건</b>으로 전년 동주차 대비 '
                f'<b style="color:{head_c};">{abs(diff):,.0f}건 {trend}</b>, 중단율은 '
                f'<b style="color:{"#e74c3c" if r1["wk"] > r2["wk"] else "#2e86de"};">{r1["wk"] - r2["wk"]:+.2f}%p</b> 변동했습니다.')

    # 경영진 참고용 판정 기준표 (박스 하단 공통) — 이번 주 해당 등급 행 강조
    th = 'style="padding:4px 10px;border-bottom:2px solid #D5DBE1;text-align:left;font-weight:800;'
    td = 'style="padding:4px 10px;border-bottom:1px solid #E5E8EC;'
    bands = {lv: th_ for th_, lv in KPI_GRADE_BANDS}
    grade_rows = [("ok", f'{bands["watch"]:.2f}배 미만', "평소 수준"),
                  ("watch", f'{bands["watch"]:.2f} ~ {bands["warn"]:.2f}배', f'평소보다 {bands["watch"] * 100 - 100:.0f}% 이상 높음'),
                  ("warn", f'{bands["warn"]:.2f} ~ {bands["danger"]:.2f}배', f'평소보다 {bands["warn"] * 100 - 100:.0f}% 이상 높음'),
                  ("danger", f'{bands["danger"]:.2f}배 이상', f'평소보다 {bands["danger"] * 100 - 100:.0f}% 이상 높음')]
    rows_html = ""
    for lv, rng, desc in grade_rows:
        emo, lbl, main, light, txt, *_ = KPI_GRADE_STYLE[lv]
        on = lv == risk
        rows_html += (f'<tr style="{"background:#FFF8DC;font-weight:800;" if on else ""}">'
                      f'<td {td}white-space:nowrap;"><span style="display:inline-block;width:12px;height:12px;border-radius:3px;'
                      f'background:{main};margin-right:6px;vertical-align:middle;"></span><b style="color:{txt};font-size:15px;">{emo} {lbl}</b></td>'
                      f'<td {td}white-space:nowrap;">{rng}</td><td {td}">{desc}</td>'
                      f'<td {td}white-space:nowrap;">{"◀ 이번 주 " + ratio_txt if on else ""}</td></tr>')
    # 참고자료: 과거 주차별 등급 결과 · 위험 주차 (작게, 클릭 시 펼침)
    sm_th = 'style="padding:2px 8px;border-bottom:1px solid #D5DBE1;text-align:center;font-weight:800;'
    sm_td = 'style="padding:2px 8px;border-bottom:1px solid #EEF1F4;text-align:center;'
    g_head = "".join(f'<th {sm_th}color:{KPI_GRADE_STYLE[lv][4]};">{KPI_GRADE_STYLE[lv][1]}</th>' for lv in ("ok", "watch", "warn", "danger"))
    g_rows = "".join(f'<tr><td {sm_td}font-weight:700;">{yy}년{" (~10월)" if yy == 2026 else ""}</td>'
                     + "".join(f'<td {sm_td}">{n}주</td>' for n in cnts) + f'<td {sm_td}color:#7f8c8d;">{sum(cnts)}주</td></tr>'
                     for yy, cnts in KPI_GRADE_HISTORY.items())
    def _d_row(yy, mm, ww, cr, br, rt):
        r1n, r1p, r2n, r2p, nwn, nwp, exn, exp_ = KPI_DANGER_DETAIL.get((yy, mm, ww), ("-", 0, "-", 0, "-", 0, "-", 0))
        camp = lambda n, pct: f'<b>{html_lib.escape(n)}</b> {pct}%' if n != "-" else '<span style="color:#B0B7BF;">신규 중단 없음</span>'
        return (f'<tr><td {sm_td}white-space:nowrap;">{yy}년 {mm}월 {ww}주차</td><td {sm_td}">{cr:.2f}%</td><td {sm_td}">{br:.2f}%</td>'
                f'<td {sm_td}color:#c0392b;font-weight:800;">{rt:.2f}배</td>'
                f'<td {sm_td}text-align:left;white-space:nowrap;"><b>{html_lib.escape(r1n)}</b> {r1p}% · {html_lib.escape(r2n)} {r2p}%</td>'
                f'<td {sm_td}text-align:left;white-space:nowrap;">{camp(nwn, nwp)}</td>'
                f'<td {sm_td}text-align:left;white-space:nowrap;">{camp(exn, exp_)}</td></tr>')
    d_rows = "".join(_d_row(*w) for w in KPI_DANGER_WEEKS)
    # 위험 주차 요약 (21개 주차 상세에서 집계)
    wk_type = {1: 0, 2: 0, 5: 0}
    for yy, mm, ww, *_ in KPI_DANGER_WEEKS:
        wk_type[ww] = wk_type.get(ww, 0) + 1
    unpaid_top = sum(1 for k, v in KPI_DANGER_DETAIL.items() if v[0] == "장기미납")
    new_cnt = {}
    for v in KPI_DANGER_DETAIL.values():
        if v[4] != "-":
            new_cnt[v[4]] = new_cnt.get(v[4], 0) + 1
    new_top = sorted(new_cnt.items(), key=lambda x: -x[1])[:2]
    ex_names = {v[6] for v in KPI_DANGER_DETAIL.values()}
    ex_rng = [v[7] for v in KPI_DANGER_DETAIL.values()]
    danger_summary = (
        '<div style="min-width:240px;max-width:340px;padding:6px 10px;background:#FDF2F1;border:1px solid #F5B7B1;border-radius:6px;">'
        '<div style="font-weight:800;margin-bottom:4px;color:#922B21;">🔍 위험 주차 요약</div>'
        f'<div>① <b>언제?</b> 월 1주차 {wk_type.get(1, 0)}회 · 월말 5주차 {wk_type.get(5, 0)}회 · 2주차 {wk_type.get(2, 0)}회 — '
        '월초·월말에 집중</div>'
        f'<div>② <b>왜?</b> 1주차는 <b>장기미납</b>(미납 정리) 중단이 1위({unpaid_top}회, 비중 57~85%), '
        '그 외 주차는 <b>개인(경제적)사유</b>가 1위(비중 65~96%)</div>'
        f'<div>③ <b>어떤 캠페인?</b> 기존중단은 '
        + (f'모든 주차에서 <b>{html_lib.escape(next(iter(ex_names)))}</b>가 1위(비중 {min(ex_rng)}~{max(ex_rng)}%)'
           if len(ex_names) == 1 else f'1위 캠페인 {len(ex_names)}종')
        + f' · 신규중단은 <b>{html_lib.escape(new_top[0][0])}</b> {new_top[0][1]}회, '
        f'{html_lib.escape(new_top[1][0])} {new_top[1][1]}회 순으로 1위</div>'
        '</div>')
    hist_html = (
        '<details style="margin-top:6px;padding:4px 12px;background:#FAFBFC;border-left:4px solid #AAB7C4;border-radius:4px;'
        'font-size:12px;color:#5D6D7E;line-height:1.5;">'
        '<summary style="cursor:pointer;font-weight:800;font-size:13px;">📎 참고자료: 2024~2026년 주차별 4단계 등급 판정 결과 및 위험 주차 '
        '<span style="font-weight:600;font-size:11px;color:#95a5a6;">(클릭하여 펼치기/접기)</span></summary>'
        '<div style="display:flex;gap:18px;flex-wrap:wrap;margin-top:4px;">'
        f'<div><div style="font-weight:800;margin-bottom:2px;">연도별 등급 분포</div><table style="border-collapse:collapse;">'
        f'<tr><th {sm_th}">연도</th>{g_head}<th {sm_th}">합계</th></tr>{g_rows}</table></div>'
        f'<div><div style="font-weight:800;margin-bottom:2px;">🚨 위험 판정 주차 ({len(KPI_DANGER_WEEKS)}개)</div>'
        '<div style="max-height:180px;overflow-y:auto;"><table style="border-collapse:collapse;">'
        f'<tr><th {sm_th}">주차</th><th {sm_th}">중단율</th><th {sm_th}">3년 평균</th><th {sm_th}">비율</th>'
        f'<th {sm_th}">주요 중단사유 (비중)</th><th {sm_th}">신규중단 1위 마케팅캠페인 (비중)</th>'
        f'<th {sm_th}">기존중단 1위 마케팅캠페인 (비중)</th></tr>{d_rows}</table></div></div>'
        + danger_summary +
        '</div>'
        '<div style="margin-top:4px;font-size:11px;color:#95a5a6;">※ 2024.1~2026.10 주간 실적(168주)에 현행 기준을 적용한 결과 · 중단사유·캠페인 비중은 해당 주차 중단건 기준 · 2026-10-27 산출</div>'
        '</details>')
    criteria_html = (
        '<div style="margin-top:8px;padding:8px 12px;background:rgba(255,255,255,0.8);border-radius:6px;'
        'font-size:13px;color:#34495E;line-height:1.5;">'
        '<div style="font-weight:800;margin-bottom:4px;">📌 판정 기준 (이번 주 중단율 ÷ 최근 3년 같은 주차 평균 중단율)</div>'
        '<table style="border-collapse:collapse;width:100%;">'
        f'<tr><th {th}">등급</th><th {th}">비율</th><th {th}">의미</th><th {th}"></th></tr>'
        + rows_html +
        '</table>'
        # 기준 근거 (2024.1~2026.10 주간 실적 168주 시뮬레이션 — 기준 재산정 시 함께 갱신) — 클릭 시 펼침
        '<details style="margin-top:8px;padding:6px 12px;background:#F4F6F8;border-left:4px solid #5D6D7E;border-radius:4px;'
        'font-size:13px;color:#34495E;line-height:1.7;">'
        '<summary style="cursor:pointer;font-weight:800;font-size:14px;">💡 왜 이 기준인가? <span style="font-weight:600;font-size:12px;color:#7f8c8d;">(클릭하여 펼치기/접기)</span></summary>'
        '<div>① <b>같은 주차끼리 비교합니다</b> — 이번 주 중단율을 최근 3년 같은 월·주차의 평균과 비교하므로, '
        '미납중단이 몰리는 1주차도 별도 기준 없이 같은 방식으로 판정합니다.</div>'
        '<div>② <b>중단율 하나로 봅니다</b> — 중단율은 회원 규모(개발+전월 활동)로 나눈 값이라, 회원이 늘어 중단건이 '
        '함께 늘어난 경우는 위험으로 잡지 않습니다.</div>'
        '<div>③ <b>과거 실적으로 검증했습니다</b> — 2024.1~2026.10 주간 실적 <b>168주</b>에 이 기준을 그대로 적용해 보니, '
        '절반 이상의 주는 양호로 판정되고 <b>평소보다 뚜렷하게 높았던 주만</b> 관심·주의·위험으로 걸러졌습니다. '
        '매주 경보가 울려 무뎌지지 않으면서도, 실제 이상 징후는 놓치지 않는 수준입니다.</div>'
        '</details>'
        + hist_html +
        '</div>')

    # 상태 제목: 큰 색상 라벨 + 한 줄 메시지 (경영진 가독성) — label=(이모지, 텍스트), 이모지는 별도 애니메이션
    status_head = lambda label, bg, color, msg, anim="", emo_anim="": (
        '<div style="display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-bottom:6px;">'
        f'<span style="display:inline-block;padding:6px 20px;border-radius:10px;background:{bg};color:#fff;'
        f'font-size:30px;font-weight:900;letter-spacing:2px;line-height:1.2;{anim}">'
        f'<span style="display:inline-block;{emo_anim}">{label[0]}</span> {label[1]}</span>'
        f'<span style="font-size:22px;font-weight:900;color:{color};">{msg}</span></div>')

    if dept_sel:
        # 부서 조회: 위험/주의 판정은 전사 기준으로만 운영 — 수치 비교만 표시, 기준표는 참고용으로 접어 둠
        inactive_note = ('<div style="margin-top:4px;font-size:13px;color:#7f8c8d;">※ CRM 실적 조직도 기준 실적부서(후원 실적부서 코드) 집계입니다. '
                         '조직도에 없는 실적부서 건은 부서 선택 시 제외되며 전사 수치에는 포함됩니다.</div>')
        alert_html = ('<div style="background:#F4F6F8;border:2px solid #AAB7C4;border-left:8px solid #5D6D7E;border-radius:8px;'
                      'padding:12px 16px;margin-bottom:12px;color:#34495E;font-size:17px;line-height:1.6;">'
                      + status_head(("ℹ️", "부서별 조회"), "#5D6D7E", "#34495E", "등급 판정은 전사 기준으로만 운영합니다 (수치 비교 참고용)")
                      + risk_detail + inactive_note
                      + '<details style="margin-top:6px;"><summary style="cursor:pointer;font-size:14px;font-weight:800;color:#5D6D7E;">'
                        '📌 판정 기준 보기 (전사 기준 · 참고용)</summary>' + criteria_html + '</details></div>')
    else:
        emo, lbl, main, light, txt, anim, emo_anim, box_anim = KPI_GRADE_STYLE[risk]
        msg = {"ok": "주간 중단율이 최근 3년 같은 주차 평균 수준으로 안정적입니다",
               "watch": f"주간 중단율이 최근 3년 같은 주차 평균보다 {ratio_txt} 높아 관심이 필요합니다",
               "warn": f"주간 중단율이 최근 3년 같은 주차 평균보다 {ratio_txt} 높아 주의가 필요합니다",
               "danger": f"주간 중단율이 최근 3년 같은 주차 평균보다 {ratio_txt} 높습니다"}[risk]
        alert_html = (f'<div style="background:{light};border:2px solid {main};border-left:8px solid {main};border-radius:8px;'
                      f'padding:12px 16px;margin-bottom:12px;color:{txt};font-size:17px;line-height:1.6;{box_anim}">'
                      + status_head((emo, lbl), main, txt, msg, anim, emo_anim)
                      + risk_detail + criteria_html + '</div>')

    small_tag = '<small style="font-size:17px;font-weight:700;margin-left:2px;">'

    def card_html(title, parts, extra, accent):
        h = (f'<div style="background:#F7F9FC;border-radius:10px;padding:14px 16px;border-top:4px solid {accent};">'
             f'<div style="font-size:18px;font-weight:900;color:#2C3E50;margin-bottom:6px;">{title}</div>'
             f'<div style="display:grid;grid-template-columns:repeat({len(parts)},1fr);gap:14px;">')
        for i, (lbl, val, sub, rows) in enumerate(parts):
            sep = "border-left:1px dashed #C9D1DB;padding-left:14px;" if i else ""
            h += (f'<div style="{sep}"><div style="font-size:15px;font-weight:800;color:#5D6D7E;">{lbl}</div>'
                  f'<div style="font-size:34px;font-weight:900;color:#2C3E50;line-height:1.25;">{val.replace("<small>", small_tag)}</div>'
                  f'<div style="font-size:13px;color:#7f8c8d;margin-bottom:6px;">{sub}</div>')
            # 비교 행: 라벨(좌) / 증감(우) 정렬표 — 줄바꿈 없이 한 줄
            h += '<table style="width:100%;border-collapse:collapse;border-top:1px solid #E1E7EF;">'
            for rl, v in rows:
                h += (f'<tr><td style="padding:4px 0;font-size:13px;color:#5D6D7E;font-weight:700;white-space:nowrap;">{rl}</td>'
                      f'<td style="padding:4px 0;font-size:14px;text-align:right;white-space:nowrap;">{v}</td></tr>')
            h += '</table></div>'
        return h + '</div>' + extra + '</div>'

    html = ('<style>@keyframes kpiBlink{0%,100%{opacity:1}50%{opacity:.45}}'
            '@keyframes kpiOkGlow{0%,100%{box-shadow:0 0 0 0 rgba(26,156,110,0)}50%{box-shadow:0 0 14px 3px rgba(26,156,110,.35)}}'
            '@keyframes kpiOkPulse{0%,100%{transform:scale(1)}50%{transform:scale(1.06)}}'
            # 관심: 노란 glow·부드러운 확대 / 주의: 주황 glow + 흔들림
            '@keyframes kpiWatchPulse{0%,100%{transform:scale(1)}50%{transform:scale(1.05)}}'
            '@keyframes kpiWatchGlow{0%,100%{box-shadow:0 0 0 0 rgba(241,196,15,0)}50%{box-shadow:0 0 14px 3px rgba(241,196,15,.45)}}'
            '@keyframes kpiWarnGlow{0%,100%{box-shadow:0 0 0 0 rgba(230,126,34,0)}50%{box-shadow:0 0 16px 4px rgba(230,126,34,.45)}}'
            # 위험: 라벨 확대·붉은 glow 맥동 / 사이렌: 켜짐(밝게·빛번짐)↔꺼짐(어둡게) 점멸
            '@keyframes kpiDangerPulse{0%,100%{transform:scale(1);box-shadow:0 0 0 0 rgba(231,76,60,0)}'
            '50%{transform:scale(1.08);box-shadow:0 0 18px 6px rgba(231,76,60,.55)}}'
            '@keyframes kpiSiren{0%{filter:brightness(1.6) drop-shadow(0 0 6px #ff1a1a) drop-shadow(0 0 12px #ff5c5c);opacity:1}'
            '50%{filter:brightness(.55) grayscale(.4);opacity:.55}}'
            # 주의: 좌우 흔들림
            '@keyframes kpiWarnShake{0%,60%,100%{transform:rotate(0) scale(1)}10%,30%,50%{transform:rotate(-3deg) scale(1.04)}'
            '20%,40%{transform:rotate(3deg) scale(1.04)}}</style>'
            # 상단(헤드라인+판정 박스) — 부서 필터 위에 배치
            f'<div style="background:#fff;border:1px solid #E1E7EF;border-radius:12px;padding:16px 20px 4px 20px;margin:6px 0 0 0;">'
            f'<div style="font-size:18px;color:#2C3E50;margin-bottom:12px;">📊 {headline}</div>'
            + alert_html + '</div>')
    with top_box:
        st.markdown(html, unsafe_allow_html=True)
    # 하단(KPI 카드) — 부서 필터 아래에 배치
    html = ('<div style="background:#fff;border:1px solid #E1E7EF;border-radius:12px;padding:16px 20px;margin:0 0 20px 0;">'
            f'<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:14px;">')
    for c, accent in zip(cards, ["#1a9c6e", "#1a9c6e", "#F39C12"]):
        html += card_html(*c, accent)
    html += '</div><div style="display:grid;grid-template-columns:repeat(2,1fr);gap:14px;">'
    for c, accent in zip(seg_cards, ["#5B7DB1", "#8E44AD"]):
        html += card_html(*c, accent)
    html += '</div></div>'
    st.markdown(html, unsafe_allow_html=True)
    # 마케팅캠페인 Top3 박스 (신규/기존) — 카드 색상과 맞춘 강조 테두리
    html = ''
    for boxes in (camp_boxes,):
        html += '<div style="display:grid;grid-template-columns:repeat(2,1fr);gap:14px;margin:0 0 20px 0;">'
        for (seg, body), accent, bg in zip(boxes, ["#5B7DB1", "#8E44AD"], ["#EEF3FA", "#F4ECF8"]):
            html += (f'<div style="background:{bg};border:2px solid {accent};border-radius:12px;padding:14px 18px;">'
                     f'<div style="display:inline-block;padding:3px 12px;border-radius:6px;background:{accent};color:#fff;'
                     f'font-size:17px;font-weight:900;">{seg}</div>'
                     f'<div style="background:#fff;border-radius:8px;padding:4px 10px 8px 10px;margin-top:8px;">{body}</div></div>')
        html += '</div>'
    st.markdown(html, unsafe_allow_html=True)


# =====================================================
# 1-1) 3개년 전체중단(신규/기존) + 그 중 미납중단 건·비중
# =====================================================
def render_unpaid_gap_chart(all_data, excl_data):
    seg_order = ["미납중단 외", "미납중단"]
    grp_order = ["신규", "기존"]
    yr_order = [f"{y}년" for y in [y3, y2, y1]]
    rows, tops, trend_txt = [], [], []
    for grp, key in [("신규", "new_c"), ("기존", "exist_c")]:
        prev_tot = None
        for ord_i, yy in enumerate([y3, y2, y1]):
            tot = float(all_data[yy][key])
            unp = max(tot - float(excl_data[yy][key]), 0.0)
            oth = tot - unp
            share = (unp / tot * 100) if tot else 0.0
            yl, cur = f"{yy}년", yy == y1
            rows.append({"구분": grp, "연도": yl, "항목": "미납중단 외", "건": oth, "cur": cur})
            rows.append({"구분": grp, "연도": yl, "항목": "미납중단", "건": unp, "cur": cur})
            tops.append({"구분": grp, "연도": yl, "전체": tot, "미납": unp, "비중": share, "cur": cur,
                         "총라벨": f"{tot:,.0f}건",
                         "미납라벨": f"미납 {unp:,.0f}건 ({share:.0f}%)" if unp > 0 else "미납 0건",
                         "ord": ord_i,
                         "증감라벨": (f"{'▲' if tot >= prev_tot else '▼'} {(tot - prev_tot) / prev_tot * 100:+.1f}%"
                                   if prev_tot else ""),
                         "증감색": "up" if (prev_tot and tot > prev_tot) else "down"})
            prev_tot = tot
        first, last = float(all_data[y3][key]), float(all_data[y1][key])
        if first:
            chg = (last - first) / first * 100
            c = "#e74c3c" if chg > 0 else "#2e86de"
            trend_txt.append(f'{grp} {str(y3)[2:]}→{str(y1)[2:]}년 <b style="color:{c};">{chg:+.1f}%</b>')
    df, tdf = pd.DataFrame(rows), pd.DataFrame(tops)
    if tdf["전체"].sum() == 0:
        st.info("데이터가 없습니다.")
        return
    x = alt.X("구분:N", sort=grp_order, title=None,
              axis=alt.Axis(labelFontSize=14, labelFontWeight="bold", labelColor="#2C3E50", labelAngle=0,
                            ticks=False, domain=False, labelPadding=26))
    xo = alt.XOffset("연도:N", sort=yr_order)
    tips = [alt.Tooltip("구분:N"), alt.Tooltip("연도:N"), alt.Tooltip("전체:Q", format=",.0f", title="전체 중단(건)"),
            alt.Tooltip("미납:Q", format=",.0f", title="미납중단(건)"), alt.Tooltip("비중:Q", format=".1f", title="미납 비중(%)")]
    bars = alt.Chart(df).mark_bar(size=48, cornerRadiusTopLeft=3, cornerRadiusTopRight=3).encode(
        x=x, xOffset=xo,
        y=alt.Y("sum(건):Q", stack="zero", title="중단(건)",
                axis=alt.Axis(format=",.0f", labelFontSize=11, grid=True, gridColor="#EEF1F4", domain=False, ticks=False)),
        color=alt.Color("항목:N", sort=seg_order, scale=alt.Scale(domain=seg_order, range=["#5B7DB1", "#F39C12"]),
                        legend=alt.Legend(orient="top", title=None, labelFontSize=12, symbolType="square", symbolSize=140)),
        order=alt.Order("항목:N", sort="ascending"),
        opacity=alt.condition(alt.datum.cur, alt.value(1.0), alt.value(0.5)),
    )
    hover = alt.Chart(tdf).mark_bar(size=48, opacity=0).encode(x=x, xOffset=xo, y="전체:Q", tooltip=tips)
    tot_lbl = alt.Chart(tdf).mark_text(dy=-24, fontSize=13, fontWeight="bold", color="#2C3E50").encode(
        x=x, xOffset=xo, y="전체:Q", text="총라벨:N")
    unp_lbl = alt.Chart(tdf).mark_text(dy=-9, fontSize=11, fontWeight="bold", color="#D35400").encode(
        x=x, xOffset=xo, y="전체:Q", text="미납라벨:N")
    trend = alt.Chart(tdf).mark_line(strokeWidth=2, strokeDash=[5, 3], color="#34495E",
                                     point=alt.OverlayMarkDef(size=55, filled=True, color="#34495E")).encode(
        x=x, xOffset=xo, y="전체:Q", detail="구분:N", order="ord:Q")
    chg_df = tdf[tdf["증감라벨"] != ""]
    chg_lbl = alt.Chart(chg_df).mark_text(dy=-40, fontSize=12, fontWeight="bold").encode(
        x=x, xOffset=xo, y="전체:Q", text="증감라벨:N",
        color=alt.Color("증감색:N", scale=alt.Scale(domain=["up", "down"], range=["#e74c3c", "#2e86de"]), legend=None))
    yr_lbl = alt.Chart(tdf).mark_text(dy=8, fontSize=11, color="#7f8c8d", baseline="top").encode(
        x=x, xOffset=xo, y=alt.datum(0), text="연도:N")
    st.markdown('<div style="font-weight:800;font-size:15px;color:#2C3E50;border-left:4px solid #F39C12;'
                'padding:2px 0 2px 10px;margin:6px 0 4px 0;">3개년 전체 중단(신규/기존) 중 미납중단 비중'
                '<span style="font-size:11px;font-weight:500;color:#8e99a4;margin-left:8px;">'
                '막대 = 1-1) 전체 중단 · 주황 = 그 중 미납중단 · 점선 = 전년 대비 증감 추세</span>'
                '<div style="font-size:12px;font-weight:600;color:#34495E;margin-top:3px;">📈 '
                + ' &nbsp;|&nbsp; '.join(trend_txt) + '</div></div>',
                unsafe_allow_html=True)
    st.altair_chart((bars + hover + trend + tot_lbl + unp_lbl + chg_lbl + yr_lbl).resolve_scale(color="independent").properties(height=400).configure_view(strokeWidth=0),
                    use_container_width=True)

# =====================================================
# 탭 생성
# =====================================================
# 회원통계보고서와 동일한 사이드바 세로 포스트잇 탭
if week_no == 1:
    TAB_KEYS = ["excl", "unpaid"]
    TAB_SHORT_LABELS = [f"{month}월\n\n1주\n\n**전체**", f"{month}월\n\n1주\n\n**미납중단**"]
else:
    TAB_KEYS = ["all"]
    TAB_SHORT_LABELS = [f"{month}월\n\n{week_no}주"]
TAB_STYLES = [
    {"active": "#FFE082", "color": "#5D4037", "border": "#FFB300"},
    {"active": "#B2DFDB", "color": "#004D40", "border": "#00897B"},
]
if st.session_state.get("wk_active_tab") not in TAB_KEYS:
    st.session_state.wk_active_tab = TAB_KEYS[0]

_postit_btn_css = """<style>
[data-testid="stSidebar"] { width: 76px !important; min-width: 76px !important; max-width: 76px !important; }
[data-testid="stSidebar"] > div:first-child { width: 76px !important; }
[data-testid="stSidebar"] [data-testid="stSidebarContent"] { padding: 8px 4px !important; }
[data-testid="stSidebar"] [data-testid="stSidebarCollapseButton"] { display: none !important; }
[data-testid="stSidebar"] .stElementContainer { margin-bottom: 0px !important; padding-bottom: 0px !important; }
[data-testid="stSidebar"] .stVerticalBlock > div { gap: 0px !important; }
"""
for i, key in enumerate(TAB_KEYS):
    s = TAB_STYLES[i]
    if st.session_state.wk_active_tab == key:
        bg, text_color, fw, opacity = s["active"], s["color"], "800", "1"
        shadow = "2px 2px 8px rgba(0,0,0,0.15)"
        bdr_bottom = f"border-bottom:3px solid {s['border']};"
    else:
        bg, text_color, fw, opacity = "#f0f0f0", "#9e9e9e", "500", "0.7"
        shadow = "1px 1px 3px rgba(0,0,0,0.06)"
        bdr_bottom = ""
    _postit_btn_css += f"""
    .st-key-wk_postit_{i} button,
    .st-key-wk_postit_{i} button:hover,
    .st-key-wk_postit_{i} button:focus,
    .st-key-wk_postit_{i} button:active {{
        background-color:{bg} !important; color:{text_color} !important; font-weight:{fw} !important;
        font-size:12px !important; padding:10px 4px !important; border-radius:8px !important;
        box-shadow:{shadow} !important; {bdr_bottom}
        border-top:none !important; border-left:none !important; border-right:none !important;
        width:64px !important; min-width:64px !important; max-width:64px !important; height:auto !important;
        cursor:pointer !important; opacity:{opacity} !important; margin:0 auto 2px auto !important; display:block !important;
    }}
    .st-key-wk_postit_{i} button p {{
        color:{text_color} !important; font-weight:{fw} !important; font-size:13px !important;
        margin:0 0 2px 0 !important; text-align:center !important; white-space:nowrap !important;
        letter-spacing:0px !important; line-height:1.3 !important;
    }}
    .st-key-wk_postit_{i} button p strong {{
        display:inline-block !important; margin-top:6px !important; padding:4px 4px !important;
        font-size:12px !important; font-weight:900 !important; border-radius:4px !important;
        color:{"#fff" if st.session_state.wk_active_tab == key else "#757575"} !important;
        background:{s["border"] if st.session_state.wk_active_tab == key else "#e0e0e0"} !important;
    }}
    """
_postit_btn_css += "</style>"
st.markdown(_postit_btn_css, unsafe_allow_html=True)

with st.sidebar:
    for i, key in enumerate(TAB_KEYS):
        if st.button(TAB_SHORT_LABELS[i], key=f"wk_postit_{i}"):
            st.session_state.wk_active_tab = key
            st.rerun()

selected_wk_tab = st.session_state.wk_active_tab
if week_no == 1:
    tab_all_excl = st.container()
    tab_unpaid = st.container()
else:
    tab_all = st.container()

# =====================================================
# [탭1] 전체 — 2주차~5주차에만 표시
# =====================================================
if week_no != 1:
    with tab_all:
        kpi_box = st.container()
        st.markdown('<div class="section-header first">1. 신규/기존별 중단현황</div>', unsafe_allow_html=True)
        st.markdown('<div class="sub-header">1-1) 주간 3개년</div>', unsafe_allow_html=True)
        # st.caption("※ FRST_REGIST_DT 기준 신규/기존 판정")
        year_data_frst = build_section1_data()
        st.markdown(render_11_html_table(build_combined_rows(year_data_frst), y1, y2, y3), unsafe_allow_html=True)


        if week_no == 1:
            st.markdown('<div class="sub-header">1-2) 중단회원 현황(회원구분별)_<span style="background:linear-gradient(transparent 40%,#fff176 40%);">미납중단제외</span></div>', unsafe_allow_html=True)
            # st.caption("※ DSCNTC_RSN_CD NOT IN (14=장기미납, 16=신규미납)")
            year_data_excl = build_section1_data(rsn_exclude="'14','16'")
            st.markdown(render_11_html_table(build_combined_rows(year_data_excl), y1, y2, y3), unsafe_allow_html=True)

            st.markdown('<div class="sub-header">1-3) 신규, 기존 주차별 중단율(<span style="background:linear-gradient(transparent 40%,#fff176 40%);">미납중단 포함</span>)</div>', unsafe_allow_html=True)
            # st.caption(f"※ 기준일: {w_start.month}월{w_start.day}일 ~ {w_end.month}월{w_end.day}일 | 중단율 = 중단건/(개발건+전월말활동회원건)×100")
            dev_by_type_df = load_dev_weekly_by_type(all_years, month)
            active_by_type_df = load_prev_month_active_by_type(all_years, month)
            rate_data = {}
            rate_detail = {}
            for yy in all_years:
                stop_new = year_data_frst[yy]["new_c"]
                stop_exist = year_data_frst[yy]["exist_c"]
                stop_total = year_data_frst[yy]["total_c"]
                if not dev_by_type_df.empty:
                    dev_by_type_df["YEAR"] = pd.to_numeric(dev_by_type_df["YEAR"], errors='coerce').astype(int)
                    dev_by_type_df["WEEK_OF_MONTH"] = pd.to_numeric(dev_by_type_df["WEEK_OF_MONTH"], errors='coerce').astype(int)
                    dev_by_type_df["DEV_CNT"] = pd.to_numeric(dev_by_type_df["DEV_CNT"], errors='coerce').fillna(0)
                    dnew = dev_by_type_df[(dev_by_type_df["YEAR"]==yy)&(dev_by_type_df["WEEK_OF_MONTH"]==week_no)&(dev_by_type_df["NEW_EXISTING"]=="신규회원")]
                    dexist = dev_by_type_df[(dev_by_type_df["YEAR"]==yy)&(dev_by_type_df["WEEK_OF_MONTH"]==week_no)&(dev_by_type_df["NEW_EXISTING"]=="기존회원")]
                    dev_new = float(dnew["DEV_CNT"].values[0]) if not dnew.empty else 0
                    dev_exist = float(dexist["DEV_CNT"].values[0]) if not dexist.empty else 0
                else:
                    dev_new, dev_exist = 0, 0
                if not active_by_type_df.empty:
                    active_by_type_df["YEAR"] = pd.to_numeric(active_by_type_df["YEAR"], errors='coerce').astype(int)
                    active_by_type_df["ACTIVE_CNT"] = pd.to_numeric(active_by_type_df["ACTIVE_CNT"], errors='coerce').fillna(0)
                    anew = active_by_type_df[(active_by_type_df["YEAR"]==yy)&(active_by_type_df["NEW_EXISTING"]=="신규회원")]
                    aexist = active_by_type_df[(active_by_type_df["YEAR"]==yy)&(active_by_type_df["NEW_EXISTING"]=="기존회원")]
                    act_new = float(anew["ACTIVE_CNT"].values[0]) if not anew.empty else 0
                    act_exist = float(aexist["ACTIVE_CNT"].values[0]) if not aexist.empty else 0
                else:
                    act_new, act_exist = 0, 0
                denom_new = dev_new + act_new
                denom_exist = dev_exist + act_exist
                denom_total = denom_new + denom_exist
                rate_data[yy] = {
                    "신규": round(stop_new / denom_new * 100, 2) if denom_new > 0 else 0,
                    "기존": round(stop_exist / denom_exist * 100, 2) if denom_exist > 0 else 0,
                    "합계": round(stop_total / denom_total * 100, 2) if denom_total > 0 else 0,
                }
                rate_detail[yy] = {
                    "신규": {"stop": stop_new, "dev": dev_new, "active": act_new, "denom": denom_new},
                    "기존": {"stop": stop_exist, "dev": dev_exist, "active": act_exist, "denom": denom_exist},
                    "합계": {"stop": stop_total, "dev": dev_new + dev_exist, "active": act_new + act_exist, "denom": denom_total},
                }
            rate_html = f"""<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:0;">
            <thead>
                <tr>
                    <th rowspan="2" style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">구분</th>
                    <th colspan="3" style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">중단율(%)</th>
                    <th colspan="2" style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">증감(p)</th>
                </tr>
                <tr>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y1}년</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y2}년</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y3}년</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y2}년 대비</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y3}년 대비</th>
                </tr>
            </thead>
            <tbody>"""
            for cat in ["신규", "기존", "합계"]:
                is_total = cat == "합계"
                label = "합계(신규+기존)" if is_total else cat
                bg = "background:#F2F2F2;color:#222;font-weight:bold;" if is_total else ""
                v1 = rate_data[y1][cat]
                v2 = rate_data[y2][cat]
                v3 = rate_data[y3][cat]
                d12 = round(v1 - v2, 2)
                d13 = round(v1 - v3, 2)
                rate_html += f'<tr style="{bg}">'
                rate_html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{bg}">{label}</td>'
                rate_html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{v1:.2f}%</td>'
                rate_html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{v2:.2f}%</td>'
                rate_html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{v3:.2f}%</td>'
                rate_html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{d12:+.2f}%</td>'
                rate_html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{d13:+.2f}%</td>'
                rate_html += '</tr>'
            rate_html += "</tbody></table>"
            st.markdown(rate_html, unsafe_allow_html=True)

            with st.expander("중단율 계산식 상세보기"):
                for cat in ["신규", "기존"]:
                    st.markdown(f"**[ {cat} ]**")
                    for yy in all_years:
                        d = rate_detail[yy][cat]
                        rate_val = rate_data[yy][cat]
                        st.markdown(
                            f"&nbsp;&nbsp;`{yy}년` : {d['stop']:,.1f}(중단건) / ({d['dev']:,.1f}(개발건) + {d['active']:,.1f}(전월말활동회원건)) × 100 "
                            f"= {d['stop']:,.1f} / {d['denom']:,.1f} × 100 = **{rate_val:.2f}%**"
                        )

            st.markdown('<div class="sub-header">1-4) 연 누계 3개년 비교</div>', unsafe_allow_html=True)
        else:
            st.markdown('<div class="sub-header">2) 월 누계 3개년(미납중단 포함)</div>', unsafe_allow_html=True)
        # st.caption(f"※ 각 연도 {month}월 1일 ~ {month}월 {week_no}주차 종료일까지 누계")
        year_data_12 = build_section12_data()
        st.markdown(render_11_html_table(build_combined_rows(year_data_12), y1, y2, y3), unsafe_allow_html=True)
        with kpi_box:
            render_kpi_strip(year_data_frst, year_data_12)

        # === 섹션2: 동월 주차별 중단(건) 현황 ===
        st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="section-header">2. 동월 주차별 중단(건) 현황(미납중단 포함) <span style="font-size:11px;font-weight:400;opacity:0.8;margin-left:10px;">*각 주차별 중단건 클릭 시 세부사항을 확인할 수 있습니다.</span></div>', unsafe_allow_html=True)
        stop_tab_all = stop_df.copy()
        stop_by_week_ta = stop_tab_all.groupby(["YEAR", "WEEK_OF_MONTH"]).agg(STOP_CNT=("STOP_CNT", "sum")).reset_index()
        stop_by_week_ta = stop_by_week_ta[stop_by_week_ta["WEEK_OF_MONTH"] <= week_no].copy()
        all_wk_ta = ["1주차", "2주차", "3주차", "4주차", "5주차"]
        if not stop_by_week_ta.empty:
            pivot_ta = stop_by_week_ta.pivot(index="YEAR", columns="WEEK_OF_MONTH", values="STOP_CNT").fillna(0)
            for w in range(1, 6):
                if w not in pivot_ta.columns:
                    pivot_ta[w] = 0
            pivot_ta = pivot_ta[[1, 2, 3, 4, 5]]
            pivot_ta.columns = all_wk_ta
            pivot_ta["합계"] = pivot_ta.sum(axis=1)
            for w in range(week_no + 1, 6):
                pivot_ta[f"{w}주차"] = None
            wk_disp_ta = all_wk_ta + ["합계"]
            yr_vals_ta = {}
            for yy in all_years:
                if yy in pivot_ta.index:
                    yr_vals_ta[yy] = {c: pivot_ta.loc[yy, c] for c in wk_disp_ta}
                else:
                    yr_vals_ta[yy] = {c: None for c in wk_disp_ta}
            html_ta = '<table id="tbl_s2" style="width:100%;border-collapse:collapse;font-size:13px;">'
            html_ta += '<thead><tr>'
            html_ta += '<th style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">년도</th>'
            for c in wk_disp_ta:
                html_ta += f'<th style="background:#A9C1DD;color:#222;padding:4px;border:1px solid #BFBFBF;text-align:center;">{c}</th>'
            html_ta += '</tr></thead><tbody>'
            yr_sty_ta = {y1: "font-weight:bold;", y2: "", y3: ""}
            _popup_data = {}
            for yy in all_years:
                sty = yr_sty_ta.get(yy, "")
                html_ta += '<tr>'
                html_ta += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{sty}">{yy}년</td>'
                for c in wk_disp_ta:
                    val = yr_vals_ta[yy][c]
                    if val is None or (isinstance(val, float) and pd.isna(val)):
                        html_ta += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}"></td>'
                    elif c != "합계" and c in all_wk_ta[:week_no]:
                        wk_idx = all_wk_ta.index(c) + 1
                        dp_key = f"{yy}_{wk_idx}"
                        html_ta += f'<td data-popup="{dp_key}" style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}cursor:pointer;" title="클릭 시 상세보기">{val:,.0f}</td>'
                        if dp_key not in _popup_data:
                            _wr = calc_week_ranges(yy, month)
                            if wk_idx <= len(_wr):
                                _ws, _we = _wr[wk_idx - 1]
                                _di = calc_day_info(_ws, _we)
                                _days_all = []
                                for _yy2 in all_years:
                                    _wr2 = calc_week_ranges(_yy2, month)
                                    if wk_idx <= len(_wr2):
                                        _ws2, _we2 = _wr2[wk_idx - 1]
                                        _di2 = calc_day_info(_ws2, _we2)
                                        _days_all.append({"y": _yy2, "p": f"{_ws2.month}/{_ws2.day}~{_we2.month}/{_we2.day}", "t": _di2["total"], "wd": _di2["weekdays"], "we": _di2["weekends"], "h": _di2["holidays"]})
                                _top3 = load_top3_campaigns(yy, _ws.strftime("%Y%m%d"), _we.strftime("%Y%m%d"))
                                _camps = []
                                if not _top3.empty:
                                    for _, _r in _top3.iterrows():
                                        _camps.append({"n": str(_r["CAMPAIGN_NAME"]), "c": float(_r["DSCNTC_CNT"])})
                                _rsn_df = load_dscntc_by_reason(yy, _ws.strftime("%Y%m%d"), _we.strftime("%Y%m%d"))
                                _reasons = []
                                if not _rsn_df.empty:
                                    _rtotal = float(_rsn_df["DSCNTC_CNT"].sum())
                                    for _, _rr in _rsn_df.iterrows():
                                        _rv = float(_rr["DSCNTC_CNT"])
                                        _reasons.append({"n": str(_rr["REASON_NAME"]), "c": _rv, "p": round(_rv / _rtotal * 100, 1) if _rtotal > 0 else 0})
                                _prev_yr = yy - 1
                                _wr_prev = calc_week_ranges(_prev_yr, month)
                                _prev_reasons = []
                                if wk_idx <= len(_wr_prev):
                                    _wsp, _wep = _wr_prev[wk_idx - 1]
                                    _rsn_prev = load_dscntc_by_reason(_prev_yr, _wsp.strftime("%Y%m%d"), _wep.strftime("%Y%m%d"))
                                    if not _rsn_prev.empty:
                                        for _, _rp in _rsn_prev.iterrows():
                                            _prev_reasons.append({"n": str(_rp["REASON_NAME"]), "c": float(_rp["DSCNTC_CNT"])})
                                _popup_data[dp_key] = {"title": f"{month}월 {wk_idx}주차 중단 상세 ({yy}년)", "year": int(yy), "week": wk_idx, "days": _days_all, "camps": _camps, "reasons": _reasons, "prev_reasons": _prev_reasons, "prev_year": _prev_yr,
                                    "v1": yr_vals_ta.get(y1, {}).get(wk_disp_ta[wk_idx - 1]),
                                    "v2": yr_vals_ta.get(y2, {}).get(wk_disp_ta[wk_idx - 1]),
                                    "v3": yr_vals_ta.get(y3, {}).get(wk_disp_ta[wk_idx - 1]),
                                    "y1n": f"{y1}년", "y2n": f"{y2}년", "y3n": f"{y3}년"}
                    else:
                        html_ta += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}">{val:,.0f}</td>'
                html_ta += '</tr>'
            diff_sty_ta = "font-weight:bold;"
            for label, ya, yb in [(f"{y1}-{y2} 증감(건)", y1, y2), (f"{y1}-{y3} 증감(건)", y1, y3)]:
                html_ta += '<tr>'
                html_ta += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{diff_sty_ta}">{label}</td>'
                for c in wk_disp_ta:
                    va = yr_vals_ta[ya].get(c)
                    vb = yr_vals_ta[yb].get(c)
                    if va is not None and vb is not None and not (isinstance(va, float) and pd.isna(va)) and not (isinstance(vb, float) and pd.isna(vb)):
                        html_ta += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{diff_sty_ta}">{va - vb:+,.0f}</td>'
                    else:
                        html_ta += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{diff_sty_ta}"></td>'
                html_ta += '</tr>'
            html_ta += '</tbody></table>'
            st.markdown(html_ta, unsafe_allow_html=True)


            # SVG 차트
            st.markdown("&nbsp;")
            chart_df_ta = stop_by_week_ta.copy()
            chart_df_ta["년도"] = chart_df_ta["YEAR"].astype(str) + "년"
            chart_df_ta["주차라벨"] = chart_df_ta["WEEK_OF_MONTH"].apply(lambda w: f"{int(w)}주차")
            chart_df_ta["중단건수"] = chart_df_ta["STOP_CNT"]
            yr_list_ta = [f"{y}년" for y in all_years]
            dot_colors_ta = {yr_list_ta[0]: "#27ae60", yr_list_ta[1]: "#3498db", yr_list_ta[2]: "#95a5a6"}
            wk_yr_ta = {}
            for wl in all_wk_ta:
                wk_yr_ta[wl] = {}
                for yr_name in yr_list_ta:
                    m = chart_df_ta[(chart_df_ta["주차라벨"] == wl) & (chart_df_ta["년도"] == yr_name)]
                    wk_yr_ta[wl][yr_name] = float(m["중단건수"].iloc[0]) if not m.empty else None
            y_min_ta = float(chart_df_ta["중단건수"].min())
            y_max_ta = float(chart_df_ta["중단건수"].max())
            y_rng_ta = y_max_ta - y_min_ta if y_max_ta != y_min_ta else y_max_ta * 0.1
            y_lo_ta = max(0, y_min_ta - y_rng_ta * 0.4)
            y_hi_ta = y_max_ta + y_rng_ta * 0.6
            cw_ta, ch_ta = 1100, 300
            pl_ta, pr_ta, pt_ta, pb_ta = 80, 40, 55, 45
            pw_ta = cw_ta - pl_ta - pr_ta
            ph_ta = ch_ta - pt_ta - pb_ta
            ystep_ta = round(y_rng_ta / 4, -2) if y_rng_ta > 400 else round(y_rng_ta / 4)
            if ystep_ta == 0: ystep_ta = 1
            yticks_ta = []
            t = int(y_lo_ta // ystep_ta) * ystep_ta
            while t <= y_hi_ta:
                if t >= y_lo_ta: yticks_ta.append(t)
                t += ystep_ta
            def to_xta(idx): return pl_ta + (idx + 0.5) * pw_ta / 5
            def to_yta(val): return pt_ta + ph_ta - (val - y_lo_ta) / (y_hi_ta - y_lo_ta) * ph_ta
            render_exec_chart(wk_yr_ta, all_wk_ta, yr_list_ta, "동월 주차별 중단(건) 추이", "중단(건)")
        else:
            st.info("데이터가 없습니다.")

        # === 섹션3: 동월 주차별 중단율 추이 ===
        st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="section-header">3. 동월 주차별 중단율 추이(미납중단 포함) <span style="font-size:11px;font-weight:400;opacity:0.8;margin-left:10px;">*각 주차별 중단율 클릭 시 세부사항을 확인할 수 있습니다.</span></div>', unsafe_allow_html=True)
        # st.caption("중단율(%) = 중단(건) / (개발건 + 전월말 활동회원건) × 100")
        rate_rows_ta = []
        for yy in all_years:
            active_row = active_df[active_df["YEAR"] == yy]
            active_cnt = float(active_row["ACTIVE_CNT"].values[0]) if not active_row.empty else 0
            y_stop = stop_by_week_ta[stop_by_week_ta["YEAR"] == yy] if not stop_by_week_ta.empty else pd.DataFrame()
            y_dev = dev_df[dev_df["YEAR"] == yy]
            if not y_stop.empty:
                for _, row in y_stop.iterrows():
                    w = int(row["WEEK_OF_MONTH"])
                    s_cnt = float(row["STOP_CNT"])
                    dev_row = y_dev[y_dev["WEEK_OF_MONTH"] == w]
                    d_cnt = float(dev_row["DEV_CNT"].values[0]) if not dev_row.empty else 0
                    denom = d_cnt + active_cnt
                    rate = round(s_cnt / denom * 100, 2) if denom > 0 else 0
                    rate_rows_ta.append({"년도": int(yy), "주차": w, "중단율(%)": rate})
        r_df_ta = pd.DataFrame(rate_rows_ta)
        if not r_df_ta.empty:
            # HTML 표 (증감/합계 없음)
            all_wk_cols_r = ["1주차", "2주차", "3주차", "4주차", "5주차"]
            yr_list_r = [f"{y}년" for y in all_years]
            wk_yr_rate_ta = {}
            for w_idx, wl in enumerate(all_wk_cols_r):
                w_num = w_idx + 1
                wk_yr_rate_ta[wl] = {}
                for yy in all_years:
                    yr_name = f"{yy}년"
                    m = r_df_ta[(r_df_ta["년도"] == yy) & (r_df_ta["주차"] == w_num)]
                    wk_yr_rate_ta[wl][yr_name] = float(m["중단율(%)"].iloc[0]) if not m.empty else None
            yr_sty_r = {y1: "font-weight:bold;", y2: "", y3: ""}
            html_r = '<table style="width:100%;border-collapse:collapse;font-size:13px;">'
            html_r += '<thead><tr>'
            html_r += '<th style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">년도</th>'
            for c in all_wk_cols_r:
                html_r += f'<th style="background:#A9C1DD;color:#222;padding:4px;border:1px solid #BFBFBF;text-align:center;">{c}</th>'
            html_r += '</tr></thead><tbody>'
            for yy in all_years:
                yr_name = f"{yy}년"
                sty = yr_sty_r.get(yy, "")
                html_r += '<tr>'
                html_r += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{sty}">{yr_name}</td>'
                for w_idx, wl in enumerate(all_wk_cols_r):
                    val = wk_yr_rate_ta[wl].get(yr_name)
                    if val is not None:
                        rp_key = f"r_{yy}_{w_idx}"
                        html_r += f'<td data-popup="{rp_key}" style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}cursor:pointer;" title="클릭 시 상세보기">{val:.2f}%</td>'
                        if rp_key not in _popup_data:
                            v1r = wk_yr_rate_ta[wl].get(f"{y1}년")
                            v2r = wk_yr_rate_ta[wl].get(f"{y2}년")
                            v3r = wk_yr_rate_ta[wl].get(f"{y3}년")
                            rp = {"type": "rate", "wk": wl, "year": int(yy), "y1n": f"{y1}년", "y2n": f"{y2}년", "y3n": f"{y3}년"}
                            if v1r is not None: rp["v1"] = round(v1r, 2)
                            if v2r is not None: rp["v2"] = round(v2r, 2)
                            if v3r is not None: rp["v3"] = round(v3r, 2)
                            if v1r is not None and v2r is not None: rp["d2"] = round(v1r - v2r, 2)
                            if v1r is not None and v3r is not None: rp["d3"] = round(v1r - v3r, 2)
                            _popup_data[rp_key] = rp
                    else:
                        html_r += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}"></td>'
                html_r += '</tr>'
            html_r += '</tbody></table>'
            st.markdown(html_r, unsafe_allow_html=True)

            import json
            _pjson = json.dumps(_popup_data, ensure_ascii=False)
            stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._s2popup){{try{{doc._s2popup()}}catch(e){{}}}}
var D={_pjson};
var ov=doc.getElementById('s2-popup-overlay');
if(!ov){{
  ov=doc.createElement('div');ov.id='s2-popup-overlay';
  ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:80px;';
  ov.innerHTML='<div id="s2-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:900px;width:92%;max-height:80vh;overflow-y:auto;animation:s2pop .2s ease"></div>';
  var st=doc.createElement('style');
  st.textContent='@keyframes s2pop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#s2-popup-overlay td[data-popup]{{cursor:pointer}}#s2-popup-overlay td[data-popup]:hover{{background:rgba(26,115,232,0.10)!important}}';
  doc.head.appendChild(st);
  doc.body.appendChild(ov);
  ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
}}
var box=doc.getElementById('s2-popup-box');
function show(key){{
  var d=D[key];if(!d)return;
  if(d.type==='rate'){{
    var h='<div style="background:linear-gradient(135deg,#2C3E50,#9b59b6);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
    h+='<span style="font-weight:700;font-size:15px">📈 '+d.wk+' 중단율 비교</span>';
    h+='<span id="s2-close" style="cursor:pointer;font-size:20px;opacity:0.8">✕</span></div>';
    h+='<div style="padding:18px 20px">';
    h+='<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:10px">';
    h+='<thead><tr><th style="background:#f8f9fa;padding:8px;border:1px solid #e0e0e0;text-align:center">구분</th>';
    h+='<th style="background:#eafaf1;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y1n+'</th>';
    if(d.v2!=null)h+='<th style="background:#d6eaf8;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y2n+'</th>';
    if(d.v3!=null)h+='<th style="background:#f5f5f5;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y3n+'</th>';
    h+='</tr></thead><tbody>';
    h+='<tr><td style="padding:8px;border:1px solid #e0e0e0;font-weight:600">중단율(%)</td>';
    if(d.v1!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right;font-weight:700;color:#27ae60">'+d.v1.toFixed(2)+'%</td>';
    if(d.v2!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v2.toFixed(2)+'%</td>';
    if(d.v3!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v3.toFixed(2)+'%</td>';
    h+='</tr></tbody></table>';
    if(d.d2!=null){{
      var c2=d.d2>0?'#e74c3c':(d.d2<0?'#3498db':'#666');
      var a2=d.d2>0?'▲':(d.d2<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#f0f8ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y2n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+c2+'">'+a2+' '+(d.d2>0?'+':'')+d.d2.toFixed(2)+'%p</span></div>';
    }}
    if(d.d3!=null){{
      var c3=d.d3>0?'#e74c3c':(d.d3<0?'#3498db':'#666');
      var a3=d.d3>0?'▲':(d.d3<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#faf5ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y3n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+c3+'">'+a3+' '+(d.d3>0?'+':'')+d.d3.toFixed(2)+'%p</span></div>';
    }}
    h+='</div>';
    box.innerHTML=h;
    ov.style.display='flex';
    doc.getElementById('s2-close').addEventListener('click',function(){{ov.style.display='none'}});
    return;
  }}
  var h='<div style="background:linear-gradient(135deg,#2C3E50,#34495E);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:16px;font-weight:700">'+d.title+'</span>';
  h+='<span id="s2-close" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px;transition:background .15s" onmouseover="this.style.background=\\'rgba(255,255,255,0.2)\\'" onmouseout="this.style.background=\\'transparent\\'">✕</span></div>';
  h+='<div style="padding:18px 22px">';
  h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin-bottom:10px;border-bottom:2px solid #667eea;padding-bottom:5px">📅 기간 및 일수</div>';
  for(var i=0;i<d.days.length;i++){{
    var dd=d.days[i];var isPrimary=(dd.y===d.year);
    var bg=isPrimary?'background:#f0fdf4;border-left:3px solid #27ae60;padding:10px 14px;border-radius:0 10px 10px 0':'padding:10px 14px;background:#fafafa;border-radius:10px';
    var yc=isPrimary?'#1a9c6e':'#555';
    h+='<div style="'+bg+';margin-bottom:6px">';
    h+='<div style="font-weight:700;color:'+yc+';font-size:14px">'+dd.y+'년 <span style="color:#888;font-size:12px;font-weight:400;margin-left:6px">'+dd.p+'</span></div>';
    h+='<div style="font-size:13px;margin-top:3px;color:#555">총 <b>'+dd.t+'</b>일 &nbsp;<span style="color:#2980b9">평일 '+dd.wd+'일</span> &nbsp;';
    if(dd.h>0)h+='<span style="color:#e67e22">주말·공휴일 '+(dd.we+dd.h)+'일</span> <span style="color:#999;font-size:11px">(주말'+dd.we+'+공휴일'+dd.h+')</span>';
    else h+='<span style="color:#e67e22">주말 '+dd.we+'일</span>';
    h+='</div></div>';
  }}
  h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #e74c3c;padding-bottom:5px">🏆 중단 상위 3개 캠페인 ('+d.year+'년)</div>';
  var medals=['🥇','🥈','🥉'];
  if(d.camps.length>0){{
    for(var j=0;j<d.camps.length;j++){{
      var bg2=j===0?'#fff8f0':(j===1?'#fafafa':'#f5f5f5');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:'+bg2+';border-radius:10px;margin-bottom:5px">';
      h+='<span style="font-size:13px;flex:1;margin-right:10px;line-height:1.4">'+medals[j]+' '+d.camps[j].n+'</span>';
      h+='<span style="font-weight:700;color:#e74c3c;font-size:13px;white-space:nowrap">'+d.camps[j].c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건</span></div>';
    }}
  }}else{{h+='<div style="color:#999;padding:10px">데이터 없음</div>';}}
  if(d.v1!=null){{
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #3498db;padding-bottom:5px">📊 3개년 중단건 비교</div>';
    h+='<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:10px">';
    h+='<thead><tr><th style="background:#f8f9fa;padding:8px;border:1px solid #e0e0e0;text-align:center">구분</th>';
    h+='<th style="background:#eafaf1;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y1n+'</th>';
    if(d.v2!=null)h+='<th style="background:#d6eaf8;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y2n+'</th>';
    if(d.v3!=null)h+='<th style="background:#f5f5f5;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y3n+'</th>';
    h+='</tr></thead><tbody>';
    h+='<tr><td style="padding:8px;border:1px solid #e0e0e0;font-weight:600">중단(건)</td>';
    h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right;font-weight:700;color:#27ae60">'+d.v1.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    if(d.v2!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v2.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    if(d.v3!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v3.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    h+='</tr></tbody></table>';
    if(d.v2!=null){{
      var dd2=d.v1-d.v2;var pp2=d.v2!==0?((d.v1-d.v2)/d.v2*100):0;
      var cc2=dd2>0?'#e74c3c':(dd2<0?'#3498db':'#666');
      var aa2=dd2>0?'▲':(dd2<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#f0f8ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y2n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+cc2+'">'+aa2+' '+(dd2>0?'+':'')+Math.round(dd2).toLocaleString()+'건 ('+(pp2>0?'+':'')+pp2.toFixed(1)+'%)</span></div>';
    }}
    if(d.v3!=null){{
      var dd3=d.v1-d.v3;var pp3=d.v3!==0?((d.v1-d.v3)/d.v3*100):0;
      var cc3=dd3>0?'#e74c3c':(dd3<0?'#3498db':'#666');
      var aa3=dd3>0?'▲':(dd3<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#faf5ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y3n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+cc3+'">'+aa3+' '+(dd3>0?'+':'')+Math.round(dd3).toLocaleString()+'건 ('+(pp3>0?'+':'')+pp3.toFixed(1)+'%)</span></div>';
    }}
  }}
  if(d.reasons&&d.reasons.length>0){{
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #9b59b6;padding-bottom:5px">📋 중단사유별 현황 ('+d.year+'년)</div>';
    h+='<table style="width:100%;border-collapse:collapse;font-size:12px"><thead><tr><th style="background:#f5f0ff;padding:6px 10px;text-align:left;border-bottom:2px solid #9b59b6">중단사유</th><th style="background:#f5f0ff;padding:6px 10px;text-align:right;border-bottom:2px solid #9b59b6">중단(건)</th><th style="background:#f5f0ff;padding:6px 10px;text-align:right;border-bottom:2px solid #9b59b6">비중</th></tr></thead><tbody>';
    for(var k=0;k<d.reasons.length;k++){{
      var rr=d.reasons[k];var rbg=k%2===0?'#fff':'#fafafa';
      h+='<tr style="background:'+rbg+'"><td style="padding:5px 10px;border-bottom:1px solid #eee">'+rr.n+'</td>';
      h+='<td style="padding:5px 10px;text-align:right;border-bottom:1px solid #eee">'+rr.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="padding:5px 10px;text-align:right;border-bottom:1px solid #eee;color:#9b59b6;font-weight:600">'+rr.p.toFixed(1)+'%</td></tr>';
    }}
    h+='</tbody></table>';
  }}
  if(d.reasons&&d.reasons.length>0&&d.prev_reasons&&d.prev_reasons.length>0){{
    var py=d.prev_year||d.year-1;
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:18px 0 10px;border-bottom:2px solid #e67e22;padding-bottom:5px">📊 '+d.year+'년 vs '+py+'년 중단사유 비교</div>';
    var pm={{}};for(var pi=0;pi<d.prev_reasons.length;pi++){{pm[d.prev_reasons[pi].n]=d.prev_reasons[pi].c;}}
    var items=[];for(var ri=0;ri<d.reasons.length;ri++){{var rn=d.reasons[ri].n;var cv=d.reasons[ri].c;var pv=pm[rn]||0;items.push({{n:rn,c:cv,p:pv,up:cv>pv}});}}
    items.sort(function(a,b){{return b.c-a.c;}});
    var maxV=0;for(var ii=0;ii<items.length;ii++){{maxV=Math.max(maxV,items[ii].c,items[ii].p);}}
    if(maxV===0)maxV=1;
    var bh=18,gap=4,lw=120,cw2=700,ch2=items.length*(bh*2+gap)+20;
    h+='<div style="overflow-x:auto"><svg width="'+cw2+'" viewBox="0 0 '+cw2+' '+ch2+'" preserveAspectRatio="xMidYMid meet" style="width:100%;font-family:sans-serif">';
    var bw2=cw2-lw-80;
    for(var gi=0;gi<items.length;gi++){{
      var it=items[gi];var y0=gi*(bh*2+gap)+10;
      var w1=Math.max(it.c/maxV*bw2,1);var w2=Math.max(it.p/maxV*bw2,1);
      var c1=it.up?'#e74c3c':'#27ae60';var c2r='#95a5a6';
      h+='<text x="'+(lw-4)+'" y="'+(y0+bh-2)+'" text-anchor="end" font-size="10" fill="#333">'+it.n+'</text>';
      h+='<rect x="'+lw+'" y="'+y0+'" width="'+w1+'" height="'+bh+'" rx="3" fill="'+c1+'" opacity="0.85"/>';
      h+='<text x="'+(lw+w1+4)+'" y="'+(y0+bh-4)+'" font-size="9" fill="'+c1+'" font-weight="700">'+it.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</text>';
      h+='<rect x="'+lw+'" y="'+(y0+bh)+'" width="'+w2+'" height="'+bh+'" rx="3" fill="'+c2r+'" opacity="0.6"/>';
      h+='<text x="'+(lw+w2+4)+'" y="'+(y0+bh*2-4)+'" font-size="9" fill="#777">'+it.p.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</text>';
    }}
    h+='</svg></div>';
    h+='<div style="display:flex;gap:16px;margin-top:6px;font-size:11px;color:#666">';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#e74c3c;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+d.year+'년 (전년대비 증가)</span>';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#27ae60;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+d.year+'년 (전년대비 감소)</span>';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#95a5a6;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+py+'년</span>';
    h+='</div>';
  }}

  h+='</div>';
  box.innerHTML=h;
  ov.style.display='flex';
  doc.getElementById('s2-close').addEventListener('click',function(){{ov.style.display='none'}});
}}
function onClick(e){{
  var td=e.target.closest('td[data-popup]');
  if(!td)return;
  show(td.getAttribute('data-popup'));
}}
doc.addEventListener('click',onClick);
doc._s2popup=function(){{doc.removeEventListener('click',onClick)}};
}})();
</script>""", height=0)

            with st.expander("중단율 계산식 상세보기"):
                active_by_type_ta = load_prev_month_active_by_type(all_years, month)
                if not active_by_type_ta.empty:
                    active_by_type_ta["YEAR"] = pd.to_numeric(active_by_type_ta["YEAR"], errors='coerce').astype(int)
                    active_by_type_ta["ACTIVE_CNT"] = pd.to_numeric(active_by_type_ta["ACTIVE_CNT"], errors='coerce').fillna(0)
                for w_num in range(1, week_no + 1):
                    st.markdown(f"**[ {w_num}주차 ]**")
                    for yy in all_years:
                        if not active_by_type_ta.empty:
                            anew_ta = active_by_type_ta[(active_by_type_ta["YEAR"]==yy)&(active_by_type_ta["NEW_EXISTING"]=="신규회원")]
                            aexist_ta = active_by_type_ta[(active_by_type_ta["YEAR"]==yy)&(active_by_type_ta["NEW_EXISTING"]=="기존회원")]
                            a_cnt = (float(anew_ta["ACTIVE_CNT"].values[0]) if not anew_ta.empty else 0) + (float(aexist_ta["ACTIVE_CNT"].values[0]) if not aexist_ta.empty else 0)
                        else:
                            a_cnt = 0
                        s_row = stop_by_week_ta[(stop_by_week_ta["YEAR"] == yy) & (stop_by_week_ta["WEEK_OF_MONTH"] == w_num)]
                        s_cnt = float(s_row["STOP_CNT"].values[0]) if not s_row.empty else 0
                        d_row = dev_df[(dev_df["YEAR"] == yy) & (dev_df["WEEK_OF_MONTH"] == w_num)]
                        d_cnt = float(d_row["DEV_CNT"].values[0]) if not d_row.empty else 0
                        denom = d_cnt + a_cnt
                        rate_val = round(s_cnt / denom * 100, 2) if denom > 0 else 0
                        st.markdown(
                            f"&nbsp;&nbsp;`{yy}년` : {s_cnt:,.1f}(중단건) / ({d_cnt:,.1f}(개발건) + {a_cnt:,.1f}(전월말활동회원건)) × 100 "
                            f"= {s_cnt:,.1f} / {denom:,.1f} × 100 = **{rate_val:.2f}%**"
                        )

            render_exec_chart(wk_yr_rate_ta, all_wk_cols_r, yr_list_r, "동월 주차별 중단율(%) 추이", "중단율(%)", is_rate=True)
        else:
            st.info("중단율 계산 데이터가 없습니다.")

        st.markdown('<div style="height:30px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="section-header">4. 가입경로별 중단현황(미납중단 포함)</div>', unsafe_allow_html=True)
        brand_df_s4 = load_brand_stop(year, dscntc_from, dscntc_to)
        _remarks_s4 = build_brand_remarks(year, dscntc_from, dscntc_to)
        st.markdown(render_brand_table(brand_df_s4, remarks=_remarks_s4, popup_key="s4"), unsafe_allow_html=True)
        render_brand_popup_script("s4", build_brand_popup_payload(load_brand_popup_members(year, dscntc_from, dscntc_to), year),
                                  f"{year}년 {month}월 {week_no}주차")
        st.markdown(render_high_value_remarks(year, dscntc_from, dscntc_to), unsafe_allow_html=True)

# =====================================================
# [탭2] 전체-미납중단 — 1주차에만 표시
# =====================================================
if week_no == 1 and selected_wk_tab == "excl":
    stop_df_excl_unpaid = load_weekly_stop(all_years, month, rsn_filter="")
    # 미납중단 제외를 위해 전체에서 미납중단(14,16)을 빼는 대신 rsn_exclude 사용
    dev_df_excl = load_dev_weekly(all_years, month)
    active_df_excl = load_prev_month_active(all_years, month)

    with tab_all_excl:
        kpi_box_excl = st.container()
        st.markdown('<div class="section-header first">1. 신규/기존별 중단현황</div>', unsafe_allow_html=True)
        unpaid_gap_box = st.container()
        st.markdown('<div style="height:28px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="sub-header">1-1) 주간 3개년</div>', unsafe_allow_html=True)
        # st.caption("※ FRST_REGIST_DT 기준 신규/기존 판정")
        year_data_frst_excl = build_section1_data()
        st.markdown(render_11_html_table(build_combined_rows(year_data_frst_excl), y1, y2, y3), unsafe_allow_html=True)


        st.markdown('<div class="sub-header">1-2) 주간 3개년(<span style="background:linear-gradient(transparent 40%,#fff176 40%);">미납중단 제외</span>)</div>', unsafe_allow_html=True)
        # st.caption("※ DSCNTC_RSN_CD NOT IN (14=장기미납, 16=신규미납)")
        year_data_excl_tab = build_section1_data(rsn_exclude="'14','16'")
        st.markdown(render_11_html_table(build_combined_rows(year_data_excl_tab), y1, y2, y3), unsafe_allow_html=True)
        with unpaid_gap_box:
            render_unpaid_gap_chart(year_data_frst_excl, year_data_excl_tab)

        if week_no == 1:
            st.markdown('<div class="sub-header">1-3) 신규/기존 주차별 중단율(<span style="background:linear-gradient(transparent 40%,#fff176 40%);">미납중단 포함</span>)</div>', unsafe_allow_html=True)
            # st.caption(f"※ 기준 : {month}월 {week_no}주차 | 중단율=중단건/(개발건+전월말활동회원건)×100")
            dev_by_type_df_excl = load_dev_weekly_by_type(all_years, month)
            active_by_type_df_excl = load_prev_month_active_by_type(all_years, month)
            rate_data_excl = {}
            rate_detail_excl = {}
            for yy in all_years:
                stop_new_e = year_data_frst_excl[yy]["new_c"]
                stop_exist_e = year_data_frst_excl[yy]["exist_c"]
                stop_total_e = year_data_frst_excl[yy]["total_c"]
                if not dev_by_type_df_excl.empty:
                    dev_by_type_df_excl["YEAR"] = pd.to_numeric(dev_by_type_df_excl["YEAR"], errors='coerce').astype(int)
                    dev_by_type_df_excl["WEEK_OF_MONTH"] = pd.to_numeric(dev_by_type_df_excl["WEEK_OF_MONTH"], errors='coerce').astype(int)
                    dev_by_type_df_excl["DEV_CNT"] = pd.to_numeric(dev_by_type_df_excl["DEV_CNT"], errors='coerce').fillna(0)
                    dnew_e = dev_by_type_df_excl[(dev_by_type_df_excl["YEAR"]==yy)&(dev_by_type_df_excl["WEEK_OF_MONTH"]==week_no)&(dev_by_type_df_excl["NEW_EXISTING"]=="신규회원")]
                    dexist_e = dev_by_type_df_excl[(dev_by_type_df_excl["YEAR"]==yy)&(dev_by_type_df_excl["WEEK_OF_MONTH"]==week_no)&(dev_by_type_df_excl["NEW_EXISTING"]=="기존회원")]
                    dev_new_e = float(dnew_e["DEV_CNT"].values[0]) if not dnew_e.empty else 0
                    dev_exist_e = float(dexist_e["DEV_CNT"].values[0]) if not dexist_e.empty else 0
                else:
                    dev_new_e, dev_exist_e = 0, 0
                if not active_by_type_df_excl.empty:
                    active_by_type_df_excl["YEAR"] = pd.to_numeric(active_by_type_df_excl["YEAR"], errors='coerce').astype(int)
                    active_by_type_df_excl["ACTIVE_CNT"] = pd.to_numeric(active_by_type_df_excl["ACTIVE_CNT"], errors='coerce').fillna(0)
                    anew_e = active_by_type_df_excl[(active_by_type_df_excl["YEAR"]==yy)&(active_by_type_df_excl["NEW_EXISTING"]=="신규회원")]
                    aexist_e = active_by_type_df_excl[(active_by_type_df_excl["YEAR"]==yy)&(active_by_type_df_excl["NEW_EXISTING"]=="기존회원")]
                    act_new_e = float(anew_e["ACTIVE_CNT"].values[0]) if not anew_e.empty else 0
                    act_exist_e = float(aexist_e["ACTIVE_CNT"].values[0]) if not aexist_e.empty else 0
                else:
                    act_new_e, act_exist_e = 0, 0
                denom_new_e = dev_new_e + act_new_e
                denom_exist_e = dev_exist_e + act_exist_e
                denom_total_e = denom_new_e + denom_exist_e
                rate_data_excl[yy] = {
                    "신규": round(stop_new_e / denom_new_e * 100, 2) if denom_new_e > 0 else 0,
                    "기존": round(stop_exist_e / denom_exist_e * 100, 2) if denom_exist_e > 0 else 0,
                    "합계": round(stop_total_e / denom_total_e * 100, 2) if denom_total_e > 0 else 0,
                }
                rate_detail_excl[yy] = {
                    "신규": {"stop": stop_new_e, "dev": dev_new_e, "active": act_new_e, "denom": denom_new_e},
                    "기존": {"stop": stop_exist_e, "dev": dev_exist_e, "active": act_exist_e, "denom": denom_exist_e},
                    "합계": {"stop": stop_total_e, "dev": dev_new_e + dev_exist_e, "active": act_new_e + act_exist_e, "denom": denom_total_e},
                }
            rate_html_excl = f"""<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:0;">
            <thead>
                <tr>
                    <th rowspan="2" style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">구분</th>
                    <th colspan="3" style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">중단율(%)</th>
                    <th colspan="2" style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">증감(p)</th>
                </tr>
                <tr>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y1}년</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y2}년</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y3}년</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y2}년 대비</th>
                    <th style="background:#A9C1DD;padding:4px;border:1px solid #BFBFBF;text-align:center;">{y3}년 대비</th>
                </tr>
            </thead>
            <tbody>"""
            for cat in ["신규", "기존", "합계"]:
                is_total = cat == "합계"
                label = "합계(신규+기존)" if is_total else cat
                bg = "background:#F2F2F2;color:#222;font-weight:bold;" if is_total else ""
                v1 = rate_data_excl[y1][cat]
                v2 = rate_data_excl[y2][cat]
                v3 = rate_data_excl[y3][cat]
                d12 = round(v1 - v2, 2)
                d13 = round(v1 - v3, 2)
                rate_html_excl += f'<tr style="{bg}">'
                rate_html_excl += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{bg}">{label}</td>'
                rate_html_excl += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{v1:.2f}%</td>'
                rate_html_excl += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{v2:.2f}%</td>'
                rate_html_excl += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{v3:.2f}%</td>'
                rate_html_excl += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{d12:+.2f}%</td>'
                rate_html_excl += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{bg}">{d13:+.2f}%</td>'
                rate_html_excl += '</tr>'
            rate_html_excl += "</tbody></table>"
            st.markdown(rate_html_excl, unsafe_allow_html=True)

            with st.expander("중단율 계산식 상세보기"):
                for cat in ["신규", "기존", "합계"]:
                    label = "합계(신규+기존)" if cat == "합계" else cat
                    st.markdown(f"**[ {label} ]**")
                    for yy in all_years:
                        d = rate_detail_excl[yy][cat]
                        rate_val = rate_data_excl[yy][cat]
                        st.markdown(
                            f"&nbsp;&nbsp;`{yy}년` : {d['stop']:,.1f}(중단건) / ({d['dev']:,.1f}(개발건) + {d['active']:,.1f}(전월말활동회원건)) × 100 "
                            f"= {d['stop']:,.1f} / {d['denom']:,.1f} × 100 = **{rate_val:.2f}%**"
                        )

            st.markdown('<div class="sub-header">2) 월 누계 3년(미납중단 포함)</div>', unsafe_allow_html=True)
        else:
            st.markdown('<div class="sub-header">2) 월 누계 3년(미납중단 포함)</div>', unsafe_allow_html=True)
        year_data_12_excl = build_section12_data()
        st.markdown(render_11_html_table(build_combined_rows(year_data_12_excl), y1, y2, y3, subtitle=f"({week_no}주차)"), unsafe_allow_html=True)
        with kpi_box_excl:
            render_kpi_strip(year_data_frst_excl, year_data_12_excl)

        # === 섹션2: 동월 주차별 중단(건) 현황 — 미납중단 포함 전체 데이터 기준 ===
        st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="section-header">2. 동월 주차별 중단(건) 현황(미납중단 포함) <span style="font-size:11px;font-weight:400;opacity:0.8;margin-left:10px;">*각 주차별 중단건 클릭 시 세부사항을 확인할 수 있습니다.</span></div>', unsafe_allow_html=True)
        stop_full_tab2 = stop_df.copy()
        stop_by_week_tab2 = stop_full_tab2.groupby(["YEAR", "WEEK_OF_MONTH"]).agg(STOP_CNT=("STOP_CNT", "sum")).reset_index()
        stop_by_week_tab2 = stop_by_week_tab2[stop_by_week_tab2["WEEK_OF_MONTH"] <= week_no].copy()
        all_week_cols_t2 = ["1주차", "2주차", "3주차", "4주차", "5주차"]
        if not stop_by_week_tab2.empty:
            pivot_t2 = stop_by_week_tab2.pivot(index="YEAR", columns="WEEK_OF_MONTH", values="STOP_CNT").fillna(0)
            for w in range(1, 6):
                if w not in pivot_t2.columns:
                    pivot_t2[w] = 0
            pivot_t2 = pivot_t2[[1, 2, 3, 4, 5]]
            pivot_t2.columns = all_week_cols_t2
            pivot_t2["합계"] = pivot_t2.sum(axis=1)
            for w in range(week_no + 1, 6):
                pivot_t2[f"{w}주차"] = None
            week_cols_disp = all_week_cols_t2 + ["합계"]
            year_vals_t2 = {}
            for yy in all_years:
                if yy in pivot_t2.index:
                    year_vals_t2[yy] = {c: pivot_t2.loc[yy, c] for c in week_cols_disp}
                else:
                    year_vals_t2[yy] = {c: None for c in week_cols_disp}
            html_t2 = '<table id="tbl_s2w1" style="width:100%;border-collapse:collapse;font-size:13px;">'
            html_t2 += '<thead><tr>'
            html_t2 += '<th style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">년도</th>'
            for c in week_cols_disp:
                html_t2 += f'<th style="background:#A9C1DD;color:#222;padding:4px;border:1px solid #BFBFBF;text-align:center;">{c}</th>'
            html_t2 += '</tr></thead><tbody>'
            year_styles_t2 = {y1: "font-weight:bold;", y2: "", y3: ""}
            _popup_data_w1 = {}
            for yy in all_years:
                sty = year_styles_t2.get(yy, "")
                html_t2 += '<tr>'
                html_t2 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{sty}">{yy}년</td>'
                for c in week_cols_disp:
                    val = year_vals_t2[yy][c]
                    if val is None or (isinstance(val, float) and pd.isna(val)):
                        html_t2 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}"></td>'
                    elif c != "합계" and c in all_week_cols_t2[:week_no]:
                        wk_idx2 = all_week_cols_t2.index(c) + 1
                        dp_key2 = f"{yy}_{wk_idx2}"
                        html_t2 += f'<td data-popup="{dp_key2}" style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}cursor:pointer;" title="클릭 시 상세보기">{val:,.0f}</td>'
                        if dp_key2 not in _popup_data_w1:
                            _wr = calc_week_ranges(yy, month)
                            if wk_idx2 <= len(_wr):
                                _ws, _we = _wr[wk_idx2 - 1]
                                _days_all = []
                                for _yy2 in all_years:
                                    _wr2 = calc_week_ranges(_yy2, month)
                                    if wk_idx2 <= len(_wr2):
                                        _ws2, _we2 = _wr2[wk_idx2 - 1]
                                        _di2 = calc_day_info(_ws2, _we2)
                                        _days_all.append({"y": _yy2, "p": f"{_ws2.month}/{_ws2.day}~{_we2.month}/{_we2.day}", "t": _di2["total"], "wd": _di2["weekdays"], "we": _di2["weekends"], "h": _di2["holidays"]})
                                _top3 = load_top3_campaigns(yy, _ws.strftime("%Y%m%d"), _we.strftime("%Y%m%d"))
                                _camps = []
                                if not _top3.empty:
                                    for _, _r in _top3.iterrows():
                                        _camps.append({"n": str(_r["CAMPAIGN_NAME"]), "c": float(_r["DSCNTC_CNT"])})
                                _rsn_df = load_dscntc_by_reason(yy, _ws.strftime("%Y%m%d"), _we.strftime("%Y%m%d"))
                                _reasons = []
                                if not _rsn_df.empty:
                                    _rtotal = float(_rsn_df["DSCNTC_CNT"].sum())
                                    for _, _rr in _rsn_df.iterrows():
                                        _rv = float(_rr["DSCNTC_CNT"])
                                        _reasons.append({"n": str(_rr["REASON_NAME"]), "c": _rv, "p": round(_rv / _rtotal * 100, 1) if _rtotal > 0 else 0})
                                _prev_yr = yy - 1
                                _wr_prev = calc_week_ranges(_prev_yr, month)
                                _prev_reasons = []
                                if wk_idx2 <= len(_wr_prev):
                                    _wsp, _wep = _wr_prev[wk_idx2 - 1]
                                    _rsn_prev = load_dscntc_by_reason(_prev_yr, _wsp.strftime("%Y%m%d"), _wep.strftime("%Y%m%d"))
                                    if not _rsn_prev.empty:
                                        for _, _rp in _rsn_prev.iterrows():
                                            _prev_reasons.append({"n": str(_rp["REASON_NAME"]), "c": float(_rp["DSCNTC_CNT"])})
                                _popup_data_w1[dp_key2] = {"title": f"{month}월 {wk_idx2}주차 중단 상세 ({yy}년)", "year": int(yy), "week": wk_idx2, "days": _days_all, "camps": _camps, "reasons": _reasons, "prev_reasons": _prev_reasons, "prev_year": _prev_yr}
                    else:
                        html_t2 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}">{val:,.0f}</td>'
                html_t2 += '</tr>'
            diff_sty_t2 = "font-weight:bold;"
            for label, ya, yb in [(f"{y1}-{y2} 증감(건)", y1, y2), (f"{y1}-{y3} 증감(건)", y1, y3)]:
                html_t2 += '<tr>'
                html_t2 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{diff_sty_t2}">{label}</td>'
                for c in week_cols_disp:
                    va = year_vals_t2[ya].get(c)
                    vb = year_vals_t2[yb].get(c)
                    if va is None or vb is None or (isinstance(va, float) and pd.isna(va)) or (isinstance(vb, float) and pd.isna(vb)):
                        html_t2 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{diff_sty_t2}"></td>'
                    else:
                        diff_val = va - vb
                        html_t2 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{diff_sty_t2}">{diff_val:+,.0f}</td>'
                html_t2 += '</tr>'
            html_t2 += '</tbody></table>'
            st.markdown(html_t2, unsafe_allow_html=True)


            st.markdown("&nbsp;")  # 표와 차트 사이 여백
            # 차트 데이터: 현재 주차까지만 실제 값, 나머지는 x축만 표시
            chart_df_t2 = stop_by_week_tab2.copy()
            chart_df_t2["년도"] = chart_df_t2["YEAR"].astype(str) + "년"
            chart_df_t2["주차라벨"] = chart_df_t2["WEEK_OF_MONTH"].apply(lambda w: f"{int(w)}주차")
            chart_df_t2["중단건수"] = chart_df_t2["STOP_CNT"]
            chart_df_t2["라벨"] = chart_df_t2["중단건수"].apply(lambda v: f"{v:,.0f}")
            wk_order_t2 = [f"{w}주차" for w in range(1, 6)]
            yr_list_t2 = [f"{y}년" for y in all_years]
            color_map = {f"{y1}년": "#27ae60", f"{y2}년": "#3498db", f"{y3}년": "#95a5a6"}

            # Y축 범위
            y_min_val = float(chart_df_t2["중단건수"].min())
            y_max_val = float(chart_df_t2["중단건수"].max())
            y_range = y_max_val - y_min_val if y_max_val != y_min_val else y_max_val * 0.1

            # 주차별 연도 데이터 구성
            week_year_data = {}
            for wl in wk_order_t2:
                week_year_data[wl] = {}
                for yr_name in yr_list_t2:
                    match = chart_df_t2[(chart_df_t2["주차라벨"] == wl) & (chart_df_t2["년도"] == yr_name)]
                    week_year_data[wl][yr_name] = float(match["중단건수"].iloc[0]) if not match.empty else None

            # HTML 차트: X축=주차, Y축=중단건수, 원형 도형 + 데이터라벨
            dot_colors = {yr_list_t2[0]: "#27ae60", yr_list_t2[1]: "#3498db", yr_list_t2[2]: "#95a5a6"}
            chart_w = 1100
            chart_h = 300
            pad_left = 80
            pad_right = 40
            pad_top = 55
            pad_bottom = 45
            plot_w = chart_w - pad_left - pad_right
            plot_h = chart_h - pad_top - pad_bottom

            # Y축 범위 (여유 확보)
            y_lo = max(0, y_min_val - y_range * 0.4)
            y_hi = y_max_val + y_range * 0.6

            # Y축 눈금 (적절히 4~5개)
            y_tick_step = round(y_range / 4, -2) if y_range > 400 else round(y_range / 4)
            if y_tick_step == 0:
                y_tick_step = 1
            y_ticks = []
            t = int(y_lo // y_tick_step) * y_tick_step
            while t <= y_hi:
                if t >= y_lo:
                    y_ticks.append(t)
                t += y_tick_step

            def to_px_x(week_idx):
                return pad_left + (week_idx + 0.5) * plot_w / 5

            def to_px_y(val):
                return pad_top + plot_h - (val - y_lo) / (y_hi - y_lo) * plot_h

            render_exec_chart(week_year_data, wk_order_t2, yr_list_t2, "동월 주차별 중단(건) 추이", "중단(건)")
        else:
            st.info("데이터가 없습니다.")

        # === 섹션3: 동월 주차별 중단율 추이 — 미납중단 포함 (1-3 표와 동일 기준) ===
        st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="section-header">3. 동월 주차별 중단율 추이 <span style="font-size:11px;font-weight:400;opacity:0.8;margin-left:10px;">*각 주차별 중단율 클릭 시 세부사항을 확인할 수 있습니다.</span></div>', unsafe_allow_html=True)
        # st.caption("중단율(%) = 중단(건) / (개발건 + 전월말 활동회원건) × 100")

        # 미납중단 포함 전체 stop 데이터로 중단율 계산 (1-3 표와 동일)
        stop_full_s3 = stop_df.copy()
        stop_by_week_s3 = stop_full_s3.groupby(["YEAR", "WEEK_OF_MONTH"]).agg(STOP_CNT=("STOP_CNT", "sum")).reset_index()
        stop_by_week_s3 = stop_by_week_s3[stop_by_week_s3["WEEK_OF_MONTH"] <= week_no].copy()

        rate_rows_s3 = []
        for yy in all_years:
            active_row = active_df_excl[active_df_excl["YEAR"] == yy]
            active_cnt = float(active_row["ACTIVE_CNT"].values[0]) if not active_row.empty else 0
            y_stop = stop_by_week_s3[stop_by_week_s3["YEAR"] == yy] if not stop_by_week_s3.empty else pd.DataFrame()
            y_dev = dev_df_excl[dev_df_excl["YEAR"] == yy]
            if not y_stop.empty:
                for _, row in y_stop.iterrows():
                    w = int(row["WEEK_OF_MONTH"])
                    s_cnt = float(row["STOP_CNT"])
                    dev_row = y_dev[y_dev["WEEK_OF_MONTH"] == w]
                    d_cnt = float(dev_row["DEV_CNT"].values[0]) if not dev_row.empty else 0
                    denom = d_cnt + active_cnt
                    rate = round(s_cnt / denom * 100, 2) if denom > 0 else 0
                    rate_rows_s3.append({"년도": int(yy), "주차": w, "중단율(%)": rate})
        r_df_s3 = pd.DataFrame(rate_rows_s3)

        if not r_df_s3.empty:
            # 주차별 연도 데이터 구성
            all_wk_cols_s3 = ["1주차", "2주차", "3주차", "4주차", "5주차"]
            yr_list_s3 = [f"{y}년" for y in all_years]
            wk_yr_rate_s3 = {}
            for w_idx, wl in enumerate(all_wk_cols_s3):
                w_num = w_idx + 1
                wk_yr_rate_s3[wl] = {}
                for yy in all_years:
                    yr_name = f"{yy}년"
                    m = r_df_s3[(r_df_s3["년도"] == yy) & (r_df_s3["주차"] == w_num)]
                    wk_yr_rate_s3[wl][yr_name] = float(m["중단율(%)"].iloc[0]) if not m.empty else None

            # HTML 표 (섹션2 스타일, 증감/합계 없음)
            week_cols_s3 = all_wk_cols_s3
            year_styles_s3 = {
                y1: "font-weight:bold;",
                y2: "",
                y3: ""
            }
            html_s3 = '<table style="width:100%;border-collapse:collapse;font-size:13px;">'
            html_s3 += '<thead><tr>'
            html_s3 += '<th style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">년도</th>'
            for c in week_cols_s3:
                html_s3 += f'<th style="background:#A9C1DD;color:#222;padding:4px;border:1px solid #BFBFBF;text-align:center;">{c}</th>'
            html_s3 += '</tr></thead><tbody>'
            for yy in all_years:
                yr_name = f"{yy}년"
                sty = year_styles_s3.get(yy, "")
                html_s3 += '<tr>'
                html_s3 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{sty}">{yr_name}</td>'
                for w_idx, wl in enumerate(week_cols_s3):
                    val = wk_yr_rate_s3[wl].get(yr_name)
                    if val is not None:
                        rp_key = f"r_{yy}_{w_idx}"
                        html_s3 += f'<td data-popup="{rp_key}" style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}cursor:pointer;" title="클릭 시 상세보기">{val:.2f}%</td>'
                        if rp_key not in _popup_data_w1:
                            v1r = wk_yr_rate_s3[wl].get(f"{y1}년")
                            v2r = wk_yr_rate_s3[wl].get(f"{y2}년")
                            v3r = wk_yr_rate_s3[wl].get(f"{y3}년")
                            rp = {"type": "rate", "wk": wl, "year": int(yy), "y1n": f"{y1}년", "y2n": f"{y2}년", "y3n": f"{y3}년"}
                            if v1r is not None: rp["v1"] = round(v1r, 2)
                            if v2r is not None: rp["v2"] = round(v2r, 2)
                            if v3r is not None: rp["v3"] = round(v3r, 2)
                            if v1r is not None and v2r is not None: rp["d2"] = round(v1r - v2r, 2)
                            if v1r is not None and v3r is not None: rp["d3"] = round(v1r - v3r, 2)
                            _popup_data_w1[rp_key] = rp
                    else:
                        html_s3 += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}"></td>'
                html_s3 += '</tr>'
            html_s3 += '</tbody></table>'
            st.markdown(html_s3, unsafe_allow_html=True)

            import json as _json2
            _pjson2 = _json2.dumps(_popup_data_w1, ensure_ascii=False)
            stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._s2popupW1){{try{{doc._s2popupW1()}}catch(e){{}}}}
var D={_pjson2};
var ov=doc.getElementById('s2-popup-overlay');
if(!ov){{
  ov=doc.createElement('div');ov.id='s2-popup-overlay';
  ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:80px;';
  ov.innerHTML='<div id="s2-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:900px;width:92%;max-height:80vh;overflow-y:auto;animation:s2pop .2s ease"></div>';
  var st=doc.createElement('style');
  st.textContent='@keyframes s2pop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}td[data-popup]{{cursor:pointer}}td[data-popup]:hover{{background:rgba(26,115,232,0.10)!important}}';
  doc.head.appendChild(st);
  doc.body.appendChild(ov);
  ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
}}
var box=doc.getElementById('s2-popup-box');
function show(key){{
  var d=D[key];if(!d)return;
  if(d.type==='rate'){{
    var h='<div style="background:linear-gradient(135deg,#2C3E50,#9b59b6);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
    h+='<span style="font-weight:700;font-size:15px">📈 '+d.wk+' 중단율 비교</span>';
    h+='<span id="s2-close" style="cursor:pointer;font-size:20px;opacity:0.8">✕</span></div>';
    h+='<div style="padding:18px 20px">';
    h+='<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:10px">';
    h+='<thead><tr><th style="background:#f8f9fa;padding:8px;border:1px solid #e0e0e0;text-align:center">구분</th>';
    h+='<th style="background:#eafaf1;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y1n+'</th>';
    if(d.v2!=null)h+='<th style="background:#d6eaf8;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y2n+'</th>';
    if(d.v3!=null)h+='<th style="background:#f5f5f5;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y3n+'</th>';
    h+='</tr></thead><tbody>';
    h+='<tr><td style="padding:8px;border:1px solid #e0e0e0;font-weight:600">중단율(%)</td>';
    if(d.v1!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right;font-weight:700;color:#27ae60">'+d.v1.toFixed(2)+'%</td>';
    if(d.v2!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v2.toFixed(2)+'%</td>';
    if(d.v3!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v3.toFixed(2)+'%</td>';
    h+='</tr></tbody></table>';
    if(d.d2!=null){{
      var c2=d.d2>0?'#e74c3c':(d.d2<0?'#3498db':'#666');
      var a2=d.d2>0?'▲':(d.d2<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#f0f8ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y2n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+c2+'">'+a2+' '+(d.d2>0?'+':'')+d.d2.toFixed(2)+'%p</span></div>';
    }}
    if(d.d3!=null){{
      var c3=d.d3>0?'#e74c3c':(d.d3<0?'#3498db':'#666');
      var a3=d.d3>0?'▲':(d.d3<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#faf5ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y3n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+c3+'">'+a3+' '+(d.d3>0?'+':'')+d.d3.toFixed(2)+'%p</span></div>';
    }}
    h+='</div>';
    box.innerHTML=h;
    ov.style.display='flex';
    doc.getElementById('s2-close').addEventListener('click',function(){{ov.style.display='none'}});
    return;
  }}
  var h='<div style="background:linear-gradient(135deg,#2C3E50,#34495E);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:16px;font-weight:700">'+d.title+'</span>';
  h+='<span id="s2-close" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px;transition:background .15s" onmouseover="this.style.background=\\'rgba(255,255,255,0.2)\\'" onmouseout="this.style.background=\\'transparent\\'">✕</span></div>';
  h+='<div style="padding:18px 22px">';
  h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin-bottom:10px;border-bottom:2px solid #667eea;padding-bottom:5px">📅 기간 및 일수</div>';
  for(var i=0;i<d.days.length;i++){{
    var dd=d.days[i];var isPrimary=(dd.y===d.year);
    var bg=isPrimary?'background:#f0fdf4;border-left:3px solid #27ae60;padding:10px 14px;border-radius:0 10px 10px 0':'padding:10px 14px;background:#fafafa;border-radius:10px';
    var yc=isPrimary?'#1a9c6e':'#555';
    h+='<div style="'+bg+';margin-bottom:6px">';
    h+='<div style="font-weight:700;color:'+yc+';font-size:14px">'+dd.y+'년 <span style="color:#888;font-size:12px;font-weight:400;margin-left:6px">'+dd.p+'</span></div>';
    h+='<div style="font-size:13px;margin-top:3px;color:#555">총 <b>'+dd.t+'</b>일 &nbsp;<span style="color:#2980b9">평일 '+dd.wd+'일</span> &nbsp;';
    if(dd.h>0)h+='<span style="color:#e67e22">주말·공휴일 '+(dd.we+dd.h)+'일</span> <span style="color:#999;font-size:11px">(주말'+dd.we+'+공휴일'+dd.h+')</span>';
    else h+='<span style="color:#e67e22">주말 '+dd.we+'일</span>';
    h+='</div></div>';
  }}
  h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #e74c3c;padding-bottom:5px">🏆 중단 상위 3개 캠페인 ('+d.year+'년)</div>';
  var medals=['🥇','🥈','🥉'];
  if(d.camps.length>0){{
    for(var j=0;j<d.camps.length;j++){{
      var bg2=j===0?'#fff8f0':(j===1?'#fafafa':'#f5f5f5');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:'+bg2+';border-radius:10px;margin-bottom:5px">';
      h+='<span style="font-size:13px;flex:1;margin-right:10px;line-height:1.4">'+medals[j]+' '+d.camps[j].n+'</span>';
      h+='<span style="font-weight:700;color:#e74c3c;font-size:13px;white-space:nowrap">'+d.camps[j].c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건</span></div>';
    }}
  }}else{{h+='<div style="color:#999;padding:10px">데이터 없음</div>';}}
  if(d.v1!=null){{
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #3498db;padding-bottom:5px">📊 3개년 중단건 비교</div>';
    h+='<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:10px">';
    h+='<thead><tr><th style="background:#f8f9fa;padding:8px;border:1px solid #e0e0e0;text-align:center">구분</th>';
    h+='<th style="background:#eafaf1;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y1n+'</th>';
    if(d.v2!=null)h+='<th style="background:#d6eaf8;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y2n+'</th>';
    if(d.v3!=null)h+='<th style="background:#f5f5f5;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y3n+'</th>';
    h+='</tr></thead><tbody>';
    h+='<tr><td style="padding:8px;border:1px solid #e0e0e0;font-weight:600">중단(건)</td>';
    h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right;font-weight:700;color:#27ae60">'+d.v1.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    if(d.v2!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v2.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    if(d.v3!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v3.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    h+='</tr></tbody></table>';
    if(d.v2!=null){{
      var dd2=d.v1-d.v2;var pp2=d.v2!==0?((d.v1-d.v2)/d.v2*100):0;
      var cc2=dd2>0?'#e74c3c':(dd2<0?'#3498db':'#666');
      var aa2=dd2>0?'▲':(dd2<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#f0f8ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y2n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+cc2+'">'+aa2+' '+(dd2>0?'+':'')+Math.round(dd2).toLocaleString()+'건 ('+(pp2>0?'+':'')+pp2.toFixed(1)+'%)</span></div>';
    }}
    if(d.v3!=null){{
      var dd3=d.v1-d.v3;var pp3=d.v3!==0?((d.v1-d.v3)/d.v3*100):0;
      var cc3=dd3>0?'#e74c3c':(dd3<0?'#3498db':'#666');
      var aa3=dd3>0?'▲':(dd3<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#faf5ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y3n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+cc3+'">'+aa3+' '+(dd3>0?'+':'')+Math.round(dd3).toLocaleString()+'건 ('+(pp3>0?'+':'')+pp3.toFixed(1)+'%)</span></div>';
    }}
  }}
  if(d.reasons&&d.reasons.length>0){{
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #9b59b6;padding-bottom:5px">📋 중단사유별 현황 ('+d.year+'년)</div>';
    h+='<table style="width:100%;border-collapse:collapse;font-size:12px"><thead><tr><th style="background:#f5f0ff;padding:6px 10px;text-align:left;border-bottom:2px solid #9b59b6">중단사유</th><th style="background:#f5f0ff;padding:6px 10px;text-align:right;border-bottom:2px solid #9b59b6">중단(건)</th><th style="background:#f5f0ff;padding:6px 10px;text-align:right;border-bottom:2px solid #9b59b6">비중</th></tr></thead><tbody>';
    for(var k=0;k<d.reasons.length;k++){{
      var rr=d.reasons[k];var rbg=k%2===0?'#fff':'#fafafa';
      h+='<tr style="background:'+rbg+'"><td style="padding:5px 10px;border-bottom:1px solid #eee">'+rr.n+'</td>';
      h+='<td style="padding:5px 10px;text-align:right;border-bottom:1px solid #eee">'+rr.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="padding:5px 10px;text-align:right;border-bottom:1px solid #eee;color:#9b59b6;font-weight:600">'+rr.p.toFixed(1)+'%</td></tr>';
    }}
    h+='</tbody></table>';
  }}
  if(d.reasons&&d.reasons.length>0&&d.prev_reasons&&d.prev_reasons.length>0){{
    var py=d.prev_year||d.year-1;
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:18px 0 10px;border-bottom:2px solid #e67e22;padding-bottom:5px">📊 '+d.year+'년 vs '+py+'년 중단사유 비교</div>';
    var pm={{}};for(var pi=0;pi<d.prev_reasons.length;pi++){{pm[d.prev_reasons[pi].n]=d.prev_reasons[pi].c;}}
    var items=[];for(var ri=0;ri<d.reasons.length;ri++){{var rn=d.reasons[ri].n;var cv=d.reasons[ri].c;var pv=pm[rn]||0;items.push({{n:rn,c:cv,p:pv,up:cv>pv}});}}
    items.sort(function(a,b){{return b.c-a.c;}});
    var maxV=0;for(var ii=0;ii<items.length;ii++){{maxV=Math.max(maxV,items[ii].c,items[ii].p);}}
    if(maxV===0)maxV=1;
    var bh=18,gap=4,lw=120,cw2=700,ch2=items.length*(bh*2+gap)+20;
    h+='<div style="overflow-x:auto"><svg width="'+cw2+'" viewBox="0 0 '+cw2+' '+ch2+'" preserveAspectRatio="xMidYMid meet" style="width:100%;font-family:sans-serif">';
    var bw2=cw2-lw-80;
    for(var gi=0;gi<items.length;gi++){{
      var it=items[gi];var y0=gi*(bh*2+gap)+10;
      var w1=Math.max(it.c/maxV*bw2,1);var w2=Math.max(it.p/maxV*bw2,1);
      var c1=it.up?'#e74c3c':'#27ae60';var c2r='#95a5a6';
      h+='<text x="'+(lw-4)+'" y="'+(y0+bh-2)+'" text-anchor="end" font-size="10" fill="#333">'+it.n+'</text>';
      h+='<rect x="'+lw+'" y="'+y0+'" width="'+w1+'" height="'+bh+'" rx="3" fill="'+c1+'" opacity="0.85"/>';
      h+='<text x="'+(lw+w1+4)+'" y="'+(y0+bh-4)+'" font-size="9" fill="'+c1+'" font-weight="700">'+it.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</text>';
      h+='<rect x="'+lw+'" y="'+(y0+bh)+'" width="'+w2+'" height="'+bh+'" rx="3" fill="'+c2r+'" opacity="0.6"/>';
      h+='<text x="'+(lw+w2+4)+'" y="'+(y0+bh*2-4)+'" font-size="9" fill="#777">'+it.p.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</text>';
    }}
    h+='</svg></div>';
    h+='<div style="display:flex;gap:16px;margin-top:6px;font-size:11px;color:#666">';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#e74c3c;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+d.year+'년 (전년대비 증가)</span>';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#27ae60;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+d.year+'년 (전년대비 감소)</span>';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#95a5a6;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+py+'년</span>';
    h+='</div>';
  }}

  h+='</div>';
  box.innerHTML=h;
  ov.style.display='flex';
  doc.getElementById('s2-close').addEventListener('click',function(){{ov.style.display='none'}});
}}
function onClickW1(e){{
  var td=e.target.closest('td[data-popup]');
  if(!td)return;
  show(td.getAttribute('data-popup'));
}}
doc.addEventListener('click',onClickW1);
doc._s2popupW1=function(){{doc.removeEventListener('click',onClickW1)}};
}})();
</script>""", height=0)

            render_exec_chart(wk_yr_rate_s3, all_wk_cols_s3, yr_list_s3, "동월 주차별 중단율(%) 추이", "중단율(%)", is_rate=True)
        else:
            st.info("중단율 계산 데이터가 없습니다.")

        st.markdown('<div style="height:30px"></div>', unsafe_allow_html=True)
        st.markdown('<div class="section-header">4. 가입경로별 중단현황(미납중단 포함)</div>', unsafe_allow_html=True)
        wr_s4 = calc_week_ranges(year, month)
        s4_start, s4_end = wr_s4[0]
        brand_df_s4_w1 = load_brand_stop(year, s4_start.strftime("%Y%m%d"), s4_end.strftime("%Y%m%d"))
        _remarks_w1 = build_brand_remarks(year, s4_start.strftime("%Y%m%d"), s4_end.strftime("%Y%m%d"))
        st.markdown(render_brand_table(brand_df_s4_w1, remarks=_remarks_w1, popup_key="s4w1"), unsafe_allow_html=True)
        render_brand_popup_script("s4w1", build_brand_popup_payload(
            load_brand_popup_members(year, s4_start.strftime("%Y%m%d"), s4_end.strftime("%Y%m%d")), year), f"{year}년 {month}월 1주차")
        st.markdown(render_high_value_remarks(year, s4_start.strftime("%Y%m%d"), s4_end.strftime("%Y%m%d")), unsafe_allow_html=True)

# =====================================================
# [탭2] 1주차 미납중단만 (DSCNTC_RSN_CD IN 14,16)
# =====================================================
if week_no == 1 and selected_wk_tab == "unpaid":
  with tab_unpaid:
    st.markdown('<div class="section-header first">1. 신규/기존별 미납중단 현황</div>', unsafe_allow_html=True)
    st.markdown('<div class="sub-header">1) 당월 3개년 미납중단</div>', unsafe_allow_html=True)
    # st.caption("※ DSCNTC_RSN_CD IN (14=장기미납, 16=신규미납), 1주차 기간만")
    year_data_unpaid = build_section1_data(rsn_filter="'14','16'")
    st.markdown(render_11_html_table(build_combined_rows(year_data_unpaid), y1, y2, y3), unsafe_allow_html=True)

    # 미납중단 회원 상세 리스트 다운로드 (3개년) — 토글로 숨김/표시
    if st.checkbox("미납중단 회원 상세 리스트 다운로드 보기", value=False, key="chk_unpaid_download"):
        for dl_year in [y1, y2, y3]:
            with st.expander(f"📥 {dl_year}년 미납중단 회원 상세 리스트 다운로드"):
                if st.button("리스트 조회", key=f"btn_unpaid_list_{dl_year}"):
                    wr_dl = calc_week_ranges(dl_year, month)
                    s_dl, e_dl = wr_dl[0]
                    detail_df = load_dscntc_detail_list(dl_year, s_dl.strftime("%Y%m%d"), e_dl.strftime("%Y%m%d"), rsn_filter="'14','16'")
                    if not detail_df.empty:
                        st.dataframe(detail_df, use_container_width=True, height=300)
                        csv_data = detail_df.to_csv(index=False).encode("utf-8-sig")
                        st.download_button(
                            label=f"CSV 다운로드 ({len(detail_df):,}건)",
                            data=csv_data,
                            file_name=f"{dl_year}년_{month}월_1주차_미납중단_회원리스트.csv",
                            mime="text/csv",
                            key=f"dl_unpaid_csv_{dl_year}"
                        )
                    else:
                        st.info("조회된 데이터가 없습니다.")

    st.markdown('<div class="sub-header">2) 누계 3개년(미납중단)</div>', unsafe_allow_html=True)
    # st.caption(f"※ 1월~{month}월 1주차 미납중단 누계")
    # 1월 1일 ~ 조회월 1주차 종료일까지 미납중단 누계
    year_data_12_unpaid = {}
    for yy in all_years:
        cum_from_dt = datetime.date(yy, 1, 1)
        wr = calc_week_ranges(yy, month)
        _, cum_to_dt = wr[0]  # 조회월 1주차 종료일
        y_df = load_dscntc_detail(yy, cum_from_dt.strftime("%Y%m%d"), cum_to_dt.strftime("%Y%m%d"), rsn_filter="'14','16'")
        if not y_df.empty:
            new_r = y_df[y_df["NEW_EXISTING"] == "신규회원"]
            exist_r = y_df[y_df["NEW_EXISTING"] == "기존회원"]
            new_m = int(new_r["DSCNTC_MEMBERS"].sum()) if len(new_r) > 0 else 0
            new_c = float(new_r["DSCNTC_CNT"].sum()) if len(new_r) > 0 else 0.0
            exist_m = int(exist_r["DSCNTC_MEMBERS"].sum()) if len(exist_r) > 0 else 0
            exist_c = float(exist_r["DSCNTC_CNT"].sum()) if len(exist_r) > 0 else 0.0
        else:
            new_m, new_c, exist_m, exist_c = 0, 0.0, 0, 0.0
        year_data_12_unpaid[yy] = {"new_m": new_m, "new_c": new_c, "exist_m": exist_m, "exist_c": exist_c,
                                    "total_m": new_m + exist_m, "total_c": new_c + exist_c}
    st.markdown(render_11_html_table(build_combined_rows(year_data_12_unpaid), y1, y2, y3), unsafe_allow_html=True)

    st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
    st.markdown('<div style="height:80px"></div>', unsafe_allow_html=True)
    st.markdown('<div class="section-header">2. 동월 주차별 미납중단(건) 현황 <span style="font-size:11px;font-weight:400;opacity:0.8;margin-left:10px;">*월별 중단건 클릭 시 세부사항을 확인할 수 있습니다.</span></div>', unsafe_allow_html=True)
    # st.caption(f"※ 각 년도 1월~{month}월 {week_no}주차 미납중단(건) (DSCNTC_RSN_CD IN 14,16)")
    monthly_unpaid_df = load_monthly_unpaid_by_week(all_years, week_no)
    if not monthly_unpaid_df.empty:
        monthly_unpaid_df["YEAR"] = pd.to_numeric(monthly_unpaid_df["YEAR"], errors='coerce').astype(int)
        monthly_unpaid_df["MONTH"] = pd.to_numeric(monthly_unpaid_df["MONTH"], errors='coerce').astype(int)
        monthly_unpaid_df["STOP_CNT"] = pd.to_numeric(monthly_unpaid_df["STOP_CNT"], errors='coerce').fillna(0)
        monthly_data = {}
        for yy in all_years:
            monthly_data[yy] = {}
            for m in range(1, 13):
                if m <= month:
                    row = monthly_unpaid_df[(monthly_unpaid_df["YEAR"] == yy) & (monthly_unpaid_df["MONTH"] == m)]
                    monthly_data[yy][m] = float(row["STOP_CNT"].values[0]) if not row.empty else 0.0
                else:
                    monthly_data[yy][m] = None
            monthly_data[yy]["합계"] = round(sum(monthly_data[yy][m] for m in range(1, month + 1) if monthly_data[yy][m] is not None))

        month_cols = [f"{m}월" for m in range(1, 13)] + ["합계"]
        _popup_data_up = {}
        html = '<table id="tbl_unpaid" style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:0;">'
        html += '<thead><tr>'
        html += '<th style="background:#A9C1DD;color:#222;padding:6px;border:1px solid #BFBFBF;text-align:center;">구분</th>'
        for mc in month_cols:
            html += f'<th style="background:#A9C1DD;color:#222;padding:4px;border:1px solid #BFBFBF;text-align:center;">{mc}</th>'
        html += '</tr></thead><tbody>'
        year_styles = {
            y1: "font-weight:bold;",
            y2: "",
            y3: ""
        }
        for yy in all_years:
            sty = year_styles.get(yy, "")
            html += '<tr>'
            html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{sty}">{yy}년</td>'
            for m in range(1, 13):
                val = monthly_data[yy][m]
                if val is not None and val > 0:
                    dp_key_up = f"{yy}_{m}"
                    html += f'<td data-popup="{dp_key_up}" style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}cursor:pointer;" title="클릭 시 상세보기">{val:,.0f}</td>'
                    if dp_key_up not in _popup_data_up:
                        _wr_up = calc_week_ranges(yy, m)
                        if week_no <= len(_wr_up):
                            _ws_up, _we_up = _wr_up[week_no - 1]
                        else:
                            _ws_up, _we_up = _wr_up[0]
                        _days_up = []
                        for _yy2 in all_years:
                            _wr2_up = calc_week_ranges(_yy2, m)
                            if week_no <= len(_wr2_up):
                                _ws2, _we2 = _wr2_up[week_no - 1]
                            else:
                                _ws2, _we2 = _wr2_up[0]
                            _di2 = calc_day_info(_ws2, _we2)
                            _days_up.append({"y": _yy2, "p": f"{_ws2.month}/{_ws2.day}~{_we2.month}/{_we2.day}", "t": _di2["total"], "wd": _di2["weekdays"], "we": _di2["weekends"], "h": _di2["holidays"]})
                        _top3_up = load_top3_campaigns(yy, _ws_up.strftime("%Y%m%d"), _we_up.strftime("%Y%m%d"))
                        _camps_up = []
                        if not _top3_up.empty:
                            for _, _r in _top3_up.iterrows():
                                _camps_up.append({"n": str(_r["CAMPAIGN_NAME"]), "c": float(_r["DSCNTC_CNT"])})
                        _rsn_up = load_dscntc_by_reason(yy, _ws_up.strftime("%Y%m%d"), _we_up.strftime("%Y%m%d"))
                        _reasons_up = []
                        if not _rsn_up.empty:
                            _rtotal_up = float(_rsn_up["DSCNTC_CNT"].sum())
                            for _, _rr in _rsn_up.iterrows():
                                _rv = float(_rr["DSCNTC_CNT"])
                                _reasons_up.append({"n": str(_rr["REASON_NAME"]), "c": _rv, "p": round(_rv / _rtotal_up * 100, 1) if _rtotal_up > 0 else 0})
                        _prev_yr_up = yy - 1
                        _prev_reasons_up = []
                        _wr_prev_up = calc_week_ranges(_prev_yr_up, m)
                        if week_no <= len(_wr_prev_up):
                            _wsp_up, _wep_up = _wr_prev_up[week_no - 1]
                        else:
                            _wsp_up, _wep_up = _wr_prev_up[0]
                        _rsn_prev_up = load_dscntc_by_reason(_prev_yr_up, _wsp_up.strftime("%Y%m%d"), _wep_up.strftime("%Y%m%d"))
                        if not _rsn_prev_up.empty:
                            for _, _rp in _rsn_prev_up.iterrows():
                                _prev_reasons_up.append({"n": str(_rp["REASON_NAME"]), "c": float(_rp["DSCNTC_CNT"])})
                        _popup_data_up[dp_key_up] = {"title": f"{m}월 {week_no}주차 미납중단 상세 ({yy}년)", "year": int(yy), "week": week_no, "days": _days_up, "camps": _camps_up, "reasons": _reasons_up, "prev_reasons": _prev_reasons_up, "prev_year": _prev_yr_up}
                elif val is not None:
                    html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}">{val:,.0f}</td>'
                else:
                    html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}"></td>'
            html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{sty}">{monthly_data[yy]["합계"]:,.0f}</td>'
            html += '</tr>'
        diff_sty = "font-weight:bold;"
        for label, ya, yb in [(f"{y1}-{y2}증감(건)", y1, y2), (f"{y1}-{y3}증감(건)", y1, y3)]:
            html += '<tr>'
            html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:left;{diff_sty}">{label}</td>'
            for m in range(1, 13):
                va = monthly_data[ya][m]
                vb = monthly_data[yb][m]
                if va is not None and vb is not None:
                    diff = va - vb
                    html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{diff_sty}">{diff:+,.0f}</td>'
                else:
                    html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{diff_sty}"></td>'
            total_diff = monthly_data[ya]["합계"] - monthly_data[yb]["합계"]
            html += f'<td style="padding:5px;border:1px solid #BFBFBF;text-align:right;{diff_sty}">{total_diff:+,.0f}</td>'
            html += '</tr>'
        html += '</tbody></table>'
        st.markdown(html, unsafe_allow_html=True)

        import json as _json_up
        _pjson_up = _json_up.dumps(_popup_data_up, ensure_ascii=False)
        stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._s2popupUp){{try{{doc._s2popupUp()}}catch(e){{}}}}
var D={_pjson_up};
var ov=doc.getElementById('s2-popup-overlay');
if(!ov){{
  ov=doc.createElement('div');ov.id='s2-popup-overlay';
  ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:80px;';
  ov.innerHTML='<div id="s2-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:900px;width:92%;max-height:80vh;overflow-y:auto;animation:s2pop .2s ease"></div>';
  var st=doc.createElement('style');
  st.textContent='@keyframes s2pop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}td[data-popup]{{cursor:pointer}}td[data-popup]:hover{{background:rgba(26,115,232,0.10)!important}}';
  doc.head.appendChild(st);
  doc.body.appendChild(ov);
  ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
}}
var box=doc.getElementById('s2-popup-box');
function show(key){{
  var d=D[key];if(!d)return;
  if(d.type==='rate'){{
    var h='<div style="background:linear-gradient(135deg,#2C3E50,#9b59b6);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
    h+='<span style="font-weight:700;font-size:15px">📈 '+d.wk+' 중단율 비교</span>';
    h+='<span id="s2-close" style="cursor:pointer;font-size:20px;opacity:0.8">✕</span></div>';
    h+='<div style="padding:18px 20px">';
    h+='<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:10px">';
    h+='<thead><tr><th style="background:#f8f9fa;padding:8px;border:1px solid #e0e0e0;text-align:center">구분</th>';
    h+='<th style="background:#eafaf1;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y1n+'</th>';
    if(d.v2!=null)h+='<th style="background:#d6eaf8;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y2n+'</th>';
    if(d.v3!=null)h+='<th style="background:#f5f5f5;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y3n+'</th>';
    h+='</tr></thead><tbody>';
    h+='<tr><td style="padding:8px;border:1px solid #e0e0e0;font-weight:600">중단율(%)</td>';
    if(d.v1!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right;font-weight:700;color:#27ae60">'+d.v1.toFixed(2)+'%</td>';
    if(d.v2!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v2.toFixed(2)+'%</td>';
    if(d.v3!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v3.toFixed(2)+'%</td>';
    h+='</tr></tbody></table>';
    if(d.d2!=null){{
      var c2=d.d2>0?'#e74c3c':(d.d2<0?'#3498db':'#666');
      var a2=d.d2>0?'▲':(d.d2<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#f0f8ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y2n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+c2+'">'+a2+' '+(d.d2>0?'+':'')+d.d2.toFixed(2)+'%p</span></div>';
    }}
    if(d.d3!=null){{
      var c3=d.d3>0?'#e74c3c':(d.d3<0?'#3498db':'#666');
      var a3=d.d3>0?'▲':(d.d3<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#faf5ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y3n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+c3+'">'+a3+' '+(d.d3>0?'+':'')+d.d3.toFixed(2)+'%p</span></div>';
    }}
    h+='</div>';
    box.innerHTML=h;
    ov.style.display='flex';
    doc.getElementById('s2-close').addEventListener('click',function(){{ov.style.display='none'}});
    return;
  }}
  var h='<div style="background:linear-gradient(135deg,#2C3E50,#34495E);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:16px;font-weight:700">'+d.title+'</span>';
  h+='<span id="s2-close" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px;transition:background .15s" onmouseover="this.style.background=\\'rgba(255,255,255,0.2)\\'" onmouseout="this.style.background=\\'transparent\\'">✕</span></div>';
  h+='<div style="padding:18px 22px">';
  h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin-bottom:10px;border-bottom:2px solid #667eea;padding-bottom:5px">📅 기간 및 일수</div>';
  for(var i=0;i<d.days.length;i++){{
    var dd=d.days[i];var isPrimary=(dd.y===d.year);
    var bg=isPrimary?'background:#f0fdf4;border-left:3px solid #27ae60;padding:10px 14px;border-radius:0 10px 10px 0':'padding:10px 14px;background:#fafafa;border-radius:10px';
    var yc=isPrimary?'#1a9c6e':'#555';
    h+='<div style="'+bg+';margin-bottom:6px">';
    h+='<div style="font-weight:700;color:'+yc+';font-size:14px">'+dd.y+'년 <span style="color:#888;font-size:12px;font-weight:400;margin-left:6px">'+dd.p+'</span></div>';
    h+='<div style="font-size:13px;margin-top:3px;color:#555">총 <b>'+dd.t+'</b>일 &nbsp;<span style="color:#2980b9">평일 '+dd.wd+'일</span> &nbsp;';
    if(dd.h>0)h+='<span style="color:#e67e22">주말·공휴일 '+(dd.we+dd.h)+'일</span> <span style="color:#999;font-size:11px">(주말'+dd.we+'+공휴일'+dd.h+')</span>';
    else h+='<span style="color:#e67e22">주말 '+dd.we+'일</span>';
    h+='</div></div>';
  }}
  h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #e74c3c;padding-bottom:5px">🏆 중단 상위 3개 캠페인 ('+d.year+'년)</div>';
  var medals=['🥇','🥈','🥉'];
  if(d.camps.length>0){{
    for(var j=0;j<d.camps.length;j++){{
      var bg2=j===0?'#fff8f0':(j===1?'#fafafa':'#f5f5f5');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:'+bg2+';border-radius:10px;margin-bottom:5px">';
      h+='<span style="font-size:13px;flex:1;margin-right:10px;line-height:1.4">'+medals[j]+' '+d.camps[j].n+'</span>';
      h+='<span style="font-weight:700;color:#e74c3c;font-size:13px;white-space:nowrap">'+d.camps[j].c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건</span></div>';
    }}
  }}else{{h+='<div style="color:#999;padding:10px">데이터 없음</div>';}}
  if(d.v1!=null){{
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #3498db;padding-bottom:5px">📊 3개년 중단건 비교</div>';
    h+='<table style="width:100%;border-collapse:collapse;font-size:13px;margin-bottom:10px">';
    h+='<thead><tr><th style="background:#f8f9fa;padding:8px;border:1px solid #e0e0e0;text-align:center">구분</th>';
    h+='<th style="background:#eafaf1;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y1n+'</th>';
    if(d.v2!=null)h+='<th style="background:#d6eaf8;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y2n+'</th>';
    if(d.v3!=null)h+='<th style="background:#f5f5f5;padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.y3n+'</th>';
    h+='</tr></thead><tbody>';
    h+='<tr><td style="padding:8px;border:1px solid #e0e0e0;font-weight:600">중단(건)</td>';
    h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right;font-weight:700;color:#27ae60">'+d.v1.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    if(d.v2!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v2.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    if(d.v3!=null)h+='<td style="padding:8px;border:1px solid #e0e0e0;text-align:right">'+d.v3.toLocaleString(undefined,{{minimumFractionDigits:0}})+'</td>';
    h+='</tr></tbody></table>';
    if(d.v2!=null){{
      var dd2=d.v1-d.v2;var pp2=d.v2!==0?((d.v1-d.v2)/d.v2*100):0;
      var cc2=dd2>0?'#e74c3c':(dd2<0?'#3498db':'#666');
      var aa2=dd2>0?'▲':(dd2<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#f0f8ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y2n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+cc2+'">'+aa2+' '+(dd2>0?'+':'')+Math.round(dd2).toLocaleString()+'건 ('+(pp2>0?'+':'')+pp2.toFixed(1)+'%)</span></div>';
    }}
    if(d.v3!=null){{
      var dd3=d.v1-d.v3;var pp3=d.v3!==0?((d.v1-d.v3)/d.v3*100):0;
      var cc3=dd3>0?'#e74c3c':(dd3<0?'#3498db':'#666');
      var aa3=dd3>0?'▲':(dd3<0?'▼':'—');
      h+='<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 14px;background:#faf5ff;border-radius:8px;margin-bottom:6px">';
      h+='<span style="font-size:13px;font-weight:600">vs '+d.y3n+'</span>';
      h+='<span style="font-size:14px;font-weight:700;color:'+cc3+'">'+aa3+' '+(dd3>0?'+':'')+Math.round(dd3).toLocaleString()+'건 ('+(pp3>0?'+':'')+pp3.toFixed(1)+'%)</span></div>';
    }}
  }}
  if(d.reasons&&d.reasons.length>0){{
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:14px 0 10px;border-bottom:2px solid #9b59b6;padding-bottom:5px">📋 중단사유별 현황 ('+d.year+'년)</div>';
    h+='<table style="width:100%;border-collapse:collapse;font-size:12px"><thead><tr><th style="background:#f5f0ff;padding:6px 10px;text-align:left;border-bottom:2px solid #9b59b6">중단사유</th><th style="background:#f5f0ff;padding:6px 10px;text-align:right;border-bottom:2px solid #9b59b6">중단(건)</th><th style="background:#f5f0ff;padding:6px 10px;text-align:right;border-bottom:2px solid #9b59b6">비중</th></tr></thead><tbody>';
    for(var k=0;k<d.reasons.length;k++){{
      var rr=d.reasons[k];var rbg=k%2===0?'#fff':'#fafafa';
      h+='<tr style="background:'+rbg+'"><td style="padding:5px 10px;border-bottom:1px solid #eee">'+rr.n+'</td>';
      h+='<td style="padding:5px 10px;text-align:right;border-bottom:1px solid #eee">'+rr.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="padding:5px 10px;text-align:right;border-bottom:1px solid #eee;color:#9b59b6;font-weight:600">'+rr.p.toFixed(1)+'%</td></tr>';
    }}
    h+='</tbody></table>';
  }}
  if(d.reasons&&d.reasons.length>0&&d.prev_reasons&&d.prev_reasons.length>0){{
    var py=d.prev_year||d.year-1;
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin:18px 0 10px;border-bottom:2px solid #e67e22;padding-bottom:5px">📊 '+d.year+'년 vs '+py+'년 중단사유 비교</div>';
    var pm={{}};for(var pi=0;pi<d.prev_reasons.length;pi++){{pm[d.prev_reasons[pi].n]=d.prev_reasons[pi].c;}}
    var items=[];for(var ri=0;ri<d.reasons.length;ri++){{var rn=d.reasons[ri].n;var cv=d.reasons[ri].c;var pv=pm[rn]||0;items.push({{n:rn,c:cv,p:pv,up:cv>pv}});}}
    items.sort(function(a,b){{return b.c-a.c;}});
    var maxV=0;for(var ii=0;ii<items.length;ii++){{maxV=Math.max(maxV,items[ii].c,items[ii].p);}}
    if(maxV===0)maxV=1;
    var bh=18,gap=4,lw=120,cw2=700,ch2=items.length*(bh*2+gap)+20;
    h+='<div style="overflow-x:auto"><svg width="'+cw2+'" viewBox="0 0 '+cw2+' '+ch2+'" preserveAspectRatio="xMidYMid meet" style="width:100%;font-family:sans-serif">';
    var bw2=cw2-lw-80;
    for(var gi=0;gi<items.length;gi++){{
      var it=items[gi];var y0=gi*(bh*2+gap)+10;
      var w1=Math.max(it.c/maxV*bw2,1);var w2=Math.max(it.p/maxV*bw2,1);
      var c1=it.up?'#e74c3c':'#27ae60';var c2r='#95a5a6';
      h+='<text x="'+(lw-4)+'" y="'+(y0+bh-2)+'" text-anchor="end" font-size="10" fill="#333">'+it.n+'</text>';
      h+='<rect x="'+lw+'" y="'+y0+'" width="'+w1+'" height="'+bh+'" rx="3" fill="'+c1+'" opacity="0.85"/>';
      h+='<text x="'+(lw+w1+4)+'" y="'+(y0+bh-4)+'" font-size="9" fill="'+c1+'" font-weight="700">'+it.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</text>';
      h+='<rect x="'+lw+'" y="'+(y0+bh)+'" width="'+w2+'" height="'+bh+'" rx="3" fill="'+c2r+'" opacity="0.6"/>';
      h+='<text x="'+(lw+w2+4)+'" y="'+(y0+bh*2-4)+'" font-size="9" fill="#777">'+it.p.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</text>';
    }}
    h+='</svg></div>';
    h+='<div style="display:flex;gap:16px;margin-top:6px;font-size:11px;color:#666">';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#e74c3c;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+d.year+'년 (전년대비 증가)</span>';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#27ae60;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+d.year+'년 (전년대비 감소)</span>';
    h+='<span><span style="display:inline-block;width:10px;height:10px;background:#95a5a6;border-radius:2px;margin-right:3px;vertical-align:middle"></span>'+py+'년</span>';
    h+='</div>';
  }}

  h+='</div>';
  box.innerHTML=h;
  ov.style.display='flex';
  doc.getElementById('s2-close').addEventListener('click',function(){{ov.style.display='none'}});
}}
function onClickUp(e){{
  var td=e.target.closest('td[data-popup]');
  if(!td)return;
  show(td.getAttribute('data-popup'));
}}
doc.addEventListener('click',onClickUp);
doc._s2popupUp=function(){{doc.removeEventListener('click',onClickUp)}};
}})();
</script>""", height=0)

        st.markdown("&nbsp;")
        # SVG 차트 (6월 1주(전체) 탭과 동일 스타일)
        _up_data = {f"{m}월": {f"{y}년": monthly_data.get(y, {}).get(m) for y in all_years} for m in range(1, 13)}
        render_exec_chart(_up_data, [f"{m}월" for m in range(1, 13)], [f"{y}년" for y in all_years], "3개년 미납중단 월별 중단(건)", "중단(건)")
    else:
        st.info("미납중단 월별 데이터가 없습니다.")

    st.markdown('<div style="height:30px"></div>', unsafe_allow_html=True)
    st.markdown('<div class="section-header">3. 가입경로별 미납중단 현황</div>', unsafe_allow_html=True)
    _unpaid_rsn = "'14','16'"
    brand_df_unpaid = load_brand_stop(year, dscntc_from, dscntc_to, rsn_filter=_unpaid_rsn)
    _remarks_unpaid = build_brand_remarks(year, dscntc_from, dscntc_to, rsn_filter=_unpaid_rsn)
    st.markdown(render_brand_table(brand_df_unpaid, remarks=_remarks_unpaid, popup_key="unpaid"), unsafe_allow_html=True)
    render_brand_popup_script("unpaid", build_brand_popup_payload(
        load_brand_popup_members(year, dscntc_from, dscntc_to, rsn_filter=_unpaid_rsn), year), f"{year}년 {month}월 {week_no}주차 미납중단")
    st.markdown(render_high_value_remarks(year, dscntc_from, dscntc_to, rsn_filter=_unpaid_rsn), unsafe_allow_html=True)
