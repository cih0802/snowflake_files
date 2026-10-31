import streamlit as st
import pandas as pd
from html import escape

st.set_page_config(
    page_title="마케팅 캠페인 통합 성과",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
    <style>
    :root {
        --bg: #F7F6F1;
        --panel: #FFFFFF;
        --ink: #26332C;
        --muted: #70766F;
        --line: #DDD9CF;
        --olive: #80951B;
        --olive-soft: #F1F4DF;
        --orange: #F36A16;
        --blue: #397FF0;
    }
    .stApp {background: var(--bg); color: var(--ink);}
    .block-container {padding-top:1.35rem;padding-bottom:3rem;max-width:1500px;}
    [data-testid="stSidebar"] {background:#FFFFFF;border-right:1px solid var(--line);}
    [data-testid="stSidebar"] .block-container {padding-top:1.6rem;}
    h1,h2,h3,h4 {color:var(--ink);letter-spacing:-0.02em;}
    h1 {font-size:2rem !important;font-weight:800 !important;}
    div[data-testid="stCaptionContainer"] {color:var(--muted);}
    div[data-testid="stMetric"] {background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px 18px;min-height:104px;box-shadow:none;}
    div[data-testid="stMetricLabel"] {color:#59635B;font-weight:700;}
    div[data-testid="stMetricValue"] {color:var(--ink);font-weight:800;letter-spacing:-0.03em;}
    .report-kicker {color:var(--olive);font-size:.78rem;font-weight:800;letter-spacing:.10em;margin-bottom:6px;}
    .report-title {font-size:2rem;font-weight:850;color:var(--ink);line-height:1.2;margin-bottom:6px;}
    .report-subtitle {font-size:.88rem;color:var(--muted);margin-bottom:18px;}
    .sidebar-brand {font-size:1rem;font-weight:850;color:var(--ink);margin-bottom:3px;}
    .sidebar-sub {font-size:.75rem;color:var(--muted);margin-bottom:20px;}
    .sidebar-section {font-size:.79rem;font-weight:800;color:var(--olive);margin:18px 0 8px;}
    .section-shell {background:rgba(255,255,255,.58);border:1px solid var(--line);border-radius:10px;padding:18px 18px 10px;margin:14px 0 16px;}
    .section-number {color:var(--olive);font-weight:900;letter-spacing:.08em;margin-right:7px;}
    .section-title {font-size:1.25rem;font-weight:850;color:var(--ink);}
    .section-desc {font-size:.82rem;color:var(--muted);margin-top:4px;margin-bottom:10px;}
    .question-box {background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:18px 20px;margin:12px 0 16px;}
    .question-tag {display:inline-block;background:var(--olive-soft);color:#657817;border-radius:6px;padding:5px 10px;font-size:.75rem;font-weight:800;margin-bottom:10px;}
    .question-text {font-size:1.25rem;font-weight:850;line-height:1.45;color:var(--ink);}
    .hero-note {background:#F2F3EE;border:1px solid #D8DDD4;border-radius:12px;padding:13px 16px;color:#405047;margin:14px 0 8px;}
    .insight-card {background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:14px;margin-bottom:14px;height:390px;min-height:390px;max-height:390px;box-sizing:border-box;overflow:hidden;}
    .insight-title {font-size:.90rem;font-weight:850;color:var(--ink);margin-bottom:4px;line-height:1.35;}
    .insight-description {font-size:.73rem;color:var(--muted);margin-bottom:10px;min-height:32px;line-height:1.4;}
    .ranking-row {display:grid;grid-template-columns:24px minmax(0,1fr);column-gap:7px;padding:8px 0;border-bottom:1px solid #ECEAE4;}
    .ranking-row:last-child {border-bottom:none;}
    .ranking-number {width:22px;height:22px;border-radius:50%;background:var(--olive-soft);color:#607313;display:flex;align-items:center;justify-content:center;font-size:.72rem;font-weight:850;}
    .ranking-name {font-size:.79rem;font-weight:750;color:var(--ink);line-height:1.3;word-break:keep-all;overflow-wrap:anywhere;}
    .ranking-value {font-size:.72rem;color:var(--muted);margin-top:3px;}
    .ranking-empty {color:var(--muted);font-size:.80rem;padding:15px 0;}
    div[data-baseweb="tab-list"] {gap:2px;border-bottom:1px solid var(--line);}
    button[data-baseweb="tab"] {font-weight:750;color:#606860;padding-left:12px;padding-right:12px;}
    button[data-baseweb="tab"][aria-selected="true"] {color:var(--olive);}
    [data-testid="stDataFrame"] {border:1px solid var(--line);border-radius:10px;overflow:hidden;}
    [data-testid="stExpander"] {background:var(--panel);border:1px solid var(--line);border-radius:10px;}
    .stButton button {border-radius:8px;border:1px solid var(--line);background:#fff;color:var(--ink);font-weight:700;}
    .stButton button:hover {border-color:var(--olive);color:var(--olive);}
    </style>
    """,
    unsafe_allow_html=True,
)

conn = st.connection("snowflake")


@st.cache_data(ttl=3600, show_spinner=False)
def get_columns(schema_name, table_name):
    query = f"""
    SELECT COLUMN_NAME
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = '{schema_name}'
      AND TABLE_NAME = '{table_name}'
    ORDER BY ORDINAL_POSITION
    """
    return set(
        conn.query(query, ttl=3600)["COLUMN_NAME"]
        .astype(str)
        .str.upper()
    )


def choose_column(schema_name, table_name, candidates):
    columns = get_columns(schema_name, table_name)
    return next(
        (candidate.upper() for candidate in candidates if candidate.upper() in columns),
        None,
    )


def date_expr(alias, column):
    if not column:
        return "NULL::DATE"
    reference = f"{alias}.{column}"
    return (
        f"COALESCE("
        f"TRY_TO_DATE(TO_VARCHAR({reference}), 'YYYYMMDD'), "
        f"TRY_TO_DATE(TO_VARCHAR({reference})))"
    )


def rate_expr(alias, column):
    if not column:
        return "NULL::FLOAT"
    return f"TRY_TO_DOUBLE(REPLACE(TO_VARCHAR({alias}.{column}), '%', ''))"


VIDEO_DATE_COL = choose_column(
    "SILVER",
    "AGENCY_AD_ROW_VIDEO",
    ["BROADCAST_DATE", "DATE", "AD_START_TIME", "START_DATE", "BRDC_DATE", "YEAR_MONTH"],
)
REBROADCAST_DATE_COL = choose_column(
    "SILVER",
    "AGENCY_AD_ROW_REBRDC",
    ["BROADCAST_DATE", "DATE", "AD_START_TIME", "START_DATE", "BRDC_DATE", "WRITE_DATE", "YEAR_MONTH"],
)
ACTIVITY_RATE_COL = choose_column(
    "SILVER",
    "CRM_MEMBER_DEV",
    ["ACTIVITY_RATE", "ACTIVE_RATE", "ACTV_RATE", "ACTIVITY_RATIO", "ACTIVE_RATIO", "ACTV_RATIO"],
)
PAYMENT_RATE_COL = choose_column(
    "SILVER",
    "CRM_MEMBER_DEV",
    ["PAYMENT_RATE", "PAY_RATE", "PMNT_RATE", "PAYMENT_RATIO", "PAY_RATIO", "PMNT_RATIO"],
)

CAMPAIGN_TYPE1_COL = "CMPGN_TYPE1_NM"
CHANNEL_COL = "MKTG_CHANNEL_NM"

VIDEO_DATE_EXPR = date_expr("V", VIDEO_DATE_COL)
REBROADCAST_DATE_EXPR = date_expr("R", REBROADCAST_DATE_COL)
ACTIVITY_RATE_EXPR = rate_expr("D", ACTIVITY_RATE_COL)
PAYMENT_RATE_EXPR = rate_expr("D", PAYMENT_RATE_COL)


INTEGRATED_SQL = f"""
WITH CRM_CAMPAIGN_BASE AS (
    SELECT
        NULLIF(TRIM(CMPGN_CD), '') AS CMPGN_CD,
        NULLIF(TRIM(MK_CMPGN_NM), '') AS MKTG_CAMPAIGN_NM,
        NULLIF(TRIM(MBER_INFLOW_PATH_NM), '') AS INFLOW_PATH_NM,
        NULLIF(TRIM(MKTG_UTM_NM), '') AS MKTG_UTM_NM,
        NULLIF(TRIM(UPPER_CMPGN_CD), '') AS UPPER_CMPGN_CD,
        NULLIF(TRIM(PARENT_CAMPAIGN_NAME), '') AS PARENT_CAMPAIGN_NAME,
        COALESCE(NULLIF(TRIM(CMPGN_TYPE1_NM), ''), '미분류') AS CAMPAIGN_TYPE1,
        COALESCE(NULLIF(TRIM(MKTG_CHANNEL_NM), ''), '미분류') AS CHANNEL_NAME
    FROM GN_DW.SILVER.CRM_CAMPAIGN
    WHERE NULLIF(TRIM(CMPGN_CD), '') IS NOT NULL
      AND NULLIF(TRIM(MK_CMPGN_NM), '') IS NOT NULL
),
CAMPAIGN_DIM AS (
    SELECT
        MKTG_CAMPAIGN_NM,
        LISTAGG(DISTINCT CAMPAIGN_TYPE1, ', ')
            WITHIN GROUP (ORDER BY CAMPAIGN_TYPE1) AS CAMPAIGN_TYPE1,
        LISTAGG(DISTINCT CHANNEL_NAME, ', ')
            WITHIN GROUP (ORDER BY CHANNEL_NAME) AS CHANNEL_NAME
    FROM CRM_CAMPAIGN_BASE
    GROUP BY 1
),
CRM_DEV_SUMMARY AS (
    SELECT
        TO_DATE(D.OCCRRNC_DE, 'YYYYMMDD') AS PERFORMANCE_DATE,
        C.MKTG_CAMPAIGN_NM,
        LISTAGG(DISTINCT COALESCE(C.INFLOW_PATH_NM, '미분류'), ', ')
            WITHIN GROUP (ORDER BY COALESCE(C.INFLOW_PATH_NM, '미분류')) AS INFLOW_PATH_NM,
        COUNT(
            DISTINCT CONCAT_WS(
                '|',
                COALESCE(D.SPNSR_NO, ''),
                COALESCE(TO_VARCHAR(D.SPNSR_BSNS_NO), ''),
                COALESCE(D.OCCRRNC_DE, ''),
                COALESCE(TO_VARCHAR(D.SER_NO), '')
            )
        ) AS DEVELOPMENT_COUNT,
        1 AS ACTIVITY_RATE,
        1 AS PAYMENT_RATE
    FROM GN_DW.SILVER.CRM_MEMBER_DEV D
    JOIN CRM_CAMPAIGN_BASE C
      ON UPPER(TRIM(D.CMPGN_CD)) = UPPER(C.CMPGN_CD)
    WHERE REGEXP_LIKE(D.OCCRRNC_DE, '^[0-9]{{8}}$')
    GROUP BY 1, 2
),
ERP_COST_CODE AS (
    SELECT
        COALESCE(
            TRY_TO_DATE(TO_VARCHAR(WRITE_DATE), 'YYYYMMDD'),
            TRY_TO_DATE(TO_VARCHAR(WRITE_DATE))
        ) AS PERFORMANCE_DATE,
        UPPER(TRIM(CONTENTS_DELIMITER)) AS CMPGN_CD,
        SUM(COALESCE(SUM_AMT, 0)) AS PRODUCTION_COST
    FROM GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION
    WHERE CONTENTS_DELIMITER IS NOT NULL
      AND TRIM(CONTENTS_DELIMITER) NOT IN ('', '-')
    GROUP BY 1, 2
),
ERP_COST AS (
    SELECT
        E.PERFORMANCE_DATE,
        C.MKTG_CAMPAIGN_NM,
        SUM(E.PRODUCTION_COST) AS PRODUCTION_COST
    FROM ERP_COST_CODE E
    JOIN CRM_CAMPAIGN_BASE C
      ON E.CMPGN_CD = UPPER(C.CMPGN_CD)
    WHERE E.PERFORMANCE_DATE IS NOT NULL
    GROUP BY 1, 2
),
DIGITAL_MAP AS (
    SELECT UPPER(TRIM(MKTG_UTM_NM)) AS K,
           MKTG_CAMPAIGN_NM,
           COUNT(DISTINCT MKTG_CAMPAIGN_NM) OVER (PARTITION BY UPPER(TRIM(MKTG_UTM_NM))) AS CAMP_CNT
    FROM (
        SELECT DISTINCT MKTG_UTM_NM, MKTG_CAMPAIGN_NM
        FROM CRM_CAMPAIGN_BASE
        WHERE MKTG_UTM_NM IS NOT NULL AND TRIM(MKTG_UTM_NM) NOT IN ('', '-')
    )
),
DIGITAL_COST_KEY AS (
    SELECT TO_DATE(DATE) AS PERFORMANCE_DATE,
           UPPER(TRIM(UTM_CMPGN_NM)) AS K,
           SUM(COALESCE(LAST_STMT_AMT, 0)) AS DIGITAL_AD_COST
    FROM GN_DW.SILVER.AGENCY_AD_ROW_DGT
    WHERE UTM_CMPGN_NM IS NOT NULL AND TRIM(UTM_CMPGN_NM) NOT IN ('', '-') AND DATE IS NOT NULL
    GROUP BY 1, 2
),
DIGITAL_COST AS (
    SELECT D.PERFORMANCE_DATE,
           M.MKTG_CAMPAIGN_NM,
           SUM(D.DIGITAL_AD_COST / M.CAMP_CNT) AS DIGITAL_AD_COST
    FROM DIGITAL_COST_KEY D
    JOIN DIGITAL_MAP M ON D.K = M.K
    GROUP BY 1, 2
),
VIDEO_MAP AS (
    SELECT UPPER(TRIM(PARENT_CAMPAIGN_NAME)) AS K,
           MKTG_CAMPAIGN_NM,
           COUNT(DISTINCT MKTG_CAMPAIGN_NM) OVER (PARTITION BY UPPER(TRIM(PARENT_CAMPAIGN_NAME))) AS CAMP_CNT
    FROM (
        SELECT DISTINCT PARENT_CAMPAIGN_NAME, MKTG_CAMPAIGN_NM
        FROM CRM_CAMPAIGN_BASE
        WHERE PARENT_CAMPAIGN_NAME IS NOT NULL AND TRIM(PARENT_CAMPAIGN_NAME) NOT IN ('', '-')
    )
),
VIDEO_COST_KEY AS (
    SELECT COALESCE(TRY_TO_DATE(TO_VARCHAR(V.BRDC_DATE), 'YYYYMMDD'),
                    TRY_TO_DATE(TO_VARCHAR(V.BRDC_DATE))) AS PERFORMANCE_DATE,
           UPPER(TRIM(V.UPPER_CMPGN_NM)) AS K,
           SUM(COALESCE(V.LAST_AD_COST, 0)) AS VIDEO_AD_COST
    FROM GN_DW.SILVER.AGENCY_AD_ROW_VIDEO V
    WHERE V.UPPER_CMPGN_NM IS NOT NULL AND TRIM(V.UPPER_CMPGN_NM) NOT IN ('', '-')
      AND COALESCE(TRY_TO_DATE(TO_VARCHAR(V.BRDC_DATE), 'YYYYMMDD'),
                   TRY_TO_DATE(TO_VARCHAR(V.BRDC_DATE))) IS NOT NULL
    GROUP BY 1, 2
),
VIDEO_COST AS (
    SELECT V.PERFORMANCE_DATE,
           M.MKTG_CAMPAIGN_NM,
           SUM(V.VIDEO_AD_COST / M.CAMP_CNT) AS VIDEO_AD_COST
    FROM VIDEO_COST_KEY V
    JOIN VIDEO_MAP M ON V.K = M.K
    GROUP BY 1, 2
),
REBROADCAST_MAP AS (
    SELECT UPPER(TRIM(UPPER_CMPGN_CD)) AS K,
           MKTG_CAMPAIGN_NM,
           COUNT(DISTINCT MKTG_CAMPAIGN_NM) OVER (PARTITION BY UPPER(TRIM(UPPER_CMPGN_CD))) AS CAMP_CNT
    FROM (
        SELECT DISTINCT UPPER_CMPGN_CD, MKTG_CAMPAIGN_NM
        FROM CRM_CAMPAIGN_BASE
        WHERE UPPER_CMPGN_CD IS NOT NULL AND TRIM(UPPER_CMPGN_CD) NOT IN ('', '-')
    )
),
REBROADCAST_COST_KEY AS (
    SELECT COALESCE(TRY_TO_DATE(TO_VARCHAR(R.BRDC_DATE), 'YYYYMMDD'),
                    TRY_TO_DATE(TO_VARCHAR(R.BRDC_DATE))) AS PERFORMANCE_DATE,
           UPPER(TRIM(R.UPPER_CMPGN_CD)) AS K,
           SUM(COALESCE(R.TOT_COST, 0)) AS REBROADCAST_AD_COST
    FROM GN_DW.SILVER.AGENCY_AD_ROW_REBRDC R
    WHERE R.UPPER_CMPGN_CD IS NOT NULL AND TRIM(R.UPPER_CMPGN_CD) NOT IN ('', '-')
      AND COALESCE(TRY_TO_DATE(TO_VARCHAR(R.BRDC_DATE), 'YYYYMMDD'),
                   TRY_TO_DATE(TO_VARCHAR(R.BRDC_DATE))) IS NOT NULL
    GROUP BY 1, 2
),
REBROADCAST_COST AS (
    SELECT R.PERFORMANCE_DATE,
           M.MKTG_CAMPAIGN_NM,
           SUM(R.REBROADCAST_AD_COST / M.CAMP_CNT) AS REBROADCAST_AD_COST
    FROM REBROADCAST_COST_KEY R
    JOIN REBROADCAST_MAP M ON R.K = M.K
    GROUP BY 1, 2
),
REBROADCAST_COST_KEY AS (
    SELECT
        {REBROADCAST_DATE_EXPR} AS PERFORMANCE_DATE,
        UPPER(TRIM(R.UPPER_CMPGN_CD)) AS K,
        SUM(COALESCE(R.TOT_COST, 0)) AS REBROADCAST_AD_COST
    FROM GN_DW.SILVER.AGENCY_AD_ROW_REBRDC R
    WHERE R.UPPER_CMPGN_CD IS NOT NULL
      AND TRIM(R.UPPER_CMPGN_CD) NOT IN ('', '-')
      AND {REBROADCAST_DATE_EXPR} IS NOT NULL
    GROUP BY 1, 2
),
REBROADCAST_COST AS (
    SELECT
        R.PERFORMANCE_DATE,
        M.MKTG_CAMPAIGN_NM,
        SUM(R.REBROADCAST_AD_COST) AS REBROADCAST_AD_COST
    FROM REBROADCAST_COST_KEY R
    JOIN REBROADCAST_MAP M ON R.K = M.K
    GROUP BY 1, 2
),
ACTIVE_KEYS AS (
    SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM FROM CRM_DEV_SUMMARY
    UNION
    SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM FROM ERP_COST
    UNION
    SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM FROM DIGITAL_COST
    UNION
    SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM FROM VIDEO_COST
    UNION
    SELECT PERFORMANCE_DATE, MKTG_CAMPAIGN_NM FROM REBROADCAST_COST
),
FINAL_DATA AS (
    SELECT
        K.PERFORMANCE_DATE,
        K.MKTG_CAMPAIGN_NM AS MARKETING_CAMPAIGN_NAME,
        COALESCE(X.CAMPAIGN_TYPE1, '미분류') AS CAMPAIGN_TYPE1,
        COALESCE(X.CHANNEL_NAME, '미분류') AS CHANNEL_NAME,
        COALESCE(C.INFLOW_PATH_NM, '미분류') AS DEVELOPMENT_INFLOW_PATH,
        COALESCE(E.PRODUCTION_COST, 0) AS PRODUCTION_COST,
        COALESCE(D.DIGITAL_AD_COST, 0) AS DIGITAL_AD_COST,
        COALESCE(V.VIDEO_AD_COST, 0) AS VIDEO_AD_COST,
        COALESCE(R.REBROADCAST_AD_COST, 0) AS REBROADCAST_AD_COST,
        COALESCE(D.DIGITAL_AD_COST, 0)
            + COALESCE(V.VIDEO_AD_COST, 0)
            + COALESCE(R.REBROADCAST_AD_COST, 0) AS AD_COST,
        COALESCE(E.PRODUCTION_COST, 0)
            + COALESCE(D.DIGITAL_AD_COST, 0)
            + COALESCE(V.VIDEO_AD_COST, 0)
            + COALESCE(R.REBROADCAST_AD_COST, 0) AS TOTAL_COST,
        COALESCE(C.DEVELOPMENT_COUNT, 0) AS DEVELOPMENT_COUNT,
        C.ACTIVITY_RATE,
        C.PAYMENT_RATE
    FROM ACTIVE_KEYS K
    LEFT JOIN CAMPAIGN_DIM X
      ON K.MKTG_CAMPAIGN_NM = X.MKTG_CAMPAIGN_NM
    LEFT JOIN CRM_DEV_SUMMARY C
      ON K.PERFORMANCE_DATE = C.PERFORMANCE_DATE
     AND K.MKTG_CAMPAIGN_NM = C.MKTG_CAMPAIGN_NM
    LEFT JOIN ERP_COST E
      ON K.PERFORMANCE_DATE = E.PERFORMANCE_DATE
     AND K.MKTG_CAMPAIGN_NM = E.MKTG_CAMPAIGN_NM
    LEFT JOIN DIGITAL_COST D
      ON K.PERFORMANCE_DATE = D.PERFORMANCE_DATE
     AND K.MKTG_CAMPAIGN_NM = D.MKTG_CAMPAIGN_NM
    LEFT JOIN VIDEO_COST V
      ON K.PERFORMANCE_DATE = V.PERFORMANCE_DATE
     AND K.MKTG_CAMPAIGN_NM = V.MKTG_CAMPAIGN_NM
    LEFT JOIN REBROADCAST_COST R
      ON K.PERFORMANCE_DATE = R.PERFORMANCE_DATE
     AND K.MKTG_CAMPAIGN_NM = R.MKTG_CAMPAIGN_NM
)
SELECT
    *,
    DIV0(TOTAL_COST, DEVELOPMENT_COUNT) AS DEVELOPMENT_UNIT_COST
FROM FINAL_DATA
WHERE PERFORMANCE_DATE IS NOT NULL
  AND (DEVELOPMENT_COUNT > 0 OR TOTAL_COST <> 0)
ORDER BY PERFORMANCE_DATE DESC, TOTAL_COST DESC
"""


@st.cache_data(ttl=600, show_spinner=False)
def load_data():
    return conn.query(INTEGRATED_SQL, ttl=600)


def won(value):
    return f"{float(value or 0):,.0f}원"


def cnt(value):
    return f"{float(value or 0):,.0f}건"


def rate_pct(value):
    if pd.isna(value):
        return "-"
    numeric = float(value)
    if 0 <= numeric <= 1:
        numeric *= 100
    return f"{numeric:,.1f}%"


def sums(df):
    production = df["PRODUCTION_COST"].sum()
    advertising = df["AD_COST"].sum()
    development = df["DEVELOPMENT_COUNT"].sum()
    total = df["TOTAL_COST"].sum()
    return {
        "prod": production,
        "ad": advertising,
        "dev": development,
        "total": total,
        "unit": total / development if development else 0,
    }


def combine_labels(values):
    return ", ".join(
        sorted(
            {
                item.strip()
                for value in values.dropna().astype(str)
                for item in value.split(",")
                if item.strip()
            }
        )
    ) or "미분류"


def aggregate_campaigns(df):
    output_columns = [
        "MARKETING_CAMPAIGN_NAME", "CAMPAIGN_TYPE1", "CHANNEL_NAME",
        "DEVELOPMENT_INFLOW_PATH", "PRODUCTION_COST", "DIGITAL_AD_COST",
        "VIDEO_AD_COST", "REBROADCAST_AD_COST", "AD_COST", "TOTAL_COST",
        "DEVELOPMENT_COUNT", "DEVELOPMENT_UNIT_COST", "ACTIVITY_RATE",
        "PAYMENT_RATE",
    ]
    if df.empty:
        return pd.DataFrame(columns=output_columns)

    working = df.copy()
    for rate_column in ["ACTIVITY_RATE", "PAYMENT_RATE"]:
        working[f"{rate_column}_WX"] = (
            working[rate_column] * working["DEVELOPMENT_COUNT"]
        )
        working[f"{rate_column}_W"] = working["DEVELOPMENT_COUNT"].where(
            working[rate_column].notna(),
            0,
        )

    grouped = working.groupby("MARKETING_CAMPAIGN_NAME", as_index=False).agg(
        CAMPAIGN_TYPE1=("CAMPAIGN_TYPE1", combine_labels),
        CHANNEL_NAME=("CHANNEL_NAME", combine_labels),
        DEVELOPMENT_INFLOW_PATH=("DEVELOPMENT_INFLOW_PATH", combine_labels),
        PRODUCTION_COST=("PRODUCTION_COST", "sum"),
        DIGITAL_AD_COST=("DIGITAL_AD_COST", "sum"),
        VIDEO_AD_COST=("VIDEO_AD_COST", "sum"),
        REBROADCAST_AD_COST=("REBROADCAST_AD_COST", "sum"),
        AD_COST=("AD_COST", "sum"),
        TOTAL_COST=("TOTAL_COST", "sum"),
        DEVELOPMENT_COUNT=("DEVELOPMENT_COUNT", "sum"),
        ACTIVITY_RATE_WX=("ACTIVITY_RATE_WX", "sum"),
        ACTIVITY_RATE_W=("ACTIVITY_RATE_W", "sum"),
        PAYMENT_RATE_WX=("PAYMENT_RATE_WX", "sum"),
        PAYMENT_RATE_W=("PAYMENT_RATE_W", "sum"),
    )

    grouped["DEVELOPMENT_UNIT_COST"] = (
        grouped["TOTAL_COST"]
        .div(grouped["DEVELOPMENT_COUNT"].replace(0, pd.NA))
        .fillna(0)
    )
    grouped["ACTIVITY_RATE"] = grouped["ACTIVITY_RATE_WX"].div(
        grouped["ACTIVITY_RATE_W"].replace(0, pd.NA)
    )
    grouped["PAYMENT_RATE"] = grouped["PAYMENT_RATE_WX"].div(
        grouped["PAYMENT_RATE_W"].replace(0, pd.NA)
    )

    return grouped.drop(
        columns=[
            "ACTIVITY_RATE_WX", "ACTIVITY_RATE_W",
            "PAYMENT_RATE_WX", "PAYMENT_RATE_W",
        ]
    )


def split_options(series):
    return sorted(
        {
            item.strip()
            for value in series.dropna().astype(str)
            for item in value.split(",")
            if item.strip()
        }
    )


def filter_multi_value_column(df, column, selected_values):
    if not selected_values:
        return df
    selected_set = set(selected_values)
    mask = df[column].apply(
        lambda value: bool(
            {
                item.strip()
                for item in str(value).split(",")
                if item.strip()
            }
            & selected_set
        )
    )
    return df[mask]


def ranking_card(title, description, ranking_df, value_column, formatter, label):
    parts = [
        '<div class="insight-card">',
        f'<div class="insight-title">{escape(title)}</div>',
        f'<div class="insight-description">{escape(description)}</div>',
    ]
    if ranking_df.empty:
        parts.append('<div class="ranking-empty">표시할 데이터가 없습니다.</div>')
    else:
        for rank, (_, row) in enumerate(ranking_df.iterrows(), start=1):
            name = escape(str(row["MARKETING_CAMPAIGN_NAME"]))
            value = escape(formatter(row[value_column]))
            parts.append(
                '<div class="ranking-row">'
                f'<div class="ranking-number">{rank}</div>'
                '<div>'
                f'<div class="ranking-name">{name}</div>'
                f'<div class="ranking-value">{escape(label)} {value}</div>'
                '</div>'
                '</div>'
            )
    parts.append('</div>')
    st.markdown(''.join(parts), unsafe_allow_html=True)


def selected_campaign_from_event(event):
    """Vega-Lite 선택 이벤트에서 캠페인명을 안전하게 추출합니다."""
    try:
        selection = event.selection.get("campaign_pick", [])
    except (AttributeError, TypeError):
        try:
            selection = event.get("selection", {}).get("campaign_pick", [])
        except (AttributeError, TypeError):
            return None

    if isinstance(selection, dict):
        selection = [selection]
    if not selection:
        return None

    first = selection[0]
    if isinstance(first, dict):
        return first.get("MARKETING_CAMPAIGN_NAME")
    return None


st.markdown(
    """
    <div class="report-kicker">MARKETING PERFORMANCE</div>
    <div class="report-title">마케팅 콘텐츠 통합성과 대시보드</div>
    """,
    unsafe_allow_html=True,
)

try:
    with st.spinner("Snowflake 데이터를 불러오는 중입니다."):
        raw = load_data()
except Exception as error:
    st.error("통합 데이터를 조회하지 못했습니다.")
    st.exception(error)
    st.stop()

if raw.empty:
    st.warning("조회 결과가 없습니다.")
    st.stop()

raw["PERFORMANCE_DATE"] = pd.to_datetime(raw["PERFORMANCE_DATE"], errors="coerce")
raw = raw[
    raw["PERFORMANCE_DATE"].notna()
    & raw["PERFORMANCE_DATE"].dt.year.between(2000, 2100)
].copy()

if raw.empty:
    st.warning("정상적인 분석 기간 데이터가 없습니다.")
    st.stop()

raw["PERFORMANCE_DATE"] = raw["PERFORMANCE_DATE"].dt.normalize()

numeric_columns = [
    "PRODUCTION_COST", "DIGITAL_AD_COST", "VIDEO_AD_COST",
    "REBROADCAST_AD_COST", "AD_COST", "TOTAL_COST",
    "DEVELOPMENT_COUNT", "DEVELOPMENT_UNIT_COST",
    "ACTIVITY_RATE", "PAYMENT_RATE",
]
for column in numeric_columns:
    raw[column] = pd.to_numeric(raw[column], errors="coerce")

for column in [
    "PRODUCTION_COST", "DIGITAL_AD_COST", "VIDEO_AD_COST",
    "REBROADCAST_AD_COST", "AD_COST", "TOTAL_COST",
    "DEVELOPMENT_COUNT", "DEVELOPMENT_UNIT_COST",
]:
    raw[column] = raw[column].fillna(0)

for column in ["CAMPAIGN_TYPE1", "CHANNEL_NAME", "DEVELOPMENT_INFLOW_PATH"]:
    raw[column] = raw[column].fillna("미분류").astype(str)

min_date = raw["PERFORMANCE_DATE"].min().date()
max_date = raw["PERFORMANCE_DATE"].max().date()
default_start = max(
    min_date,
    (pd.Timestamp(max_date) - pd.DateOffset(years=1)).date(),
)

with st.sidebar:
    st.markdown('<div class="sidebar-brand">나눔마케팅본부 통합 분석</div>', unsafe_allow_html=True)
    st.markdown('<div class="sidebar-sub">CRM · ERP · 광고성과 데이터</div>', unsafe_allow_html=True)

    st.header("분석 필터")

    period_scope = st.selectbox(
        "분석 범위",
        options=[
            "최근 1개월",
            "최근 3개월",
            "최근 6개월",
            "최근 1년",
            "최근 2년",
            "전체 기간",
            "직접 선택",
        ],
        index=3,
        help="데이터의 최신일을 기준으로 분석 기간을 선택합니다.",
    )

    if period_scope == "최근 1개월":
        selected_start_date = max(
            min_date,
            (pd.Timestamp(max_date) - pd.DateOffset(months=1)).date(),
        )
        selected_end_date = max_date
    elif period_scope == "최근 3개월":
        selected_start_date = max(
            min_date,
            (pd.Timestamp(max_date) - pd.DateOffset(months=3)).date(),
        )
        selected_end_date = max_date
    elif period_scope == "최근 6개월":
        selected_start_date = max(
            min_date,
            (pd.Timestamp(max_date) - pd.DateOffset(months=6)).date(),
        )
        selected_end_date = max_date
    elif period_scope == "최근 1년":
        selected_start_date = max(
            min_date,
            (pd.Timestamp(max_date) - pd.DateOffset(years=1)).date(),
        )
        selected_end_date = max_date
    elif period_scope == "최근 2년":
        selected_start_date = max(
            min_date,
            (pd.Timestamp(max_date) - pd.DateOffset(years=2)).date(),
        )
        selected_end_date = max_date
    elif period_scope == "전체 기간":
        selected_start_date = min_date
        selected_end_date = max_date
    else:
        selected_start_date = st.date_input(
            "시작일",
            value=default_start,
            min_value=min_date,
            max_value=max_date,
            format="YYYY.MM.DD",
            key="analysis_start_date",
        )
        selected_end_date = st.date_input(
            "종료일",
            value=max_date,
            min_value=min_date,
            max_value=max_date,
            format="YYYY.MM.DD",
            key="analysis_end_date",
        )

    if period_scope != "직접 선택":
        st.caption(
            f"적용 기간: {selected_start_date:%Y.%m.%d} ~ "
            f"{selected_end_date:%Y.%m.%d}"
        )

    st.divider()

    campaign_type_options = split_options(raw["CAMPAIGN_TYPE1"])
    selected_campaign_types = st.multiselect(
        "캠페인 유형1",
        options=campaign_type_options,
        placeholder="전체 캠페인 유형1",
    )

    channel_options = split_options(raw["CHANNEL_NAME"])
    selected_channels = st.multiselect(
        "채널",
        options=channel_options,
        placeholder="전체 채널",
    )

    inflow_options = split_options(raw["DEVELOPMENT_INFLOW_PATH"])
    selected_inflows = st.multiselect(
        "개발인입경로",
        options=inflow_options,
        placeholder="전체 개발인입경로",
    )

    if st.button("데이터 새로고침", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

    st.divider()
    st.caption(f"전체 데이터 기간: {min_date:%Y.%m.%d} ~ {max_date:%Y.%m.%d}")

start_date = pd.Timestamp(selected_start_date)
end_date = pd.Timestamp(selected_end_date)

if start_date > end_date:
    st.warning("시작일은 종료일보다 늦을 수 없습니다.")
    st.stop()

filtered = raw[
    raw["PERFORMANCE_DATE"].between(start_date, end_date, inclusive="both")
].copy()
filtered = filter_multi_value_column(
    filtered,
    "CAMPAIGN_TYPE1",
    selected_campaign_types,
)
filtered = filter_multi_value_column(
    filtered,
    "CHANNEL_NAME",
    selected_channels,
)
filtered = filter_multi_value_column(
    filtered,
    "DEVELOPMENT_INFLOW_PATH",
    selected_inflows,
)

current = aggregate_campaigns(filtered)
cur = sums(current)

k1, k2, k3, k4 = st.columns(4)
k1.metric("총 제작비", won(cur["prod"]))
k2.metric("총 광고비", won(cur["ad"]))
k3.metric("총 개발건수", cnt(cur["dev"]))
k4.metric("통합 개발단가", won(cur["unit"]))

period_label = "전체 기간" if period_scope == "전체 기간" else "직접 선택"
st.markdown(
    f'<div class="hero-note"><b>분석 기준</b>&nbsp;&nbsp;{period_label}'
    f'&nbsp;&nbsp;{start_date:%Y.%m.%d} ~ {end_date:%Y.%m.%d}'
    f'&nbsp;&nbsp;|&nbsp;&nbsp;통합 개발단가 = (제작비 + 광고비) ÷ 개발건수</div>',
    unsafe_allow_html=True,
)

tab1, tab2, tab3, tab4 = st.tabs(
    ["01 통합 성과", "02 비용 상세", "03 캠페인 상세", "04 데이터 점검"]
)

with tab1:
    st.subheader("비용 투입 대비 개발 성과")
    st.caption("버블의 크기는 캠페인별 개발총수를 나타냅니다. 원을 클릭하면 상세 성과가 아래에 표시됩니다.")
    chart = current[
        (current["TOTAL_COST"] > 0)
        & (current["DEVELOPMENT_COUNT"] > 0)
    ].copy()

    if chart.empty:
        st.info("산점도와 TOP 5를 표시할 데이터가 없습니다.")
    else:
        positive_unit = chart.loc[
            chart["DEVELOPMENT_UNIT_COST"] > 0,
            "DEVELOPMENT_UNIT_COST",
        ]
        q33 = positive_unit.quantile(0.33) if not positive_unit.empty else 0
        q67 = positive_unit.quantile(0.67) if not positive_unit.empty else 0

        def efficiency_band(value):
            if value <= 0:
                return "성과 없음"
            if value <= q33:
                return "효율 우수"
            if value <= q67:
                return "보통"
            return "효율 점검"

        chart["효율영역"] = chart["DEVELOPMENT_UNIT_COST"].apply(efficiency_band)
        chart["점크기"] = chart["DEVELOPMENT_COUNT"].clip(lower=1)

        x_max = max(float(chart["PRODUCTION_COST"].max()) * 1.12, 1.0)
        y_max = max(float(chart["AD_COST"].max()) * 1.12, 1.0)

        scatter_spec = {
            "padding": {"left": 24, "right": 34, "top": 24, "bottom": 18},
            "autosize": {"type": "fit", "contains": "padding"},
            "params": [
                {
                    "name": "campaign_pick",
                    "select": {
                        "type": "point",
                        "fields": ["MARKETING_CAMPAIGN_NAME"],
                        "on": "click",
                        "clear": "dblclick",
                    },
                }
            ],
            "mark": {"type": "circle", "opacity": 0.72, "stroke": "#FFFFFF", "strokeWidth": 1.2},
            "encoding": {
                "x": {
                    "field": "PRODUCTION_COST",
                    "type": "quantitative",
                    "title": "제작비(원)",
                    "scale": {"domain": [0, x_max], "nice": True},
                },
                "y": {
                    "field": "AD_COST",
                    "type": "quantitative",
                    "title": "광고비(원)",
                    "scale": {"domain": [0, y_max], "nice": True},
                },
                "color": {
                    "field": "효율영역",
                    "type": "nominal",
                    "title": "효율영역",
                    "scale": {
                        "domain": ["효율 우수", "보통", "효율 점검", "성과 없음"],
                        "range": ["#80951B", "#D5B25A", "#F36A16", "#9A9E98"],
                    },
                },
                "size": {
                    "field": "점크기",
                    "type": "quantitative",
                    "title": "개발총수",
                    "legend": None,
                    "scale": {"type": "sqrt", "range": [55, 820]},
                },
                "opacity": {
                    "condition": {"param": "campaign_pick", "value": 0.95},
                    "value": 0.48,
                },
                "tooltip": [
                    {"field": "MARKETING_CAMPAIGN_NAME", "title": "캠페인"},
                    {"field": "CAMPAIGN_TYPE1", "title": "캠페인 유형1"},
                    {"field": "CHANNEL_NAME", "title": "채널"},
                    {"field": "PRODUCTION_COST", "title": "제작비", "format": ",.0f"},
                    {"field": "AD_COST", "title": "광고비", "format": ",.0f"},
                    {"field": "DEVELOPMENT_COUNT", "title": "개발총수", "format": ",.0f"},
                    {"field": "DEVELOPMENT_UNIT_COST", "title": "개발단가", "format": ",.0f"},
                ],
            },
        }
        chart_event = st.vega_lite_chart(
            chart,
            scatter_spec,
            width="stretch",
            height=460,
            key="campaign_scatter",
            on_select="rerun",
            selection_mode="campaign_pick",
        )

        selected_campaign = selected_campaign_from_event(chart_event)
        if selected_campaign:
            selected_rows = chart[
                chart["MARKETING_CAMPAIGN_NAME"] == selected_campaign
            ]
            if not selected_rows.empty:
                selected_row = selected_rows.iloc[0]
                st.markdown(f"#### 선택 캠페인 성과 · {selected_campaign}")
                d1, d2, d3, d4 = st.columns(4)
                d1.metric("총비용", won(selected_row["TOTAL_COST"]))
                d2.metric("개발총수", cnt(selected_row["DEVELOPMENT_COUNT"]))
                d3.metric("개발단가", won(selected_row["DEVELOPMENT_UNIT_COST"]))
                d4.metric(
                    "활동률 / 납입률",
                    f"{rate_pct(selected_row['ACTIVITY_RATE'])} / {rate_pct(selected_row['PAYMENT_RATE'])}",
                )

                detail_left, detail_right = st.columns([1.15, 1.85])
                with detail_left:
                    selected_summary = pd.DataFrame(
                        {
                            "항목": [
                                "캠페인 유형1",
                                "채널",
                                "개발인입경로",
                                "제작비",
                                "광고비",
                            ],
                            "값": [
                                selected_row["CAMPAIGN_TYPE1"],
                                selected_row["CHANNEL_NAME"],
                                selected_row["DEVELOPMENT_INFLOW_PATH"],
                                won(selected_row["PRODUCTION_COST"]),
                                won(selected_row["AD_COST"]),
                            ],
                        }
                    )
                    st.dataframe(
                        selected_summary,
                        use_container_width=True,
                        hide_index=True,
                    )

                with detail_right:
                    selected_cost = pd.DataFrame(
                        {
                            "비용 구분": ["제작비", "디지털", "영상광고", "재송출·방송"],
                            "금액": [
                                selected_row["PRODUCTION_COST"],
                                selected_row["DIGITAL_AD_COST"],
                                selected_row["VIDEO_AD_COST"],
                                selected_row["REBROADCAST_AD_COST"],
                            ],
                        }
                    ).set_index("비용 구분")
                    st.bar_chart(selected_cost, use_container_width=True)
        else:
            st.caption("산점도의 원을 클릭하면 해당 캠페인의 상세 성과가 표시됩니다. 선택 해제는 원을 더블클릭하세요.")

        efficient_top5 = (
            chart[chart["DEVELOPMENT_UNIT_COST"] > 0]
            .sort_values(
                ["DEVELOPMENT_UNIT_COST", "DEVELOPMENT_COUNT"],
                ascending=[True, False],
            )
            .head(5)
        )
        development_top5 = (
            chart.sort_values(
                ["DEVELOPMENT_COUNT", "DEVELOPMENT_UNIT_COST"],
                ascending=[False, True],
            )
            .head(5)
        )
        activity_top5 = (
            chart[chart["ACTIVITY_RATE"].notna()]
            .sort_values(
                ["ACTIVITY_RATE", "DEVELOPMENT_COUNT"],
                ascending=[False, False],
            )
            .head(5)
        )
        payment_top5 = (
            chart[chart["PAYMENT_RATE"].notna()]
            .sort_values(
                ["PAYMENT_RATE", "DEVELOPMENT_COUNT"],
                ascending=[False, False],
            )
            .head(5)
        )

        st.markdown("#### 주요 캠페인 TOP 5")
        top1, top2, top3, top4 = st.columns(4)

        with top1:
            ranking_card(
                "효율 우수 캠페인 TOP 5",
                "개발단가가 낮은 순입니다.",
                efficient_top5,
                "DEVELOPMENT_UNIT_COST",
                won,
                "개발단가",
            )
        with top2:
            ranking_card(
                "개발건수 상위 캠페인 TOP 5",
                "개발건수가 많은 순입니다.",
                development_top5,
                "DEVELOPMENT_COUNT",
                cnt,
                "개발건수",
            )
        with top3:
            ranking_card(
                "활동률 높은 캠페인 TOP 5",
                "활동률이 높은 순입니다.",
                activity_top5,
                "ACTIVITY_RATE",
                rate_pct,
                "활동률",
            )
        with top4:
            ranking_card(
                "납입률 높은 캠페인 TOP 5",
                "납입률이 높은 순입니다.",
                payment_top5,
                "PAYMENT_RATE",
                rate_pct,
                "납입률",
            )

    st.divider()
    st.subheader("캠페인별 통합 성과")

    table = current.sort_values("TOTAL_COST", ascending=False).rename(
        columns={
            "MARKETING_CAMPAIGN_NAME": "마케팅캠페인명",
            "CAMPAIGN_TYPE1": "캠페인 유형1",
            "CHANNEL_NAME": "채널",
            "DEVELOPMENT_INFLOW_PATH": "개발인입경로",
            "PRODUCTION_COST": "제작비",
            "AD_COST": "광고비",
            "TOTAL_COST": "총비용",
            "DEVELOPMENT_COUNT": "개발건수",
            "DEVELOPMENT_UNIT_COST": "개발단가",
            "ACTIVITY_RATE": "활동률",
            "PAYMENT_RATE": "납입률",
        }
    )
    show_columns = [
        "마케팅캠페인명", "캠페인 유형1", "채널", "개발인입경로",
        "제작비", "광고비", "총비용", "개발건수", "개발단가",
        "활동률", "납입률",
    ]
    st.dataframe(
        table[show_columns],
        use_container_width=True,
        hide_index=True,
    )
    st.download_button(
        "통합 성과 CSV 다운로드",
        table.to_csv(index=False).encode("utf-8-sig"),
        file_name=(
            f"campaign_performance_{start_date:%Y%m%d}_{end_date:%Y%m%d}.csv"
        ),
        mime="text/csv",
    )

with tab2:
    st.markdown('<div class="section-shell"><span class="section-number">02</span><span class="section-title">비용 상세</span><div class="section-desc">제작비와 매체별 광고비가 어디에 투입되었는지 확인합니다.</div></div>', unsafe_allow_html=True)
    st.subheader("원천별 비용 상세")
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("ERP 제작비", won(cur["prod"]))
    c2.metric("디지털", won(current["DIGITAL_AD_COST"].sum()))
    c3.metric("영상광고", won(current["VIDEO_AD_COST"].sum()))
    c4.metric("재송출·방송", won(current["REBROADCAST_AD_COST"].sum()))

    cost = current[
        [
            "MARKETING_CAMPAIGN_NAME", "CAMPAIGN_TYPE1", "CHANNEL_NAME",
            "PRODUCTION_COST", "DIGITAL_AD_COST", "VIDEO_AD_COST",
            "REBROADCAST_AD_COST", "TOTAL_COST",
        ]
    ].sort_values("TOTAL_COST", ascending=False)
    st.dataframe(cost, use_container_width=True, hide_index=True)

    if not cost.empty:
        chart_cost = cost.head(10).set_index("MARKETING_CAMPAIGN_NAME")[
            [
                "PRODUCTION_COST", "DIGITAL_AD_COST",
                "VIDEO_AD_COST", "REBROADCAST_AD_COST",
            ]
        ]
        st.bar_chart(chart_cost, use_container_width=True)

with tab3:
    st.markdown('<div class="section-shell"><span class="section-number">03</span><span class="section-title">캠페인 상세</span><div class="section-desc">선택한 캠페인의 비용과 개발성과를 자세히 확인합니다.</div></div>', unsafe_allow_html=True)
    st.subheader("캠페인 상세")
    campaign_options = current["MARKETING_CAMPAIGN_NAME"].dropna().astype(str).tolist()

    if campaign_options:
        campaign_name = st.selectbox("상세 캠페인", campaign_options)
        row = current[
            current["MARKETING_CAMPAIGN_NAME"] == campaign_name
        ].iloc[0]

        a, b, c, d = st.columns(4)
        a.metric("제작비", won(row["PRODUCTION_COST"]))
        b.metric("광고비", won(row["AD_COST"]))
        c.metric("개발건수", cnt(row["DEVELOPMENT_COUNT"]))
        d.metric("개발단가", won(row["DEVELOPMENT_UNIT_COST"]))

        st.write(
            f"캠페인 유형1: {row['CAMPAIGN_TYPE1']} / "
            f"채널: {row['CHANNEL_NAME']} / "
            f"활동률: {rate_pct(row['ACTIVITY_RATE'])} / "
            f"납입률: {rate_pct(row['PAYMENT_RATE'])}"
        )
    else:
        st.info("상세 조회할 캠페인이 없습니다.")

with tab4:
    st.markdown('<div class="section-shell"><span class="section-number">04</span><span class="section-title">데이터 점검</span><div class="section-desc">비용 또는 개발성과가 연결되지 않은 캠페인을 확인합니다.</div></div>', unsafe_allow_html=True)
    st.subheader("데이터 점검")
    zero_development = current[current["DEVELOPMENT_COUNT"] == 0]
    zero_production = current[current["PRODUCTION_COST"] == 0]
    zero_advertising = current[current["AD_COST"] == 0]

    a, b, c = st.columns(3)
    a.metric("개발건수 0", f"{len(zero_development):,}개")
    b.metric("제작비 미연결", f"{len(zero_production):,}개")
    c.metric("광고비 미연결", f"{len(zero_advertising):,}개")

    check_type = st.selectbox(
        "점검 항목",
        ["제작비 미연결", "광고비 미연결", "개발건수 0"],
    )
    check_frames = {
        "제작비 미연결": zero_production,
        "광고비 미연결": zero_advertising,
        "개발건수 0": zero_development,
    }
    st.dataframe(
        check_frames[check_type],
        use_container_width=True,
        hide_index=True,
    )

with st.expander("현재 적용 기준 및 확인 항목"):
    st.write("캠페인 유형1은 CRM_CAMPAIGN.CMPGN_TYPE1_NM을 사용합니다.")
    st.write("채널은 CRM_CAMPAIGN.MKTG_CHANNEL_NM을 사용합니다.")
    st.write("분석 범위는 전체 기간 또는 시작일·종료일 직접 선택 방식입니다.")
    st.write(
        "활동률·납입률은 CRM_MEMBER_DEV의 직접 비율 컬럼 후보를 자동 탐색합니다. "
        "미확인으로 표시되면 실제 컬럼명 또는 계산식 확인이 필요합니다."
    )
