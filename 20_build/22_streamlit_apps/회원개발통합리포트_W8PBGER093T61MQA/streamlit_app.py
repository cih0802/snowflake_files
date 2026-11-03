"""
회원개발 통합 리포트 — Snowflake Streamlit
월간 회원개발 실적 보고를 위한 Executive Dashboard

DEMO_MODE=True 상태에서 Snowflake 객체 없이 전체 UI 실행 가능
"""
import os
import math
from datetime import date
from typing import Optional

import pandas as pd
import altair as alt
import streamlit as st

# ══════════════════════════════════════════════════════════
# 1. PAGE CONFIG (must be first Streamlit call)
# ══════════════════════════════════════════════════════════
st.set_page_config(
    page_title="회원개발 통합 리포트",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ══════════════════════════════════════════════════════════
# 2. APP CONFIG
# ══════════════════════════════════════════════════════════
APP_CONFIG = {
    "demo_mode": False,
    "data_validation": {
        "skill_name": "snowflake-mstr-dw-to-ods",
        "skill_available": True,
        "actual_data_validated": True,
        "validated_at": "2026-10-12",
        "validated_report_month": "202609",
        "validation_notes": "SERVING 뷰 기반 실 데이터 연동 완료",
    },
    "snowflake": {
        "database": "GN_DW",
        "schema": "SERVING",
        "source_schema": "GOLD",
        "views": {
            "goal": "MSTR_DVLP_GOAL_V",
            "achievement": "FACT_MEMBER_DEV_ACHIEVEMENT",
            "ye_trend": "MSTR_DVLP_YE_TREND_V",
            "ye_trend_bsns": "MSTR_DVLP_YE_TREND_BSNS_V",
        },
    },
    "org_mapping": {
        "hq_teams": ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀", "캠페인기획2팀"],
        "participation_team": "회원참여팀",
        "csr_team": "사회공헌협력팀",
    },
    "thresholds": {
        "achievement_good": 1.0,
        "achievement_warning": 0.8,
    },
    "features": {
        "show_three_year_average": True,
    },
}

DEMO_MODE = APP_CONFIG["demo_mode"]
ORG_MAP = APP_CONFIG["org_mapping"]

# ══════════════════════════════════════════════════════════
# 3. BRAND COLORS
# ══════════════════════════════════════════════════════════
GN_GREEN = "#89A230"
GN_DARK_BROWN = "#685A55"
GN_ORANGE = "#F16521"
GN_SKYBLUE = "#5DC6CF"
GN_YELLOW = "#FFD55B"
GN_BEIGE = "#C2B49A"
GN_PURPLE = "#9A5F9B"
MONO_GREEN_1 = "#E9EADE"
MONO_GREEN_2 = "#D5DAB4"
MONO_GREEN_3 = "#718B29"
MONO_GREEN_4 = "#556A1F"
MONO_WARM_1 = "#F2EFED"
MONO_WARM_2 = "#CDC4BF"
MONO_WARM_3 = "#8B7F79"
MONO_WARM_4 = "#57463D"

YEAR_COLORS = {2023: GN_BEIGE, 2024: GN_ORANGE, 2025: GN_SKYBLUE, 2026: GN_GREEN}
ACH_GOOD = APP_CONFIG["thresholds"]["achievement_good"]
ACH_WARN = APP_CONFIG["thresholds"]["achievement_warning"]

# ══════════════════════════════════════════════════════════
# 4. CSS
# ══════════════════════════════════════════════════════════
GLOBAL_CSS = f"""
<style>
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;600;700&display=swap');
:root {{
    --gn-green: {GN_GREEN};
    --gn-brown: {GN_DARK_BROWN};
    --gn-orange: {GN_ORANGE};
    --mono-green-1: {MONO_GREEN_1};
    --mono-warm-1: {MONO_WARM_1};
}}
html, body, [class*="st-"] {{
    font-family: 'Noto Sans KR', 'Noto Sans', sans-serif;
}}
/* Left navigation panel */
.nav-panel {{
    background: {GN_DARK_BROWN};
    border-radius: 8px;
    padding: 1.2rem 1rem;
    position: sticky;
    top: 0;
    color: #FFF;
}}
.nav-panel .nav-title {{
    font-size: 0.72rem; color: {MONO_GREEN_2}; letter-spacing: 2px;
}}
.nav-panel .nav-brand {{
    font-size: 0.88rem; font-weight: 700; color: #FFF; margin-top: 0.1rem;
}}
.nav-panel .nav-app-name {{
    font-size: 1rem; font-weight: 700; color: #FFF; margin-top: 0.4rem;
    margin-bottom: 0.8rem;
}}
.nav-panel .nav-filter-label {{
    font-size: 0.78rem; color: {MONO_GREEN_2}; margin-bottom: 0.3rem;
}}
.nav-panel .nav-divider {{
    border: none; border-top: 1px solid rgba(255,255,255,0.2); margin: 0.8rem 0;
}}
.nav-panel .nav-item {{
    display: block;
    padding: 0.5rem 0.7rem;
    margin: 0.15rem 0;
    color: #FFF;
    text-decoration: none;
    border-radius: 5px;
    font-size: 0.85rem;
    cursor: pointer;
}}
.nav-panel .nav-item:hover {{
    background: rgba(255,255,255,0.15);
}}
.nav-panel .nav-item.active {{
    background: {GN_GREEN};
    font-weight: 600;
}}
.nav-demo-badge {{
    margin-top: 1rem;
    padding: 0.5rem;
    background: rgba(255,213,91,0.2);
    border-radius: 6px;
    font-size: 0.72rem;
    text-align: center;
    color: {GN_YELLOW};
}}
/* KPI card */
.kpi-card {{
    background: #FFF;
    border: 1px solid #E0E0E0;
    border-radius: 10px;
    padding: 1.2rem 1.4rem;
    text-align: center;
    min-height: 150px;
    display: flex; flex-direction: column; justify-content: center;
}}
.kpi-label {{
    font-size: 0.82rem; font-weight: 600; color: {GN_DARK_BROWN};
    margin-bottom: 0.3rem;
}}
.kpi-value {{
    font-size: 1.9rem; font-weight: 700; color: {GN_DARK_BROWN};
    line-height: 1.2;
}}
.kpi-sub {{
    font-size: 0.78rem; margin-top: 0.35rem; color: {MONO_WARM_3};
}}
.kpi-up {{ color: {GN_GREEN}; font-weight: 600; }}
.kpi-down {{ color: {GN_ORANGE}; font-weight: 600; }}
/* Section header */
.section-header {{
    background: {GN_DARK_BROWN};
    color: #FFF;
    padding: 0.6rem 1.2rem;
    border-radius: 6px;
    font-size: 1.1rem;
    font-weight: 700;
    margin-top: 2.5rem;
    margin-bottom: 0.6rem;
}}
.section-sub {{
    font-size: 0.85rem; color: {MONO_WARM_3};
    margin-bottom: 1rem;
}}
/* Report tables */
.report-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 0.82rem;
    margin: 0.5rem 0 1.5rem 0;
}}
.report-table th {{
    background: {GN_DARK_BROWN};
    color: #FFF;
    padding: 0.5rem 0.7rem;
    font-weight: 600;
    text-align: center;
    border: 1px solid {MONO_WARM_2};
    white-space: nowrap;
}}
.report-table th.sub-header {{
    background: {MONO_GREEN_3};
}}
.report-table td {{
    padding: 0.4rem 0.7rem;
    border-bottom: 1px solid #EEE;
    vertical-align: middle;
}}
.report-table td.num {{
    text-align: right;
    font-variant-numeric: tabular-nums;
}}
.report-table td.left {{
    text-align: left;
}}
.report-table td.bold, .report-table td.bold {{
    font-weight: 700;
}}
.report-table tr.subtotal td {{
    background: {MONO_GREEN_1};
    font-weight: 600;
}}
.report-table tr.hq-subtotal td {{
    background: {MONO_GREEN_2};
    font-weight: 700;
}}
.report-table tr.grand-total td {{
    background: {GN_DARK_BROWN};
    color: #FFF;
    font-weight: 700;
}}
.report-table td.indent-1 {{ padding-left: 1.5rem; }}
.report-table td.indent-2 {{ padding-left: 2.8rem; }}
.ach-good {{ color: {GN_GREEN}; font-weight: 600; }}
.ach-warn {{ color: {GN_ORANGE}; font-weight: 600; }}
.ach-bad {{ color: #D32F2F; font-weight: 600; }}
.delta-up {{ color: {GN_GREEN}; }}
.delta-down {{ color: {GN_ORANGE}; }}
/* Highlight boxes */
.insight-box {{
    background: {MONO_GREEN_1};
    border-left: 4px solid {GN_GREEN};
    border-radius: 0 6px 6px 0;
    padding: 1rem 1.2rem;
    margin: 0.5rem 0;
    font-size: 0.88rem;
}}
.insight-box strong {{ color: {GN_DARK_BROWN}; }}
.footer-note {{
    font-size: 0.82rem;
    color: {MONO_WARM_3};
    border-top: 1px solid #EEE;
    padding-top: 0.8rem;
    margin-top: 1.5rem;
}}
.demo-banner {{
    background: {GN_YELLOW};
    color: {GN_DARK_BROWN};
    padding: 0.5rem 1rem;
    border-radius: 6px;
    font-size: 0.82rem;
    font-weight: 600;
    text-align: center;
    margin-bottom: 1rem;
}}
</style>
"""
st.markdown(GLOBAL_CSS, unsafe_allow_html=True)

# ══════════════════════════════════════════════════════════
# 5. UTILITY FUNCTIONS
# ══════════════════════════════════════════════════════════
def safe_divide(numerator, denominator, default=None):
    if denominator is None or denominator == 0:
        return default
    if numerator is None:
        return default
    return numerator / denominator


def format_number(val, decimal=1):
    if val is None or (isinstance(val, float) and (math.isnan(val) or math.isinf(val))):
        return "-"
    if decimal == 0:
        return f"{val:,.0f}"
    return f"{val:,.{decimal}f}"


def format_percent(val, decimal=1):
    if val is None or (isinstance(val, float) and (math.isnan(val) or math.isinf(val))):
        return "-"
    return f"{val * 100:,.{decimal}f}%"


def format_percent_pp(val, decimal=1):
    if val is None or (isinstance(val, float) and (math.isnan(val) or math.isinf(val))):
        return "-"
    v = val * 100
    sign = "+" if v > 0 else ""
    return f"{sign}{v:,.{decimal}f}%p"


def delta_html(rate, label=""):
    if rate is None or (isinstance(rate, float) and (math.isnan(rate) or math.isinf(rate))):
        return f'<span class="kpi-sub">{label} -</span>'
    v = rate * 100
    if v > 0:
        return f'<span class="kpi-up">▲ +{v:.1f}% {label}</span>'
    elif v < 0:
        return f'<span class="kpi-down">▼ {v:.1f}% {label}</span>'
    return f'<span class="kpi-sub">0.0% {label}</span>'


def delta_text(rate):
    if rate is None or (isinstance(rate, float) and (math.isnan(rate) or math.isinf(rate))):
        return "-"
    v = rate * 100
    if v > 0:
        return f"▲ +{v:.1f}%"
    elif v < 0:
        return f"▼ {v:.1f}%"
    return "0.0%"


def ach_class(rate):
    if rate is None:
        return ""
    if rate >= ACH_GOOD:
        return "ach-good"
    if rate >= ACH_WARN:
        return "ach-warn"
    return "ach-bad"


def fmt_int(val):
    if val is None or (isinstance(val, float) and (math.isnan(val) or math.isinf(val))):
        return "-"
    return f"{val:,.0f}"


def fmt_dec(val, d=1):
    return format_number(val, d)


def fmt_pct(val, d=1):
    return format_percent(val, d)


def calculate_growth_rate(current, previous):
    if previous is None or previous == 0:
        if current is not None and current != 0:
            return None  # new item
        return None
    if current is None:
        return None
    return (current - previous) / abs(previous)


# ══════════════════════════════════════════════════════════
# 6. DEMO DATA GENERATION
# ══════════════════════════════════════════════════════════
def get_demo_available_months():
    months = []
    for y in [2026, 2025]:
        end_m = 9 if y == 2026 else 12
        for m in range(end_m, 0, -1):
            months.append({"year": y, "month": m, "label": f"{y}년 {m}월"})
    return pd.DataFrame(months)


def _build_detail_rows():
    """Build the full monthly detail data for 2026-09 and comparable periods."""
    # org_l1, org_l2, perf_type, sort, row_type, month_target, month_actual, annual_target
    # Designed so subtotals match sum of detail rows
    rows = [
        # -- 나눔마케팅본부 --
        # 매체운영팀
        ("본부", "매체운영팀", "디지털", 110, "detail", 3400, 3560.2, 40800),
        ("본부", "매체운영팀", "영상광고", 120, "detail", 1200, 1148.5, 14400),
        ("본부", "매체운영팀", "재송출", 130, "detail", 800, 821.0, 9600),
        ("본부", "매체운영팀", "콜개발", 140, "detail", 600, 635.3, 7200),
        ("본부", "매체운영팀", "소계", 150, "subtotal", 6000, 6165.0, 72000),
        # 마케팅기획1팀
        ("본부", "마케팅기획1팀", "방송", 210, "detail", 3800, 3912.4, 45600),
        ("본부", "마케팅기획1팀", "디지털", 220, "detail", 1700, 1743.6, 20400),
        ("본부", "마케팅기획1팀", "소계", 230, "subtotal", 5500, 5656.0, 66000),
        # 마케팅기획2팀
        ("본부", "마케팅기획2팀", "방송", 310, "detail", 2200, 2115.8, 26400),
        ("본부", "마케팅기획2팀", "뉴미디어", 320, "detail", 900, 957.2, 10800),
        ("본부", "마케팅기획2팀", "디지털", 330, "detail", 1400, 1467.5, 16800),
        ("본부", "마케팅기획2팀", "소계", 340, "subtotal", 4500, 4540.5, 54000),
        # 컬쳐콘텐츠팀
        ("본부", "컬쳐콘텐츠팀", "디지털", 410, "detail", 1800, 1892.5, 21600),
        ("본부", "컬쳐콘텐츠팀", "소계", 420, "subtotal", 1800, 1892.5, 21600),
        # 나눔마케팅본부 소계
        ("본부", "나눔마케팅본부", "소계", 500, "hq_subtotal", 17800, 18254.0, 213600),
        # 회원참여팀
        ("회원참여팀", "회원참여팀", "온라인", 610, "detail", 1300, 1342.7, 15600),
        ("회원참여팀", "회원참여팀", "콜", 620, "detail", 800, 785.0, 9600),
        ("회원참여팀", "회원참여팀", "오프라인", 630, "detail", 500, 528.0, 6000),
        ("회원참여팀", "회원참여팀", "소계", 640, "subtotal", 2600, 2655.7, 31200),
        # 기타(기업개발)
        ("기타", "기업개발", "", 710, "detail", 813, 846.0, 9756),
        # 본부 소계
        ("본부 소계", "본부 소계", "", 800, "hq_subtotal", 21213, 21755.7, 254556),
        # 대면모금
        ("대면모금", "대면모금", "", 900, "detail", 3200, 3300.0, 60000),
        # 시도본부/지부
        ("시도본부", "시도본부 및 지부", "", 950, "detail", 1400, 1400.0, 33444),
        # 총계
        ("총계", "총계", "", 999, "grand_total", 25813, 26455.7, 348000),
    ]
    cols = ["org_l1", "org_l2", "perf_type", "sort_order", "row_type",
            "month_target", "month_actual", "annual_target"]
    return pd.DataFrame(rows, columns=cols)


def _make_monthly_series(annual, monthly_weights=None):
    """Generate 9 monthly values that sum to a plausible YTD."""
    if monthly_weights is None:
        monthly_weights = [0.09, 0.09, 0.10, 0.11, 0.11, 0.12, 0.12, 0.13, 0.13]
    return [round(annual * w, 1) for w in monthly_weights]


def create_demo_monthly_data(sel_year, sel_month):
    """Return a DataFrame with monthly detail rows for the selected period and prior year."""
    base = _build_detail_rows()
    base["report_year"] = sel_year
    base["report_month_no"] = sel_month

    # Build YTD by scaling: ytd ≈ month_actual * factor(month)
    ytd_factor = {1: 1.0, 2: 2.05, 3: 3.12, 4: 4.22, 5: 5.35, 6: 6.50,
                  7: 7.68, 8: 8.88, 9: 9.45, 10: 10.50, 11: 11.55, 12: 12.60}
    f = ytd_factor.get(sel_month, sel_month)
    base["ytd_actual"] = (base["month_actual"] * f).round(1)
    base["ytd_target"] = (base["month_target"] * sel_month).round(0)

    # Previous year — slightly lower
    prev = base.copy()
    prev["report_year"] = sel_year - 1
    prev["month_actual"] = (prev["month_actual"] * 0.93).round(1)
    prev["ytd_actual"] = (prev["ytd_actual"] * 0.94).round(1)
    prev["month_target"] = (prev["month_target"] * 0.97).round(0)
    prev["ytd_target"] = (prev["ytd_target"] * 0.97).round(0)
    prev["annual_target"] = (prev["annual_target"] * 0.97).round(0)

    return pd.concat([base, prev], ignore_index=True)


def create_demo_trend_data(sel_year, sel_month):
    """4-year monthly data for trend chart."""
    rows = []
    base_monthly = [21200, 22100, 24500, 26800, 27300, 29400, 30200, 28800, 26500, 25100, 23800, 22600]
    growth = {2023: 0.85, 2024: 0.92, 2025: 1.0, 2026: 1.07}
    for yr in range(sel_year - 3, sel_year + 1):
        g = growth.get(yr, 1.0)
        row = {"year": yr}
        for m in range(1, 13):
            if yr == sel_year and m > sel_month:
                row[m] = None
            else:
                row[m] = round(base_monthly[m - 1] * g)
        rows.append(row)
    return pd.DataFrame(rows)


def create_demo_sponsorship_data(sel_year, sel_month):
    """Sponsorship by legal entity type."""
    # team, spon_type, all_target, all_actual, corp_target, corp_actual, welfare_target, welfare_actual
    rows = [
        ("매체운영팀", "국내", 28000, 20185.0, 28000, 19785.0, None, 400.0),
        ("매체운영팀", "결연", 12000, 10230.5, 12000, 9430.5, None, 800.0),
        ("매체운영팀", "해외", 22000, 17584.5, 22000, 17084.5, None, 500.0),
        ("매체운영팀", "기타", 10000, 7485.0, 10000, 7285.0, None, 200.0),
        ("매체운영팀", "소계", 72000, 55485.0, 72000, 53585.0, None, 1900.0),

        ("마케팅기획1팀", "국내", 25000, 19254.0, 25000, 18654.0, None, 600.0),
        ("마케팅기획1팀", "결연", 11000, 9950.0, 11000, 9350.0, None, 600.0),
        ("마케팅기획1팀", "해외", 20000, 16456.0, 20000, 15956.0, None, 500.0),
        ("마케팅기획1팀", "기타", 10000, 7440.0, 10000, 7140.0, None, 300.0),
        ("마케팅기획1팀", "소계", 66000, 53100.0, 66000, 51100.0, None, 2000.0),

        ("마케팅기획2팀", "국내", 20000, 14872.5, 20000, 14372.5, None, 500.0),
        ("마케팅기획2팀", "결연", 9000, 7200.0, 9000, 6800.0, None, 400.0),
        ("마케팅기획2팀", "해외", 16000, 13068.0, 16000, 12668.0, None, 400.0),
        ("마케팅기획2팀", "기타", 9000, 7665.0, 9000, 7365.0, None, 300.0),
        ("마케팅기획2팀", "소계", 54000, 42805.5, 54000, 41205.5, None, 1600.0),

        ("컬쳐콘텐츠팀", "국내", 8000, 6184.5, 8000, 5984.5, None, 200.0),
        ("컬쳐콘텐츠팀", "결연", 4000, 3120.0, 4000, 2920.0, None, 200.0),
        ("컬쳐콘텐츠팀", "해외", 6000, 4812.0, 6000, 4612.0, None, 200.0),
        ("컬쳐콘텐츠팀", "기타", 3600, 2774.1, 3600, 2674.1, None, 100.0),
        ("컬쳐콘텐츠팀", "소계", 21600, 16890.6, 21600, 16190.6, None, 700.0),

        ("회원참여팀", "국내", 12000, 8520.3, 12000, 8220.3, None, 300.0),
        ("회원참여팀", "결연", 5000, 3950.0, 5000, 3650.0, None, 300.0),
        ("회원참여팀", "해외", 9000, 7255.0, 9000, 7055.0, None, 200.0),
        ("회원참여팀", "기타", 5200, 5374.7, 5200, 5174.7, None, 200.0),
        ("회원참여팀", "소계", 31200, 25100.0, 31200, 24100.0, None, 1000.0),

        ("기업개발", "국내", 4000, 3450.0, 4000, 3250.0, None, 200.0),
        ("기업개발", "결연", 1500, 1230.0, 1500, 1130.0, None, 100.0),
        ("기업개발", "해외", 2500, 2078.0, 2500, 1978.0, None, 100.0),
        ("기업개발", "기타", 1756, 1246.3, 1756, 1146.3, None, 100.0),
        ("기업개발", "소계", 9756, 8004.3, 9756, 7504.3, None, 500.0),

        ("본부 총계", "국내", 97000, 72466.3, 97000, 70266.3, None, 2200.0),
        ("본부 총계", "결연", 42500, 35680.5, 42500, 33280.5, None, 2400.0),
        ("본부 총계", "해외", 75500, 61253.5, 75500, 59353.5, None, 1900.0),
        ("본부 총계", "기타", 39556, 31985.1, 39556, 30785.1, None, 1200.0),
        ("본부 총계", "소계", 254556, 201385.4, 254556, 193685.4, None, 7700.0),
    ]
    cols = ["team", "type", "all_target", "all_actual",
            "corp_target", "corp_actual", "welfare_target", "welfare_actual"]
    return pd.DataFrame(rows, columns=cols)


# ══════════════════════════════════════════════════════════
# 7. SNOWFLAKE DATA LOADING
# ══════════════════════════════════════════════════════════
def get_snowflake_connection():
    if DEMO_MODE:
        return None
    return st.connection("snowflake")


def _classify_org_l1(dept_nm):
    if dept_nm in ORG_MAP["hq_teams"]:
        return "나눔마케팅본부"
    if dept_nm == ORG_MAP["participation_team"]:
        return "회원참여팀"
    if dept_nm == ORG_MAP["csr_team"]:
        return "기업개발"
    return "시도본부 및 지부"


@st.cache_data(ttl=900)
def load_available_months_snowflake():
    conn = get_snowflake_connection()
    db = APP_CONFIG["snowflake"]["database"]
    schema = APP_CONFIG["snowflake"]["schema"]
    view = APP_CONFIG["snowflake"]["views"]["goal"]
    sql = f"""
        SELECT DISTINCT
            CAST(LEFT(STRD_MT, 4) AS INT) AS year,
            CAST(RIGHT(STRD_MT, 2) AS INT) AS month,
            CLOSED_MONTH_YN
        FROM {db}.{schema}.{view}
        WHERE CLOSED_MONTH_YN = 'Y'
        ORDER BY year DESC, month DESC
    """
    df = conn.query(sql)
    df.columns = [c.lower() for c in df.columns]
    df["label"] = df.apply(lambda r: f"{int(r['year'])}년 {int(r['month'])}월", axis=1)
    return df


@st.cache_data(ttl=900)
def load_monthly_data_snowflake(_year, _month):
    conn = get_snowflake_connection()
    db = APP_CONFIG["snowflake"]["database"]
    schema = APP_CONFIG["snowflake"]["schema"]
    view = APP_CONFIG["snowflake"]["views"]["goal"]
    strd_mt = f"{_year}{_month:02d}"
    prev_strd_mt = f"{_year - 1}{_month:02d}"
    sql = f"""
        SELECT
            CAST(LEFT(STRD_MT, 4) AS INT) AS report_year,
            CAST(RIGHT(STRD_MT, 2) AS INT) AS report_month_no,
            DEPT_NM AS org_l2,
            DVLP_DIV_CD,
            DVLP_DIV_NM AS perf_type,
            COALESCE(GOAL_CNT, 0) AS month_target,
            COALESCE(ACT_CNT, 0) AS month_actual
        FROM {db}.{schema}.{view}
        WHERE STRD_MT IN (%(mt)s, %(prev_mt)s)
          AND DVLP_DIV_CD IN ('1', '2', '4')
    """
    raw = conn.query(sql, params={"mt": strd_mt, "prev_mt": prev_strd_mt})
    raw.columns = [c.lower() for c in raw.columns]
    if raw.empty:
        return pd.DataFrame()

    raw["org_l1"] = raw["org_l2"].apply(_classify_org_l1)

    # Aggregate YTD from goal view: sum all closed months in the year up to sel_month
    ytd_sql = f"""
        SELECT
            CAST(LEFT(STRD_MT, 4) AS INT) AS report_year,
            DEPT_NM AS org_l2,
            DVLP_DIV_CD,
            SUM(COALESCE(GOAL_CNT, 0)) AS ytd_target,
            SUM(COALESCE(ACT_CNT, 0)) AS ytd_actual
        FROM {db}.{schema}.{view}
        WHERE LEFT(STRD_MT, 4) IN (%(yy)s, %(prev_yy)s)
          AND RIGHT(STRD_MT, 2) <= %(mm)s
          AND DVLP_DIV_CD IN ('1', '2', '4')
        GROUP BY report_year, org_l2, DVLP_DIV_CD
    """
    ytd = conn.query(ytd_sql, params={
        "yy": str(_year), "prev_yy": str(_year - 1), "mm": f"{_month:02d}"
    })
    ytd.columns = [c.lower() for c in ytd.columns]

    # Annual target: sum goal across all 12 months
    annual_sql = f"""
        SELECT
            CAST(LEFT(STRD_MT, 4) AS INT) AS report_year,
            DEPT_NM AS org_l2,
            DVLP_DIV_CD,
            SUM(COALESCE(GOAL_CNT, 0)) AS annual_target
        FROM {db}.{schema}.{view}
        WHERE LEFT(STRD_MT, 4) IN (%(yy)s, %(prev_yy)s)
          AND DVLP_DIV_CD IN ('1', '2', '4')
        GROUP BY report_year, org_l2, DVLP_DIV_CD
    """
    annual = conn.query(annual_sql, params={"yy": str(_year), "prev_yy": str(_year - 1)})
    annual.columns = [c.lower() for c in annual.columns]

    # Merge
    df = raw.merge(ytd, on=["report_year", "org_l2", "dvlp_div_cd"], how="left")
    df = df.merge(annual, on=["report_year", "org_l2", "dvlp_div_cd"], how="left")
    df[["ytd_target", "ytd_actual", "annual_target"]] = df[["ytd_target", "ytd_actual", "annual_target"]].fillna(0)

    # Build detail rows
    detail = df.groupby(
        ["report_year", "report_month_no", "org_l1", "org_l2", "perf_type"],
        as_index=False,
    ).agg(
        month_target=("month_target", "sum"),
        month_actual=("month_actual", "sum"),
        ytd_target=("ytd_target", "sum"),
        ytd_actual=("ytd_actual", "sum"),
        annual_target=("annual_target", "sum"),
    )
    detail["row_type"] = "detail"
    detail["sort_order"] = detail["perf_type"].map({"신규": 1, "재후원": 2, "증액": 3}).fillna(9).astype(int)

    # Team subtotals
    team_sub = detail.groupby(
        ["report_year", "report_month_no", "org_l1", "org_l2"],
        as_index=False,
    ).agg(
        month_target=("month_target", "sum"),
        month_actual=("month_actual", "sum"),
        ytd_target=("ytd_target", "sum"),
        ytd_actual=("ytd_actual", "sum"),
        annual_target=("annual_target", "sum"),
    )
    team_sub["perf_type"] = "소계"
    team_sub["row_type"] = "subtotal"
    team_sub["sort_order"] = 100

    # Org L1 subtotals
    org_sub = team_sub.groupby(
        ["report_year", "report_month_no", "org_l1"],
        as_index=False,
    ).agg(
        month_target=("month_target", "sum"),
        month_actual=("month_actual", "sum"),
        ytd_target=("ytd_target", "sum"),
        ytd_actual=("ytd_actual", "sum"),
        annual_target=("annual_target", "sum"),
    )
    org_sub["org_l2"] = org_sub["org_l1"]
    org_sub["perf_type"] = "소계"
    org_sub["row_type"] = "hq_subtotal"
    org_sub["sort_order"] = 200

    # Grand total
    grand = team_sub.groupby(
        ["report_year", "report_month_no"],
        as_index=False,
    ).agg(
        month_target=("month_target", "sum"),
        month_actual=("month_actual", "sum"),
        ytd_target=("ytd_target", "sum"),
        ytd_actual=("ytd_actual", "sum"),
        annual_target=("annual_target", "sum"),
    )
    grand["org_l1"] = "총계"
    grand["org_l2"] = "총계"
    grand["perf_type"] = "소계"
    grand["row_type"] = "grand_total"
    grand["sort_order"] = 999

    result = pd.concat([detail, team_sub, org_sub, grand], ignore_index=True)
    # Sort: org_l1 order, then org_l2, then sort_order
    org_l1_order = {"나눔마케팅본부": 1, "회원참여팀": 2, "기업개발": 3, "시도본부 및 지부": 4, "총계": 9}
    result["_org_sort"] = result["org_l1"].map(org_l1_order).fillna(5)
    result = result.sort_values(["report_year", "_org_sort", "org_l2", "sort_order"]).drop(columns=["_org_sort"])
    return result


@st.cache_data(ttl=900)
def load_trend_data_snowflake(_year, _month):
    conn = get_snowflake_connection()
    db = APP_CONFIG["snowflake"]["database"]
    schema = APP_CONFIG["snowflake"]["schema"]
    view = APP_CONFIG["snowflake"]["views"]["goal"]
    rows = []
    for yr in range(_year - 3, _year + 1):
        sql = f"""
            SELECT
                CAST(RIGHT(STRD_MT, 2) AS INT) AS month,
                SUM(COALESCE(ACT_CNT, 0)) AS actual
            FROM {db}.{schema}.{view}
            WHERE LEFT(STRD_MT, 4) = %(yy)s
              AND DVLP_DIV_CD IN ('1', '2', '4')
              AND CLOSED_MONTH_YN = 'Y'
            GROUP BY month
            ORDER BY month
        """
        mdf = conn.query(sql, params={"yy": str(yr)})
        mdf.columns = [c.lower() for c in mdf.columns]
        row = {"year": yr}
        for m in range(1, 13):
            match = mdf[mdf["month"] == m]
            if not match.empty:
                row[m] = float(match.iloc[0]["actual"])
            else:
                row[m] = None
        rows.append(row)
    return pd.DataFrame(rows)


@st.cache_data(ttl=900)
def load_sponsorship_data_snowflake(_year, _month):
    conn = get_snowflake_connection()
    db = APP_CONFIG["snowflake"]["database"]
    src = APP_CONFIG["snowflake"]["source_schema"]
    view = APP_CONFIG["snowflake"]["views"]["ye_trend_bsns"]
    strd_mt = f"{_year}{_month:02d}"
    sql = f"""
        SELECT
            DVLP_DIV_NM AS dev_type,
            SPNSR_BSNS2_NM AS type,
            COALESCE(CLOSED_ACT_CNT, 0) + COALESCE(CUR_MONTH_ACT_CNT, 0) AS ytd_actual
        FROM {db}.SERVING.{view}
        WHERE AS_OF_MT = %(mt)s
          AND STRD_YY = %(yy)s
          AND DVLP_DIV_CD IN ('1', '2', '4')
    """
    raw = conn.query(sql, params={"mt": strd_mt, "yy": str(_year)})
    raw.columns = [c.lower() for c in raw.columns]
    if raw.empty:
        return pd.DataFrame()

    # Pivot: sponsorship type rows, dev_type as breakdown
    pivot = raw.groupby("type", as_index=False).agg(all_actual=("ytd_actual", "sum"))
    pivot = pivot.sort_values("all_actual", ascending=False).head(10)

    # Format for the sponsorship table: team=dev_type is not applicable here.
    # We'll build a simple sponsorship-by-business table.
    spon = raw.groupby("type", as_index=False).agg(all_actual=("ytd_actual", "sum"))
    spon = spon.sort_values("all_actual", ascending=False)
    total_actual = spon["all_actual"].sum()
    total_row = pd.DataFrame([{"type": "총계", "all_actual": total_actual}])
    spon = pd.concat([spon, total_row], ignore_index=True)
    spon["team"] = spon["type"]
    spon["all_target"] = None
    spon["corp_target"] = None
    spon["corp_actual"] = None
    spon["welfare_target"] = None
    spon["welfare_actual"] = None
    return spon


# ══════════════════════════════════════════════════════════
# 8. DATA LOADING DISPATCHER
# ══════════════════════════════════════════════════════════
def load_available_months():
    if DEMO_MODE:
        return get_demo_available_months()
    return load_available_months_snowflake()


def load_monthly_data(year, month):
    if DEMO_MODE:
        return create_demo_monthly_data(year, month)
    return load_monthly_data_snowflake(year, month)


def load_trend_data(year, month):
    if DEMO_MODE:
        return create_demo_trend_data(year, month)
    return load_trend_data_snowflake(year, month)


def load_sponsorship_data(year, month):
    if DEMO_MODE:
        return create_demo_sponsorship_data(year, month)
    return load_sponsorship_data_snowflake(year, month)


# ══════════════════════════════════════════════════════════
# 9. KPI CALCULATION
# ══════════════════════════════════════════════════════════
def compute_kpi(df, sel_year, sel_month):
    cur = df[(df["report_year"] == sel_year) & (df["row_type"] == "grand_total")]
    prev = df[(df["report_year"] == sel_year - 1) & (df["row_type"] == "grand_total")]

    m_actual = cur["month_actual"].sum() if not cur.empty else 0
    m_target = cur["month_target"].sum() if not cur.empty else 0
    ytd_actual = cur["ytd_actual"].sum() if "ytd_actual" in cur.columns and not cur.empty else m_actual * 9.45
    a_target = cur["annual_target"].sum() if not cur.empty else 0

    prev_m = prev["month_actual"].sum() if not prev.empty else 0
    prev_ytd = prev["ytd_actual"].sum() if "ytd_actual" in prev.columns and not prev.empty else prev_m * 9.45

    m_ach = safe_divide(m_actual, m_target)
    a_ach = safe_divide(ytd_actual, a_target)
    m_yoy = calculate_growth_rate(m_actual, prev_m)
    ytd_yoy = calculate_growth_rate(ytd_actual, prev_ytd)
    m_ach_delta = (m_ach - 1.0) if m_ach is not None else None

    return {
        "month_actual": m_actual,
        "month_target": m_target,
        "month_ach": m_ach,
        "ytd_actual": ytd_actual,
        "annual_target": a_target,
        "annual_ach": a_ach,
        "month_yoy": m_yoy,
        "ytd_yoy": ytd_yoy,
        "month_ach_delta": m_ach_delta,
        "remaining": a_target - ytd_actual if a_target and ytd_actual else None,
    }


# ══════════════════════════════════════════════════════════
# 10. RENDERING HELPERS
# ══════════════════════════════════════════════════════════
def render_section_anchor(anchor_id):
    st.markdown(f'<div id="{anchor_id}"></div>', unsafe_allow_html=True)


def render_section_header(number, title, subtitle=""):
    st.markdown(f'<div class="section-header">{number} {title}</div>', unsafe_allow_html=True)
    if subtitle:
        st.markdown(f'<div class="section-sub">{subtitle}</div>', unsafe_allow_html=True)


def render_kpi_card(label, value_str, sub_html=""):
    html = f"""
    <div class="kpi-card">
        <div class="kpi-label">{label}</div>
        <div class="kpi-value">{value_str}</div>
        <div class="kpi-sub">{sub_html}</div>
    </div>
    """
    st.markdown(html, unsafe_allow_html=True)


# ══════════════════════════════════════════════════════════
# 11. TABLE BUILDERS
# ══════════════════════════════════════════════════════════
def build_monthly_close_html(df, sel_year, sel_month):
    cur = df[df["report_year"] == sel_year].copy()
    if cur.empty:
        return "<p>데이터 없음</p>"

    cur = cur.sort_values("sort_order")

    html = """<table class="report-table">
    <thead>
        <tr>
            <th rowspan="2" style="min-width:200px">구분</th>
            <th colspan="3">당월</th>
            <th colspan="3">누계</th>
            <th colspan="2">연간</th>
        </tr>
        <tr>
            <th class="sub-header">목표</th><th class="sub-header">실적</th><th class="sub-header">달성률</th>
            <th class="sub-header">목표</th><th class="sub-header">실적</th><th class="sub-header">달성률</th>
            <th class="sub-header">연목표</th><th class="sub-header">달성률</th>
        </tr>
    </thead><tbody>"""

    for _, r in cur.iterrows():
        rt = r["row_type"]
        o2 = r["org_l2"]
        pt = r.get("perf_type", "")

        # Row class
        if rt == "grand_total":
            rc = "grand-total"
        elif rt == "hq_subtotal":
            rc = "hq-subtotal"
        elif rt == "subtotal":
            rc = "subtotal"
        else:
            rc = ""

        # Label and indent
        if rt in ("grand_total", "hq_subtotal"):
            label = f'<td class="bold">{o2}</td>'
        elif rt == "subtotal":
            label = f'<td class="indent-1 bold">{o2} 소계</td>'
        elif pt:
            label = f'<td class="indent-2">{pt}</td>'
        else:
            label = f'<td class="indent-1">{o2}</td>'

        mt = r["month_target"]
        ma = r["month_actual"]
        m_ach = safe_divide(ma, mt)
        yt = r.get("ytd_target", mt * sel_month if mt else 0)
        ya = r.get("ytd_actual", ma * 9.45 if ma else 0)
        y_ach = safe_divide(ya, yt)
        at = r["annual_target"]
        a_ach = safe_divide(ya, at)

        ach_m = f'<span class="{ach_class(m_ach)}">{fmt_pct(m_ach)}</span>' if m_ach is not None else "-"
        ach_y = f'<span class="{ach_class(y_ach)}">{fmt_pct(y_ach)}</span>' if y_ach is not None else "-"
        ach_a = f'<span class="{ach_class(a_ach)}">{fmt_pct(a_ach)}</span>' if a_ach is not None else "-"

        html += f'<tr class="{rc}">{label}'
        html += f'<td class="num">{fmt_int(mt)}</td>'
        html += f'<td class="num">{fmt_dec(ma)}</td>'
        html += f'<td class="num">{ach_m}</td>'
        html += f'<td class="num">{fmt_int(yt)}</td>'
        html += f'<td class="num">{fmt_dec(ya)}</td>'
        html += f'<td class="num">{ach_y}</td>'
        html += f'<td class="num">{fmt_int(at)}</td>'
        html += f'<td class="num">{ach_a}</td>'
        html += '</tr>'

    html += "</tbody></table>"
    return html


def build_yoy_html(df, sel_year, sel_month):
    cur = df[df["report_year"] == sel_year].copy().sort_values("sort_order")
    prev = df[df["report_year"] == sel_year - 1].copy()

    if cur.empty:
        return "<p>데이터 없음</p>"

    prev_map = {}
    for _, r in prev.iterrows():
        key = (r["org_l2"], r.get("perf_type", ""))
        prev_map[key] = r

    html = f"""<table class="report-table">
    <thead>
        <tr>
            <th rowspan="2" style="min-width:200px">구분</th>
            <th colspan="3">당월 실적</th>
            <th colspan="3">누계 실적</th>
        </tr>
        <tr>
            <th class="sub-header">{sel_year-1}년</th>
            <th class="sub-header">{sel_year}년</th>
            <th class="sub-header">증감률</th>
            <th class="sub-header">{sel_year-1}년</th>
            <th class="sub-header">{sel_year}년</th>
            <th class="sub-header">증감률</th>
        </tr>
    </thead><tbody>"""

    for _, r in cur.iterrows():
        rt = r["row_type"]
        o2 = r["org_l2"]
        pt = r.get("perf_type", "")
        key = (o2, pt)
        pr = prev_map.get(key)

        if rt == "grand_total":
            rc = "grand-total"
        elif rt == "hq_subtotal":
            rc = "hq-subtotal"
        elif rt == "subtotal":
            rc = "subtotal"
        else:
            rc = ""

        if rt in ("grand_total", "hq_subtotal"):
            label = f'<td class="bold">{o2}</td>'
        elif rt == "subtotal":
            label = f'<td class="indent-1 bold">{o2} 소계</td>'
        elif pt:
            label = f'<td class="indent-2">{pt}</td>'
        else:
            label = f'<td class="indent-1">{o2}</td>'

        c_m = r["month_actual"]
        c_y = r.get("ytd_actual", c_m * 9.45 if c_m else 0)
        p_m = pr["month_actual"] if pr is not None else None
        p_y = pr.get("ytd_actual", p_m * 9.45 if p_m else 0) if pr is not None else None

        m_rate = calculate_growth_rate(c_m, p_m)
        y_rate = calculate_growth_rate(c_y, p_y)

        m_delta = delta_text(m_rate)
        y_delta = delta_text(y_rate)
        m_cls = "delta-up" if m_rate and m_rate > 0 else "delta-down" if m_rate and m_rate < 0 else ""
        y_cls = "delta-up" if y_rate and y_rate > 0 else "delta-down" if y_rate and y_rate < 0 else ""

        html += f'<tr class="{rc}">{label}'
        html += f'<td class="num">{fmt_dec(p_m) if p_m is not None else "-"}</td>'
        html += f'<td class="num">{fmt_dec(c_m)}</td>'
        html += f'<td class="num {m_cls}">{m_delta}</td>'
        html += f'<td class="num">{fmt_dec(p_y) if p_y is not None else "-"}</td>'
        html += f'<td class="num">{fmt_dec(c_y)}</td>'
        html += f'<td class="num {y_cls}">{y_delta}</td>'
        html += '</tr>'

    html += "</tbody></table>"
    return html


def build_sponsorship_table_html(sdf, sel_year, sel_month):
    if sdf.empty:
        return "<p>데이터 없음</p>"
    period_label = f"{sel_year}.01.01 ~ {sel_year}.{sel_month:02d}.{[31,28,31,30,31,30,31,31,30,31,30,31][sel_month-1]:02d}"

    has_corp = "corp_actual" in sdf.columns and sdf["corp_actual"].notna().any()

    if has_corp:
        html = f"""<table class="report-table">
        <thead>
            <tr>
                <th rowspan="2" style="min-width:160px">구분</th>
                <th colspan="3">사단+사복 누계실적<br><span style="font-weight:400;font-size:0.75rem">{period_label}</span></th>
                <th colspan="3">사단법인 누계실적</th>
                <th colspan="3">사회복지법인 누계실적</th>
            </tr>
            <tr>
                <th class="sub-header">연목표</th><th class="sub-header">누계실적</th><th class="sub-header">달성률</th>
                <th class="sub-header">연목표</th><th class="sub-header">누계실적</th><th class="sub-header">달성률</th>
                <th class="sub-header">연목표</th><th class="sub-header">누계실적</th><th class="sub-header">달성률</th>
            </tr>
        </thead><tbody>"""
    else:
        html = f"""<table class="report-table">
        <thead>
            <tr>
                <th style="min-width:200px">후원사업</th>
                <th>누계실적 (건)</th>
                <th>비중</th>
            </tr>
        </thead><tbody>"""

    total_all = sdf[sdf["team"] != "총계"]["all_actual"].sum() if not sdf.empty else 0

    for _, r in sdf.iterrows():
        team = r["team"]
        is_total = "총계" in str(team)

        if has_corp:
            at = r.get("all_target")
            aa = r.get("all_actual")
            ct = r.get("corp_target")
            ca = r.get("corp_actual")
            wt = r.get("welfare_target")
            wa = r.get("welfare_actual")
            a_ach = safe_divide(aa, at)
            c_ach = safe_divide(ca, ct)
            w_ach = safe_divide(wa, wt)

            rc = "grand-total" if is_total else ""
            label = f'<td class="bold">{team}</td>' if is_total else f'<td>{team}</td>'

            def _cell(target, actual, ach):
                t_str = fmt_int(target) if target else "-"
                a_str = fmt_dec(actual) if actual else "-"
                ac_str = f'<span class="{ach_class(ach)}">{fmt_pct(ach)}</span>' if ach is not None else "-"
                return f'<td class="num">{t_str}</td><td class="num">{a_str}</td><td class="num">{ac_str}</td>'

            html += f'<tr class="{rc}">{label}'
            html += _cell(at, aa, a_ach)
            html += _cell(ct, ca, c_ach)
            html += _cell(wt, wa, w_ach)
            html += '</tr>'
        else:
            aa = r.get("all_actual", 0)
            share = safe_divide(aa, total_all) if not is_total else None
            rc = "grand-total" if is_total else ""
            label = f'<td class="bold">{team}</td>' if is_total else f'<td>{team}</td>'
            share_str = fmt_pct(share) if share is not None else ""
            html += f'<tr class="{rc}">{label}<td class="num">{fmt_dec(aa)}</td><td class="num">{share_str}</td></tr>'

    html += "</tbody></table>"
    return html


# ══════════════════════════════════════════════════════════
# 12. ORG SUMMARY TABLE + CHART
# ══════════════════════════════════════════════════════════
def get_org_summary(df, sel_year):
    cur = df[df["report_year"] == sel_year].copy()
    # Get key org rows: hq_subtotal, grand_total, and subtotals for non-HQ orgs
    orgs = cur[
        (cur["row_type"].isin(["hq_subtotal", "grand_total"])) |
        ((cur["org_l1"].isin(["회원참여팀", "기업개발", "시도본부 및 지부"])) &
         (cur["row_type"] == "subtotal"))
    ].copy()

    # For 시도본부 및 지부, collapse to a single subtotal
    non_branch = orgs[orgs["org_l1"] != "시도본부 및 지부"]
    branch = orgs[orgs["org_l1"] == "시도본부 및 지부"]
    if not branch.empty:
        branch_sum = branch.groupby(
            ["report_year", "report_month_no", "org_l1"], as_index=False
        ).agg(
            month_target=("month_target", "sum"),
            month_actual=("month_actual", "sum"),
            ytd_target=("ytd_target", "sum") if "ytd_target" in branch.columns else ("month_target", "sum"),
            ytd_actual=("ytd_actual", "sum") if "ytd_actual" in branch.columns else ("month_actual", "sum"),
            annual_target=("annual_target", "sum"),
        )
        branch_sum["org_l2"] = "시도본부 및 지부"
        branch_sum["perf_type"] = "소계"
        branch_sum["row_type"] = "hq_subtotal"
        branch_sum["sort_order"] = 200
        orgs = pd.concat([non_branch, branch_sum], ignore_index=True)
    else:
        orgs = non_branch

    # Deduplicate: prefer hq_subtotal over subtotal for same org
    keep = []
    seen = set()
    for _, r in orgs.sort_values("sort_order").iterrows():
        key = r["org_l2"]
        if key not in seen:
            seen.add(key)
            keep.append(r)
    return pd.DataFrame(keep)


# ══════════════════════════════════════════════════════════
# 13. MAIN APP — Column-based layout (no st.sidebar)
# ══════════════════════════════════════════════════════════

# --- Session state ---
if "nav_active" not in st.session_state:
    st.session_state["nav_active"] = "summary"

# --- Data load (before layout so we have sel_year/sel_month) ---
avail = load_available_months()
month_options = avail["label"].tolist()

# Use a hidden selectbox value from session_state
if "sel_month_label" not in st.session_state:
    st.session_state["sel_month_label"] = month_options[0]

nav_items = [
    ("summary", "① SUMMARY"),
    ("monthly-close", "② 월 마감 현황"),
    ("yoy-comparison", "③ 전년도 실적 비교"),
    ("multi-year-trend", "④ 최근 4개년 추이"),
    ("sponsorship-ytd", "⑤ 후원사업별 누계"),
]

# Chart display label map for org names
ORG_LABEL_MAP = {
    "나눔마케팅본부": "나눔마케팅본부",
    "회원참여팀": "회원참여팀",
    "기타 기업개발(사회공헌협력팀)": "기업개발",
    "기업개발": "기업개발",
    "대면모금": "대면모금",
    "시도본부 및 지부, 기타": "시도본부·지부",
    "시도본부 및 지부": "시도본부·지부",
}

# ── Two-column layout: Left Nav | Right Content ──
nav_col, content_col = st.columns([1, 5], gap="medium")

# ── LEFT: Navigation Panel ──
with nav_col:
    # Build nav items HTML
    nav_links = ""
    for anchor, label in nav_items:
        active_cls = "active" if st.session_state["nav_active"] == anchor else ""
        nav_links += f'<a href="#{anchor}" class="nav-item {active_cls}">{label}</a>\n'

    demo_badge = ""
    if DEMO_MODE:
        demo_badge = '<div class="nav-demo-badge">⚠ DEMO MODE<br>샘플 데이터 사용 중</div>'

    st.markdown(f"""
    <div class="nav-panel">
        <div class="nav-title">회원개발</div>
        <div class="nav-brand">REPORT</div>
        <div class="nav-app-name">회원개발 통합 리포트</div>
        <hr class="nav-divider">
        <div class="nav-filter-label">조회 기준</div>
    </div>
    """, unsafe_allow_html=True)

    # Streamlit selectbox for month filter (native widget — always renders)
    sel_label = st.selectbox(
        "조회 기준",
        month_options,
        index=month_options.index(st.session_state["sel_month_label"]) if st.session_state["sel_month_label"] in month_options else 0,
        key="month_filter",
        label_visibility="collapsed",
    )
    st.session_state["sel_month_label"] = sel_label

    sel_row = avail[avail["label"] == sel_label].iloc[0]
    sel_year = int(sel_row["year"])
    sel_month = int(sel_row["month"])

    # Navigation buttons (native Streamlit)
    for anchor, label in nav_items:
        if st.button(label, key=f"nav_{anchor}", use_container_width=True):
            st.session_state["nav_active"] = anchor

    if DEMO_MODE:
        st.caption("⚠ DEMO MODE — 샘플 데이터")
    else:
        st.caption("📊 LIVE — GN_DW.SERVING 기반")


# ── Load data ──
monthly_df = load_monthly_data(sel_year, sel_month)
trend_df = load_trend_data(sel_year, sel_month)
sponsor_df = load_sponsorship_data(sel_year, sel_month)
kpi = compute_kpi(monthly_df, sel_year, sel_month)

# ── RIGHT: Report Content ──
with content_col:


    # ══════════════════════════════════════════════════════════
    # SECTION 01: SUMMARY
    # ══════════════════════════════════════════════════════════
    render_section_anchor("summary")

    st.markdown(f"""
    <div style="margin-bottom:0.3rem;">
        <span style="font-size:1.6rem;font-weight:700;color:{GN_DARK_BROWN};">회원개발 통합 리포트</span>
    </div>
    <div style="font-size:0.9rem;color:{MONO_WARM_3};margin-bottom:1.5rem;">
        {sel_year}년 {sel_month}월 마감 기준
    </div>
    """, unsafe_allow_html=True)

    render_section_header("①", "SUMMARY")

    # KPI Cards
    k1, k2, k3, k4 = st.columns(4)
    with k1:
        render_kpi_card(
            f"{sel_month}월 전체 실적",
            f"{format_number(kpi['month_actual'])}건",
            delta_html(kpi["month_yoy"], "전년 동월 대비"),
        )
    with k2:
        render_kpi_card(
            f"{sel_month}월 목표 달성률",
            format_percent(kpi["month_ach"]),
            f'<span class="kpi-sub">목표 대비 {format_percent_pp(kpi["month_ach_delta"])}</span>',
        )
    with k3:
        render_kpi_card(
            "누계 전체 실적",
            f"{format_number(kpi['ytd_actual'])}건",
            delta_html(kpi["ytd_yoy"], "전년 누계 대비"),
        )
    with k4:
        render_kpi_card(
            "연간 목표 달성률",
            format_percent(kpi["annual_ach"]),
            f'<span class="kpi-sub">연 목표 {format_number(kpi["annual_target"], 0)}건</span>',
        )

    st.markdown("<div style='height:1.5rem'></div>", unsafe_allow_html=True)

    # Org summary table + chart
    org_sum = get_org_summary(monthly_df, sel_year)

    if not org_sum.empty:
        col_t, col_c = st.columns([1.05, 0.95], gap="medium")

        with col_t:
            st.markdown(f'<div style="font-size:0.95rem;font-weight:700;color:{GN_DARK_BROWN};margin-bottom:0.5rem;">조직별 성과 요약</div>', unsafe_allow_html=True)

            org_html = """<table class="report-table"><thead><tr>
                <th>조직</th><th>월 목표</th><th>월 실적</th><th>월 달성률</th>
                <th>누계 실적</th><th>연 목표</th><th>연 달성률</th>
            </tr></thead><tbody>"""
            for _, r in org_sum.iterrows():
                o = r["org_l2"]
                mt = r["month_target"]
                ma = r["month_actual"]
                m_ach = safe_divide(ma, mt)
                ya = r.get("ytd_actual", ma * 9.45 if ma else 0)
                at = r["annual_target"]
                a_ach = safe_divide(ya, at)
                rt = r["row_type"]

                rc = "grand-total" if rt == "grand_total" else "hq-subtotal" if rt == "hq_subtotal" else ""
                org_html += f'<tr class="{rc}">'
                org_html += f'<td class="bold">{o}</td>'
                org_html += f'<td class="num">{fmt_int(mt)}</td>'
                org_html += f'<td class="num">{fmt_dec(ma)}</td>'
                ma_str = f'<span class="{ach_class(m_ach)}">{fmt_pct(m_ach)}</span>' if m_ach else "-"
                org_html += f'<td class="num">{ma_str}</td>'
                org_html += f'<td class="num">{fmt_dec(ya)}</td>'
                org_html += f'<td class="num">{fmt_int(at)}</td>'
                aa_str = f'<span class="{ach_class(a_ach)}">{fmt_pct(a_ach)}</span>' if a_ach else "-"
                org_html += f'<td class="num">{aa_str}</td>'
                org_html += '</tr>'
            org_html += "</tbody></table>"
            st.markdown(org_html, unsafe_allow_html=True)

        with col_c:
            st.markdown(f'<div style="font-size:0.95rem;font-weight:700;color:{GN_DARK_BROWN};margin-bottom:0.5rem;">조직별 월 목표 대비 실적</div>', unsafe_allow_html=True)

            # Filter: exclude 본부 소계, 총계 — keep actual orgs only
            chart_data = org_sum[
                ~org_sum["org_l2"].isin(["본부 소계", "총계", "전체 합계"])
            ].copy()
            chart_data = chart_data[~chart_data["row_type"].isin(["grand_total"])].copy()
            if not chart_data.empty:
                chart_data = chart_data[["org_l2", "month_target", "month_actual"]].copy()
                chart_data.columns = ["조직", "목표", "실적"]
                chart_data["조직"] = chart_data["조직"].map(lambda x: ORG_LABEL_MAP.get(x, x))
                chart_melted = chart_data.melt(
                    id_vars="조직", value_vars=["목표", "실적"],
                    var_name="구분", value_name="건수",
                )
                chart_melted["표시값"] = chart_melted.apply(
                    lambda row: (
                        "" if pd.isna(row["건수"]) or row["건수"] == 0
                        else f"{row['건수']:,.0f}" if row["구분"] == "목표"
                        else f"{row['건수']:,.1f}"
                    ), axis=1,
                )

                bars = (
                    alt.Chart(chart_melted)
                    .mark_bar(cornerRadiusTopLeft=3, cornerRadiusTopRight=3)
                    .encode(
                        x=alt.X("조직:N", title=None, sort=None,
                                 axis=alt.Axis(labelAngle=0, labelLimit=100,
                                               labelFontSize=9, labelColor=GN_DARK_BROWN,
                                               labelPadding=4, ticks=False, domain=False)),
                        xOffset=alt.XOffset("구분:N"),
                        y=alt.Y("건수:Q", title=None,
                                 axis=alt.Axis(labels=False, ticks=False, domain=False,
                                               title=None, grid=True, gridColor="#EEEEEE"),
                                 scale=alt.Scale(padding=20)),
                        color=alt.Color("구분:N",
                                        scale=alt.Scale(domain=["목표", "실적"],
                                                        range=[MONO_WARM_2, GN_GREEN]),
                                        legend=alt.Legend(title=None, orient="top-right",
                                                         direction="horizontal",
                                                         labelFontSize=10, symbolSize=80)),
                        tooltip=[
                            alt.Tooltip("조직:N", title="조직"),
                            alt.Tooltip("구분:N", title="구분"),
                            alt.Tooltip("건수:Q", title="건수", format=",.1f"),
                        ],
                    )
                )

                label_df = chart_melted[chart_melted["건수"].notna() & (chart_melted["건수"] != 0)]
                labels = (
                    alt.Chart(label_df)
                    .mark_text(dy=-6, fontSize=8.5, fontWeight=600, color=GN_DARK_BROWN)
                    .encode(
                        x=alt.X("조직:N", sort=None),
                        xOffset=alt.XOffset("구분:N"),
                        y=alt.Y("건수:Q"),
                        text=alt.Text("표시값:N"),
                    )
                )

                chart = (bars + labels).properties(height=260)
                st.altair_chart(chart, use_container_width=True)

    # Key Insights
    st.markdown("<div style='height:0.8rem'></div>", unsafe_allow_html=True)
    st.markdown(f'<div style="font-size:0.95rem;font-weight:700;color:{GN_DARK_BROWN};margin-bottom:0.5rem;">핵심 포인트</div>', unsafe_allow_html=True)

    org_detail = org_sum[~org_sum["row_type"].isin(["grand_total"])].copy() if not org_sum.empty else pd.DataFrame()
    if not org_detail.empty:
        org_detail["m_ach"] = org_detail.apply(lambda r: safe_divide(r["month_actual"], r["month_target"]), axis=1)
        org_detail["ytd_est"] = org_detail["month_actual"] * 9.45
        org_detail["a_ach"] = org_detail.apply(lambda r: safe_divide(r["ytd_est"], r["annual_target"]), axis=1)
        best_m = org_detail.loc[org_detail["m_ach"].idxmax()] if org_detail["m_ach"].notna().any() else None
        best_a = org_detail.loc[org_detail["a_ach"].idxmax()] if org_detail["a_ach"].notna().any() else None
    else:
        best_m = best_a = None

    i1, i2, i3 = st.columns(3)
    with i1:
        yoy_str = delta_text(kpi["month_yoy"]) if kpi["month_yoy"] is not None else "-"
        st.markdown(f"""<div class="insight-box">
            <strong>01 당월 흐름</strong><br>
            {sel_month}월 전체 실적 <strong>{format_number(kpi['month_actual'])}건</strong><br>
            전년 동월 대비 {yoy_str}
        </div>""", unsafe_allow_html=True)
    with i2:
        bm_name = best_m["org_l2"] if best_m is not None else "-"
        ba_name = best_a["org_l2"] if best_a is not None else "-"
        st.markdown(f"""<div class="insight-box">
            <strong>02 조직 성과</strong><br>
            월 달성률 최고: <strong>{bm_name}</strong><br>
            연 달성률 최고: <strong>{ba_name}</strong>
        </div>""", unsafe_allow_html=True)
    with i3:
        remaining = kpi["remaining"]
        rem_str = format_number(remaining, 0) if remaining else "-"
        st.markdown(f"""<div class="insight-box">
            <strong>03 목표 진척</strong><br>
            연간 달성률 <strong>{format_percent(kpi['annual_ach'])}</strong><br>
            목표까지 <strong>{rem_str}건</strong> 남음
        </div>""", unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════
    # SECTION 02: 월 마감 현황
    # ══════════════════════════════════════════════════════════
    render_section_anchor("monthly-close")
    render_section_header("②", "월 마감 현황", f"{sel_year}년 {sel_month}월 회원개발 현황 — 마감")
    st.markdown(build_monthly_close_html(monthly_df, sel_year, sel_month), unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════
    # SECTION 03: 전년도 실적 비교
    # ══════════════════════════════════════════════════════════
    render_section_anchor("yoy-comparison")
    render_section_header("③", "전년도 실적 비교", f"{sel_year-1}년 vs {sel_year}년 비교")

    yc1, yc2 = st.columns(2)
    with yc1:
        m_yoy_str = delta_text(kpi["month_yoy"])
        st.markdown(f"""<div class="insight-box">
            전체 실적 전년 동월 대비: <strong>{m_yoy_str}</strong>
        </div>""", unsafe_allow_html=True)
    with yc2:
        y_yoy_str = delta_text(kpi["ytd_yoy"])
        st.markdown(f"""<div class="insight-box">
            전체 실적 전년 동기 누계 대비: <strong>{y_yoy_str}</strong>
        </div>""", unsafe_allow_html=True)

    st.markdown(build_yoy_html(monthly_df, sel_year, sel_month), unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════
    # SECTION 04: 4개년 추이
    # ══════════════════════════════════════════════════════════
    render_section_anchor("multi-year-trend")
    render_section_header("④", "최근 4개년 추이", f"월별 본부실적 추이 {sel_year-3}~{sel_year}년")

    if trend_df.empty:
        st.info("4개년 추이 데이터가 없습니다.")
    else:
        chart_rows = []
        for _, r in trend_df.iterrows():
            yr = int(r["year"])
            for m in range(1, 13):
                val = r[m]
                if val is not None and not (isinstance(val, float) and pd.isna(val)):
                    chart_rows.append({"월": m, "연도": str(yr), "실적": float(val)})
        chart_df = pd.DataFrame(chart_rows)

        if not chart_df.empty:
            year_list = sorted(chart_df["연도"].unique())
            color_range = [YEAR_COLORS.get(int(y), MONO_WARM_2) for y in year_list]
            cur_str = str(sel_year)

            base = alt.Chart(chart_df).encode(
                x=alt.X("월:O", title="월",
                         axis=alt.Axis(labelExpr="datum.value + '월'"),
                         scale=alt.Scale(domain=list(range(1, 13)))),
                y=alt.Y("실적:Q", title="회원개발 실적 (건)", axis=alt.Axis(format=",")),
                color=alt.Color("연도:N",
                                scale=alt.Scale(domain=year_list, range=color_range),
                                legend=alt.Legend(title="연도", orient="top")),
                tooltip=[alt.Tooltip("연도:N"), alt.Tooltip("월:O"),
                         alt.Tooltip("실적:Q", format=",")],
            )

            line = base.mark_line().encode(
                strokeWidth=alt.condition(
                    alt.datum["연도"] == cur_str, alt.value(3), alt.value(1.5)
                ),
            )
            points = base.mark_circle(size=40).encode(
                opacity=alt.condition(
                    alt.datum["연도"] == cur_str, alt.value(1), alt.value(0.6)
                ),
            )

            chart = (line + points).properties(height=380).configure_view(
                strokeWidth=0
            ).configure_axis(
                gridColor="#EEE", gridDash=[3, 3],
            )
            st.altair_chart(chart, use_container_width=True)

        # 3-year average
        if APP_CONFIG["features"]["show_three_year_average"]:
            avg_years = [y for y in range(sel_year - 3, sel_year)]
            avg_df = trend_df[trend_df["year"].isin(avg_years)]
            if not avg_df.empty:
                avg_row = {"year": "3개년 평균"}
                for m in range(1, 13):
                    vals = [r[m] for _, r in avg_df.iterrows()
                            if r[m] is not None and not (isinstance(r[m], float) and pd.isnan(r[m]))]
                    avg_row[m] = round(sum(vals) / len(vals)) if vals else None
                trend_display = pd.concat([trend_df, pd.DataFrame([avg_row])], ignore_index=True)
            else:
                trend_display = trend_df
        else:
            trend_display = trend_df

        st.markdown(f'<div style="font-size:0.88rem;font-weight:600;color:{GN_DARK_BROWN};margin:1rem 0 0.4rem;">월별 데이터</div>', unsafe_allow_html=True)

        t_html = '<table class="report-table"><thead><tr><th class="left">구분</th>'
        for m in range(1, 13):
            t_html += f"<th>{m}월</th>"
        t_html += "<th>합계</th></tr></thead><tbody>"

        for _, r in trend_display.iterrows():
            yr = r["year"]
            yr_label = f"{yr}년" if isinstance(yr, (int, float)) else str(yr)
            is_current = (isinstance(yr, (int, float)) and int(yr) == sel_year)
            rc = "hq-subtotal" if is_current else ""

            t_html += f'<tr class="{rc}"><td class="bold">{yr_label}</td>'
            total = 0
            for m in range(1, 13):
                v = r.get(m)
                if v is not None and not (isinstance(v, float) and pd.isnan(v)):
                    t_html += f'<td class="num">{fmt_int(v)}</td>'
                    total += v
                else:
                    t_html += '<td class="num" style="color:#CCC">-</td>'
            t_html += f'<td class="num bold">{fmt_int(total)}</td></tr>'
        t_html += "</tbody></table>"
        st.markdown(t_html, unsafe_allow_html=True)

    # ══════════════════════════════════════════════════════════
    # SECTION 05: 후원사업별 누계
    # ══════════════════════════════════════════════════════════
    render_section_anchor("sponsorship-ytd")
    render_section_header("⑤", "후원사업별 누계", f"{sel_year}년 {sel_month}월까지 누계")

    if sponsor_df.empty:
        st.info("후원사업별 데이터가 없습니다.")
    else:
        st.markdown(build_sponsorship_table_html(sponsor_df, sel_year, sel_month), unsafe_allow_html=True)

    st.markdown("""<div class="footer-note">
        ※ 법인별 회원개발 실적은 개발부서 기준이 아닌 개발회원이 속한 법인 기준임.
    </div>""", unsafe_allow_html=True)

    st.markdown("<div style='height:2rem'></div>", unsafe_allow_html=True)
    st.caption(f"회원개발 통합 리포트 · {sel_year}년 {sel_month}월 마감 기준 · Generated by Snowflake Streamlit")
