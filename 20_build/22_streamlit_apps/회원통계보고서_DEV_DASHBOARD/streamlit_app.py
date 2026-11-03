# 실적부서별 개발건 대시보드 (목표 대비 달성율 포함)
# Co-authored with CoCo
import os
import streamlit as st
import pandas as pd
import altair as alt
import streamlit.components.v1 as stc

st.set_page_config(page_title="실적부서별 개발건 대시보드", layout="wide")

st.markdown('<style>td.center-pct{text-align:center !important;} .vega-bindings{display:none !important;}</style>', unsafe_allow_html=True)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

NAMED_DEPTS = [
    "매체운영팀",
    "마케팅기획1팀",
    "마케팅기획2팀",
    "컬쳐콘텐츠팀",
    "회원참여팀",
    "캠페인기획2팀(가두)",
    "사회공헌협력팀",
]

DVLP_TYPE_MAP = {"1": "신규", "2": "증액", "4": "재후원"}

# 당월/누계 목표(건) — DB에서 동적 로드
_TEAM_MAP = {
    "매체운영팀": ("본부", "매체운영팀"),
    "마케팅기획1팀": ("본부", "마케팅기획1팀"),
    "마케팅기획2팀": ("본부", "마케팅기획2팀"),
    "컬쳐콘텐츠팀": ("본부", "컬쳐콘텐츠팀"),
    "회원참여팀": ("본부", "회원참여팀"),
    "캠페인기획2팀(가두)": ("대면", "캠페인기획2팀"),
    "사회공헌협력팀": None,
    "시도본부 및 지부": ("지부", None),
}


@st.cache_data(ttl=600)
def _load_goal_from_db(year):
    sql = f"""
    SELECT "TEAM_NM", "ORG_DIV_NM",
           ROUND(SUM("M01_GOAL_CNT"),0)::INTEGER AS M01, ROUND(SUM("M02_GOAL_CNT"),0)::INTEGER AS M02,
           ROUND(SUM("M03_GOAL_CNT"),0)::INTEGER AS M03, ROUND(SUM("M04_GOAL_CNT"),0)::INTEGER AS M04,
           ROUND(SUM("M05_GOAL_CNT"),0)::INTEGER AS M05, ROUND(SUM("M06_GOAL_CNT"),0)::INTEGER AS M06,
           ROUND(SUM("M07_GOAL_CNT"),0)::INTEGER AS M07, ROUND(SUM("M08_GOAL_CNT"),0)::INTEGER AS M08,
           ROUND(SUM("M09_GOAL_CNT"),0)::INTEGER AS M09, ROUND(SUM("M10_GOAL_CNT"),0)::INTEGER AS M10,
           ROUND(SUM("M11_GOAL_CNT"),0)::INTEGER AS M11, ROUND(SUM("M12_GOAL_CNT"),0)::INTEGER AS M12,
           SUM("M01_GOAL_CNT") AS R01, SUM("M02_GOAL_CNT") AS R02,
           SUM("M03_GOAL_CNT") AS R03, SUM("M04_GOAL_CNT") AS R04,
           SUM("M05_GOAL_CNT") AS R05, SUM("M06_GOAL_CNT") AS R06,
           SUM("M07_GOAL_CNT") AS R07, SUM("M08_GOAL_CNT") AS R08,
           SUM("M09_GOAL_CNT") AS R09, SUM("M10_GOAL_CNT") AS R10,
           SUM("M11_GOAL_CNT") AS R11, SUM("M12_GOAL_CNT") AS R12
    FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
    WHERE "BDGT_PRCD_NM"='연사업' AND "GOAL_TYPE_NM"='후원사업' AND "CPR_DIV_NM"='사단'
      AND "YEAR"='{year}'
    GROUP BY "TEAM_NM", "ORG_DIV_NM"
    """
    return conn.query(sql)


def _build_targets(year, month):
    goal_df = _load_goal_from_db(year)
    monthly_target = {}
    ytd_target = {}
    mcol = f"M{month:02d}"
    rcol = f"R{month:02d}"
    r_ytd_cols = [f"R{m:02d}" for m in range(1, month + 1)]
    for dept, mapping in _TEAM_MAP.items():
        if mapping is None:
            monthly_target[dept] = 0
            ytd_target[dept] = 0
            continue
        org_div, team_nm = mapping
        if team_nm is None:
            mask = goal_df["ORG_DIV_NM"] == org_div
        else:
            mask = (goal_df["ORG_DIV_NM"] == org_div) & (goal_df["TEAM_NM"] == team_nm)
        rows = goal_df[mask]
        if rows.empty:
            monthly_target[dept] = 0
            ytd_target[dept] = 0
        else:
            # 원본 합산 후 round (여러 팀 합산 시 반올림 오차 방지)
            monthly_target[dept] = round(float(rows[rcol].sum()))
            ytd_target[dept] = round(float(rows[r_ytd_cols].sum().sum()))
    return monthly_target, ytd_target

# 허수회원 제외 목록 (2025년): 고액후원 신청 후 미납 또는 직원테스트
# (회원번호, 기준월) 쌍으로 해당 월 기록만 제외
EXCLUDED_MEMBERS_2025 = [
    ("1846164", 202503),   # 고액허수회원 (매체운영팀, 신규/신규, 개발건 599)
    ("1860931", 202504),   # 직원테스트 (매체운영팀, 신규/신규, 개발건 4)
    ("1860972", 202504),   # 직원테스트 (매체운영팀, 신규/신규, 개발건 2)
    ("1721918", 202510),   # 고액허수회원 (매체운영팀, 기존/증액, 개발건 2,952)
    ("1945685", 202512),   # 고액허수회원 (매체운영팀, 신규/신규, 개발건 10)
    ("1894701", 202512),   # 고액허수회원 (회원참여팀, 신규/재후원, 개발건 480)
]


@st.cache_data(ttl=600)

def load_active_v2(year, month, by_setle=False):

    """MSTR_ODS 원천 기반 활동/중단 재현 쿼리 (Snowflake 변환)"""

    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if year == 2025 else []
    exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""

    month_start = f"{year}-{month:02d}-01"

    import calendar

    last_day = calendar.monthrange(year, month)[1]

    month_end = f"{year}-{month:02d}-{last_day:02d}"

    month_31 = f"{strd_mt}31"

    setle_cutoff_str = f"'{month_end}'::DATE + INTERVAL '2 DAY'"



    sql = f"""

    WITH

    -- 1. 상세 실적부서 → 본부/지부(DEPT4) 매핑

    DEPT_MAP AS (

        SELECT E.DEPT_ID AS SRC_DEPT_ID, B.DEPT_ID AS DEPT4_ID

        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A

        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID

        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID

        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID

        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO E ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID

        WHERE A.UPPER_DEPT_ID = 'ZV000000' AND C.DEPT_ID <> 'ZC000029'

    ),

    -- 본부/지부 차원

    DEPT4_DIM AS (

        SELECT B.DEPT_ID AS DEPT4_ID, B.DEPT_NM AS DEPT4_NM, B.SORT_ORDR

        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A

        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID

        WHERE A.UPPER_DEPT_ID = 'ZV000000' AND A.USE_YN = 'Y'

        UNION ALL

        SELECT 'Z~', '없음', 999

    ),

    -- 후원사업별 법인 변환

    BUSINESS_DIM AS (

        SELECT SPNSR_BSNS_ID,

               CASE WHEN CPR_DIV_CD = '1' THEN 'I' WHEN CPR_DIV_CD = '2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD

        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO

    ),

    -- 2. 기준월 회원상태 스냅샷

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

    -- 3. 기준월 결제정보 (최신 1건)

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

    -- 4. 후원번호+후원사업번호별 기준월 납입액

    PAY_MONTH AS (

        SELECT SPNSR_NO, SPNSR_BSNS_NO,

               SUM(CASE WHEN TO_CHAR(PAY_DE, 'YYYYMM') = '{strd_mt}' THEN PAY_AMT ELSE 0 END) AS PAY_AMT

        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT

        WHERE USE_YN = 'Y' AND PRCS_STAT_CD = 'S' AND PAY_STAT_CD = 'S'

          AND MBRFEE_DIV_CD = 'E' AND RETUN_MBRFEE_KEY IS NULL

          AND PAY_DE <= '{month_end}'::DATE

        GROUP BY SPNSR_NO, SPNSR_BSNS_NO

    ),

    -- 5. 기준월 활동회원 목록

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

    -- 6. 활동 팩트: 후원번호+후원사업별 월말 잔액

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

            CASE

                WHEN LEFT(TO_CHAR(M.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{year}'

                 AND LEFT(TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{year}'

                THEN '1' ELSE '2'

            END AS NEW_OLD_DIV_CD,

            COALESCE(MAP.DEPT4_ID, 'Z~') AS DEPT4_ID,

            COALESCE(ST.CPR_DIV_CD, 'I') AS CPR_DIV_CD,

            ST.SETLE_CD::VARCHAR AS SETLE_CD,

            B.CPR_DIV_CD AS BIZ_CPR_DIV_CD,

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

    ),

    -- 7. 중단 팩트: 개발구분 5의 월 합계

    DSCNTC_SOURCE AS (

        SELECT LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,

               A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.ACMSLT_DEPT_CD, A.SPNSR_BSNS_ID,

               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.MBER_NO, A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)) AS MAMT,

               ROW_NUMBER() OVER (PARTITION BY A.MBER_NO, A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6) ORDER BY A.SER_NO DESC) AS SNUM

        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A

        JOIN (SELECT DISTINCT MBER_NO, SPNSR_DSCNTC_DE FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC) D

            ON A.MBER_NO = D.MBER_NO AND A.OCCRRNC_DE = D.SPNSR_DSCNTC_DE

        WHERE A.DVLP_DIV_CD = '5' AND LEFT(A.OCCRRNC_DE, 6) = '{strd_mt}'

    ),

    DSCNTC_FACT AS (

        SELECT D.MBER_NO,

               CASE

                   WHEN LEFT(TO_CHAR(M.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{year}'

                    AND LEFT(TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD'), 4) = '{year}'

                   THEN '1' ELSE '2'

               END AS NEW_OLD_DIV_CD,

               COALESCE(MAP.DEPT4_ID, 'Z~') AS DEPT4_ID,

               B.CPR_DIV_CD,

               D.MAMT / 10000.0 AS SPNSR_AMT_CNT

        FROM DSCNTC_SOURCE D

        JOIN MEMBER_MONTH M ON D.MBER_NO = M.MBER_NO

        JOIN BUSINESS_DIM B ON D.SPNSR_BSNS_ID = B.SPNSR_BSNS_ID

        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON D.MBER_NO = S.MBER_NO AND D.SPNSR_NO = S.SPNSR_NO

        LEFT JOIN DEPT_MAP MAP ON COALESCE(D.ACMSLT_DEPT_CD, 'Z~') = MAP.SRC_DEPT_ID

        WHERE D.SNUM = 1

    ),

    -- 8. 활동 집계

    ACTIVE_AGG AS (

        SELECT NEW_OLD_DIV_CD, DEPT4_ID, CPR_DIV_CD,

               COUNT(DISTINCT MBER_NO) AS WJXBFS1,

               SUM(SPNSR_AMT_CNT) AS WJXBFS2,

               SUM(CASE WHEN NPY_YN = 'N' THEN PAY_AMT ELSE NULL END) AS WJXBFS3

        FROM ACTIVE_FACT

        GROUP BY NEW_OLD_DIV_CD, DEPT4_ID, CPR_DIV_CD

    ),

    DSCNTC_AGG AS (

        SELECT NEW_OLD_DIV_CD, DEPT4_ID, CPR_DIV_CD,

               SUM(ABS(SPNSR_AMT_CNT)) AS WJXBFS1

        FROM DSCNTC_FACT

        GROUP BY NEW_OLD_DIV_CD, DEPT4_ID, CPR_DIV_CD

    )

    -- 9. 최종 결과

    SELECT

        COALESCE(A.NEW_OLD_DIV_CD, D.NEW_OLD_DIV_CD) AS NEW_OLD_DIV_CD,

        CASE COALESCE(A.NEW_OLD_DIV_CD, D.NEW_OLD_DIV_CD)

            WHEN '1' THEN '신규회원' WHEN '2' THEN '기존회원' ELSE '없음'

        END AS NEW_OLD_DIV_NM,

        COALESCE(A.DEPT4_ID, D.DEPT4_ID) AS DEPT4_ID,

        D4.DEPT4_NM,

        D4.SORT_ORDR,

        COALESCE(A.WJXBFS1, 0) AS WJXBFS1,

        COALESCE(A.WJXBFS2, 0) AS WJXBFS2,

        COALESCE(A.WJXBFS3, 0) AS WJXBFS3,

        COALESCE(D.WJXBFS1, 0) AS WJXBFS4

    FROM ACTIVE_AGG A

    FULL OUTER JOIN DSCNTC_AGG D

        ON A.CPR_DIV_CD = D.CPR_DIV_CD AND A.DEPT4_ID = D.DEPT4_ID AND A.NEW_OLD_DIV_CD = D.NEW_OLD_DIV_CD

    LEFT JOIN DEPT4_DIM D4 ON COALESCE(A.DEPT4_ID, D.DEPT4_ID) = D4.DEPT4_ID

    WHERE COALESCE(A.CPR_DIV_CD, D.CPR_DIV_CD) = 'I'

    ORDER BY D4.SORT_ORDR, COALESCE(A.NEW_OLD_DIV_CD, D.NEW_OLD_DIV_CD)

    """
    if by_setle:
        # 납입방식별 활동: MSTR 마감 로직(R3_STRICT_CURRENT_FIRST) 재현
        #  1) 다음 달 시작 전 등록된 결제행만 후보 (현재+이력 UNION)
        #  2) 회원+법인별 SETLE_KEY 최대, 동일 키는 현재행 우선
        #  3) 선택행이 기준월 이후 수정됐으면 동일 키의 최초 이력 → 회원+법인 최초 이력 순으로 복원
        #  4) 결제정보 없으면 '4'(회비통장)
        next_month_start = f"DATEADD(MONTH, 1, '{month_start}'::DATE)"
        r3 = f"""
        SETLE_R3_SOURCE AS (
            SELECT 1 AS SETLE_DIV_CD, SETLE_KEY, MBER_NO, CPR_DIV_CD, SETLE_CD::VARCHAR AS SETLE_CD, LAST_UPDT_DT AS UPDT_DT
            FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE FRST_REGIST_DT < {next_month_start}
            UNION ALL
            SELECT 2, SETLE_KEY, MBER_NO, CPR_DIV_CD, SETLE_CD::VARCHAR, UPDT_DT
            FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST WHERE REGIST_DT < {next_month_start}
        ),
        SETLE_R3_RANKED AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC, SETLE_DIV_CD ASC) AS RNUM
            FROM SETLE_R3_SOURCE
        ),
        SETLE_R3_AFTER_KEY AS (
            SELECT MBER_NO, CPR_DIV_CD, SETLE_KEY, SETLE_CD::VARCHAR AS SETLE_CD,
                   ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD, SETLE_KEY ORDER BY UPDT_DT ASC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST WHERE UPDT_DT >= {next_month_start}
        ),
        SETLE_R3_AFTER_MBR AS (
            SELECT MBER_NO, CPR_DIV_CD, SETLE_CD::VARCHAR AS SETLE_CD,
                   ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY UPDT_DT ASC, SETLE_KEY ASC) AS RNUM
            FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST WHERE UPDT_DT >= {next_month_start}
        ),
        SETLE_R3 AS (
            SELECT S.MBER_NO, S.CPR_DIV_CD,
                   CASE WHEN S.UPDT_DT >= {next_month_start} THEN COALESCE(K.SETLE_CD, H.SETLE_CD, S.SETLE_CD) ELSE S.SETLE_CD END AS SETLE_CD
            FROM SETLE_R3_RANKED S
            LEFT JOIN SETLE_R3_AFTER_KEY K ON K.MBER_NO = S.MBER_NO AND K.CPR_DIV_CD = S.CPR_DIV_CD AND K.SETLE_KEY = S.SETLE_KEY AND K.RNUM = 1
            LEFT JOIN SETLE_R3_AFTER_MBR H ON H.MBER_NO = S.MBER_NO AND H.CPR_DIV_CD = S.CPR_DIV_CD AND H.RNUM = 1
            WHERE S.RNUM = 1
        ),
        """
        cut = sql.index("-- 7. 중단 팩트")
        sql = sql[:cut].rstrip().rstrip(",") + ",\n" + r3 + """
        R3_FACT AS (
            SELECT F.MBER_NO, F.SPNSR_AMT_CNT, COALESCE(R.SETLE_CD, '4') AS SETLE_CD
            FROM ACTIVE_FACT F
            LEFT JOIN SETLE_R3 R ON R.MBER_NO = F.MBER_NO AND R.CPR_DIV_CD = F.BIZ_CPR_DIV_CD
            WHERE F.BIZ_CPR_DIV_CD = 'I'
        )
        SELECT SETLE_CD, COUNT(DISTINCT MBER_NO) AS ACT_MEM, SUM(SPNSR_AMT_CNT) AS ACT_CNT
        FROM R3_FACT
        WHERE SETLE_CD IN ('1', '2', '5', '12', '8', '4')
        GROUP BY SETLE_CD
        """
    return conn.query(sql)


@st.cache_data(ttl=600)
def load_data(year):
    year_start = f"{year}0101"
    year_end = f"{year}1231"
    sql = f"""
    WITH new_rejoin_base AS (
        SELECT
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            SUM(A.SPNSR_AMT) OVER (
                PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)
            ) AS MAMT,
            A.SPNSR_NO, A.SPNSR_BSNS_NO, A.OCCRRNC_DE, A.SER_NO,
            A.MBER_NO, A.ACMSLT_DEPT_CD, A.SPNSR_BSNS_ID,
            A.SPNSR_AMT, A.DVLP_DIV_CD, A.MBER_DIV_CD, A.CMPGN_CD, A.AGE AS AGE_CD, A.SETLE_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B
            ON A.SPNSR_NO = B.SPNSR_NO AND A.SPNSR_BSNS_NO = B.SPNSR_BSNS_NO
            AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231')
                > LEFT(A.OCCRRNC_DE, 6) || '31'
        WHERE A.OCCRRNC_DE BETWEEN '{year_start}' AND '{year_end}'
          AND A.DVLP_DIV_CD IN ('1', '4')
    ),
    new_rejoin AS (
        SELECT STRD_MT, SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO,
               MBER_NO, COALESCE(ACMSLT_DEPT_CD, 'Z~') AS DEPT_ID,
               SPNSR_BSNS_ID, DVLP_DIV_CD, SPNSR_AMT, MBER_DIV_CD, CMPGN_CD, AGE_CD, SETLE_CD
        FROM new_rejoin_base
        WHERE MAMT > 0
    ),
    change_base AS (
        SELECT
            LEFT(A.OCCRRNC_DE, 6) AS STRD_MT,
            SUM(CASE WHEN A.DVLP_DIV_CD IN ('2','3') THEN A.SPNSR_AMT ELSE 0 END)
                OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO, LEFT(A.OCCRRNC_DE, 6)) AS SAMT,
            SUM(A.SPNSR_AMT)
                OVER (PARTITION BY A.MBER_NO, LEFT(A.OCCRRNC_DE, 6)) AS MAMT,
            A.SPNSR_NO, A.SPNSR_BSNS_NO, A.OCCRRNC_DE, A.SER_NO,
            A.MBER_NO, A.ACMSLT_DEPT_CD, A.SPNSR_BSNS_ID,
            A.SPNSR_AMT, A.DVLP_DIV_CD, A.MBER_DIV_CD, A.CMPGN_CD, A.AGE AS AGE_CD, A.SETLE_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        WHERE A.OCCRRNC_DE BETWEEN '{year_start}' AND '{year_end}'
          AND A.DVLP_DIV_CD IN ('2', '3', '5')
    ),
    change_member AS (
        SELECT
            SUM(CASE WHEN C.DVLP_DIV_CD = '3' THEN C.SPNSR_AMT ELSE 0 END)
                OVER (PARTITION BY C.MBER_NO, C.STRD_MT) AS DAMT,
            C.*
        FROM change_base C
        WHERE C.MAMT > 0
          AND ((C.SAMT > 0 AND C.DVLP_DIV_CD = '2') OR (C.SAMT < 0 AND C.DVLP_DIV_CD = '3'))
    ),
    change_running AS (
        SELECT
            SUM(C.SAMT) OVER (
                PARTITION BY C.MBER_NO, C.STRD_MT ORDER BY C.OCCRRNC_DE, C.SER_NO
            ) AS AAMT,
            C.*
        FROM change_member C
        WHERE C.DVLP_DIV_CD = '2'
    ),
    change_alloc AS (
        SELECT
            ROW_NUMBER() OVER (
                PARTITION BY C.STRD_MT, C.SPNSR_NO, C.SPNSR_BSNS_NO ORDER BY C.SER_NO
            ) AS RNUM,
            CASE
                WHEN C.MAMT <= C.SAMT AND C.AAMT + C.DAMT <= C.MAMT THEN C.AAMT + C.DAMT
                WHEN C.MAMT > C.SAMT AND C.AAMT + C.DAMT <= C.SAMT THEN C.AAMT + C.DAMT
                WHEN C.MAMT <= C.SAMT THEN C.MAMT
                ELSE C.SAMT
            END AS RAMT,
            C.*
        FROM change_running C
        WHERE C.AAMT - ABS(C.DAMT) > 0
    ),
    increase AS (
        SELECT STRD_MT, SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO,
               MBER_NO, COALESCE(ACMSLT_DEPT_CD, 'Z~') AS DEPT_ID,
               SPNSR_BSNS_ID, '2' AS DVLP_DIV_CD, RAMT AS SPNSR_AMT,
               MBER_DIV_CD, CMPGN_CD, AGE_CD, SETLE_CD
        FROM change_alloc
        WHERE RNUM = 1
    ),
    transformed AS (
        SELECT * FROM new_rejoin
        UNION ALL
        SELECT * FROM increase
    ),
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    dvlp_fact AS (
        SELECT
            T.STRD_MT,
            T.OCCRRNC_DE,
            D.DEPT_NM AS DEPT_NAME,
            T.DVLP_DIV_CD AS DVLP_TYPE,
            T.MBER_NO,
            T.MBER_DIV_CD AS MBER_DIV,
            T.SPNSR_AMT,
            COALESCE(BIZ.CPR_DIV_CD, '0') AS CPR_DIV_CD,
            BIZ.SPNSR_BSNS_NM AS BIZ_NAME,
            C.CMPGN_NM AS CAMPAIGN_NAME,
            UC.CMPGN_NM AS UPPER_CAMPAIGN,
            COALESCE(BRND_LK.CMMN_BRND_NM, SB.CMMN_BRND_NM,
                CASE WHEN C.CMPGN_NM LIKE '%재송출%' THEN '재송출'
                     WHEN C.CMPGN_NM LIKE '%본방송%' OR C.CMPGN_NM LIKE '%재방송%' THEN '방송'
                     WHEN C.CMPGN_NM LIKE '%HP%' OR C.CMPGN_NM LIKE '%APP%' OR C.CMPGN_NM LIKE '%QR%' THEN '디지털'
                     WHEN C.CMPGN_NM LIKE '%콜%인바운드%' THEN '마케팅콜개발'
                     WHEN C.CMPGN_NM LIKE '%YOUTUBE%' OR C.CMPGN_NM LIKE '%TIKTOK%' OR C.CMPGN_NM LIKE '%SNS%' THEN '디지털'
                     ELSE '디지털' END
            ) AS BRAND_NAME,
            SC_CTGR.CMPGN_CTGR_NM AS CAMPAIGN_CATEGORY,
            MKTG_CD.DTL_CD_NM AS MKTG_CMPGN_NM,
            T.CMPGN_CD,
            T.SETLE_CD,
            CASE T.AGE_CD WHEN 1 THEN '10대이하' WHEN 2 THEN '10대' WHEN 3 THEN '20대' WHEN 4 THEN '30대'
                 WHEN 5 THEN '40대' WHEN 6 THEN '50대' WHEN 7 THEN '60대이상' WHEN 8 THEN '60대이상' WHEN 9 THEN '60대이상'
                 WHEN 10 THEN '기타' WHEN 11 THEN '기타' WHEN 12 THEN '기타' ELSE '기타' END AS AGE_BAND
        FROM transformed T
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D ON T.DEPT_ID = D.DEPT_ID
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO BIZ ON T.SPNSR_BSNS_ID = BIZ.SPNSR_BSNS_ID
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG C ON C.CMPGN_CD = T.CMPGN_CD
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG UC ON UC.CMPGN_CD = C.UPPER_CMPGN_CD
        LEFT JOIN brnd_lookup BRND_LK ON BRND_LK.CMMN_BRND = C.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD = C.UPPER_CMPGN_CD AND SB.RN = 1
        LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN SC_CTGR ON SC_CTGR.CMPGN_CD = C.CMPGN_CD
        LEFT JOIN GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD MKTG_CD ON MKTG_CD.CD_ID = 'C001' AND MKTG_CD.DTL_CD_ID = C.MKTG_CMPGN_NM::VARCHAR
    ),
    first_dev AS (
        SELECT MBER_NO, MIN(OCCRRNC_DE) AS FIRST_DEV_DATE
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
        WHERE DVLP_DIV_CD = '1'
        GROUP BY MBER_NO
    )
    SELECT
        CAST(f.STRD_MT AS INTEGER) AS STRD_MT,
        CAST(f.OCCRRNC_DE AS INTEGER) AS OCCUR_DATE,
        f.DEPT_NAME,
        f.DVLP_TYPE,
        f.MBER_NO,
        f.MBER_DIV,
        f.SPNSR_AMT,
        f.CPR_DIV_CD,
        f.BIZ_NAME,
        f.CAMPAIGN_NAME,
        f.UPPER_CAMPAIGN,
        f.BRAND_NAME,
        f.CAMPAIGN_CATEGORY,
        f.MKTG_CMPGN_NM,
        f.AGE_BAND,
        f.SETLE_CD::VARCHAR AS SETLE_CD,
        CASE WHEN fd.FIRST_DEV_DATE >= '{year_start}' THEN '신규회원' ELSE '기존회원' END AS NEW_EXISTING
    FROM dvlp_fact f
    LEFT JOIN first_dev fd ON f.MBER_NO = fd.MBER_NO
    WHERE f.CPR_DIV_CD = 'I'
    """
    df = conn.query(sql)
    return df


def classify_dept(name):
    if name is None:
        return "시도본부 및 지부"
    if "회원" in name:
        return "회원참여팀"
    if name == "캠페인기획2팀" or name == "소셜펀딩부":
        return "캠페인기획2팀(가두)"
    if name == "사회공헌협력팀" or name == "ESG팀":
        return "사회공헌협력팀"
    if name in ("매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀"):
        return name
    return "시도본부 및 지부"


BIZ_NAME_MAP = {
    "국내아동권리보호사업(사단법인)": "국내아동권리보호사업",
    "결식아동지원": "국내아동권리보호사업",
    "아동학대예방": "국내아동권리보호사업",
    "저소득가정지원": "국내아동권리보호사업",
    "아동복지시설지원": "국내아동권리보호사업",
    "복지관후원": "국내아동권리보호사업",
    "해외아동결연": "해외아동결연",
    "해외교육지원사업": "해외교육지원사업",
    "희망학교지원사업": "희망학교지원사업",
    "식수위생지원사업": "식수위생지원사업",
    "보건의료지원사업": "보건의료지원사업",
    "해외지역개발사업": "해외지역개발사업",
    "재난구호지원사업": "재난구호지원사업",
    "대북지원사업": "대북지원사업",
    "전체사업지원": "전체사업지원",
    "좋은이웃": "좋은이웃후원",
}


def build_summary(df):
    df = df.copy()
    df["부서"] = df["DEPT_NAME"].apply(classify_dept)
    df["개발구분"] = df["DVLP_TYPE"].astype(str).map(DVLP_TYPE_MAP)
    df["회원구분"] = df["NEW_EXISTING"]
    df["개발건"] = df["SPNSR_AMT"].astype(float) / 10000.0
    df["캠페인명"] = df["CAMPAIGN_NAME"].fillna("미분류")
    df["상위캠페인"] = df["UPPER_CAMPAIGN"].fillna("미분류")
    df["브랜드"] = df["BRAND_NAME"].fillna("미분류")
    df["캠페인카테고리"] = df["CAMPAIGN_CATEGORY"].fillna("미분류")
    df["마케팅캠페인명"] = df["MKTG_CMPGN_NM"].fillna("미분류")
    df["연령대"] = df["AGE_BAND"].fillna("기타")
    # 납입방식: 개발 레코드의 결제수단(TM_MM_FDRM_MBER_DVLP_AMT.SETLE_CD) 기준 = 마감값 기준
    _SETLE_NM = {"1": "자동이체", "2": "신용카드", "4": "회비통장", "5": "휴대폰", "8": "OCR", "12": "네이버페이"}
    df["납입방식"] = df["SETLE_CD"].map(lambda x: _SETLE_NM.get(str(x).split(".")[0], "기타") if pd.notna(x) else "미확인")
    df["후원사업"] = df["BIZ_NAME"].map(BIZ_NAME_MAP)
    return df


# 2026년 4월 수정: 1-1/1-2 시도본부 신규 -1, 1-3/1-4 신규회원 본부 신규 +1
ADJ_YEAR = 2026
ADJ_MONTH = 4


def should_apply_adjustment(sel_year, sel_month, is_ytd):
    if sel_year != ADJ_YEAR:
        return False
    if is_ytd:
        return sel_month >= ADJ_MONTH
    else:
        return sel_month == ADJ_MONTH


def apply_adjustment_pivot(df, sel_year, sel_month, is_ytd):
    if not should_apply_adjustment(sel_year, sel_month, is_ytd):
        return df
    df = df.copy()
    # 시도본부 및 지부: 신규 -1, 재후원 +1
    mask_sido = df["부서"] == "시도본부 및 지부"
    if mask_sido.any():
        df.loc[mask_sido, "신규"] += -1
        df.loc[mask_sido, "재후원"] += 1
        df.loc[mask_sido, "합계"] = df.loc[mask_sido, ["신규", "재후원", "증액"]].sum(axis=1)
        target = df.loc[mask_sido, "목표(건)"].values[0]
        if target > 0:
            df.loc[mask_sido, "달성율(%)"] = round(df.loc[mask_sido, "합계"].values[0] / target * 100, 1)
    # 합계: 신규 -1, 재후원 +1
    mask_total = df["부서"] == "합계"
    if mask_total.any():
        df.loc[mask_total, "신규"] += -1
        df.loc[mask_total, "재후원"] += 1
        df.loc[mask_total, "합계"] = df.loc[mask_total, ["신규", "재후원", "증액"]].sum(axis=1)
        target = df.loc[mask_total, "목표(건)"].values[0]
        if target > 0:
            df.loc[mask_total, "달성율(%)"] = round(df.loc[mask_total, "합계"].values[0] / target * 100, 1)
    return df


def apply_adjustment_member(df, sel_year, sel_month, is_ytd):
    if not should_apply_adjustment(sel_year, sel_month, is_ytd):
        return df
    df = df.copy()
    # 신규회원 > 본부: 신규 +1
    mask_hq = (df["신규기존"] == "신규회원") & (df["본부/지부"] == "본부")
    if mask_hq.any():
        df.loc[mask_hq, "신규"] += 1
        df.loc[mask_hq, "합계"] = df.loc[mask_hq, ["신규", "재후원", "증액"]].sum(axis=1)
        target = df.loc[mask_hq, "목표(건)"].values[0]
        if target > 0:
            df.loc[mask_hq, "달성율(%)"] = round(df.loc[mask_hq, "합계"].values[0] / target * 100, 1)
    # 신규회원 > 시도본부 및 지부: 신규 -1
    mask_sido = (df["신규기존"] == "신규회원") & (df["본부/지부"] == "시도본부 및 지부")
    if mask_sido.any():
        df.loc[mask_sido, "신규"] += -1
        df.loc[mask_sido, "합계"] = df.loc[mask_sido, ["신규", "재후원", "증액"]].sum(axis=1)
        target = df.loc[mask_sido, "목표(건)"].values[0]
        if target > 0:
            df.loc[mask_sido, "달성율(%)"] = round(df.loc[mask_sido, "합계"].values[0] / target * 100, 1)
    # 기존회원: 신규 -1, 재후원 +1
    mask_exist = df["본부/지부"] == "기존회원"
    if mask_exist.any():
        df.loc[mask_exist, "신규"] += -1
        df.loc[mask_exist, "재후원"] += 1
        df.loc[mask_exist, "합계"] = df.loc[mask_exist, ["신규", "재후원", "증액"]].sum(axis=1)
        target = df.loc[mask_exist, "목표(건)"].values[0]
        if target > 0:
            df.loc[mask_exist, "달성율(%)"] = round(df.loc[mask_exist, "합계"].values[0] / target * 100, 1)
    # 합계: 신규회원(+1-1=0) + 기존회원(신규-1, 재후원+1) = 신규-1, 재후원+1
    mask_total = df["본부/지부"] == "합계"
    if mask_total.any():
        df.loc[mask_total, "신규"] += -1
        df.loc[mask_total, "재후원"] += 1
        df.loc[mask_total, "합계"] = df.loc[mask_total, ["신규", "재후원", "증액"]].sum(axis=1)
        target = df.loc[mask_total, "목표(건)"].values[0]
        if target > 0:
            df.loc[mask_total, "달성율(%)"] = round(df.loc[mask_total, "합계"].values[0] / target * 100, 1)
    return df


def make_pivot(df, target_map):
    cols = ["본부/지부", "사업부/시도권역", "부서", "목표(건)", "신규", "재후원", "증액", "합계", "달성율(%)"]
    if df.empty:
        return pd.DataFrame(columns=cols)

    pivot = df.groupby(["부서", "개발구분"])["개발건"].sum().reset_index()

    pivot_wide = pivot.pivot_table(
        index="부서", columns="개발구분", values="개발건", aggfunc="sum", fill_value=0
    ).reset_index()

    for col in ["신규", "재후원", "증액"]:
        if col not in pivot_wide.columns:
            pivot_wide[col] = 0

    pivot_wide["합계"] = pivot_wide[["신규", "재후원", "증액"]].sum(axis=1)
    pivot_wide["목표(건)"] = pivot_wide["부서"].map(target_map).fillna(0).astype(int)
    pivot_wide["달성율(%)"] = pivot_wide.apply(
        lambda r: round(r["합계"] / r["목표(건)"] * 100, 1) if r["목표(건)"] > 0 else 0.0, axis=1
    )

    data = pivot_wide.set_index("부서")[["목표(건)", "신규", "재후원", "증액", "합계", "달성율(%)"]].to_dict("index")

    def make_row(hq_type, division, name, row_data=None):
        if row_data:
            return {"본부/지부": hq_type, "사업부/시도권역": division, "부서": name, **row_data}
        target = target_map.get(name, 0)
        return {"본부/지부": hq_type, "사업부/시도권역": division, "부서": name, "목표(건)": target, "신규": 0, "재후원": 0, "증액": 0, "합계": 0, "달성율(%)": 0.0}

    def subtotal_row(name, depts):
        s = {"본부/지부": "", "사업부/시도권역": "", "부서": name}
        s["목표(건)"] = sum(target_map.get(d, 0) for d in depts)
        for c in ["신규", "재후원", "증액", "합계"]:
            s[c] = sum(data.get(d, {}).get(c, 0) for d in depts)
        s["달성율(%)"] = round(s["합계"] / s["목표(건)"] * 100, 1) if s["목표(건)"] > 0 else 0.0
        return s

    rows = []

    # Group 1: 나눔마케팅본부
    group1 = ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀"]
    for dept in group1:
        rows.append(make_row("본부", "나눔마케팅본부", dept, data.get(dept)))
    rows.append(subtotal_row("소계", group1))

    # Group 2: 회원실
    group2 = ["회원참여팀"]
    rows.append(make_row("본부", "회원실", "회원참여팀", data.get("회원참여팀")))
    rows.append(subtotal_row("소계", group2))

    # Group 3: 국내사업본부
    group3 = ["캠페인기획2팀(가두)"]
    rows.append(make_row("본부", "국내사업본부", "캠페인기획2팀(가두)", data.get("캠페인기획2팀(가두)")))
    rows.append(subtotal_row("소계", group3))

    # Group 4: ESG사회공헌협력실
    group4 = ["사회공헌협력팀"]
    rows.append(make_row("본부", "ESG사회공헌협력실", "사회공헌협력팀", data.get("사회공헌협력팀")))
    rows.append(subtotal_row("소계", group4))

    # 본부 소계
    all_hq = group1 + group2 + group3 + group4
    hq_subtotal = subtotal_row("본부 소계", all_hq)
    hq_subtotal["목표(건)"] = sum(target_map.get(d, 0) for d in all_hq)
    hq_subtotal["달성율(%)"] = round(hq_subtotal["합계"] / hq_subtotal["목표(건)"] * 100, 1) if hq_subtotal["목표(건)"] > 0 else 0.0
    rows.append(hq_subtotal)

    # 시도본부 및 지부
    sido_row = make_row("시도본부 및 지부", "시도본부 및 지부", "시도본부 및 지부", data.get("시도본부 및 지부"))
    sido_row["목표(건)"] = target_map.get("시도본부 및 지부", 0)
    if sido_row["합계"] > 0 and sido_row["목표(건)"] > 0:
        sido_row["달성율(%)"] = round(sido_row["합계"] / sido_row["목표(건)"] * 100, 1)
    rows.append(sido_row)

    # 합계 = 본부소계 + 시도본부 및 지부
    total_row = subtotal_row("합계", all_hq + ["시도본부 및 지부"])
    total_row["목표(건)"] = hq_subtotal["목표(건)"] + target_map.get("시도본부 및 지부", 0)
    total_row["달성율(%)"] = round(total_row["합계"] / total_row["목표(건)"] * 100, 1) if total_row["목표(건)"] > 0 else 0.0
    rows.append(total_row)

    result = pd.DataFrame(rows, columns=cols)
    return result


def style_table(df):
    def row_style(row):
        dept = row["부서"]
        division = row["사업부/시도권역"]
        styles = [""] * len(row)
        if dept == "합계":
            styles = ["background-color: #222222; color: white; font-weight: bold"] * len(row)
        elif dept in ("소계", "본부 소계"):
            styles = ["background-color: #d9d9d9; font-weight: bold"] * len(row)
        else:
            target_idx = df.columns.get_loc("목표(건)")
            styles[target_idx] = "background-color: #808000; color: white"
        return styles
    return df.style.apply(row_style, axis=1)


def _build_member_targets(year, month):
    goal_raw = _load_goal_member_from_db(year)
    rcol = f"R{month:02d}"
    r_ytd_cols = [f"R{m:02d}" for m in range(1, month + 1)]

    monthly = {}
    ytd = {}

    # 신규회원_본부 (신규 + 본부/대면) — 원본 합산 후 round
    new_hq = goal_raw[(goal_raw["NEW_OLD_DIV_NM"] == "신규") & goal_raw["ORG_DIV_NM"].isin(["본부", "대면"])]
    monthly["신규회원_본부"] = round(float(new_hq[rcol].sum())) if not new_hq.empty else 0
    ytd["신규회원_본부"] = round(float(new_hq[r_ytd_cols].sum().sum())) if not new_hq.empty else 0

    # 신규회원_시도본부 (신규 + 지부)
    new_sido = goal_raw[(goal_raw["NEW_OLD_DIV_NM"] == "신규") & (goal_raw["ORG_DIV_NM"] == "지부")]
    monthly["신규회원_시도본부"] = round(float(new_sido[rcol].sum())) if not new_sido.empty else 0
    ytd["신규회원_시도본부"] = round(float(new_sido[r_ytd_cols].sum().sum())) if not new_sido.empty else 0

    # 기존회원 (기존 + 전체 본부/지부/대면)
    old_all = goal_raw[goal_raw["NEW_OLD_DIV_NM"] == "기존"]
    monthly["기존회원"] = round(float(old_all[rcol].sum())) if not old_all.empty else 0
    ytd["기존회원"] = round(float(old_all[r_ytd_cols].sum().sum())) if not old_all.empty else 0

    return monthly, ytd


@st.cache_data(ttl=600)
def _load_goal_member_from_db(year):
    sql = f"""
    SELECT "NEW_OLD_DIV_NM", "ORG_DIV_NM",
           ROUND(SUM("M01_GOAL_CNT"),0)::INTEGER AS M01, ROUND(SUM("M02_GOAL_CNT"),0)::INTEGER AS M02,
           ROUND(SUM("M03_GOAL_CNT"),0)::INTEGER AS M03, ROUND(SUM("M04_GOAL_CNT"),0)::INTEGER AS M04,
           ROUND(SUM("M05_GOAL_CNT"),0)::INTEGER AS M05, ROUND(SUM("M06_GOAL_CNT"),0)::INTEGER AS M06,
           ROUND(SUM("M07_GOAL_CNT"),0)::INTEGER AS M07, ROUND(SUM("M08_GOAL_CNT"),0)::INTEGER AS M08,
           ROUND(SUM("M09_GOAL_CNT"),0)::INTEGER AS M09, ROUND(SUM("M10_GOAL_CNT"),0)::INTEGER AS M10,
           ROUND(SUM("M11_GOAL_CNT"),0)::INTEGER AS M11, ROUND(SUM("M12_GOAL_CNT"),0)::INTEGER AS M12,
           SUM("M01_GOAL_CNT") AS R01, SUM("M02_GOAL_CNT") AS R02,
           SUM("M03_GOAL_CNT") AS R03, SUM("M04_GOAL_CNT") AS R04,
           SUM("M05_GOAL_CNT") AS R05, SUM("M06_GOAL_CNT") AS R06,
           SUM("M07_GOAL_CNT") AS R07, SUM("M08_GOAL_CNT") AS R08,
           SUM("M09_GOAL_CNT") AS R09, SUM("M10_GOAL_CNT") AS R10,
           SUM("M11_GOAL_CNT") AS R11, SUM("M12_GOAL_CNT") AS R12
    FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
    WHERE "BDGT_PRCD_NM"='연사업' AND "GOAL_TYPE_NM"='후원사업' AND "CPR_DIV_NM"='사단'
      AND "YEAR"='{year}'
    GROUP BY "NEW_OLD_DIV_NM", "ORG_DIV_NM"
    """
    return conn.query(sql)


def make_member_type_pivot(df, target_map):
    cols = ["신규기존", "본부/지부", "목표(건)", "신규", "재후원", "증액", "합계", "달성율(%)"]
    if df.empty:
        return pd.DataFrame(columns=cols)

    df = df.copy()
    df["본부지부"] = df["부서"].apply(lambda x: "시도본부 및 지부" if x == "시도본부 및 지부" else "본부")

    rows = []

    df_new = df[df["회원구분"] == "신규회원"]

    new_hq = df_new[df_new["본부지부"] == "본부"]
    new_hq_counts = {"신규": 0.0, "재후원": 0.0, "증액": 0.0}
    for t in ["신규", "재후원", "증액"]:
        new_hq_counts[t] = new_hq[new_hq["개발구분"] == t]["개발건"].sum()
    new_hq_total = sum(new_hq_counts.values())
    hq_target = target_map.get("신규회원_본부", 0)
    rows.append({
        "신규기존": "신규회원", "본부/지부": "본부", "목표(건)": hq_target,
        **new_hq_counts, "합계": new_hq_total,
        "달성율(%)": round(new_hq_total / hq_target * 100, 1) if hq_target > 0 else 0.0
    })

    new_sido = df_new[df_new["본부지부"] == "시도본부 및 지부"]
    new_sido_counts = {"신규": 0.0, "재후원": 0.0, "증액": 0.0}
    for t in ["신규", "재후원", "증액"]:
        new_sido_counts[t] = new_sido[new_sido["개발구분"] == t]["개발건"].sum()
    new_sido_total = sum(new_sido_counts.values())
    sido_target = target_map.get("신규회원_시도본부", 0)
    rows.append({
        "신규기존": "신규회원", "본부/지부": "시도본부 및 지부", "목표(건)": sido_target,
        **new_sido_counts, "합계": new_sido_total,
        "달성율(%)": round(new_sido_total / sido_target * 100, 1) if sido_target > 0 else 0.0
    })

    new_target = hq_target + sido_target
    new_total = new_hq_total + new_sido_total
    rows.append({
        "신규기존": "", "본부/지부": "신규회원 소계", "목표(건)": new_target,
        "신규": new_hq_counts["신규"] + new_sido_counts["신규"],
        "재후원": new_hq_counts["재후원"] + new_sido_counts["재후원"],
        "증액": new_hq_counts["증액"] + new_sido_counts["증액"],
        "합계": new_total,
        "달성율(%)": round(new_total / new_target * 100, 1) if new_target > 0 else 0.0
    })

    df_exist = df[df["회원구분"] == "기존회원"]
    exist_counts = {"신규": 0.0, "재후원": 0.0, "증액": 0.0}
    for t in ["신규", "재후원", "증액"]:
        exist_counts[t] = df_exist[df_exist["개발구분"] == t]["개발건"].sum()
    exist_total = sum(exist_counts.values())
    exist_target = target_map.get("기존회원", 0)
    rows.append({
        "신규기존": "기존회원", "본부/지부": "기존회원", "목표(건)": exist_target,
        **exist_counts, "합계": exist_total,
        "달성율(%)": round(exist_total / exist_target * 100, 1) if exist_target > 0 else 0.0
    })

    grand_total = new_total + exist_total
    grand_target = new_target + exist_target
    rows.append({
        "신규기존": "", "본부/지부": "합계", "목표(건)": grand_target,
        "신규": new_hq_counts["신규"] + new_sido_counts["신규"] + exist_counts["신규"],
        "재후원": new_hq_counts["재후원"] + new_sido_counts["재후원"] + exist_counts["재후원"],
        "증액": new_hq_counts["증액"] + new_sido_counts["증액"] + exist_counts["증액"],
        "합계": grand_total,
        "달성율(%)": round(grand_total / grand_target * 100, 1) if grand_target > 0 else 0.0
    })

    return pd.DataFrame(rows, columns=cols)


def style_member_table(df):
    def row_style(row):
        label = row["본부/지부"]
        styles = [""] * len(row)
        if label == "합계":
            styles = ["background-color: #222222; color: white; font-weight: bold"] * len(row)
        elif label in ("소계", "신규회원 소계"):
            styles = ["background-color: #d9d9d9; font-weight: bold"] * len(row)
        else:
            target_idx = df.columns.get_loc("목표(건)")
            styles[target_idx] = "background-color: #808000; color: white"
        return styles
    return df.style.apply(row_style, axis=1)

# =====================================================
# 데이터 로더 (탭 내부에서 상단으로 이동 — 사전 병렬 조회용)
# =====================================================

@st.cache_data(ttl=600)
def _load_setle_for_popup():
    sql = """
    WITH SETLE_LATEST AS (
        SELECT MBER_NO, SETLE_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SETLE_KEY DESC) AS RN
        FROM (
            SELECT SETLE_KEY, MBER_NO, SETLE_CD FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
            UNION ALL
            SELECT SETLE_KEY, MBER_NO, SETLE_CD FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
        )
    )
    SELECT MBER_NO,
           CASE SETLE_CD::VARCHAR
               WHEN '1' THEN '자동이체'
               WHEN '2' THEN '신용카드'
               WHEN '4' THEN '회비통장'
               WHEN '5' THEN '휴대폰'
               WHEN '8' THEN 'OCR'
               WHEN '12' THEN '네이버페이'
               ELSE '기타' END AS SETLE_NM
    FROM SETLE_LATEST WHERE RN = 1
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_active_campaign_popup(year, month):
    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if year == 2025 else []
    exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""
    month_start = f"{year}-{month:02d}-01"
    import calendar as _cal_acp
    last_day = _cal_acp.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
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
        SELECT B.DEPT_ID AS DEPT4_ID, B.DEPT_NM AS DEPT4_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
        WHERE A.UPPER_DEPT_ID = 'ZV000000' AND A.USE_YN = 'Y'
        UNION ALL SELECT 'Z~', '없음'
    ),
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID, SPNSR_BSNS_NM,
               CASE WHEN CPR_DIV_CD='1' THEN 'I' WHEN CPR_DIV_CD='2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT, 'YYYYMM') = '{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE WHEN H.CHN_STAT_CD IS NULL THEN
                   CASE WHEN M.MBER_STAT_CD::VARCHAR='12' THEN '1'
                        WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                            CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                        ELSE M.MBER_STAT_CD::VARCHAR END
               WHEN H.CHN_STAT_CD::VARCHAR='12' THEN '1' ELSE H.CHN_STAT_CD::VARCHAR END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO=H.MBER_NO AND H.RNUM=1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO=X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT,'YYYYMM')<='{strd_mt}'
    ),
    SETLE_UNION AS (
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, FRST_REGIST_DT FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
        UNION ALL
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, REGIST_DT FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
    ),
    SETLE_MONTH AS (
        SELECT MBER_NO, CPR_DIV_CD FROM (
            SELECT MBER_NO, CPR_DIV_CD, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM
            FROM SETLE_UNION WHERE FRST_REGIST_DT<=DATEADD(DAY,1,DATEADD(MONTH,1,'{month_start}'::DATE))
        ) WHERE RNUM=1
    ),
    LAST_DSCNTC AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE<='{month_31}'
    ),
    LAST_RE_SPNSR AS (
        SELECT MBER_NO, RE_SPNSR_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE<='{month_31}'
    ),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE>R.RE_SPNSR_DE THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE<TO_CHAR('{month_end}'::DATE,'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE,'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO=R.MBER_NO AND R.RNUM=1 WHERE D.RNUM=1
    ),
    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT S.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD')<='{month_31}'
          AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE,''),'99991231')>'{month_31}'
    ),
    ACTIVE_MEMBER AS (
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO=L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO=A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT,'9999-12-31'::DATE) {exclude_clause}
    ),
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID, A.CMPGN_CD,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A WHERE A.OCCRRNC_DE<='{month_31}'
    ),
    ACTIVE_FACT AS (
        SELECT A.MBER_NO,
               CASE WHEN LEFT(TO_CHAR(MM.FRST_REGIST_DT,'YYYYMMDD'),4)='{year}'
                     AND LEFT(TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD'),4)='{year}' THEN '신규회원' ELSE '기존회원' END AS NEW_OLD,
               CASE WHEN D4.DEPT4_NM IN ('본부','본부(사복)') THEN '본부' ELSE '시도본부 및 지부' END AS HQ_DIV,
               BD.SPNSR_BSNS_NM AS BIZ_NAME,
               COALESCE(BL.CMMN_BRND_NM, SB.CMMN_BRND_NM, '기타') AS CMMN_BRND_NM,
               COALESCE(MK.DTL_CD_NM,'미분류') AS MKTG_CMPGN_NM,
               A.SUM_AMT/10000.0 AS SPNSR_AMT_CNT
        FROM ACTIVE_HISTORY A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO=AM.MBER_NO
        JOIN MEMBER_MONTH MM ON A.MBER_NO=MM.MBER_NO
        JOIN BUSINESS_DIM BD ON A.SPNSR_BSNS_ID=BD.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON A.MBER_NO=S.MBER_NO AND A.SPNSR_NO=S.SPNSR_NO
        LEFT JOIN SETLE_MONTH ST ON A.MBER_NO=ST.MBER_NO AND BD.CPR_DIV_CD=ST.CPR_DIV_CD
        LEFT JOIN DEPT_MAP MAP ON COALESCE(S.ACMSLT_DEPT_CD,'Z~')=MAP.SRC_DEPT_ID
        LEFT JOIN DEPT4_DIM D4 ON COALESCE(MAP.DEPT4_ID,'Z~')=D4.DEPT4_ID
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG C ON C.CMPGN_CD=A.CMPGN_CD
        LEFT JOIN brnd_lookup BL ON BL.CMMN_BRND=C.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD=C.UPPER_CMPGN_CD AND SB.RN=1
        LEFT JOIN GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD MK ON MK.CD_ID='C001' AND MK.DTL_CD_ID=C.MKTG_CMPGN_NM::VARCHAR
        WHERE A.RNUM=1 AND A.SUM_AMT>0 AND COALESCE(ST.CPR_DIV_CD,'I')='I'
    )
    SELECT NEW_OLD, HQ_DIV, BIZ_NAME, CMMN_BRND_NM, MKTG_CMPGN_NM,
           COUNT(DISTINCT MBER_NO) AS ACT_MEMBERS,
           SUM(SPNSR_AMT_CNT) AS ACT_CASES
    FROM ACTIVE_FACT
    GROUP BY NEW_OLD, HQ_DIV, BIZ_NAME, CMMN_BRND_NM, MKTG_CMPGN_NM
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_active_target(year):
    sql = f"""
    SELECT "NEW_OLD_DIV_NM", "ORG_DIV_NM",
           ROUND(SUM("M01_GOAL_CNT"),0)::INTEGER AS M01, ROUND(SUM("M02_GOAL_CNT"),0)::INTEGER AS M02,
           ROUND(SUM("M03_GOAL_CNT"),0)::INTEGER AS M03, ROUND(SUM("M04_GOAL_CNT"),0)::INTEGER AS M04,
           ROUND(SUM("M05_GOAL_CNT"),0)::INTEGER AS M05, ROUND(SUM("M06_GOAL_CNT"),0)::INTEGER AS M06,
           ROUND(SUM("M07_GOAL_CNT"),0)::INTEGER AS M07, ROUND(SUM("M08_GOAL_CNT"),0)::INTEGER AS M08,
           ROUND(SUM("M09_GOAL_CNT"),0)::INTEGER AS M09, ROUND(SUM("M10_GOAL_CNT"),0)::INTEGER AS M10,
           ROUND(SUM("M11_GOAL_CNT"),0)::INTEGER AS M11, ROUND(SUM("M12_GOAL_CNT"),0)::INTEGER AS M12,
           SUM("M01_GOAL_CNT") AS R01, SUM("M02_GOAL_CNT") AS R02,
           SUM("M03_GOAL_CNT") AS R03, SUM("M04_GOAL_CNT") AS R04,
           SUM("M05_GOAL_CNT") AS R05, SUM("M06_GOAL_CNT") AS R06,
           SUM("M07_GOAL_CNT") AS R07, SUM("M08_GOAL_CNT") AS R08,
           SUM("M09_GOAL_CNT") AS R09, SUM("M10_GOAL_CNT") AS R10,
           SUM("M11_GOAL_CNT") AS R11, SUM("M12_GOAL_CNT") AS R12
    FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
    WHERE "BDGT_PRCD_NM"='연사업' AND "GOAL_TYPE_NM"='월말활동회원' AND "CPR_DIV_NM"='사단'
      AND "YEAR"='{year}'
    GROUP BY "NEW_OLD_DIV_NM", "ORG_DIV_NM"
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_activity_rate_target(year):
    sql = f"""
    SELECT "NEW_OLD_DIV_NM", "ORG_DIV_NM",
           "M01_GOAL_CNT" AS M01, "M02_GOAL_CNT" AS M02,
           "M03_GOAL_CNT" AS M03, "M04_GOAL_CNT" AS M04,
           "M05_GOAL_CNT" AS M05, "M06_GOAL_CNT" AS M06,
           "M07_GOAL_CNT" AS M07, "M08_GOAL_CNT" AS M08,
           "M09_GOAL_CNT" AS M09, "M10_GOAL_CNT" AS M10,
           "M11_GOAL_CNT" AS M11, "M12_GOAL_CNT" AS M12
    FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
    WHERE "BDGT_PRCD_NM"='연사업' AND "GOAL_TYPE_NM"='신규기존활동율' AND "CPR_DIV_NM"='사단'
      AND "YEAR"='{year}'
    ORDER BY "NEW_OLD_DIV_NM", "ORG_DIV_NM"
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_biz_active_target(year):
    sql = f"""
    SELECT "SPNSR_BSNS_DIV_NM",
           ROUND(SUM("M01_GOAL_CNT"),0)::INTEGER AS M01, ROUND(SUM("M02_GOAL_CNT"),0)::INTEGER AS M02,
           ROUND(SUM("M03_GOAL_CNT"),0)::INTEGER AS M03, ROUND(SUM("M04_GOAL_CNT"),0)::INTEGER AS M04,
           ROUND(SUM("M05_GOAL_CNT"),0)::INTEGER AS M05, ROUND(SUM("M06_GOAL_CNT"),0)::INTEGER AS M06,
           ROUND(SUM("M07_GOAL_CNT"),0)::INTEGER AS M07, ROUND(SUM("M08_GOAL_CNT"),0)::INTEGER AS M08,
           ROUND(SUM("M09_GOAL_CNT"),0)::INTEGER AS M09, ROUND(SUM("M10_GOAL_CNT"),0)::INTEGER AS M10,
           ROUND(SUM("M11_GOAL_CNT"),0)::INTEGER AS M11, ROUND(SUM("M12_GOAL_CNT"),0)::INTEGER AS M12,
           SUM("M01_GOAL_CNT") AS R01, SUM("M02_GOAL_CNT") AS R02,
           SUM("M03_GOAL_CNT") AS R03, SUM("M04_GOAL_CNT") AS R04,
           SUM("M05_GOAL_CNT") AS R05, SUM("M06_GOAL_CNT") AS R06,
           SUM("M07_GOAL_CNT") AS R07, SUM("M08_GOAL_CNT") AS R08,
           SUM("M09_GOAL_CNT") AS R09, SUM("M10_GOAL_CNT") AS R10,
           SUM("M11_GOAL_CNT") AS R11, SUM("M12_GOAL_CNT") AS R12
    FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
    WHERE "BDGT_PRCD_NM"='연사업' AND "GOAL_TYPE_NM"='월말활동회원' AND "CPR_DIV_NM"='사단'
      AND "YEAR"='{year}'
    GROUP BY "SPNSR_BSNS_DIV_NM"
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def load_active_by_biz(year, month):
    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if year == 2025 else []
    exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""
    month_start = f"{year}-{month:02d}-01"
    import calendar as cal
    last_day = cal.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
    sql = f"""
    WITH
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID, SPNSR_BSNS_NM,
               CASE WHEN CPR_DIV_CD = '1' THEN 'I' WHEN CPR_DIV_CD = '2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT, 'YYYYMM') = '{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE
                   WHEN H.CHN_STAT_CD IS NULL THEN
                       CASE WHEN M.MBER_STAT_CD::VARCHAR = '12' THEN '1'
                            WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                                CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                            ELSE M.MBER_STAT_CD::VARCHAR END
                   WHEN H.CHN_STAT_CD::VARCHAR = '12' THEN '1'
                   ELSE H.CHN_STAT_CD::VARCHAR
               END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO = H.MBER_NO AND H.RNUM = 1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO = X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT, 'YYYYMM') <= '{strd_mt}'
    ),
    LAST_DSCNTC AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE <= '{month_31}'
    ),
    LAST_RE_SPNSR AS (
        SELECT MBER_NO, RE_SPNSR_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE <= '{month_31}'
    ),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE > R.RE_SPNSR_DE THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE < TO_CHAR('{month_end}'::DATE, 'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE, 'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO = R.MBER_NO AND R.RNUM = 1
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
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO = L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO = A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT, '9999-12-31'::DATE)
          {exclude_clause}
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A WHERE A.OCCRRNC_DE <= '{month_31}'
    ),
    SETLE_UNION AS (
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, FRST_REGIST_DT
        FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
        UNION ALL
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, REGIST_DT AS FRST_REGIST_DT
        FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
    ),
    SETLE_MONTH AS (
        SELECT MBER_NO, CPR_DIV_CD
        FROM (
            SELECT MBER_NO, CPR_DIV_CD,
                   ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM
            FROM SETLE_UNION
            WHERE FRST_REGIST_DT <= DATEADD(DAY, 1, DATEADD(MONTH, 1, '{month_start}'::DATE))
        ) WHERE RNUM = 1
    ),
    ACTIVE_FACT AS (
        SELECT A.MBER_NO, BD.SPNSR_BSNS_NM, A.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT
        FROM ACTIVE_HISTORY A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO = AM.MBER_NO
        JOIN MEMBER_MONTH M ON A.MBER_NO = M.MBER_NO
        JOIN BUSINESS_DIM BD ON A.SPNSR_BSNS_ID = BD.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON A.MBER_NO = S.MBER_NO AND A.SPNSR_NO = S.SPNSR_NO
        LEFT JOIN SETLE_MONTH ST ON A.MBER_NO = ST.MBER_NO AND BD.CPR_DIV_CD = ST.CPR_DIV_CD
        WHERE A.RNUM = 1 AND A.SUM_AMT > 0
          AND COALESCE(ST.CPR_DIV_CD, 'I') = 'I'
    )
    SELECT SPNSR_BSNS_NM AS BIZ_NAME,
           COUNT(DISTINCT MBER_NO) AS ACTIVE_MEMBERS,
           SUM(SPNSR_AMT_CNT) AS ACTIVE_CASES
    FROM ACTIVE_FACT
    GROUP BY SPNSR_BSNS_NM
    ORDER BY SPNSR_BSNS_NM
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def load_active_by_brand(year, month):
    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if year == 2025 else []
    exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""
    month_start = f"{year}-{month:02d}-01"
    import calendar as _cal2
    last_day = _cal2.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
    sql = f"""
    WITH
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID,
               CASE WHEN CPR_DIV_CD = '1' THEN 'I' WHEN CPR_DIV_CD = '2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    CAMPAIGN_BRAND AS (
        SELECT CMPGN_CD, COALESCE(MAX(BRND_ID::VARCHAR), 'Z~') AS BRND_ID
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG
        GROUP BY CMPGN_CD
    ),
    BRAND_DIM AS (
        SELECT BRND_ID::VARCHAR AS BRND_ID, MAX(BRND_NM) AS BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_BRND_MNG
        GROUP BY BRND_ID::VARCHAR
    ),
    MBER_STAT_DIM AS (
        SELECT DTL_CD_ID AS MBER_STAT_CD, MAX(DTL_CD_NM) AS MBER_STAT_NM, MAX(SORT_ORDR) AS SORT_ORDR
        FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD
        WHERE CD_ID = 'MM010'
        GROUP BY DTL_CD_ID
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT, 'YYYYMM') = '{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE
                   WHEN H.CHN_STAT_CD IS NULL THEN
                       CASE WHEN M.MBER_STAT_CD::VARCHAR = '12' THEN '1'
                            WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                                CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                            ELSE M.MBER_STAT_CD::VARCHAR END
                   WHEN H.CHN_STAT_CD::VARCHAR = '12' THEN '1'
                   ELSE H.CHN_STAT_CD::VARCHAR
               END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO = H.MBER_NO AND H.RNUM = 1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO = X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT, 'YYYYMM') <= '{strd_mt}'
    ),
    LAST_DSCNTC AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE <= '{month_31}'
    ),
    LAST_RE_SPNSR AS (
        SELECT MBER_NO, RE_SPNSR_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE <= '{month_31}'
    ),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE > R.RE_SPNSR_DE THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE < TO_CHAR('{month_end}'::DATE, 'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE, 'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO = R.MBER_NO AND R.RNUM = 1
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
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO = L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO = A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT, '9999-12-31'::DATE)
          {exclude_clause}
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO = AM.MBER_NO
        WHERE A.OCCRRNC_DE <= '{month_31}'
    ),
    ACTIVE_FACT AS (
        SELECT
            AC.MBER_NO,
            COALESCE(CB.BRND_ID, 'Z~') AS BRND_ID,
            MM.MBER_STAT_CD,
            AC.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT
        FROM ACTIVE_HISTORY AC
        JOIN MEMBER_MONTH MM ON AC.MBER_NO = MM.MBER_NO
        JOIN BUSINESS_DIM BS ON AC.SPNSR_BSNS_ID = BS.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR SM
            ON AC.MBER_NO = SM.MBER_NO AND AC.SPNSR_NO = SM.SPNSR_NO
        LEFT JOIN CAMPAIGN_BRAND CB ON SM.CMPGN_CD = CB.CMPGN_CD
        WHERE AC.RNUM = 1 AND AC.SUM_AMT > 0 AND BS.CPR_DIV_CD = 'I'
    )
    SELECT
        COALESCE(BD.BRND_NM, '없음') AS BRND_NM,
        AF.BRND_ID,
        COALESCE(MD.MBER_STAT_NM, '없음') AS MBER_STAT_NM,
        AF.MBER_STAT_CD,
        COALESCE(MD.SORT_ORDR, 999) AS SORT_ORDR,
        SUM(AF.SPNSR_AMT_CNT) AS WJXBFS1
    FROM ACTIVE_FACT AF
    LEFT JOIN BRAND_DIM BD ON AF.BRND_ID = BD.BRND_ID
    LEFT JOIN MBER_STAT_DIM MD ON AF.MBER_STAT_CD = MD.MBER_STAT_CD
    GROUP BY AF.BRND_ID, BD.BRND_NM, AF.MBER_STAT_CD, MD.MBER_STAT_NM, MD.SORT_ORDR
    ORDER BY AF.BRND_ID, MD.SORT_ORDR
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def load_active_by_common_brand(year, month):
    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if year == 2025 else []
    exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""
    month_start = f"{year}-{month:02d}-01"
    import calendar as _cal3
    last_day = _cal3.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
    sql = f"""
    WITH
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID,
               CASE WHEN CPR_DIV_CD = '1' THEN 'I' WHEN CPR_DIV_CD = '2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT, 'YYYYMM') = '{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE
                   WHEN H.CHN_STAT_CD IS NULL THEN
                       CASE WHEN M.MBER_STAT_CD::VARCHAR = '12' THEN '1'
                            WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                                CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                            ELSE M.MBER_STAT_CD::VARCHAR END
                   WHEN H.CHN_STAT_CD::VARCHAR = '12' THEN '1'
                   ELSE H.CHN_STAT_CD::VARCHAR END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO = H.MBER_NO AND H.RNUM = 1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO = X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT, 'YYYYMM') <= '{strd_mt}'
    ),
    LAST_DSCNTC AS (SELECT MBER_NO, SPNSR_DSCNTC_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE <= '{month_31}'),
    LAST_RE_SPNSR AS (SELECT MBER_NO, RE_SPNSR_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE <= '{month_31}'),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE > R.RE_SPNSR_DE THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE < TO_CHAR('{month_end}'::DATE, 'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE, 'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO = R.MBER_NO AND R.RNUM = 1
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
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO = L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO = A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT, '9999-12-31'::DATE)
          {exclude_clause}
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO = AM.MBER_NO
        WHERE A.OCCRRNC_DE <= '{month_31}'
    ),
    SETLE_UNION AS (SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, FRST_REGIST_DT FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO UNION ALL SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, REGIST_DT FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST),
    SETLE_MONTH AS (SELECT MBER_NO, CPR_DIV_CD FROM (SELECT MBER_NO, CPR_DIV_CD, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM FROM SETLE_UNION WHERE FRST_REGIST_DT <= DATEADD(DAY, 1, DATEADD(MONTH, 1, '{month_start}'::DATE))) WHERE RNUM = 1),
    ACTIVE_FACT AS (
        SELECT
            AC.MBER_NO,
            COALESCE(BL.CMMN_BRND_NM, SB.CMMN_BRND_NM, '기타') AS CMMN_BRND_NM,
            MM.MBER_STAT_CD,
            AC.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT
        FROM ACTIVE_HISTORY AC
        JOIN MEMBER_MONTH MM ON AC.MBER_NO = MM.MBER_NO
        JOIN BUSINESS_DIM BS ON AC.SPNSR_BSNS_ID = BS.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR SM
            ON AC.MBER_NO = SM.MBER_NO AND AC.SPNSR_NO = SM.SPNSR_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG CM ON SM.CMPGN_CD = CM.CMPGN_CD
        LEFT JOIN brnd_lookup BL ON BL.CMMN_BRND = CM.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD = CM.UPPER_CMPGN_CD AND SB.RN = 1
        WHERE AC.RNUM = 1 AND AC.SUM_AMT > 0 AND BS.CPR_DIV_CD = 'I'
    )
    SELECT CMMN_BRND_NM, MBER_STAT_CD, SUM(SPNSR_AMT_CNT) AS WJXBFS1
    FROM ACTIVE_FACT
    GROUP BY CMMN_BRND_NM, MBER_STAT_CD
    ORDER BY CMMN_BRND_NM, MBER_STAT_CD
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def load_active_brand_detail(year, month):
    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if year == 2025 else []
    exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""
    month_start = f"{year}-{month:02d}-01"
    import calendar as _cal4
    last_day = _cal4.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
    sql = f"""
    WITH
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID,
               CASE WHEN CPR_DIV_CD = '1' THEN 'I' WHEN CPR_DIV_CD = '2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT, 'YYYYMM') = '{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE
                   WHEN H.CHN_STAT_CD IS NULL THEN
                       CASE WHEN M.MBER_STAT_CD::VARCHAR = '12' THEN '1'
                            WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                                CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                            ELSE M.MBER_STAT_CD::VARCHAR END
                   WHEN H.CHN_STAT_CD::VARCHAR = '12' THEN '1'
                   ELSE H.CHN_STAT_CD::VARCHAR END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO = H.MBER_NO AND H.RNUM = 1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO = X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT, 'YYYYMM') <= '{strd_mt}'
    ),
    LAST_DSCNTC AS (SELECT MBER_NO, SPNSR_DSCNTC_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE <= '{month_31}'),
    LAST_RE_SPNSR AS (SELECT MBER_NO, RE_SPNSR_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE <= '{month_31}'),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE > R.RE_SPNSR_DE THEN DATEADD(DAY, -1, TO_DATE(D.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE < TO_CHAR('{month_end}'::DATE, 'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE, 'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO = R.MBER_NO AND R.RNUM = 1 WHERE D.RNUM = 1
    ),
    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT S.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO = B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT, 'YYYYMMDD') <= '{month_31}'
          AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE, ''), '99991231') > '{month_31}'
    ),
    ACTIVE_MEMBER AS (
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO = L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO = A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT, '9999-12-31'::DATE)
          {exclude_clause}
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO = AM.MBER_NO
        WHERE A.OCCRRNC_DE <= '{month_31}'
    ),
    SETLE_UNION AS (SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, FRST_REGIST_DT FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO UNION ALL SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, REGIST_DT FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST),
    SETLE_MONTH AS (SELECT MBER_NO, CPR_DIV_CD FROM (SELECT MBER_NO, CPR_DIV_CD, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM FROM SETLE_UNION WHERE FRST_REGIST_DT <= DATEADD(DAY, 1, DATEADD(MONTH, 1, '{month_start}'::DATE))) WHERE RNUM = 1),
    ACTIVE_FACT AS (
        SELECT
            AC.MBER_NO,
            COALESCE(BL.CMMN_BRND_NM, SB.CMMN_BRND_NM, '기타') AS CMMN_BRND_NM,
            CASE WHEN MM.MBER_STAT_CD::VARCHAR = '1' THEN '활동회원'
                 WHEN MM.MBER_STAT_CD::VARCHAR IN ('2','3','4','5','6') THEN '신규미납'
                 WHEN MM.MBER_STAT_CD::VARCHAR IN ('7','8','9','10','11') THEN '장기미납'
                 ELSE '기타' END AS STAT_GROUP,
            COALESCE(SC.CMPGN_CTGR_NM, '미분류') AS CMPGN_CTGR_NM,
            COALESCE(MK.DTL_CD_NM, '미분류') AS MKTG_CMPGN_NM,
            COALESCE(CM.CMPGN_NM, '미분류') AS CMPGN_NM,
            CASE WHEN LEFT(TO_CHAR(SM.FRST_REGIST_DT,'YYYY'),4)='{year}' THEN '{year}'
                 WHEN LEFT(TO_CHAR(SM.FRST_REGIST_DT,'YYYY'),4)='{year-1}' THEN '{year-1}'
                 WHEN LEFT(TO_CHAR(SM.FRST_REGIST_DT,'YYYY'),4)='{year-2}' THEN '{year-2}'
                 ELSE 'prev' END AS JOIN_YR,
            AC.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT,
            MM.MBER_STAT_CD::VARCHAR AS MBER_STAT_CD
        FROM ACTIVE_HISTORY AC
        JOIN MEMBER_MONTH MM ON AC.MBER_NO = MM.MBER_NO
        JOIN BUSINESS_DIM BS ON AC.SPNSR_BSNS_ID = BS.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR SM ON AC.MBER_NO = SM.MBER_NO AND AC.SPNSR_NO = SM.SPNSR_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG CM ON SM.CMPGN_CD = CM.CMPGN_CD
        LEFT JOIN brnd_lookup BL ON BL.CMMN_BRND = CM.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD = CM.UPPER_CMPGN_CD AND SB.RN = 1
        LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN SC ON SC.CMPGN_CD = CM.CMPGN_CD
        LEFT JOIN GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD MK ON MK.CD_ID = 'C001' AND MK.DTL_CD_ID = CM.MKTG_CMPGN_NM::VARCHAR
        WHERE AC.RNUM = 1 AND AC.SUM_AMT > 0 AND BS.CPR_DIV_CD = 'I'
    )
    SELECT CMMN_BRND_NM, STAT_GROUP, CMPGN_CTGR_NM, MKTG_CMPGN_NM, CMPGN_NM, JOIN_YR, MBER_NO, MBER_STAT_CD, SUM(SPNSR_AMT_CNT) AS AMT
    FROM ACTIVE_FACT
    GROUP BY CMMN_BRND_NM, STAT_GROUP, CMPGN_CTGR_NM, MKTG_CMPGN_NM, CMPGN_NM, JOIN_YR, MBER_NO, MBER_STAT_CD
    ORDER BY CMMN_BRND_NM, CMPGN_CTGR_NM, MKTG_CMPGN_NM, CMPGN_NM, STAT_GROUP, JOIN_YR
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_setle_for_activity():
    _sql = """
    WITH SETLE_LATEST AS (
        SELECT MBER_NO, SETLE_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SETLE_KEY DESC) AS RN
        FROM (
            SELECT SETLE_KEY, MBER_NO, SETLE_CD FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
            UNION ALL
            SELECT SETLE_KEY, MBER_NO, SETLE_CD FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
        )
    )
    SELECT MBER_NO,
           CASE SETLE_CD::VARCHAR
               WHEN '1' THEN '자동이체' WHEN '2' THEN '신용카드' WHEN '4' THEN '회비통장'
               WHEN '5' THEN '휴대폰' WHEN '8' THEN 'OCR' WHEN '12' THEN '네이버페이'
               ELSE '기타' END AS SETLE_NM
    FROM SETLE_LATEST WHERE RN = 1
    """
    return conn.query(_sql)

# ── 회비 납입 선택 규칙 (3-1·3-2·3-3 공통) ──
# 참고: MSTR_ODS 신규기존 및 후원사업별 회비 SQL(2026-10-21) — 기본 MONTH_PROCESS "당월 처리분 + 이후 환급/이관 원회비 복원"
#  · PAY_DE로 납입월 결정. 일반 회비는 OPERT_DE <= 익월 1일이면 포함(이전 작업일 제한 없음, NULL·익월 2일 이후 작업 → 제외)
#    (2026-10-21 사용자 확인: 원 SQL의 '같은 월' 조건 대신 이 경계 사용 → 202609 마감값과 구분별 일치)
#  · 복원: USE_YN=N 양수 원회비(OPERT_DE >= 해당 월 1일) + 회비키로 연결된 상대 전부가 익월 1일 이후·Y·S/S·금액 일치
#    (환급=음수 / 이관=양수·같은 납입월, 공유 상대키·환급/이관 혼재·부분환급은 복원하지 않음)
#  · 복원된 원회비와 연결된 상대 회비는 같은 납입월에서 제외(이관 전/후 동시 합산 금지)
#  · 연결 판단은 전 법인, 사단(I) 등 보고서 범위는 각 표 쿼리에서 적용
#  · 제외 회원(0000066)은 모든 월의 활동·납입에서 제외
#  · EVENT_ASOF(이전 비교용): 일반 회비 작업월 무제한 + 마감 이후 사건 보정 + 원회비 Y 유지 이관 상대 제외 규칙
#  · 이전 9월 대사 금액은 새 기준의 기대값이 아님 (예: PAY_DE 9/30·OPERT_DE 10/1 정상 회비는 새 기준에서 제외)
FEE_PAYMENT_POLICY = "MONTH_PROCESS"  # MONTH_PROCESS(기본) / EVENT_ASOF(이전 비교용) / CURRENT(현재 ODS 조건, 복원 없음)
FEE_CLOSING_EXTRA_DAYS = 0          # 0 = 익월 1일 배타 경계. 실제 마감일이 확인된 경우에만 변경
FEE_CHECK_REVERSE_LINKS = True      # 정방향+역방향 연결 조회 (False면 자동 복원하지 않음)
FEE_EXCLUDED_MEMBER_NO = "0000066"  # 사용자 확인 DW 제외 회원 (금액 차감 보정이 아님)

def _fee_selected_pay_ctes(year, month_end, month_start=None):
    """납입 선택 CTE 묶음 (WITH/쉼표 없이 반환). 마지막 CTE SELECTED_PAY(MBRFEE_KEY)를 원천 회비와 조인해 사용.
    범위: month_start(기본 기준연도 1월 1일) ~ month_end. 각 납입월은 자신의 마감 경계로 따로 판정."""
    if FEE_PAYMENT_POLICY not in ("MONTH_PROCESS", "EVENT_ASOF", "CURRENT"):
        raise ValueError("납입 정책은 MONTH_PROCESS / EVENT_ASOF / CURRENT입니다.")
    if FEE_PAYMENT_POLICY == "MONTH_PROCESS" and FEE_CLOSING_EXTRA_DAYS != 0:
        raise ValueError("당월 처리 기준의 마감 추가일은 0이어야 합니다.")
    range_start = month_start or f"{year}-01-01"
    # adj: 환급/이관 원회비 복원 사용 여부 / asof: 이전 비교 모드 / mproc: 당월 처리 기준
    adj = "TRUE" if FEE_PAYMENT_POLICY in ("MONTH_PROCESS", "EVENT_ASOF") else "FALSE"
    asof = "TRUE" if FEE_PAYMENT_POLICY == "EVENT_ASOF" else "FALSE"
    mproc = "TRUE" if FEE_PAYMENT_POLICY == "MONTH_PROCESS" else "FALSE"
    rev = "TRUE" if FEE_CHECK_REVERSE_LINKS else "FALSE"
    excl = FEE_EXCLUDED_MEMBER_NO
    src = "GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT"
    link_cols = ("Q.MBRFEE_KEY AS REL_KEY, Q.OPERT_DE AS REL_OPERT_DE, Q.PAY_DE AS REL_PAY_DE, "
                 "Q.PAY_AMT::DECIMAL(38,4) AS REL_AMT, Q.USE_YN AS REL_USE_YN, "
                 "Q.PRCS_STAT_CD AS REL_PRCS, Q.PAY_STAT_CD AS REL_PAYST")
    reverse_links = f"""
        UNION ALL
        SELECT C.MBRFEE_KEY, 'REFUND', {link_cols}
        FROM FEE_ADJ_CAND C JOIN {src} Q ON Q.RETUN_MBRFEE_KEY = C.MBRFEE_KEY WHERE Q.MBRFEE_KEY <> C.MBRFEE_KEY
        UNION ALL
        SELECT C.MBRFEE_KEY, 'TRANSFER', {link_cols}
        FROM FEE_ADJ_CAND C JOIN {src} Q ON Q.TRNSFER_MBRFEE_KEY = C.MBRFEE_KEY WHERE Q.MBRFEE_KEY <> C.MBRFEE_KEY""" if FEE_CHECK_REVERSE_LINKS else ""
    return f"""
    FEE_PAY_RAW AS (
        -- 연결 판단은 전 법인 (원회비가 조회 법인 밖이어도 이관 상대를 찾기 위함)
        SELECT P.MBRFEE_KEY, P.MBER_NO, P.PAY_DE, P.PAY_AMT::DECIMAL(38,4) AS PAY_AMT, P.USE_YN, P.OPERT_DE,
               P.RETUN_REQUST_KEY, P.RETUN_MBRFEE_KEY, P.TRNSFER_REQUST_KEY, P.TRNSFER_MBRFEE_KEY,
               DATE_TRUNC('MONTH', P.PAY_DE) AS MONTH_START,
               DATEADD(DAY, {int(FEE_CLOSING_EXTRA_DAYS)}, DATEADD(MONTH, 1, DATE_TRUNC('MONTH', P.PAY_DE))) AS CUTOFF_EXCL,
               (P.USE_YN = 'Y' AND P.RETUN_REQUST_KEY IS NULL
                AND COALESCE(P.MBER_NO::VARCHAR, '') <> '{excl}') AS CURRENT_RULE_INCLUDE
        FROM {src} P
        WHERE P.PAY_DE >= '{range_start}'::DATE AND P.PAY_DE <= '{month_end}'::DATE
          AND P.PRCS_STAT_CD = 'S' AND P.PAY_STAT_CD = 'S'
    ),
    -- 복원 후보: USE_YN=N 양수 원거래만 (음수 환급행 자체는 복원하지 않음)
    FEE_ADJ_CAND AS (
        SELECT * FROM FEE_PAY_RAW WHERE {adj} AND USE_YN = 'N' AND PAY_AMT > 0
    ),
    -- 회비키 연결: 정방향(원거래 → 상대) + 역방향(상대 → 원거래). 요청번호/회원/금액만 같은 행은 연결로 보지 않음
    FEE_LINK_RAW AS (
        SELECT C.MBRFEE_KEY AS ORIG_KEY, 'REFUND' AS LINK_TYPE, {link_cols}
        FROM FEE_ADJ_CAND C JOIN {src} Q ON Q.MBRFEE_KEY = C.RETUN_MBRFEE_KEY WHERE Q.MBRFEE_KEY <> C.MBRFEE_KEY
        UNION ALL
        SELECT C.MBRFEE_KEY, 'TRANSFER', {link_cols}
        FROM FEE_ADJ_CAND C JOIN {src} Q ON Q.MBRFEE_KEY = C.TRNSFER_MBRFEE_KEY WHERE Q.MBRFEE_KEY <> C.MBRFEE_KEY{reverse_links}
    ),
    -- 양방향 같은 연결은 관계 1개로 정리 (납입행 중복 제거가 아님)
    FEE_LINK_EDGE AS (
        SELECT DISTINCT ORIG_KEY, LINK_TYPE, REL_KEY, REL_OPERT_DE, REL_PAY_DE, REL_AMT, REL_USE_YN, REL_PRCS, REL_PAYST
        FROM FEE_LINK_RAW
    ),
    -- 상대 회비 1행이 여러 원거래와 연결되면 자동 복원하지 않음
    FEE_REL_OWNERS AS (
        SELECT LINK_TYPE, REL_KEY, COUNT(*) AS OWNER_CNT FROM FEE_LINK_EDGE GROUP BY LINK_TYPE, REL_KEY
    ),
    FEE_LINK_EVID AS (
        SELECT E.ORIG_KEY, E.LINK_TYPE, COUNT(*) AS REL_CNT, SUM(ABS(E.REL_AMT)) AS REL_ABS_AMT,
               SUM(CASE WHEN E.REL_OPERT_DE >= C.CUTOFF_EXCL AND E.REL_PRCS = 'S' AND E.REL_PAYST = 'S'
                         AND E.REL_USE_YN = 'Y' AND O.OWNER_CNT = 1
                         AND ((E.LINK_TYPE = 'REFUND' AND E.REL_AMT < 0)
                           OR (E.LINK_TYPE = 'TRANSFER' AND E.REL_AMT > 0 AND DATE_TRUNC('MONTH', E.REL_PAY_DE) = C.MONTH_START))
                        THEN 1 ELSE 0 END) AS VALID_CNT
        FROM FEE_LINK_EDGE E
        JOIN FEE_ADJ_CAND C ON E.ORIG_KEY = C.MBRFEE_KEY
        JOIN FEE_REL_OWNERS O ON E.LINK_TYPE = O.LINK_TYPE AND E.REL_KEY = O.REL_KEY
        GROUP BY E.ORIG_KEY, E.LINK_TYPE
    ),
    FEE_PAY_FLAGS AS (
        SELECT P.*,
               (P.RETUN_REQUST_KEY IS NOT NULL OR P.RETUN_MBRFEE_KEY IS NOT NULL OR R.REL_CNT IS NOT NULL) AS HAS_REFUND,
               (P.TRNSFER_REQUST_KEY IS NOT NULL OR P.TRNSFER_MBRFEE_KEY IS NOT NULL OR T.REL_CNT IS NOT NULL) AS HAS_TRANSFER,
               COALESCE(R.REL_CNT > 0 AND R.REL_CNT = R.VALID_CNT AND R.REL_ABS_AMT = P.PAY_AMT, FALSE) AS CAN_RESTORE_REFUND,
               COALESCE(T.REL_CNT > 0 AND T.REL_CNT = T.VALID_CNT AND T.REL_ABS_AMT = P.PAY_AMT, FALSE) AS CAN_RESTORE_TRANSFER
        FROM FEE_PAY_RAW P
        LEFT JOIN FEE_LINK_EVID R ON P.MBRFEE_KEY = R.ORIG_KEY AND R.LINK_TYPE = 'REFUND'
        LEFT JOIN FEE_LINK_EVID T ON P.MBRFEE_KEY = T.ORIG_KEY AND T.LINK_TYPE = 'TRANSFER'
    ),
    -- 원회비 복원 판정: MONTH_PROCESS는 원회비 OPERT_DE >= 해당 월 1일(이후 월 변경 포함), EVENT_ASOF는 OPERT_DE < 마감
    --  원회비 OPERT_DE가 해당 월 이전이거나 NULL이면 자동 복원하지 않음
    FEE_PAY_EVID AS (
        SELECT F.*,
            CASE
                WHEN {adj} AND {rev} AND F.USE_YN = 'N' AND F.PAY_AMT > 0
                     AND (({asof} AND F.OPERT_DE < F.CUTOFF_EXCL) OR ({mproc} AND F.OPERT_DE >= F.MONTH_START))
                     AND F.HAS_REFUND AND NOT F.HAS_TRANSFER AND F.CAN_RESTORE_REFUND
                    THEN 'RESTORE_ORIGINAL_AFTER_REFUND'
                WHEN {adj} AND {rev} AND F.USE_YN = 'N' AND F.PAY_AMT > 0
                     AND (({asof} AND F.OPERT_DE < F.CUTOFF_EXCL) OR ({mproc} AND F.OPERT_DE >= F.MONTH_START))
                     AND F.HAS_TRANSFER AND NOT F.HAS_REFUND AND F.CAN_RESTORE_TRANSFER
                    THEN 'RESTORE_ORIGINAL_AFTER_TRANSFER'
            END AS RESTORE_REASON
        FROM FEE_PAY_FLAGS F
    ),
    -- 복원과 제외를 한 쌍으로: 복원 원회비와 연결된 마감 이후 상대는 같은 납입월에서 제외
    FEE_ROLLBACK_TARGET AS (
        SELECT R.MONTH_START, E.REL_KEY, MIN(E.LINK_TYPE) AS LINK_TYPE
        FROM FEE_PAY_EVID R
        JOIN FEE_LINK_EDGE E ON R.MBRFEE_KEY = E.ORIG_KEY
        WHERE (R.RESTORE_REASON = 'RESTORE_ORIGINAL_AFTER_REFUND' AND E.LINK_TYPE = 'REFUND')
           OR (R.RESTORE_REASON = 'RESTORE_ORIGINAL_AFTER_TRANSFER' AND E.LINK_TYPE = 'TRANSFER')
        GROUP BY R.MONTH_START, E.REL_KEY
    ),
    -- 추가 규칙(EVENT_ASOF 전용): 원회비가 Y로 남은 채 마감 이후 이관 상대(Y)가 생성된 경우 → 상대 회비 제외(이중 집계 방지)
    --  MONTH_PROCESS에서는 해당 상대가 다음 달 작업이라 EXCLUDE_LATE_NO_VERIFIED_EVENT로 제외됨
    --  상대: Y·양수·S/S·작업일 >= 마감 / 원회비: 회비키 1:1 연결·Y·S/S·작업일 < 마감 / 같은 납입월·같은 금액
    FEE_TIN_EDGE AS (
        SELECT T.MBRFEE_KEY AS T_KEY, O.MBRFEE_KEY AS O_KEY, O.PAY_AMT::DECIMAL(38,4) AS O_AMT, O.PAY_DE AS O_PAY_DE,
               O.OPERT_DE AS O_OPERT, O.USE_YN AS O_USE, O.PRCS_STAT_CD AS O_PRCS, O.PAY_STAT_CD AS O_PAYST
        FROM FEE_PAY_RAW T JOIN {src} O ON O.MBRFEE_KEY = T.TRNSFER_MBRFEE_KEY AND O.MBRFEE_KEY <> T.MBRFEE_KEY
        UNION
        SELECT T.MBRFEE_KEY, O.MBRFEE_KEY, O.PAY_AMT::DECIMAL(38,4), O.PAY_DE, O.OPERT_DE, O.USE_YN, O.PRCS_STAT_CD, O.PAY_STAT_CD
        FROM FEE_PAY_RAW T JOIN {src} O ON O.TRNSFER_MBRFEE_KEY = T.MBRFEE_KEY AND O.MBRFEE_KEY <> T.MBRFEE_KEY
    ),
    FEE_TIN_O_CNT AS (SELECT O_KEY, COUNT(DISTINCT T_KEY) AS N FROM FEE_TIN_EDGE GROUP BY O_KEY),
    FEE_TIN_DUP AS (
        SELECT E.T_KEY FROM FEE_TIN_EDGE E
        JOIN FEE_PAY_RAW T ON T.MBRFEE_KEY = E.T_KEY
        JOIN FEE_TIN_O_CNT C ON C.O_KEY = E.O_KEY
        WHERE {asof} AND T.USE_YN = 'Y' AND T.PAY_AMT > 0 AND T.OPERT_DE >= T.CUTOFF_EXCL
          AND E.O_USE = 'Y' AND E.O_PRCS = 'S' AND E.O_PAYST = 'S' AND E.O_OPERT < T.CUTOFF_EXCL
          AND DATE_TRUNC('MONTH', E.O_PAY_DE) = T.MONTH_START AND E.O_AMT = T.PAY_AMT AND C.N = 1
        GROUP BY E.T_KEY HAVING COUNT(DISTINCT E.O_KEY) = 1
    ),
    -- 판정 순서는 참고 SQL(2026-10-21)과 동일. REVIEW_* 는 미포함
    FEE_PAY_DECISION AS (
        SELECT F.MBRFEE_KEY, F.PAY_DE, F.PAY_AMT, F.CURRENT_RULE_INCLUDE,
            CASE
                WHEN F.MBER_NO::VARCHAR = '{excl}' THEN 'EXCLUDE_EXCEPTION_MEMBER'
                WHEN TD.T_KEY IS NOT NULL THEN 'EXCLUDE_POST_CUTOFF_TRANSFER_ORIGINAL_KEPT'
                WHEN {adj} AND X.REL_KEY IS NOT NULL AND X.LINK_TYPE = 'TRANSFER' THEN 'EXCLUDE_LINKED_POST_CUTOFF_TRANSFER'
                WHEN {adj} AND X.REL_KEY IS NOT NULL AND X.LINK_TYPE = 'REFUND' THEN 'EXCLUDE_LINKED_POST_CUTOFF_REFUND'
                WHEN F.RESTORE_REASON IS NOT NULL THEN F.RESTORE_REASON
                WHEN {mproc} AND F.OPERT_DE IS NULL THEN 'EXCLUDE_UNKNOWN_PROCESS_DATE'
                -- 일반 회비: 이전 작업일 제한 없음, 익월 1일 작업분까지 포함 (202609 MSTR 마감값 구분별 일치 확인)
                WHEN {mproc} AND F.OPERT_DE >= DATEADD(DAY, 1, DATEADD(MONTH, 1, F.MONTH_START)) THEN 'EXCLUDE_LATE_NO_VERIFIED_EVENT'
                WHEN F.CURRENT_RULE_INCLUDE THEN 'KEEP_CURRENT'
                WHEN F.HAS_REFUND AND F.HAS_TRANSFER THEN 'REVIEW_MIXED_REFUND_TRANSFER'
                WHEN F.USE_YN = 'N' AND F.PAY_AMT > 0 AND F.OPERT_DE IS NULL THEN 'REVIEW_N_ORIGINAL_UNKNOWN_DATE'
                WHEN F.USE_YN = 'N' AND F.PAY_AMT > 0 AND F.OPERT_DE >= F.CUTOFF_EXCL THEN 'REVIEW_N_ORIGINAL_AFTER_CUTOFF'
                WHEN F.USE_YN = 'N' AND F.PAY_AMT > 0 THEN 'REVIEW_N_ORIGINAL_NO_SAFE_KEY_EVIDENCE'
                ELSE 'EXCLUDE_CURRENT_STATUS'
            END AS SELECTION_REASON
        FROM FEE_PAY_EVID F
        LEFT JOIN FEE_ROLLBACK_TARGET X ON F.MONTH_START = X.MONTH_START AND F.MBRFEE_KEY = X.REL_KEY
        LEFT JOIN FEE_TIN_DUP TD ON TD.T_KEY = F.MBRFEE_KEY
    ),
    SELECTED_PAY AS (
        SELECT MBRFEE_KEY FROM FEE_PAY_DECISION
        WHERE SELECTION_REASON IN ('KEEP_CURRENT', 'RESTORE_ORIGINAL_AFTER_REFUND', 'RESTORE_ORIGINAL_AFTER_TRANSFER')
    )"""

def _mstr_new_old_cte(year, run_m):
    """3-1 MSTR 신규/기존 판정 CTE (WITH ~ MSTR_NEW_OLD) — 3-1 표·3-4 표 공유"""
    import calendar as _cal_mno
    run_mt = f"{year}{run_m:02d}"
    run_last = _cal_mno.monthrange(year, run_m)[1]
    run_month_start = f"{year}-{run_m:02d}-01"
    run_month_end = f"{year}-{run_m:02d}-{run_last:02d}"
    run_month_31 = f"{run_mt}31"
    run_setle_cutoff = f"DATEADD(DAY,1,DATEADD(MONTH,1,'{run_month_start}'::DATE))"
    return f"""
    WITH
    DEPT_MAP AS (
        SELECT E.DEPT_ID AS SRC_DEPT_ID, B.DEPT_ID AS DEPT4_ID
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO C ON C.ACMSLT_UPPER_DEPT_ID = B.DEPT_ID
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO D ON D.ACMSLT_UPPER_DEPT_ID = C.DEPT_ID
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO E ON E.ACMSLT_UPPER_DEPT_ID = D.DEPT_ID
        WHERE A.UPPER_DEPT_ID = 'ZV000000' AND C.DEPT_ID <> 'ZC000029'
        UNION ALL SELECT 'Z~','Z~'
    ),
    DEPT4_DIM AS (
        SELECT B.DEPT_ID AS DEPT4_ID, B.DEPT_NM AS DEPT4_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
        WHERE A.UPPER_DEPT_ID = 'ZV000000' AND A.USE_YN = 'Y'
        UNION ALL SELECT 'Z~','없음'
    ),
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID,
               CASE WHEN CPR_DIV_CD='1' THEN 'I' WHEN CPR_DIV_CD='2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    SETLE_MONTH AS (
        SELECT MBER_NO, CPR_DIV_CD FROM (
            SELECT MBER_NO, CPR_DIV_CD,
                   ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC, SETLE_DIV_CD DESC) AS RNUM
            FROM (
                SELECT 1 AS SETLE_DIV_CD, SETLE_KEY, MBER_NO,
                       CASE WHEN CPR_DIV_CD='1' THEN 'I' WHEN CPR_DIV_CD='2' THEN 'S' ELSE CPR_DIV_CD::VARCHAR END AS CPR_DIV_CD
                FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE FRST_REGIST_DT < {run_setle_cutoff}
                UNION ALL
                SELECT 2, SETLE_KEY, MBER_NO,
                       CASE WHEN CPR_DIV_CD='1' THEN 'I' WHEN CPR_DIV_CD='2' THEN 'S' ELSE CPR_DIV_CD::VARCHAR END
                FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST WHERE REGIST_DT < {run_setle_cutoff}
            ) WHERE CPR_DIV_CD IS NOT NULL
        ) WHERE RNUM=1
    ),
    LAST_DSCNTC AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE<='{run_month_31}'
    ),
    LAST_RE_SPNSR AS (
        SELECT MBER_NO, RE_SPNSR_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE<='{run_month_31}'
    ),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE>R.RE_SPNSR_DE THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE<TO_CHAR('{run_month_end}'::DATE,'YYYYMMDD') THEN '{run_month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE,'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO=R.MBER_NO AND R.RNUM=1
        WHERE D.RNUM=1
    ),
    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT S.MBER_NO
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD')<='{run_month_31}'
          AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE,''),'99991231')>'{run_month_31}'
    ),
    ACTIVE_MEMBER AS (
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO=L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO=A.MBER_NO
        WHERE '{run_month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT,'9999-12-31'::DATE)
          AND COALESCE(M.MBER_NO::VARCHAR,'') <> '{FEE_EXCLUDED_MEMBER_NO}'  -- DW 제외 회원
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO,
               COALESCE(A.SPNSR_BSNS_ID::VARCHAR,'99') AS SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO=AM.MBER_NO
        WHERE A.OCCRRNC_DE<='{run_month_31}'
    ),
    ACTIVE_DETAIL AS (
        SELECT A.MBER_NO,
               CASE WHEN LEFT(TO_CHAR(M.FRST_REGIST_DT,'YYYYMMDD'),4)='{year}'
                     AND LEFT(TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD'),4)='{year}'
                    THEN '1' ELSE '2' END AS NEW_OLD_DIV_CD
        FROM ACTIVE_HISTORY A
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M ON A.MBER_NO=M.MBER_NO
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON A.SPNSR_NO=S.SPNSR_NO AND A.MBER_NO=S.MBER_NO
        LEFT JOIN BUSINESS_DIM BD ON A.SPNSR_BSNS_ID=BD.SPNSR_BSNS_ID
        LEFT JOIN SETLE_MONTH ST ON A.MBER_NO=ST.MBER_NO AND BD.CPR_DIV_CD=ST.CPR_DIV_CD
        -- MSTR 기준: 신규/기존 연결용 활동행은 전 법인 (#RUN_ACTIVE_NEW_OLD). 사단(I) 범위는 납입 쪽에서 적용
        WHERE A.RNUM=1 AND A.SUM_AMT>0
    ),
    MSTR_NEW_OLD AS (SELECT DISTINCT MBER_NO, NEW_OLD_DIV_CD FROM ACTIVE_DETAIL)
    """

@st.cache_data(ttl=600)
def _load_fee_month(year, run_m):
    """한 달치 회비 집계 (월 단위 캐시 — 3-1 표와 납입율 그래프가 공유)"""
    import calendar as _cal_fee
    year_start = f"{year}-01-01"
    if True:
        run_mt = f"{year}{run_m:02d}"
        run_last = _cal_fee.monthrange(year, run_m)[1]
        run_month_start = f"{year}-{run_m:02d}-01"
        run_month_end = f"{year}-{run_m:02d}-{run_last:02d}"
        run_month_31 = f"{run_mt}31"
        run_setle_cutoff = f"DATEADD(DAY,1,DATEADD(MONTH,1,'{run_month_start}'::DATE))"
        sql = _mstr_new_old_cte(year, run_m) + ",\n" + _fee_selected_pay_ctes(year, run_month_end, run_month_start) + f""",
    PAY_SOURCE AS (
        SELECT P.MBER_NO, P.SPNSR_NO, P.PAY_AMT, P.PAY_DE,
               COALESCE(P.SPNSR_BSNS_ID::VARCHAR,'99') AS SPNSR_BSNS_ID, P.SETLE_ENTRPS_CD::VARCHAR AS SETLE_ENTRPS_CD,
               P.SETLE_CD::VARCHAR AS SETLE_CD, P.ACNUT_SER_NO, P.SETLE_CMPNY_ACNT_NO,
               COALESCE(SB.ACMSLT_DEPT_CD::VARCHAR,'Z~') AS ACMSLT_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT P
        LEFT JOIN (
            SELECT S.SPNSR_NO, B.SPNSR_BSNS_NO, S.ACMSLT_DEPT_CD
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        ) SB ON P.SPNSR_NO=SB.SPNSR_NO AND P.SPNSR_BSNS_NO=SB.SPNSR_BSNS_NO
        -- 납입 선택: 작업일 마감 경계 + 회비키 연결 환급/이관 원거래 조건부 복원 (_fee_selected_pay_ctes)
        JOIN SELECTED_PAY SP ON SP.MBRFEE_KEY = P.MBRFEE_KEY
        WHERE P.PRCS_STAT_CD='S' AND P.PAY_STAT_CD='S'
          AND P.MBRFEE_DIV_CD='E' AND P.CPR_DIV_CD='I'
          AND P.PAY_DE >= '{run_month_start}'::DATE AND P.PAY_DE <= '{run_month_end}'::DATE
    ),
    PAY_CHARGE AS (
        SELECT P.*,
            CASE WHEN P.SETLE_CD='4' THEN IA4.CHRG_DEPT_CD
                 WHEN P.SETLE_CD IN ('3','6','10','13') THEN IA10.CHRG_DEPT_CD
                 ELSE 'D000011' END AS CHRG_DEPT_CD
        FROM PAY_SOURCE P
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT IA4 ON P.ACNUT_SER_NO::VARCHAR=IA4.ACNUT_SER_NO::VARCHAR
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT CA ON P.SETLE_CMPNY_ACNT_NO=CA.SETLE_CMPNY_ACNT_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT IA10 ON CA.ACNUT_SER_NO::VARCHAR=IA10.ACNUT_SER_NO::VARCHAR
    ),
    PAY_FACT AS (
        SELECT P.MBER_NO, P.SPNSR_NO, P.PAY_AMT, P.PAY_DE,
               P.SPNSR_BSNS_ID, P.ACMSLT_DEPT_CD,
               CASE WHEN P.SETLE_CD IN ('3','6','10','13') THEN '10' ELSE COALESCE(P.SETLE_CD,'999') END AS G_SETLE,
               CASE WHEN P.SETLE_CD IN ('1','4','12') THEN '1' WHEN P.SETLE_CD='2' THEN '2' WHEN P.SETLE_CD='5' THEN '3' ELSE 'Z~' END AS G_FNLT,
               COALESCE(CASE WHEN P.SETLE_CD IN ('7','8') THEN '0' WHEN P.SETLE_CD IN ('3','6','10','13') THEN '10' ELSE P.SETLE_ENTRPS_CD END,'Z~') AS G_ENTRPS,
               CASE WHEN COALESCE(MN.NEW_OLD_DIV_CD,'2')='1' THEN '신규회원' ELSE '기존회원' END AS NEW_OLD,
               CASE WHEN D4.DEPT4_NM IN ('본부','본부(사복)') THEN '본부' ELSE '시도본부, 지부 등' END AS HQ_DIV
        FROM PAY_CHARGE P
        LEFT JOIN DEPT_MAP DM ON P.ACMSLT_DEPT_CD=DM.SRC_DEPT_ID
        LEFT JOIN DEPT4_DIM D4 ON COALESCE(DM.DEPT4_ID,'Z~')=D4.DEPT4_ID
        LEFT JOIN MSTR_NEW_OLD MN ON P.MBER_NO=MN.MBER_NO
        WHERE P.CHRG_DEPT_CD='D000011'
    )
    -- MSTR PAY_CNT: 원 적재 Grain(후원사업·실적부서·결제수단·금융기관구분·결제업체)별 DISTINCT 회원 수를 합산
    , PAY_GRAIN AS (
        SELECT NEW_OLD, HQ_DIV, SPNSR_BSNS_ID, ACMSLT_DEPT_CD, G_SETLE, G_FNLT, G_ENTRPS,
               COUNT(DISTINCT MBER_NO) AS PAY_CNT, SUM(PAY_AMT) AS PAY_AMT
        FROM PAY_FACT
        GROUP BY NEW_OLD, HQ_DIV, SPNSR_BSNS_ID, ACMSLT_DEPT_CD, G_SETLE, G_FNLT, G_ENTRPS
    )
    SELECT NEW_OLD, HQ_DIV,
           '{run_mt}' AS SOURCE_MT,
           SUM(PAY_CNT) AS PAY_MEMBERS,
           SUM(PAY_AMT) AS PAY_AMT
    FROM PAY_GRAIN
    GROUP BY NEW_OLD, HQ_DIV
        """
        return conn.query(sql)

@st.cache_data(ttl=600)
def load_fee_data(year, month):
    all_results = [_load_fee_month(year, _m) for _m in range(1, month + 1)]
    if not all_results:
        return pd.DataFrame(columns=["NEW_OLD","HQ_DIV","MONTH_PAY_MEMBERS","MONTH_PAY","YTD_PAY_MEMBERS","YTD_PAY"])
    import pandas as _pd_fee
    strd_mt = f"{year}{month:02d}"
    combined = _pd_fee.concat(all_results, ignore_index=True)
    # 당월 = SOURCE_MT == strd_mt
    cur = combined[combined["SOURCE_MT"] == strd_mt].groupby(["NEW_OLD","HQ_DIV"]).agg(
        MONTH_PAY_MEMBERS=("PAY_MEMBERS","sum"), MONTH_PAY=("PAY_AMT","sum")).reset_index()
    # 누계 = 전체
    ytd = combined.groupby(["NEW_OLD","HQ_DIV"]).agg(
        YTD_PAY_MEMBERS=("PAY_MEMBERS","sum"), YTD_PAY=("PAY_AMT","sum")).reset_index()
    result = ytd.merge(cur, on=["NEW_OLD","HQ_DIV"], how="outer").fillna(0)
    return result

@st.cache_data(ttl=600)
def _load_fee_target(year):
    sql = f"""
    SELECT "NEW_OLD_DIV_NM", "ORG_DIV_NM",
           SUM("M01_GOAL_CNT") AS R01, SUM("M02_GOAL_CNT") AS R02,
           SUM("M03_GOAL_CNT") AS R03, SUM("M04_GOAL_CNT") AS R04,
           SUM("M05_GOAL_CNT") AS R05, SUM("M06_GOAL_CNT") AS R06,
           SUM("M07_GOAL_CNT") AS R07, SUM("M08_GOAL_CNT") AS R08,
           SUM("M09_GOAL_CNT") AS R09, SUM("M10_GOAL_CNT") AS R10,
           SUM("M11_GOAL_CNT") AS R11, SUM("M12_GOAL_CNT") AS R12
    FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
    WHERE "BDGT_PRCD_NM"='연사업' AND "GOAL_TYPE_NM"='정기회비' AND "CPR_DIV_NM"='사단'
      AND "YEAR"='{year}'
    GROUP BY "NEW_OLD_DIV_NM", "ORG_DIV_NM"
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_fee_camp_detail(year, month):
    import calendar as _cal_fcd
    strd_mt = f"{year}{month:02d}"
    year_start = f"{year}-01-01"
    last_day = _cal_fcd.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    sql = f"""
    WITH{_fee_selected_pay_ctes(year, month_end)},
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    first_dev AS (
        SELECT MBER_NO, MIN(OCCRRNC_DE) AS FIRST_DEV_DATE
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT WHERE DVLP_DIV_CD = '1' GROUP BY MBER_NO
    ),
    PAY_BASE AS (
        SELECT P.MBER_NO, P.SPNSR_NO, P.SPNSR_BSNS_NO, P.PAY_AMT, P.PAY_DE,
               P.SETLE_CD::VARCHAR AS SETLE_CD, P.ACNUT_SER_NO, P.SETLE_CMPNY_ACNT_NO
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT P
        -- 납입 선택: 작업일 마감 경계 + 회비키 연결 환급/이관 원거래 조건부 복원 (_fee_selected_pay_ctes)
        JOIN SELECTED_PAY SP ON SP.MBRFEE_KEY = P.MBRFEE_KEY
        WHERE P.PRCS_STAT_CD='S' AND P.PAY_STAT_CD='S'
          AND P.MBRFEE_DIV_CD='E' AND P.CPR_DIV_CD='I'
          AND P.PAY_DE BETWEEN '{year_start}'::DATE AND '{month_end}'::DATE
    ),
    PAY_CHARGE AS (
        SELECT P.*,
            CASE WHEN P.SETLE_CD='4' THEN IA4.CHRG_DEPT_CD
                 WHEN P.SETLE_CD IN ('3','6','10','13') THEN IA10.CHRG_DEPT_CD
                 ELSE 'D000011' END AS CHRG_DEPT_CD
        FROM PAY_BASE P
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT IA4 ON P.ACNUT_SER_NO::VARCHAR=IA4.ACNUT_SER_NO::VARCHAR
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT CA ON P.SETLE_CMPNY_ACNT_NO=CA.SETLE_CMPNY_ACNT_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT IA10 ON CA.ACNUT_SER_NO::VARCHAR=IA10.ACNUT_SER_NO::VARCHAR
    ),
    PAY_CAMPAIGN AS (
        SELECT P.PAY_AMT, P.PAY_DE, P.MBER_NO,
               CASE WHEN FD.FIRST_DEV_DATE >= '{year}0101' THEN '신규회원' ELSE '기존회원' END AS NEW_OLD,
               COALESCE(BL.CMMN_BRND_NM, SB.CMMN_BRND_NM, '기타') AS CMMN_BRND_NM,
               COALESCE(MK.DTL_CD_NM, '미분류') AS MKTG_CMPGN_NM
        FROM PAY_CHARGE P
        LEFT JOIN (
            SELECT S.SPNSR_NO, B.SPNSR_BSNS_NO, S.CMPGN_CD
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        ) SM ON P.SPNSR_NO=SM.SPNSR_NO AND P.SPNSR_BSNS_NO=SM.SPNSR_BSNS_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG CM ON SM.CMPGN_CD=CM.CMPGN_CD
        LEFT JOIN brnd_lookup BL ON BL.CMMN_BRND=CM.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD=CM.UPPER_CMPGN_CD AND SB.RN=1
        LEFT JOIN GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD MK ON MK.CD_ID='C001' AND MK.DTL_CD_ID=CM.MKTG_CMPGN_NM::VARCHAR
        LEFT JOIN first_dev FD ON P.MBER_NO=FD.MBER_NO
        WHERE P.CHRG_DEPT_CD='D000011'
    )
    SELECT NEW_OLD, CMMN_BRND_NM, MKTG_CMPGN_NM,
           SUM(CASE WHEN TO_CHAR(PAY_DE,'YYYYMM')='{strd_mt}' THEN PAY_AMT ELSE 0 END) AS MONTH_PAY,
           SUM(PAY_AMT) AS YTD_PAY
    FROM PAY_CAMPAIGN
    GROUP BY NEW_OLD, CMMN_BRND_NM, MKTG_CMPGN_NM
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def load_fee_biz_data(year, month, by_month=False):
    strd_mt = f"{year}{month:02d}"
    year_start = f"{year}-01-01"
    month_start = f"{year}-{month:02d}-01"
    import calendar as _cal_biz
    last_day = _cal_biz.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    sql = "\n    WITH" + _fee_selected_pay_ctes(year, month_end) + f""",
    RELATNSP_DATA AS (
        SELECT R.RELATNSP_KEY,
               COALESCE(C.BPLC_CD::VARCHAR, 'Z~') AS BPLC_CD,
               COALESCE(C.MNYRS_NATION_CD::VARCHAR, 'Z~') AS NATION_CD,
               ROW_NUMBER() OVER (PARTITION BY R.RELATNSP_KEY
                   ORDER BY R.RELATNSP_STRT_DE DESC, R.SPNSR_BSNS_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_RM_RELATNSP_MSTR_INFO R
        LEFT JOIN GN_DW.BRONZE_CRM.TM_RM_CHILD_MSTR_INFO C ON R.CHILD_CD = C.CHILD_CD
    ),
    RELATNSP_ATTR AS (
        SELECT RELATNSP_KEY, BPLC_CD, NATION_CD FROM RELATNSP_DATA WHERE RNUM = 1
    ),
    INSTT_ACNUT AS (
        SELECT ACNUT_SER_NO, MAX(CHRG_DEPT_CD) AS CHRG_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT GROUP BY ACNUT_SER_NO
    ),
    CMPNY_ACNUT AS (
        SELECT C.SETLE_CMPNY_ACNT_NO, MAX(I.CHRG_DEPT_CD) AS CHRG_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT C
        LEFT JOIN INSTT_ACNUT I ON C.ACNUT_SER_NO = I.ACNUT_SER_NO
        GROUP BY C.SETLE_CMPNY_ACNT_NO
    ),
    FEE_BASE AS (
        SELECT DISTINCT
            P.MBRFEE_KEY, P.OPER_KEY,
            P.MBER_NO,
            COALESCE(P.SPNSR_BSNS_ID::VARCHAR, '99') AS SPNSR_BSNS_ID,
            P.PAY_DE,
            COALESCE(P.PAY_AMT, 0)::DECIMAL(38,4) AS PAY_AMT,
            P.RETUN_REQUST_KEY,
            CASE WHEN P.SPNSR_BSNS_ID::VARCHAR = '1'
                 THEN COALESCE(R.BPLC_CD, 'Z~') ELSE 'Z~' END AS BPLC_CD,
            CASE WHEN P.SPNSR_BSNS_ID::VARCHAR = '1'
                 THEN COALESCE(R.NATION_CD, 'Z~') ELSE 'Z~' END AS NATION_CD,
            CASE WHEN P.SETLE_CD::VARCHAR = '4' THEN IA.CHRG_DEPT_CD
                 WHEN P.SETLE_CD::VARCHAR IN ('3','6','10','13') THEN CA.CHRG_DEPT_CD
                 ELSE 'D000011' END AS CHRG_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT P
        LEFT JOIN RELATNSP_ATTR R ON P.RELATNSP_KEY = R.RELATNSP_KEY
        LEFT JOIN INSTT_ACNUT IA ON P.ACNUT_SER_NO = IA.ACNUT_SER_NO
        LEFT JOIN CMPNY_ACNUT CA ON P.SETLE_CMPNY_ACNT_NO = CA.SETLE_CMPNY_ACNT_NO
        -- 납입 선택: 작업일 마감 경계 + 회비키 연결 환급/이관 원거래 조건부 복원 (_fee_selected_pay_ctes)
        JOIN SELECTED_PAY SP ON SP.MBRFEE_KEY = P.MBRFEE_KEY
        WHERE P.MBRFEE_DIV_CD = 'E'
          AND P.PRCS_STAT_CD = 'S' AND P.PAY_STAT_CD = 'S'
          AND P.PAY_DE >= '{year_start}'::DATE AND P.PAY_DE <= '{month_end}'::DATE
          AND COALESCE(P.SPNSR_BSNS_ID::VARCHAR, '99') IN
              ('1','41','38','39','42','2','9','3','5','6','99','33','43','4','16','15','22','21','14')
          AND P.CPR_DIV_CD = 'I'
    ),
    FEE_FILTERED AS (
        SELECT * FROM FEE_BASE WHERE CHRG_DEPT_CD = 'D000011'
    ),
    PAY_MONTH_GRAIN AS (
        SELECT
            TO_CHAR(PAY_DE, 'YYYYMM') AS PAY_MT,
            SPNSR_BSNS_ID, BPLC_CD, NATION_CD,
            COUNT(DISTINCT MBER_NO) AS PAY_CNT,
            SUM(PAY_AMT) AS PAY_AMT
        FROM FEE_FILTERED
        GROUP BY TO_CHAR(PAY_DE, 'YYYYMM'), SPNSR_BSNS_ID, BPLC_CD, NATION_CD
    )
    SELECT
        SPNSR_BSNS_ID,
        SUM(CASE WHEN PAY_MT = '{strd_mt}' THEN PAY_CNT ELSE 0 END) AS MONTH_PAY_CNT,
        SUM(CASE WHEN PAY_MT = '{strd_mt}' THEN PAY_AMT ELSE 0 END) AS MONTH_PAY_AMT,
        SUM(PAY_CNT) AS YTD_PAY_CNT,
        SUM(PAY_AMT) AS YTD_PAY_AMT
    FROM PAY_MONTH_GRAIN
    GROUP BY SPNSR_BSNS_ID
    ORDER BY SPNSR_BSNS_ID
    """
    if by_month:
        # 그래프용: 월×후원사업 단위 (동일 집계 로직)
        sql = sql[:sql.rindex("SUM(CASE WHEN PAY_MT")]
        sql = sql[:sql.rindex("SELECT")] + """SELECT PAY_MT, SPNSR_BSNS_ID,
        SUM(PAY_CNT) AS PAY_CNT, SUM(PAY_AMT) AS PAY_AMT
    FROM PAY_MONTH_GRAIN
    GROUP BY PAY_MT, SPNSR_BSNS_ID
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_fee_biz_target(year):
    sql = f"""
    SELECT "SPNSR_BSNS_DIV_NM",
           SUM("M01_GOAL_CNT") AS R01, SUM("M02_GOAL_CNT") AS R02,
           SUM("M03_GOAL_CNT") AS R03, SUM("M04_GOAL_CNT") AS R04,
           SUM("M05_GOAL_CNT") AS R05, SUM("M06_GOAL_CNT") AS R06,
           SUM("M07_GOAL_CNT") AS R07, SUM("M08_GOAL_CNT") AS R08,
           SUM("M09_GOAL_CNT") AS R09, SUM("M10_GOAL_CNT") AS R10,
           SUM("M11_GOAL_CNT") AS R11, SUM("M12_GOAL_CNT") AS R12
    FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
    WHERE "BDGT_PRCD_NM"='연사업' AND "GOAL_TYPE_NM"='정기회비' AND "CPR_DIV_NM"='사단'
      AND "YEAR"='{year}'
    GROUP BY "SPNSR_BSNS_DIV_NM"
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_fee_biz_camp_detail(year, month):
    import calendar as _cal_bcd
    strd_mt = f"{year}{month:02d}"
    year_start = f"{year}-01-01"
    last_day = _cal_bcd.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    sql = f"""
    WITH{_fee_selected_pay_ctes(year, month_end)},
    INSTT_ACNUT AS (
        SELECT ACNUT_SER_NO, MAX(CHRG_DEPT_CD) AS CHRG_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT GROUP BY ACNUT_SER_NO
    ),
    CMPNY_ACNUT AS (
        SELECT C.SETLE_CMPNY_ACNT_NO, MAX(I.CHRG_DEPT_CD) AS CHRG_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT C
        LEFT JOIN INSTT_ACNUT I ON C.ACNUT_SER_NO = I.ACNUT_SER_NO
        GROUP BY C.SETLE_CMPNY_ACNT_NO
    ),
    FEE_BASE AS (
        SELECT DISTINCT P.MBRFEE_KEY, P.OPER_KEY,
               P.MBER_NO, P.SPNSR_NO, P.SPNSR_BSNS_NO,
               COALESCE(P.SPNSR_BSNS_ID::VARCHAR, '99') AS SPNSR_BSNS_ID,
               P.PAY_DE, COALESCE(P.PAY_AMT, 0)::DECIMAL(38,4) AS PAY_AMT,
               CASE WHEN P.SETLE_CD::VARCHAR = '4' THEN IA.CHRG_DEPT_CD
                    WHEN P.SETLE_CD::VARCHAR IN ('3','6','10','13') THEN CA.CHRG_DEPT_CD
                    ELSE 'D000011' END AS CHRG_DEPT_CD
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT P
        LEFT JOIN INSTT_ACNUT IA ON P.ACNUT_SER_NO = IA.ACNUT_SER_NO
        LEFT JOIN CMPNY_ACNUT CA ON P.SETLE_CMPNY_ACNT_NO = CA.SETLE_CMPNY_ACNT_NO
        -- 납입 선택: 작업일 마감 경계 + 회비키 연결 환급/이관 원거래 조건부 복원 (_fee_selected_pay_ctes)
        JOIN SELECTED_PAY SP ON SP.MBRFEE_KEY = P.MBRFEE_KEY
        WHERE P.MBRFEE_DIV_CD = 'E' AND P.PRCS_STAT_CD = 'S'
          AND P.PAY_STAT_CD = 'S'
          AND P.PAY_DE >= '{year_start}'::DATE AND P.PAY_DE <= '{month_end}'::DATE
          AND COALESCE(P.SPNSR_BSNS_ID::VARCHAR, '99') IN
              ('1','41','38','39','42','2','9','3','5','6','99','33','43','4','16','15','22','21','14')
          AND P.CPR_DIV_CD = 'I'
    ),
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    FEE_CAMPAIGN AS (
        SELECT F.SPNSR_BSNS_ID, F.PAY_AMT, F.PAY_DE,
               COALESCE(BL.CMMN_BRND_NM, SB.CMMN_BRND_NM, '기타') AS CMMN_BRND_NM,
               COALESCE(MK.DTL_CD_NM, '미분류') AS MKTG_CMPGN_NM
        FROM FEE_BASE F
        LEFT JOIN (
            SELECT S.SPNSR_NO, B.SPNSR_BSNS_NO, S.CMPGN_CD
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        ) SM ON F.SPNSR_NO=SM.SPNSR_NO AND F.SPNSR_BSNS_NO=SM.SPNSR_BSNS_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG CM ON SM.CMPGN_CD=CM.CMPGN_CD
        LEFT JOIN brnd_lookup BL ON BL.CMMN_BRND=CM.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD=CM.UPPER_CMPGN_CD AND SB.RN=1
        LEFT JOIN GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD MK ON MK.CD_ID='C001' AND MK.DTL_CD_ID=CM.MKTG_CMPGN_NM::VARCHAR
        WHERE F.CHRG_DEPT_CD = 'D000011'
    )
    SELECT SPNSR_BSNS_ID, CMMN_BRND_NM, MKTG_CMPGN_NM,
           SUM(CASE WHEN TO_CHAR(PAY_DE,'YYYYMM')='{strd_mt}' THEN PAY_AMT ELSE 0 END) AS MONTH_PAY,
           SUM(PAY_AMT) AS YTD_PAY
    FROM FEE_CAMPAIGN
    GROUP BY SPNSR_BSNS_ID, CMMN_BRND_NM, MKTG_CMPGN_NM
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_active_for_fee(year, month):
    import calendar as _cal_af
    strd_mt = f"{year}{month:02d}"
    last_day = _cal_af.monthrange(year, month)[1]
    month_start = f"{year}-{month:02d}-01"
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
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
        SELECT B.DEPT_ID AS DEPT4_ID, B.DEPT_NM AS DEPT4_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO A
        JOIN GN_DW.BRONZE_CRM.TM_CM_DEPT_INFO B ON B.ACMSLT_UPPER_DEPT_ID = A.DEPT_ID
        WHERE A.UPPER_DEPT_ID = 'ZV000000' AND A.USE_YN = 'Y'
        UNION ALL SELECT 'Z~', '없음'
    ),
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID,
               CASE WHEN CPR_DIV_CD='1' THEN 'I' WHEN CPR_DIV_CD='2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT,'YYYYMM')='{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE WHEN H.CHN_STAT_CD IS NULL THEN
                   CASE WHEN M.MBER_STAT_CD::VARCHAR='12' THEN '1'
                        WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                            CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                        ELSE M.MBER_STAT_CD::VARCHAR END
               WHEN H.CHN_STAT_CD::VARCHAR='12' THEN '1' ELSE H.CHN_STAT_CD::VARCHAR END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO=H.MBER_NO AND H.RNUM=1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO=X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT,'YYYYMM')<='{strd_mt}'
    ),
    SETLE_UNION AS (
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, FRST_REGIST_DT FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
        UNION ALL SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, REGIST_DT FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
    ),
    SETLE_MONTH AS (
        SELECT MBER_NO, CPR_DIV_CD FROM (
            SELECT MBER_NO, CPR_DIV_CD, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM
            FROM SETLE_UNION WHERE FRST_REGIST_DT<=DATEADD(DAY,1,DATEADD(MONTH,1,'{month_start}'::DATE))
        ) WHERE RNUM=1
    ),
    LAST_DSCNTC AS (SELECT MBER_NO, SPNSR_DSCNTC_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE<='{month_31}'),
    LAST_RE_SPNSR AS (SELECT MBER_NO, RE_SPNSR_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE<='{month_31}'),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE>R.RE_SPNSR_DE THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE<TO_CHAR('{month_end}'::DATE,'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE,'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO=R.MBER_NO AND R.RNUM=1 WHERE D.RNUM=1
    ),
    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT S.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD')<='{month_31}'
          AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE,''),'99991231')>'{month_31}'
    ),
    ACTIVE_MEMBER AS (
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO=L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO=A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT,'9999-12-31'::DATE)
          AND COALESCE(M.MBER_NO::VARCHAR,'') <> '{FEE_EXCLUDED_MEMBER_NO}'  -- DW 제외 회원
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO=AM.MBER_NO WHERE A.OCCRRNC_DE<='{month_31}'
    ),
    ACTIVE_AGG AS (
        SELECT
            CASE WHEN LEFT(TO_CHAR(MM.FRST_REGIST_DT,'YYYYMMDD'),4)='{year}'
                  AND LEFT(TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD'),4)='{year}' THEN '신규회원' ELSE '기존회원' END AS NEW_OLD,
            CASE WHEN D4.DEPT4_NM IN ('본부','본부(사복)') THEN '본부' ELSE '시도본부 및 지부' END AS HQ_DIV,
            SUM(A.SUM_AMT/10000.0) AS ACT_CASES
        FROM ACTIVE_HISTORY A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO=AM.MBER_NO
        JOIN MEMBER_MONTH MM ON A.MBER_NO=MM.MBER_NO
        JOIN BUSINESS_DIM BD ON A.SPNSR_BSNS_ID=BD.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON A.MBER_NO=S.MBER_NO AND A.SPNSR_NO=S.SPNSR_NO
        LEFT JOIN SETLE_MONTH ST ON A.MBER_NO=ST.MBER_NO AND BD.CPR_DIV_CD=ST.CPR_DIV_CD
        LEFT JOIN DEPT_MAP MAP ON COALESCE(S.ACMSLT_DEPT_CD,'Z~')=MAP.SRC_DEPT_ID
        LEFT JOIN DEPT4_DIM D4 ON COALESCE(MAP.DEPT4_ID,'Z~')=D4.DEPT4_ID
        WHERE A.RNUM=1 AND A.SUM_AMT>0 AND COALESCE(ST.CPR_DIV_CD,'I')='I'
        GROUP BY NEW_OLD, HQ_DIV
    )
    SELECT NEW_OLD, HQ_DIV, ACT_CASES FROM ACTIVE_AGG
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_pay_rate_goal(year):
    _mcols = ", ".join(f'"M{_m:02d}_GOAL_CNT" AS M{_m:02d}' for _m in range(1, 13))
    return conn.query(f"""
        SELECT "GOAL_TYPE_NM", "NEW_OLD_DIV_NM", "ORG_DIV_NM", {_mcols}
        FROM GN_DW.BRONZE_CRM."TM_CM_MBER_DVLP_GOAL_DIV"
        WHERE "BDGT_PRCD_NM"='연사업' AND "CPR_DIV_NM"='사단' AND "YEAR"='{year}'
          AND "GOAL_TYPE_NM" IN ('신규기존납입율', '신규기존누계납입율')
    """)

def _fee_campaign_cte(year, month, month_only=False, with_kw=True):
    # 3-4 캠페인별 회비 공통 CTE (PAY_CAMPAIGN까지) — 캠페인별/월별 집계가 공유
    # month_only=True: 해당 월 납입만 / with_kw=False: 다른 CTE 뒤에 이어 붙일 때 WITH 생략
    import calendar as _c33
    strd_mt = f"{year}{month:02d}"
    last_day = _c33.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_start = f"{year}-{month:02d}-01"
    year_start = month_start if month_only else f"{year}-01-01"
    return ("\n    WITH" if with_kw else "") + _fee_selected_pay_ctes(year, month_end, year_start) + f""",
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    PAY_BASE AS (
        SELECT P.MBER_NO, P.SPNSR_NO, P.SPNSR_BSNS_NO, P.PAY_AMT, P.PAY_DE,
               P.SETLE_CD::VARCHAR AS SETLE_CD, P.ACNUT_SER_NO, P.SETLE_CMPNY_ACNT_NO
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT P
        -- 납입 선택: 3-1·3-2와 동일 (_fee_selected_pay_ctes)
        JOIN SELECTED_PAY SP ON SP.MBRFEE_KEY = P.MBRFEE_KEY
        WHERE P.PRCS_STAT_CD='S' AND P.PAY_STAT_CD='S'
          AND P.MBRFEE_DIV_CD='E' AND P.CPR_DIV_CD='I'
          AND P.PAY_DE BETWEEN '{year_start}'::DATE AND '{month_end}'::DATE
    ),
    PAY_CHARGE AS (
        SELECT P.*,
            CASE WHEN P.SETLE_CD='4' THEN IA4.CHRG_DEPT_CD
                 WHEN P.SETLE_CD IN ('3','6','10','13') THEN IA10.CHRG_DEPT_CD
                 ELSE 'D000011' END AS CHRG_DEPT_CD
        FROM PAY_BASE P
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT IA4 ON P.ACNUT_SER_NO::VARCHAR=IA4.ACNUT_SER_NO::VARCHAR
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_SETLE_CMPNY_ACNT CA ON P.SETLE_CMPNY_ACNT_NO=CA.SETLE_CMPNY_ACNT_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_PM_INSTT_ACNUT IA10 ON CA.ACNUT_SER_NO::VARCHAR=IA10.ACNUT_SER_NO::VARCHAR
    ),
    PAY_CAMPAIGN AS (
        SELECT P.PAY_AMT, P.PAY_DE, P.MBER_NO,
               COALESCE(BL.CMMN_BRND_NM, SB.CMMN_BRND_NM, '기타') AS CMMN_BRND_NM,
               COALESCE(SC.CMPGN_CTGR_NM, '미분류') AS CMPGN_CTGR_NM,
               COALESCE(MK.DTL_CD_NM, '미분류') AS MKTG_CMPGN_NM,
               COALESCE(CM.CMPGN_NM, '미분류') AS CRM_CMPGN_NM
        FROM PAY_CHARGE P
        LEFT JOIN (
            SELECT S.SPNSR_NO, B.SPNSR_BSNS_NO, S.CMPGN_CD
            FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
            JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        ) SM ON P.SPNSR_NO=SM.SPNSR_NO AND P.SPNSR_BSNS_NO=SM.SPNSR_BSNS_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG CM ON SM.CMPGN_CD=CM.CMPGN_CD
        LEFT JOIN brnd_lookup BL ON BL.CMMN_BRND=CM.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD=CM.UPPER_CMPGN_CD AND SB.RN=1
        LEFT JOIN GN_DW.SILVER.CRM_CAMPAIGN SC ON SC.CMPGN_CD=CM.CMPGN_CD
        LEFT JOIN GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD MK ON MK.CD_ID='C001' AND MK.DTL_CD_ID=CM.MKTG_CMPGN_NM::VARCHAR
        WHERE P.CHRG_DEPT_CD='D000011'
    )
    """

@st.cache_data(ttl=600)
def load_fee_campaign_data(year, month):
    strd_mt = f"{year}{month:02d}"
    sql = _fee_campaign_cte(year, month) + f"""
    SELECT CMMN_BRND_NM, CMPGN_CTGR_NM, MKTG_CMPGN_NM, CRM_CMPGN_NM,
           SUM(CASE WHEN TO_CHAR(PAY_DE,'YYYYMM')='{strd_mt}' THEN PAY_AMT ELSE 0 END) AS MONTH_PAY,
           SUM(PAY_AMT) AS YTD_PAY
    FROM PAY_CAMPAIGN
    GROUP BY CMMN_BRND_NM, CMPGN_CTGR_NM, MKTG_CMPGN_NM, CRM_CMPGN_NM
    """
    df = conn.query(sql)
    # 신규/기존: 3-1과 동일한 MSTR 판정을 월별로 적용 (당월 = 조회월, 누계 = 1월~조회월 합)
    _keys = ["CMMN_BRND_NM", "CMPGN_CTGR_NM", "MKTG_CMPGN_NM", "CRM_CMPGN_NM"]
    _parts = []
    for _m in range(1, month + 1):
        _nm = _load_fee34_new_month(year, _m)
        if not _nm.empty:
            _parts.append(_nm.assign(_MT=_m))
    if df.empty:
        return df
    if _parts:
        _all = pd.concat(_parts, ignore_index=True)
        _all["NEW_PAY"] = _all["NEW_PAY"].astype(float)
        _y = _all.groupby(_keys)["NEW_PAY"].sum().rename("Y_NEW").reset_index()
        _mo = _all[_all["_MT"] == month].groupby(_keys)["NEW_PAY"].sum().rename("M_NEW").reset_index()
        df = df.merge(_y, on=_keys, how="left").merge(_mo, on=_keys, how="left")
    else:
        df["Y_NEW"] = 0.0
        df["M_NEW"] = 0.0
    df["M_NEW"] = df["M_NEW"].fillna(0).astype(float)
    df["Y_NEW"] = df["Y_NEW"].fillna(0).astype(float)
    return df

@st.cache_data(ttl=600)
def _load_fee34_new_month(year, run_m):
    # 해당 월 납입 중 3-1 MSTR 기준 신규회원 회비 (캠페인 키별)
    run_mt = f"{year}{run_m:02d}"
    sql = _mstr_new_old_cte(year, run_m) + ",\n" + _fee_campaign_cte(year, run_m, month_only=True, with_kw=False) + f"""
    SELECT PC.CMMN_BRND_NM, PC.CMPGN_CTGR_NM, PC.MKTG_CMPGN_NM, PC.CRM_CMPGN_NM, SUM(PC.PAY_AMT) AS NEW_PAY
    FROM PAY_CAMPAIGN PC
    JOIN MSTR_NEW_OLD MN ON PC.MBER_NO = MN.MBER_NO AND MN.NEW_OLD_DIV_CD = '1'
    WHERE TO_CHAR(PC.PAY_DE,'YYYYMM') = '{run_mt}'
    GROUP BY PC.CMMN_BRND_NM, PC.CMPGN_CTGR_NM, PC.MKTG_CMPGN_NM, PC.CRM_CMPGN_NM
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def load_fee_brand_monthly(year, month):
    # 공통브랜드 × 납입월 집계 (1월~조회월) — 3-4 월별 선그래프용
    sql = _fee_campaign_cte(year, month) + """
    SELECT CMMN_BRND_NM, TO_CHAR(PAY_DE,'YYYYMM') AS PAY_MT, SUM(PAY_AMT) AS PAY_AMT
    FROM PAY_CAMPAIGN
    GROUP BY CMMN_BRND_NM, TO_CHAR(PAY_DE,'YYYYMM')
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def _load_active_for_fee34(year, month):
    import calendar as _c34a
    strd_mt = f"{year}{month:02d}"
    month_start = f"{year}-{month:02d}-01"
    last_day = _c34a.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
    sql = f"""
    WITH
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID,
               CASE WHEN CPR_DIV_CD='1' THEN 'I' WHEN CPR_DIV_CD='2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    brnd_lookup AS (
        SELECT DISTINCT D2.CMMN_BRND, DC2.CMMN_BRND_NM
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG D2
        JOIN GN_DW.GOLD.DIM_CAMPAIGN DC2 ON D2.CMPGN_CD = DC2.CAMPAIGN_BK
        WHERE DC2.CMMN_BRND_NM IS NOT NULL
    ),
    sibling_brand AS (
        SELECT S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM,
               ROW_NUMBER() OVER (PARTITION BY S.UPPER_CMPGN_CD ORDER BY COUNT(*) DESC) AS RN
        FROM GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG S
        JOIN brnd_lookup BL2 ON BL2.CMMN_BRND = S.CMMN_BRND
        WHERE S.CMMN_BRND IS NOT NULL AND S.UPPER_CMPGN_CD IS NOT NULL
        GROUP BY S.UPPER_CMPGN_CD, BL2.CMMN_BRND_NM
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT,'YYYYMM')='{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO,
               CASE WHEN H.CHN_STAT_CD IS NULL THEN
                   CASE WHEN M.MBER_STAT_CD::VARCHAR='12' THEN '1'
                        WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                            CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                        ELSE M.MBER_STAT_CD::VARCHAR END
               WHEN H.CHN_STAT_CD::VARCHAR='12' THEN '1' ELSE H.CHN_STAT_CD::VARCHAR END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO=H.MBER_NO AND H.RNUM=1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO=X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT,'YYYYMM')<='{strd_mt}'
    ),
    LAST_DSCNTC AS (SELECT MBER_NO, SPNSR_DSCNTC_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE<='{month_31}'),
    LAST_RE_SPNSR AS (SELECT MBER_NO, RE_SPNSR_DE, ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE<='{month_31}'),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE>R.RE_SPNSR_DE THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE<TO_CHAR('{month_end}'::DATE,'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE,'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO=R.MBER_NO AND R.RNUM=1 WHERE D.RNUM=1
    ),
    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT S.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD')<='{month_31}'
          AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE,''),'99991231')>'{month_31}'
    ),
    ACTIVE_MEMBER AS (
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO=L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO=A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT,'9999-12-31'::DATE)
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO=AM.MBER_NO
        WHERE A.OCCRRNC_DE<='{month_31}'
    ),
    SETLE_UNION AS (SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, FRST_REGIST_DT FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO UNION ALL SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, REGIST_DT FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST),
    SETLE_MONTH AS (SELECT MBER_NO, CPR_DIV_CD FROM (SELECT MBER_NO, CPR_DIV_CD, ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM FROM SETLE_UNION WHERE FRST_REGIST_DT<=DATEADD(DAY,1,DATEADD(MONTH,1,'{month_start}'::DATE))) WHERE RNUM=1),
    ACTIVE_FACT AS (
        SELECT
            COALESCE(BL.CMMN_BRND_NM, SB.CMMN_BRND_NM, '기타') AS CMMN_BRND_NM,
            COALESCE(MK.DTL_CD_NM, '미분류') AS MKTG_CMPGN_NM,
            AC.SUM_AMT / 10000.0 AS SPNSR_AMT_CNT
        FROM ACTIVE_HISTORY AC
        JOIN MEMBER_MONTH MM ON AC.MBER_NO=MM.MBER_NO
        JOIN BUSINESS_DIM BS ON AC.SPNSR_BSNS_ID=BS.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR SM ON AC.MBER_NO=SM.MBER_NO AND AC.SPNSR_NO=SM.SPNSR_NO
        LEFT JOIN GN_DW.BRONZE_CRM.TM_CM_CMPGN_MNG CM ON SM.CMPGN_CD=CM.CMPGN_CD
        LEFT JOIN brnd_lookup BL ON BL.CMMN_BRND=CM.CMMN_BRND
        LEFT JOIN sibling_brand SB ON SB.UPPER_CMPGN_CD=CM.UPPER_CMPGN_CD AND SB.RN=1
        LEFT JOIN GN_DW.BRONZE_CRM.TC_MKTNG_DTL_CD MK ON MK.CD_ID='C001' AND MK.DTL_CD_ID=CM.MKTG_CMPGN_NM::VARCHAR
        WHERE AC.RNUM=1 AND AC.SUM_AMT>0 AND BS.CPR_DIV_CD='I'
    )
    SELECT CMMN_BRND_NM, MKTG_CMPGN_NM, SUM(SPNSR_AMT_CNT) AS ACT_CASES
    FROM ACTIVE_FACT
    GROUP BY CMMN_BRND_NM, MKTG_CMPGN_NM
    """
    return conn.query(sql)

@st.cache_data(ttl=600)
def load_ref_tab_data(year, month):
    strd_mt = f"{year}{month:02d}"
    strd_mt_int = int(strd_mt)
    excluded_mbers = [m for m, mt in EXCLUDED_MEMBERS_2025 if mt == strd_mt_int] if year == 2025 else []
    exclude_clause = f"AND M.MBER_NO NOT IN ({','.join(repr(m) for m in excluded_mbers)})" if excluded_mbers else ""
    month_start = f"{year}-{month:02d}-01"
    import calendar as _cal
    last_day = _cal.monthrange(year, month)[1]
    month_end = f"{year}-{month:02d}-{last_day:02d}"
    month_31 = f"{strd_mt}31"
    year_start = f"{year}-01-01"
    sql = f"""
    WITH
    BUSINESS_DIM AS (
        SELECT SPNSR_BSNS_ID, SPNSR_BSNS_NM,
               CASE WHEN CPR_DIV_CD='1' THEN 'I' WHEN CPR_DIV_CD='2' THEN 'S' ELSE CPR_DIV_CD END AS CPR_DIV_CD
        FROM GN_DW.BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO
    ),
    STATUS_HISTORY AS (
        SELECT MBER_NO, CHN_STAT_CD,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY FRST_REGIST_DT DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TH_MM_FDRM_MBER_STNG_DTLS
        WHERE TO_CHAR(FRST_REGIST_DT,'YYYYMM')='{strd_mt}'
    ),
    MEMBER_MONTH AS (
        SELECT M.MBER_NO, M.FRST_REGIST_DT,
               CASE
                   WHEN H.CHN_STAT_CD IS NULL THEN
                       CASE WHEN M.MBER_STAT_CD::VARCHAR='12' THEN '1'
                            WHEN M.MBER_STAT_CD::VARCHAR IN ('2','7') THEN
                                CASE WHEN X.MBER_NO IS NULL THEN '1' ELSE M.MBER_STAT_CD::VARCHAR END
                            ELSE M.MBER_STAT_CD::VARCHAR END
                   WHEN H.CHN_STAT_CD::VARCHAR='12' THEN '1'
                   ELSE H.CHN_STAT_CD::VARCHAR END AS MBER_STAT_CD
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        LEFT JOIN STATUS_HISTORY H ON M.MBER_NO=H.MBER_NO AND H.RNUM=1
        LEFT JOIN (SELECT DISTINCT MBER_NO FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO WHERE RQEST_EXCL_END_DE IS NOT NULL) X ON M.MBER_NO=X.MBER_NO
        WHERE TO_CHAR(M.FRST_REGIST_DT,'YYYYMM')<='{strd_mt}'
    ),
    LAST_DSCNTC AS (
        SELECT MBER_NO, SPNSR_DSCNTC_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY SPNSR_DSCNTC_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC WHERE SPNSR_DSCNTC_DE<='{month_31}'
    ),
    LAST_RE_SPNSR AS (
        SELECT MBER_NO, RE_SPNSR_DE,
               ROW_NUMBER() OVER (PARTITION BY MBER_NO ORDER BY RE_SPNSR_DE DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_RE_SPNSR WHERE RE_SPNSR_DE<='{month_31}'
    ),
    LAST_ACTIVITY_DATE AS (
        SELECT D.MBER_NO,
               CASE WHEN R.RE_SPNSR_DE IS NULL THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN D.SPNSR_DSCNTC_DE>R.RE_SPNSR_DE THEN DATEADD(DAY,-1,TO_DATE(D.SPNSR_DSCNTC_DE,'YYYYMMDD'))
                    WHEN R.RE_SPNSR_DE<TO_CHAR('{month_end}'::DATE,'YYYYMMDD') THEN '{month_end}'::DATE
                    ELSE TO_DATE(R.RE_SPNSR_DE,'YYYYMMDD') END AS ACTUAL_DT
        FROM LAST_DSCNTC D LEFT JOIN LAST_RE_SPNSR R ON D.MBER_NO=R.MBER_NO AND R.RNUM=1
        WHERE D.RNUM=1
    ),
    HAS_LIVE_SPONSOR AS (
        SELECT DISTINCT S.MBER_NO
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS B ON S.SPNSR_NO=B.SPNSR_NO
        WHERE TO_CHAR(S.FRST_REGIST_DT,'YYYYMMDD')<='{month_31}'
          AND COALESCE(NULLIF(B.SPNSR_DSCNTC_DE,''),'99991231')>'{month_31}'
    ),
    ACTIVE_MEMBER AS (
        SELECT M.MBER_NO FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO M
        JOIN HAS_LIVE_SPONSOR L ON M.MBER_NO=L.MBER_NO
        LEFT JOIN LAST_ACTIVITY_DATE A ON M.MBER_NO=A.MBER_NO
        WHERE '{month_end}'::DATE BETWEEN M.FRST_REGIST_DT::DATE AND COALESCE(A.ACTUAL_DT,'9999-12-31'::DATE)
          {exclude_clause}
    ),
    ACTIVE_HISTORY AS (
        SELECT A.SPNSR_NO, A.SPNSR_BSNS_NO, A.MBER_NO, A.SPNSR_BSNS_ID,
               SUM(A.SPNSR_AMT) OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO) AS SUM_AMT,
               ROW_NUMBER() OVER (PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC) AS RNUM
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT A WHERE A.OCCRRNC_DE<='{month_31}'
    ),
    SETLE_UNION AS (
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, FRST_REGIST_DT FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO
        UNION ALL
        SELECT SETLE_KEY, MBER_NO, CPR_DIV_CD, REGIST_DT FROM GN_DW.BRONZE_CRM.TH_PM_SETLE_INFO_HIST
    ),
    SETLE_MONTH AS (
        SELECT MBER_NO, CPR_DIV_CD FROM (
            SELECT MBER_NO, CPR_DIV_CD,
                   ROW_NUMBER() OVER (PARTITION BY MBER_NO, CPR_DIV_CD ORDER BY SETLE_KEY DESC) AS RNUM
            FROM SETLE_UNION WHERE FRST_REGIST_DT<=DATEADD(DAY,1,DATEADD(MONTH,1,'{month_start}'::DATE))
        ) WHERE RNUM=1
    ),
    PAY_DATA AS (
        SELECT SPNSR_NO, SPNSR_BSNS_NO,
               SUM(CASE WHEN TO_CHAR(PAY_DE,'YYYYMM')='{strd_mt}' THEN PAY_AMT ELSE 0 END) AS MONTH_PAY_AMT,
               SUM(PAY_AMT) AS YTD_PAY_AMT
        FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
        WHERE USE_YN='Y' AND PRCS_STAT_CD='S' AND PAY_STAT_CD='S'
          AND MBRFEE_DIV_CD='E' AND RETUN_MBRFEE_KEY IS NULL
          AND PAY_DE BETWEEN '{year_start}'::DATE AND '{month_end}'::DATE
          AND COALESCE(PAY_AMT, 0) >= 0
        GROUP BY SPNSR_NO, SPNSR_BSNS_NO
    ),
    FIRST_DEV AS (
        SELECT MBER_NO, MIN(OCCRRNC_DE) AS FIRST_DEV_DATE
        FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
        WHERE DVLP_DIV_CD = '1'
        GROUP BY MBER_NO
    ),
    ACTIVE_FACT AS (
        SELECT A.MBER_NO,
               CASE
                   WHEN BD.SPNSR_BSNS_NM IN ('국내아동권리보호사업(사단법인)','결식아동지원','아동학대예방','저소득가정지원','아동복지시설지원','복지관후원') THEN '국내아동권리보호사업'
                   WHEN BD.SPNSR_BSNS_NM = '좋은이웃' THEN '좋은이웃후원'
                   ELSE BD.SPNSR_BSNS_NM
               END AS BIZ_CATEGORY,
               A.SUM_AMT/10000.0 AS SPNSR_AMT_CNT,
               CASE WHEN FD.FIRST_DEV_DATE >= '{year}0101' THEN '신규회원' ELSE '기존회원' END AS NEW_OLD,
               COALESCE(P.MONTH_PAY_AMT,0) AS MONTH_PAY_AMT,
               COALESCE(P.YTD_PAY_AMT,0) AS YTD_PAY_AMT
        FROM ACTIVE_HISTORY A
        JOIN ACTIVE_MEMBER AM ON A.MBER_NO=AM.MBER_NO
        JOIN MEMBER_MONTH M ON A.MBER_NO=M.MBER_NO
        JOIN BUSINESS_DIM BD ON A.SPNSR_BSNS_ID=BD.SPNSR_BSNS_ID
        JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR S ON A.MBER_NO=S.MBER_NO AND A.SPNSR_NO=S.SPNSR_NO
        LEFT JOIN SETLE_MONTH ST ON A.MBER_NO=ST.MBER_NO AND BD.CPR_DIV_CD=ST.CPR_DIV_CD
        LEFT JOIN PAY_DATA P ON A.SPNSR_NO=P.SPNSR_NO AND A.SPNSR_BSNS_NO=P.SPNSR_BSNS_NO
        LEFT JOIN FIRST_DEV FD ON A.MBER_NO=FD.MBER_NO
        WHERE A.RNUM=1 AND A.SUM_AMT>0 AND COALESCE(ST.CPR_DIV_CD,'I')='I'
    )
    SELECT BIZ_CATEGORY AS BIZ_NAME, NEW_OLD,
           COUNT(DISTINCT MBER_NO) AS ACTIVE_MEMBERS,
           SUM(SPNSR_AMT_CNT) AS ACTIVE_CASES,
           SUM(MONTH_PAY_AMT) AS MONTH_PAY,
           SUM(YTD_PAY_AMT) AS YTD_PAY
    FROM ACTIVE_FACT GROUP BY BIZ_CATEGORY, NEW_OLD ORDER BY BIZ_CATEGORY, NEW_OLD
    """
    return conn.query(sql)


import threading as _threading
from concurrent.futures import ThreadPoolExecutor as _TPE

def _tab_jobs(Y, M):
    """탭별 사전 조회 대상 (함수, 인자) 목록"""
    t1 = [(load_data, (Y,)), (load_data, (Y - 1,)), (load_data, (Y - 2,)),
          (_load_goal_from_db, (Y,)), (_load_goal_member_from_db, (Y,)),
          (_load_setle_for_popup, ()), (load_active_v2, (Y, M, True))]
    t2 = [(load_active_v2, (Y, M)), (_load_active_campaign_popup, (Y, M)),
          (_load_active_target, (Y,)), (_load_activity_rate_target, (Y,)),
          (_load_biz_active_target, (Y,)), (load_active_by_biz, (Y, M)),
          (load_active_by_biz, (Y - 1, 12)), (load_active_by_brand, (Y, M)),
          (load_active_by_common_brand, (Y, M)), (load_active_brand_detail, (Y, M)),
          (load_active_brand_detail, (Y - 1, M)), (_load_setle_for_activity, ()),
          (load_data, (Y,))]
    t3 = ([(_load_fee_month, (Y, m)) for m in range(1, M + 1)]
          + [(_load_active_for_fee, (Y, m)) for m in range(1, M + 1)]
          + [(_load_fee_month, (Y - 1, m)) for m in range(1, 13)]
          + [(_load_active_for_fee, (Y - 1, m)) for m in range(1, 13)]
          + [(_load_fee_target, (Y,)), (_load_fee_camp_detail, (Y, M)),
             (load_fee_biz_data, (Y, M)), (load_fee_biz_data, (Y, M, True)),
             (load_fee_biz_data, (Y - 1, M, True)), (_load_fee_biz_camp_detail, (Y, M)),
             (_load_fee_biz_target, (Y,)), (_load_pay_rate_goal, (Y,)),
             (load_fee_campaign_data, (Y, M)), (load_fee_brand_monthly, (Y, M)), (load_fee_brand_monthly, (Y - 1, M)), (_load_active_for_fee34, (Y, M))])
    t4 = [(load_ref_tab_data, (Y, M)), (load_active_by_biz, (Y - 1, 12)), (load_data, (Y,))]
    return [t1, t2, t3, t4]

def _run_jobs(jobs, workers=8):
    # 중복 제거 후 병렬 실행 (결과는 st.cache_data에 저장되어 탭 렌더링 시 즉시 사용)
    uniq = list(dict.fromkeys(jobs))
    def _safe(fn, args):
        try:
            fn(*args)
        except Exception:
            pass  # 실패 시 탭 렌더링 때 원래대로 다시 조회
    with _TPE(max_workers=workers) as ex:
        list(ex.map(lambda j: _safe(*j), uniq))

def prefetch_all_tabs(Y, M, current_idx):
    jobs = _tab_jobs(Y, M)
    # 1) 현재 탭 데이터는 병렬로 먼저 조회 (완료까지 대기)
    with st.spinner("데이터를 불러오는 중..."):
        _run_jobs(jobs[current_idx])
    # 2) 나머지 탭은 백그라운드에서 미리 조회 → 탭 클릭 시 캐시에서 즉시 표시
    rest = [j for i, js in enumerate(jobs) if i != current_idx and not (HIDE_REF_TAB and i == 3) for j in js]
    rest.append((load_fee_data, (Y, M)))
    _threading.Thread(target=_run_jobs, args=(rest,), daemon=True).start()

# =====================================================
# 상단 조회조건 (가로 배치)
# =====================================================
if "query_executed" not in st.session_state:
    st.session_state.query_executed = False

filter_col1, filter_col2, filter_col_btn, filter_col3, _ = st.columns([1, 1, 0.7, 1.5, 3.3])
with filter_col1:
    import datetime as _dt_filter
    _current_year = _dt_filter.date.today().year
    _year_options = [_current_year, _current_year - 1, _current_year - 2, _current_year - 3]
    sel_year = st.selectbox("조회년도", options=_year_options, index=0)
with filter_col2:
    _month_sel = st.selectbox("조회월", options=["선택하세요"] + list(range(1, 13)), index=0, format_func=lambda x: "선택하세요" if x == "선택하세요" else f"{x}월")
with filter_col_btn:
    st.markdown("<div style='height:28px'></div>", unsafe_allow_html=True)
    if st.button("조회하기", type="primary", use_container_width=True):
        if _month_sel != "선택하세요":
            st.session_state.query_executed = True

if _month_sel == "선택하세요" or not st.session_state.query_executed:
    st.info("조회년도와 조회월을 선택한 후 [조회하기] 버튼을 클릭하세요.")
    st.stop()

sel_month = _month_sel
with filter_col3:
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
        )
    )


st.title(f"{sel_year}년 {sel_month}월 회원통계보고")

# ── 포스트잇 탭 ──
TAB_LABELS = ["1.회원개발", "2.회원활동", "3.회비현황", "참고)후원사업x신규기존 개발,활동,회비"]
TAB_STYLES = [
    {"bg": "#FFF9C4", "active": "#FFE082", "color": "#5D4037", "border": "#FFB300"},
    {"bg": "#E0F2F1", "active": "#B2DFDB", "color": "#004D40", "border": "#00897B"},
    {"bg": "#E3F2FD", "active": "#BBDEFB", "color": "#0D47A1", "border": "#1976D2"},
    {"bg": "#FCE4EC", "active": "#F8BBD0", "color": "#880E4F", "border": "#E91E63"},
]

if "active_tab" not in st.session_state:
    st.session_state.active_tab = TAB_LABELS[0]

# 사이드바 탭 버튼 스타일 — 세로 텍스트, 좁은 도형
_postit_btn_css = "<style>\n"
# 사이드바 너비 축소
_postit_btn_css += """
[data-testid="stSidebar"] { width: 68px !important; min-width: 68px !important; max-width: 68px !important; }
[data-testid="stSidebar"] > div:first-child { width: 68px !important; }
[data-testid="stSidebar"] [data-testid="stSidebarContent"] { padding: 8px 4px !important; }
[data-testid="stSidebar"] [data-testid="stSidebarCollapseButton"] { display: none !important; }
[data-testid="stSidebar"] .stElementContainer { margin-bottom: 0px !important; padding-bottom: 0px !important; }
[data-testid="stSidebar"] .stVerticalBlock > div { gap: 0px !important; }
"""
for i, s in enumerate(TAB_STYLES):
    is_act = st.session_state.active_tab == TAB_LABELS[i]
    if is_act:
        bg = s["active"]
        text_color = s["color"]
        fw = "800"
        shadow = "2px 2px 8px rgba(0,0,0,0.15)"
        bdr_bottom = f"border-bottom:3px solid {s['border']};"
        opacity = "1"
    else:
        bg = "#f0f0f0"
        text_color = "#9e9e9e"
        fw = "500"
        shadow = "1px 1px 3px rgba(0,0,0,0.06)"
        bdr_bottom = ""
        opacity = "0.7"
    _postit_btn_css += f"""
    .st-key-postit_{i} button,
    .st-key-postit_{i} button:hover,
    .st-key-postit_{i} button:focus,
    .st-key-postit_{i} button:active {{
        background-color:{bg} !important;
        color:{text_color} !important;
        font-weight:{fw} !important;
        font-size:12px !important;
        padding:10px 4px !important;
        border-radius:8px !important;
        box-shadow:{shadow} !important;
        {bdr_bottom}
        border-top:none !important;
        border-left:none !important;
        border-right:none !important;
        width:56px !important;
        min-width:56px !important;
        max-width:56px !important;
        height:auto !important;
        cursor:pointer !important;
        opacity:{opacity} !important;
        margin:0 auto 2px auto !important;
        display:block !important;
    }}
    .st-key-postit_{i} button p {{
        color:{text_color} !important;
        font-weight:{fw} !important;
        font-size:12px !important;
        margin:0 !important;
        writing-mode:vertical-rl !important;
        text-orientation:mixed !important;
        white-space:nowrap !important;
        letter-spacing:2px !important;
    }}
    """
_postit_btn_css += "</style>"
st.markdown(_postit_btn_css, unsafe_allow_html=True)

# 사이드바에 탭 버튼 배치
TAB_SHORT_LABELS = ["회원개발", "회원활동", "회비현황", "참고"]
# 참고탭 숨김 (재요청 시 False로 변경)
HIDE_REF_TAB = True
if HIDE_REF_TAB and st.session_state.active_tab == TAB_LABELS[3]:
    st.session_state.active_tab = TAB_LABELS[0]
with st.sidebar:
    for i, label in enumerate(TAB_LABELS):
        if HIDE_REF_TAB and i == 3:
            continue
        if st.button(TAB_SHORT_LABELS[i], key=f"postit_{i}"):
            st.session_state.active_tab = label
            st.rerun()

selected_tab = st.session_state.active_tab

# 조회 조건별 1회 사전 조회 (캐시 TTL 600초와 동일 주기로 갱신)
import time as _time
_pf_key = (sel_year, sel_month)
_pf_last = st.session_state.get("_prefetch", {})
if _pf_last.get("key") != _pf_key or _time.time() - _pf_last.get("ts", 0) > 540:
    prefetch_all_tabs(sel_year, sel_month, TAB_LABELS.index(selected_tab))
    st.session_state["_prefetch"] = {"key": _pf_key, "ts": _time.time()}

if selected_tab == TAB_LABELS[0]:
    # 테이블 스타일 CSS
    st.markdown("""
    <style>
        table {
            width: 100% !important;
            border-collapse: collapse !important;
            font-size: 12px !important;
            margin-bottom: 0 !important;
        }
        th {
            background-color: #4a4a4a !important;
            color: white !important;
            padding: 6px 5px !important;
            text-align: center !important;
            border: 1px solid #ddd !important;
            font-weight: 600 !important;
            white-space: nowrap !important;
        }
        td {
            padding: 5px 5px !important;
            text-align: right !important;
            border: 1px solid #ddd !important;
            white-space: nowrap !important;
        }
        td:first-child, td:nth-child(2), td:nth-child(3) {
            text-align: left !important;
        }
    </style>
    """, unsafe_allow_html=True)

    st.caption(f"법인: 사단법인 | 개발구분: 신규/재후원/증액 | 기준: {sel_year}년 {sel_month}월")

    with st.spinner("데이터를 불러오는 중..."):
        raw_df = load_data(sel_year)

    df_all = build_summary(raw_df)

    # 허수회원 제외 적용 (회원번호 + 해당 월 기록만 제외)
    if exclude_fake and sel_year == 2025:
        exclude_set = set(EXCLUDED_MEMBERS_2025)
        df_all = df_all[~df_all.apply(lambda r: (r["MBER_NO"], r["STRD_MT"]) in exclude_set, axis=1)]

    MONTHLY_TARGET, YTD_TARGET = _build_targets(sel_year, sel_month)
    MONTHLY_MEMBER_TARGET, YTD_MEMBER_TARGET = _build_member_targets(sel_year, sel_month)

    month_start = int(f"{sel_year}{sel_month:02d}01")
    month_end = int(f"{sel_year}{sel_month:02d}31")
    ytd_start = int(f"{sel_year}0101")

    df_month = df_all[(df_all["OCCUR_DATE"] >= month_start) & (df_all["OCCUR_DATE"] <= month_end)]
    df_ytd = df_all[(df_all["OCCUR_DATE"] >= ytd_start) & (df_all["OCCUR_DATE"] <= month_end)]

    # ── 피벗 결과 사전 계산 (KPI + 테이블 공용) ──
    result_month = make_pivot(df_month, MONTHLY_TARGET)
    result_month = apply_adjustment_pivot(result_month, sel_year, sel_month, is_ytd=False)
    result_ytd = make_pivot(df_ytd, YTD_TARGET)
    result_ytd = apply_adjustment_pivot(result_ytd, sel_year, sel_month, is_ytd=True)

    # ── KPI 카드 영역 ──
    _, ANNUAL_TARGET = _build_targets(sel_year, 12)
    _all_hq_depts = ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀", "회원참여팀", "캠페인기획2팀(가두)", "사회공헌협력팀"]
    _hq_annual = sum(ANNUAL_TARGET.get(d, 0) for d in _all_hq_depts)
    _branch_annual = ANNUAL_TARGET.get("시도본부 및 지부", 0)
    _total_annual = _hq_annual + _branch_annual

    def _kpi_val(pivot_df, dept, col):
        rows = pivot_df[pivot_df["부서"] == dept]
        return float(rows[col].values[0]) if not rows.empty else 0.0

    # KPI 1: 연목표 대비 달성율
    _hq_ytd_act = _kpi_val(result_ytd, "본부 소계", "합계")
    _br_ytd_act = _kpi_val(result_ytd, "시도본부 및 지부", "합계")
    _tot_ytd_act = _hq_ytd_act + _br_ytd_act
    _hq_ann_pct = round(_hq_ytd_act / _hq_annual * 100, 1) if _hq_annual > 0 else 0
    _br_ann_pct = round(_br_ytd_act / _branch_annual * 100, 1) if _branch_annual > 0 else 0
    _tot_ann_pct = round(_tot_ytd_act / _total_annual * 100, 1) if _total_annual > 0 else 0

    # KPI 2: 당월 개발 본부/지부 구성비
    _hq_m = _kpi_val(result_month, "본부 소계", "합계")
    _br_m = _kpi_val(result_month, "시도본부 및 지부", "합계")
    _tot_m = _hq_m + _br_m
    _hq_m_pct = round(_hq_m / _tot_m * 100, 1) if _tot_m > 0 else 0
    _br_m_pct = round(_br_m / _tot_m * 100, 1) if _tot_m > 0 else 0

    # KPI 3: 당월개발 신규/증액/재후원 구성비
    _new_m = _kpi_val(result_month, "합계", "신규")
    _inc_m = _kpi_val(result_month, "합계", "증액")
    _rej_m = _kpi_val(result_month, "합계", "재후원")
    _type_tot = _new_m + _inc_m + _rej_m
    _new_pct = round(_new_m / _type_tot * 100, 1) if _type_tot > 0 else 0
    _inc_pct = round(_inc_m / _type_tot * 100, 1) if _type_tot > 0 else 0
    _rej_pct = round(_rej_m / _type_tot * 100, 1) if _type_tot > 0 else 0

    # KPI 4: 누계 개발 본부/지부 구성비
    _hq_y = _kpi_val(result_ytd, "본부 소계", "합계")
    _br_y = _kpi_val(result_ytd, "시도본부 및 지부", "합계")
    _tot_y = _hq_y + _br_y
    _hq_y_pct = round(_hq_y / _tot_y * 100, 1) if _tot_y > 0 else 0
    _br_y_pct = round(_br_y / _tot_y * 100, 1) if _tot_y > 0 else 0

    # ── KPI 카드 + 차트 렌더링 (2×2 그리드) ──
    _card_css = (
        "background:linear-gradient(160deg,#ffffff 0%,#eef4fb 100%);"
        "border:2px solid #1565C0;border-top:6px solid #1565C0;border-radius:14px;padding:18px 22px;"
        "box-shadow:0 6px 18px rgba(21,101,192,0.18);"
        "height:340px;display:flex;flex-direction:column;justify-content:space-evenly;"
    )
    _title_css = (
        "font-weight:900;font-size:19px;margin-bottom:6px;color:#0D47A1;letter-spacing:-0.3px;"
        "border-bottom:3px solid #FFB300;padding-bottom:8px;white-space:nowrap;"
    )
    _row_css = "display:flex;justify-content:space-between;align-items:center;padding:5px 2px;"
    _lbl_css = "color:#263238;font-size:18px;font-weight:700;"
    _val_css = "font-weight:900;color:#0D47A1;font-size:30px;line-height:1.1;letter-spacing:-0.5px;"
    _sub_css = "font-size:13px;color:#546E7A;margin-top:6px;line-height:1.5;"
    _sep_css = "border-top:2px solid #CFD8DC;margin-top:4px;padding-top:8px;"
    _cnt_css = "font-size:16px;color:#2E7D32;font-weight:800;line-height:1.2;margin-top:2px;"

    def _pv(pct, cnt):
        return (f'<span style="display:flex;flex-direction:column;align-items:flex-end;">'
                f'<span style="{_val_css}">{pct:.1f}%</span>'
                f'<span style="{_cnt_css}">{cnt:,.0f}건</span></span>')

    # ── Row 1: 카드 4개 ──
    _kr1, _kr2, _kr3, _kr4 = st.columns(4, gap="small")

    with _kr1:
        st.markdown(f'''<div style="{_card_css}">
          <div style="{_title_css}">연목표 대비 달성율(%)</div>
          <div style="{_row_css}"><span style="{_lbl_css}">본부</span>{_pv(_hq_ann_pct, _hq_ytd_act)}</div>
          <div style="{_row_css}"><span style="{_lbl_css}">지부</span>{_pv(_br_ann_pct, _br_ytd_act)}</div>
          <div style="{_row_css}{_sep_css}"><span style="{_lbl_css}font-weight:800;">합계</span>{_pv(_tot_ann_pct, _tot_ytd_act)}</div>
          <div style="{_sub_css}">참고) 연목표(건): 본부 {_hq_annual:,.0f} / 지부 {_branch_annual:,.0f} / 합계 {_total_annual:,.0f}</div>
        </div>''', unsafe_allow_html=True)

    with _kr2:
        st.markdown(f'''<div style="{_card_css}">
          <div style="{_title_css}">당월 개발(본부/지부)</div>
          <div style="{_row_css}"><span style="{_lbl_css}">본부</span>{_pv(_hq_m_pct, _hq_m)}</div>
          <div style="{_row_css}"><span style="{_lbl_css}">지부</span>{_pv(_br_m_pct, _br_m)}</div>
          <div style="{_sub_css}">당월 본부/지부 합계 대비 구성비</div>
        </div>''', unsafe_allow_html=True)

    with _kr3:
        st.markdown(f'''<div style="{_card_css}">
          <div style="{_title_css}">당월개발(신규/증액/재후원)</div>
          <div style="{_row_css}"><span style="{_lbl_css}">신규</span>{_pv(_new_pct, _new_m)}</div>
          <div style="{_row_css}"><span style="{_lbl_css}">증액</span>{_pv(_inc_pct, _inc_m)}</div>
          <div style="{_row_css}"><span style="{_lbl_css}">재후원</span>{_pv(_rej_pct, _rej_m)}</div>
          <div style="{_row_css}{_sep_css}"><span style="{_lbl_css}font-weight:800;">합계</span>{_pv(100.0, _type_tot)}</div>
        </div>''', unsafe_allow_html=True)

    with _kr4:
        st.markdown(f'''<div style="{_card_css}">
          <div style="{_title_css}">누계 개발(본부/지부)</div>
          <div style="{_row_css}"><span style="{_lbl_css}">본부</span>{_pv(_hq_y_pct, _hq_y)}</div>
          <div style="{_row_css}"><span style="{_lbl_css}">지부</span>{_pv(_br_y_pct, _br_y)}</div>
          <div style="{_sub_css}">누계 본부/지부 합계 대비 구성비</div>
        </div>''', unsafe_allow_html=True)

    st.markdown('<div style="height:38px"></div>', unsafe_allow_html=True)

    # ── 2개년 월별 개발실적 비교 차트 (막대: 월별 합계, 꺾은선: 당해 월별 신규/증액/재후원) ──
    _prev_year = sel_year - 1
    _prev_raw = load_data(_prev_year)
    _prev_all = build_summary(_prev_raw)
    _prev2_year = sel_year - 2
    _prev2_all = build_summary(load_data(_prev2_year))

    _bar_rows = []
    _line_rows = []
    for _m in range(1, 13):
        _m_label = f"{_m}월"
        # 전년도: 12월까지 모두 표시
        _ms_prev = int(f"{_prev_year}{_m:02d}01")
        _me_prev = int(f"{_prev_year}{_m:02d}31")
        _m_df_prev = _prev_all[(_prev_all["OCCUR_DATE"] >= _ms_prev) & (_prev_all["OCCUR_DATE"] <= _me_prev)]
        _prev_m_tot = round(float(_m_df_prev["개발건"].sum()), 1)
        _ms_prev2 = int(f"{_prev2_year}{_m:02d}01")
        _me_prev2 = int(f"{_prev2_year}{_m:02d}31")
        _prev2_m_tot = round(float(_prev2_all[(_prev2_all["OCCUR_DATE"] >= _ms_prev2) & (_prev2_all["OCCUR_DATE"] <= _me_prev2)]["개발건"].sum()), 1)
        _bar_rows.append({"월": _m_label, "연도": str(_prev_year), "개발건": _prev_m_tot, "_sort": _m,
                          "전년동월": _prev2_m_tot, "증감건": round(_prev_m_tot - _prev2_m_tot, 1),
                          "증감율": round((_prev_m_tot - _prev2_m_tot) / _prev2_m_tot * 100, 1) if _prev2_m_tot > 0 else None})
        # 당해연도: 조회월까지만
        if _m <= sel_month:
            _ms_cur = int(f"{sel_year}{_m:02d}01")
            _me_cur = int(f"{sel_year}{_m:02d}31")
            _m_df_cur = df_all[(df_all["OCCUR_DATE"] >= _ms_cur) & (df_all["OCCUR_DATE"] <= _me_cur)]
            _cur_m_tot = round(float(_m_df_cur["개발건"].sum()), 1)
            _bar_rows.append({"월": _m_label, "연도": str(sel_year), "개발건": _cur_m_tot, "_sort": _m,
                              "전년동월": _prev_m_tot, "증감건": round(_cur_m_tot - _prev_m_tot, 1),
                              "증감율": round((_cur_m_tot - _prev_m_tot) / _prev_m_tot * 100, 1) if _prev_m_tot > 0 else None})
            # 꺾은선: 당해연도 조회월까지만
            for _t in ["신규", "증액", "재후원"]:
                _v = round(float(_m_df_cur[_m_df_cur["개발구분"] == _t]["개발건"].sum()), 1)
                _pv_t = round(float(_m_df_prev[_m_df_prev["개발구분"] == _t]["개발건"].sum()), 1)
                _line_rows.append({"월": _m_label, "구분": _t, "개발건": _v, "_sort": _m,
                                   "전년동월": _pv_t, "증감건": round(_v - _pv_t, 1),
                                   "증감율": round((_v - _pv_t) / _pv_t * 100, 1) if _pv_t > 0 else None})

    _bar_df = pd.DataFrame(_bar_rows)
    _line_df = pd.DataFrame(_line_rows)
    _month_sort = [f"{m}월" for m in range(1, 13)]

    _bars = alt.Chart(_bar_df).mark_bar(cornerRadiusTopLeft=3, cornerRadiusTopRight=3, size=22).encode(
        x=alt.X("월:N", sort=_month_sort, axis=alt.Axis(labelFontSize=11, labelAngle=0, title="월")),
        xOffset=alt.XOffset("연도:N", sort=[str(_prev_year), str(sel_year)]),
        y=alt.Y("개발건:Q", axis=alt.Axis(labelFontSize=10, format=",.0f", title="개발(건)")),
        color=alt.Color("연도:N",
            scale=alt.Scale(domain=[str(_prev_year), str(sel_year)], range=["#D5D5D5", "#8B9A46"]),
            legend=alt.Legend(orient="right", titleFontSize=11, title="연도", labelFontSize=11, symbolSize=140,
                             labelExpr="datum.value + '년 합계'")),
        tooltip=[alt.Tooltip("월:N"), alt.Tooltip("연도:N"), alt.Tooltip("개발건:Q", format=",.1f", title="월별 합계"),
                 alt.Tooltip("전년동월:Q", format=",.1f", title="전년 동월(건)"),
                 alt.Tooltip("증감건:Q", format="+,.1f", title="전년 동월 대비 증감(건)"),
                 alt.Tooltip("증감율:Q", format="+.1f", title="전년 동월 대비 증감율(%)")],
    )

    _lines = alt.Chart(_line_df).mark_line(
        point=alt.OverlayMarkDef(size=160, filled=True, stroke="white", strokeWidth=1.5), strokeWidth=3
    ).encode(
        x=alt.X("월:N", sort=_month_sort),
        y=alt.Y("개발건:Q"),
        color=alt.Color("구분:N",
            scale=alt.Scale(domain=["신규", "증액", "재후원"], range=["#1565C0", "#43A047", "#FF8F00"]),
            legend=alt.Legend(orient="right", titleFontSize=11, title="구분", labelFontSize=11, symbolSize=140,
                             symbolStrokeWidth=3)),
        strokeDash=alt.StrokeDash("구분:N",
            scale=alt.Scale(domain=["신규", "증액", "재후원"], range=[[0], [6, 3], [2, 2]]),
            legend=None),
        tooltip=[alt.Tooltip("월:N"), alt.Tooltip("구분:N"), alt.Tooltip("개발건:Q", format=",.1f", title="당월"),
                 alt.Tooltip("전년동월:Q", format=",.1f", title="전년 동월(건)"),
                 alt.Tooltip("증감건:Q", format="+,.1f", title="전년 동월 대비 증감(건)"),
                 alt.Tooltip("증감율:Q", format="+.1f", title="전년 동월 대비 증감율(%)")],
    )

    st.markdown(f'<div style="font-weight:800;font-size:16px;color:#1565C0;border-bottom:3px solid #FFB300;padding-bottom:8px;margin-bottom:12px;">▼ {_prev_year}~{sel_year}년 월별 개발실적 비교 (막대: 월별합계, 선: {sel_year}년 신규/증액/재후원)</div>', unsafe_allow_html=True)

    _combo = (_bars + _lines).properties(
        width="container",
        height=320,
    ).resolve_scale(color="independent")

    st.altair_chart(_combo, use_container_width=True)

    st.markdown('<div style="height:28px"></div>', unsafe_allow_html=True)

    col1, col2 = st.columns([1, 1], gap="medium")

    # ── 1-1/1-2 팝업 데이터: 부서×개발구분별 마케팅캠페인명 상세 ──
    _PIVOT_ROW_KEYS = [
        "매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀",
        "소계_나눔마케팅본부",
        "회원참여팀", "소계_회원실",
        "캠페인기획2팀(가두)", "소계_국내사업본부",
        "사회공헌협력팀", "소계_ESG",
        "본부 소계", "시도본부 및 지부", "합계",
    ]
    _PIVOT_KEY_DEPTS = {
        "소계_나눔마케팅본부": ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀"],
        "소계_회원실": ["회원참여팀"],
        "소계_국내사업본부": ["캠페인기획2팀(가두)"],
        "소계_ESG": ["사회공헌협력팀"],
        "본부 소계": ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀", "회원참여팀", "캠페인기획2팀(가두)", "사회공헌협력팀"],
        "합계": ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀", "회원참여팀", "캠페인기획2팀(가두)", "사회공헌협력팀", "시도본부 및 지부"],
    }

    def _camp_top20(dt_df):
        # 마케팅캠페인명 기준 상위 20 + 그외 합계
        total = float(dt_df["개발건"].sum())
        if total == 0:
            return 0.0, []
        all_camps = dt_df.groupby("마케팅캠페인명").agg(
            개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
        ).sort_values("개발건", ascending=False).reset_index()
        top20 = all_camps.head(20)
        # 캠페인별 매칭 공통브랜드 (개발건 최다 브랜드)
        brnd_map = (dt_df.groupby(["마케팅캠페인명", "브랜드"])["개발건"].sum().reset_index()
                    .sort_values("개발건", ascending=False).drop_duplicates("마케팅캠페인명")
                    .set_index("마케팅캠페인명")["브랜드"].to_dict())
        cl = []
        for _, cr in top20.iterrows():
            c_val = round(float(cr["개발건"]), 1)
            cl.append({"b": str(brnd_map.get(cr["마케팅캠페인명"], "미분류")),
                       "n": str(cr["마케팅캠페인명"]), "m": int(cr["개발명"]), "c": c_val,
                       "p": round(c_val / total * 100, 1)})
        if len(all_camps) > 20:
            etc_df = dt_df[~dt_df["마케팅캠페인명"].isin(top20["마케팅캠페인명"])]
            etc_c = round(float(etc_df["개발건"].sum()), 1)
            cl.append({"b": "", "n": "그외", "m": int(etc_df["MBER_NO"].nunique()), "c": etc_c,
                       "p": round(etc_c / total * 100, 1), "etc": True})
        return total, cl

    def _popup_entry(name, dt_df, prev_dt_df):
        total, cl = _camp_top20(dt_df)
        ptotal, pcl = _camp_top20(prev_dt_df)
        return {"name": name, "total": round(total, 1), "camps": cl,
                "ptotal": round(ptotal, 1), "pcamps": pcl}

    def _build_dept_popup(df, prev_df, prefix):
        popup = {}
        for pk in _PIVOT_ROW_KEYS:
            depts = _PIVOT_KEY_DEPTS.get(pk, [pk])
            sub_df = df[df["부서"].isin(depts)]
            prev_sub = prev_df[prev_df["부서"].isin(depts)]
            for dt in ["신규", "재후원", "증액"]:
                dt_df = sub_df[sub_df["개발구분"] == dt]
                if float(dt_df["개발건"].sum()) == 0:
                    continue
                label = pk.replace("소계_", "") if pk.startswith("소계_") else pk
                popup[f"{prefix}|{pk}|{dt}"] = _popup_entry(f"{label} > {dt}", dt_df, prev_sub[prev_sub["개발구분"] == dt])
        return popup

    # 전년 동기 데이터 (당월 → 전년 동월, 누계 → 전년 동기 누계)
    _py_month_start = int(f"{sel_year - 1}{sel_month:02d}01")
    _py_month_end = int(f"{sel_year - 1}{sel_month:02d}31")
    _py_ytd_start = int(f"{sel_year - 1}0101")
    _py_df_month = _prev_all[(_prev_all["OCCUR_DATE"] >= _py_month_start) & (_prev_all["OCCUR_DATE"] <= _py_month_end)]
    _py_df_ytd = _prev_all[(_prev_all["OCCUR_DATE"] >= _py_ytd_start) & (_prev_all["OCCUR_DATE"] <= _py_month_end)]

    _dept_popup = {}
    _dept_popup.update(_build_dept_popup(df_month, _py_df_month, "m"))
    _dept_popup.update(_build_dept_popup(df_ytd, _py_df_ytd, "y"))

    # ── 1-3/1-4 팝업 데이터: 회원구분×본부지부×개발구분별 ──
    _MEM_ROW_KEYS = ["신규회원_본부", "신규회원_시도본부", "신규회원_소계", "기존회원", "mem_합계"]
    def _build_mem_popup(df, prev_df, prefix):
        popup = {}
        def _with_hq(d):
            d = d.copy()
            d["_hq"] = d["부서"].apply(lambda x: "시도본부 및 지부" if x == "시도본부 및 지부" else "본부")
            return d
        tdf, pdf = _with_hq(df), _with_hq(prev_df)
        _MFILT = {
            "신규회원_본부": lambda d: d[(d["회원구분"] == "신규회원") & (d["_hq"] == "본부")],
            "신규회원_시도본부": lambda d: d[(d["회원구분"] == "신규회원") & (d["_hq"] == "시도본부 및 지부")],
            "신규회원_소계": lambda d: d[d["회원구분"] == "신규회원"],
            "기존회원": lambda d: d[d["회원구분"] == "기존회원"],
            "mem_합계": lambda d: d,
        }
        for pk, filt in _MFILT.items():
            sub_df, prev_sub = filt(tdf), filt(pdf)
            for dt in ["신규", "재후원", "증액"]:
                dt_df = sub_df[sub_df["개발구분"] == dt]
                if float(dt_df["개발건"].sum()) == 0:
                    continue
                label = pk.replace("mem_", "").replace("_", " > ")
                popup[f"{prefix}|{pk}|{dt}"] = _popup_entry(f"{label} > {dt}", dt_df, prev_sub[prev_sub["개발구분"] == dt])
        return popup

    _dept_popup.update(_build_mem_popup(df_month, _py_df_month, "mm"))
    _dept_popup.update(_build_mem_popup(df_ytd, _py_df_ytd, "my"))

    def _render_pivot_html(pivot_df, prefix):
        th = "background:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px"
        html = '<table style="width:100%;border-collapse:collapse;font-size:12px">'
        html += '<thead><tr>'
        for col in pivot_df.columns:
            html += f'<th style="{th}">{col}</th>'
        html += '</tr></thead><tbody>'
        for idx, (_, row) in enumerate(pivot_df.iterrows()):
            dept = row["부서"]
            is_total = dept == "합계"
            is_sub = dept in ("소계", "본부 소계")
            if is_total:
                rs = "background:#222;color:white;font-weight:bold;"
            elif is_sub:
                rs = "background:#d9d9d9;font-weight:bold;"
            else:
                rs = ""
            pk = _PIVOT_ROW_KEYS[idx] if idx < len(_PIVOT_ROW_KEYS) else dept
            html += '<tr>'
            for col in pivot_df.columns:
                val = row[col]
                td = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{rs}"
                if col == "목표(건)" and not is_total and not is_sub:
                    td += "background-color:#808000;color:white;"
                if col in ("신규", "재후원", "증액"):
                    fk = f"{prefix}|{pk}|{col}"
                    if fk in _dept_popup and float(val) != 0:
                        html += f'<td data-dept-popup="{fk}" style="{td}text-align:right;cursor:pointer" title="클릭 시 상세보기">{val:,.1f}</td>'
                    else:
                        html += f'<td style="{td}text-align:right">{val:,.1f}</td>'
                elif col == "목표(건)":
                    html += f'<td style="{td}text-align:right">{val:,.0f}</td>'
                elif col == "합계":
                    html += f'<td style="{td}text-align:right">{val:,.1f}</td>'
                elif col == "달성율(%)":
                    html += f'<td style="{td}text-align:right">{val:.1f}%</td>'
                else:
                    html += f'<td style="{td}text-align:left">{val}</td>'
            html += '</tr>'
        html += '</tbody></table>'
        return html

    def _render_mem_html(pivot_df, prefix):
        th = "background:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px"
        html = '<table style="width:100%;border-collapse:collapse;font-size:12px">'
        html += '<thead><tr>'
        for col in pivot_df.columns:
            html += f'<th style="{th}">{col}</th>'
        html += '</tr></thead><tbody>'
        for idx, (_, row) in enumerate(pivot_df.iterrows()):
            label = row["본부/지부"]
            is_total = label == "합계"
            is_sub = "소계" in str(label)
            if is_total:
                rs = "background:#222;color:white;font-weight:bold;"
            elif is_sub:
                rs = "background:#d9d9d9;font-weight:bold;"
            else:
                rs = ""
            pk = _MEM_ROW_KEYS[idx] if idx < len(_MEM_ROW_KEYS) else ""
            html += '<tr>'
            for col in pivot_df.columns:
                val = row[col]
                td = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{rs}"
                if col == "목표(건)" and not is_total and not is_sub:
                    td += "background-color:#808000;color:white;"
                if col in ("신규", "재후원", "증액"):
                    fk = f"{prefix}|{pk}|{col}"
                    if fk in _dept_popup and float(val) != 0:
                        html += f'<td data-dept-popup="{fk}" style="{td}text-align:right;cursor:pointer" title="클릭 시 상세보기">{val:,.1f}</td>'
                    else:
                        html += f'<td style="{td}text-align:right">{val:,.1f}</td>'
                elif col == "목표(건)":
                    html += f'<td style="{td}text-align:right">{val:,.0f}</td>'
                elif col == "합계":
                    html += f'<td style="{td}text-align:right">{val:,.1f}</td>'
                elif col == "달성율(%)":
                    html += f'<td style="{td}text-align:right">{val:.1f}%</td>'
                else:
                    html += f'<td style="{td}text-align:left">{val}</td>'
            html += '</tr>'
        html += '</tbody></table>'
        return html

    with col1:
        st.subheader("1-1. 회원개발 현황(당월)")
        st.caption("💡 신규/재후원/증액 숫자 클릭 시 캠페인 상세를 확인할 수 있습니다.")
        st.markdown(_render_pivot_html(result_month, "m"), unsafe_allow_html=True)
        st.caption("출처: BRONZE_CRM — MSTR FN_MM_SPNSR_DVLP 로직 재현 (신규/재후원: 해지일필터+월합양수, 증액: 순액배분)")

    with col2:
        st.subheader("1-2. 회원개발현황(누계)")
        st.caption("💡 신규/재후원/증액 숫자 클릭 시 캠페인 상세를 확인할 수 있습니다.")
        st.markdown(_render_pivot_html(result_ytd, "y"), unsafe_allow_html=True)
        st.caption("출처: BRONZE_CRM — MSTR FN_MM_SPNSR_DVLP 로직 재현 (신규/재후원: 해지일필터+월합양수, 증액: 순액배분)")

    # ── 1-1/1-2 분석 차트 (연목표 진척율 · 개발유형 구성비 · 월별 추이) ──
    st.markdown('<div style="height:28px"></div>', unsafe_allow_html=True)

    _CHART_DEPTS = ["매체운영팀", "마케팅기획1팀", "마케팅기획2팀", "컬쳐콘텐츠팀",
                    "회원참여팀", "캠페인기획2팀(가두)", "사회공헌협력팀", "시도본부 및 지부"]
    _PASTEL_BLUE = "#A8D8EA"
    _PASTEL_ORANGE = "#FFD3B6"
    _PASTEL_GREEN = "#D5E8D4"
    _PASTEL_TEAL = "#88C9BF"
    _PASTEL_PINK = "#F2B5D4"
    _PASTEL_GRAY = "#C8C8C8"

    _an_c1, _an_c2 = st.columns(2, gap="medium")

    # ── 차트 1: 연목표 대비 누계 달성율 ──
    with _an_c1:
        st.caption("▼ 연목표 대비 누계 달성율(%)")
        _ytd_total = sum(YTD_TARGET.get(d, 0) for d in _CHART_DEPTS)
        _ann_total = sum(ANNUAL_TARGET.get(d, 0) for d in _CHART_DEPTS)
        _pacing_pct = round(_ytd_total / _ann_total * 100, 1) if _ann_total > 0 else 0
        _pace_rows = []
        for _d in _CHART_DEPTS:
            _r = result_ytd[result_ytd["부서"] == _d]
            _act = float(_r["합계"].values[0]) if not _r.empty else 0
            _ann = ANNUAL_TARGET.get(_d, 0)
            _p = round(_act / _ann * 100, 1) if _ann > 0 else 0
            _pace_rows.append({"부서": _d, "달성율": _p, "라벨": f"{_p:.1f}%", "연목표": round(_ann, 1),
                               "누계실적": round(_act, 1), "구분": "부서"})
        # 전체 합계 (8개 부서 합)
        _act_all = sum(r["누계실적"] for r in _pace_rows)
        _p_all = round(_act_all / _ann_total * 100, 1) if _ann_total > 0 else 0
        _pace_rows.append({"부서": "전체 합계", "달성율": _p_all, "라벨": f"{_p_all:.1f}%", "연목표": round(_ann_total, 1),
                           "누계실적": round(_act_all, 1), "구분": "합계"})
        _pace_order = _CHART_DEPTS + ["전체 합계"]
        _pace_df = pd.DataFrame(_pace_rows)
        _pace_bar = alt.Chart(_pace_df).mark_bar(cornerRadiusEnd=5, size=30).encode(
            color=alt.Color("구분:N", scale=alt.Scale(domain=["부서", "합계"], range=[_PASTEL_TEAL, "#2E6F62"]), legend=None),
            y=alt.Y("부서:N", sort=_pace_order, axis=alt.Axis(labelFontSize=14, labelFontWeight="bold", labelLimit=200), title=None),
            x=alt.X("달성율:Q", axis=alt.Axis(labelFontSize=13, titleFontSize=13, format=".0f", title="달성(%)"), scale=alt.Scale(domain=[0, max(max(r["달성율"] for r in _pace_rows) * 1.15, _pacing_pct * 1.15)])),
            tooltip=[alt.Tooltip("부서:N"), alt.Tooltip("누계실적:Q", title="누계실적(건)", format=",.1f"),
                     alt.Tooltip("연목표:Q", title="연목표(건)", format=",.1f"), alt.Tooltip("라벨:N", title="달성율")],
        )
        _pace_text = alt.Chart(_pace_df).mark_text(align="left", dx=6, fontSize=15, fontWeight="bold", color="#3a7d6e").encode(
            y=alt.Y("부서:N", sort=_pace_order),
            x=alt.X("달성율:Q"),
            text="라벨:N",
        )
        _pace_rule = alt.Chart(pd.DataFrame({"x": [_pacing_pct]})).mark_rule(
            strokeDash=[6, 4], strokeWidth=3, color="#E57373"
        ).encode(x="x:Q")
        _pace_label = alt.Chart(pd.DataFrame({"x": [_pacing_pct], "label": [f"기대 {_pacing_pct:.0f}%"]})).mark_text(
            align="left", dx=6, dy=-10, fontSize=14, fontWeight="bold", color="#E57373"
        ).encode(x="x:Q", text="label:N")
        st.altair_chart((_pace_bar + _pace_text + _pace_rule + _pace_label).properties(height=480), use_container_width=True)

        # ── 시도본부 및 지부 세부 부서별 팝업 (당월 + 누계) ──
        _sido_ytd = df_ytd[df_ytd["부서"] == "시도본부 및 지부"]
        _sido_month = df_month[df_month["부서"] == "시도본부 및 지부"]
        if not _sido_ytd.empty:
            _sido_ytd_agg = _sido_ytd.groupby("DEPT_NAME").agg(
                누계명=("MBER_NO", "nunique"), 누계건=("개발건", "sum")
            ).reset_index()
            _sido_month_agg = _sido_month.groupby("DEPT_NAME").agg(
                당월명=("MBER_NO", "nunique"), 당월건=("개발건", "sum")
            ).reset_index() if not _sido_month.empty else pd.DataFrame(columns=["DEPT_NAME", "당월명", "당월건"])
            _sido_merged = _sido_ytd_agg.merge(_sido_month_agg, on="DEPT_NAME", how="left").fillna(0)
            _sido_merged = _sido_merged.sort_values("당월건", ascending=False).reset_index(drop=True)
            _sido_ytd_total = float(_sido_merged["누계건"].sum())
            _sido_month_total = float(_sido_merged["당월건"].sum())
            def _top_camp(_d):
                # 부서별 개발건 최다 마케팅캠페인명
                if _d.empty:
                    return {}
                _g = _d.groupby(["DEPT_NAME", "마케팅캠페인명"])["개발건"].sum().reset_index()
                _g = _g.sort_values("개발건", ascending=False).drop_duplicates("DEPT_NAME")
                return {r["DEPT_NAME"]: (str(r["마케팅캠페인명"]), round(float(r["개발건"]), 1)) for _, r in _g.iterrows()}
            _sido_top_m = _top_camp(_sido_month)
            _sido_top_y = _top_camp(_sido_ytd)
            _sido_popup_rows = []
            for _, _sr in _sido_merged.iterrows():
                _yc = round(float(_sr["누계건"]), 1)
                _yp = round(_yc / _sido_ytd_total * 100, 1) if _sido_ytd_total > 0 else 0
                _mc = round(float(_sr["당월건"]), 1)
                _mp = round(_mc / _sido_month_total * 100, 1) if _sido_month_total > 0 else 0
                _sido_popup_rows.append({
                    "n": str(_sr["DEPT_NAME"]) if _sr["DEPT_NAME"] else "미분류",
                    "mm": int(_sr["당월명"]), "mc": _mc, "mp": _mp,
                    "ym": int(_sr["누계명"]), "yc": _yc, "yp": _yp,
                    "mt": _sido_top_m.get(_sr["DEPT_NAME"], ("-", 0))[0], "mtc": _sido_top_m.get(_sr["DEPT_NAME"], ("-", 0))[1],
                    "yt": _sido_top_y.get(_sr["DEPT_NAME"], ("-", 0))[0], "ytc": _sido_top_y.get(_sr["DEPT_NAME"], ("-", 0))[1],
                })
            import json as _json_sido
            _sido_json = _json_sido.dumps({
                "ytd_total": round(_sido_ytd_total, 1),
                "month_total": round(_sido_month_total, 1),
                "rows": _sido_popup_rows
            }, ensure_ascii=False)
            stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._sidoPopupCleanup){{try{{doc._sidoPopupCleanup()}}catch(e){{}}}}
var D={_sido_json};
var ov=doc.getElementById('sido-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='sido-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="sido-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:1250px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st=doc.createElement('style');st.id='sido-popup-style';
var oldSt=doc.getElementById('sido-popup-style');if(oldSt)oldSt.remove();
st.textContent='@keyframes sidopop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#sido-popup-box{{animation:sidopop .2s ease}}';
doc.head.appendChild(st);
doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
function render(){{
  var box=doc.getElementById('sido-popup-box');
  var th='background:#f0f2f5;padding:5px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px';
  var h='<div style="background:linear-gradient(135deg,#1a5276,#2471a3);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">시도본부 및 지부 세부현황</span>';
  h+='<span id="sido-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div>';
  h+='<div style="padding:18px 22px">';
  h+='<div style="overflow-x:auto">';
  h+='<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:12px"><thead>';
  h+='<tr><th rowspan="2" style="'+th+';width:30px">순위</th>';
  h+='<th rowspan="2" style="'+th+';text-align:left;min-width:100px">부서명</th>';
  h+='<th colspan="4" style="'+th+';background:#e3f2fd">당월 ('+D.month_total.toLocaleString(undefined,{{minimumFractionDigits:1}})+'건)</th>';
  h+='<th colspan="4" style="'+th+';background:#fff3e0">누계 ('+D.ytd_total.toLocaleString(undefined,{{minimumFractionDigits:1}})+'건)</th></tr>';
  h+='<tr>';
  h+='<th style="'+th+';background:#e3f2fd;width:55px">개발명</th><th style="'+th+';background:#e3f2fd;width:65px">개발건</th><th style="'+th+';background:#e3f2fd;width:55px">구성비</th><th style="'+th+';background:#e3f2fd;min-width:150px">최다 마케팅캠페인</th>';
  h+='<th style="'+th+';background:#fff3e0;width:55px">개발명</th><th style="'+th+';background:#fff3e0;width:65px">개발건</th><th style="'+th+';background:#fff3e0;width:55px">구성비</th><th style="'+th+';background:#fff3e0;min-width:150px">최다 마케팅캠페인</th>';
  h+='</tr></thead><tbody>';
  var tmm=0,tmc=0,tym=0,tyc=0;
  for(var i=0;i<D.rows.length;i++){{
    var r=D.rows[i];tmm+=r.mm;tmc+=r.mc;tym+=r.ym;tyc+=r.yc;
    var bg=i%2===0?'#fff':'#fafafa';
    var td='padding:4px 6px;border:1px solid #eee;';
    h+='<tr style="background:'+bg+'">';
    h+='<td style="'+td+'text-align:center">'+(i+1)+'</td>';
    var medal=i===0?'🥇 ':i===1?'🥈 ':i===2?'🥉 ':'';
    h+='<td style="'+td+'text-align:left;white-space:nowrap;'+(i<3?'font-weight:700;':'')+'">'+medal+r.n+'</td>';
    h+='<td style="'+td+'text-align:right">'+r.mm.toLocaleString()+'</td>';
    h+='<td style="'+td+'text-align:right;font-weight:600">'+r.mc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="'+td+'text-align:right">'+r.mp.toFixed(1)+'%</td>';
    h+='<td style="'+td+'text-align:left;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+r.mt+'">'+r.mt+(r.mtc?' <span style="color:#2E7D32;font-weight:700">('+r.mtc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건)</span>':'')+'</td>';
    h+='<td style="'+td+'text-align:right">'+r.ym.toLocaleString()+'</td>';
    h+='<td style="'+td+'text-align:right;font-weight:600">'+r.yc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="'+td+'text-align:right">'+r.yp.toFixed(1)+'%</td>';
    h+='<td style="'+td+'text-align:left;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+r.yt+'">'+r.yt+(r.ytc?' <span style="color:#2E7D32;font-weight:700">('+r.ytc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건)</span>':'')+'</td>';
    h+='</tr>';
  }}
  var tds='padding:5px 6px;border:1px solid #555;text-align:right;';
  h+='<tr style="background:#222;color:#fff;font-weight:700">';
  h+='<td style="'+tds+'text-align:center" colspan="2">합계</td>';
  h+='<td style="'+tds+'">'+tmm.toLocaleString()+'</td>';
  h+='<td style="'+tds+'">'+tmc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
  h+='<td style="'+tds+'">'+(D.month_total>0?(tmc/D.month_total*100).toFixed(1):'0.0')+'%</td><td style="'+tds+'"></td>';
  h+='<td style="'+tds+'">'+tym.toLocaleString()+'</td>';
  h+='<td style="'+tds+'">'+tyc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
  h+='<td style="'+tds+'">'+(D.ytd_total>0?(tyc/D.ytd_total*100).toFixed(1):'0.0')+'%</td><td style="'+tds+'"></td>';
  h+='</tr></tbody></table></div></div>';
  box.innerHTML=h;box.scrollTop=0;
  doc.getElementById('sido-close-btn').addEventListener('click',function(){{ov.style.display='none'}});
}}
function hasSido(el){{
  if(!el)return false;
  var a=el.getAttribute&&(el.getAttribute('aria-label')||'');
  if(a.indexOf('시도본부')>=0)return true;
  var t=el.textContent||'';
  if(t.indexOf('시도본부')>=0)return true;
  var title=el.querySelector&&el.querySelector('title');
  if(title&&title.textContent.indexOf('시도본부')>=0)return true;
  return false;
}}
function onClick(e){{
  var el=e.target;
  // 다른 팝업(1-1/1-2 테이블 등)의 클릭 영역이면 무시
  var chk=el;
  for(var k=0;k<5&&chk;k++){{
    if(chk.getAttribute&&(chk.getAttribute('data-dept-popup')||chk.getAttribute('data-cat-popup')))return;
    if(chk.tagName&&chk.tagName.toLowerCase()==='table')return;
    chk=chk.parentNode;
  }}
  // SVG 차트 내부 클릭만 처리
  var svgParent=el.closest&&el.closest('svg');
  if(!svgParent)return;
  if(hasSido(el)){{render();ov.style.display='flex';return;}}
  var p=el.parentNode;
  for(var i=0;i<3&&p;i++){{
    if(hasSido(p)){{render();ov.style.display='flex';return;}}
    p=p.parentNode;
  }}
  if(el.tagName&&(el.tagName.toLowerCase()==='path'||el.tagName.toLowerCase()==='rect')){{
    var labels=svgParent.querySelectorAll('text');
    var elRect=el.getBoundingClientRect();
    var elCenterY=elRect.top+elRect.height/2;
    for(var j=0;j<labels.length;j++){{
      var lb=labels[j];
      var lbRect=lb.getBoundingClientRect();
      if(Math.abs(lbRect.top+lbRect.height/2-elCenterY)<20){{
        if(lb.textContent.indexOf('시도본부')>=0){{render();ov.style.display='flex';return;}}
      }}
    }}
  }}
}}
doc.addEventListener('click',onClick);
doc._sidoPopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('sido-popup-overlay');if(o)o.remove();var s=doc.getElementById('sido-popup-style');if(s)s.remove();}};
}})();
</script>""", height=0)
            st.caption("💡 '시도본부 및 지부' 막대를 클릭하면 세부 부서별 현황을 볼 수 있습니다.")

    # ── 차트 2: 당월 개발유형 구성비 ──
    with _an_c2:
        st.caption("▼ 당월 부서별 개발유형 구성비(%)")
        _comp_rows = []
        for _d in _CHART_DEPTS:
            _r = result_month[result_month["부서"] == _d]
            if not _r.empty:
                _tot = float(_r["합계"].values[0])
                if _tot > 0:
                    for _typ in ["신규", "재후원", "증액"]:
                        _v = float(_r[_typ].values[0])
                        _comp_rows.append({"부서": _d, "유형": _typ, "비율": round(_v / _tot * 100, 1), "라벨": f"{round(_v / _tot * 100)}%"})
                else:
                    for _typ in ["신규", "재후원", "증액"]:
                        _comp_rows.append({"부서": _d, "유형": _typ, "비율": 0, "라벨": ""})
        if _comp_rows:
            _comp_df = pd.DataFrame(_comp_rows)
            _comp_chart = alt.Chart(_comp_df).mark_bar(cornerRadiusEnd=3, size=30).encode(
                y=alt.Y("부서:N", sort=_CHART_DEPTS, axis=alt.Axis(labelFontSize=14, labelFontWeight="bold", labelLimit=200), title=None),
                x=alt.X("비율:Q", stack="normalize", axis=alt.Axis(format="%", title=None, labelFontSize=13), scale=alt.Scale(domain=[0, 1])),
                color=alt.Color("유형:N", scale=alt.Scale(domain=["신규", "재후원", "증액"], range=[_PASTEL_BLUE, _PASTEL_ORANGE, _PASTEL_GREEN]),
                                legend=alt.Legend(orient="bottom", titleFontSize=0, labelFontSize=14, symbolSize=200)),
                tooltip=[alt.Tooltip("부서:N"), alt.Tooltip("유형:N"), alt.Tooltip("비율:Q", format=".1f", title="구성비(%)")],
                order=alt.Order("유형:N", sort="ascending"),
            ).properties(height=480)
            _comp_text = alt.Chart(_comp_df[_comp_df["비율"] >= 10]).mark_text(fontSize=14, fontWeight="bold", color="#333").encode(
                y=alt.Y("부서:N", sort=_CHART_DEPTS),
                x=alt.X("비율:Q", stack="normalize"),
                text="라벨:N",
                order=alt.Order("유형:N", sort="ascending"),
            )
            st.altair_chart(_comp_chart + _comp_text, use_container_width=True)

    # Vega-Lite 툴팁 커스텀 스타일 (parent document에 JS로 주입)
    stc.html("""<script>
(function(){
var doc = window.parent.document;
// vega-bindings 숨기기
var vbStyle = doc.getElementById('vg-bindings-hide');
if(!vbStyle){vbStyle=doc.createElement('style');vbStyle.id='vg-bindings-hide';vbStyle.textContent='.vega-bindings,.vega-bind{display:none!important;height:0!important;overflow:hidden!important;}';doc.head.appendChild(vbStyle);}
// iframe 내부에도 적용
document.querySelectorAll('iframe').forEach(function(f){try{var fd=f.contentDocument;if(fd){var s=fd.getElementById('vg-bindings-hide');if(!s){s=fd.createElement('style');s.id='vg-bindings-hide';s.textContent='.vega-bindings,.vega-bind{display:none!important;height:0!important;overflow:hidden!important;}';fd.head.appendChild(s);}}}catch(e){}});
var oldStyle = doc.getElementById('vg-tooltip-custom-style');
if(oldStyle) oldStyle.remove();
var style = doc.createElement('style');
style.id = 'vg-tooltip-custom-style';
style.textContent = `
#vg-tooltip-element.vg-tooltip {
    font-family: 'Pretendard', 'Apple SD Gothic Neo', sans-serif !important;
    background: linear-gradient(135deg, #1e293b 0%, #334155 100%) !important;
    color: #f1f5f9 !important;
    border: none !important;
    border-radius: 12px !important;
    padding: 16px 20px !important;
    box-shadow: 0 10px 40px rgba(0,0,0,0.3), 0 2px 10px rgba(0,0,0,0.15) !important;
    font-size: 12px !important;
    line-height: 1.8 !important;
    max-width: 560px !important;
    min-width: 220px !important;
    backdrop-filter: blur(10px) !important;
    white-space: normal !important;
    word-break: keep-all !important;
    z-index: 999999 !important;
}
#vg-tooltip-element.vg-tooltip table {
    border-collapse: separate !important;
    border-spacing: 0 4px !important;
    width: 100% !important;
}
#vg-tooltip-element.vg-tooltip td.key {
    color: #94a3b8 !important;
    font-weight: 500 !important;
    font-size: 11px !important;
    padding-right: 14px !important;
    vertical-align: top !important;
    white-space: nowrap !important;
}
#vg-tooltip-element.vg-tooltip td.value {
    color: #ffffff !important;
    font-weight: 700 !important;
    font-size: 12px !important;
    white-space: normal !important;
    word-break: keep-all !important;
    max-width: 420px !important;
    line-height: 1.6 !important;
}
#vg-tooltip-element.vg-tooltip tr:first-child td {
    padding-top: 2px !important;
}
#vg-tooltip-element.vg-tooltip tr:last-child td {
    padding-bottom: 2px !important;
    border-top: 1px solid rgba(148,163,184,0.25) !important;
    padding-top: 8px !important;
}
`;
doc.head.appendChild(style);
})();
</script>""", height=0)

    st.markdown('<div style="height:12px"></div>', unsafe_allow_html=True)

    # ── JS 팝업: 부서×개발구분 캠페인 상세 ──
    import json as _json11
    _dpjson = _json11.dumps(_dept_popup, ensure_ascii=False)
    stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._deptPopupCleanup){{try{{doc._deptPopupCleanup()}}catch(e){{}}}}
var D={_dpjson};
var ov=doc.getElementById('dept-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='dept-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="dept-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:1300px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st=doc.createElement('style');st.id='dept-popup-style';
var oldSt=doc.getElementById('dept-popup-style');if(oldSt)oldSt.remove();
st.textContent='@keyframes deptpop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#dept-popup-box{{animation:deptpop .2s ease}}td[data-dept-popup]{{cursor:pointer}}td[data-dept-popup]:hover{{background:rgba(102,126,234,0.12) !important}}';
doc.head.appendChild(st);
doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
var box=doc.getElementById('dept-popup-box');
function campTable(title,list,total,c1,c2){{
  var th='background:#f0f2f5;padding:5px 8px;border:1px solid #e0e0e0;white-space:nowrap;';
  var t='<div style="font-size:13px;font-weight:700;color:'+c1+';margin-bottom:8px;border-bottom:2px solid '+c2+';padding-bottom:5px">'+title+'</div>';
  if(!list.length){{return t+'<div style="padding:16px;text-align:center;color:#999;font-size:12px">데이터 없음</div>';}}
  t+='<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:12px"><thead><tr>';
  t+='<th style="'+th+'text-align:center;width:30px">순위</th>';
  t+='<th style="'+th+'text-align:left;width:80px">공통브랜드</th>';
  t+='<th style="'+th+'text-align:left">마케팅캠페인명</th>';
  t+='<th style="'+th+'text-align:right;width:60px">개발(명)</th>';
  t+='<th style="'+th+'text-align:right;width:70px">개발(건)</th>';
  t+='<th style="'+th+'text-align:right;width:62px">구성비(%)</th>';
  t+='</tr></thead><tbody>';
  var tm=0,tc=0;
  for(var i=0;i<list.length;i++){{
    var c=list[i];var isEtc=c.etc===true;tm+=c.m;tc+=c.c;
    var bg=isEtc?'#f5f0e0;font-style:italic':i%2===0?'#fff':'#fafafa';
    t+='<tr style="background:'+bg+'"><td style="padding:4px 8px;text-align:center;border:1px solid #eee">'+(isEtc?'':String(i+1))+'</td>';
    t+='<td style="padding:4px 8px;text-align:left;border:1px solid #eee;color:#666;white-space:nowrap">'+(c.b||'')+'</td>';
    t+='<td style="padding:4px 8px;text-align:left;border:1px solid #eee;max-width:260px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+c.n+'</td>';
    t+='<td style="padding:4px 8px;text-align:right;border:1px solid #eee">'+c.m.toLocaleString()+'</td>';
    t+='<td style="padding:4px 8px;text-align:right;border:1px solid #eee;font-weight:600">'+c.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    t+='<td style="padding:4px 8px;text-align:right;border:1px solid #eee">'+c.p.toFixed(1)+'%</td></tr>';
  }}
  var tp=total>0?(tc/total*100):0;
  var tf='padding:4px 8px;text-align:right;border:1px solid #555';
  t+='<tr style="background:#222;color:#fff;font-weight:700"><td style="padding:4px 8px;text-align:center;border:1px solid #555" colspan="3">합계</td>';
  t+='<td style="'+tf+'">'+tm.toLocaleString()+'</td>';
  t+='<td style="'+tf+'">'+tc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
  t+='<td style="'+tf+'">'+tp.toFixed(1)+'%</td></tr>';
  return t+'</tbody></table>';
}}
function render(key){{
  var d=D[key];if(!d)return;
  box._currentKey=key;
  var h='<div style="background:linear-gradient(135deg,#1a5276,#2471a3);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.name+' ('+d.total.toLocaleString(undefined,{{minimumFractionDigits:1}})+'건)</span>';
  h+='<div style="display:flex;align-items:center;gap:10px">';
  h+='<button id="dept-download-btn" style="padding:4px 12px;font-size:11px;border:1px solid #fff;border-radius:4px;background:rgba(255,255,255,0.15);color:#fff;cursor:pointer;white-space:nowrap">엑셀 다운로드</button>';
  h+='<span id="dept-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div></div>';
  var isYtd=key.indexOf('y|')===0||key.indexOf('my|')===0;
  var prevLbl=isYtd?'전년 동기 누계':'전년 동월';
  h+='<div style="padding:18px 22px;display:flex;gap:18px;align-items:flex-start">';
  h+='<div style="flex:1.15;min-width:0">'+campTable('마케팅캠페인별 현황 (상위 20)',d.camps,d.total,'#1a5276','#2471a3')+'</div>';
  h+='<div style="flex:1;min-width:0">'+campTable('참고) '+prevLbl+' 마케팅캠페인별 현황 (상위 20, '+d.ptotal.toLocaleString(undefined,{{minimumFractionDigits:1}})+'건)',d.pcamps||[],d.ptotal||0,'#6d4c41','#a1887f')+'</div>';
  h+='</div>';
  box.innerHTML=h;box.scrollTop=0;
  doc.getElementById('dept-close-btn').addEventListener('click',function(){{ov.style.display='none'}});
  doc.getElementById('dept-download-btn').addEventListener('click',function(){{
    var dd=D[box._currentKey];if(!dd)return;
    var rows=[];
    function pushSec(title,list,total){{
      rows.push([title]);
      rows.push(['순위','공통브랜드','마케팅캠페인명','개발(명)','개발(건)','구성비(%)']);
      var ttm=0,ttc=0;
      for(var j=0;j<list.length;j++){{
        var cc=list[j];ttm+=cc.m;ttc+=cc.c;
        rows.push([cc.etc?'그외':String(j+1),cc.b||'',cc.n,cc.m,cc.c.toFixed(1),cc.p.toFixed(1)+'%']);
      }}
      rows.push(['합계','','',ttm,ttc.toFixed(1),(total>0?(ttc/total*100):0).toFixed(1)+'%']);
      rows.push([]);
    }}
    pushSec('당해 '+dd.name,dd.camps,dd.total);
    pushSec(prevLbl+' (참고)',dd.pcamps||[],dd.ptotal||0);
    var csv='\\uFEFF';
    rows.forEach(function(r){{csv+=r.map(function(v){{var s=String(v==null?'':v);if(s.indexOf(',')>=0||s.indexOf('"')>=0)return '"'+s.replace(/"/g,'""')+'"';return s}}).join(',')+\"\\n\"}});
    var blob=new Blob([csv],{{type:'text/csv;charset=utf-8'}});
    var a=document.createElement('a');a.href=URL.createObjectURL(blob);
    a.download=dd.name.replace(/[\\\\/:*?"<>|]/g,'_')+'_캠페인상세.csv';a.click();URL.revokeObjectURL(a.href);
  }});
}}
function onClick(e){{
  var td=e.target.closest('td[data-dept-popup]');
  if(td){{var key=td.getAttribute('data-dept-popup');if(D[key]){{render(key);ov.style.display='flex';}}}}
}}
doc.addEventListener('click',onClick);
doc._deptPopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('dept-popup-overlay');if(o)o.remove();var s=doc.getElementById('dept-popup-style');if(s)s.remove();}};
}})();
</script>""", height=0)

    st.divider()

    # ── 2개년 월별 신규/기존 회원 개발실적 비교 차트 ──
    _mem_bar_rows = []
    _mem_line_rows = []
    _yr_df_map = {_prev2_year: _prev2_all, _prev_year: _prev_all, sel_year: df_all}

    def _mem_month_vals(_yr, _m):
        _ms = int(f"{_yr}{_m:02d}01")
        _me = int(f"{_yr}{_m:02d}31")
        _df_full = _yr_df_map[_yr]
        _mdf = _df_full[(_df_full["OCCUR_DATE"] >= _ms) & (_df_full["OCCUR_DATE"] <= _me)]
        _is_br = _mdf["부서"] == "시도본부 및 지부"
        _is_new = _mdf["회원구분"] == "신규회원"
        _is_old = _mdf["회원구분"] == "기존회원"
        return {
            "신규": round(float(_mdf[_is_new]["개발건"].sum()), 1),
            "기존": round(float(_mdf[_is_old]["개발건"].sum()), 1),
            "신규본부": round(float(_mdf[_is_new & ~_is_br]["개발건"].sum()), 1),
            "신규지부": round(float(_mdf[_is_new & _is_br]["개발건"].sum()), 1),
        }

    def _yoy(cur, prev):
        return {"전년동월": prev, "증감건": round(cur - prev, 1),
                "증감율": round((cur - prev) / prev * 100, 1) if prev > 0 else None}

    for _m in range(1, 13):
        _m_label = f"{_m}월"
        _vals = {_y: _mem_month_vals(_y, _m) for _y in (_prev2_year, _prev_year) }
        if _m <= sel_month:
            _vals[sel_year] = _mem_month_vals(sel_year, _m)
        for _yr in (_prev_year, sel_year):
            if _yr not in _vals:
                continue
            for _k in ("신규", "기존"):
                _mem_bar_rows.append({"월": _m_label, "연도": str(_yr), "회원구분": _k, "개발건": _vals[_yr][_k], "_sort": _m,
                                      **_yoy(_vals[_yr][_k], _vals[_yr - 1][_k])})
        # 꺾은선: 당해연도만 (신규본부, 신규지부, 기존)
        if _m <= sel_month:
            for _k in ("신규본부", "신규지부", "기존"):
                _mem_line_rows.append({"월": _m_label, "구분": _k, "개발건": _vals[sel_year][_k], "_sort": _m,
                                       **_yoy(_vals[sel_year][_k], _vals[_prev_year][_k])})

    _mem_bar_df = pd.DataFrame(_mem_bar_rows)
    _mem_line_df = pd.DataFrame(_mem_line_rows)

    # 막대: 연도별 스택 (신규+기존)
    _mem_bar_df["색상키"] = _mem_bar_df["연도"] + " " + _mem_bar_df["회원구분"]
    _stack_domain = [f"{_prev_year} 신규", f"{_prev_year} 기존", f"{sel_year} 신규", f"{sel_year} 기존"]
    _stack_colors = ["#B0BEC5", "#E0E0E0", "#8B9A46", "#C5D68A"]

    _mem_bars = alt.Chart(_mem_bar_df).mark_bar(cornerRadiusTopLeft=2, cornerRadiusTopRight=2, size=22).encode(
        x=alt.X("월:N", sort=_month_sort, axis=alt.Axis(labelFontSize=11, labelAngle=0, title="월")),
        xOffset=alt.XOffset("연도:N", sort=[str(_prev_year), str(sel_year)]),
        y=alt.Y("개발건:Q", stack=True, axis=alt.Axis(labelFontSize=10, format=",.0f", title="개발(건)")),
        color=alt.Color("색상키:N",
            scale=alt.Scale(domain=_stack_domain, range=_stack_colors),
            legend=alt.Legend(orient="right", titleFontSize=11, title="연도", labelFontSize=10, symbolSize=120)),
        order=alt.Order("회원구분:N", sort="descending"),
        tooltip=[alt.Tooltip("월:N"), alt.Tooltip("연도:N"), alt.Tooltip("회원구분:N"), alt.Tooltip("개발건:Q", format=",.1f", title="당월(건)"),
                 alt.Tooltip("전년동월:Q", format=",.1f", title="전년 동월(건)"),
                 alt.Tooltip("증감건:Q", format="+,.1f", title="전년 동월 대비 증감(건)"),
                 alt.Tooltip("증감율:Q", format="+.1f", title="전년 동월 대비 증감율(%)")],
    )

    _mem_lines = alt.Chart(_mem_line_df).mark_line(
        point=alt.OverlayMarkDef(size=160, filled=True, stroke="white", strokeWidth=1.5), strokeWidth=3
    ).encode(
        x=alt.X("월:N", sort=_month_sort),
        y=alt.Y("개발건:Q"),
        color=alt.Color("구분:N",
            scale=alt.Scale(domain=["신규본부", "신규지부", "기존"], range=["#1565C0", "#FF8F00", "#7B1FA2"]),
            legend=alt.Legend(orient="right", titleFontSize=11, title="구분", labelFontSize=10, symbolSize=120, symbolStrokeWidth=3)),
        strokeDash=alt.StrokeDash("구분:N",
            scale=alt.Scale(domain=["신규본부", "신규지부", "기존"], range=[[0], [6, 3], [2, 2]]),
            legend=None),
        tooltip=[alt.Tooltip("월:N"), alt.Tooltip("구분:N"), alt.Tooltip("개발건:Q", format=",.1f", title="당월"),
                 alt.Tooltip("전년동월:Q", format=",.1f", title="전년 동월(건)"),
                 alt.Tooltip("증감건:Q", format="+,.1f", title="전년 동월 대비 증감(건)"),
                 alt.Tooltip("증감율:Q", format="+.1f", title="전년 동월 대비 증감율(%)")],
    )

    _mem_combo = (_mem_bars + _mem_lines).properties(
        width="container", height=320,
        title=alt.Title(f"▼ {_prev_year}~{sel_year}년 월별 신규/기존 회원 개발실적 비교 (막대: 신규+기존 스택, 선: {sel_year}년 신규본부/신규지부/기존)", fontSize=18, fontWeight=700, anchor="start")
    ).resolve_scale(color="independent")

    st.altair_chart(_mem_combo, use_container_width=True)

    st.markdown('<div style="height:28px"></div>', unsafe_allow_html=True)

    col3, col4 = st.columns([1, 1], gap="medium")

    with col3:
        st.subheader("1-3. 회원구분별 현황(당월)")
        st.caption("💡 신규/재후원/증액 숫자 클릭 시 캠페인 상세를 확인할 수 있습니다.")
        result_mem_month = make_member_type_pivot(df_month, MONTHLY_MEMBER_TARGET)
        result_mem_month = apply_adjustment_member(result_mem_month, sel_year, sel_month, is_ytd=False)
        st.markdown(_render_mem_html(result_mem_month, "mm"), unsafe_allow_html=True)
        st.caption("출처: BRONZE_CRM — MBER_DIV_CD 기준 신규/기존 구분, FN_MM_SPNSR_DVLP 로직")

    with col4:
        st.subheader("1-4. 회원구분별 현황(누계)")
        st.caption("💡 신규/재후원/증액 숫자 클릭 시 캠페인 상세를 확인할 수 있습니다.")
        result_mem_ytd = make_member_type_pivot(df_ytd, YTD_MEMBER_TARGET)
        result_mem_ytd = apply_adjustment_member(result_mem_ytd, sel_year, sel_month, is_ytd=True)
        st.markdown(_render_mem_html(result_mem_ytd, "my"), unsafe_allow_html=True)
        st.caption("출처: BRONZE_CRM — MBER_DIV_CD 기준 신규/기존 구분, FN_MM_SPNSR_DVLP 로직")

    st.divider()


    def make_campaign_rank(month_df, ytd_df):
        month_total = month_df["개발건"].sum()
        ytd_total = ytd_df["개발건"].sum()

        # 당월 공통브랜드별 집계 (DIM_CAMPAIGN.CMMN_BRND_NM 기준)
        month_rank = (
            month_df.groupby("브랜드")
            .agg(당월개발건=("개발건", "sum"), 당월개발명수=("MBER_NO", "nunique"))
            .reset_index()
            .sort_values("당월개발건", ascending=False)
            .reset_index(drop=True)
        )

        # 누계 공통브랜드별 집계
        ytd_rank = (
            ytd_df.groupby("브랜드")
            .agg(누계개발건=("개발건", "sum"), 누계개발명수=("MBER_NO", "nunique"))
            .reset_index()
        )

        # 브랜드 → 해당 브랜드의 캠페인카테고리 목록 매핑 (당월 개발건 상위 3개)
        def get_top_categories(brand, df):
            sub = df[df["브랜드"] == brand]
            if sub.empty:
                return ""
            top = sub.groupby("캠페인카테고리")["개발건"].sum().sort_values(ascending=False).head(3)
            return ", ".join(top.index.tolist())

        top10 = month_rank.head(10)
        etc_df = month_rank.iloc[10:]

        rows = []
        for idx, r in enumerate(top10.itertuples(), start=1):
            brand = r.브랜드
            ytd_row = ytd_rank[ytd_rank["브랜드"] == brand]
            ytd_건 = int(ytd_row["누계개발건"].values[0]) if len(ytd_row) > 0 else 0
            ytd_명 = int(ytd_row["누계개발명수"].values[0]) if len(ytd_row) > 0 else 0
            rows.append({
                "순위": idx,
                "가입경로": brand,
                "컨텐츠": get_top_categories(brand, month_df),
                "당월_개발명": r.당월개발명수,
                "당월_개발건": r.당월개발건,
                "당월_구성비": round(r.당월개발건 / month_total * 100, 1) if month_total > 0 else 0,
                "누계_개발명": ytd_명,
                "누계_개발건": ytd_건,
                "누계_구성비": round(ytd_건 / ytd_total * 100, 1) if ytd_total > 0 else 0,
            })

        # 기타 (11위~마지막)
        etc_month_total = int(etc_df["당월개발건"].sum()) if len(etc_df) > 0 else 0
        etc_brands = etc_df["브랜드"].tolist() if len(etc_df) > 0 else []
        etc_ytd = ytd_rank[ytd_rank["브랜드"].isin(etc_brands)]
        etc_ytd_total = int(etc_ytd["누계개발건"].sum()) if len(etc_ytd) > 0 else 0
        etc_month_names = int(etc_df["당월개발명수"].sum()) if len(etc_df) > 0 else 0
        etc_ytd_names = int(etc_ytd["누계개발명수"].sum()) if len(etc_ytd) > 0 else 0

        last_rank = 10 + len(etc_brands)
        # 기타 브랜드들의 캠페인카테고리 목록 (당월 개발건 상위순)
        etc_all_df = month_df[month_df["브랜드"].isin(etc_brands)]
        etc_cat_rank = etc_all_df.groupby("캠페인카테고리")["개발건"].sum().sort_values(ascending=False)
        etc_cat_names = etc_cat_rank.index.tolist()
        # 마지막 카테고리 뒤에 '등' 추가
        if len(etc_cat_names) > 0:
            etc_contents = ", ".join(etc_cat_names[:-1]) + ", " + etc_cat_names[-1] + " 등" if len(etc_cat_names) > 1 else etc_cat_names[0] + " 등"
        else:
            etc_contents = ""

        rows.append({
            "순위": f"11위~{last_rank}위",
            "가입경로": "기타",
            "컨텐츠": etc_contents,
            "당월_개발명": etc_month_names,
            "당월_개발건": etc_month_total,
            "당월_구성비": round(etc_month_total / month_total * 100, 1) if month_total > 0 else 0,
            "누계_개발명": etc_ytd_names,
            "누계_개발건": etc_ytd_total,
            "누계_구성비": round(etc_ytd_total / ytd_total * 100, 1) if ytd_total > 0 else 0,
        })

        # 합계
        total_month_members = sum(r.get("당월_개발명", 0) for r in rows)
        total_ytd_members = sum(r.get("누계_개발명", 0) for r in rows)
        rows.append({
            "순위": "합계",
            "가입경로": "",
            "컨텐츠": "",
            "당월_개발명": total_month_members,
            "당월_개발건": month_total,
            "당월_구성비": 100.0,
            "누계_개발명": total_ytd_members,
            "누계_개발건": ytd_total,
            "누계_구성비": 100.0,
        })

        return pd.DataFrame(rows)


    def style_campaign_rank(df):
        def row_style(row):
            styles = [""] * len(row)
            if row["순위"] == "합계":
                styles = ["background-color:#222222;color:white;font-weight:bold"] * len(row)
            elif isinstance(row["순위"], str) and "위~" in row["순위"]:
                styles = ["background-color:#d9d9d9;font-weight:bold"] * len(row)
            elif isinstance(row["순위"], int) and row["순위"] <= 5:
                styles = ["background-color:#d4e6b5"] * len(row)
            return styles
        return df.style.apply(row_style, axis=1)


    campaign_rank_df = make_campaign_rank(df_month, df_ytd)

    # ── 팝업용 결제수단 데이터 (정기회원 납입회비 기준) ──

    with st.spinner("결제수단 데이터 로딩 중..."):
        _setle_df = _load_setle_for_popup()
    _setle_map = {}
    if not _setle_df.empty:
        for _, _sr in _setle_df.iterrows():
            _setle_map[str(_sr["MBER_NO"])] = str(_sr["SETLE_NM"])

    # ── 1-5. 회원구분별(납입방식): 팝업과 동일한 결제수단 매핑 기준 ──
    st.subheader("1-5. 회원구분별(납입방식)")
    _PAY_ORDER = ["자동이체", "신용카드", "휴대폰", "네이버페이", "OCR", "회비통장", "기타", "미확인"]
    _PAY_FIXED = ["자동이체", "신용카드", "휴대폰", "네이버페이", "OCR", "회비통장"]

    def _pay_agg(_d):
        if _d.empty:
            return pd.DataFrame(columns=["납입방식", "개발명", "개발건"])
        return _d.groupby("납입방식").agg(개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")).reset_index()

    _pm = _pay_agg(df_month).rename(columns={"개발명": "당월명", "개발건": "당월건"})
    _py = _pay_agg(df_ytd).rename(columns={"개발명": "누계명", "개발건": "누계건"})
    _pay_tbl = pd.DataFrame({"납입방식": _PAY_FIXED}).merge(_py, on="납입방식", how="outer").merge(_pm, on="납입방식", how="outer").fillna(0)
    _pay_tbl = _pay_tbl[_pay_tbl["납입방식"].isin(_PAY_FIXED) | (_pay_tbl["누계건"] > 0) | (_pay_tbl["당월건"] > 0)]
    _pay_tbl["_o"] = _pay_tbl["납입방식"].apply(lambda x: _PAY_ORDER.index(x) if x in _PAY_ORDER else len(_PAY_ORDER))
    _pay_tbl = _pay_tbl.sort_values("_o")
    _pm_tot, _py_tot = float(_pay_tbl["당월건"].sum()), float(_pay_tbl["누계건"].sum())
    _pm_mtot = int(_pay_tbl["당월명"].sum())
    _py_mtot = int(_pay_tbl["누계명"].sum())
    _fm = lambda v, f: "-" if v == 0 else format(v, f)

    # 활동: 월말 기준 활동 회원의 결제수단(SETLE_MONTH.SETLE_CD) 기준
    with st.spinner("납입방식별 활동 데이터 로딩 중..."):
        _act_setle = load_active_v2(sel_year, sel_month, by_setle=True)
    _SETLE_NM_ACT = {"1": "자동이체", "2": "신용카드", "4": "회비통장", "5": "휴대폰", "8": "OCR", "12": "네이버페이"}
    if not _act_setle.empty:
        _act_setle = _act_setle.assign(납입방식=_act_setle["SETLE_CD"].map(
            lambda x: _SETLE_NM_ACT.get(str(x).split(".")[0], "기타") if pd.notna(x) else "미확인"))
        _act_setle["ACT_MEM"] = _act_setle["ACT_MEM"].astype(int)
        _act_setle["ACT_CNT"] = _act_setle["ACT_CNT"].astype(float)
        _pa = _act_setle.groupby("납입방식").agg(활동명=("ACT_MEM", "sum"), 활동건=("ACT_CNT", "sum")).reset_index()
    else:
        _pa = pd.DataFrame(columns=["납입방식", "활동명", "활동건"])
    _pay_tbl = _pay_tbl.merge(_pa, on="납입방식", how="outer").fillna(0)
    _pay_tbl["_o"] = _pay_tbl["납입방식"].apply(lambda x: _PAY_ORDER.index(x) if x in _PAY_ORDER else len(_PAY_ORDER))
    _pay_tbl = _pay_tbl.sort_values("_o")
    _pa_tot = float(_pay_tbl["활동건"].sum())
    _pa_mtot = int(_pay_tbl["활동명"].sum())

    # 1-1~1-4 표와 동일한 스타일
    _pth = "background:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px"
    _ptd = "padding:5px;border:1px solid #ddd;white-space:nowrap;text-align:right;"
    _ptot = "background:#222;color:white;font-weight:bold;"
    _ph = '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:8px"><thead>'
    _ph += (f'<tr><th rowspan="2" style="{_pth}">납입방식</th><th colspan="3" style="{_pth}">당월 개발</th>'
            f'<th colspan="3" style="{_pth}">누계 개발</th><th colspan="3" style="{_pth}">활동 ({sel_month}월말)</th></tr><tr>')
    for _c in ["개발명", "개발건", "구성비(%)", "개발명", "개발건", "구성비(%)", "활동명", "활동건", "구성비(%)"]:
        _ph += f'<th style="{_pth}">{_c}</th>'
    _ph += '</tr></thead><tbody>'

    def _pcell(v, f, extra=""):
        return f'<td style="{_ptd}{extra}">{_fm(v, f)}</td>'

    def _ppct(v, tot, extra=""):
        v, tot = float(v), float(tot)
        _v = v / tot * 100 if tot > 0 else 0
        return f'<td style="{_ptd}{extra}">{"-" if _v == 0 else f"{_v:.1f}%"}</td>'

    for _, _r in _pay_tbl.iterrows():
        _ph += f'<tr><td style="{_ptd}text-align:center;font-weight:600">{_r["납입방식"]}</td>'
        _ph += _pcell(int(_r["당월명"]), ",") + _pcell(_r["당월건"], ",.2f") + _ppct(_r["당월건"], _pm_tot)
        _ph += _pcell(int(_r["누계명"]), ",") + _pcell(_r["누계건"], ",.2f") + _ppct(_r["누계건"], _py_tot)
        _ph += _pcell(int(_r["활동명"]), ",") + _pcell(_r["활동건"], ",.2f") + _ppct(_r["활동건"], _pa_tot) + '</tr>'
    _ph += (f'<tr><td style="{_ptd}{_ptot}text-align:center">합계</td>'
            + _pcell(_pm_mtot, ",", _ptot) + _pcell(_pm_tot, ",.2f", _ptot) + _ppct(_pm_tot, _pm_tot, _ptot)
            + _pcell(_py_mtot, ",", _ptot) + _pcell(_py_tot, ",.2f", _ptot) + _ppct(_py_tot, _py_tot, _ptot)
            + _pcell(_pa_mtot, ",", _ptot) + _pcell(_pa_tot, ",.2f", _ptot) + _ppct(_pa_tot, _pa_tot, _ptot)
            + '</tr></tbody></table>')
    st.markdown(_ph, unsafe_allow_html=True)
    st.caption("※ 개발: 개발 건별 결제수단(개발내역 SETLE_CD) 기준(마감값 기준) / 활동: 월말 활동회원의 결제수단 기준 / 합계 명수는 납입방식별 명수의 합")

    # ── 1-5 분석 차트 ──
    _PAY_COLORS = ["#A8D8EA", "#FFD3B6", "#D5E8D4", "#F2B5D4", "#C9B6E4", "#FFF1A8", "#C8C8C8", "#E0E0E0"]
    _pay_list = list(_pay_tbl["납입방식"])
    _pay_scale = alt.Scale(domain=_pay_list, range=_PAY_COLORS[:len(_pay_list)])
    _pc1, _pc2 = st.columns(2, gap="medium")

    # 차트 1: 개발 vs 활동 구성비 (100% 누적)
    with _pc1:
        st.caption("▼ 납입방식 구성비 비교 (당월 개발 · 누계 개발 · 월말 활동)")
        _mix_rows = []
        for _lbl, _col, _tot in [("당월 개발", "당월건", _pm_tot), ("누계 개발", "누계건", _py_tot), (f"{sel_month}월말 활동", "활동건", _pa_tot)]:
            for _, _r in _pay_tbl.iterrows():
                _p = float(_r[_col]) / _tot * 100 if _tot > 0 else 0
                _mix_rows.append({"구분": _lbl, "납입방식": _r["납입방식"], "비율": round(_p, 1),
                                  "건수": float(_r[_col]), "라벨": f"{_p:.0f}%", "_o": _pay_list.index(_r["납입방식"])})
        _mix_df = pd.DataFrame(_mix_rows).sort_values(["구분", "_o"])
        _mix_df["_mid"] = (_mix_df.groupby("구분")["비율"].cumsum() - _mix_df["비율"] / 2) / 100
        _mix_order = ["당월 개발", "누계 개발", f"{sel_month}월말 활동"]
        _mix_bar = alt.Chart(_mix_df).mark_bar(size=50).encode(
            y=alt.Y("구분:N", sort=_mix_order, axis=alt.Axis(labelFontSize=14, labelFontWeight="bold", labelLimit=200), title=None),
            x=alt.X("비율:Q", stack="normalize", axis=alt.Axis(format="%", labelFontSize=13), title=None),
            color=alt.Color("납입방식:N", scale=_pay_scale, sort=_pay_list,
                            legend=alt.Legend(orient="bottom", title=None, labelFontSize=13, symbolSize=200, columns=4)),
            order=alt.Order("_o:Q"),
            tooltip=[alt.Tooltip("구분:N"), alt.Tooltip("납입방식:N"), alt.Tooltip("건수:Q", format=",.1f"), alt.Tooltip("비율:Q", format=".1f", title="구성비(%)")],
        ).properties(height=380)
        _mix_text = alt.Chart(_mix_df[_mix_df["비율"] >= 5]).mark_text(fontSize=14, fontWeight="bold", color="#333").encode(
            y=alt.Y("구분:N", sort=_mix_order), x=alt.X("_mid:Q"), text="라벨:N",
        )
        st.altair_chart(_mix_bar + _mix_text, use_container_width=True)

    # 차트 2: 구성비 차이 (당월 개발 − 월말 활동, %p)
    with _pc2:
        st.caption(f"▼ 납입방식 구성비 차이 (당월 개발 − {sel_month}월말 활동, %p)")
        _gap_rows = []
        for _, _r in _pay_tbl.iterrows():
            _dp = float(_r["당월건"]) / _pm_tot * 100 if _pm_tot > 0 else 0
            _ap = float(_r["활동건"]) / _pa_tot * 100 if _pa_tot > 0 else 0
            _g = round(_dp - _ap, 1)
            _gap_rows.append({"납입방식": _r["납입방식"], "차이": _g, "개발비중": round(_dp, 1), "활동비중": round(_ap, 1),
                              "라벨": f"{_g:+.1f}%p", "방향": "증가" if _g >= 0 else "감소"})
        _gap_df = pd.DataFrame(_gap_rows)
        _gap_bar = alt.Chart(_gap_df).mark_bar(size=28, cornerRadius=3).encode(
            y=alt.Y("납입방식:N", sort=_pay_list, axis=alt.Axis(labelFontSize=14, labelFontWeight="bold"), title=None),
            x=alt.X("차이:Q", axis=alt.Axis(labelFontSize=13, title="%p", titleFontSize=13)),
            color=alt.Color("방향:N", scale=alt.Scale(domain=["증가", "감소"], range=["#5B9BD5", "#BDBDBD"]), legend=None),
            tooltip=[alt.Tooltip("납입방식:N"), alt.Tooltip("개발비중:Q", title="당월 개발 비중(%)", format=".1f"),
                     alt.Tooltip("활동비중:Q", title="활동 비중(%)", format=".1f"), alt.Tooltip("라벨:N", title="차이")],
        )
        _gap_text_pos = alt.Chart(_gap_df[_gap_df["차이"] >= 0]).mark_text(
            fontSize=14, fontWeight="bold", align="left", dx=6, color="#1a5276"
        ).encode(y=alt.Y("납입방식:N", sort=_pay_list), x=alt.X("차이:Q"), text="라벨:N")
        _gap_text_neg = alt.Chart(_gap_df[_gap_df["차이"] < 0]).mark_text(
            fontSize=14, fontWeight="bold", align="right", dx=-6, color="#616161"
        ).encode(y=alt.Y("납입방식:N", sort=_pay_list), x=alt.X("차이:Q"), text="라벨:N")
        _gap_text = _gap_text_pos + _gap_text_neg
        _gap_rule = alt.Chart(pd.DataFrame({"x": [0]})).mark_rule(color="#333", strokeWidth=1.5).encode(x="x:Q")
        st.altair_chart((_gap_bar + _gap_rule + _gap_text).properties(height=380), use_container_width=True)
        st.caption("※ 파랑: 활동회원 대비 신규 개발에서 비중이 커진 수단 / 회색: 비중이 줄어든 수단")

    # 차트 3: 월별 납입방식 구성비 추이
    st.caption(f"▼ {sel_year}년 월별 개발 납입방식 구성비 추이 (%)")
    if not df_ytd.empty:
        _pt = df_ytd.groupby(["STRD_MT", "납입방식"])["개발건"].sum().reset_index()
        _pt_tot = _pt.groupby("STRD_MT")["개발건"].transform("sum")
        _pt["비율"] = (_pt["개발건"] / _pt_tot * 100).round(1)
        _pt["월"] = _pt["STRD_MT"].apply(lambda x: f"{int(str(x)[-2:])}월")
        _pt["라벨"] = _pt["비율"].apply(lambda v: f"{v:.0f}%")
        _pt_months = [f"{m}월" for m in range(1, sel_month + 1)]
        _pt_hover = alt.selection_point(fields=["납입방식"], on="pointerover", empty=True, clear="pointerout")
        _pt_pick = alt.selection_point(fields=["납입방식"], on="pointerover", empty=False, clear="pointerout")
        _pt_line = alt.Chart(_pt).mark_line(point=alt.OverlayMarkDef(size=80, filled=True), strokeWidth=3).encode(
            x=alt.X("월:N", sort=_pt_months, axis=alt.Axis(labelFontSize=13, labelAngle=0), title=None),
            y=alt.Y("비율:Q", axis=alt.Axis(labelFontSize=13, title="구성비(%)", titleFontSize=13)),
            color=alt.Color("납입방식:N", scale=alt.Scale(domain=_pay_list, range=["#4A90C2", "#F28E2B", "#59A14F", "#E15759", "#B07AA1", "#EDC948", "#9C9C9C", "#BAB0AC"][:len(_pay_list)]),
                            sort=_pay_list, legend=alt.Legend(orient="right", title=None, labelFontSize=13, symbolSize=200)),
            opacity=alt.condition(_pt_hover, alt.value(1), alt.value(0.25)),
            tooltip=[alt.Tooltip("월:N"), alt.Tooltip("납입방식:N"), alt.Tooltip("개발건:Q", format=",.1f"), alt.Tooltip("비율:Q", format=".1f", title="구성비(%)")],
        ).add_params(_pt_hover, _pt_pick)
        _pt_text = alt.Chart(_pt).mark_text(dy=-14, fontSize=13, fontWeight="bold").encode(
            x=alt.X("월:N", sort=_pt_months), y="비율:Q", text="라벨:N",
            color=alt.Color("납입방식:N", scale=alt.Scale(domain=_pay_list, range=["#4A90C2", "#F28E2B", "#59A14F", "#E15759", "#B07AA1", "#EDC948", "#9C9C9C", "#BAB0AC"][:len(_pay_list)]), legend=None),
        ).transform_filter(_pt_pick)
        st.altair_chart((_pt_line + _pt_text).properties(height=420), use_container_width=True)
        st.caption("💡 선에 마우스를 올리면 해당 납입방식만 강조되고 월별 수치가 표시됩니다.")
    st.markdown('<div style="height:24px"></div>', unsafe_allow_html=True)

    st.subheader("1-6. 캠페인별 개발 상위10 (당월기준)")
    st.caption("💡 각 컨텐츠 컬럼 클릭 시 세부사항을 확인할 수 있습니다.")

    # 후원금액대 분류 함수
    def _amt_band(amt):
        v = float(amt)
        if v < 10000: return "1만원 미만"
        if v < 30000: return "1~3만원"
        if v < 50000: return "3~5만원"
        if v < 100000: return "5~10만원"
        return "10만원 이상"

    # 카테고리별 납입방식/금액대 분포 집계 헬퍼
    def _build_pay_amt(sub_df):
        pay_dict = {}
        amt_dict = {"1만원 미만": 0, "1~3만원": 0, "3~5만원": 0, "5~10만원": 0, "10만원 이상": 0}
        for _, r in sub_df.iterrows():
            mn = str(r["MBER_NO"])
            sn = r["납입방식"]
            dev = float(r["개발건"])
            pay_dict[sn] = round(pay_dict.get(sn, 0) + dev, 1)
            ab = _amt_band(r["SPNSR_AMT"])
            amt_dict[ab] = round(amt_dict.get(ab, 0) + dev, 1)
        pay_dict = {k: v for k, v in pay_dict.items() if v > 0}
        amt_dict = {k: v for k, v in amt_dict.items() if v > 0}
        return pay_dict, amt_dict

    # ── 팝업 데이터 준비: 브랜드별 캠페인카테고리 상세 ──
    _popup_data = {}
    for brand_name in df_ytd["브랜드"].dropna().unique():
        brand_df = df_ytd[df_ytd["브랜드"] == brand_name]
        for cat_name in brand_df["캠페인카테고리"].dropna().unique():
            cat_df = brand_df[brand_df["캠페인카테고리"] == cat_name]
            cat_total = float(cat_df["개발건"].sum())
            # 1) 마케팅캠페인명별 집계 (신규/기존 포함, 그외 행 추가)
            all_camps = cat_df.groupby("마케팅캠페인명").agg(
                개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
            ).sort_values("개발건", ascending=False).reset_index()
            top20 = all_camps.head(20)
            top_camp_names = list(top20["마케팅캠페인명"])
            camps_ne = cat_df[cat_df["마케팅캠페인명"].isin(top_camp_names)].groupby(
                ["마케팅캠페인명", "회원구분"]).agg(
                개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
            ).reset_index()
            camp_list = []
            top_c = 0.0
            top_m_set = set()
            for _, cr in top20.iterrows():
                cn = str(cr["마케팅캠페인명"])
                tc = round(float(cr["개발건"]), 1)
                top_c += tc
                top_m_set.update(cat_df[cat_df["마케팅캠페인명"] == cn]["MBER_NO"].unique())
                tp = round(tc / cat_total * 100, 1) if cat_total > 0 else 0
                nr = camps_ne[(camps_ne["마케팅캠페인명"] == cn) & (camps_ne["회원구분"] == "신규회원")]
                nc = round(float(nr["개발건"].sum()), 1) if not nr.empty else 0.0
                nm = int(nr["개발명"].sum()) if not nr.empty else 0
                n_p = round(nc / cat_total * 100, 1) if cat_total > 0 else 0
                er = camps_ne[(camps_ne["마케팅캠페인명"] == cn) & (camps_ne["회원구분"] == "기존회원")]
                ec = round(float(er["개발건"].sum()), 1) if not er.empty else 0.0
                em = int(er["개발명"].sum()) if not er.empty else 0
                e_p = round(ec / cat_total * 100, 1) if cat_total > 0 else 0
                camp_list.append({"n": cn, "m": int(cr["개발명"]), "c": tc, "p": tp,
                                  "nm": nm, "nc": nc, "np": n_p, "em": em, "ec": ec, "ep": e_p})
            if len(all_camps) > 20:
                etc_df = cat_df[~cat_df["마케팅캠페인명"].isin(top_camp_names)]
                etc_c = round(cat_total - top_c, 1)
                etc_m = int(etc_df["MBER_NO"].nunique())
                etc_p = round(etc_c / cat_total * 100, 1) if cat_total > 0 else 0
                etc_new = etc_df[etc_df["회원구분"] == "신규회원"]
                etc_exist = etc_df[etc_df["회원구분"] == "기존회원"]
                enc = round(float(etc_new["개발건"].sum()), 1)
                enm = int(etc_new["MBER_NO"].nunique())
                eec = round(float(etc_exist["개발건"].sum()), 1)
                eem = int(etc_exist["MBER_NO"].nunique())
                camp_list.append({"n": "그외", "m": etc_m, "c": etc_c, "p": etc_p,
                    "nm": enm, "nc": enc, "np": round(enc / cat_total * 100, 1) if cat_total > 0 else 0,
                    "em": eem, "ec": eec, "ep": round(eec / cat_total * 100, 1) if cat_total > 0 else 0,
                    "etc": True})
            # 2) 신규/기존 구성비
            ne_dist = cat_df.groupby("회원구분")["개발건"].sum()
            ne_dict = {str(k): round(float(v), 1) for k, v in ne_dist.items()}
            # 3) 연령대 구성비
            age_order = ["10대이하", "10대", "20대", "30대", "40대", "50대", "60대이상", "기타"]
            age_dist = cat_df.groupby("연령대")["개발건"].sum()
            age_dict = {}
            for ag in age_order:
                age_dict[ag] = round(float(age_dist.get(ag, 0)), 1)
            # 4) 납입방식 / 후원금액대 분포
            pay_dict, amt_dict = _build_pay_amt(cat_df)
            key = f"{brand_name}|{cat_name}"
            entry = {"brand": brand_name, "cat": cat_name, "total": round(cat_total, 1),
                     "camps": camp_list, "ne": ne_dict, "age": age_dict, "pay": pay_dict, "amt": amt_dict}
            # 대면모금 > 가두캠페인: 마케팅캠페인명='가두캠페인' 매핑 세부캠페인명 추가
            if brand_name == "대면모금" and cat_name == "가두캠페인":
                sub_df = cat_df[cat_df["마케팅캠페인명"] == "가두캠페인"]
                if len(sub_df) > 0:
                    sub_total = float(sub_df["개발건"].sum())
                    sub_camps = sub_df.groupby("캠페인명").agg(
                        개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
                    ).sort_values("개발건", ascending=False).head(20).reset_index()
                    sub_ne = sub_df.groupby(["캠페인명", "회원구분"]).agg(
                        개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
                    ).reset_index()
                    sub_list = []
                    for _, sr in sub_camps.iterrows():
                        sn = str(sr["캠페인명"])
                        sc = round(float(sr["개발건"]), 1)
                        sp = round(sc / sub_total * 100, 1) if sub_total > 0 else 0
                        snr = sub_ne[(sub_ne["캠페인명"] == sn) & (sub_ne["회원구분"] == "신규회원")]
                        ser = sub_ne[(sub_ne["캠페인명"] == sn) & (sub_ne["회원구분"] == "기존회원")]
                        sub_list.append({"n": sn, "m": int(sr["개발명"]), "c": sc, "p": sp,
                            "nm": int(snr["개발명"].sum()) if not snr.empty else 0,
                            "nc": round(float(snr["개발건"].sum()), 1) if not snr.empty else 0.0,
                            "np": round(float(snr["개발건"].sum()) / sub_total * 100, 1) if not snr.empty and sub_total > 0 else 0,
                            "em": int(ser["개발명"].sum()) if not ser.empty else 0,
                            "ec": round(float(ser["개발건"].sum()), 1) if not ser.empty else 0.0,
                            "ep": round(float(ser["개발건"].sum()) / sub_total * 100, 1) if not ser.empty and sub_total > 0 else 0})
                    entry["sub"] = sub_list
            _popup_data[key] = entry

    # ── 기타 브랜드(11위~) 통합 팝업 데이터 ──
    _top10_brands = set(
        str(row["가입경로"]) for _, row in campaign_rank_df.iterrows()
        if isinstance(row["순위"], (int, float))
    )
    _etc_df = df_ytd[~df_ytd["브랜드"].isin(_top10_brands)]
    if len(_etc_df) > 0:
        etc_total = float(_etc_df["개발건"].sum())
        # 브랜드별 집계
        etc_camps = _etc_df.groupby("브랜드").agg(
            개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
        ).sort_values("개발건", ascending=False).head(20).reset_index()
        etc_ne_by_brand = _etc_df.groupby(["브랜드", "회원구분"]).agg(
            개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
        ).reset_index()
        etc_camp_list = []
        for _, cr in etc_camps.iterrows():
            brand_nm = str(cr["브랜드"])
            bc = round(float(cr["개발건"]), 1)
            pct = round(bc / etc_total * 100, 1) if etc_total > 0 else 0
            bnr = etc_ne_by_brand[(etc_ne_by_brand["브랜드"] == brand_nm) & (etc_ne_by_brand["회원구분"] == "신규회원")]
            ber = etc_ne_by_brand[(etc_ne_by_brand["브랜드"] == brand_nm) & (etc_ne_by_brand["회원구분"] == "기존회원")]
            # 브랜드별 캠페인카테고리 상세
            b_df = _etc_df[_etc_df["브랜드"] == brand_nm]
            b_total = float(b_df["개발건"].sum())
            cat_grp = b_df.groupby("캠페인카테고리").agg(
                개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
            ).sort_values("개발건", ascending=False).reset_index()
            cat_ne = b_df.groupby(["캠페인카테고리", "회원구분"]).agg(
                개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
            ).reset_index()
            detail = []
            for _, dr in cat_grp.iterrows():
                dn = str(dr["캠페인카테고리"])
                dc = round(float(dr["개발건"]), 1)
                dp = round(dc / b_total * 100, 1) if b_total > 0 else 0
                dnr = cat_ne[(cat_ne["캠페인카테고리"] == dn) & (cat_ne["회원구분"] == "신규회원")]
                der = cat_ne[(cat_ne["캠페인카테고리"] == dn) & (cat_ne["회원구분"] == "기존회원")]
                detail.append({"n": dn, "m": int(dr["개발명"]), "c": dc, "p": dp,
                    "nm": int(dnr["개발명"].sum()) if not dnr.empty else 0,
                    "nc": round(float(dnr["개발건"].sum()), 1) if not dnr.empty else 0.0,
                    "np": round(float(dnr["개발건"].sum()) / b_total * 100, 1) if not dnr.empty and b_total > 0 else 0,
                    "em": int(der["개발명"].sum()) if not der.empty else 0,
                    "ec": round(float(der["개발건"].sum()), 1) if not der.empty else 0.0,
                    "ep": round(float(der["개발건"].sum()) / b_total * 100, 1) if not der.empty and b_total > 0 else 0})
            etc_camp_list.append({"n": brand_nm, "m": int(cr["개발명"]), "c": bc, "p": pct,
                "nm": int(bnr["개발명"].sum()) if not bnr.empty else 0,
                "nc": round(float(bnr["개발건"].sum()), 1) if not bnr.empty else 0.0,
                "np": round(float(bnr["개발건"].sum()) / etc_total * 100, 1) if not bnr.empty and etc_total > 0 else 0,
                "em": int(ber["개발명"].sum()) if not ber.empty else 0,
                "ec": round(float(ber["개발건"].sum()), 1) if not ber.empty else 0.0,
                "ep": round(float(ber["개발건"].sum()) / etc_total * 100, 1) if not ber.empty and etc_total > 0 else 0,
                "detail": detail})
        etc_ne = _etc_df.groupby("회원구분")["개발건"].sum()
        etc_ne_dict = {str(k): round(float(v), 1) for k, v in etc_ne.items()}
        age_order = ["10대이하", "10대", "20대", "30대", "40대", "50대", "60대이상", "기타"]
        etc_age = _etc_df.groupby("연령대")["개발건"].sum()
        etc_age_dict = {}
        for ag in age_order:
            etc_age_dict[ag] = round(float(etc_age.get(ag, 0)), 1)
        etc_pay_dict, etc_amt_dict = _build_pay_amt(_etc_df)
        _popup_data["__etc__"] = {
            "brand": "기타", "cat": f"11위 이하 브랜드 ({len(_etc_df['브랜드'].unique())}개)",
            "total": round(etc_total, 1),
            "camps": etc_camp_list, "ne": etc_ne_dict, "age": etc_age_dict, "pay": etc_pay_dict, "amt": etc_amt_dict
        }

    # 2단 헤더 HTML 테이블 생성
    def render_campaign_html(df):
        html = '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0">'
        html += '<thead>'
        html += '<tr>'
        html += '<th rowspan="2" style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600;white-space:nowrap">순위</th>'
        html += '<th rowspan="2" style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600;white-space:nowrap">가입경로</th>'
        html += '<th rowspan="2" style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600;white-space:nowrap">컨텐츠</th>'
        html += '<th colspan="3" style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600">당월</th>'
        html += '<th colspan="3" style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600">누계</th>'
        html += '</tr>'
        html += '<tr>'
        for _ in range(2):
            html += '<th style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600;white-space:nowrap">개발(명)</th>'
            html += '<th style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600;white-space:nowrap">개발(건)</th>'
            html += '<th style="background:#4a4a4a;color:white;padding:6px 5px;border:1px solid #ddd;text-align:center;font-weight:600;white-space:nowrap">구성비(%)</th>'
        html += '</tr>'
        html += '</thead><tbody>'
        for _, row in df.iterrows():
            rank = row["순위"]
            _is_etc = isinstance(rank, str) and "위~" in rank
            if rank == "합계":
                row_style = 'background-color:#222222;color:white;font-weight:bold'
            elif _is_etc:
                row_style = 'background-color:#d9d9d9;font-weight:bold'
            elif isinstance(rank, (int, float)) and rank <= 5:
                row_style = 'background-color:#d4e6b5'
            else:
                row_style = ''
            td_base = f'style="{row_style};padding:5px;border:1px solid #ddd;white-space:nowrap'
            html += '<tr>'
            html += f'<td {td_base};text-align:center">{rank}</td>'
            brand_val = row["가입경로"]
            html += f'<td {td_base};text-align:left">{brand_val}</td>'
            # 컨텐츠: 셀 전체를 클릭 가능하게 (브랜드를 키로 사용)
            contents_raw = str(row["컨텐츠"])
            if _is_etc:
                html += f'<td data-cat-popup="__etc__" {td_base};text-align:left;cursor:pointer" title="클릭 시 상세보기">{contents_raw}</td>'
            elif contents_raw and brand_val and rank != "합계":
                cats = [c.strip() for c in contents_raw.split(",") if c.strip()]
                # 모든 카테고리 키를 파이프로 구분하여 전달
                popup_keys = "||".join([f"{brand_val}|{c}" for c in cats])
                html += f'<td data-cat-popup="{popup_keys}" {td_base};text-align:left;cursor:pointer" title="클릭 시 상세보기">{contents_raw}</td>'
            else:
                html += f'<td {td_base};text-align:left">{contents_raw}</td>'
            html += f'<td {td_base};text-align:right">{row["당월_개발명"]:,.0f}</td>'
            html += f'<td {td_base};text-align:right">{row["당월_개발건"]:,.1f}</td>'
            html += f'<td {td_base};text-align:right">{row["당월_구성비"]:.1f}%</td>'
            html += f'<td {td_base};text-align:right">{row["누계_개발명"]:,.0f}</td>'
            html += f'<td {td_base};text-align:right">{row["누계_개발건"]:,.1f}</td>'
            html += f'<td {td_base};text-align:right">{row["누계_구성비"]:.1f}%</td>'
            html += '</tr>'
        html += '</tbody></table>'
        return html

    st.markdown(render_campaign_html(campaign_rank_df), unsafe_allow_html=True)

    # ── JS 팝업 (주간중단보고 스타일 — components.html + parent document) ──
    import json as _json15
    _pjson15 = _json15.dumps(_popup_data, ensure_ascii=False)
    stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._catPopupCleanup){{try{{doc._catPopupCleanup()}}catch(e){{}}}}
var D={_pjson15};
var ov=doc.getElementById('cat-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='cat-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="cat-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:1150px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st=doc.createElement('style');st.id='cat-popup-style';
var oldSt=doc.getElementById('cat-popup-style');if(oldSt)oldSt.remove();
st.textContent='@keyframes catpop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#cat-popup-box{{animation:catpop .2s ease}}td[data-cat-popup]{{cursor:pointer}}td[data-cat-popup]:hover{{filter:brightness(0.94)}}';
doc.head.appendChild(st);
doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
var box=doc.getElementById('cat-popup-box');
var _keys=[],_idx=0;
function pie(data,colors){{
  var tot=0;for(var k in data)tot+=data[k];if(tot===0)return '<span style="color:#999">데이터 없음</span>';
  var parts=[],cum=0,i=0;
  for(var k in data){{var p=data[k]/tot*100;parts.push(colors[i%colors.length]+' '+cum.toFixed(1)+'% '+(cum+p).toFixed(1)+'%');cum+=p;i++;}}
  var h='<div style="display:flex;align-items:center;gap:18px"><div style="width:140px;height:140px;border-radius:50%;background:conic-gradient('+parts.join(',')+');flex-shrink:0"></div><div style="font-size:12px">';
  i=0;for(var k in data){{var p=(data[k]/tot*100).toFixed(1);h+='<div style="margin:3px 0"><span style="display:inline-block;width:11px;height:11px;background:'+colors[i%colors.length]+';border-radius:2px;margin-right:6px"></span>'+k+': '+data[k].toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+' ('+p+'%)</div>';i++;}}
  return h+'</div></div>';
}}
function render(idx){{
  _idx=idx;var key=_keys[idx];var d=D[key];if(!d)return;
  var nc=['#7B1FA2','#FF9800','#9E9E9E'];
  var ac=['#E91E63','#FF5722','#FF9800','#FFC107','#4CAF50','#2196F3','#3F51B5','#9E9E9E'];
  var h='<div style="background:linear-gradient(135deg,#2C3E50,#34495E);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.brand+' &gt; '+d.cat+' (누계 '+d.total.toLocaleString(undefined,{{minimumFractionDigits:1}})+'건)</span>';
  h+='<span id="cat-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div>';
  if(_keys.length>1){{
    h+='<div style="display:flex;align-items:center;justify-content:center;gap:12px;padding:10px 20px;background:#f8f9fa;border-bottom:1px solid #eee;">';
    var prevDis=idx===0?'opacity:0.3;pointer-events:none':'cursor:pointer';
    var nextDis=idx===_keys.length-1?'opacity:0.3;pointer-events:none':'cursor:pointer';
    h+='<span id="cat-prev" style="font-size:18px;font-weight:700;'+prevDis+'">◀</span>';
    h+='<span style="font-size:13px;font-weight:600;color:#555">';
    for(var p=0;p<_keys.length;p++){{
      var dd=D[_keys[p]];var cn=dd?dd.cat:'';
      if(p===idx)h+='<span style="background:#2C3E50;color:#fff;padding:3px 10px;border-radius:12px;margin:0 3px">'+cn+'</span>';
      else h+='<span style="color:#999;margin:0 3px">'+cn+'</span>';
    }}
    h+='</span>';
    h+='<span id="cat-next" style="font-size:18px;font-weight:700;'+nextDis+'">▶</span>';
    h+='</div>';
  }}
  h+='<div style="padding:18px 22px">';
  h+='<div style="margin-bottom:20px;display:flex;gap:36px;flex-wrap:wrap">';
  h+='<div style="flex:1;min-width:280px"><div style="font-size:14px;font-weight:700;color:#2C3E50;margin-bottom:10px;border-bottom:2px solid #7B1FA2;padding-bottom:6px">신규/기존 구성비</div>'+pie(d.ne,nc)+'</div>';
  h+='<div style="flex:1;min-width:280px"><div style="font-size:14px;font-weight:700;color:#2C3E50;margin-bottom:10px;border-bottom:2px solid #E91E63;padding-bottom:6px">연령대 분포</div>'+pie(d.age,ac)+'</div>';
  h+='</div>';
  var pc=['#1565C0','#43A047','#FF8F00','#8E24AA','#D81B60','#00897B'];
  var amc=['#2196F3','#4CAF50','#FF9800','#9C27B0','#F44336'];
  h+='<div style="margin-bottom:20px;display:flex;gap:36px;flex-wrap:wrap">';
  h+='<div style="flex:1;min-width:280px"><div style="font-size:14px;font-weight:700;color:#2C3E50;margin-bottom:10px;border-bottom:2px solid #1565C0;padding-bottom:6px">💳 납입방식 분포</div>'+(d.pay?pie(d.pay,pc):'<span style="color:#999">데이터 없음</span>')+'</div>';
  h+='<div style="flex:1;min-width:280px"><div style="font-size:14px;font-weight:700;color:#2C3E50;margin-bottom:10px;border-bottom:2px solid #FF8F00;padding-bottom:6px">💰 후원금액대 분포</div>'+(d.amt?pie(d.amt,amc):'<span style="color:#999">데이터 없음</span>')+'</div>';
  h+='</div>';
h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin-bottom:8px;border-bottom:2px solid #667eea;padding-bottom:5px">캠페인 세부현황 (상위 20)</div>';
h+='<div style="overflow-x:auto">';
h+='<table style="width:100%;border-collapse:collapse;font-size:11px;margin-bottom:16px"><thead><tr>';
h+='<th rowspan="2" style="background:#f0f2f5;padding:5px 6px;text-align:center;border:1px solid #e0e0e0;width:28px">순위</th>';
h+='<th rowspan="2" style="background:#f0f2f5;padding:5px 6px;text-align:left;border:1px solid #e0e0e0;min-width:120px">캠페인명</th>';
h+='<th colspan="3" style="background:#e8f5e9;padding:4px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:700">신규회원</th>';
h+='<th colspan="3" style="background:#e3f2fd;padding:4px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:700">기존회원</th>';
h+='<th colspan="3" style="background:#fff3e0;padding:4px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:700">합계</th>';
h+='</tr><tr>';
var _hbgs=['#e8f5e9','#e3f2fd','#fff3e0'];
for(var hi=0;hi<3;hi++){{h+='<th style="background:'+_hbgs[hi]+';padding:3px 5px;text-align:right;border:1px solid #e0e0e0;font-size:10px;width:45px">개발명</th><th style="background:'+_hbgs[hi]+';padding:3px 5px;text-align:right;border:1px solid #e0e0e0;font-size:10px;width:50px">개발건</th><th style="background:'+_hbgs[hi]+';padding:3px 5px;text-align:right;border:1px solid #e0e0e0;font-size:10px;width:42px">구성비</th>';}}
h+='</tr></thead><tbody>';
  for(var i=0;i<d.camps.length;i++){{
    var c=d.camps[i];var isEtc=c.etc===true;
    var bg=isEtc?'#f5f0e0':i%2===0?'#fff':'#fafafa';
    var hasDetail=c.detail&&c.detail.length>0;
    var cursor=hasDetail?'cursor:pointer':'';
    var arrow=hasDetail?'<span style="font-size:10px;margin-right:4px;display:inline-block;transition:transform .2s" class="etc-arrow">▶</span>':'';
    h+='<tr data-etc-idx="'+i+'" style="background:'+bg+';'+cursor+(isEtc?';font-style:italic':'')+'"><td style="padding:3px 6px;text-align:center;border:1px solid #eee">'+(isEtc?'':String(i+1))+'</td>';
    h+='<td style="padding:3px 6px;text-align:left;border:1px solid #eee;max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+(isEtc?'':arrow)+c.n+'</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(c.nm||0).toLocaleString()+'</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(c.nc||0).toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(c.np||0).toFixed(1)+'%</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(c.em||0).toLocaleString()+'</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(c.ec||0).toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(c.ep||0).toFixed(1)+'%</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee;font-weight:600">'+c.m.toLocaleString()+'</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee;font-weight:600">'+c.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee;font-weight:600">'+c.p.toFixed(1)+'%</td></tr>';
    if(hasDetail){{
      h+='<tr class="etc-detail-'+i+'" style="display:none"><td colspan="11" style="padding:0;border:1px solid #eee">';
      h+='<table style="width:100%;border-collapse:collapse;font-size:10px;background:#f8f5ff">';
      for(var di=0;di<c.detail.length;di++){{
        var dd=c.detail[di];var dbg=di%2===0?'#f8f5ff':'#f0ebfa';
        h+='<tr style="background:'+dbg+'"><td style="padding:2px 6px;text-align:center;border:1px solid #e8e0f0;width:28px">'+(di+1)+'</td>';
        h+='<td style="padding:2px 6px;text-align:left;border:1px solid #e8e0f0">'+dd.n+'</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0">'+(dd.nm||0).toLocaleString()+'</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0">'+(dd.nc||0).toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0">'+(dd.np||0).toFixed(1)+'%</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0">'+(dd.em||0).toLocaleString()+'</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0">'+(dd.ec||0).toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0">'+(dd.ep||0).toFixed(1)+'%</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0;font-weight:600">'+dd.m.toLocaleString()+'</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0;font-weight:600">'+dd.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
        h+='<td style="padding:2px 5px;text-align:right;border:1px solid #e8e0f0;font-weight:600">'+dd.p.toFixed(1)+'%</td></tr>';
      }}
      h+='</table></td></tr>';
    }}
  }}
  var _tnm=0,_tnc=0,_tem=0,_tec=0,_tm=0,_tc=0;
  for(var ti=0;ti<d.camps.length;ti++){{var _r=d.camps[ti];_tnm+=(_r.nm||0);_tnc+=(_r.nc||0);_tem+=(_r.em||0);_tec+=(_r.ec||0);_tm+=_r.m;_tc+=_r.c;}}
  var _tnp=d.total>0?(_tnc/d.total*100):0,_tep=d.total>0?(_tec/d.total*100):0,_ttp=d.total>0?(_tc/d.total*100):0;
  h+='<tr style="background:#222;color:#fff;font-weight:700"><td style="padding:4px 6px;text-align:center;border:1px solid #555" colspan="2">합계</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tnm.toLocaleString()+'</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tnc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tnp.toFixed(1)+'%</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tem.toLocaleString()+'</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tec.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tep.toFixed(1)+'%</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tm.toLocaleString()+'</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_tc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
  h+='<td style="padding:3px 5px;text-align:right;border:1px solid #555">'+_ttp.toFixed(1)+'%</td></tr>';
  h+='</tbody></table></div>';
  if(d.sub&&d.sub.length>0){{
    h+='<div style="font-size:13px;font-weight:700;color:#2C3E50;margin-bottom:8px;margin-top:12px;border-bottom:2px solid #667eea;padding-bottom:5px">세부캠페인 현황</div>';
    h+='<div style="overflow-x:auto">';
    h+='<table style="width:100%;border-collapse:collapse;font-size:11px;margin-bottom:16px"><thead><tr>';
    h+='<th rowspan="2" style="background:#f0f2f5;padding:5px 6px;text-align:center;border:1px solid #e0e0e0;width:28px">순위</th>';
    h+='<th rowspan="2" style="background:#f0f2f5;padding:5px 6px;text-align:left;border:1px solid #e0e0e0;min-width:120px">세부캠페인명</th>';
    h+='<th colspan="3" style="background:#e8f5e9;padding:4px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:700">신규회원</th>';
    h+='<th colspan="3" style="background:#e3f2fd;padding:4px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:700">기존회원</th>';
    h+='<th colspan="3" style="background:#fff3e0;padding:4px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:700">합계</th>';
    h+='</tr><tr>';
    for(var shi=0;shi<3;shi++){{h+='<th style="background:'+_hbgs[shi]+';padding:3px 5px;text-align:right;border:1px solid #e0e0e0;font-size:10px;width:45px">개발명</th><th style="background:'+_hbgs[shi]+';padding:3px 5px;text-align:right;border:1px solid #e0e0e0;font-size:10px;width:50px">개발건</th><th style="background:'+_hbgs[shi]+';padding:3px 5px;text-align:right;border:1px solid #e0e0e0;font-size:10px;width:42px">구성비</th>';}}
    h+='</tr></thead><tbody>';
    for(var j=0;j<d.sub.length;j++){{
      var s=d.sub[j];var sbg=j%2===0?'#fff':'#fafafa';
      h+='<tr style="background:'+sbg+'"><td style="padding:3px 6px;text-align:center;border:1px solid #eee">'+(j+1)+'</td>';
      h+='<td style="padding:3px 6px;text-align:left;border:1px solid #eee;max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+s.n+'">'+s.n+'</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(s.nm||0).toLocaleString()+'</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(s.nc||0).toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(s.np||0).toFixed(1)+'%</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(s.em||0).toLocaleString()+'</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(s.ec||0).toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee">'+(s.ep||0).toFixed(1)+'%</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee;font-weight:600">'+s.m.toLocaleString()+'</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee;font-weight:600">'+s.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="padding:3px 5px;text-align:right;border:1px solid #eee;font-weight:600">'+s.p.toFixed(1)+'%</td></tr>';
    }}
    h+='</tbody></table></div>';
  }}
  h+='</div>';
  box.innerHTML=h;
  box.scrollTop=0;
  doc.getElementById('cat-close-btn').addEventListener('click',function(){{ov.style.display='none'}});
  // 기타 브랜드 행 클릭 → 캠페인카테고리 상세 토글
  var etcRows=box.querySelectorAll('tr[data-etc-idx]');
  etcRows.forEach(function(tr){{
    tr.addEventListener('click',function(ev){{
      ev.stopPropagation();
      var idx2=tr.getAttribute('data-etc-idx');
      var detail=box.querySelector('.etc-detail-'+idx2);
      if(!detail)return;
      var arrow=tr.querySelector('.etc-arrow');
      if(detail.style.display==='none'){{
        detail.style.display='table-row';
        if(arrow)arrow.style.transform='rotate(90deg)';
      }}else{{
        detail.style.display='none';
        if(arrow)arrow.style.transform='rotate(0deg)';
      }}
    }});
  }});
  if(_keys.length>1){{
    var prev=doc.getElementById('cat-prev'),next=doc.getElementById('cat-next');
    if(prev)prev.addEventListener('click',function(){{if(_idx>0)render(_idx-1);}});
    if(next)next.addEventListener('click',function(){{if(_idx<_keys.length-1)render(_idx+1);}});
  }}
}}
function onClick(e){{
  var td=e.target.closest('td[data-cat-popup]');
  if(td){{
    var raw=td.getAttribute('data-cat-popup');
    _keys=raw.split('||').filter(function(k){{return D[k];}});
    if(_keys.length>0){{render(0);ov.style.display='flex';}}
  }}
}}
doc.addEventListener('click',onClick);
doc._catPopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('cat-popup-overlay');if(o)o.remove();}};
}})();
</script>""", height=0)
    st.caption("출처: BRONZE_CRM (TM_MM_FDRM_MBER_DVLP_AMT + TM_CM_CMPGN_MNG — UPPER_CMPGN_CD 기준)")

    # ── 1-5 심층분석: 마케팅캠페인명 기준 ──
    st.markdown('<div style="height:28px"></div>', unsafe_allow_html=True)

    # 전년 동월 데이터 로드 (전년 대비 비교용)
    _prev_year = sel_year - 1
    _prev_raw = load_data(_prev_year)
    _prev_all = build_summary(_prev_raw)
    _prev_month_start = int(f"{_prev_year}{sel_month:02d}01")
    _prev_month_end = int(f"{_prev_year}{sel_month:02d}31")
    _prev_month_df = _prev_all[(_prev_all["OCCUR_DATE"] >= _prev_month_start) & (_prev_all["OCCUR_DATE"] <= _prev_month_end)]
    _prev_camp = {}
    if not _prev_month_df.empty:
        _pca = _prev_month_df.groupby("마케팅캠페인명").agg(개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")).reset_index()
        _prev_camp_total = float(_pca["개발건"].sum())
        for _, _pr in _pca.iterrows():
            _prev_camp[_pr["마케팅캠페인명"]] = {"건수": float(_pr["개발건"]), "명수": int(_pr["개발명"]),
                "비율": round(float(_pr["개발건"]) / _prev_camp_total * 100, 1) if _prev_camp_total > 0 else 0}

    # 최근 3개월 마케팅캠페인명별 집계
    _recent_months = sorted(df_all["STRD_MT"].unique())
    _recent_months = [m for m in _recent_months if int(m) <= int(f"{sel_year}{sel_month:02d}")]
    _last3 = _recent_months[-3:] if len(_recent_months) >= 3 else _recent_months

    # 당월 마케팅캠페인명 TOP 10
    _camp_month = df_month.groupby("마케팅캠페인명").agg(
        개발명=("MBER_NO", "nunique"), 개발건=("개발건", "sum")
    ).sort_values("개발건", ascending=False).reset_index()
    _camp_month_total = float(_camp_month["개발건"].sum())
    _camp_month["구성비"] = _camp_month["개발건"].apply(lambda x: round(x / _camp_month_total * 100, 1) if _camp_month_total > 0 else 0)
    _camp_top10 = _camp_month.head(10)

    # 최근 3개월 월별 집계 (추이 분석용)
    _trend_data = {}
    for _mt in _last3:
        _mt_df = df_all[df_all["STRD_MT"] == _mt]
        _mt_agg = _mt_df.groupby("마케팅캠페인명")["개발건"].sum()
        _mt_total = float(_mt_agg.sum())
        for _cn, _cv in _mt_agg.items():
            if _cn not in _trend_data:
                _trend_data[_cn] = {}
            _trend_data[_cn][_mt] = {"건수": float(_cv), "비율": round(float(_cv) / _mt_total * 100, 1) if _mt_total > 0 else 0}

    # 당월 마케팅캠페인명별 개발유형 상세
    _camp_type_detail = {}
    if not df_month.empty:
        for _cn, _g in df_month.groupby("마케팅캠페인명"):
            _det = {}
            _tot = float(_g["개발건"].sum())
            for _typ in ["신규", "재후원", "증액"]:
                _tv = float(_g[_g["개발구분"] == _typ]["개발건"].sum())
                _det[_typ] = {"건수": _tv, "비율": round(_tv / _tot * 100, 1) if _tot > 0 else 0}
            _camp_type_detail[_cn] = _det

    # 3개월 연속 변화 감지
    _change_rows = []
    for _cn, _months in _trend_data.items():
        if len(_last3) >= 3 and all(m in _months for m in _last3):
            _v0 = _months[_last3[0]]["건수"]
            _v1 = _months[_last3[1]]["건수"]
            _v2 = _months[_last3[2]]["건수"]
            _p0 = _months[_last3[0]]["비율"]
            _p2 = _months[_last3[2]]["비율"]
            _pct_change = round(_p2 - _p0, 1)
            _is_rising = _v2 > _v1 > _v0 and _v2 > 0
            _is_falling = _v2 < _v1 < _v0 and _v0 > 0
            if _is_rising or _is_falling or abs(_pct_change) >= 1.0:
                _change_rows.append({
                    "캠페인": _cn,
                    f"{int(str(_last3[0])[-2:])}월": _v0, f"{int(str(_last3[1])[-2:])}월": _v1, f"{int(str(_last3[2])[-2:])}월": _v2,
                    "비율변화": _pct_change, "추세": "급등" if _is_rising else ("급락" if _is_falling else ("상승" if _pct_change > 0 else "하락")),
                    "당월건수": _v2, "당월비율": _p2,
                })
    _rising_camps = sorted([r for r in _change_rows if r["비율변화"] > 0], key=lambda x: -x["비율변화"])[:5]
    _falling_camps = sorted([r for r in _change_rows if r["비율변화"] < 0], key=lambda x: x["비율변화"])[:5]

    # ── 인사이트 카드 ──
    if not _camp_top10.empty:
        _t1 = _camp_top10.iloc[0]
        _t3_pct = float(_camp_top10.head(3)["구성비"].sum())
        _t5_pct = float(_camp_top10.head(5)["구성비"].sum())
        _t10_pct = float(_camp_top10["구성비"].sum())

        _ih = '<div style="background:linear-gradient(135deg,#f8f9fa,#e8f4fd);border:2px solid #1565C0;border-radius:12px;padding:20px 24px;margin-bottom:20px;">'
        _ih += '<div style="font-weight:800;font-size:15px;color:#1565C0;margin-bottom:14px;border-bottom:2px solid #FFB300;padding-bottom:8px;">컨텐츠 심층 분석</div>'

        # 핵심 지표 카드 (TOP 10 집중도 · 1위 비중 · 전년 동월 대비)
        _top10_sum = float(_camp_top10["개발건"].sum())
        _top10_pct = _top10_sum / _camp_month_total * 100 if _camp_month_total > 0 else 0
        _prev_top10_sum = sum(_prev_camp.get(_cn, {}).get("건수", 0) for _cn in _camp_top10["마케팅캠페인명"])
        _kpi_yoy = (_top10_sum - _prev_top10_sum) / _prev_top10_sum * 100 if _prev_top10_sum > 0 else None
        _kpi_yoy_html = (f'<span style="color:{"#C62828" if _kpi_yoy >= 0 else "#1565C0"}">{"▲" if _kpi_yoy >= 0 else "▼"} {_kpi_yoy:+.1f}%</span>'
                         if _kpi_yoy is not None else "-")
        _kbox = "flex:1;min-width:180px;background:#fff;border-radius:8px;padding:14px;box-shadow:0 1px 4px rgba(0,0,0,0.08);"
        _klbl = "font-size:13px;color:#666;font-weight:600"
        _kval = "font-size:24px;font-weight:800;margin-top:2px"
        _ih += '<div style="display:flex;gap:16px;flex-wrap:wrap;margin-bottom:16px;">'
        _ih += (f'<div style="{_kbox}border-left:4px solid #2E7D32;"><div style="{_klbl}">TOP 10 합계 비중</div>'
                f'<div style="{_kval}color:#2E7D32;">{_top10_pct:.1f}%</div>'
                f'<div style="font-size:12px;color:#888">{_top10_sum:,.0f}건 / 전체 {_camp_month_total:,.0f}건</div></div>')
        _ih += (f'<div style="{_kbox}border-left:4px solid #0D47A1;"><div style="{_klbl}">1위 단독 비중</div>'
                f'<div style="{_kval}color:#0D47A1;">{float(_t1["구성비"]):.1f}%</div>'
                f'<div style="font-size:12px;color:#888;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="{_t1["마케팅캠페인명"]}">{_t1["마케팅캠페인명"]}</div></div>')
        _ih += (f'<div style="{_kbox}border-left:4px solid #6A1B9A;"><div style="{_klbl}">TOP 10 전년 동월 대비</div>'
                f'<div style="{_kval}">{_kpi_yoy_html}</div>'
                f'<div style="font-size:12px;color:#888">전년 동월 동일 캠페인 {_prev_top10_sum:,.0f}건</div></div>')
        _ih += '</div>'

        # 3개월 추이 변화 + 전년 동월 비교
        if _rising_camps or _falling_camps:
            _m_labels = [f'{int(str(m)[-2:])}월' for m in _last3]
            _ih += '<div style="display:flex;gap:16px;flex-wrap:wrap;">'
            if _rising_camps:
                _ih += '<div style="flex:1;min-width:380px;background:#E8F5E9;border-radius:8px;padding:14px;">'
                _ih += f'<div style="font-weight:700;color:#2E7D32;margin-bottom:8px;">▲ 최근 3개월 비중 상승 캠페인 ({_m_labels[0]}→{_m_labels[-1]})</div>'
                _ih += '<table style="width:100%;border-collapse:collapse;font-size:11px;"><thead><tr>'
                _ih += '<th style="text-align:left;padding:3px 6px;border-bottom:1px solid #c8e6c9;">캠페인명</th>'
                for _ml in _m_labels:
                    _ih += f'<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #c8e6c9;">{_ml}</th>'
                _ih += '<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #c8e6c9;">변화</th>'
                _ih += f'<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #c8e6c9;color:#1565C0;">{_prev_year}년<br>{sel_month}월</th>'
                _ih += f'<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #c8e6c9;color:#1565C0;">전년비</th>'
                _ih += '<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #c8e6c9;">당월 구성</th>'
                _ih += '</tr></thead><tbody>'
                for _rc in _rising_camps:
                    _pv = _prev_camp.get(_rc["캠페인"], {})
                    _pv_val = _pv.get("건수", 0)
                    _yoy = round((_rc["당월건수"] - _pv_val) / _pv_val * 100, 1) if _pv_val > 0 else 0
                    _yoy_color = "#2E7D32" if _yoy > 0 else "#E65100" if _yoy < 0 else "#777"
                    _yoy_sign = "+" if _yoy > 0 else ""
                    _td = _camp_type_detail.get(_rc["캠페인"], {})
                    _td_parts = []
                    for _typ, _clr in [("신규", "#1976D2"), ("재후원", "#E65100"), ("증액", "#2E7D32")]:
                        _tv = _td.get(_typ, {"건수": 0, "비율": 0})
                        if _tv["건수"] > 0:
                            _td_parts.append(f'<span style="color:{_clr};font-weight:600;">{_typ} {_tv["비율"]:.0f}%</span>')
                    _td_str = " · ".join(_td_parts) if _td_parts else "-"
                    _ih += '<tr>'
                    _ih += f'<td style="padding:3px 6px;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="{_rc["캠페인"]}">{_rc["캠페인"]}</td>'
                    for _ml in _m_labels:
                        _ih += f'<td style="text-align:right;padding:3px 6px;">{_rc[_ml]:,.1f}</td>'
                    _ih += f'<td style="text-align:right;padding:3px 6px;color:#2E7D32;font-weight:700;">+{_rc["비율변화"]:.1f}%p</td>'
                    _ih += f'<td style="text-align:right;padding:3px 6px;color:#888;">{_pv_val:,.1f}</td>'
                    if _pv_val > 0:
                        _ih += f'<td style="text-align:right;padding:3px 6px;color:{_yoy_color};font-weight:700;">{_yoy_sign}{_yoy:.1f}%</td>'
                    else:
                        _ih += '<td style="text-align:right;padding:3px 6px;color:#bbb;">신규</td>'
                    _ih += f'<td style="text-align:right;padding:3px 6px;font-size:10px;">{_td_str}</td>'
                    _ih += '</tr>'
                _ih += '</tbody></table></div>'

            if _falling_camps:
                _ih += '<div style="flex:1;min-width:380px;background:#FFF3E0;border-radius:8px;padding:14px;">'
                _ih += f'<div style="font-weight:700;color:#E65100;margin-bottom:8px;">▼ 최근 3개월 비중 하락 캠페인 ({_m_labels[0]}→{_m_labels[-1]})</div>'
                _ih += '<table style="width:100%;border-collapse:collapse;font-size:11px;"><thead><tr>'
                _ih += '<th style="text-align:left;padding:3px 6px;border-bottom:1px solid #ffe0b2;">캠페인명</th>'
                for _ml in _m_labels:
                    _ih += f'<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #ffe0b2;">{_ml}</th>'
                _ih += '<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #ffe0b2;">변화</th>'
                _ih += f'<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #ffe0b2;color:#1565C0;">{_prev_year}년<br>{sel_month}월</th>'
                _ih += f'<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #ffe0b2;color:#1565C0;">전년비</th>'
                _ih += '<th style="text-align:right;padding:3px 6px;border-bottom:1px solid #ffe0b2;">당월 구성</th>'
                _ih += '</tr></thead><tbody>'
                for _fc in _falling_camps:
                    _pv = _prev_camp.get(_fc["캠페인"], {})
                    _pv_val = _pv.get("건수", 0)
                    _yoy = round((_fc["당월건수"] - _pv_val) / _pv_val * 100, 1) if _pv_val > 0 else 0
                    _yoy_color = "#2E7D32" if _yoy > 0 else "#E65100" if _yoy < 0 else "#777"
                    _yoy_sign = "+" if _yoy > 0 else ""
                    _td = _camp_type_detail.get(_fc["캠페인"], {})
                    _td_parts = []
                    for _typ, _clr in [("신규", "#1976D2"), ("재후원", "#E65100"), ("증액", "#2E7D32")]:
                        _tv = _td.get(_typ, {"건수": 0, "비율": 0})
                        if _tv["건수"] > 0:
                            _td_parts.append(f'<span style="color:{_clr};font-weight:600;">{_typ} {_tv["비율"]:.0f}%</span>')
                    _td_str = " · ".join(_td_parts) if _td_parts else "-"
                    _ih += '<tr>'
                    _ih += f'<td style="padding:3px 6px;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="{_fc["캠페인"]}">{_fc["캠페인"]}</td>'
                    for _ml in _m_labels:
                        _ih += f'<td style="text-align:right;padding:3px 6px;">{_fc[_ml]:,.1f}</td>'
                    _ih += f'<td style="text-align:right;padding:3px 6px;color:#E65100;font-weight:700;">{_fc["비율변화"]:.1f}%p</td>'
                    _ih += f'<td style="text-align:right;padding:3px 6px;color:#888;">{_pv_val:,.1f}</td>'
                    if _pv_val > 0:
                        _ih += f'<td style="text-align:right;padding:3px 6px;color:{_yoy_color};font-weight:700;">{_yoy_sign}{_yoy:.1f}%</td>'
                    else:
                        _ih += '<td style="text-align:right;padding:3px 6px;color:#bbb;">신규</td>'
                    _ih += f'<td style="text-align:right;padding:3px 6px;font-size:10px;">{_td_str}</td>'
                    _ih += '</tr>'
                _ih += '</tbody></table></div>'
            _ih += '</div>'

        _ih += '</div>'
        st.markdown(_ih, unsafe_allow_html=True)

    # ── 차트: TOP 10 마케팅캠페인명 당월 개발건 ──
    st.markdown('<div style="height:16px"></div>', unsafe_allow_html=True)
    st.caption("▼ 당월 마케팅캠페인 TOP 10 (개발건) — 개발유형 구성 · 전년 동월 대비")
    if not _camp_top10.empty:
        _cb_df = _camp_top10.copy()
        _cb_order = _cb_df["마케팅캠페인명"].tolist()
        _cb_max = float(_cb_df["개발건"].max())

        # 개발유형별 누적 막대 데이터
        _TYPES = ["신규", "재후원", "증액"]
        _stk_rows = []
        for _, _r in _cb_df.iterrows():
            _cn = _r["마케팅캠페인명"]
            _det = _camp_type_detail.get(_cn, {})
            for _i, _t in enumerate(_TYPES):
                _v = float(_det.get(_t, {}).get("건수", 0))
                _pp = float(_det.get(_t, {}).get("비율", 0))
                _stk_rows.append({"마케팅캠페인명": _cn, "유형": _t, "건수": round(_v, 1), "유형비율": _pp,
                                  "라벨": f"{_pp:.0f}%", "_o": _i})
        _stk_df = pd.DataFrame(_stk_rows)
        _stk_df["_mid"] = _stk_df.groupby("마케팅캠페인명")["건수"].cumsum() - _stk_df["건수"] / 2

        # 합계 · 전년 대비 라벨
        _lbl_rows = []
        for _, _r in _cb_df.iterrows():
            _cn, _cur = _r["마케팅캠페인명"], float(_r["개발건"])
            _pv = _prev_camp.get(_cn, {}).get("건수")
            if not _pv:
                _yoy, _dir = "NEW (전년 없음)", "new"
            else:
                _d = _cur - _pv
                _yoy = f'{"▲" if _d >= 0 else "▼"} {_d:+,.0f}건 ({_d / _pv * 100:+.0f}%)'
                _dir = "up" if _d >= 0 else "down"
            _lbl_rows.append({"마케팅캠페인명": _cn, "개발건": _cur, "합계라벨": f'{_cur:,.0f}건 ({_r["구성비"]:.1f}%)',
                              "전년": f"{_pv:,.1f}" if _pv else "-", "증감": _yoy, "방향": _dir,
                              "_yx": _cb_max * 1.38})
        _lbl_df = pd.DataFrame(_lbl_rows)

        _y_enc = alt.Y("마케팅캠페인명:N", sort=_cb_order, title=None,
                       axis=alt.Axis(labelFontSize=14, labelFontWeight="bold", labelLimit=260))
        _x_scale = alt.Scale(domain=[0, _cb_max * 1.85])
        _cb_bar = alt.Chart(_stk_df).mark_bar(size=32).encode(
            y=_y_enc,
            x=alt.X("건수:Q", stack="zero", scale=_x_scale, title="개발건",
                    axis=alt.Axis(labelFontSize=13, titleFontSize=13, format=",.0f")),
            color=alt.Color("유형:N", scale=alt.Scale(domain=_TYPES, range=["#A8D8EA", "#FFD3B6", "#D5E8D4"]),
                            legend=alt.Legend(orient="top", title=None, labelFontSize=14, symbolSize=220)),
            order=alt.Order("_o:Q"),
            tooltip=[alt.Tooltip("마케팅캠페인명:N"), alt.Tooltip("유형:N"), alt.Tooltip("건수:Q", format=",.1f"),
                     alt.Tooltip("유형비율:Q", format=".1f", title="캠페인 내 비율(%)")],
        )
        _seg_text = alt.Chart(_stk_df[_stk_df["건수"] >= _cb_max * 0.08]).mark_text(
            fontSize=12, fontWeight="bold", color="#333"
        ).encode(y=alt.Y("마케팅캠페인명:N", sort=_cb_order), x=alt.X("_mid:Q", scale=_x_scale), text="라벨:N")
        _tot_text = alt.Chart(_lbl_df).mark_text(align="left", dx=6, fontSize=14, fontWeight="bold", color="#333").encode(
            y=alt.Y("마케팅캠페인명:N", sort=_cb_order), x=alt.X("개발건:Q", scale=_x_scale), text="합계라벨:N")
        _yoy_text = alt.Chart(_lbl_df).mark_text(align="left", fontSize=14, fontWeight="bold").encode(
            y=alt.Y("마케팅캠페인명:N", sort=_cb_order), x=alt.X("_yx:Q", scale=_x_scale), text="증감:N",
            color=alt.Color("방향:N", scale=alt.Scale(domain=["up", "down", "new"], range=["#C62828", "#1565C0", "#8E24AA"]), legend=None),
            tooltip=[alt.Tooltip("마케팅캠페인명:N"), alt.Tooltip("전년:N", title="전년 동월(건)"), alt.Tooltip("증감:N", title="전년 대비")],
        )
        st.altair_chart((_cb_bar + _seg_text + _tot_text + _yoy_text).resolve_scale(color="independent")
                        .properties(height=540), use_container_width=True)
        st.caption("※ 막대 안 % = 캠페인 내 개발유형 비율 / 오른쪽 = 전년 동월 대비 증감 (▲빨강 증가 · ▼파랑 감소 · NEW 전년 실적 없음)")

    st.markdown('<div style="height:12px"></div>', unsafe_allow_html=True)

    st.divider()
    st.caption("전체 데이터 출처: GN_DW.BRONZE_CRM — MSTR FN_MM_SPNSR_DVLP 개발구분 1/2/4 로직 재현 (사단법인 필터: CPR_DIV_CD='I')")

elif selected_tab == TAB_LABELS[1]:

    # ===== 2. 회원활동(2안) — MSTR_ODS 원천 기반 활동/중단 재현 =====

    # 1. 회원개발 탭과 동일한 테이블 스타일 + slide-up 애니메이션
    st.markdown("""
    <style>
        @keyframes slideUp {
            from { opacity: 0; transform: translateY(60px); }
            to   { opacity: 1; transform: translateY(0); }
        }
        .stMarkdown, .stAltairChart, .stColumns, .stExpander, .stCaption, [data-testid="stHorizontalBlock"] {
            animation: slideUp 0.6s ease-out both;
        }
        table {
            width: 100% !important;
            border-collapse: collapse !important;
            font-size: 12px !important;
            margin-bottom: 0 !important;
        }
        th {
            background-color: #4a4a4a !important;
            color: white !important;
            padding: 6px 5px !important;
            text-align: center !important;
            border: 1px solid #ddd !important;
            font-weight: 600 !important;
            white-space: nowrap !important;
        }
        td {
            padding: 5px 5px !important;
            text-align: right !important;
            border: 1px solid #ddd !important;
            white-space: nowrap !important;
        }
        td:first-child, td:nth-child(2), td:nth-child(3) {
            text-align: left !important;
        }
    </style>
    """, unsafe_allow_html=True)





    with st.spinner("MSTR_ODS 기반 활동회원 집계 중... (소요시간 약 1~2분)"):
        v2_df = load_active_v2(sel_year, sel_month)
        _act_camp_df = _load_active_campaign_popup(sel_year, sel_month)



    if not v2_df.empty:

        # 본부/시도본부 파생 요소 계산 (MSTR 분석엔진 파생 요소)

        v2_df["본부지부"] = v2_df["DEPT4_NM"].apply(

            lambda x: "본부" if x in ("본부", "본부(사복)") else "시도본부 및 지부"

        )



        # 연도초 활동회원 — 추후 목표파일 업로드로 대체 예정
        BOY_ACTIVE_MEMBERS = 614161
        BOY_ACTIVE_CASES = 1311308.07

        # 월말 활동회원 목표(건) — DB에서 동적 로드

        act_goal_df = _load_active_target(sel_year)
        mcol_act = f"M{sel_month:02d}"
        rcol_act = f"R{sel_month:02d}"

        def _get_act_target(new_old, org_div):
            if org_div is None:
                mask = act_goal_df["NEW_OLD_DIV_NM"] == new_old
                mask = mask & act_goal_df["ORG_DIV_NM"].isna()
            else:
                mask = (act_goal_df["NEW_OLD_DIV_NM"] == new_old) & (act_goal_df["ORG_DIV_NM"] == org_div)
            rows = act_goal_df[mask]
            return int(rows[mcol_act].sum()) if not rows.empty else 0

        def _get_act_target_raw(new_old, org_div):
            if org_div is None:
                mask = act_goal_df["NEW_OLD_DIV_NM"] == new_old
                mask = mask & act_goal_df["ORG_DIV_NM"].isna()
            else:
                mask = (act_goal_df["NEW_OLD_DIV_NM"] == new_old) & (act_goal_df["ORG_DIV_NM"] == org_div)
            rows = act_goal_df[mask]
            return float(rows[rcol_act].sum()) if not rows.empty else 0.0

        ACTIVE_TARGET = {
            "본부": _get_act_target("신규", "본부"),
            "시도본부 및 지부": _get_act_target("신규", "지부"),
            "기존회원": _get_act_target("기존", None),
        }
        # 소계/합계는 원본 합산 후 round
        _raw_hq = _get_act_target_raw("신규", "본부")
        _raw_sido = _get_act_target_raw("신규", "지부")
        _raw_exist = _get_act_target_raw("기존", None)
        ACTIVE_TARGET["소계"] = round(_raw_hq + _raw_sido)
        ACTIVE_TARGET["합계"] = round(_raw_hq + _raw_sido + _raw_exist)

        # 활동율 목표(%) — DB에서 동적 로드 (목표구분: 신규기존활동율)

        act_rate_df = _load_activity_rate_target(sel_year)
        _rate_mcol = f"M{sel_month:02d}"

        def _get_rate_val(df, new_old, org_div, col):
            if org_div is None:
                mask = (df["NEW_OLD_DIV_NM"] == new_old) & df["ORG_DIV_NM"].isna()
            else:
                mask = (df["NEW_OLD_DIV_NM"] == new_old) & (df["ORG_DIV_NM"] == org_div)
            rows = df[mask]
            if rows.empty:
                return 0.0
            return round(float(rows[col].values[0]) * 100, 1)

        ACTIVE_RATE_TARGET = {
            "본부": _get_rate_val(act_rate_df, "신규", "본부", _rate_mcol),
            "시도본부 및 지부": _get_rate_val(act_rate_df, "신규", "지부", _rate_mcol),
            "소계": _get_rate_val(act_rate_df, "신규합계", None, _rate_mcol),
            "기존회원": _get_rate_val(act_rate_df, "기존", None, _rate_mcol),
            "합계": _get_rate_val(act_rate_df, "합계", None, _rate_mcol),
        }

        ANNUAL_RATE_TARGET = {
            "본부": _get_rate_val(act_rate_df, "신규", "본부", "M12"),
            "시도본부 및 지부": _get_rate_val(act_rate_df, "신규", "지부", "M12"),
            "소계": _get_rate_val(act_rate_df, "신규합계", None, "M12"),
            "기존회원": _get_rate_val(act_rate_df, "기존", None, "M12"),
            "합계": _get_rate_val(act_rate_df, "합계", None, "M12"),
        }

        # 1-4표(누계) 데이터에서 행별 누계 개발건 추출
        # — 탭1의 result_mem_ytd를 여기서 재생성
        raw_df_for_ytd = load_data(sel_year)
        df_all_for_ytd = build_summary(raw_df_for_ytd)
        if exclude_fake and sel_year == 2025:
            exclude_set = set(EXCLUDED_MEMBERS_2025)
            df_all_for_ytd = df_all_for_ytd[~df_all_for_ytd.apply(lambda r: (r["MBER_NO"], r["STRD_MT"]) in exclude_set, axis=1)]
        month_end_int = int(f"{sel_year}{sel_month:02d}31")
        ytd_start_int = int(f"{sel_year}0101")
        df_ytd_for_mem = df_all_for_ytd[(df_all_for_ytd["OCCUR_DATE"] >= ytd_start_int) & (df_all_for_ytd["OCCUR_DATE"] <= month_end_int)]
        _, YTD_MEMBER_TARGET_TAB2 = _build_member_targets(sel_year, sel_month)
        result_mem_ytd = make_member_type_pivot(df_ytd_for_mem, YTD_MEMBER_TARGET_TAB2)
        result_mem_ytd = apply_adjustment_member(result_mem_ytd, sel_year, sel_month, is_ytd=True)

        ytd_dev_map = {}
        if not result_mem_ytd.empty:
            for _, r in result_mem_ytd.iterrows():
                label = r["본부/지부"]
                if label == "본부":
                    ytd_dev_map["본부"] = float(r["합계"])
                elif label == "시도본부 및 지부":
                    ytd_dev_map["시도본부 및 지부"] = float(r["합계"])
                elif label == "신규회원 소계":
                    ytd_dev_map["소계"] = float(r["합계"])
                elif label == "기존회원":
                    ytd_dev_map["기존회원"] = float(r["합계"])
                elif label == "합계":
                    ytd_dev_map["합계"] = float(r["합계"])

        # ── 연도별 월말 활동율(%) 추이 표 + 그래프 ──
        _HIST_ACTIVITY_RATE = {
            "2019년": [98.0, 97.0, 95.2, 94.1, 93.1, 92.1, 91.1, 90.2, 89.2, 88.2, 87.3, 85.9],
            "2020년": [98.4, 97.1, 95.9, 94.7, 93.2, 92.0, 91.1, 90.3, 89.4, 86.9, 83.7, 81.6],
            "2021년": [98.5, 97.2, 96.1, 95.2, 94.4, 93.5, 92.7, 91.9, 91.2, 90.5, 89.9, 88.7],
            "2022년": [98.7, 97.7, 96.7, 95.9, 95.0, 94.1, 93.2, 92.3, 91.5, 90.5, 89.6, 88.2],
            "2023년": [98.4, 97.1, 95.8, 94.7, 93.6, 92.6, 91.4, 90.2, 88.7, 87.5, 86.5, 85.1],
            "2024년": [98.1, 96.6, 95.3, 94.1, 93.0, 92.0, 90.9, 89.8, 88.9, 87.8, 87.0, 85.7],
            "2025년": [98.4, 96.9, 95.6, 94.3, 93.1, 92.0, 90.8, 89.7, 88.6, 87.6, 86.7, 85.3],
            "2026년": [98.3, 96.9, 95.4, 94.1, 92.8, 91.6, 90.3, 89.1, None, None, None, None],
        }

        # 조회년도 조회월의 합계 활동율을 현재 데이터로 업데이트
        _cur_year_key = f"{sel_year}년"
        if _cur_year_key not in _HIST_ACTIVITY_RATE:
            _HIST_ACTIVITY_RATE[_cur_year_key] = [None] * 12

        # 2-1 표 합계행의 월말 활동율(%) 계산
        _total_cases = float(v2_df["WJXBFS2"].sum())
        _total_act_rate = round(_total_cases / (BOY_ACTIVE_CASES + ytd_dev_map.get("합계", 0)) * 100, 1) if (BOY_ACTIVE_CASES + ytd_dev_map.get("합계", 0)) > 0 else 0.0
        _HIST_ACTIVITY_RATE[_cur_year_key][sel_month - 1] = _total_act_rate

        # ── 회원활동 KPI 카드 영역 ──
        _total_members = int(v2_df["WJXBFS1"].sum())
        _total_cases_kpi = float(v2_df["WJXBFS2"].sum())
        _per_member = round(_total_cases_kpi / _total_members, 2) if _total_members > 0 else 0
        _act_target_total = ACTIVE_TARGET.get("합계", 0)
        _act_achieve = round(_total_cases_kpi / _act_target_total * 100, 1) if _act_target_total > 0 else 0
        _rate_target_total = ACTIVE_RATE_TARGET.get("합계", 0)
        _rate_achieve = round(_total_act_rate / _rate_target_total * 100, 1) if _rate_target_total > 0 else 0

        # 전년 동월 비교
        _prev_years = {"2025년": "#FF8F00", "2023년": "#E53935", "2019년": "#43A047"}
        _prev_vals = {}
        for _py, _pc in _prev_years.items():
            _pv = _HIST_ACTIVITY_RATE.get(_py, [None]*12)[sel_month - 1]
            if _pv is not None:
                _prev_vals[_py] = {"val": _pv, "diff": round(_total_act_rate - _pv, 1), "color": _pc}

        # 올해 월별 활동율 (스파크라인용)
        _spark_data = []
        _cur_rates = _HIST_ACTIVITY_RATE.get(_cur_year_key, [None]*12)
        for _si in range(12):
            if _cur_rates[_si] is not None:
                _spark_data.append({"월": f"{_si+1}월", "활동율": _cur_rates[_si]})

        # ── KPI 카드 스타일 (회원개발 탭과 동일) ──
        _ac_card = (
            "background:linear-gradient(160deg,#ffffff 0%,#eef4fb 100%);"
            "border:2px solid #1565C0;border-top:6px solid #1565C0;border-radius:14px;padding:18px 22px;"
            "box-shadow:0 6px 18px rgba(21,101,192,0.18);"
            "height:340px;display:flex;flex-direction:column;justify-content:space-evenly;"
        )
        _ac_title = (
            "font-weight:900;font-size:19px;margin-bottom:6px;color:#0D47A1;letter-spacing:-0.3px;"
            "border-bottom:3px solid #FFB300;padding-bottom:8px;white-space:nowrap;"
        )
        _ac_row = "display:flex;justify-content:space-between;align-items:center;padding:5px 2px;"
        _ac_lbl = "color:#263238;font-size:18px;font-weight:700;"
        _ac_val = "font-weight:900;color:#0D47A1;font-size:30px;line-height:1.1;letter-spacing:-0.5px;"
        _ac_big = "font-weight:900;color:#0D47A1;font-size:48px;text-align:center;padding:6px 0;line-height:1.1;letter-spacing:-1px;"
        _ac_sub = "font-size:13px;color:#546E7A;margin-top:6px;line-height:1.5;"
        _ac_sep = "border-top:2px solid #CFD8DC;margin-top:4px;padding-top:8px;"

        # 전년 대비 HTML
        _prev_html_lines = ""
        for _py_name, _pinfo in _prev_vals.items():
            _diff_sign = "+" if _pinfo["diff"] >= 0 else ""
            _prev_html_lines += f'<div style="{_ac_row}"><span style="{_ac_lbl}">{_py_name}</span><span style="font-weight:900;font-size:26px;color:{_pinfo["color"]}">{_pinfo["val"]:.1f}% <span style="font-size:16px;font-weight:800;">({_diff_sign}{_pinfo["diff"]:.1f}%p)</span></span></div>'

        # ── Row 1: 카드 3개 ──
        _akr1, _akr2, _akr3 = st.columns(3, gap="small")

        with _akr1:
            _diff_2025 = _prev_vals.get("2025년", {})
            _diff_str = ""
            if _diff_2025:
                _d = _diff_2025["diff"]
                _diff_str = f'<div style="font-size:17px;font-weight:800;color:{"#E53935" if _d < 0 else "#43A047"};text-align:center;margin-top:2px;">vs 2025년 {"+" if _d >= 0 else ""}{_d:.1f}%p</div>'
            _annual_rate_target = ANNUAL_RATE_TARGET.get("합계", 0)
            st.markdown(f'''<div style="{_ac_card}">
              <div style="{_ac_title}">당월 월말 활동율(%)</div>
              <div style="{_ac_big}">{_total_act_rate:.1f}%</div>
              {_diff_str}
              <div style="display:flex;justify-content:center;gap:24px;margin-top:6px;">
                <div style="text-align:center;"><span style="font-size:15px;color:#546E7A;font-weight:700;">당월목표</span><br><span style="font-weight:900;font-size:22px;color:#37474F;">{_rate_target_total:.1f}%</span></div>
                <div style="text-align:center;"><span style="font-size:15px;color:#546E7A;font-weight:700;">누계목표</span><br><span style="font-weight:900;font-size:22px;color:#37474F;">{_annual_rate_target:.1f}%</span></div>
              </div>
            </div>''', unsafe_allow_html=True)

        with _akr2:
            _mem_diff = _total_members - BOY_ACTIVE_MEMBERS
            _mem_pct = round(_mem_diff / BOY_ACTIVE_MEMBERS * 100, 1) if BOY_ACTIVE_MEMBERS > 0 else 0
            _mem_sign = "+" if _mem_diff >= 0 else ""
            _mem_color = "#1565C0" if _mem_diff >= 0 else "#E53935"
            _case_diff = _total_cases_kpi - BOY_ACTIVE_CASES
            _case_pct = round(_case_diff / BOY_ACTIVE_CASES * 100, 1) if BOY_ACTIVE_CASES > 0 else 0
            _case_sign = "+" if _case_diff >= 0 else ""
            _case_color = "#1565C0" if _case_diff >= 0 else "#E53935"
            _sub_style = "font-size:11px;color:{color};margin-left:4px;"
            st.markdown(f'''<div style="{_ac_card}">
              <div style="display:flex;justify-content:space-between;align-items:flex-start;{_ac_title}">
                <span>활동회원 현황</span>
                <span style="font-size:12px;font-weight:600;color:#607D8B;text-align:right;line-height:1.4;white-space:nowrap;">연도초(명) {BOY_ACTIVE_MEMBERS:,}<br>연도초(건) {BOY_ACTIVE_CASES:,.0f}</span>
              </div>
              <div style="{_ac_row}"><span style="{_ac_lbl}">활동회원(명)</span><span style="{_ac_val}">{_total_members:,}</span></div>
              <div style="padding:0 0 2px 0;text-align:right;margin-top:-4px;"><span style="font-size:16px;font-weight:800;color:{_mem_color};">연도초 대비 {_mem_sign}{_mem_diff:,}명 ({_mem_sign}{_mem_pct:.1f}%)</span></div>
              <div style="{_ac_row}"><span style="{_ac_lbl}">활동회원(건)</span><span style="{_ac_val}">{_total_cases_kpi:,.1f}</span></div>
              <div style="padding:0 0 2px 0;text-align:right;margin-top:-4px;"><span style="font-size:16px;font-weight:800;color:{_case_color};">연도초 대비 {_case_sign}{_case_diff:,.1f}건 ({_case_sign}{_case_pct:.1f}%)</span></div>
              <div style="{_ac_row}{_ac_sep}margin-top:2px;"><span style="{_ac_lbl}font-weight:800;">명당건수</span><span style="{_ac_val}">{_per_member:.2f}</span></div>
            </div>''', unsafe_allow_html=True)

        with _akr3:
            st.markdown(f'''<div style="{_ac_card}">
              <div style="{_ac_title}">전년 대비 활동율 비교</div>
              <div>{_prev_html_lines}</div>
              <div style="{_ac_sub}">동월({sel_month}월) 기준 비교</div>
            </div>''', unsafe_allow_html=True)

        st.markdown('<div style="height:36px"></div>', unsafe_allow_html=True)

        # ── 2026년 월별 활동율 추이 (마우스오버 시 과거 연도 비교) ──
        _cur_year_rates = _HIST_ACTIVITY_RATE.get(_cur_year_key, [None]*12)
        _compare_years = ["2025년", "2024년", "2023년", "2021년", "2019년"]
        _rate_rows = []
        for _mi in range(12):
            _m_label = f"{_mi+1}월"
            _val = _cur_year_rates[_mi] if _mi < len(_cur_year_rates) and _cur_year_rates[_mi] is not None else None
            if _val is not None:
                _tooltip_lines = [f"{_cur_year_key}: {_val:.1f}%"]
                for _cy in _compare_years:
                    _cy_vals = _HIST_ACTIVITY_RATE.get(_cy, [None]*12)
                    _cv = _cy_vals[_mi] if _mi < len(_cy_vals) and _cy_vals[_mi] is not None else None
                    _tooltip_lines.append(f"{_cy}: {_cv:.1f}%" if _cv is not None else f"{_cy}: -")
                _rate_rows.append({
                    "월": _m_label, "활동율": _val, "_sort": _mi + 1,
                    "라벨": f"{_val:.1f}",
                    _cur_year_key: f"{_val:.1f}%",
                    **{_cy: (
                        f"{_HIST_ACTIVITY_RATE.get(_cy, [None]*12)[_mi]:.1f}% ({'+' if _val - _HIST_ACTIVITY_RATE.get(_cy, [None]*12)[_mi] >= 0 else ''}{_val - _HIST_ACTIVITY_RATE.get(_cy, [None]*12)[_mi]:.1f}%p)"
                        if _HIST_ACTIVITY_RATE.get(_cy, [None]*12)[_mi] is not None else "-"
                    ) for _cy in _compare_years}
                })

        _rate_df = pd.DataFrame(_rate_rows)
        _month_sort = [f"{m}월" for m in range(1, 13)]

        _rate_line = alt.Chart(_rate_df).mark_line(
            point=alt.OverlayMarkDef(size=120, filled=True, fill="#1565C0", stroke="#0D47A1", strokeWidth=2),
            strokeWidth=3, color="#1565C0"
        ).encode(
            x=alt.X("월:N", sort=_month_sort, axis=alt.Axis(labelFontSize=11, labelAngle=0, title=None)),
            y=alt.Y("활동율:Q", axis=alt.Axis(labelFontSize=10, format=".0f", title="활동율(%)"),
                     scale=alt.Scale(domain=[
                         max(0, _rate_df["활동율"].min() - 3),
                         min(100, _rate_df["활동율"].max() + 2)
                     ])),
            tooltip=[
                alt.Tooltip("월:N"),
                alt.Tooltip(f"{_cur_year_key}:N", title=_cur_year_key),
                *[alt.Tooltip(f"{_cy}:N", title=_cy) for _cy in _compare_years],
            ],
        )

        _rate_text = alt.Chart(_rate_df).mark_text(dy=-16, fontSize=12, fontWeight="bold", color="#0D47A1").encode(
            x=alt.X("월:N", sort=_month_sort),
            y=alt.Y("활동율:Q"),
            text="라벨:N",
        )

        _rate_chart = (_rate_line + _rate_text).properties(
            width="container",
            height=320,
            title=alt.Title(f"▼ {sel_year}년 월별 활동율 추이 (월말 기준, 마우스오버 시 과거 연도 비교)", fontSize=18, fontWeight=700, anchor="start")
        )

        st.altair_chart(_rate_chart, use_container_width=True)

        st.markdown('<div style="height:16px"></div>', unsafe_allow_html=True)

        # ※참고) 연도별 월말 활동율 표 — 접기/펼치기
        _months = [f"{m}월" for m in range(1, 13)]
        _rate_display_order = sorted(_HIST_ACTIVITY_RATE.keys(), reverse=True)

        _rate_th = "background-color:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px;"
        _rate_html = '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
        _rate_html += '<thead><tr>'
        _rate_html += f'<th style="{_rate_th}">구분</th>'
        for m in _months:
            _rate_html += f'<th style="{_rate_th}">{m}</th>'
        _rate_html += '</tr></thead><tbody>'
        for yr in _rate_display_order:
            vals = _HIST_ACTIVITY_RATE[yr]
            is_cur = yr == _cur_year_key
            tr_style = "background-color:#808000;color:white;font-weight:bold;" if is_cur else "background-color:#e8e4c9;"
            _rate_html += f'<tr style="{tr_style}">'
            _rate_html += f'<td style="padding:5px;border:1px solid #ddd;text-align:center;white-space:nowrap;font-weight:600;">{yr}</td>'
            for v in vals:
                _rate_html += f'<td style="padding:5px;border:1px solid #ddd;text-align:right;white-space:nowrap;">{v:.1f}%</td>' if v is not None else '<td style="padding:5px;border:1px solid #ddd;text-align:right;white-space:nowrap;color:#ccc;">-</td>'
            _rate_html += '</tr>'
            # 2026년 대비 증감 행 (현재 연도 자체는 제외)
            _cur_yr_vals = _HIST_ACTIVITY_RATE.get(_cur_year_key, [None]*12)
            if yr != _cur_year_key:
                _rate_html += '<tr style="background:#f5f5f5;font-size:11px;">'
                _rate_html += f'<td style="padding:3px 5px;border:1px solid #ddd;text-align:center;white-space:nowrap;color:#888;">vs {_cur_year_key}</td>'
                for _mi in range(12):
                    _cv = _cur_yr_vals[_mi]
                    _pv2 = vals[_mi]
                    if _cv is not None and _pv2 is not None:
                        _diff = round(_cv - _pv2, 1)
                        _clr = "#E53935" if _diff < 0 else "#43A047" if _diff > 0 else "#888"
                        _sign = "+" if _diff > 0 else ""
                        _rate_html += f'<td style="padding:3px 5px;border:1px solid #ddd;text-align:right;white-space:nowrap;color:{_clr};font-weight:600;">{_sign}{_diff:.1f}</td>'
                    else:
                        _rate_html += '<td style="padding:3px 5px;border:1px solid #ddd;text-align:right;white-space:nowrap;color:#ccc;">-</td>'
                _rate_html += '</tr>'
        _rate_html += '</tbody></table>'

        with st.expander("※참고) 연도별 월말 활동율(%) 추이 — 클릭하여 상세 보기"):
            st.markdown(_rate_html, unsafe_allow_html=True)

        st.markdown('<div style="height:20px"></div>', unsafe_allow_html=True)

        st.subheader("2-1. 활동회원 현황 (회원구분별)")
        st.caption("💡 활동회원(건) 숫자 클릭 시 마케팅캠페인 상세를 확인할 수 있습니다.")
        st.caption(f"연도초 활동회원(명): {BOY_ACTIVE_MEMBERS:,.0f} | 연도초 활동회원(건): {BOY_ACTIVE_CASES:,.2f}")

        st.markdown('<div style="height:30px"></div>', unsafe_allow_html=True)

        # 회원구분 × 본부/지부 집계
        def build_active_table_v2(df):
            rows = []

            def _calc_rate(cases, target):
                return round(cases / target * 100, 1) if target > 0 else 0.0

            def _calc_activity_rate(cases, key):
                if key in ("합계", "기존회원"):
                    denom = BOY_ACTIVE_CASES + ytd_dev_map.get(key, 0)
                else:
                    denom = ytd_dev_map.get(key, 0)
                return round(cases / denom * 100, 1) if denom > 0 else 0.0

            def _calc_act_achievement(activity_rate, target_rate):
                return round(activity_rate / target_rate * 100, 1) if target_rate > 0 else 0.0

            for new_old_nm, new_old_key in [("신규회원", "신규회원"), ("기존회원", "기존회원")]:
                sub = df[df["NEW_OLD_DIV_NM"] == new_old_nm]
                if new_old_nm == "신규회원":
                    for dept_div in ["본부", "시도본부 및 지부"]:
                        d = sub[sub["본부지부"] == dept_div]
                        members = int(d["WJXBFS1"].sum())
                        cases = float(d["WJXBFS2"].sum())
                        per = round(cases / members, 2) if members > 0 else 0
                        tgt = ACTIVE_TARGET.get(dept_div, 0)
                        act_rate = _calc_activity_rate(cases, dept_div)
                        act_tgt = ACTIVE_RATE_TARGET.get(dept_div, 0)
                        rows.append({
                            "신규/기존": new_old_nm,
                            "본부/지부": dept_div,
                            "월말 활동회원 목표(건)": tgt,
                            "활동회원(명)": members,
                            "활동회원(건)": cases,
                            "명당건수": per,
                            "달성율(%)": _calc_rate(cases, tgt),
                            "활동율 목표(%)": act_tgt,
                            "월말 활동율(%)": act_rate,
                            "달성율(%)_활동": _calc_act_achievement(act_rate, act_tgt),
                            f"{sel_year}년 활동율 목표(%)": ANNUAL_RATE_TARGET.get(dept_div, 0)
                        })
                    # 소계
                    new_members = int(sub["WJXBFS1"].sum())
                    new_cases = float(sub["WJXBFS2"].sum())
                    new_per = round(new_cases / new_members, 2) if new_members > 0 else 0
                    tgt = ACTIVE_TARGET["소계"]
                    act_rate = _calc_activity_rate(new_cases, "소계")
                    act_tgt = ACTIVE_RATE_TARGET["소계"]
                    rows.append({
                        "신규/기존": "",
                        "본부/지부": "소계",
                        "월말 활동회원 목표(건)": tgt,
                        "활동회원(명)": new_members,
                        "활동회원(건)": new_cases,
                        "명당건수": new_per,
                        "달성율(%)": _calc_rate(new_cases, tgt),
                        "활동율 목표(%)": act_tgt,
                        "월말 활동율(%)": act_rate,
                        "달성율(%)_활동": _calc_act_achievement(act_rate, act_tgt),
                        f"{sel_year}년 활동율 목표(%)": ANNUAL_RATE_TARGET["소계"]
                    })
                else:
                    members = int(sub["WJXBFS1"].sum())
                    cases = float(sub["WJXBFS2"].sum())
                    per = round(cases / members, 2) if members > 0 else 0
                    tgt = ACTIVE_TARGET["기존회원"]
                    act_rate = _calc_activity_rate(cases, "기존회원")
                    act_tgt = ACTIVE_RATE_TARGET["기존회원"]
                    rows.append({
                        "신규/기존": "기존회원",
                        "본부/지부": "기존회원",
                        "월말 활동회원 목표(건)": tgt,
                        "활동회원(명)": members,
                        "활동회원(건)": cases,
                        "명당건수": per,
                        "달성율(%)": _calc_rate(cases, tgt),
                        "활동율 목표(%)": act_tgt,
                        "월말 활동율(%)": act_rate,
                        "달성율(%)_활동": _calc_act_achievement(act_rate, act_tgt),
                        f"{sel_year}년 활동율 목표(%)": ANNUAL_RATE_TARGET["기존회원"]
                    })

            # 합계
            total_members = int(df["WJXBFS1"].sum())
            total_cases = float(df["WJXBFS2"].sum())
            total_per = round(total_cases / total_members, 2) if total_members > 0 else 0
            tgt = ACTIVE_TARGET["합계"]
            act_rate = _calc_activity_rate(total_cases, "합계")
            act_tgt = ACTIVE_RATE_TARGET["합계"]
            rows.append({
                "신규/기존": "합계",
                "본부/지부": "",
                "월말 활동회원 목표(건)": tgt,
                "활동회원(명)": total_members,
                "활동회원(건)": total_cases,
                "명당건수": total_per,
                "달성율(%)": _calc_rate(total_cases, tgt),
                "활동율 목표(%)": act_tgt,
                "월말 활동율(%)": act_rate,
                "달성율(%)_활동": _calc_act_achievement(act_rate, act_tgt),
                f"{sel_year}년 활동율 목표(%)": ANNUAL_RATE_TARGET["합계"]
            })

            return pd.DataFrame(rows)



        active_table_v2 = build_active_table_v2(v2_df)

        # ── 2-1 팝업 데이터 구축: 활동회원(건) → 마케팅캠페인명 상세 ──
        _act_popup = {}
        if not _act_camp_df.empty:
            def _act_brnd_map(sub):
                # 캠페인별 매칭 공통브랜드 (활동건 최다 브랜드)
                if "CMMN_BRND_NM" not in sub.columns:
                    return {}
                g = sub.groupby(["MKTG_CMPGN_NM", "CMMN_BRND_NM"])["ACT_CASES"].sum().reset_index()
                g = g.sort_values("ACT_CASES", ascending=False).drop_duplicates("MKTG_CMPGN_NM")
                return dict(zip(g["MKTG_CMPGN_NM"], g["CMMN_BRND_NM"]))

            def _build_act_camp(sub, key_name, total_cases):
                if total_cases == 0:
                    return None
                all_c = sub.groupby("MKTG_CMPGN_NM").agg(
                    활동명=("ACT_MEMBERS", "sum"), 활동건=("ACT_CASES", "sum")
                ).sort_values("활동건", ascending=False).reset_index()
                top20 = all_c.head(20)
                bmap = _act_brnd_map(sub)
                cl = []
                top_sum = 0.0
                for _, cr in top20.iterrows():
                    c_val = round(float(cr["활동건"]), 1)
                    top_sum += c_val
                    pct = round(c_val / total_cases * 100, 1) if total_cases > 0 else 0
                    cl.append({"b": str(bmap.get(cr["MKTG_CMPGN_NM"], "")), "n": str(cr["MKTG_CMPGN_NM"]), "m": int(cr["활동명"]), "c": c_val, "p": pct})
                if len(all_c) > 20:
                    etc_c = round(total_cases - top_sum, 1)
                    etc_m = int(all_c.iloc[20:]["활동명"].sum())
                    cl.append({"n": "그외", "m": etc_m, "c": etc_c, "p": round(etc_c / total_cases * 100, 1), "etc": True})
                return {"name": key_name, "total": round(total_cases, 1), "camps": cl}

            def _build_act_camp_biz(sub, key_name, total_cases):
                """2-2 전용: 캠페인별 신규/기존/합계 분리 집계"""
                if total_cases == 0:
                    return None
                new_sub = sub[sub["NEW_OLD"] == "신규회원"]
                old_sub = sub[sub["NEW_OLD"] == "기존회원"]
                new_total = float(new_sub["ACT_CASES"].sum())
                old_total = float(old_sub["ACT_CASES"].sum())
                # 합계 기준 top20
                all_c = sub.groupby("MKTG_CMPGN_NM").agg(활동명=("ACT_MEMBERS", "sum"), 활동건=("ACT_CASES", "sum")).sort_values("활동건", ascending=False).reset_index()
                new_c = new_sub.groupby("MKTG_CMPGN_NM").agg(활동명=("ACT_MEMBERS", "sum"), 활동건=("ACT_CASES", "sum")).reset_index().set_index("MKTG_CMPGN_NM")
                old_c = old_sub.groupby("MKTG_CMPGN_NM").agg(활동명=("ACT_MEMBERS", "sum"), 활동건=("ACT_CASES", "sum")).reset_index().set_index("MKTG_CMPGN_NM")
                top20 = all_c.head(20)
                bmap = _act_brnd_map(sub)
                cl = []
                top_m, top_c = 0, 0.0
                top_nm, top_nc = 0, 0.0
                top_em, top_ec = 0, 0.0
                for _, cr in top20.iterrows():
                    nm = cr["MKTG_CMPGN_NM"]
                    m_val = int(cr["활동명"]); c_val = round(float(cr["활동건"]), 1)
                    n_m = int(new_c.loc[nm, "활동명"]) if nm in new_c.index else 0
                    n_c = round(float(new_c.loc[nm, "활동건"]), 1) if nm in new_c.index else 0.0
                    e_m = int(old_c.loc[nm, "활동명"]) if nm in old_c.index else 0
                    e_c = round(float(old_c.loc[nm, "활동건"]), 1) if nm in old_c.index else 0.0
                    n_p = round(n_c / new_total * 100, 1) if new_total > 0 else 0
                    e_p = round(e_c / old_total * 100, 1) if old_total > 0 else 0
                    p_val = round(c_val / total_cases * 100, 1) if total_cases > 0 else 0
                    cl.append({"b": str(bmap.get(nm, "")), "n": str(nm), "nm": n_m, "nc": n_c, "np": n_p, "em": e_m, "ec": e_c, "ep": e_p, "m": m_val, "c": c_val, "p": p_val})
                    top_m += m_val; top_c += c_val
                    top_nm += n_m; top_nc += n_c
                    top_em += e_m; top_ec += e_c
                if len(all_c) > 20:
                    etc_c = round(total_cases - top_c, 1)
                    etc_m = int(all_c.iloc[20:]["활동명"].sum())
                    etc_nc = round(new_total - top_nc, 1)
                    etc_nm = max(0, int(new_sub["ACT_MEMBERS"].sum()) - top_nm)
                    etc_ec = round(old_total - top_ec, 1)
                    etc_em = max(0, int(old_sub["ACT_MEMBERS"].sum()) - top_em)
                    cl.append({"n": "그외", "nm": etc_nm, "nc": etc_nc, "np": round(etc_nc / new_total * 100, 1) if new_total > 0 else 0,
                               "em": etc_em, "ec": etc_ec, "ep": round(etc_ec / old_total * 100, 1) if old_total > 0 else 0,
                               "m": etc_m, "c": etc_c, "p": round(etc_c / total_cases * 100, 1) if total_cases > 0 else 0, "etc": True})
                return {"name": key_name, "total": round(total_cases, 1), "nt": round(new_total, 1), "et": round(old_total, 1), "biz": True, "camps": cl}

            # 2-1 keys: (NEW_OLD, HQ_DIV) → 신규회원 본부 / 신규회원 시도본부 및 지부 / 소계 / 기존회원 / 합계
            _v2_row_keys = ["신규_본부", "신규_시도본부", "신규_소계", "기존", "합계"]
            _v2_filters = {
                "신규_본부": lambda d: d[(d["NEW_OLD"] == "신규회원") & (d["HQ_DIV"] == "본부")],
                "신규_시도본부": lambda d: d[(d["NEW_OLD"] == "신규회원") & (d["HQ_DIV"] == "시도본부 및 지부")],
                "신규_소계": lambda d: d[d["NEW_OLD"] == "신규회원"],
                "기존": lambda d: d[d["NEW_OLD"] == "기존회원"],
                "합계": lambda d: d,
            }
            _v2_labels = {
                "신규_본부": "신규회원 > 본부",
                "신규_시도본부": "신규회원 > 시도본부 및 지부",
                "신규_소계": "신규회원 소계",
                "기존": "기존회원",
                "합계": "합계",
            }
            for vk in _v2_row_keys:
                sub = _v2_filters[vk](_act_camp_df)
                tc = float(sub["ACT_CASES"].sum())
                entry = _build_act_camp(sub, _v2_labels[vk], tc)
                if entry:
                    _act_popup[f"v2|{vk}"] = entry

            # 2-2 keys: BIZ_NAME (후원사업별) — use BIZ_NAME_MAP to aggregate
            from collections import defaultdict as _ddict
            _biz_camp_agg = _ddict(list)
            for _, r in _act_camp_df.iterrows():
                biz = str(r["BIZ_NAME"])
                disp = BIZ_NAME_MAP.get(biz, biz)
                _biz_camp_agg[disp].append(r)
            _BIZ_POPUP_GROUPS = {
                "국내 소계": ["국내아동권리보호사업"],
                "해외 소계": ["해외아동결연", "해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"],
                "프로젝트 소계": ["해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"],
                "기타 소계": ["대북지원사업", "전체사업지원", "좋은이웃후원"],
                "합계_biz": ["국내아동권리보호사업", "해외아동결연", "해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업", "대북지원사업", "전체사업지원", "좋은이웃후원"],
            }
            import pandas as _pd_act
            for disp_name, rows_list in _biz_camp_agg.items():
                sub = _pd_act.DataFrame(rows_list)
                tc = float(sub["ACT_CASES"].sum())
                entry = _build_act_camp_biz(sub, disp_name, tc)
                if entry:
                    _act_popup[f"biz|{disp_name}"] = entry
            for grp_name, biz_list in _BIZ_POPUP_GROUPS.items():
                rows_all = []
                for bn in biz_list:
                    rows_all.extend(_biz_camp_agg.get(bn, []))
                if rows_all:
                    sub = _pd_act.DataFrame(rows_all)
                    tc = float(sub["ACT_CASES"].sum())
                    entry = _build_act_camp_biz(sub, grp_name.replace("_biz", ""), tc)
                    if entry:
                        _act_popup[f"biz|{grp_name}"] = entry

        # ── 2-1 커스텀 HTML 렌더링 ──
        def _render_v2_html(df):
            th = "background:#4a4a4a;color:white;padding:5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:11px"
            html = '<table style="width:100%;border-collapse:collapse;font-size:11px">'
            html += '<thead><tr>'
            for col in df.columns:
                label = col
                if col == "활동회원(명)":
                    label = '활동회원(명)<br><span style="font-size:9px;font-weight:normal">(중복포함)</span>'
                html += f'<th style="{th}">{label}</th>'
            html += '</tr></thead><tbody>'
            row_popup_keys = _v2_row_keys if len(_v2_row_keys) == len(df) else [None] * len(df)
            for idx, (_, row) in enumerate(df.iterrows()):
                is_total = row["신규/기존"] == "합계"
                is_sub = row["본부/지부"] == "소계"
                if is_total:
                    rs = "background:#222;color:white;font-weight:bold;"
                elif is_sub:
                    rs = "background:#d9d9d9;font-weight:bold;"
                else:
                    rs = ""
                pk = row_popup_keys[idx] if idx < len(row_popup_keys) else None
                html += '<tr>'
                for col in df.columns:
                    val = row[col]
                    td = f"padding:4px 5px;border:1px solid #ddd;white-space:nowrap;{rs}"
                    if col in ("월말 활동회원 목표(건)", "활동율 목표(%)") and not is_total and not is_sub:
                        td += "background-color:#808000;color:white;"
                    if col == "활동회원(건)" and pk:
                        fk = f"v2|{pk}"
                        if fk in _act_popup and float(val) != 0:
                            html += f'<td data-act-popup="{fk}" style="{td}text-align:right;cursor:pointer" title="클릭 시 상세보기">{val:,.1f}</td>'
                        else:
                            html += f'<td style="{td}text-align:right">{val:,.1f}</td>'
                    elif col in ("활동회원(명)",):
                        html += f'<td style="{td}text-align:right">{val:,.0f}</td>'
                    elif col in ("월말 활동회원 목표(건)",):
                        html += f'<td style="{td}text-align:right">{val:,.0f}</td>'
                    elif col == "명당건수":
                        html += f'<td style="{td}text-align:right">{val:.2f}</td>'
                    elif "%" in col:
                        html += f'<td style="{td}text-align:right">{val:.1f}%</td>'
                    else:
                        html += f'<td style="{td}text-align:left">{val}</td>'
                html += '</tr>'
            html += '</tbody></table>'
            return html

        st.markdown(f'<div id="active-v2-table">{_render_v2_html(active_table_v2)}</div>', unsafe_allow_html=True)
        st.caption(f"출처: BRONZE_CRM — MSTR_ODS 원천 기반 F_MM_SPNSR_ACT 완전 재현 (기준월: {sel_year}-{sel_month:02d}, 법인: I)")




        # ===== 2-2. 활동회원현황 (후원사업별) =====
        st.divider()
        st.subheader("2-2. 활동회원 현황 (후원사업별)")
        st.caption("💡 활동회원(건) 숫자 클릭 시 마케팅캠페인 상세를 확인할 수 있습니다.")

        # 후원사업별 월말활동회원 목표 — DB에서 동적 로드

        biz_goal_df = _load_biz_active_target(sel_year)
        _biz_mcol = f"M{sel_month:02d}"
        _biz_rcol = f"R{sel_month:02d}"

        # 표 후원사업명 → DB SPNSR_BSNS_DIV_NM 매핑
        _BIZ_GOAL_MAP = {
            "국내아동권리보호사업": "국내(사단)",
            "해외아동결연": "해외아동결연",
            "해외교육지원사업": "해외교육지원사업",
            "희망학교지원사업": "희망학교지원사업",
            "식수위생지원사업": "식수위생지원사업",
            "보건의료지원사업": "보건의료지원사업",
            "해외지역개발사업": "해외지역개발사업",
            "재난구호지원사업": "재난구호지원사업",
            "대북지원사업": "대북지원사업",
            "전체사업지원": "전체사업지원",
            "좋은이웃후원": "좋은이웃후원",
        }
        # 국내 하위사업 DB명 리스트 (모두 국내(사단)에 합산)
        _DOMESTIC_DB_NAMES = ["국내아동권리보호사업(사단법인)", "결식아동지원", "아동학대예방", "저소득가정지원", "아동복지시설지원", "복지관후원"]

        def _get_biz_goal(display_name):
            db_name = _BIZ_GOAL_MAP.get(display_name)
            if db_name is None:
                return 0
            rows = biz_goal_df[biz_goal_df["SPNSR_BSNS_DIV_NM"] == db_name]
            return int(rows[_biz_mcol].sum()) if not rows.empty else 0

        def _get_biz_goal_sum_raw(display_names):
            total_raw = 0.0
            for n in display_names:
                db_name = _BIZ_GOAL_MAP.get(n)
                if db_name is None:
                    continue
                rows = biz_goal_df[biz_goal_df["SPNSR_BSNS_DIV_NM"] == db_name]
                if not rows.empty:
                    total_raw += float(rows[_biz_rcol].sum())
            return round(total_raw)


        with st.spinner("후원사업별 활동회원 집계 중..."):
            biz_df = load_active_by_biz(sel_year, sel_month)
            boy_biz_df = load_active_by_biz(sel_year - 1, 12)

        BIZ_STRUCTURE = [
            ("국내", "국내아동권리보호사업", "_DOMESTIC_SUM_"),
            ("국내 소계", None, None),
            ("해외", "해외아동결연", "해외아동결연"),
            ("해외", "해외교육지원사업", "해외교육지원사업"),
            ("해외", "희망학교지원사업", "희망학교지원사업"),
            ("해외", "식수위생지원사업", "식수위생지원사업"),
            ("해외", "보건의료지원사업", "보건의료지원사업"),
            ("해외", "해외지역개발사업", "해외지역개발사업"),
            ("해외", "재난구호지원사업", "재난구호지원사업"),
            ("프로젝트 소계", None, None),
            ("해외 소계", None, None),
            ("기타", "대북지원사업", "대북지원사업"),
            ("기타", "전체사업지원", "전체사업지원"),
            ("기타", "좋은이웃후원", "좋은이웃"),
            ("기타 소계", None, None),
            ("합계", None, None),
        ]

        PROJECT_BIZS = ["해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"]
        OVERSEAS_BIZS = ["해외아동결연"] + PROJECT_BIZS
        DOMESTIC_BIZS = ["국내아동권리보호사업"]
        ETC_BIZS = ["대북지원사업", "전체사업지원", "좋은이웃후원"]

        # 연도초 활동회원(건) = 전년도 12월 후원사업별 활동회원(건) — 동적 조회
        BOY_BIZ_CASES = {}
        if not boy_biz_df.empty:
            for _, r in boy_biz_df.iterrows():
                BOY_BIZ_CASES[r["BIZ_NAME"]] = float(r["ACTIVE_CASES"])

        # 후원사업별 전체(신규+기존) 누계개발건 — 탭3 "3) 전체회원" 표의 누계개발(건)과 동일
        _biz_ytd_dev_map = {}
        if not df_ytd_for_mem.empty:
            _dev_biz = df_ytd_for_mem[df_ytd_for_mem["후원사업"].notna()]
            if not _dev_biz.empty:
                for biz, g in _dev_biz.groupby("후원사업"):
                    _biz_ytd_dev_map[biz] = float(g["개발건"].sum())

        def build_biz_table(df):
            biz_data = {}
            if not df.empty:
                for _, r in df.iterrows():
                    biz_data[r["BIZ_NAME"]] = {"members": int(r["ACTIVE_MEMBERS"]), "cases": float(r["ACTIVE_CASES"])}

            def get_vals(display_name, db_name):
                d = biz_data.get(db_name, {"members": 0, "cases": 0.0})
                return d["members"], d["cases"]

            def sum_vals(names):
                m = sum(biz_data.get(n, {"members": 0})["members"] for n in names)
                c = sum(biz_data.get(n, {"cases": 0.0})["cases"] for n in names)
                return m, c

            domestic_db = ["국내아동권리보호사업(사단법인)", "결식아동지원", "아동학대예방", "저소득가정지원", "아동복지시설지원", "복지관후원"]
            overseas_db = ["해외아동결연", "해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"]
            project_db = overseas_db[1:]
            etc_sub_db = ["전체사업지원", "좋은이웃"]
            etc_db = ["대북지원사업"] + etc_sub_db

            total_cases = sum(biz_data.get(n, {"cases": 0.0})["cases"] for n in domestic_db + overseas_db + etc_db)
            boy_total = sum(BOY_BIZ_CASES.get(n, 0) for n in domestic_db + overseas_db + etc_db)

            def boy_sum(names):
                return sum(BOY_BIZ_CASES.get(n, 0) for n in names)

            def ytd_dev_sum(db_names):
                mapped = set()
                for n in db_names:
                    mapped.add(BIZ_NAME_MAP.get(n, n))
                return sum(_biz_ytd_dev_map.get(m, 0) for m in mapped)

            def calc_extra(c, boy_names):
                boy_c = boy_sum(boy_names) if isinstance(boy_names, list) else boy_names
                ytd_dev_c = ytd_dev_sum(boy_names) if isinstance(boy_names, list) else 0
                boy_pct = round(boy_c / boy_total * 100, 1) if boy_total > 0 else 0
                diff = c - boy_c
                diff_rate = round(diff / boy_c * 100, 1) if boy_c > 0 else 0
                denom = boy_c + ytd_dev_c
                act_rate = round(c / denom * 100, 1) if denom > 0 else 0
                return {
                    "후원사업별 활동율(%)": act_rate,
                    "연도초 활동회원(건)": boy_c,
                    "연도초 활동회원 구성비(%)": boy_pct,
                    "연도초 대비 증감(건)": diff,
                    "연도초 대비 증감율(%)": diff_rate,
                }

            NEW_COLS = ["달성율(%)", "후원사업별 활동율(%)", "연도초 활동회원(건)",
                        "연도초 활동회원 구성비(%)", "연도초 대비 증감(건)",
                        "연도초 대비 증감율(%)", "직전연도말 누계목표 포션(%)"]

            # 직전연도말 누계목표 포션(%) — 2026년 조회 시 고정값
            _PORTION_2026 = {
                "국내아동권리보호사업": 25.0,
                "국내 소계": 25.0,
                "해외아동결연": 42.2,
                "해외교육지원사업": 2.8,
                "희망학교지원사업": 1.0,
                "식수위생지원사업": 2.7,
                "보건의료지원사업": 14.6,
                "해외지역개발사업": 7.6,
                "재난구호지원사업": 0.8,
                "프로젝트 소계": 29.5,
                "해외 소계": 71.7,
                "대북지원사업": 0.2,
                "전체사업지원": 2.6,
                "좋은이웃후원": 0.4,
                "기타 소계": 3.1,
                "합계": 100.0,
            }

            def _get_portion(cat, biz):
                if sel_year != 2026:
                    return ""
                key = biz if biz else cat
                return _PORTION_2026.get(key, "")

            def make_row(cat, biz, target, m, c, pct, extra=None):
                row = {"구분": cat, "후원사업": biz, "월말 활동회원 목표(건)": target,
                       "활동회원(명)": m, "활동회원(건)": c, "구성비(%)": pct}
                for col in NEW_COLS:
                    row[col] = "" if extra is None else extra.get(col, "")
                row["달성율(%)"] = round(c / target * 100, 1) if target > 0 else 0.0
                row["직전연도말 누계목표 포션(%)"] = _get_portion(cat, biz)
                return row

            rows = []
            for cat, display, db_name in BIZ_STRUCTURE:
                if cat == "국내 소계":
                    m, c = sum_vals(domestic_db)
                    ex = calc_extra(c, domestic_db)
                    tgt = _get_biz_goal("국내아동권리보호사업")
                    rows.append(make_row("국내 소계", "", tgt, m, c,
                        round(c / total_cases * 100, 1) if total_cases > 0 else 0, ex))
                elif cat == "프로젝트 소계":
                    m, c = sum_vals(project_db)
                    ex = calc_extra(c, project_db)
                    tgt = _get_biz_goal_sum_raw(["해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"])
                    rows.append(make_row("프로젝트 소계", "", tgt, m, c,
                        round(c / total_cases * 100, 1) if total_cases > 0 else 0, ex))
                elif cat == "해외 소계":
                    m, c = sum_vals(overseas_db)
                    ex = calc_extra(c, overseas_db)
                    tgt = _get_biz_goal_sum_raw(["해외아동결연", "해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"])
                    rows.append(make_row("해외 소계", "", tgt, m, c,
                        round(c / total_cases * 100, 1) if total_cases > 0 else 0, ex))
                elif cat == "기타 소계":
                    m, c = sum_vals(etc_sub_db)
                    ex = calc_extra(c, etc_sub_db)
                    tgt = _get_biz_goal_sum_raw(["전체사업지원", "좋은이웃후원"])
                    rows.append(make_row("기타 소계", "", tgt, m, c,
                        round(c / total_cases * 100, 1) if total_cases > 0 else 0, ex))
                elif cat == "합계":
                    dom_m, dom_c = sum_vals(domestic_db)
                    ovs_m, ovs_c = sum_vals(overseas_db)
                    dae_m, dae_c = sum_vals(["대북지원사업"])
                    etc_s_m, etc_s_c = sum_vals(etc_sub_db)
                    m = dom_m + ovs_m + dae_m + etc_s_m
                    c = dom_c + ovs_c + dae_c + etc_s_c
                    all_db = domestic_db + overseas_db + ["대북지원사업"] + etc_sub_db
                    ex = calc_extra(c, all_db)
                    # 합계 = 국내소계 + 해외소계 + 대북지원사업 + 기타소계
                    tgt_domestic = _get_biz_goal("국내아동권리보호사업")
                    tgt_overseas = _get_biz_goal_sum_raw(["해외아동결연", "해외교육지원사업", "희망학교지원사업", "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"])
                    tgt_daebuk = _get_biz_goal("대북지원사업")
                    tgt_etc = _get_biz_goal_sum_raw(["전체사업지원", "좋은이웃후원"])
                    tgt = tgt_domestic + tgt_overseas + tgt_daebuk + tgt_etc
                    rows.append(make_row("합계", "", tgt, m, c, 100.0, ex))
                else:
                    if db_name == "_DOMESTIC_SUM_":
                        m, c = sum_vals(domestic_db)
                        ex = calc_extra(c, domestic_db)
                        tgt = _get_biz_goal("국내아동권리보호사업")
                    else:
                        m, c = get_vals(display, db_name)
                        ex = calc_extra(c, [db_name])
                        tgt = _get_biz_goal(display)
                    rows.append(make_row(cat, display, tgt, m, c,
                        round(c / total_cases * 100, 1) if total_cases > 0 else 0, ex))
            return pd.DataFrame(rows)

        biz_table = build_biz_table(biz_df)

        def style_biz_table(df):
            def row_style(row):
                styles = [""] * len(row)
                label = row["구분"]
                if label == "합계":
                    styles = ["background-color:#222222;color:white;font-weight:bold"] * len(row)
                elif "소계" in label:
                    styles = ["background-color:#d9d9d9;font-weight:bold"] * len(row)
                else:
                    if "월말 활동회원 목표(건)" in df.columns:
                        idx = df.columns.get_loc("월말 활동회원 목표(건)")
                        styles[idx] = "background-color:#808000;color:white"
                return styles
            return df.style.apply(row_style, axis=1)

        # ── 2-2 커스텀 HTML 렌더링 (활동회원(건) 팝업 포함) ──
        _BIZ_ROW_POPUP_KEYS = [
            "국내아동권리보호사업", "국내 소계",
            "해외아동결연", "해외교육지원사업", "희망학교지원사업", "식수위생지원사업",
            "보건의료지원사업", "해외지역개발사업", "재난구호지원사업",
            "프로젝트 소계", "해외 소계",
            "대북지원사업", "전체사업지원", "좋은이웃후원", "기타 소계", "합계_biz",
        ]

        def _render_biz_html(df):
            th = "background:#4a4a4a;color:white;padding:5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:11px"
            html = '<table style="width:100%;border-collapse:collapse;font-size:11px">'
            html += '<thead><tr>'
            for col in df.columns:
                label = col
                if col == "활동회원(명)":
                    label = '활동회원(명)<br><span style="font-size:9px;font-weight:normal">(중복포함)</span>'
                html += f'<th style="{th}">{label}</th>'
            html += '</tr></thead><tbody>'
            for idx, (_, row) in enumerate(df.iterrows()):
                cat = row["구분"]
                is_total = cat == "합계"
                is_sub = "소계" in str(cat)
                if is_total:
                    rs = "background:#222;color:white;font-weight:bold;"
                elif is_sub:
                    rs = "background:#d9d9d9;font-weight:bold;"
                else:
                    rs = ""
                pk = _BIZ_ROW_POPUP_KEYS[idx] if idx < len(_BIZ_ROW_POPUP_KEYS) else None
                html += '<tr>'
                for col in df.columns:
                    val = row[col]
                    td = f"padding:4px 5px;border:1px solid #ddd;white-space:nowrap;{rs}"
                    if col == "월말 활동회원 목표(건)" and not is_total and not is_sub:
                        td += "background-color:#808000;color:white;"
                    if col == "활동회원(건)" and pk:
                        fk = f"biz|{pk}"
                        if fk in _act_popup and isinstance(val, (int, float)) and float(val) != 0:
                            html += f'<td data-act-popup="{fk}" style="{td}text-align:right;cursor:pointer" title="클릭 시 상세보기">{val:,.1f}</td>'
                        else:
                            html += f'<td style="{td}text-align:right">{val:,.1f}</td>'
                    elif col == "활동회원(명)":
                        html += f'<td style="{td}text-align:right">{val:,.0f}</td>'
                    elif col == "월말 활동회원 목표(건)":
                        if isinstance(val, (int, float)) and val != "":
                            html += f'<td style="{td}text-align:right">{val:,.0f}</td>'
                        else:
                            html += f'<td style="{td}text-align:right"></td>'
                    elif col in ("구분", "후원사업"):
                        html += f'<td style="{td}text-align:left">{val}</td>'
                    elif "%" in col:
                        if isinstance(val, (int, float)) and val != "":
                            html += f'<td style="{td}text-align:right">{val:.1f}%</td>'
                        else:
                            html += f'<td style="{td}text-align:right"></td>'
                    elif isinstance(val, (int, float)) and val != "":
                        html += f'<td style="{td}text-align:right">{val:,.1f}</td>'
                    else:
                        html += f'<td style="{td}text-align:right">{val}</td>'
                html += '</tr>'
            html += '</tbody></table>'
            return html

        st.markdown(f'<div id="active-biz-table">{_render_biz_html(biz_table)}</div>', unsafe_allow_html=True)
        st.caption(f"출처: BRONZE_CRM — MSTR_ODS 원천 기반 (사단법인 후원사업별, 기준월: {sel_year}-{sel_month:02d})")

        # ── JS 팝업: 활동회원(건) 마케팅캠페인 상세 (2-1 + 2-2 공용) ──
        import json as _json_act
        _act_pjson = _json_act.dumps(_act_popup, ensure_ascii=False)
        stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._actPopupCleanup){{try{{doc._actPopupCleanup()}}catch(e){{}}}}
var D={_act_pjson};
var ov=doc.getElementById('act-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='act-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="act-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:1050px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st=doc.createElement('style');st.id='act-popup-style';
var oldSt=doc.getElementById('act-popup-style');if(oldSt)oldSt.remove();
st.textContent='@keyframes actpop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#act-popup-box{{animation:actpop .2s ease}}td[data-act-popup]{{cursor:pointer}}td[data-act-popup]:hover{{background:rgba(39,113,163,0.12) !important}}';
doc.head.appendChild(st);
doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
var box=doc.getElementById('act-popup-box');
var thS='background:#f0f2f5;padding:5px 6px;text-align:center;border:1px solid #e0e0e0;font-size:11px;white-space:nowrap';
var tdS='padding:4px 6px;text-align:right;border:1px solid #eee;font-size:11px';
function render(key){{
  var d=D[key];if(!d)return;
  var isBiz=d.biz===true;
  var h='<div style="background:linear-gradient(135deg,#0d6e3f,#27ae60);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.name+' — 활동회원(건) '+d.total.toLocaleString(undefined,{{minimumFractionDigits:1}})+'</span>';
  h+='<span id="act-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div>';
  h+='<div style="padding:18px 22px">';
  if(isBiz){{
    var nt=d.nt||0,et=d.et||0,tt=nt+et;
    var npct=tt>0?(nt/tt*100):0,epct=tt>0?(et/tt*100):0;
    h+='<div style="margin-bottom:16px">';
    h+='<div style="font-size:13px;font-weight:700;color:#0d6e3f;margin-bottom:8px;border-bottom:2px solid #27ae60;padding-bottom:5px">신규/기존 활동회원(건) 구성비</div>';
    h+='<div style="display:flex;align-items:center;gap:10px;margin-bottom:4px">';
    h+='<div style="width:100%;height:32px;border-radius:6px;overflow:hidden;display:flex;background:#eee">';
    if(npct>0) h+='<div style="width:'+npct.toFixed(1)+'%;background:#42A5F5;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:12px;min-width:40px">신규 '+npct.toFixed(1)+'%</div>';
    if(epct>0) h+='<div style="width:'+epct.toFixed(1)+'%;background:#EF5350;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:12px;min-width:40px">기존 '+epct.toFixed(1)+'%</div>';
    h+='</div></div>';
    h+='<div style="display:flex;justify-content:space-between;font-size:11px;color:#666;padding:0 2px">';
    h+='<span>신규: '+nt.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건</span>';
    h+='<span>기존: '+et.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건</span>';
    h+='<span>합계: '+tt.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'건</span>';
    h+='</div></div>';
  }}
  h+='<div style="font-size:13px;font-weight:700;color:#0d6e3f;margin-bottom:8px;border-bottom:2px solid #27ae60;padding-bottom:5px">마케팅캠페인별 활동 현황 (상위 20)</div>';
  h+='<table style="width:100%;border-collapse:collapse;font-size:11px;margin-bottom:12px">';
  if(isBiz){{
    h+='<thead><tr>';
    h+='<th rowspan="2" style="'+thS+';width:28px">순위</th>';
    h+='<th rowspan="2" style="'+thS+';text-align:left;width:80px">공통브랜드</th>';
    h+='<th rowspan="2" style="'+thS+';text-align:left">마케팅캠페인명</th>';
    h+='<th colspan="3" style="'+thS+';background:#e3f2fd;color:#1565C0">신규</th>';
    h+='<th colspan="3" style="'+thS+';background:#fff3e0;color:#E65100">기존</th>';
    h+='<th colspan="3" style="'+thS+';background:#e8e8e8;color:#333">합계</th>';
    h+='</tr><tr>';
    h+='<th style="'+thS+';background:#e3f2fd;width:55px">활동(명)</th><th style="'+thS+';background:#e3f2fd;width:65px">활동(건)</th><th style="'+thS+';background:#e3f2fd;width:50px">구성비</th>';
    h+='<th style="'+thS+';background:#fff3e0;width:55px">활동(명)</th><th style="'+thS+';background:#fff3e0;width:65px">활동(건)</th><th style="'+thS+';background:#fff3e0;width:50px">구성비</th>';
    h+='<th style="'+thS+';background:#e8e8e8;width:55px">활동(명)</th><th style="'+thS+';background:#e8e8e8;width:65px">활동(건)</th><th style="'+thS+';background:#e8e8e8;width:50px">구성비</th>';
    h+='</tr></thead><tbody>';
    var tnm=0,tnc=0,tem=0,tec=0,tm=0,tc=0;
    for(var i=0;i<d.camps.length;i++){{
      var c=d.camps[i];var isEtc=c.etc===true;
      tnm+=c.nm;tnc+=c.nc;tem+=c.em;tec+=c.ec;tm+=c.m;tc+=c.c;
      var bg=isEtc?'#f5f0e0':i%2===0?'#fff':'#fafafa';
      var rank=isEtc?'':String(i+1);
      h+='<tr style="background:'+bg+(isEtc?';font-style:italic':'')+'">';
      h+='<td style="'+tdS+';text-align:center">'+rank+'</td>';
      h+='<td style="'+tdS+';text-align:left;color:#666;white-space:nowrap">'+(c.b||'')+'</td>';
      h+='<td style="'+tdS+';text-align:left;max-width:250px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+c.n+'</td>';
      h+='<td style="'+tdS+'">'+c.nm.toLocaleString()+'</td>';
      h+='<td style="'+tdS+';font-weight:600">'+c.nc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="'+tdS+'">'+c.np.toFixed(1)+'%</td>';
      h+='<td style="'+tdS+'">'+c.em.toLocaleString()+'</td>';
      h+='<td style="'+tdS+';font-weight:600">'+c.ec.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="'+tdS+'">'+c.ep.toFixed(1)+'%</td>';
      h+='<td style="'+tdS+'">'+c.m.toLocaleString()+'</td>';
      h+='<td style="'+tdS+';font-weight:600">'+c.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="'+tdS+'">'+c.p.toFixed(1)+'%</td></tr>';
    }}
    var tnp=d.nt>0?(tnc/d.nt*100):0;var tep=d.et>0?(tec/d.et*100):0;var tp=d.total>0?(tc/d.total*100):0;
    h+='<tr style="background:#222;color:#fff;font-weight:700">';
    h+='<td style="padding:4px 6px;text-align:center;border:1px solid #555" colspan="3">합계</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tnm.toLocaleString()+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tnc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tnp.toFixed(1)+'%</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tem.toLocaleString()+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tec.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tep.toFixed(1)+'%</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tm.toLocaleString()+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tp.toFixed(1)+'%</td></tr>';
  }}else{{
    h+='<thead><tr>';
    h+='<th style="'+thS+';width:30px">순위</th>';
    h+='<th style="'+thS+';text-align:left;width:80px">공통브랜드</th>';
    h+='<th style="'+thS+';text-align:left">마케팅캠페인명</th>';
    h+='<th style="'+thS+';width:70px">활동(명)</th>';
    h+='<th style="'+thS+';width:80px">활동(건)</th>';
    h+='<th style="'+thS+';width:65px">구성비(%)</th>';
    h+='</tr></thead><tbody>';
    var tm=0,tc=0;
    for(var i=0;i<d.camps.length;i++){{
      var c=d.camps[i];var isEtc=c.etc===true;tm+=c.m;tc+=c.c;
      var bg=isEtc?'#f5f0e0':i%2===0?'#fff':'#fafafa';
      var rank=isEtc?'':String(i+1);
      h+='<tr style="background:'+bg+(isEtc?';font-style:italic':'')+'">';
      h+='<td style="'+tdS+';text-align:center">'+rank+'</td>';
      h+='<td style="'+tdS+';text-align:left;color:#666;white-space:nowrap">'+(c.b||'')+'</td>';
      h+='<td style="'+tdS+';text-align:left;max-width:350px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+c.n+'</td>';
      h+='<td style="'+tdS+'">'+c.m.toLocaleString()+'</td>';
      h+='<td style="'+tdS+';font-weight:600">'+c.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
      h+='<td style="'+tdS+'">'+c.p.toFixed(1)+'%</td></tr>';
    }}
    var tp=d.total>0?(tc/d.total*100):0;
    h+='<tr style="background:#222;color:#fff;font-weight:700"><td style="padding:4px 6px;text-align:center;border:1px solid #555" colspan="3">합계</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tm.toLocaleString()+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tp.toFixed(1)+'%</td></tr>';
  }}
  h+='</tbody></table></div>';
  box.style.maxWidth=isBiz?'1150px':'850px';
  box.innerHTML=h;box.scrollTop=0;
  doc.getElementById('act-close-btn').addEventListener('click',function(){{ov.style.display='none'}});
}}
function onClick(e){{
  var td=e.target.closest('td[data-act-popup]');
  if(td){{var key=td.getAttribute('data-act-popup');if(D[key]){{render(key);ov.style.display='flex';}}}}
}}
doc.addEventListener('click',onClick);
doc._actPopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('act-popup-overlay');if(o)o.remove();var s=doc.getElementById('act-popup-style');if(s)s.remove();}};
}})();
</script>""", height=0)

        st.markdown('<div style="height:30px"></div>', unsafe_allow_html=True)
        # ===== 2-3. 유입경로별 회원 활동현황 =====
        st.divider()
        st.subheader("2-3. 유입경로별 회원 활동현황")
        st.caption("💡 각 유입경로별 컬럼 클릭 시 상세내용을 확인할 수 있습니다.")
        st.markdown('<div style="height:0px"></div>', unsafe_allow_html=True)


        with st.spinner("유입경로별 활동회원 집계 중..."):
            brand_df = load_active_by_brand(sel_year, sel_month)

        if not brand_df.empty:
            # ── 플랫폼별 회원상태 요약 표 (상단) ──
            BRAND_PLATFORM_MAP = {
                # 온라인
                "PC캠페인": "온라인", "PC홈페이지": "온라인", "PC광고마케팅": "온라인",
                "PC공동캠페인": "온라인", "PC신규기획": "온라인",
                "M캠페인": "온라인", "M홈페이지": "온라인", "M광고마케팅": "온라인",
                "M공동캠페인": "온라인", "M신규기획": "온라인", "M모바일앱": "온라인",
                # 방송/광고
                "지상파방송": "방송/광고", "케이블방송": "방송/광고", "종편방송": "방송/광고",
                "특집방송": "방송/광고", "goodneighbors.kr": "방송/광고",
                "기타-미디어": "방송/광고", "영상광고": "방송/광고",
                # 미디어콜
                "콜 개발(미디어)": "미디어콜", "기획기사": "미디어콜", "방송진행": "미디어콜",
                "신문": "미디어콜", "지면 컨텐츠": "미디어콜", "희망tv 팝콘": "미디어콜",
                "후원광고": "미디어콜", "뉴미디어": "미디어콜", "라디오광고": "미디어콜",
                "라디오진행": "미디어콜", "공통캠페인": "미디어콜",
                # 회원상담센터
                "콜 개발": "회원상담센터", "기존회원온라인개발": "회원상담센터",
                "기존회원오프라인개발": "회원상담센터", "대리가입": "회원상담센터",
                "이중가입": "회원상담센터", "회원감액": "회원상담센터", "회원행사": "회원상담센터",
                "후원사업변경": "회원상담센터", "회원배가": "회원상담센터", "회원서비스": "회원상담센터",
                "회원신규": "회원상담센터", "회원재후원": "회원상담센터", "회원증액": "회원상담센터",
                "회원증액 외": "회원상담센터",
                # 세계시민교육
                "세계시민교육": "세계시민교육", "희망편지쓰기대회": "세계시민교육",
                "아동평화대행진": "세계시민교육", "가족그림편지쓰기대회": "세계시민교육",
                # 지역사회개발
                "지역개발": "지역사회개발", "직원개발": "지역사회개발",
                "네트워크연계-기타": "지역사회개발", "예비부모교육": "지역사회개발",
                "모아모아 프로젝트": "지역사회개발", "F5": "지역사회개발",
                "사례캠페인": "지역사회개발", "사업후원": "지역사회개발",
                "지구촌나눔": "지역사회개발", "천원의행복": "지역사회개발",
                "지부캠페인": "지역사회개발",
                # 기업
                "기업": "기업", "오프라인결연캠페인": "기업", "정기후원": "기업",
                "해외아동결연": "기업", "회원개발행사": "기업", "기타회원개발": "기업",
                "기업 공동캠페인": "기업", "브랜드캠페인": "기업", "기타": "기업",
                "나눔교육": "기업", "희망트리 오프라인캠페인": "기업", "방북직항": "기업",
            }
            PLATFORM_ORDER = ["온라인", "방송/광고", "미디어콜", "회원상담센터", "세계시민교육", "지역사회개발", "기업"]

            def classify_stat_group(stat_cd):
                s = str(stat_cd)
                if s == "1":
                    return "활동회원"
                elif s in ("2", "3", "4", "5", "6"):
                    return "신규미납"
                elif s in ("7", "8", "9", "10", "11"):
                    return "장기미납"
                return "기타"

            bdf = brand_df.copy()
            bdf["PLATFORM"] = bdf["BRND_NM"].map(BRAND_PLATFORM_MAP).fillna("기업")
            bdf["STAT_GROUP"] = bdf["MBER_STAT_CD"].apply(classify_stat_group)

            pf_stat = bdf.groupby(["PLATFORM", "STAT_GROUP"])["WJXBFS1"].sum().reset_index()

            stat_groups = ["활동회원", "신규미납", "장기미납"]
            pf_data = {}
            for pf in PLATFORM_ORDER:
                pf_sub = pf_stat[pf_stat["PLATFORM"] == pf]
                d = {}
                for sg in stat_groups:
                    row = pf_sub[pf_sub["STAT_GROUP"] == sg]
                    d[sg] = float(row["WJXBFS1"].sum()) if not row.empty else 0.0
                d["합계"] = sum(d.values())
                pf_data[pf] = d

            grand = {sg: sum(pf_data[pf][sg] for pf in PLATFORM_ORDER) for sg in stat_groups}
            grand["합계"] = sum(grand.values())

            th = "background:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;"
            th_sub = "background:#4a4a4a;color:white;padding:5px 4px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:11px;"
            pf_html = '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
            pf_html += '<thead><tr>'
            pf_html += f'<th rowspan="2" style="{th}">구분</th>'
            for pf in PLATFORM_ORDER:
                pf_html += f'<th colspan="2" style="{th}">{pf}</th>'
            pf_html += f'<th colspan="2" style="{th}">합계</th>'
            pf_html += '</tr><tr>'
            for _ in range(len(PLATFORM_ORDER) + 1):
                pf_html += f'<th style="{th_sub}">건</th>'
                pf_html += f'<th style="{th_sub}">구성비(%)</th>'
            pf_html += '</tr></thead><tbody>'

            row_metrics = ["활동회원", "신규미납", "장기미납", "합계"]
            for metric in row_metrics:
                is_total = metric == "합계"
                rs = "background-color:#222222;color:white;font-weight:bold;" if is_total else ""
                td = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{rs}"
                pf_html += '<tr>'
                pf_html += f'<td style="{td}text-align:left;">{metric}</td>'
                for pf in PLATFORM_ORDER:
                    v = pf_data[pf][metric]
                    total = pf_data[pf]["합계"]
                    pct = round(v / total * 100, 1) if total > 0 else 0.0
                    pf_html += f'<td style="{td}text-align:right;">{v:,.1f}</td>'
                    pf_html += f'<td style="{td}text-align:right;">{pct:.1f}%</td>'
                gv = grand[metric]
                gt = grand["합계"]
                gpct = round(gv / gt * 100, 1) if gt > 0 else 0.0
                pf_html += f'<td style="{td}text-align:right;font-weight:bold;">{gv:,.1f}</td>'
                pf_html += f'<td style="{td}text-align:right;font-weight:bold;">{gpct:.1f}%</td>'
                pf_html += '</tr>'

            rs_pct = "background-color:#d9d9d9;font-weight:bold;"
            td_pct = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{rs_pct}"
            pf_html += '<tr>'
            pf_html += f'<td style="{td_pct}text-align:left;">플랫폼별 구성비(%)</td>'
            for pf in PLATFORM_ORDER:
                pct = round(pf_data[pf]["합계"] / grand["합계"] * 100, 1) if grand["합계"] > 0 else 0.0
                pf_html += f'<td colspan="2" class="center-pct" style="{td_pct}">{pct:.1f}%</td>'
            pf_html += f'<td colspan="2" class="center-pct" style="{td_pct}">100.0%</td>'
            pf_html += '</tr>'

            pf_html += '</tbody></table>'
            # [숨김 처리] 플랫폼별 표 — 계정관리자 요청 시 다시 활성화
            # st.markdown(pf_html, unsafe_allow_html=True)
            # st.caption("※ 플랫폼별 브랜드 매핑 기준 집계")

            CMMN_BRND_ORDER = ["디지털", "방송/광고", "마케팅콜개발", "회원", "기업",
                               "교육기관", "지역개발", "대면모금"]
            CMMN_BRND_GROUP1 = CMMN_BRND_ORDER[:5]
            CMMN_BRND_GROUP2 = CMMN_BRND_ORDER[5:]
            _BRND_MERGE = {
                "방송": "방송/광고", "재송출": "방송/광고", "영상광고": "방송/광고", "뉴미디어": "방송/광고",
                "회원 온라인개발": "회원", "회원 오프라인개발": "회원", "회원 콜개발": "회원", "회원 기타": "회원",
            }


            with st.spinner("공통브랜드별 활동회원 집계 중..."):
                cb_df = load_active_by_common_brand(sel_year, sel_month)


            with st.spinner("공통브랜드 상세 데이터 집계 중..."):
                bd_detail = load_active_brand_detail(sel_year, sel_month)

            if not cb_df.empty:
                cb_df["CMMN_BRND_NM"] = cb_df["CMMN_BRND_NM"].replace({"직원개발": "지역개발", "콜개발": "마케팅콜개발"})
                cb_df["CMMN_BRND_NM"] = cb_df["CMMN_BRND_NM"].replace(_BRND_MERGE)
                cb_df["STAT_GROUP"] = cb_df["MBER_STAT_CD"].apply(classify_stat_group)
                cb_stat = cb_df.groupby(["CMMN_BRND_NM", "STAT_GROUP"])["WJXBFS1"].sum().reset_index()

                cb_stat_groups = ["활동회원", "신규미납", "장기미납"]
                cb_data = {}
                for brnd in CMMN_BRND_ORDER:
                    sub = cb_stat[cb_stat["CMMN_BRND_NM"] == brnd]
                    d = {}
                    for sg in cb_stat_groups:
                        row = sub[sub["STAT_GROUP"] == sg]
                        d[sg] = float(row["WJXBFS1"].sum()) if not row.empty else 0.0
                    d["합계"] = sum(d.values())
                    cb_data[brnd] = d

                cb_grand = {sg: sum(cb_data.get(b, {}).get(sg, 0) for b in CMMN_BRND_ORDER) for sg in cb_stat_groups}
                cb_grand["합계"] = sum(cb_grand.values())

                # ── 팝업 데이터 구축 ──
                _brnd_popup = {}
                if not bd_detail.empty:
                    bd_detail["ORIG_BRND"] = bd_detail["CMMN_BRND_NM"].replace({"직원개발": "지역개발", "콜개발": "마케팅콜개발"})
                    bd_detail["CMMN_BRND_NM"] = bd_detail["ORIG_BRND"].replace(_BRND_MERGE)
                    sgs = ["활동회원", "신규미납", "장기미납"]
                    for brnd in CMMN_BRND_ORDER:
                        bsub = bd_detail[bd_detail["CMMN_BRND_NM"] == brnd]
                        if bsub.empty:
                            continue
                        brnd_total = float(bsub["AMT"].sum())
                        cats = []
                        for cat_nm, cg in bsub.groupby("CMPGN_CTGR_NM"):
                            cat_total = float(cg["AMT"].sum())
                            camps = []
                            for mk_nm, mg in cg.groupby("MKTG_CMPGN_NM"):
                                c = {}
                                for sg in sgs:
                                    c[sg] = round(float(mg[mg["STAT_GROUP"] == sg]["AMT"].sum()), 1)
                                c["합계"] = round(sum(c.values()), 1)
                                # 세부캠페인명 리스트
                                details = []
                                for cmpgn_nm, dg in mg.groupby("CMPGN_NM"):
                                    dd = {}
                                    for sg in sgs:
                                        dd[sg] = round(float(dg[dg["STAT_GROUP"] == sg]["AMT"].sum()), 1)
                                    dd["합계"] = round(sum(dd.values()), 1)
                                    if dd["합계"] > 0:
                                        details.append({"n": str(cmpgn_nm), **dd})
                                details.sort(key=lambda x: x["합계"], reverse=True)
                                if c["합계"] > 0:
                                    ob = str(mg["ORIG_BRND"].mode().iloc[0]) if not mg["ORIG_BRND"].mode().empty else brnd
                                    camps.append({"n": str(mk_nm), "ob": ob, **c, "det": details})
                            camps.sort(key=lambda x: x["합계"], reverse=True)
                            sub_t = {}
                            for sg in sgs:
                                sub_t[sg] = round(float(cg[cg["STAT_GROUP"] == sg]["AMT"].sum()), 1)
                            sub_t["합계"] = round(sum(sub_t.values()), 1)
                            cats.append({"name": str(cat_nm), "subtotal": sub_t, "camps": camps})
                        cats.sort(key=lambda x: x["subtotal"]["합계"], reverse=True)
                        grand_t = {}
                        for sg in sgs:
                            grand_t[sg] = round(float(bsub[bsub["STAT_GROUP"] == sg]["AMT"].sum()), 1)
                        grand_t["합계"] = round(sum(grand_t.values()), 1)
                        _brnd_popup[brnd] = {"brand": brnd, "total": grand_t, "cats": cats}


                def render_cmmn_brnd_table(brands, show_grand=False):
                    th = "background-color:#4a4a4a !important;color:white !important;padding:6px 5px !important;text-align:center !important;border:1px solid #ddd !important;font-weight:600 !important;white-space:nowrap !important;"
                    th_sub = "background-color:#4a4a4a !important;color:white !important;padding:5px 4px !important;text-align:center !important;border:1px solid #ddd !important;font-weight:600 !important;white-space:nowrap !important;font-size:11px !important;"
                    html = '<table style="width:100% !important;border-collapse:collapse !important;font-size:12px !important;margin-bottom:0 !important;">'
                    html += '<thead><tr>'
                    html += f'<th rowspan="2" style="{th}">구분</th>'
                    for b in brands:
                        html += f'<th colspan="2" data-brnd-popup="{b}" style="{th}cursor:pointer;" title="클릭 시 상세보기">{b}</th>'
                    if show_grand:
                        html += f'<th colspan="2" style="{th}">합계</th>'
                    html += '</tr><tr>'
                    col_count = len(brands) + (1 if show_grand else 0)
                    for _ in range(col_count):
                        html += f'<th style="{th_sub}">건</th>'
                        html += f'<th style="{th_sub}">구성비(%)</th>'
                    html += '</tr></thead><tbody>'

                    row_metrics = ["활동회원", "신규미납", "장기미납", "합계"]
                    for metric in row_metrics:
                        is_total = metric == "합계"
                        if is_total:
                            tr_style = "background-color:#222222;color:white;font-weight:bold;"
                        elif metric == "활동회원":
                            tr_style = "background-color:#808000;color:white;"
                        else:
                            tr_style = ""
                        td_base = f"padding:5px 5px;border:1px solid #ddd;white-space:nowrap;"
                        html += f'<tr style="{tr_style}">'
                        html += f'<td style="{td_base}text-align:left;">{metric}</td>'
                        for b in brands:
                            v = cb_data.get(b, {}).get(metric, 0)
                            total_b = cb_data.get(b, {}).get("합계", 0)
                            pct = round(v / total_b * 100, 1) if total_b > 0 else 0.0
                            html += f'<td style="{td_base}text-align:right;">{v:,.1f}</td>'
                            html += f'<td style="{td_base}text-align:right;">{pct:.1f}%</td>'
                        if show_grand:
                            gv = cb_grand[metric]
                            gt = cb_grand["합계"]
                            gpct = round(gv / gt * 100, 1) if gt > 0 else 0.0
                            html += f'<td style="{td_base}text-align:right;font-weight:bold;">{gv:,.1f}</td>'
                            html += f'<td style="{td_base}text-align:right;font-weight:bold;">{gpct:.1f}%</td>'
                        html += '</tr>'

                    rs_pct = "background-color:#d9d9d9 !important;font-weight:bold !important;"
                    td_pct = f"padding:5px 5px !important;border:1px solid #ddd !important;white-space:nowrap !important;{rs_pct}"
                    html += '<tr>'
                    html += f'<td style="{td_pct}text-align:left !important;">유입경로별 구성비(%)</td>'
                    for b in brands:
                        pct = round(cb_data.get(b, {}).get("합계", 0) / cb_grand["합계"] * 100, 1) if cb_grand["합계"] > 0 else 0.0
                        html += f'<td colspan="2" class="center-pct" style="{td_pct}">{pct:.1f}%</td>'
                    if show_grand:
                        html += f'<td colspan="2" class="center-pct" style="{td_pct}">100.0%</td>'
                    html += '</tr>'

                    html += '</tbody></table>'
                    return html

                # ── 전체 공통브랜드 엑셀 다운로드 ──
                def _build_full_csv():
                    wb_rows = []
                    # 유입경로별 구성비 계산
                    _brnd_totals = {}
                    _all_total = 0
                    for brnd in CMMN_BRND_ORDER:
                        bt = cb_data.get(brnd, {}).get("합계", 0)
                        _brnd_totals[brnd] = bt
                        _all_total += bt
                    for brnd in CMMN_BRND_ORDER:
                        bp = _brnd_popup.get(brnd)
                        if not bp:
                            continue
                        brnd_pct = round(_brnd_totals[brnd] / _all_total * 100, 1) if _all_total > 0 else 0.0
                        for cat in bp["cats"]:
                            for camp in cat["camps"]:
                                if camp.get("det"):
                                    for det in camp["det"]:
                                        wb_rows.append({
                                            "공통브랜드": brnd, "유입경로별구성비(%)": brnd_pct,
                                            "캠페인카테고리": cat["name"],
                                            "마케팅캠페인명": camp["n"], "세부캠페인명": det["n"],
                                            "활동회원(건)": det["활동회원"], "신규미납(건)": det["신규미납"],
                                            "장기미납(건)": det["장기미납"], "합계(건)": det["합계"],
                                        })
                                else:
                                    wb_rows.append({
                                        "공통브랜드": brnd, "유입경로별구성비(%)": brnd_pct,
                                        "캠페인카테고리": cat["name"],
                                        "마케팅캠페인명": camp["n"], "세부캠페인명": "",
                                        "활동회원(건)": camp["활동회원"], "신규미납(건)": camp["신규미납"],
                                        "장기미납(건)": camp["장기미납"], "합계(건)": camp["합계"],
                                    })
                    df_xl = pd.DataFrame(wb_rows)
                    return "\ufeff" + df_xl.to_csv(index=False)

                _xl_col1, _xl_col2 = st.columns([8, 2])
                with _xl_col2:
                    st.download_button(
                        label="전체 엑셀 다운로드",
                        data=_build_full_csv(),
                        file_name=f"유입경로별_활동회원상세_{sel_year}{sel_month:02d}.csv",
                        mime="text/csv",
                    )

                st.markdown(render_cmmn_brnd_table(CMMN_BRND_GROUP1, show_grand=False), unsafe_allow_html=True)
                st.markdown('<div style="height:20px"></div>', unsafe_allow_html=True)
                st.markdown(render_cmmn_brnd_table(CMMN_BRND_GROUP2, show_grand=True), unsafe_allow_html=True)

                # ── JS 팝업: 공통브랜드 상세 ──
                import json as _json23
                _bp_json = _json23.dumps(_brnd_popup, ensure_ascii=False)
                stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._brndPopupCleanup){{try{{doc._brndPopupCleanup()}}catch(e){{}}}};
var D={_bp_json};
var ov=doc.getElementById('brnd-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='brnd-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:50px;';
ov.innerHTML='<div id="brnd-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:1050px;width:96%;max-height:85vh;overflow-y:auto;"></div>';
var st2=doc.createElement('style');st2.id='brnd-popup-style';
var os=doc.getElementById('brnd-popup-style');if(os)os.remove();
st2.textContent='@keyframes brndpop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#brnd-popup-box{{animation:brndpop .2s ease}}th[data-brnd-popup]{{cursor:pointer}}th[data-brnd-popup]:hover{{filter:brightness(1.3)}}';
doc.head.appendChild(st2);doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
var box=doc.getElementById('brnd-popup-box');
function fmt(v){{return v.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})}}
function pct(v,t){{return t>0?(v/t*100).toFixed(1)+'%':'0.0%'}}
function render(key){{
  var d=D[key];if(!d)return;
  var t=d.total;
  var h='<div style="background:linear-gradient(135deg,#2C3E50,#34495E);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.brand+' — 활동회원 상세현황 (합계 '+fmt(t['합계'])+'건)</span>';
  h+='<span id="brnd-close" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div>';
  h+='<div style="padding:4px 20px 0;display:flex;gap:8px;align-items:center">';
  h+='<input id="brnd-search" type="text" placeholder="캠페인명 검색..." style="flex:1;padding:5px 10px;font-size:12px;border:1px solid #ccc;border-radius:4px;outline:none">';
  h+='<button id="brnd-download-xl" style="padding:4px 12px;font-size:11px;border:1px solid #4CAF50;border-radius:4px;background:#4CAF50;color:#fff;cursor:pointer;white-space:nowrap">엑셀 다운로드</button>';
  h+='<button id="brnd-expand-all" style="padding:4px 12px;font-size:11px;border:1px solid #ccc;border-radius:4px;background:#f5f5f5;cursor:pointer;white-space:nowrap">전체 펼치기</button>';
  h+='<button id="brnd-collapse-all" style="padding:4px 12px;font-size:11px;border:1px solid #ccc;border-radius:4px;background:#f5f5f5;cursor:pointer;white-space:nowrap">전체 접기</button>';
  h+='</div>';
  h+='<div style="padding:12px 22px 18px">';
  var th='background:#f0f2f5;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px;white-space:nowrap;';
  var th2='background:#808000;color:white;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px;white-space:nowrap;';
  var th3='background:#4682B4;color:white;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px;white-space:nowrap;';
  var th4='background:#CD853F;color:white;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px;white-space:nowrap;';
  var th5='background:#4a4a4a;color:white;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px;white-space:nowrap;';
  h+='<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0">';
  h+='<thead><tr>';
  h+='<th rowspan="2" style="'+th+'min-width:80px">공통브랜드</th>';
  h+='<th rowspan="2" style="'+th+'min-width:120px">캠페인카테고리</th>';
  h+='<th rowspan="2" style="'+th+'min-width:140px">마케팅캠페인명</th>';
  h+='<th colspan="2" style="'+th2+'">활동회원</th>';
  h+='<th colspan="2" style="'+th3+'">신규미납</th>';
  h+='<th colspan="2" style="'+th4+'">장기미납</th>';
  h+='<th colspan="2" style="'+th5+'">합계</th>';
  h+='</tr><tr>';
  for(var i=0;i<4;i++){{
    var bg=i===0?th2:i===1?th3:i===2?th4:th5;
    h+='<th style="'+bg+'">건</th><th style="'+bg+'">구성비(%)</th>';
  }}
  h+='</tr></thead><tbody>';
  var sgs=['활동회원','신규미납','장기미납'];
  h+='<tr style="background:#222;color:#fff;font-weight:bold">';
  h+='<td colspan="3" style="padding:6px 8px;border:1px solid #555;text-align:center">합계</td>';
  for(var si=0;si<sgs.length;si++){{
    var gv=t[sgs[si]];
    h+='<td style="padding:6px 8px;border:1px solid #555;text-align:right">'+fmt(gv)+'</td>';
    h+='<td style="padding:6px 8px;border:1px solid #555;text-align:right">'+pct(gv,t['합계'])+'</td>';
  }}
  h+='<td style="padding:6px 8px;border:1px solid #555;text-align:right">'+fmt(t['합계'])+'</td>';
  h+='<td style="padding:6px 8px;border:1px solid #555;text-align:right">100.0%</td>';
  h+='</tr>';
  for(var ci=0;ci<d.cats.length;ci++){{
    var cat=d.cats[ci];
    var st3=cat.subtotal;
    var stbg=ci%2===0?'#e8f5e9':'#e3f2fd';
    h+='<tr data-cat-toggle="'+ci+'" style="background:'+stbg+';font-weight:bold;cursor:pointer" title="클릭하여 상세 펼치기/접기">';
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;font-weight:700">'+(ci===0?d.brand:'')+'</td>';
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;font-weight:700"><span class="cat-arrow-'+ci+'" style="display:inline-block;transition:transform .2s;margin-right:4px;font-size:10px">▶</span>'+cat.name+'</td>';
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;font-weight:700">소계</td>';
    for(var si=0;si<sgs.length;si++){{
      var sv2=st3[sgs[si]];
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+fmt(sv2)+'</td>';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+pct(sv2,st3['합계'])+'</td>';
    }}
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right;font-weight:bold">'+fmt(st3['합계'])+'</td>';
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+pct(st3['합계'],t['합계'])+'</td>';
    h+='</tr>';
    for(var ri=0;ri<cat.camps.length;ri++){{
      var c=cat.camps[ri];
      var bg2=ci%2===0?'#fff':'#fafafa';
      var mkid='mk-'+ci+'-'+ri;
      var hasDet=c.det&&c.det.length>0;
      var mkCur=hasDet?'cursor:pointer':'';
      var mkArrow=hasDet?'<span class="mk-arrow-'+mkid+'" style="display:inline-block;transition:transform .2s;margin-right:4px;font-size:9px;color:#999">▶</span>':'';
      h+='<tr class="cat-detail-'+ci+'" style="display:none;background:'+bg2+';'+mkCur+'"'+(hasDet?' data-mk-toggle="'+mkid+'" title="클릭하여 세부캠페인 펼치기/접기"':'')+'>';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;color:#666;font-size:11px">'+(c.ob||'')+'</td>';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;color:#999"></td>';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+mkArrow+c.n+'</td>';
      for(var si=0;si<sgs.length;si++){{
        var sv=c[sgs[si]];
        h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+fmt(sv)+'</td>';
        h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+pct(sv,c['합계'])+'</td>';
      }}
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right;font-weight:600">'+fmt(c['합계'])+'</td>';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+pct(c['합계'],t['합계'])+'</td>';
      h+='</tr>';
      if(hasDet){{
        for(var di=0;di<c.det.length;di++){{
          var dd=c.det[di];
          var dbg=di%2===0?'#f8f5ff':'#f0ebfa';
          h+='<tr class="mk-detail-'+mkid+'" style="display:none;background:'+dbg+'">';
          h+='<td style="padding:3px 8px;border:1px solid #e8e0f0;text-align:left"></td>';
          h+='<td style="padding:3px 8px;border:1px solid #e8e0f0;text-align:left"></td>';
          h+='<td style="padding:3px 8px;border:1px solid #e8e0f0;text-align:left;font-size:11px;padding-left:24px;max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+dd.n+'">'+dd.n+'</td>';
          for(var si=0;si<sgs.length;si++){{
            var dv=dd[sgs[si]];
            h+='<td style="padding:3px 8px;border:1px solid #e8e0f0;text-align:right;font-size:11px">'+fmt(dv)+'</td>';
            h+='<td style="padding:3px 8px;border:1px solid #e8e0f0;text-align:right;font-size:11px">'+pct(dv,dd['합계'])+'</td>';
          }}
          h+='<td style="padding:3px 8px;border:1px solid #e8e0f0;text-align:right;font-size:11px;font-weight:600">'+fmt(dd['합계'])+'</td>';
          h+='<td style="padding:3px 8px;border:1px solid #e8e0f0;text-align:right;font-size:11px">'+pct(dd['합계'],t['합계'])+'</td>';
          h+='</tr>';
        }}
      }}
    }}
  }}
  h+='</tbody></table></div>';
  box.innerHTML=h;box.scrollTop=0;box._currentKey=key;
  doc.getElementById('brnd-close').addEventListener('click',function(){{ov.style.display='none'}});
  box.querySelectorAll('tr[data-cat-toggle]').forEach(function(tr){{
    tr.addEventListener('click',function(){{
      var idx=tr.getAttribute('data-cat-toggle');
      var rows=box.querySelectorAll('.cat-detail-'+idx);
      var arrow=box.querySelector('.cat-arrow-'+idx);
      var open=rows.length>0&&rows[0].style.display!=='none';
      rows.forEach(function(r){{r.style.display=open?'none':'table-row'}});
      if(arrow)arrow.style.transform=open?'rotate(0deg)':'rotate(90deg)';
    }});
  }});
  doc.getElementById('brnd-expand-all').addEventListener('click',function(){{
    box.querySelectorAll('tr[class^="cat-detail-"]').forEach(function(r){{r.style.display='table-row'}});
    box.querySelectorAll('span[class^="cat-arrow-"]').forEach(function(a){{a.style.transform='rotate(90deg)'}});
  }});
  doc.getElementById('brnd-collapse-all').addEventListener('click',function(){{
    box.querySelectorAll('tr[class^="cat-detail-"]').forEach(function(r){{r.style.display='none'}});
    box.querySelectorAll('span[class^="cat-arrow-"]').forEach(function(a){{a.style.transform='rotate(0deg)'}});
    box.querySelectorAll('tr[class^="mk-detail-"]').forEach(function(r){{r.style.display='none'}});
    box.querySelectorAll('span[class^="mk-arrow-"]').forEach(function(a){{a.style.transform='rotate(0deg)'}});
  }});
  box.querySelectorAll('tr[data-mk-toggle]').forEach(function(tr){{
    tr.addEventListener('click',function(ev){{
      ev.stopPropagation();
      var mkid=tr.getAttribute('data-mk-toggle');
      var rows=box.querySelectorAll('.mk-detail-'+mkid);
      var arrow=box.querySelector('.mk-arrow-'+mkid);
      var open=rows.length>0&&rows[0].style.display!=='none';
      rows.forEach(function(r){{r.style.display=open?'none':'table-row'}});
      if(arrow)arrow.style.transform=open?'rotate(0deg)':'rotate(90deg)';
    }});
  }});
  var searchInput=doc.getElementById('brnd-search');
  searchInput.addEventListener('input',function(){{
    var q=searchInput.value.trim().toLowerCase();
    if(!q){{
      box.querySelectorAll('tr[data-cat-toggle]').forEach(function(r){{r.style.display='table-row'}});
      box.querySelectorAll('tr[class^="cat-detail-"]').forEach(function(r){{r.style.display='table-row'}});
      box.querySelectorAll('span[class^="cat-arrow-"]').forEach(function(a){{a.style.transform='rotate(90deg)'}});
      box.querySelectorAll('tr[class^="mk-detail-"]').forEach(function(r){{r.style.display='none'}});
      box.querySelectorAll('span[class^="mk-arrow-"]').forEach(function(a){{a.style.transform='rotate(0deg)'}});
      return;
    }}
    box.querySelectorAll('tr[data-cat-toggle]').forEach(function(tr){{
      var idx=tr.getAttribute('data-cat-toggle');
      var catName=tr.querySelector('td').textContent.toLowerCase();
      var mkRows=box.querySelectorAll('.cat-detail-'+idx);
      var catMatch=catName.indexOf(q)>=0;
      var anyMkMatch=false;
      mkRows.forEach(function(mr){{
        var mkName=mr.querySelectorAll('td')[2]?mr.querySelectorAll('td')[2].textContent.toLowerCase():'';
        var mkid=mr.getAttribute('data-mk-toggle');
        var mkMatch=mkName.indexOf(q)>=0;
        var detRows=mkid?box.querySelectorAll('.mk-detail-'+mkid):[];
        var anyDetMatch=false;
        detRows.forEach(function(dr){{
          var detName=dr.querySelectorAll('td')[2]?dr.querySelectorAll('td')[2].textContent.toLowerCase():'';
          if(detName.indexOf(q)>=0){{dr.style.display='table-row';anyDetMatch=true;}}
          else{{dr.style.display='none';}}
        }});
        if(catMatch||mkMatch||anyDetMatch){{mr.style.display='table-row';anyMkMatch=true;}}
        else{{mr.style.display='none';}}
        var mkArrow=mkid?box.querySelector('.mk-arrow-'+mkid):null;
        if(mkArrow)mkArrow.style.transform=anyDetMatch?'rotate(90deg)':'rotate(0deg)';
      }});
      tr.style.display=(catMatch||anyMkMatch)?'table-row':'none';
      var catArrow=box.querySelector('.cat-arrow-'+idx);
      if(catArrow)catArrow.style.transform=(catMatch||anyMkMatch)?'rotate(90deg)':'rotate(0deg)';
    }});
  }});
  searchInput.addEventListener('keydown',function(e){{e.stopPropagation()}});
  doc.getElementById('brnd-download-xl').addEventListener('click',function(){{
    var sgs=['활동회원','신규미납','장기미납'];
    var rows=[['공통브랜드','캠페인카테고리','마케팅캠페인명','세부캠페인명','활동회원(건)','활동회원(%)','신규미납(건)','신규미납(%)','장기미납(건)','장기미납(%)','합계(건)','합계(%)']];
    var d=D[box._currentKey];if(!d)return;
    var gt=d.total;
    for(var ci=0;ci<d.cats.length;ci++){{
      var cat=d.cats[ci];
      var st3=cat.subtotal;
      rows.push([d.brand,cat.name,'소계','',st3['활동회원'],pct(st3['활동회원'],st3['합계']),st3['신규미납'],pct(st3['신규미납'],st3['합계']),st3['장기미납'],pct(st3['장기미납'],st3['합계']),st3['합계'],pct(st3['합계'],gt['합계'])]);
      for(var ri=0;ri<cat.camps.length;ri++){{
        var c=cat.camps[ri];
        rows.push([c.ob||'',cat.name,c.n,'',c['활동회원'],pct(c['활동회원'],c['합계']),c['신규미납'],pct(c['신규미납'],c['합계']),c['장기미납'],pct(c['장기미납'],c['합계']),c['합계'],pct(c['합계'],gt['합계'])]);
        if(c.det){{
          for(var di=0;di<c.det.length;di++){{
            var dd=c.det[di];
            rows.push([c.ob||'',cat.name,c.n,dd.n,dd['활동회원'],pct(dd['활동회원'],dd['합계']),dd['신규미납'],pct(dd['신규미납'],dd['합계']),dd['장기미납'],pct(dd['장기미납'],dd['합계']),dd['합계'],pct(dd['합계'],gt['합계'])]);
          }}
        }}
      }}
    }}
    rows.push(['합계','','','',gt['활동회원'],pct(gt['활동회원'],gt['합계']),gt['신규미납'],pct(gt['신규미납'],gt['합계']),gt['장기미납'],pct(gt['장기미납'],gt['합계']),gt['합계'],'100.0%']);
    var csv='\\uFEFF';
    rows.forEach(function(r){{csv+=r.map(function(v){{var s=String(v==null?'':v);if(s.indexOf(',')>=0||s.indexOf('"')>=0)return '"'+s.replace(/"/g,'""')+'"';return s}}).join(',')+\"\\n\"}});
    var blob=new Blob([csv],{{type:'text/csv;charset=utf-8'}});
    var a=document.createElement('a');a.href=URL.createObjectURL(blob);
    a.download=d.brand+'_활동회원상세.csv';a.click();URL.revokeObjectURL(a.href);
  }});
}}
function onClick(e){{
  var th=e.target.closest('th[data-brnd-popup]');
  if(th){{var key=th.getAttribute('data-brnd-popup');if(D[key]){{render(key);ov.style.display='flex';}}}}
}}
doc.addEventListener('click',onClick);
doc._brndPopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('brnd-popup-overlay');if(o)o.remove();}};
}})();
</script>""", height=0)

                st.caption(f"출처: BRONZE_CRM — MSTR_ODS 원천 기반 F_MM_SPNSR_ACT 공통브랜드별 재현 (기준월: {sel_year}-{sel_month:02d}, 법인: I)")

                # ── 2-3 심층분석: 마케팅캠페인명 기준 활동/미납 분석 ──
                if not bd_detail.empty:
                    st.markdown('<div style="height:28px"></div>', unsafe_allow_html=True)

                    # Vega-Lite 툴팁 스타일 (parent document에 JS 주입)
                    stc.html("""<script>
(function(){
var doc = window.parent.document;
var oldS = doc.getElementById('vg-tooltip-custom-style-tab2');
if(oldS) oldS.remove();
var s = doc.createElement('style');
s.id = 'vg-tooltip-custom-style-tab2';
s.textContent = `
#vg-tooltip-element.vg-tooltip {
    font-family: 'Pretendard', 'Apple SD Gothic Neo', sans-serif !important;
    background: linear-gradient(135deg, #1e293b 0%, #334155 100%) !important;
    color: #f1f5f9 !important;
    border: none !important;
    border-radius: 12px !important;
    padding: 16px 20px !important;
    box-shadow: 0 10px 40px rgba(0,0,0,0.3), 0 2px 10px rgba(0,0,0,0.15) !important;
    font-size: 12px !important;
    line-height: 1.8 !important;
    max-width: 560px !important;
    min-width: 220px !important;
    backdrop-filter: blur(10px) !important;
    white-space: normal !important;
    word-break: keep-all !important;
    z-index: 999999 !important;
}
#vg-tooltip-element.vg-tooltip table {
    border-collapse: separate !important;
    border-spacing: 0 4px !important;
    width: 100% !important;
}
#vg-tooltip-element.vg-tooltip td.key {
    color: #94a3b8 !important;
    font-weight: 500 !important;
    font-size: 11px !important;
    padding-right: 14px !important;
    vertical-align: top !important;
    white-space: nowrap !important;
}
#vg-tooltip-element.vg-tooltip td.value {
    color: #ffffff !important;
    font-weight: 700 !important;
    font-size: 12px !important;
    white-space: normal !important;
    word-break: keep-all !important;
    max-width: 420px !important;
    line-height: 1.6 !important;
}
#vg-tooltip-element.vg-tooltip tr:first-child td {
    padding-top: 2px !important;
}
#vg-tooltip-element.vg-tooltip tr:last-child td {
    padding-bottom: 2px !important;
    border-top: 1px solid rgba(148,163,184,0.25) !important;
    padding-top: 8px !important;
}
`;
doc.head.appendChild(s);
})();
</script>""", height=0)

                    _bd = bd_detail.copy()
                    _bd["CMMN_BRND_NM"] = _bd["CMMN_BRND_NM"].replace({"직원개발": "지역개발", "콜개발": "마케팅콜개발"})
                    _bd["CMMN_BRND_NM"] = _bd["CMMN_BRND_NM"].replace(_BRND_MERGE)
                    _sgs = ["활동회원", "신규미납", "장기미납"]

                    # 마케팅캠페인명별 대표 유입경로 매핑 (활동건 최대 브랜드)
                    _brnd_map_df = _bd.groupby(["MKTG_CMPGN_NM", "CMMN_BRND_NM"])["AMT"].sum().reset_index()
                    _brnd_map_df = _brnd_map_df.sort_values("AMT", ascending=False).drop_duplicates(subset="MKTG_CMPGN_NM", keep="first")
                    _bd_brnd_dict = dict(zip(_brnd_map_df["MKTG_CMPGN_NM"], _brnd_map_df["CMMN_BRND_NM"]))

                    # 직접 피벗
                    _bd_pivot = _bd.groupby(["MKTG_CMPGN_NM", "STAT_GROUP"])["AMT"].sum().reset_index()
                    _bd_wide = _bd_pivot.pivot_table(index="MKTG_CMPGN_NM", columns="STAT_GROUP", values="AMT", aggfunc="sum", fill_value=0).reset_index()
                    _bd_wide["유입경로"] = _bd_wide["MKTG_CMPGN_NM"].map(_bd_brnd_dict).fillna("")
                    for _sg in _sgs:
                        if _sg not in _bd_wide.columns:
                            _bd_wide[_sg] = 0.0
                        else:
                            _bd_wide[_sg] = pd.to_numeric(_bd_wide[_sg], errors="coerce").fillna(0)
                    _bd_wide["합계"] = _bd_wide["활동회원"] + _bd_wide["신규미납"] + _bd_wide["장기미납"]
                    _bd_wide = _bd_wide[_bd_wide["합계"] > 0].sort_values("합계", ascending=False).reset_index(drop=True)
                    _bd_total = float(_bd_wide["합계"].sum())
                    _bd_wide["구성비"] = (_bd_wide["합계"] / _bd_total * 100).round(1) if _bd_total > 0 else 0
                    _bd_wide["장기미납비율"] = (_bd_wide["장기미납"] / _bd_wide["합계"] * 100).round(1)
                    _bd_wide["신규미납비율"] = (_bd_wide["신규미납"] / _bd_wide["합계"] * 100).round(1)

                    _bd_top10 = _bd_wide.head(10)
                    _grand_long_pct = round(float(_bd_wide["장기미납"].sum()) / _bd_total * 100, 1) if _bd_total > 0 else 0
                    _grand_new_pct = round(float(_bd_wide["신규미납"].sum()) / _bd_total * 100, 1) if _bd_total > 0 else 0

                    # 장기미납 비중 높은 캠페인 (합계 50건 이상만)
                    _bd_risky = _bd_wide[_bd_wide["합계"] >= 50].sort_values("장기미납비율", ascending=False).head(5)

                    # ── 캠페인카테고리별 신규미납+장기미납 전년 비교 차트 ──
                    _target_cats = ["초등캠페인", "유아캠페인", "가두캠페인", "청소년캠페인", "교회캠페인",
                                    "굿즈캠페인", "고려인캠페인", "참전용사캠페인", "국내사례캠페인"]
                    # 당해연도 데이터
                    _cat_cur = _bd[_bd["CMPGN_CTGR_NM"].isin(_target_cats) & _bd["STAT_GROUP"].isin(["신규미납", "장기미납"])]
                    _cat_cur_agg = _cat_cur.groupby(["CMPGN_CTGR_NM", "STAT_GROUP"])["AMT"].sum().reset_index()
                    _cat_cur_agg["연도"] = str(sel_year)

                    # 전년도 데이터
                    _prev_bd = load_active_brand_detail(sel_year - 1, sel_month)
                    if not _prev_bd.empty:
                        _prev_bd_filtered = _prev_bd[_prev_bd["CMPGN_CTGR_NM"].isin(_target_cats) & _prev_bd["STAT_GROUP"].isin(["신규미납", "장기미납"])]
                        _cat_prev_agg = _prev_bd_filtered.groupby(["CMPGN_CTGR_NM", "STAT_GROUP"])["AMT"].sum().reset_index()
                        _cat_prev_agg["연도"] = str(sel_year - 1)
                    else:
                        _cat_prev_agg = pd.DataFrame(columns=["CMPGN_CTGR_NM", "STAT_GROUP", "AMT", "연도"])

                    _cat_all = pd.concat([_cat_prev_agg, _cat_cur_agg], ignore_index=True)
                    _cat_all["건수"] = _cat_all["AMT"].apply(lambda x: round(float(x), 1))
                    _cat_all.rename(columns={"CMPGN_CTGR_NM": "캠페인카테고리", "STAT_GROUP": "상태"}, inplace=True)

                    if not _cat_all.empty:
                        # 당해연도 합계 기준 정렬
                        _cat_order_df = _cat_all[_cat_all["연도"] == str(sel_year)].groupby("캠페인카테고리")["건수"].sum().sort_values(ascending=False)
                        _cat_order = [c for c in _cat_order_df.index if c in _target_cats]
                        for _tc in _target_cats:
                            if _tc not in _cat_order:
                                _cat_order.append(_tc)

                        # 증감%p 계산 (합계 기준)
                        _cur_total = _cat_all[_cat_all["연도"] == str(sel_year)].groupby("캠페인카테고리")["건수"].sum()
                        _prev_total = _cat_all[_cat_all["연도"] == str(sel_year - 1)].groupby("캠페인카테고리")["건수"].sum()
                        _pct_rows = []
                        for _cc in _cat_order:
                            _cv = float(_cur_total.get(_cc, 0))
                            _pv = float(_prev_total.get(_cc, 0))
                            _diff = round(_cv - _pv, 1)
                            _rate = (_cv - _pv) / _pv * 100 if _pv > 0 else None
                            _lbl = (f"{'+' if _rate >= 0 else ''}{_rate:.1f}%" if _rate is not None else "NEW")
                            _pct_rows.append({"캠페인카테고리": _cc, "건수": _cv, "라벨": _lbl, "연도": str(sel_year),
                                              "전년건": round(_pv, 1), "당해건": round(_cv, 1),
                                              "증감건": f"{'+' if _diff >= 0 else ''}{_diff:,.1f}건", "증감율": _lbl})
                        _pct_df = pd.DataFrame(_pct_rows)
                        _diff_map = dict(zip(_pct_df["캠페인카테고리"], _pct_df["증감건"]))
                        _rate_map = dict(zip(_pct_df["캠페인카테고리"], _pct_df["증감율"]))
                        _cat_all["전년대비 증감건"] = _cat_all["캠페인카테고리"].map(_diff_map).fillna("")
                        _cat_all["전년대비 증감율"] = _cat_all["캠페인카테고리"].map(_rate_map).fillna("")

                        # 연도+상태 조합 색상키 (전년=그레이 계열, 당해=주황+빨강)
                        _cat_all["색상키"] = _cat_all["연도"] + " " + _cat_all["상태"]
                        _color_domain = [
                            f"{sel_year - 1} 신규미납", f"{sel_year - 1} 장기미납",
                            f"{sel_year} 신규미납", f"{sel_year} 장기미납",
                        ]
                        _color_range = ["#D5D5D5", "#B0B0B0", "#FFB74D", "#E57373"]

                        _cat_bar = alt.Chart(_cat_all).mark_bar(cornerRadiusTopLeft=3, cornerRadiusTopRight=3, size=30).encode(
                            x=alt.X("캠페인카테고리:N", sort=_cat_order, axis=alt.Axis(labelFontSize=13, labelFontWeight="bold", labelAngle=-30, title=None)),
                            xOffset=alt.XOffset("연도:N", sort=[str(sel_year - 1), str(sel_year)]),
                            y=alt.Y("건수:Q", stack=True, axis=alt.Axis(labelFontSize=10, format=",.0f", title="미납건(건)")),
                            color=alt.Color("색상키:N",
                                scale=alt.Scale(domain=_color_domain, range=_color_range),
                                legend=alt.Legend(orient="right", titleFontSize=11, title="연도 / 상태", labelFontSize=10, symbolSize=120)),
                            tooltip=[alt.Tooltip("캠페인카테고리:N"), alt.Tooltip("연도:N"), alt.Tooltip("상태:N"),
                                     alt.Tooltip("건수:Q", format=",.1f"),
                                     alt.Tooltip("전년대비 증감건:N", title="전년대비 증감(신규+장기)"),
                                     alt.Tooltip("전년대비 증감율:N", title="전년대비 증감율")],
                            order=alt.Order("상태:N", sort="ascending"),
                        )

                        _pct_text = alt.Chart(_pct_df).mark_text(dy=-12, fontSize=13, fontWeight="bold").encode(
                            x=alt.X("캠페인카테고리:N", sort=_cat_order),
                            xOffset=alt.XOffset("연도:N", sort=[str(sel_year - 1), str(sel_year)]),
                            y=alt.Y("건수:Q"),
                            text="라벨:N",
                            color=alt.value("#D32F2F"),
                            tooltip=[alt.Tooltip("캠페인카테고리:N"),
                                     alt.Tooltip("전년건:Q", format=",.1f", title=f"{sel_year-1}년 미납(건)"),
                                     alt.Tooltip("당해건:Q", format=",.1f", title=f"{sel_year}년 미납(건)"),
                                     alt.Tooltip("증감건:N", title="증감(건)"), alt.Tooltip("증감율:N", title="증감율")],
                        )

                        _cat_chart = (_cat_bar + _pct_text).properties(
                            width="container", height=380,
                            title=alt.Title(
                                f"▼ 주요 캠페인카테고리별 미납현황 비교 — {sel_year-1}년 vs {sel_year}년 {sel_month}월 (신규미납+장기미납)",
                                fontSize=18, fontWeight=700, anchor="start")
                        )

                        st.altair_chart(_cat_chart, use_container_width=True)

                        # ── 그래프 하단 데이터 테이블 ──
                        _tbl_pivot = _cat_all.groupby(["캠페인카테고리", "연도", "상태"])["건수"].sum().reset_index()
                        # 활동회원 데이터 (미납비중 계산용)
                        _cat_act_cur = _bd[_bd["CMPGN_CTGR_NM"].isin(_target_cats) & (_bd["STAT_GROUP"] == "활동회원")]
                        _cat_act_cur_agg = _cat_act_cur.groupby("CMPGN_CTGR_NM")["AMT"].sum()
                        _cat_act_prev_agg = {}
                        if not _prev_bd.empty:
                            _pba = _prev_bd[_prev_bd["CMPGN_CTGR_NM"].isin(_target_cats) & (_prev_bd["STAT_GROUP"] == "활동회원")]
                            _cat_act_prev_agg = _pba.groupby("CMPGN_CTGR_NM")["AMT"].sum()

                        _tbl_wide_rows = []
                        for _cc in _cat_order:
                            _row = {"캠페인카테고리": _cc}
                            for _yr in [str(sel_year - 1), str(sel_year)]:
                                _new = float(_tbl_pivot[(_tbl_pivot["캠페인카테고리"] == _cc) & (_tbl_pivot["연도"] == _yr) & (_tbl_pivot["상태"] == "신규미납")]["건수"].sum())
                                _old = float(_tbl_pivot[(_tbl_pivot["캠페인카테고리"] == _cc) & (_tbl_pivot["연도"] == _yr) & (_tbl_pivot["상태"] == "장기미납")]["건수"].sum())
                                _row[f"{_yr}_신규미납"] = round(_new, 1)
                                _row[f"{_yr}_장기미납"] = round(_old, 1)
                                _row[f"{_yr}_합계"] = round(_new + _old, 1)
                                # 활동회원건
                                if _yr == str(sel_year):
                                    _act_v = float(_cat_act_cur_agg.get(_cc, 0))
                                else:
                                    _act_v = float(_cat_act_prev_agg.get(_cc, 0)) if hasattr(_cat_act_prev_agg, 'get') else 0
                                _total_all = _act_v + _new + _old
                                _row[f"{_yr}_미납비중"] = round((_new + _old) / _total_all * 100, 1) if _total_all > 0 else 0
                            _cv = _row[f"{sel_year}_합계"]
                            _pv = _row[f"{sel_year-1}_합계"]
                            _row["증감"] = round(_cv - _pv, 1)
                            _row["증감%p"] = round((_cv - _pv) / _pv * 100, 1) if _pv > 0 else 0
                            _tbl_wide_rows.append(_row)
                        # 합계행
                        _total_row = {"캠페인카테고리": "합계"}
                        # 합계 = 당월 전체 캠페인카테고리 기준 (표에 표시된 카테고리 합이 아님)
                        for _yr in [str(sel_year - 1), str(sel_year)]:
                            _src = _bd if _yr == str(sel_year) else _prev_bd
                            if _src is None or _src.empty:
                                _g_new = _g_old = _g_act = 0.0
                            else:
                                _g_new = float(_src[_src["STAT_GROUP"] == "신규미납"]["AMT"].sum())
                                _g_old = float(_src[_src["STAT_GROUP"] == "장기미납"]["AMT"].sum())
                                _g_act = float(_src[_src["STAT_GROUP"] == "활동회원"]["AMT"].sum())
                            _total_row[f"{_yr}_신규미납"] = round(_g_new, 1)
                            _total_row[f"{_yr}_장기미납"] = round(_g_old, 1)
                            _total_row[f"{_yr}_합계"] = round(_g_new + _g_old, 1)
                            _all_total = _g_act + _g_new + _g_old
                            _total_row[f"{_yr}_미납비중"] = round((_g_new + _g_old) / _all_total * 100, 1) if _all_total > 0 else 0
                        _total_row["증감"] = round(_total_row[f"{sel_year}_합계"] - _total_row[f"{sel_year-1}_합계"], 1)
                        _tv = _total_row[f"{sel_year}_합계"]
                        _tp = _total_row[f"{sel_year-1}_합계"]
                        _total_row["증감%p"] = round((_tv - _tp) / _tp * 100, 1) if _tp > 0 else 0
                        _tbl_wide_rows.append(_total_row)
                        # 당해(각 연도) 합계 미납비중 대비 차이(%p)
                        for _r in _tbl_wide_rows:
                            for _yr in [str(sel_year - 1), str(sel_year)]:
                                _r[f"{_yr}_비중차"] = round(_r[f"{_yr}_미납비중"] - _total_row[f"{_yr}_미납비중"], 1)
                            # 전년 대비 미납비중 변화(%p) / 우선관리: 합계비중보다 높고 전년보다 악화
                            # 전년 신규+장기미납이 없으면(미진행 등) 비교 불가 → None
                            _r["비중변화"] = (round(_r[f"{sel_year}_미납비중"] - _r[f"{sel_year-1}_미납비중"], 1)
                                            if _r[f"{sel_year-1}_합계"] > 0 else None)
                            _r["우선관리"] = ((_r["캠페인카테고리"] != "합계") and _r["비중변화"] is not None
                                            and _r[f"{sel_year}_비중차"] > 0 and _r["비중변화"] > 0)

                        _th = "background:#4a4a4a;color:white;padding:6px 8px;text-align:center;border:1px solid #ddd;font-weight:600;font-size:13px;white-space:nowrap"
                        _tbl_html = '<table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:8px"><thead>'
                        _tbl_html += f'<tr><th rowspan="2" style="{_th}">캠페인카테고리</th>'
                        _tbl_html += f'<th colspan="5" style="{_th};background:#666">{sel_year-1}년</th>'
                        _tbl_html += f'<th colspan="5" style="{_th};background:#C62828">{sel_year}년</th>'
                        _tbl_html += f'<th rowspan="2" style="{_th};background:#1565C0">증감</th>'
                        _tbl_html += f'<th rowspan="2" style="{_th};background:#1565C0">증감(%p)</th>'
                        _tbl_html += f'<th rowspan="2" style="{_th};background:#6A1B9A">전년 대비<br>미납비중 변화</th></tr>'
                        _tbl_html += f'<tr><th style="{_th};background:#666">신규미납</th><th style="{_th};background:#666">장기미납</th><th style="{_th};background:#666">합계</th><th style="{_th};background:#666">미납비중</th><th style="{_th};background:#666">합계비중 대비</th>'
                        _tbl_html += f'<th style="{_th};background:#C62828">신규미납</th><th style="{_th};background:#C62828">장기미납</th><th style="{_th};background:#C62828">합계</th><th style="{_th};background:#C62828">미납비중</th><th style="{_th};background:#C62828">합계비중 대비</th></tr></thead><tbody>'
                        for _r in _tbl_wide_rows:
                            _is_total = _r["캠페인카테고리"] == "합계"
                            _rs = "background:#222;color:#fff;font-weight:700;" if _is_total else ""
                            _td = f"padding:5px 8px;border:1px solid #eee;text-align:center;font-size:13px;{_rs}"
                            _diff_v = _r["증감"]
                            _diff_color = "#D32F2F" if _diff_v > 0 else "#1565C0" if _diff_v < 0 else "#333"
                            _diff_sign = "+" if _diff_v > 0 else ""
                            _pct_v = _r["증감%p"]
                            _pct_sign = "+" if _pct_v > 0 else ""
                            _cat_name = _r["캠페인카테고리"]
                            _hot = _r.get("우선관리", False)
                            _hot_css = "background:#B71C1C;color:#fff;font-weight:800;"
                            _tbl_html += '<tr>'
                            _tbl_html += (f'<td style="{_td}font-weight:600;text-align:left;{_hot_css if _hot else ""}">'
                                          f'{"⚠ " if _hot else ""}{"전체 캠페인카테고리 합계" if _is_total else _cat_name}</td>')
                            for _yr in [str(sel_year - 1), str(sel_year)]:
                                for _st in ["신규미납", "장기미납"]:
                                    _v = _r[f"{_yr}_{_st}"]
                                    if not _is_total and _v > 0:
                                        _pk = f"{_yr}|{_cat_name}|{_st}"
                                        _tbl_html += f'<td data-unpaid-popup="{_pk}" style="{_td}cursor:pointer" title="클릭 시 상세보기">{_v:,.1f}</td>'
                                    else:
                                        _tbl_html += f'<td style="{_td}">{_v:,.1f}</td>'
                                _tbl_html += f'<td style="{_td}font-weight:700">{_r[f"{_yr}_합계"]:,.1f}</td>'
                                _tbl_html += f'<td style="{_td}color:#E65100;font-weight:600">{_r[f"{_yr}_미납비중"]:.1f}%</td>'
                                _gd = _r[f"{_yr}_비중차"]
                                if _is_total:
                                    _tbl_html += f'<td style="{_td}">-</td>'
                                else:
                                    _hl = "background:#FFCDD2;color:#B71C1C;font-weight:700;" if _gd > 0 else "color:#1565C0;"
                                    if _hot and _yr == str(sel_year):
                                        _hl = _hot_css
                                    _tbl_html += f'<td style="{_td}{_hl}">{"+" if _gd > 0 else ""}{_gd:.1f}%p</td>'
                            _tbl_html += f'<td style="{_td}font-weight:700;color:{_diff_color}">{_diff_sign}{_diff_v:,.1f}</td>'
                            _tbl_html += f'<td style="{_td}font-weight:700;color:{_diff_color}">{_pct_sign}{_pct_v:.1f}%</td>'
                            _sv = _r["비중변화"]
                            if _sv is None:
                                _tbl_html += f'<td style="{_td}color:#999">-</td>'
                                _tbl_html += '</tr>'
                                continue
                            if _hot:
                                _sv_css = _hot_css
                            elif _sv > 0 and not _is_total:
                                _sv_css = "background:#FFCDD2;color:#B71C1C;font-weight:700;"
                            elif _is_total:
                                _sv_css = "font-weight:700;"
                            else:
                                _sv_css = "color:#1565C0;font-weight:600;"
                            _tbl_html += f'<td style="{_td}{_sv_css}">{"+" if _sv > 0 else ""}{_sv:.1f}%p</td>'
                            _tbl_html += '</tr>'
                        _tbl_html += '</tbody></table>'
                        st.caption("💡 표의 신규미납/장기미납 숫자를 클릭하면 상세 분석을 볼 수 있습니다.")
                        st.markdown(_tbl_html, unsafe_allow_html=True)
                        st.caption("※ 합계 = 당월 전체 캠페인카테고리 기준 / 합계비중 대비 = 해당 연도 합계 미납비중 대비 차이(%p), 빨간색은 합계 미납비중보다 높은 항목 / 전년 대비 미납비중 변화 = 당해 미납비중 − 전년 미납비중(%p) / ⚠ 진한 빨강 = 합계비중보다 높고 전년보다 악화된 우선 관리 대상")

                        # ── 미납 상세 팝업 데이터 구축 ──
                        # 결제수단 매핑 로드 (회원활동 탭용)
                        if "_setle_map" not in dir() or not _setle_map:
                            _setle_df2 = _load_setle_for_activity()
                            _setle_map = {}
                            if not _setle_df2.empty:
                                for _, _sr2 in _setle_df2.iterrows():
                                    _setle_map[str(_sr2["MBER_NO"])] = str(_sr2["SETLE_NM"])
                        _STAT_CD_MAP = {"2": "신규미납1", "3": "신규미납2", "4": "신규미납3", "5": "신규미납4", "6": "신규미납5",
                                        "7": "장기미납1", "8": "장기미납2", "9": "장기미납3", "10": "장기미납4", "11": "장기미납5"}
                        _unpaid_popup = {}
                        # 당해연도 + 전년도 데이터
                        for _uyr, _ubd in [(str(sel_year), _bd), (str(sel_year - 1), _prev_bd if '_prev_bd' in dir() else None)]:
                            if _ubd is None or _ubd.empty:
                                continue
                            _ubd_copy = _ubd.copy()
                            _ubd_copy["CMMN_BRND_NM"] = _ubd_copy["CMMN_BRND_NM"].replace({"직원개발": "지역개발", "콜개발": "마케팅콜개발"})
                            _ubd_copy["CMMN_BRND_NM"] = _ubd_copy["CMMN_BRND_NM"].replace(_BRND_MERGE)
                            for _cat in _cat_order:
                                for _st in ["신규미납", "장기미납"]:
                                    _sub = _ubd_copy[(_ubd_copy["CMPGN_CTGR_NM"] == _cat) & (_ubd_copy["STAT_GROUP"] == _st)]
                                    if _sub.empty:
                                        continue
                                    _total_amt = round(float(_sub["AMT"].sum()), 1)
                                    # 1) 가입연도별
                                    _jy = _sub.groupby("JOIN_YR")["MBER_NO"].nunique()
                                    _jy_total = int(_jy.sum())
                                    _jy_list = []
                                    for _yk in [str(sel_year), str(sel_year-1), str(sel_year-2), "prev"]:
                                        _yv = int(_jy.get(_yk, 0))
                                        if _yv > 0:
                                            _yl = f"{_yk}년" if _yk != "prev" else "이전"
                                            _jy_list.append({"n": _yl, "v": _yv, "p": round(_yv / _jy_total * 100, 1) if _jy_total > 0 else 0})
                                    # 2) 납입방식별
                                    _pay = {}
                                    for _mn in _sub["MBER_NO"].unique():
                                        _sn = _setle_map.get(str(_mn), "미확인")
                                        _pay[_sn] = _pay.get(_sn, 0) + 1
                                    _pay_list = [{"n": k, "v": v, "p": round(v / _jy_total * 100, 1) if _jy_total > 0 else 0} for k, v in sorted(_pay.items(), key=lambda x: -x[1])]
                                    # 3) 미납차수별
                                    if "MBER_STAT_CD" in _sub.columns:
                                        _sc = _sub.groupby("MBER_STAT_CD")["MBER_NO"].nunique()
                                        _sc_total = int(_sc.sum())
                                        _sc_list = []
                                        for _cd, _nm in sorted(_STAT_CD_MAP.items(), key=lambda x: int(x[0])):
                                            if (_st == "신규미납" and _cd in ("2","3","4","5","6")) or (_st == "장기미납" and _cd in ("7","8","9","10","11")):
                                                _sv = int(_sc.get(_cd, 0))
                                                if _sv > 0:
                                                    _sc_list.append({"n": _nm, "v": _sv, "p": round(_sv / _sc_total * 100, 1) if _sc_total > 0 else 0})
                                    else:
                                        _sc_list = []
                                    # 4) 마케팅캠페인명별
                                    _mc = _sub.groupby("MKTG_CMPGN_NM").agg(명수=("MBER_NO", "nunique"), 건수=("AMT", "sum")).sort_values("건수", ascending=False).reset_index()
                                    _mc_total = float(_mc["건수"].sum())
                                    _mc_list = []
                                    for _, _mr in _mc.head(20).iterrows():
                                        _mc_list.append({"n": str(_mr["MKTG_CMPGN_NM"]), "m": int(_mr["명수"]), "c": round(float(_mr["건수"]), 1),
                                                         "p": round(float(_mr["건수"]) / _mc_total * 100, 1) if _mc_total > 0 else 0})
                                    _pk = f"{_uyr}|{_cat}|{_st}"
                                    _unpaid_popup[_pk] = {"cat": _cat, "yr": _uyr, "st": _st, "total": _total_amt, "members": _jy_total,
                                                          "join_yr": _jy_list, "pay": _pay_list, "stat_cd": _sc_list, "camps": _mc_list}

                        import json as _json_unpaid
                        _unpaid_json = _json_unpaid.dumps(_unpaid_popup, ensure_ascii=False)
                        stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._unpaidPopupCleanup){{try{{doc._unpaidPopupCleanup()}}catch(e){{}}}}
var D={_unpaid_json};
var ov=doc.getElementById('unpaid-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='unpaid-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:40px;';
ov.innerHTML='<div id="unpaid-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:850px;width:96%;max-height:85vh;overflow-y:auto;"></div>';
var st=doc.createElement('style');st.id='unpaid-popup-style';
var oldSt=doc.getElementById('unpaid-popup-style');if(oldSt)oldSt.remove();
st.textContent='@keyframes unpaidpop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#unpaid-popup-box{{animation:unpaidpop .2s ease}}td[data-unpaid-popup]{{cursor:pointer}}td[data-unpaid-popup]:hover{{background:rgba(198,40,40,0.1)!important;}}';
doc.head.appendChild(st);
doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
function pie(items,colors){{
  if(!items||items.length===0)return '<span style="color:#999">데이터 없음</span>';
  var h='<div style="display:flex;flex-wrap:wrap;gap:6px">';
  for(var i=0;i<items.length;i++){{
    var it=items[i];var c=colors[i%colors.length];
    h+='<span style="background:'+c+';color:#fff;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:600">'+it.n+' '+it.v+'명 ('+it.p+'%)</span>';
  }}
  return h+'</div>';
}}
function render(key){{
  var d=D[key];if(!d)return;
  var box=doc.getElementById('unpaid-popup-box');
  var stColor=d.st==='신규미납'?'#E65100':'#C62828';
  var h='<div style="background:linear-gradient(135deg,'+stColor+','+stColor+'cc);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.yr+'년 '+d.cat+' > '+d.st+' ('+d.members.toLocaleString()+'명 / '+d.total.toLocaleString(undefined,{{minimumFractionDigits:1}})+'건)</span>';
  h+='<span id="unpaid-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px">✕</span></div>';
  h+='<div style="padding:18px 22px">';
  var sec='font-size:13px;font-weight:700;margin-bottom:8px;padding-bottom:5px;border-bottom:2px solid';
  // 가입연도별
  h+='<div style="'+sec+' #1565C0;color:#1565C0;margin-top:0">가입연도별 분포</div>';
  h+=pie(d.join_yr,['#1565C0','#42A5F5','#90CAF9','#B0BEC5']);
  // 납입방식별
  h+='<div style="'+sec+' #43A047;color:#43A047;margin-top:16px">납입방식(결제수단)별 분포</div>';
  h+=pie(d.pay,['#43A047','#66BB6A','#A5D6A7','#81C784','#4CAF50','#2E7D32']);
  // 미납차수별
  h+='<div style="'+sec+' #E65100;color:#E65100;margin-top:16px">미납차수별 분포</div>';
  h+=pie(d.stat_cd,['#FF8F00','#FFB74D','#E65100','#D84315','#BF360C']);
  // 마케팅캠페인명별 테이블
  h+='<div style="'+sec+' #333;color:#333;margin-top:16px">마케팅캠페인명별 상세 (상위 20)</div>';
  var th2='background:#f0f2f5;padding:5px 6px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px';
  h+='<table style="width:100%;border-collapse:collapse;font-size:11px"><thead><tr>';
  h+='<th style="'+th2+';width:28px">순위</th><th style="'+th2+';text-align:left">마케팅캠페인명</th>';
  h+='<th style="'+th2+';width:55px">명수</th><th style="'+th2+';width:65px">건수</th><th style="'+th2+';width:50px">구성비</th></tr></thead><tbody>';
  var tm=0,tc=0;
  for(var i=0;i<d.camps.length;i++){{
    var c=d.camps[i];tm+=c.m;tc+=c.c;
    var bg=i%2===0?'#fff':'#fafafa';
    h+='<tr style="background:'+bg+'"><td style="padding:3px 6px;text-align:center;border:1px solid #eee">'+(i+1)+'</td>';
    h+='<td style="padding:3px 6px;text-align:left;border:1px solid #eee;max-width:250px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+c.n+'</td>';
    h+='<td style="padding:3px 6px;text-align:right;border:1px solid #eee">'+c.m.toLocaleString()+'</td>';
    h+='<td style="padding:3px 6px;text-align:right;border:1px solid #eee;font-weight:600">'+c.c.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
    h+='<td style="padding:3px 6px;text-align:right;border:1px solid #eee">'+c.p.toFixed(1)+'%</td></tr>';
  }}
  h+='<tr style="background:#222;color:#fff;font-weight:700"><td style="padding:4px 6px;border:1px solid #555" colspan="2">합계</td>';
  h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tm.toLocaleString()+'</td>';
  h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tc.toLocaleString(undefined,{{minimumFractionDigits:1,maximumFractionDigits:1}})+'</td>';
  var tp=d.total>0?(tc/d.total*100):0;
  h+='<td style="padding:4px 6px;text-align:right;border:1px solid #555">'+tp.toFixed(1)+'%</td></tr>';
  h+='</tbody></table></div>';
  box.innerHTML=h;box.scrollTop=0;
  doc.getElementById('unpaid-close-btn').addEventListener('click',function(){{ov.style.display='none'}});
}}
function onClick(e){{
  var td=e.target.closest('td[data-unpaid-popup]');
  if(td){{var key=td.getAttribute('data-unpaid-popup');if(D[key]){{render(key);ov.style.display='flex';}}}}
}}
doc.addEventListener('click',onClick);
doc._unpaidPopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('unpaid-popup-overlay');if(o)o.remove();var s=doc.getElementById('unpaid-popup-style');if(s)s.remove();}};
}})();
</script>""", height=0)
                        st.markdown('<div style="height:12px"></div>', unsafe_allow_html=True)

        else:
            st.warning("유입경로별 활동회원 데이터가 없습니다.")



    else:

        st.warning("MSTR_ODS 기반 활동회원 데이터가 없습니다.")

elif selected_tab == TAB_LABELS[2]:
    # ===== 3. 회비현황 =====
    st.markdown("""
    <style>
        table { width: 100% !important; border-collapse: collapse !important; font-size: 12px !important; margin-bottom: 0 !important; }
        th { background-color: #4a4a4a !important; color: white !important; padding: 6px 5px !important; text-align: center !important; border: 1px solid #ddd !important; font-weight: 600 !important; white-space: nowrap !important; }
        td { padding: 5px 5px !important; text-align: right !important; border: 1px solid #ddd !important; white-space: nowrap !important; }
        td:first-child, td:nth-child(2), td:nth-child(3) {
            text-align: left !important;
        }
        td.center-pct {
            text-align: center !important;
        }
    </style>
    """, unsafe_allow_html=True)
    st.caption(f"법인: 사단법인 | 기준: {sel_year}년 {sel_month}월")

    # KPI 박스 자리 — 3-1·3-3·3-4 계산 완료 후 하단에서 채움
    _fee_kpi_slot = st.container()

    st.subheader("3-1. 회비현황 (회원구분별)")

    def _summary_box(parts, tail, ok):
        # 3-1·3-2·3-3 공통 한 줄 요약 박스 (달성 시 초록 띠, 미달 시 빨강 띠)
        _bd = "#2E7D32" if ok else "#C62828"
        st.markdown(
            f'<div style="background:linear-gradient(160deg,#ffffff 0%,#eef4fb 100%);border-left:6px solid {_bd};'
            f'border-radius:10px;padding:12px 18px;margin:4px 0 12px 0;box-shadow:0 3px 10px rgba(21,101,192,0.12);'
            f'font-size:15px;color:#263238;line-height:1.6;">'
            f'<span style="font-weight:900;color:#0D47A1;margin-right:8px;">📌 요약</span>'
            f'{", ".join(parts)}. <span style="color:#546E7A;">| {tail}</span></div>',
            unsafe_allow_html=True)

    def _eok(v):
        return f"{v / 1e8:,.1f}억원"
    st.caption("💡 납입회비를 클릭하시면 세부사항을 볼 수 있습니다.")

    # 회비 데이터 — MSTR_ODS F_PM_NEW_OLD_MBRFEE 로직 재현 (월별 루프)


    # 회비 목표 — DB에서 동적 로드

    with st.spinner("회비현황 데이터 집계 중..."):
        fee_df = load_fee_data(sel_year, sel_month)

    fee_goal_df = _load_fee_target(sel_year)
    _fee_mcol = f"R{sel_month:02d}"
    _fee_ytd_cols = [f"R{m:02d}" for m in range(1, sel_month + 1)]

    def _get_fee_goal(new_old, org_div, cols):
        if org_div is None:
            mask = fee_goal_df["NEW_OLD_DIV_NM"] == new_old
        else:
            mask = (fee_goal_df["NEW_OLD_DIV_NM"] == new_old) & (fee_goal_df["ORG_DIV_NM"] == org_div)
        rows = fee_goal_df[mask]
        if rows.empty:
            return 0
        return round(float(rows[cols].sum().sum()))

    def _get_fee_goal_month(new_old, org_div):
        return _get_fee_goal(new_old, org_div, [_fee_mcol])

    def _get_fee_goal_ytd(new_old, org_div):
        return _get_fee_goal(new_old, org_div, _fee_ytd_cols)

    if not fee_df.empty:
        fee_data = {}
        for _, r in fee_df.iterrows():
            key = (r["NEW_OLD"], r["HQ_DIV"])
            fee_data[key] = {
                "m_members": int(r["MONTH_PAY_MEMBERS"]),
                "m_pay": float(r["MONTH_PAY"]),
                "y_members": int(r["YTD_PAY_MEMBERS"]),
                "y_pay": float(r["YTD_PAY"]),
            }

        def _fd(key):
            return fee_data.get(key, {"m_members": 0, "m_pay": 0, "y_members": 0, "y_pay": 0})

        def _pct(v, t):
            return round(v / t * 100, 1) if t > 0 else 0.0

        # 표 데이터 구축
        fee_rows = []
        # 신규회원 > 본부
        d = _fd(("신규회원", "본부"))
        m_tgt = _get_fee_goal_month("신규", "본부")
        y_tgt = _get_fee_goal_ytd("신규", "본부")
        fee_rows.append({"구분1": "회원구분별\n회비 (원)", "구분2": "일반\n회비", "구분3": "정기\n회비", "구분4": "신규\n회원", "구분5": "본부",
            "m_tgt": m_tgt, "m_members": d["m_members"], "m_pay": d["m_pay"], "m_rate": _pct(d["m_pay"], m_tgt),
            "y_tgt": y_tgt, "y_members": d["y_members"], "y_pay": d["y_pay"], "y_rate": _pct(d["y_pay"], y_tgt)})
        # 신규회원 > 시도본부, 지부 등
        d = _fd(("신규회원", "시도본부, 지부 등"))
        m_tgt = _get_fee_goal_month("신규", "지부")
        y_tgt = _get_fee_goal_ytd("신규", "지부")
        fee_rows.append({"구분1": "", "구분2": "", "구분3": "", "구분4": "", "구분5": "시도본부, 지부 등",
            "m_tgt": m_tgt, "m_members": d["m_members"], "m_pay": d["m_pay"], "m_rate": _pct(d["m_pay"], m_tgt),
            "y_tgt": y_tgt, "y_members": d["y_members"], "y_pay": d["y_pay"], "y_rate": _pct(d["y_pay"], y_tgt)})
        # 소계
        d1 = _fd(("신규회원", "본부"))
        d2 = _fd(("신규회원", "시도본부, 지부 등"))
        sm = {k: d1[k] + d2[k] for k in d1}
        sm_m_tgt = fee_rows[0]["m_tgt"] + fee_rows[1]["m_tgt"]
        sm_y_tgt = fee_rows[0]["y_tgt"] + fee_rows[1]["y_tgt"]
        fee_rows.append({"구분1": "", "구분2": "", "구분3": "", "구분4": "", "구분5": "소계",
            "m_tgt": sm_m_tgt, "m_members": sm["m_members"], "m_pay": sm["m_pay"], "m_rate": _pct(sm["m_pay"], sm_m_tgt),
            "y_tgt": sm_y_tgt, "y_members": sm["y_members"], "y_pay": sm["y_pay"], "y_rate": _pct(sm["y_pay"], sm_y_tgt)})
        # 기존회원
        d3a = _fd(("기존회원", "본부"))
        d3b = _fd(("기존회원", "시도본부, 지부 등"))
        de = {k: d3a[k] + d3b[k] for k in d3a}
        em_tgt = _get_fee_goal_month("기존", None)
        ey_tgt = _get_fee_goal_ytd("기존", None)
        fee_rows.append({"구분1": "", "구분2": "", "구분3": "", "구분4": "기존회원", "구분5": "기존회원",
            "m_tgt": em_tgt, "m_members": de["m_members"], "m_pay": de["m_pay"], "m_rate": _pct(de["m_pay"], em_tgt),
            "y_tgt": ey_tgt, "y_members": de["y_members"], "y_pay": de["y_pay"], "y_rate": _pct(de["y_pay"], ey_tgt)})
        # 합계
        gt = {k: sm[k] + de[k] for k in sm}
        gm_tgt = sm_m_tgt + em_tgt
        gy_tgt = sm_y_tgt + ey_tgt
        fee_rows.append({"구분1": "", "구분2": "", "구분3": "", "구분4": "합계", "구분5": "",
            "m_tgt": gm_tgt, "m_members": gt["m_members"], "m_pay": gt["m_pay"], "m_rate": _pct(gt["m_pay"], gm_tgt),
            "y_tgt": gy_tgt, "y_members": gt["y_members"], "y_pay": gt["y_pay"], "y_rate": _pct(gt["y_pay"], gy_tgt)})

        # ── 3-1 한 줄 요약 ──
        _s1 = fee_rows[4]
        _s1_parts = [f"당월 납입회비 <b>{_eok(_s1['m_pay'])}</b>"]
        if _s1["m_tgt"]:
            _s1_parts[0] += f" (목표 {_eok(_s1['m_tgt'])}, 달성률 <b>{_s1['m_rate']:.1f}%</b>)"
        _s1_pf = _load_fee_month(sel_year - 1, sel_month)
        _s1_prev = float(_s1_pf["PAY_AMT"].sum()) if not _s1_pf.empty else 0
        if _s1_prev:
            _s1_d = (_s1["m_pay"] - _s1_prev) / _s1_prev * 100
            _s1_parts.append(f"전년 동월 대비 <b>{abs(_s1_d):.1f}% {'증가' if _s1_d >= 0 else '감소'}</b>")
        _s1_lbl = ["신규회원 본부", "신규회원 지부", None, "기존회원"]
        _s1_gaps = [(_s1_lbl[i], fee_rows[i]["m_pay"] - fee_rows[i]["m_tgt"]) for i in (0, 1, 3) if fee_rows[i]["m_tgt"]]
        _s1_neg = [g for g in _s1_gaps if g[1] < 0]
        if _s1_neg:
            _s1_w = min(_s1_neg, key=lambda g: g[1])
            _s1_parts.append(f"목표 미달 주요 원인은 <b>{_s1_w[0]} (-{_eok(-_s1_w[1])})</b>")
        elif _s1_gaps:
            _s1_parts.append("<b>모든 회원구분 목표 달성</b>")
        _s1_tail = f"누계 납입회비 <b>{_eok(_s1['y_pay'])}</b>" + (f" (목표 대비 <b>{_s1['y_rate']:.1f}%</b>)" if _s1["y_tgt"] else "")
        _summary_box(_s1_parts, _s1_tail, (not _s1["m_tgt"]) or _s1["m_pay"] >= _s1["m_tgt"])

        # HTML 렌더링
        th = "background-color:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px;"
        th_sub = "background-color:#4a4a4a;color:white;padding:5px 4px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:11px;"
        fee_html = '<div id="fee-table"><style>#fee-table td { text-align:center !important; }</style>'
        fee_html += '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
        fee_html += '<thead><tr>'
        fee_html += f'<th colspan="2" rowspan="2" style="{th}">구분</th>'
        fee_html += f'<th colspan="4" style="{th}">당월</th>'
        fee_html += f'<th colspan="4" style="{th}">누계</th>'
        fee_html += '</tr><tr>'
        for _ in range(2):
            fee_html += f'<th style="{th_sub}">목표 (원)</th>'
            fee_html += f'<th style="{th_sub}">납입 (명)<br><span style="font-size:9px;font-weight:normal">*중복포함</span></th>'
            fee_html += f'<th style="{th_sub}">납입 (원)</th>'
            fee_html += f'<th style="{th_sub}">달성율 (%)</th>'
        fee_html += '</tr></thead><tbody>'

        for i, r in enumerate(fee_rows):
            is_total = r["구분4"] == "합계"
            is_sub = r["구분5"] == "소계"
            if is_total:
                rs = "background-color:#222222;color:white;font-weight:bold;"
            elif is_sub:
                rs = "background-color:#d9d9d9;font-weight:bold;"
            else:
                rs = ""
            td = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{rs}"
            fee_html += '<tr>'
            if i == 0:
                fee_html += f'<td rowspan="3" style="{td}text-align:center;vertical-align:middle;">신규회원</td>'
            elif i == 3:
                fee_html += f'<td rowspan="1" style="{td}text-align:center;">기존회원</td>'
            elif i == 4:
                fee_html += f'<td rowspan="1" style="{td}text-align:center;font-weight:bold;">합계</td>'
            label = r["구분5"]
            if i < 3:
                fee_html += f'<td style="{td}text-align:center;">{label}</td>'
            elif i == 3:
                fee_html += f'<td style="{td}text-align:center;"></td>'
            elif i == 4:
                fee_html += f'<td style="{td}text-align:center;"></td>'
            tgt_style = f"padding:5px;border:1px solid #ddd;white-space:nowrap;background-color:#808000;color:white;{rs}"
            fee_html += f'<td style="{tgt_style}text-align:center !important;">{r["m_tgt"]:,.0f}</td>'
            fee_html += f'<td style="{td}text-align:center !important;">{r["m_members"]:,}</td>'
            fee_html += f'<td style="{td}text-align:center !important;">{r["m_pay"]:,.0f}</td>'
            fee_html += f'<td style="{td}text-align:center !important;">{r["m_rate"]:.1f}%</td>'
            fee_html += f'<td style="{tgt_style}text-align:center !important;">{r["y_tgt"]:,.0f}</td>'
            fee_html += f'<td style="{td}text-align:center !important;">{r["y_members"]:,}</td>'
            fee_html += f'<td style="{td}text-align:center !important;">{r["y_pay"]:,.0f}</td>'
            fee_html += f'<td style="{td}text-align:center !important;">{r["y_rate"]:.1f}%</td>'
            fee_html += '</tr>'
        fee_html += '</tbody></table></div>'

        # ── 3-1 팝업: 납입(원) 캠페인 상세 ──

        with st.spinner("납입 캠페인 상세 로딩 중..."):
            _fcd = _load_fee_camp_detail(sel_year, sel_month)

        _fee_popup = {}
        if not _fcd.empty:
            _BRND_MERGE_FEE = {"방송": "방송/광고", "재송출": "방송/광고", "영상광고": "방송/광고", "뉴미디어": "방송/광고",
                               "회원 온라인개발": "회원", "회원 오프라인개발": "회원", "회원 콜개발": "회원", "회원 기타": "회원",
                               "직원개발": "지역개발", "콜개발": "마케팅콜개발"}
            _fcd["CMMN_BRND_NM"] = _fcd["CMMN_BRND_NM"].replace(_BRND_MERGE_FEE)
            # 팝업 키: m|신규본부, m|신규지부, m|신규소계, m|기존, m|합계, y|... (10개)
            _FEE_POPUP_FILTERS = {
                "신규본부": lambda d: d[d["NEW_OLD"] == "신규회원"],
                "신규지부": lambda d: d[d["NEW_OLD"] == "신규회원"],
                "신규소계": lambda d: d[d["NEW_OLD"] == "신규회원"],
                "기존": lambda d: d[d["NEW_OLD"] == "기존회원"],
                "합계": lambda d: d,
            }
            for _pk, _filt in _FEE_POPUP_FILTERS.items():
                _sub = _filt(_fcd)
                for _period, _col in [("m", "MONTH_PAY"), ("y", "YTD_PAY")]:
                    _agg = _sub.groupby(["CMMN_BRND_NM", "MKTG_CMPGN_NM"])[_col].sum().reset_index()
                    _agg.columns = ["브랜드", "캠페인", "납입원"]
                    _agg = _agg[_agg["납입원"] > 0].sort_values("납입원", ascending=False).reset_index(drop=True)
                    _total = float(_agg["납입원"].sum())
                    if _total <= 0:
                        continue
                    _top20 = _agg.head(20)
                    _camps = []
                    for _, _cr in _top20.iterrows():
                        _camps.append({"b": str(_cr["브랜드"]), "n": str(_cr["캠페인"]),
                                       "v": round(float(_cr["납입원"])), "p": round(float(_cr["납입원"]) / _total * 100, 1)})
                    _label = {"신규본부": "신규회원 > 본부", "신규지부": "신규회원 > 시도본부,지부", "신규소계": "신규회원 소계", "기존": "기존회원", "합계": "합계"}[_pk]
                    _period_label = "당월" if _period == "m" else "누계"
                    _fee_popup[f"{_period}|{_pk}"] = {"name": f"{_label} {_period_label} 납입(원)", "total": round(_total), "camps": _camps}

        # 3-1 HTML 재렌더링 (납입원 셀 클릭 가능)
        _FEE_ROW_KEYS = ["신규본부", "신규지부", "신규소계", "기존", "합계"]
        fee_html2 = '<div id="fee-table2"><style>#fee-table2 td { text-align:center !important; }</style>'
        fee_html2 += '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
        fee_html2 += '<thead><tr>'
        fee_html2 += f'<th colspan="2" rowspan="2" style="{th}">구분</th>'
        fee_html2 += f'<th colspan="4" style="{th}">당월</th>'
        fee_html2 += f'<th colspan="4" style="{th}">누계</th>'
        fee_html2 += '</tr><tr>'
        for _ in range(2):
            fee_html2 += f'<th style="{th_sub}">목표 (원)</th>'
            fee_html2 += f'<th style="{th_sub}">납입 (명)<br><span style="font-size:9px;font-weight:normal">*중복포함</span></th>'
            fee_html2 += f'<th style="{th_sub}">납입 (원)</th>'
            fee_html2 += f'<th style="{th_sub}">달성율 (%)</th>'
        fee_html2 += '</tr></thead><tbody>'
        for i, r in enumerate(fee_rows):
            is_total = r["구분4"] == "합계"
            is_sub = r["구분5"] == "소계"
            if is_total:
                rs = "background-color:#222222;color:white;font-weight:bold;"
            elif is_sub:
                rs = "background-color:#d9d9d9;font-weight:bold;"
            else:
                rs = ""
            td = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{rs}"
            _pk = _FEE_ROW_KEYS[i]
            fee_html2 += '<tr>'
            if i == 0:
                fee_html2 += f'<td rowspan="3" style="{td}text-align:center;vertical-align:middle;">신규회원</td>'
            elif i == 3:
                fee_html2 += f'<td rowspan="1" style="{td}text-align:center;">기존회원</td>'
            elif i == 4:
                fee_html2 += f'<td rowspan="1" style="{td}text-align:center;font-weight:bold;">합계</td>'
            label = r["구분5"]
            if i < 3:
                fee_html2 += f'<td style="{td}text-align:center;">{label}</td>'
            else:
                fee_html2 += f'<td style="{td}text-align:center;"></td>'
            tgt_style = f"padding:5px;border:1px solid #ddd;white-space:nowrap;background-color:#808000;color:white;{rs}"
            fee_html2 += f'<td style="{tgt_style}text-align:center !important;">{r["m_tgt"]:,.0f}</td>'
            fee_html2 += f'<td style="{td}text-align:center !important;">{r["m_members"]:,}</td>'
            _mk = f"m|{_pk}"
            if _mk in _fee_popup and r["m_pay"] > 0:
                fee_html2 += f'<td data-fee-popup="{_mk}" style="{td}text-align:center !important;cursor:pointer;" title="클릭 시 캠페인 상세">{r["m_pay"]:,.0f}</td>'
            else:
                fee_html2 += f'<td style="{td}text-align:center !important;">{r["m_pay"]:,.0f}</td>'
            fee_html2 += f'<td style="{td}text-align:center !important;">{r["m_rate"]:.1f}%</td>'
            fee_html2 += f'<td style="{tgt_style}text-align:center !important;">{r["y_tgt"]:,.0f}</td>'
            fee_html2 += f'<td style="{td}text-align:center !important;">{r["y_members"]:,}</td>'
            _yk = f"y|{_pk}"
            if _yk in _fee_popup and r["y_pay"] > 0:
                fee_html2 += f'<td data-fee-popup="{_yk}" style="{td}text-align:center !important;cursor:pointer;" title="클릭 시 캠페인 상세">{r["y_pay"]:,.0f}</td>'
            else:
                fee_html2 += f'<td style="{td}text-align:center !important;">{r["y_pay"]:,.0f}</td>'
            fee_html2 += f'<td style="{td}text-align:center !important;">{r["y_rate"]:.1f}%</td>'
            fee_html2 += '</tr>'
        fee_html2 += '</tbody></table></div>'
        st.markdown(fee_html2, unsafe_allow_html=True)

        # JS 팝업
        import json as _json_fee
        _fp_json = _json_fee.dumps(_fee_popup, ensure_ascii=False)
        stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._feePopupCleanup){{try{{doc._feePopupCleanup()}}catch(e){{}}}};
var D={_fp_json};
var ov=doc.getElementById('fee-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='fee-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="fee-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:850px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st2=doc.createElement('style');st2.id='fee-popup-style';
var os=doc.getElementById('fee-popup-style');if(os)os.remove();
st2.textContent='@keyframes feepop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#fee-popup-box{{animation:feepop .2s ease}}td[data-fee-popup]{{cursor:pointer}}td[data-fee-popup]:hover{{background:rgba(21,101,192,0.1) !important}}';
doc.head.appendChild(st2);doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
var box=doc.getElementById('fee-popup-box');
function fmt(v){{return Number(v).toLocaleString()}}
function render(key){{
  var d=D[key];if(!d)return;
  var h='<div style="background:linear-gradient(135deg,#1565C0,#1976D2);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.name+' ('+fmt(d.total)+'원)</span>';
  h+='<div style="display:flex;align-items:center;gap:10px">';
  h+='<button id="fee-dl-btn" style="padding:4px 12px;font-size:11px;border:1px solid #fff;border-radius:4px;background:rgba(255,255,255,0.15);color:#fff;cursor:pointer">엑셀 다운로드</button>';
  h+='<span id="fee-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div></div>';
  h+='<div style="padding:18px 22px">';
  // 테이블
  h+='<div style="font-size:13px;font-weight:700;color:#1565C0;margin-bottom:8px;border-bottom:2px solid #1976D2;padding-bottom:5px">공통브랜드 × 마케팅캠페인별 납입 현황 (상위 20)</div>';
  h+='<table style="width:100%;border-collapse:collapse;font-size:11px;margin-bottom:16px"><thead><tr>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;width:28px">순위</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:left;border:1px solid #e0e0e0;width:80px">공통브랜드</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:left;border:1px solid #e0e0e0">마케팅캠페인명</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:right;border:1px solid #e0e0e0;width:90px">납입(원)</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:right;border:1px solid #e0e0e0;width:60px">구성비(%)</th>';
  h+='</tr></thead><tbody>';
  var tc=0;
  for(var i=0;i<d.camps.length;i++){{
    var c=d.camps[i];tc+=c.v;
    var bg=i%2===0?'#fff':'#fafafa';
    h+='<tr style="background:'+bg+'"><td style="padding:4px 8px;text-align:center;border:1px solid #eee">'+(i+1)+'</td>';
    h+='<td style="padding:4px 8px;text-align:left;border:1px solid #eee;color:#666">'+c.b+'</td>';
    h+='<td style="padding:4px 8px;text-align:left;border:1px solid #eee;max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+c.n+'</td>';
    h+='<td style="padding:4px 8px;text-align:right;border:1px solid #eee;font-weight:600">'+fmt(c.v)+'</td>';
    h+='<td style="padding:4px 8px;text-align:right;border:1px solid #eee">'+c.p.toFixed(1)+'%</td></tr>';
  }}
  var tp=d.total>0?(tc/d.total*100):0;
  h+='<tr style="background:#222;color:#fff;font-weight:700"><td style="padding:4px 8px;text-align:center;border:1px solid #555" colspan="3">합계</td>';
  h+='<td style="padding:4px 8px;text-align:right;border:1px solid #555">'+fmt(tc)+'</td>';
  h+='<td style="padding:4px 8px;text-align:right;border:1px solid #555">'+tp.toFixed(1)+'%</td></tr>';
  h+='</tbody></table>';
  // 상위 10 바차트 (CSS)
  h+='<div style="font-size:13px;font-weight:700;color:#1565C0;margin-bottom:8px;border-bottom:2px solid #1976D2;padding-bottom:5px">TOP 10 마케팅캠페인 납입(원)</div>';
  var top10=d.camps.slice(0,10);
  var maxV=top10.length>0?top10[0].v:1;
  for(var j=0;j<top10.length;j++){{
    var c=top10[j];
    var w=Math.max(maxV>0?(c.v/maxV*100):0,2);
    h+='<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">';
    h+='<div style="width:140px;font-size:11px;text-align:right;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#555" title="'+c.n+'">'+c.n+'</div>';
    h+='<div style="flex:1;height:20px;background:#f0f0f0;border-radius:4px;overflow:hidden">';
    h+='<div style="width:'+w.toFixed(1)+'%;height:100%;background:linear-gradient(90deg,#A8D8EA,#88C9BF);border-radius:4px"></div></div>';
    h+='<div style="width:100px;font-size:11px;font-weight:700;color:#333">'+fmt(c.v)+'</div></div>';
  }}
  h+='</div>';
  box.innerHTML=h;box.scrollTop=0;box._currentKey=key;
  doc.getElementById('fee-close-btn').addEventListener('click',function(){{ov.style.display='none'}});
  doc.getElementById('fee-dl-btn').addEventListener('click',function(){{
    var dd=D[box._currentKey];if(!dd)return;
    var rows=[['순위','공통브랜드','마케팅캠페인명','납입(원)','구성비(%)']];
    for(var j=0;j<dd.camps.length;j++){{var c=dd.camps[j];rows.push([j+1,c.b,c.n,c.v,c.p.toFixed(1)+'%']);}};
    var csv='\\uFEFF';rows.forEach(function(r){{csv+=r.map(function(v){{var s=String(v==null?'':v);if(s.indexOf(',')>=0||s.indexOf('"')>=0)return '"'+s.replace(/"/g,'""')+'"';return s}}).join(',')+\"\\n\"}});
    var blob=new Blob([csv],{{type:'text/csv;charset=utf-8'}});var a=document.createElement('a');a.href=URL.createObjectURL(blob);
    a.download=dd.name.replace(/[\\\\/:*?"<>|]/g,'_')+'_상세.csv';a.click();URL.revokeObjectURL(a.href);
  }});
}}
function onClick(e){{
  var td=e.target.closest('td[data-fee-popup]');
  if(td){{var key=td.getAttribute('data-fee-popup');if(D[key]){{render(key);ov.style.display='flex';}}}}
}}
doc.addEventListener('click',onClick);
doc._feePopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('fee-popup-overlay');if(o)o.remove();var s=doc.getElementById('fee-popup-style');if(s)s.remove();}};
}})();
</script>""", height=0)
        st.caption(f"출처: BRONZE_CRM — MSTR_ODS F_PM_NEW_OLD_MBRFEE 로직 재현 (활동행 기준 신규/기존, 기준월: {sel_year}-{sel_month:02d}, 법인: I)")
    else:
        st.warning("회비현황 데이터가 없습니다.")

    # ===== 3-2. 회비현황 (후원사업별) =====
    st.divider()
    st.subheader("3-2. 회비현황 (후원사업별)")
    st.caption("💡 납입회비를 클릭하시면 세부사항을 볼 수 있습니다.")




    with st.spinner("후원사업별 회비 데이터 집계 중..."):
        fee_biz_df = load_fee_biz_data(sel_year, sel_month)

    with st.spinner("후원사업별 캠페인 상세 로딩 중..."):
        _fbc = _load_fee_biz_camp_detail(sel_year, sel_month)

    fee_biz_goal_df = _load_fee_biz_target(sel_year)
    _fbm = f"R{sel_month:02d}"
    _fby = [f"R{m:02d}" for m in range(1, sel_month + 1)]

    _BIZ_FEE_GOAL_MAP = {
        "국내아동권리보호사업": "국내(사단)", "해외아동결연": "해외아동결연",
        "해외교육지원사업": "해외교육지원사업", "희망학교지원사업": "희망학교지원사업",
        "식수위생지원사업": "식수위생지원사업", "보건의료지원사업": "보건의료지원사업",
        "해외지역개발사업": "해외지역개발사업", "재난구호지원사업": "재난구호지원사업",
        "대북지원사업": "대북지원사업", "전체사업지원": "전체사업지원",
        "좋은이웃후원": "좋은이웃후원",
    }

    def _bfg(name, cols):
        db = _BIZ_FEE_GOAL_MAP.get(name)
        if db is None:
            return 0
        rows = fee_biz_goal_df[fee_biz_goal_df["SPNSR_BSNS_DIV_NM"] == db]
        return round(float(rows[cols].sum().sum())) if not rows.empty else 0

    def _bfg_m(name):
        return _bfg(name, [_fbm])

    def _bfg_y(name):
        return _bfg(name, _fby)

    def _bfg_sum_m(names):
        return sum(_bfg_m(n) for n in names)

    def _bfg_sum_y(names):
        return sum(_bfg_y(n) for n in names)

    _BIZ_FEE_ID_MAP = {
        '4': "국내아동권리보호사업", '16': "국내아동권리보호사업", '15': "국내아동권리보호사업",
        '22': "국내아동권리보호사업", '14': "국내아동권리보호사업", '21': "국내아동권리보호사업",
        '43': "국내아동권리보호사업",
        '1': "해외아동결연", '41': "해외교육지원사업", '38': "희망학교지원사업",
        '39': "식수위생지원사업", '42': "보건의료지원사업", '2': "해외지역개발사업",
        '9': "재난구호지원사업", '3': "대북지원사업", '5': "전체사업지원",
        '6': "좋은이웃후원", '33': "기타사업후원", '99': "기타",
    }

    _biz_fee = {}
    if not fee_biz_df.empty:
        for _, r in fee_biz_df.iterrows():
            disp = _BIZ_FEE_ID_MAP.get(str(r["SPNSR_BSNS_ID"]), "기타")
            if disp not in _biz_fee:
                _biz_fee[disp] = {"m_cnt": 0, "m_amt": 0.0, "y_cnt": 0, "y_amt": 0.0}
            _biz_fee[disp]["m_cnt"] += int(r["MONTH_PAY_CNT"])
            _biz_fee[disp]["m_amt"] += float(r["MONTH_PAY_AMT"])
            _biz_fee[disp]["y_cnt"] += int(r["YTD_PAY_CNT"])
            _biz_fee[disp]["y_amt"] += float(r["YTD_PAY_AMT"])

    def _bf(name):
        return _biz_fee.get(name, {"m_cnt": 0, "m_amt": 0.0, "y_cnt": 0, "y_amt": 0.0})

    def _bf_sum(names):
        return {k: sum(_bf(n)[k] for n in names) for k in ["m_cnt", "m_amt", "y_cnt", "y_amt"]}

    _OVERSEAS = ["해외아동결연", "해외교육지원사업", "희망학교지원사업",
                 "식수위생지원사업", "보건의료지원사업", "해외지역개발사업", "재난구호지원사업"]
    _ETC_DISPLAY = ["전체사업지원", "좋은이웃후원"]
    _ETC_ALL = _ETC_DISPLAY + ["기타사업후원", "기타"]

    def _pct_biz(v, t):
        return round(v / t * 100, 1) if t > 0 else 0.0

    biz_fee_rows = []

    # 국내아동권리보호사업
    d = _bf("국내아동권리보호사업")
    mt = _bfg_m("국내아동권리보호사업"); yt = _bfg_y("국내아동권리보호사업")
    biz_fee_rows.append(("국내아동권리보호사업", mt, d["m_cnt"], d["m_amt"], _pct_biz(d["m_amt"], mt),
                          yt, d["y_cnt"], d["y_amt"], _pct_biz(d["y_amt"], yt), False))

    # 해외 개별
    for name in _OVERSEAS:
        d = _bf(name)
        mt = _bfg_m(name); yt = _bfg_y(name)
        biz_fee_rows.append((name, mt, d["m_cnt"], d["m_amt"], _pct_biz(d["m_amt"], mt),
                              yt, d["y_cnt"], d["y_amt"], _pct_biz(d["y_amt"], yt), False))

    # 해외 소계
    d = _bf_sum(_OVERSEAS)
    mt = _bfg_sum_m(_OVERSEAS); yt = _bfg_sum_y(_OVERSEAS)
    biz_fee_rows.append(("해외 소계", mt, d["m_cnt"], d["m_amt"], _pct_biz(d["m_amt"], mt),
                          yt, d["y_cnt"], d["y_amt"], _pct_biz(d["y_amt"], yt), True))

    # 대북지원사업
    d = _bf("대북지원사업")
    mt = _bfg_m("대북지원사업"); yt = _bfg_y("대북지원사업")
    biz_fee_rows.append(("대북지원사업", mt, d["m_cnt"], d["m_amt"], _pct_biz(d["m_amt"], mt),
                          yt, d["y_cnt"], d["y_amt"], _pct_biz(d["y_amt"], yt), False))

    # 기타 개별
    for name in _ETC_DISPLAY:
        d = _bf(name)
        mt = _bfg_m(name); yt = _bfg_y(name)
        biz_fee_rows.append((name, mt, d["m_cnt"], d["m_amt"], _pct_biz(d["m_amt"], mt),
                              yt, d["y_cnt"], d["y_amt"], _pct_biz(d["y_amt"], yt), False))

    # 기타 소계
    d = _bf_sum(_ETC_ALL)
    mt = _bfg_sum_m(_ETC_DISPLAY); yt = _bfg_sum_y(_ETC_DISPLAY)
    biz_fee_rows.append(("기타 소계", mt, d["m_cnt"], d["m_amt"], _pct_biz(d["m_amt"], mt),
                          yt, d["y_cnt"], d["y_amt"], _pct_biz(d["y_amt"], yt), True))

    # 합계 = 국내 + 해외소계 + 대북 + 기타소계
    dom = _bf("국내아동권리보호사업")
    ovs = _bf_sum(_OVERSEAS)
    dae = _bf("대북지원사업")
    etc = _bf_sum(_ETC_ALL)
    gt = {k: dom[k] + ovs[k] + dae[k] + etc[k] for k in dom}
    mt = _bfg_m("국내아동권리보호사업") + _bfg_sum_m(_OVERSEAS) + _bfg_m("대북지원사업") + _bfg_sum_m(_ETC_DISPLAY)
    yt = _bfg_y("국내아동권리보호사업") + _bfg_sum_y(_OVERSEAS) + _bfg_y("대북지원사업") + _bfg_sum_y(_ETC_DISPLAY)
    biz_fee_rows.append(("합계", mt, gt["m_cnt"], gt["m_amt"], _pct_biz(gt["m_amt"], mt),
                          yt, gt["y_cnt"], gt["y_amt"], _pct_biz(gt["y_amt"], yt), True))

    # ── 3-2 한 줄 요약 ──
    _s2_map = {r[0]: r for r in biz_fee_rows}
    _s2 = _s2_map["합계"]   # (구분, 당월목표, 당월건, 당월납입, 당월달성, 누계목표, 누계건, 누계납입, 누계달성, 소계여부)
    _s2_parts = [f"당월 후원사업 납입 <b>{_eok(_s2[3])}</b>"]
    if _s2[1]:
        _s2_parts[0] += f" (목표 {_eok(_s2[1])}, 달성률 <b>{_s2[4]:.1f}%</b>)"
    _s2_pb = load_fee_biz_data(sel_year - 1, sel_month, by_month=True)
    _s2_prev = (float(_s2_pb[_s2_pb["PAY_MT"].astype(str).str[-2:].astype(int) == sel_month]["PAY_AMT"].astype(float).sum())
                if not _s2_pb.empty else 0)
    if _s2_prev:
        _s2_d = (_s2[3] - _s2_prev) / _s2_prev * 100
        _s2_parts.append(f"전년 동월 대비 <b>{abs(_s2_d):.1f}% {'증가' if _s2_d >= 0 else '감소'}</b>")
    _s2_grp = [("국내", "국내아동권리보호사업"), ("해외", "해외 소계"), ("대북", "대북지원사업"), ("기타", "기타 소계")]
    _s2_gaps = [(_nm, _s2_map[_k][3] - _s2_map[_k][1]) for _nm, _k in _s2_grp if _k in _s2_map and _s2_map[_k][1]]
    _s2_neg = [g for g in _s2_gaps if g[1] < 0]
    if _s2_neg:
        _s2_w = min(_s2_neg, key=lambda g: g[1])
        _s2_parts.append(f"목표 미달 주요 원인은 <b>{_s2_w[0]}사업 (-{_eok(-_s2_w[1])})</b>")
    elif _s2_gaps:
        _s2_parts.append("<b>모든 사업 목표 달성</b>")
    # 누계 비중 1위 사업
    _s2_share = [(_nm, _s2_map[_k][7]) for _nm, _k in _s2_grp if _k in _s2_map]
    _s2_tail = f"누계 납입 <b>{_eok(_s2[7])}</b>" + (f" (목표 대비 <b>{_s2[8]:.1f}%</b>)" if _s2[5] else "")
    if _s2_share and _s2[7]:
        _s2_top = max(_s2_share, key=lambda g: g[1])
        _s2_tail += f", 누계 비중 1위 {_s2_top[0]}사업 {_s2_top[1] / _s2[7] * 100:.1f}%"
    _summary_box(_s2_parts, _s2_tail, (not _s2[1]) or _s2[3] >= _s2[1])

    # 후원사업별 캠페인 팝업 데이터
    _fee_biz_popup = {}
    if not _fbc.empty:
        _BRND_MERGE_BIZ = {"방송": "방송/광고", "재송출": "방송/광고", "영상광고": "방송/광고", "뉴미디어": "방송/광고",
                           "회원 온라인개발": "회원", "회원 오프라인개발": "회원", "회원 콜개발": "회원", "회원 기타": "회원",
                           "직원개발": "지역개발", "콜개발": "마케팅콜개발"}
        _fbc_c = _fbc.copy()
        _fbc_c["CMMN_BRND_NM"] = _fbc_c["CMMN_BRND_NM"].replace(_BRND_MERGE_BIZ)
        _fbc_c["DISP_NM"] = _fbc_c["SPNSR_BSNS_ID"].map(_BIZ_FEE_ID_MAP).fillna("기타")
        def _build_biz_popup(sub_df, name, period, col):
            agg = sub_df.groupby(["CMMN_BRND_NM", "MKTG_CMPGN_NM"])[col].sum().reset_index()
            agg.columns = ["브랜드", "캠페인", "납입원"]
            agg = agg[agg["납입원"] > 0].sort_values("납입원", ascending=False).reset_index(drop=True)
            total = float(agg["납입원"].sum())
            if total <= 0:
                return
            top20 = agg.head(20)
            camps = []
            for _, cr in top20.iterrows():
                camps.append({"b": str(cr["브랜드"]), "n": str(cr["캠페인"]),
                               "v": round(float(cr["납입원"])), "p": round(float(cr["납입원"]) / total * 100, 1)})
            pl = "당월" if period == "m" else "누계"
            _fee_biz_popup[f"{period}|{name}"] = {"name": f"{name} {pl} 납입(원)", "total": round(total), "camps": camps}
        for dname in _fbc_c["DISP_NM"].unique():
            sub = _fbc_c[_fbc_c["DISP_NM"] == dname]
            for _p, _c in [("m", "MONTH_PAY"), ("y", "YTD_PAY")]:
                _build_biz_popup(sub, dname, _p, _c)
        for grp_name, grp_list in [("해외 소계", _OVERSEAS), ("기타 소계", _ETC_ALL)]:
            sub = _fbc_c[_fbc_c["DISP_NM"].isin(grp_list)]
            for _p, _c in [("m", "MONTH_PAY"), ("y", "YTD_PAY")]:
                _build_biz_popup(sub, grp_name, _p, _c)
        for _p, _c in [("m", "MONTH_PAY"), ("y", "YTD_PAY")]:
            _build_biz_popup(_fbc_c, "합계", _p, _c)

    # HTML 렌더링
    _bth = "background-color:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px;"
    _bths = "background-color:#4a4a4a;color:white;padding:5px 4px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:11px;"
    bfh = '<div id="fee-biz-table"><style>#fee-biz-table td { text-align:center !important; }</style>'
    bfh += '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
    bfh += '<thead><tr>'
    bfh += f'<th rowspan="2" style="{_bth}">후원사업명</th>'
    bfh += f'<th colspan="4" style="{_bth}">당월</th>'
    bfh += f'<th colspan="4" style="{_bth}">누계</th>'
    bfh += '</tr><tr>'
    for _ in range(2):
        bfh += f'<th style="{_bths}">목표 (원)</th>'
        bfh += f'<th style="{_bths}">납입 (명)<br><span style="font-size:9px;font-weight:normal">*중복포함</span></th>'
        bfh += f'<th style="{_bths}">납입 (원)</th>'
        bfh += f'<th style="{_bths}">달성율 (%)</th>'
    bfh += '</tr></thead><tbody>'

    for label, m_tgt, m_cnt, m_amt, m_rate, y_tgt, y_cnt, y_amt, y_rate, is_summary in biz_fee_rows:
        is_total = (label == "합계")
        is_sub = is_summary and not is_total
        if is_total:
            rs = "background-color:#222222;color:white;font-weight:bold;"
        elif is_sub:
            rs = "background-color:#d9d9d9;font-weight:bold;"
        else:
            rs = ""
        td = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{rs}"
        tgt_s = f"padding:5px;border:1px solid #ddd;white-space:nowrap;background-color:#808000;color:white;{rs}"
        bfh += '<tr>'
        bfh += f'<td style="{td}text-align:center !important;">{label}</td>'
        bfh += f'<td style="{tgt_s}text-align:center !important;">{m_tgt:,.0f}</td>'
        bfh += f'<td style="{td}text-align:center !important;">{m_cnt:,}</td>'
        _mk_biz = f"m|{label}"
        if _mk_biz in _fee_biz_popup and m_amt > 0:
            bfh += f'<td data-fee-biz-popup="{_mk_biz}" style="{td}text-align:center !important;cursor:pointer;" title="클릭 시 캠페인 상세">{m_amt:,.0f}</td>'
        else:
            bfh += f'<td style="{td}text-align:center !important;">{m_amt:,.0f}</td>'
        bfh += f'<td style="{td}text-align:center !important;">{m_rate:.1f}%</td>'
        bfh += f'<td style="{tgt_s}text-align:center !important;">{y_tgt:,.0f}</td>'
        bfh += f'<td style="{td}text-align:center !important;">{y_cnt:,}</td>'
        _yk_biz = f"y|{label}"
        if _yk_biz in _fee_biz_popup and y_amt > 0:
            bfh += f'<td data-fee-biz-popup="{_yk_biz}" style="{td}text-align:center !important;cursor:pointer;" title="클릭 시 캠페인 상세">{y_amt:,.0f}</td>'
        else:
            bfh += f'<td style="{td}text-align:center !important;">{y_amt:,.0f}</td>'
        bfh += f'<td style="{td}text-align:center !important;">{y_rate:.1f}%</td>'
        bfh += '</tr>'
    bfh += '</tbody></table></div>'
    st.markdown(bfh, unsafe_allow_html=True)

    import json as _json_biz
    _fbp_json = _json_biz.dumps(_fee_biz_popup, ensure_ascii=False)
    stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._feeBizPopupCleanup){{try{{doc._feeBizPopupCleanup()}}catch(e){{}}}};
var D={_fbp_json};
var ov=doc.getElementById('fee-biz-popup-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='fee-biz-popup-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="fee-biz-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:850px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st2=doc.createElement('style');st2.id='fee-biz-popup-style';
var os=doc.getElementById('fee-biz-popup-style');if(os)os.remove();
st2.textContent='@keyframes feebizpop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#fee-biz-popup-box{{animation:feebizpop .2s ease}}td[data-fee-biz-popup]{{cursor:pointer}}td[data-fee-biz-popup]:hover{{background:rgba(21,101,192,0.1) !important}}';
doc.head.appendChild(st2);doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
var box=doc.getElementById('fee-biz-popup-box');
function fmt(v){{return Number(v).toLocaleString()}}
function render(key){{
  var d=D[key];if(!d)return;
  var h='<div style="background:linear-gradient(135deg,#1565C0,#1976D2);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.name+' ('+fmt(d.total)+'원)</span>';
  h+='<div style="display:flex;align-items:center;gap:10px">';
  h+='<button id="fee-biz-dl-btn" style="padding:4px 12px;font-size:11px;border:1px solid #fff;border-radius:4px;background:rgba(255,255,255,0.15);color:#fff;cursor:pointer">엑셀 다운로드</button>';
  h+='<span id="fee-biz-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div></div>';
  h+='<div style="padding:18px 22px">';
  h+='<div style="font-size:13px;font-weight:700;color:#1565C0;margin-bottom:8px;border-bottom:2px solid #1976D2;padding-bottom:5px">공통브랜드 × 마케팅캠페인별 납입 현황 (상위 20)</div>';
  h+='<table style="width:100%;border-collapse:collapse;font-size:11px;margin-bottom:16px"><thead><tr>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;width:28px">순위</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:left;border:1px solid #e0e0e0;width:80px">공통브랜드</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:left;border:1px solid #e0e0e0">마케팅캠페인명</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:right;border:1px solid #e0e0e0;width:90px">납입(원)</th>';
  h+='<th style="background:#f0f2f5;padding:5px 8px;text-align:right;border:1px solid #e0e0e0;width:60px">구성비(%)</th>';
  h+='</tr></thead><tbody>';
  var tc=0;
  for(var i=0;i<d.camps.length;i++){{
    var c=d.camps[i];tc+=c.v;
    var bg=i%2===0?'#fff':'#fafafa';
    h+='<tr style="background:'+bg+'"><td style="padding:4px 8px;text-align:center;border:1px solid #eee">'+(i+1)+'</td>';
    h+='<td style="padding:4px 8px;text-align:left;border:1px solid #eee;color:#666">'+c.b+'</td>';
    h+='<td style="padding:4px 8px;text-align:left;border:1px solid #eee;max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.n+'">'+c.n+'</td>';
    h+='<td style="padding:4px 8px;text-align:right;border:1px solid #eee;font-weight:600">'+fmt(c.v)+'</td>';
    h+='<td style="padding:4px 8px;text-align:right;border:1px solid #eee">'+c.p.toFixed(1)+'%</td></tr>';
  }}
  var tp=d.total>0?(tc/d.total*100):0;
  h+='<tr style="background:#222;color:#fff;font-weight:700"><td style="padding:4px 8px;text-align:center;border:1px solid #555" colspan="3">합계</td>';
  h+='<td style="padding:4px 8px;text-align:right;border:1px solid #555">'+fmt(tc)+'</td>';
  h+='<td style="padding:4px 8px;text-align:right;border:1px solid #555">'+tp.toFixed(1)+'%</td></tr>';
  h+='</tbody></table>';
  h+='<div style="font-size:13px;font-weight:700;color:#1565C0;margin-bottom:8px;border-bottom:2px solid #1976D2;padding-bottom:5px">TOP 10 마케팅캠페인 납입(원)</div>';
  var top10=d.camps.slice(0,10);
  var maxV=top10.length>0?top10[0].v:1;
  for(var j=0;j<top10.length;j++){{
    var c=top10[j];
    var w=Math.max(maxV>0?(c.v/maxV*100):0,2);
    h+='<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">';
    h+='<div style="width:140px;font-size:11px;text-align:right;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#555" title="'+c.n+'">'+c.n+'</div>';
    h+='<div style="flex:1;height:20px;background:#f0f0f0;border-radius:4px;overflow:hidden">';
    h+='<div style="width:'+w.toFixed(1)+'%;height:100%;background:linear-gradient(90deg,#A8D8EA,#88C9BF);border-radius:4px"></div></div>';
    h+='<div style="width:100px;font-size:11px;font-weight:700;color:#333">'+fmt(c.v)+'</div></div>';
  }}
  h+='</div>';
  box.innerHTML=h;box.scrollTop=0;box._currentKey=key;
  doc.getElementById('fee-biz-close-btn').addEventListener('click',function(){{ov.style.display='none'}});
  doc.getElementById('fee-biz-dl-btn').addEventListener('click',function(){{
    var dd=D[box._currentKey];if(!dd)return;
    var rows=[['순위','공통브랜드','마케팅캠페인명','납입(원)','구성비(%)']];
    for(var j=0;j<dd.camps.length;j++){{var c=dd.camps[j];rows.push([j+1,c.b,c.n,c.v,c.p.toFixed(1)+'%']);}};
    var csv='\\uFEFF';rows.forEach(function(r){{csv+=r.map(function(v){{var s=String(v==null?'':v);if(s.indexOf(',')>=0||s.indexOf('"')>=0)return '"'+s.replace(/"/g,'""')+'"';return s}}).join(',')+\"\\n\"}});
    var blob=new Blob([csv],{{type:'text/csv;charset=utf-8'}});var a=document.createElement('a');a.href=URL.createObjectURL(blob);
    a.download=dd.name.replace(/[\\\\/:*?"<>|]/g,'_')+'_상세.csv';a.click();URL.revokeObjectURL(a.href);
  }});
}}
function onClick(e){{
  var td=e.target.closest('td[data-fee-biz-popup]');
  if(td){{var key=td.getAttribute('data-fee-biz-popup');if(D[key]){{render(key);ov.style.display='flex';}}}}
}}
doc.addEventListener('click',onClick);
doc._feeBizPopupCleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('fee-biz-popup-overlay');if(o)o.remove();var s=doc.getElementById('fee-biz-popup-style');if(s)s.remove();}};
}})();
</script>""", height=0)
    st.caption(f"출처: BRONZE_CRM — MSTR_ODS F_PM_SPNSR_BSNS_MBRFEE 로직 재현 (후원사업별, 기준월: {sel_year}-{sel_month:02d}, 법인: I)")

    # ===== 3-2 그래프: 사업별 월별 추이 / 누계 구성비 / 명당 납입액 =====
    _BIZ_GRP_ORDER = ["국내", "해외", "대북", "기타"]
    _BIZ_GRP_COLOR = ["#1565C0", "#2E7D32", "#C62828", "#8D6E63"]

    def _biz_grp(nm):
        if nm == "국내아동권리보호사업":
            return "국내"
        if nm in _OVERSEAS:
            return "해외"
        if nm == "대북지원사업":
            return "대북"
        return "기타"

    def _biz_monthly(yr):
        _d = load_fee_biz_data(yr, sel_month, by_month=True)
        if _d.empty:
            return _d
        _d = _d.copy()
        _d["사업"] = _d["SPNSR_BSNS_ID"].astype(str).map(_BIZ_FEE_ID_MAP).fillna("기타")
        _d["묶음"] = _d["사업"].map(_biz_grp)
        _d["_m"] = _d["PAY_MT"].astype(str).str[-2:].astype(int)
        _d["PAY_AMT"] = _d["PAY_AMT"].astype(float)
        _d["PAY_CNT"] = _d["PAY_CNT"].astype(float)
        return _d

    with st.spinner("후원사업별 그래프 데이터 집계 중..."):
        _bm_cur = _biz_monthly(sel_year)
        _bm_prev = _biz_monthly(sel_year - 1)

    if not _bm_cur.empty:
        _py32, _cy32 = str(sel_year - 1), str(sel_year)
        _mo_sort32 = [f"{m}월" for m in range(1, 13)]
        _ttl32 = "font-weight:800;font-size:16px;color:#1565C0;border-bottom:3px solid #FFB300;padding-bottom:8px;margin-bottom:12px;"

        # ① 사업별 월별 납입액 추이
        _g_cur = _bm_cur.groupby(["_m", "묶음"])["PAY_AMT"].sum()
        _g_prev = _bm_prev.groupby(["_m", "묶음"])["PAY_AMT"].sum() if not _bm_prev.empty else pd.Series(dtype=float)
        _tr_rows = []
        for (_m, _g), _v in _g_cur.items():
            _pv = float(_g_prev.get((_m, _g), 0)) if len(_g_prev) else 0
            _tr_rows.append({
                "월": f"{_m}월", "사업": _g, "납입억": round(_v / 1e8, 2),
                "당월납입": f"{_v:,.0f}원",
                "전년동월": f"{_pv:,.0f}원" if _pv else "-",
                "증감": (f"{_v - _pv:+,.0f}원 ({(_v - _pv) / _pv * 100:+.1f}%)" if _pv else "-"),
            })
        _tr_df = pd.DataFrame(_tr_rows)
        # 범례(국내/해외/대북/기타) 클릭 → 세부사업 월별 추이 팝업
        # 클릭 후 차트 key를 바꿔 선택 상태를 초기화 → 다른 범례가 비활성(흐림) 처리되지 않음
        _tr_key = f"fee_biz_trend_chart_{st.session_state.get('_fee_tr_key_n', 0)}"
        def _open_ovs_popup():
            _sel = (st.session_state.get(_tr_key) or {}).get("selection", {}).get("biz_legend") or []
            for s in _sel:
                if isinstance(s, dict) and s.get("사업") in _BIZ_GRP_ORDER:
                    st.session_state["_fee_ovs_popup"] = s.get("사업")
            st.session_state["_fee_tr_key_n"] = st.session_state.get("_fee_tr_key_n", 0) + 1

        st.markdown(f'<div style="{_ttl32}">▼ {_cy32}년 후원사업별 월별 납입액 추이 (억원)'
                    f'<span style="font-size:12px;font-weight:600;color:#2E7D32;"> — 범례 클릭 시 세부사업 상세</span></div>', unsafe_allow_html=True)
        _biz_legend = alt.selection_point(name="biz_legend", fields=["사업"], bind="legend")
        _tr_chart = alt.Chart(_tr_df).mark_line(
            strokeWidth=3, point=alt.OverlayMarkDef(size=160, filled=True, stroke="white", strokeWidth=1.5)
        ).encode(
            x=alt.X("월:N", sort=_mo_sort32, axis=alt.Axis(labelFontSize=11, labelAngle=0, title="월")),
            y=alt.Y("납입억:Q", axis=alt.Axis(labelFontSize=10, format=",.0f", title="납입액(억원)")),
            color=alt.Color("사업:N", scale=alt.Scale(domain=_BIZ_GRP_ORDER, range=_BIZ_GRP_COLOR),
                            legend=alt.Legend(orient="right", title="후원사업", titleFontSize=11, labelFontSize=11, symbolSize=140)),
            tooltip=[alt.Tooltip("월:N"), alt.Tooltip("사업:N"), alt.Tooltip("당월납입:N", title="당월 납입"),
                     alt.Tooltip("전년동월:N", title=f"{_py32}년 동월"), alt.Tooltip("증감:N", title="전년 동월 대비")],
        ).add_params(_biz_legend)
        # 월별 억원 라벨: 대북·기타는 선이 겹치므로 월마다 큰 값은 위, 작은 값은 아래에 배치
        _lbl_df = _tr_df.copy()
        _lbl_df["_pos"] = "up"
        _pv_db = _lbl_df[_lbl_df["사업"].isin(["대북", "기타"])].pivot_table(index="월", columns="사업", values="납입억", aggfunc="sum")
        for _mo, _r in _pv_db.iterrows():
            _low = "대북" if _r.get("대북", 0) <= _r.get("기타", 0) else "기타"
            _lbl_df.loc[(_lbl_df["월"] == _mo) & (_lbl_df["사업"] == _low), "_pos"] = "down"
        _lbl_base = alt.Chart(_lbl_df).encode(
            x=alt.X("월:N", sort=_mo_sort32),
            y=alt.Y("납입억:Q"),
            text=alt.Text("납입억:Q", format=",.1f"),
            color=alt.Color("사업:N", scale=alt.Scale(domain=_BIZ_GRP_ORDER, range=_BIZ_GRP_COLOR), legend=None),
        )
        _lbl_up = _lbl_base.transform_filter(alt.FieldEqualPredicate(field="_pos", equal="up")).mark_text(
            dy=-13, fontSize=10, fontWeight="bold")
        _lbl_dn = _lbl_base.transform_filter(alt.FieldEqualPredicate(field="_pos", equal="down")).mark_text(
            dy=15, fontSize=10, fontWeight="bold")
        _tr_chart = alt.layer(_tr_chart, _lbl_up, _lbl_dn).properties(width="container", height=340)
        st.altair_chart(_tr_chart, use_container_width=True, key=_tr_key,
                        on_select=_open_ovs_popup, selection_mode="biz_legend")
        st.caption("※ 국내·해외 대비 대북·기타는 금액 규모가 작아 하단에 표시됩니다. 점에 마우스오버 시 전년 동월 대비 증감을 확인할 수 있습니다.")

        _ovs_grp = st.session_state.pop("_fee_ovs_popup", None)
        if _ovs_grp:
            import json as _json_ovs
            _ovs_c = _bm_cur[_bm_cur["묶음"] == _ovs_grp].groupby(["사업", "_m"])["PAY_AMT"].sum()
            _ovs_p = (_bm_prev[_bm_prev["묶음"] == _ovs_grp].groupby(["사업", "_m"])["PAY_AMT"].sum()
                      if not _bm_prev.empty else pd.Series(dtype=float))
            if _ovs_grp == "해외":
                _ovs_names = _OVERSEAS
            else:
                # 국내/대북/기타: 실제 데이터에 있는 세부사업 (누계 납입액 큰 순)
                _ovs_names = list(_bm_cur[_bm_cur["묶음"] == _ovs_grp].groupby("사업")["PAY_AMT"].sum()
                                  .sort_values(ascending=False).index)
            _ovs_colors = {
                "국내": ["#1565C0", "#42A5F5", "#0D47A1", "#64B5F6"],
                "해외": ["#1B5E20", "#43A047", "#00897B", "#7CB342", "#26A69A", "#558B2F", "#9E9D24"],
                "대북": ["#C62828", "#EF5350", "#8E0000", "#E57373"],
                "기타": ["#5D4037", "#8D6E63", "#A1887F", "#6D4C41", "#BCAAA4", "#795548", "#4E342E"],
            }.get(_ovs_grp, ["#546E7A"])
            _ovs_series = []
            for _nm in _ovs_names:
                _cur = [float(_ovs_c.get((_nm, _m), 0)) for _m in range(1, sel_month + 1)]
                _prv = [float(_ovs_p.get((_nm, _m), 0)) if len(_ovs_p) else 0.0 for _m in range(1, sel_month + 1)]
                _ovs_series.append({"n": _nm, "cur": _cur, "prev": _prv})
            _ovs_payload = _json_ovs.dumps({"cy": _cy32, "py": _py32, "months": sel_month, "grp": _ovs_grp,
                                            "colors": _ovs_colors,
                                            "s": _ovs_series}, ensure_ascii=False)
            stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._ovsPopupCleanup){{try{{doc._ovsPopupCleanup()}}catch(e){{}}}};
var D={_ovs_payload};
var ov=doc.createElement('div');ov.id='ovs-popup-overlay';
ov.style.cssText='display:flex;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="ovs-popup-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:960px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st2=doc.createElement('style');st2.id='ovs-popup-style';
st2.textContent='@keyframes ovspop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#ovs-popup-box{{animation:ovspop .2s ease}}';
doc.head.appendChild(st2);doc.body.appendChild(ov);
function close(){{doc._ovsPopupCleanup()}}
ov.addEventListener('click',function(e){{if(e.target===ov)close()}});
var box=doc.getElementById('ovs-popup-box');
function fmt(v){{return Math.round(v).toLocaleString()}}
function eok(v){{return (v/1e8).toFixed(2)}}
var M=D.months, S=D.s, C=D.colors;
var tot=0;S.forEach(function(x){{x.yc=x.cur.reduce(function(a,b){{return a+b}},0);x.yp=x.prev.reduce(function(a,b){{return a+b}},0);tot+=x.yc}});
// SVG 라인차트
var W=900,H=340,L=60,R=170,T=20,B=40,pw=W-L-R,ph=H-T-B,mx=0;
S.forEach(function(x){{x.cur.forEach(function(v){{if(v>mx)mx=v}})}});mx=mx>0?mx*1.1:1;
function xp(i){{return L+(M>1?i*pw/(M-1):pw/2)}}function yp(v){{return T+ph-v/mx*ph}}
var g='<svg viewBox="0 0 '+W+' '+H+'" style="width:100%;height:auto;font-family:inherit">';
for(var k=0;k<=5;k++){{var yv=mx*k/5,yy=yp(yv);g+='<line x1="'+L+'" x2="'+(L+pw)+'" y1="'+yy+'" y2="'+yy+'" stroke="#eceff1"/>';g+='<text x="'+(L-8)+'" y="'+(yy+4)+'" font-size="10" text-anchor="end" fill="#78909C">'+(yv/1e8).toFixed(1)+'</text>';}}
for(var i=0;i<M;i++)g+='<text x="'+xp(i)+'" y="'+(H-B+18)+'" font-size="11" text-anchor="middle" fill="#455A64">'+(i+1)+'월</text>';
g+='<text x="14" y="'+(T+ph/2)+'" font-size="11" fill="#455A64" transform="rotate(-90 14 '+(T+ph/2)+')" text-anchor="middle">납입액(억원)</text>';
S.forEach(function(x,si){{
  var col=C[si%C.length],pts=x.cur.map(function(v,i){{return xp(i)+','+yp(v)}}).join(' ');
  g+='<polyline points="'+pts+'" fill="none" stroke="'+col+'" stroke-width="2.5"/>';
  x.cur.forEach(function(v,i){{var pv=x.prev[i],dd=pv?((v-pv)/pv*100).toFixed(1)+'%':'-';
    g+='<circle cx="'+xp(i)+'" cy="'+yp(v)+'" r="5" fill="'+col+'" stroke="#fff" stroke-width="1.5"><title>'+x.n+' '+(i+1)+'월\\n당월 납입: '+fmt(v)+'원\\n'+D.py+'년 동월: '+(pv?fmt(pv)+'원':'-')+'\\n전년 동월 대비: '+dd+'</title></circle>';}});
  var ly=T+10+si*22;g+='<circle cx="'+(L+pw+22)+'" cy="'+ly+'" r="6" fill="'+col+'"/><text x="'+(L+pw+34)+'" y="'+(ly+4)+'" font-size="11" fill="#263238">'+x.n+'</text>';
}});
// 월별 억원 라벨 (같은 월 라벨끼리 겹치지 않도록 세로 간격 자동 조정)
for(var mi=0;mi<M;mi++){{
  var lb=[];S.forEach(function(x,si){{var v=x.cur[mi];if(v>0)lb.push({{y:yp(v)-9,t:(v/1e8).toFixed(1),c:C[si%C.length]}})}});
  lb.sort(function(p,q){{return p.y-q.y}});
  for(var li=1;li<lb.length;li++){{if(lb[li].y<lb[li-1].y+11)lb[li].y=lb[li-1].y+11}}
  lb.forEach(function(o){{g+='<text x="'+(xp(mi)+(M>1&&mi===M-1?-4:0))+'" y="'+o.y+'" font-size="10" font-weight="700" text-anchor="'+(M>1&&mi===M-1?'end':'middle')+'" fill="'+o.c+'" stroke="#fff" stroke-width="3" paint-order="stroke">'+o.t+'</text>'}});
}}
g+='</svg>';
var th='background:#f0f2f5;padding:5px 8px;border:1px solid #e0e0e0;text-align:right;white-space:nowrap';
var td='padding:4px 8px;border:1px solid #eee;text-align:right;white-space:nowrap';
var h='<div style="background:linear-gradient(135deg,#1565C0,#1976D2);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
h+='<span style="font-size:15px;font-weight:700">'+D.grp+'사업 '+S.length+'개 세부사업별 월별 납입액 추이 ('+D.cy+'년 1~'+M+'월 누계 '+fmt(tot)+'원)</span>';
h+='<div style="display:flex;align-items:center;gap:10px">';
h+='<button id="ovs-dl-btn" style="padding:4px 12px;font-size:11px;border:1px solid #fff;border-radius:4px;background:rgba(255,255,255,0.15);color:#fff;cursor:pointer">엑셀 다운로드</button>';
h+='<span id="ovs-close-btn" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div></div>';
h+='<div style="padding:18px 22px">';
h+='<div style="font-size:13px;font-weight:700;color:#1565C0;margin-bottom:8px;border-bottom:2px solid #1976D2;padding-bottom:5px">사업별 월별 납입액 추이 (억원)</div>'+g;
h+='<div style="font-size:13px;font-weight:700;color:#1565C0;margin:14px 0 8px;border-bottom:2px solid #1976D2;padding-bottom:5px">사업별 월별 납입액 (억원)</div>';
h+='<table style="width:100%;border-collapse:collapse;font-size:11px"><thead><tr><th style="'+th+';text-align:left">사업</th>';
for(var i=1;i<=M;i++)h+='<th style="'+th+'">'+i+'월</th>';
h+='<th style="'+th+'">누계</th><th style="'+th+'">구성비</th><th style="'+th+'">전년 누계</th><th style="'+th+'">증감률</th></tr></thead><tbody>';
var mt=new Array(M).fill(0),pt=0;
S.forEach(function(x,si){{var bg=si%2===0?'#fff':'#fafafa';
  h+='<tr style="background:'+bg+'"><td style="'+td+';text-align:left"><span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:'+C[si%C.length]+';margin-right:6px"></span>'+x.n+'</td>';
  x.cur.forEach(function(v,i){{mt[i]+=v;h+='<td style="'+td+'">'+eok(v)+'</td>'}});pt+=x.yp;
  h+='<td style="'+td+';font-weight:700">'+eok(x.yc)+'</td><td style="'+td+'">'+(tot?(x.yc/tot*100).toFixed(1):'0.0')+'%</td>';
  h+='<td style="'+td+'">'+eok(x.yp)+'</td><td style="'+td+'">'+(x.yp?((x.yc-x.yp)/x.yp*100).toFixed(1)+'%':'-')+'</td></tr>';}});
h+='<tr style="background:#222;color:#fff;font-weight:700"><td style="padding:4px 8px;border:1px solid #555">합계</td>';
mt.forEach(function(v){{h+='<td style="padding:4px 8px;border:1px solid #555;text-align:right">'+eok(v)+'</td>'}});
h+='<td style="padding:4px 8px;border:1px solid #555;text-align:right">'+eok(tot)+'</td><td style="padding:4px 8px;border:1px solid #555;text-align:right">100.0%</td>';
h+='<td style="padding:4px 8px;border:1px solid #555;text-align:right">'+eok(pt)+'</td><td style="padding:4px 8px;border:1px solid #555;text-align:right">'+(pt?((tot-pt)/pt*100).toFixed(1)+'%':'-')+'</td></tr>';
h+='</tbody></table></div>';
box.innerHTML=h;
doc.getElementById('ovs-close-btn').addEventListener('click',close);
doc.getElementById('ovs-dl-btn').addEventListener('click',function(){{
  var hd=['사업'];for(var i=1;i<=M;i++)hd.push(i+'월(원)');hd.push('누계(원)','전년 누계(원)');
  var rows=[hd];S.forEach(function(x){{rows.push([x.n].concat(x.cur.map(Math.round),[Math.round(x.yc),Math.round(x.yp)]))}});
  var csv='\\uFEFF';rows.forEach(function(r){{csv+=r.join(',')+"\\n"}});
  var blob=new Blob([csv],{{type:'text/csv;charset=utf-8'}});var a=document.createElement('a');a.href=URL.createObjectURL(blob);
  a.download=D.grp+'사업_월별납입액_'+D.cy+'.csv';a.click();URL.revokeObjectURL(a.href);
}});
doc._ovsPopupCleanup=function(){{var o=doc.getElementById('ovs-popup-overlay');if(o)o.remove();var s=doc.getElementById('ovs-popup-style');if(s)s.remove();doc._ovsPopupCleanup=null;}};
}})();
</script>""", height=0)
        st.markdown('<div style="height:20px"></div>', unsafe_allow_html=True)

        _c32a, _c32b = st.columns([1, 1], gap="medium")

        # ② 누계 회비 구성비 (전년 vs 당해, 1~조회월)
        with _c32a:
            _sh_rows = []
            _sh_prev = {}
            for _yr_s, _bd in [(_py32, _bm_prev), (_cy32, _bm_cur)]:
                if _bd.empty:
                    continue
                _gs = _bd.groupby("묶음")["PAY_AMT"].sum()
                _tot = float(_gs.sum())
                for _g in _BIZ_GRP_ORDER:
                    _v = float(_gs.get(_g, 0))
                    _p = _v / _tot * 100 if _tot else 0
                    if _yr_s == _py32:
                        _sh_prev[_g] = _p
                    _chg = (f"{_p - _sh_prev[_g]:+.1f}%p" if (_yr_s == _cy32 and _g in _sh_prev) else "-")
                    _sh_rows.append({"연도": f"{_yr_s}년", "사업": _g, "비중": round(_p, 1), "라벨": f"{_p:.1f}%" if _p >= 4 else "",
                                     "누계납입": f"{_v:,.0f}원", "증감": _chg, "_o": _BIZ_GRP_ORDER.index(_g)})
            _sh_df = pd.DataFrame(_sh_rows)
            st.markdown(f'<div style="{_ttl32}">▼ 후원사업별 누계 회비 구성비 (1~{sel_month}월)</div>', unsafe_allow_html=True)
            _yr_sort = [f"{_py32}년", f"{_cy32}년"]
            _sh_bar = alt.Chart(_sh_df).mark_bar(size=46).encode(
                y=alt.Y("연도:N", sort=_yr_sort, axis=alt.Axis(labelFontSize=13, title=None)),
                x=alt.X("비중:Q", stack="normalize", axis=alt.Axis(format="%", title=None, labelFontSize=10)),
                color=alt.Color("사업:N", scale=alt.Scale(domain=_BIZ_GRP_ORDER, range=_BIZ_GRP_COLOR),
                                legend=alt.Legend(orient="bottom", title=None, labelFontSize=11, symbolSize=140)),
                order=alt.Order("_o:Q"),
                tooltip=[alt.Tooltip("연도:N"), alt.Tooltip("사업:N"), alt.Tooltip("누계납입:N", title="누계 납입"),
                         alt.Tooltip("비중:Q", format=".1f", title="비중(%)"), alt.Tooltip("증감:N", title="전년 대비")],
            )
            _sh_txt = alt.Chart(_sh_df).mark_text(color="white", fontSize=13, fontWeight="bold").encode(
                y=alt.Y("연도:N", sort=_yr_sort),
                x=alt.X("비중:Q", stack="normalize", bandPosition=0.5),
                detail="사업:N", order=alt.Order("_o:Q"), text="라벨:N",
            )
            st.altair_chart((_sh_bar + _sh_txt).properties(height=230), use_container_width=True)

        # ③ 사업별 명당 납입액 (누계)
        with _c32b:
            _pp_names = ["국내아동권리보호사업"] + _OVERSEAS + ["대북지원사업"] + _ETC_DISPLAY
            _pp_prev = {}
            if not _bm_prev.empty:
                _ga = _bm_prev.groupby("사업")[["PAY_AMT", "PAY_CNT"]].sum()
                _pp_prev = {n: (float(_ga.loc[n, "PAY_AMT"]) / float(_ga.loc[n, "PAY_CNT"])) for n in _ga.index if float(_ga.loc[n, "PAY_CNT"]) > 0}
            _pp_rows = []
            for _n in _pp_names:
                _d = _bf(_n)
                if _d["y_cnt"] <= 0:
                    continue
                _yv = _d["y_amt"] / _d["y_cnt"]
                _mv = _d["m_amt"] / _d["m_cnt"] if _d["m_cnt"] else 0
                _pv = _pp_prev.get(_n)
                _pp_rows.append({"사업": _n, "누계명당": round(_yv), "라벨": f"{_yv:,.0f}원",
                                 "당월명당": f"{_mv:,.0f}원", "전년명당": round(_pv) if _pv else None,
                                 "전년명당_t": f"{_pv:,.0f}원" if _pv else "-",
                                 "증감": f"{(_yv - _pv) / _pv * 100:+.1f}%" if _pv else "-",
                                 "묶음": _biz_grp(_n)})
            _pp_df = pd.DataFrame(_pp_rows)
            st.markdown(f'<div style="{_ttl32}">▼ 후원사업별 명당 납입액 (누계, 원)</div>', unsafe_allow_html=True)
            if not _pp_df.empty:
                _pp_sort = list(_pp_df["사업"])
                _pp_tt = [alt.Tooltip("사업:N"), alt.Tooltip("당월명당:N", title="당월 명당"), alt.Tooltip("라벨:N", title="누계 명당"),
                          alt.Tooltip("전년명당_t:N", title=f"{_py32}년 동기 명당"), alt.Tooltip("증감:N", title="전년 대비")]
                _pp_y = alt.Y("사업:N", sort=_pp_sort, axis=alt.Axis(labelFontSize=11, title=None, labelLimit=160))
                _pp_bar = alt.Chart(_pp_df).mark_bar(size=18, cornerRadiusTopRight=3, cornerRadiusBottomRight=3).encode(
                    y=_pp_y, x=alt.X("누계명당:Q", axis=alt.Axis(format=",.0f", title=None, labelFontSize=10)),
                    color=alt.Color("묶음:N", scale=alt.Scale(domain=_BIZ_GRP_ORDER, range=_BIZ_GRP_COLOR), legend=None),
                    tooltip=_pp_tt)
                _pp_txt = alt.Chart(_pp_df).mark_text(align="left", dx=6, fontSize=12, fontWeight="bold", color="#263238").encode(
                    y=_pp_y, x="누계명당:Q", text="라벨:N")
                _pp_layers = [_pp_bar, _pp_txt]
                if _pp_df["전년명당"].notna().any():
                    _pp_layers.append(alt.Chart(_pp_df[_pp_df["전년명당"].notna()]).mark_point(
                        shape="diamond", size=110, filled=True, color="#757575").encode(
                        y=_pp_y, x="전년명당:Q", tooltip=_pp_tt))
                st.altair_chart(alt.layer(*_pp_layers).properties(height=max(230, 26 * len(_pp_df))), use_container_width=True)
                st.caption(f"◆ 회색 마커: {_py32}년 동기(1~{sel_month}월) 명당 납입액 | 명당 = 누계 납입(원) ÷ 누계 납입(명). 납입(명)은 월별 합산이므로 '회원 1명의 월평균 납입액'에 해당")

        st.markdown('<div style="height:24px"></div>', unsafe_allow_html=True)

    # ===== 3-3. 회원구분(신규/기존)별 납입율 =====
    st.divider()
    st.subheader("3-3. 회원구분(신규/기존)별 납입율")

    # 활동회원(건) — 간이 쿼리 (신규/기존 × 본부/지부)

    with st.spinner("납입율 계산 중..."):
        # 당월 활동회원(건)
        _af_cur = _load_active_for_fee(sel_year, sel_month)
        _act_map = {}
        if not _af_cur.empty:
            for _, _r in _af_cur.iterrows():
                _act_map[(_r["NEW_OLD"], _r["HQ_DIV"])] = float(_r["ACT_CASES"])
        _act_new_hq = _act_map.get(("신규회원", "본부"), 0)
        _act_new_br = _act_map.get(("신규회원", "시도본부 및 지부"), 0)
        _act_new_sub = _act_new_hq + _act_new_br
        _act_old = _act_map.get(("기존회원", "본부"), 0) + _act_map.get(("기존회원", "시도본부 및 지부"), 0)
        _act_total = _act_new_sub + _act_old

        # 누계 활동회원(건) = 1~조회월 합산
        _ytd_new_hq, _ytd_new_br, _ytd_old = 0, 0, 0
        for _rm in range(1, sel_month + 1):
            _af_m = _load_active_for_fee(sel_year, _rm)
            if not _af_m.empty:
                for _, _r in _af_m.iterrows():
                    if _r["NEW_OLD"] == "신규회원" and _r["HQ_DIV"] == "본부":
                        _ytd_new_hq += float(_r["ACT_CASES"])
                    elif _r["NEW_OLD"] == "신규회원":
                        _ytd_new_br += float(_r["ACT_CASES"])
                    else:
                        _ytd_old += float(_r["ACT_CASES"])
        _ytd_new_sub = _ytd_new_hq + _ytd_new_br
        _ytd_total = _ytd_new_sub + _ytd_old

    if _act_total > 0:
        # 납입 데이터 — fee_rows에서 추출
        _fee_new_hq_m = fee_rows[0]["m_pay"]
        _fee_new_br_m = fee_rows[1]["m_pay"]
        _fee_new_sub_m = fee_rows[2]["m_pay"]
        _fee_old_m = fee_rows[3]["m_pay"]
        _fee_total_m = fee_rows[4]["m_pay"]
        _fee_new_hq_y = fee_rows[0]["y_pay"]
        _fee_new_br_y = fee_rows[1]["y_pay"]
        _fee_new_sub_y = fee_rows[2]["y_pay"]
        _fee_old_y = fee_rows[3]["y_pay"]
        _fee_total_y = fee_rows[4]["y_pay"]

        def _pay_rate(pay, act):
            return round(pay / (act * 10000) * 100, 1) if act > 0 else 0.0

        # 목표(납입율): 연목표 원천 (연사업/사단, 당월=신규기존납입율, 누계=신규기존누계납입율)

        _prg_df = _load_pay_rate_goal(sel_year)
        _prg_col = f"M{sel_month:02d}"

        def _prg(goal_type, new_old, org_div):
            if _prg_df.empty:
                return None
            _mask = (_prg_df["GOAL_TYPE_NM"] == goal_type) & (_prg_df["NEW_OLD_DIV_NM"] == new_old)
            _mask &= _prg_df["ORG_DIV_NM"].isna() if org_div is None else (_prg_df["ORG_DIV_NM"] == org_div)
            _rows = _prg_df[_mask]
            if _rows.empty or pd.isna(_rows[_prg_col].values[0]):
                return None
            return float(_rows[_prg_col].values[0]) * 100

        # 표 행 순서: 신규 본부 / 신규 지부 / 신규합계 / 기존 / 합계
        _PRG_KEYS = [("신규", "본부"), ("신규", "지부"), ("신규합계", None), ("기존", None), ("합계", None)]
        _goal_m = [_prg("신규기존납입율", _k, _o) for _k, _o in _PRG_KEYS]
        _goal_y = [_prg("신규기존누계납입율", _k, _o) for _k, _o in _PRG_KEYS]

        def _ach(rate, goal):
            # 목표대비 달성률 = 실적 납입율 / 목표 납입율 × 100
            return "-" if not goal else f"{rate / goal * 100:.1f}%"

        # 표 렌더링
        _nr_th = "background-color:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px;"
        _nr_ths = "background-color:#4a4a4a;color:white;padding:5px 4px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:11px;"
        _nrh = '<div id="fee-rate-table"><style>#fee-rate-table td { text-align:center !important; }</style>'
        _nrh += '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
        _nrh += '<thead><tr>'
        _nrh += f'<th colspan="2" rowspan="2" style="{_nr_th}">구분</th>'
        _nrh += f'<th colspan="5" style="{_nr_th}">당월</th>'
        _nrh += f'<th colspan="5" style="{_nr_th}">누계</th>'
        _nrh += '</tr><tr>'
        for _ in range(2):
            _nrh += f'<th style="{_nr_ths}">목표(납입율)</th>'
            _nrh += f'<th style="{_nr_ths}">활동회원(건)</th>'
            _nrh += f'<th style="{_nr_ths}">납입(원)</th>'
            _nrh += f'<th style="{_nr_ths}">납입율(%)</th>'
            _nrh += f'<th style="{_nr_ths}">목표대비 달성률(%)</th>'
        _nrh += '</tr></thead><tbody>'

        _nr_rows = [
            ("신규회원", "본부", _act_new_hq, _fee_new_hq_m, _ytd_new_hq, _fee_new_hq_y),
            ("", "시도본부, 지부 등", _act_new_br, _fee_new_br_m, _ytd_new_br, _fee_new_br_y),
            ("", "소계", _act_new_sub, _fee_new_sub_m, _ytd_new_sub, _fee_new_sub_y),
            ("기존회원", "기존회원", _act_old, _fee_old_m, _ytd_old, _fee_old_y),
            ("합계", "", _act_total, _fee_total_m, _ytd_total, _fee_total_y),
        ]
        for _i, (_c1, _c2, _m_act, _m_pay, _y_act, _y_pay) in enumerate(_nr_rows):
            _is_total = _c1 == "합계"
            _is_sub = _c2 == "소계"
            if _is_total:
                _rs = "background-color:#222222;color:white;font-weight:bold;"
            elif _is_sub:
                _rs = "background-color:#d9d9d9;font-weight:bold;"
            else:
                _rs = ""
            _td = f"padding:5px;border:1px solid #ddd;white-space:nowrap;{_rs}"
            _nrh += '<tr>'
            if _i == 0:
                _nrh += f'<td rowspan="3" style="{_td}text-align:center !important;">신규회원</td>'
            elif _i == 3:
                _nrh += f'<td style="{_td}text-align:center !important;">기존회원</td>'
            elif _i == 4:
                _nrh += f'<td style="{_td}text-align:center !important;font-weight:bold;">합계</td>'
            if _i < 3:
                _nrh += f'<td style="{_td}text-align:center !important;">{_c2}</td>'
            else:
                _nrh += f'<td style="{_td}text-align:center !important;"></td>'
            _gm = _goal_m[_i]
            _nrh += f'<td style="{_td}">{"-" if _gm is None else f"{_gm:.1f}%"}</td>'
            _nrh += f'<td style="{_td}">{_m_act:,.1f}</td>'
            _nrh += f'<td style="{_td}">{_m_pay:,.0f}</td>'
            # 납입율(%) 칸: 1-1표 목표(건)과 동일한 올리브그린 강조 (소계/합계 행은 기존 행 색 유지)
            _olive = "" if (_is_total or _is_sub) else "background-color:#808000;color:white;font-weight:600;"
            _nrh += f'<td style="{_td}{_olive}">{_pay_rate(_m_pay, _m_act):.1f}%</td>'
            _nrh += f'<td style="{_td}">{_ach(_pay_rate(_m_pay, _m_act), _gm)}</td>'
            _gy = _goal_y[_i]
            _nrh += f'<td style="{_td}">{"-" if _gy is None else f"{_gy:.1f}%"}</td>'
            _nrh += f'<td style="{_td}">{_y_act:,.1f}</td>'
            _nrh += f'<td style="{_td}">{_y_pay:,.0f}</td>'
            _nrh += f'<td style="{_td}{_olive}">{_pay_rate(_y_pay, _y_act):.1f}%</td>'
            _nrh += f'<td style="{_td}">{_ach(_pay_rate(_y_pay, _y_act), _gy)}</td>'
            _nrh += '</tr>'
        _nrh += '</tbody></table></div>'

        # ── 한 줄 요약 (표 위) ──
        _nr_labels = ["신규회원 본부", "신규회원 지부", "신규회원 소계", "기존회원", "합계"]
        _nr_m_rates = [_pay_rate(r[3], r[2]) for r in _nr_rows]
        _nr_y_rates = [_pay_rate(r[5], r[4]) for r in _nr_rows]

        def _prev_month_rate(_yr, _m):
            # 전년 동월 전체 납입율 (하단 '월별 납입율 비교' 그래프와 동일 기준)
            _f = _load_fee_month(_yr, _m)
            _a = _load_active_for_fee(_yr, _m)
            if _f.empty or _a.empty:
                return None
            _act_s = float(_a["ACT_CASES"].sum())
            return float(_f["PAY_AMT"].sum()) / (_act_s * 10000) * 100 if _act_s > 0 else None

        _sm_rate, _sm_goal = _nr_m_rates[4], _goal_m[4]
        _sm_detail = ""
        _sm_parts = [f"당월 전체 납입율 <b>{_sm_rate:.1f}%</b>"]
        if _sm_goal:
            _sm_parts[0] += f" (목표 {_sm_goal:.1f}%, 달성률 <b>{_sm_rate / _sm_goal * 100:.1f}%</b>)"
        _sm_prev = _prev_month_rate(sel_year - 1, sel_month)
        if _sm_prev is not None:
            _sm_d = _sm_rate - _sm_prev
            _sm_parts.append(f"전년 동월 대비 <b>{abs(_sm_d):.1f}%p {'상승' if _sm_d >= 0 else '하락'}</b>")
        # 목표 미달 주요 원인: 세부 행(신규 본부/지부, 기존) 중 목표 대비 차이가 가장 큰 구분
        _sm_gaps = [(_nr_labels[i], _nr_m_rates[i] - _goal_m[i]) for i in (0, 1, 3) if _goal_m[i]]
        _sm_neg = [g for g in _sm_gaps if g[1] < 0]
        if _sm_neg:
            _sm_w = min(_sm_neg, key=lambda g: g[1])
            _sm_parts.append(f"목표 미달 주요 원인은 <b>{_sm_w[0]} ({_sm_w[1]:+.1f}%p)</b>")
            # 세부 원인: 활동회원 목표(2-1 월말활동회원) · 납입 목표(3-1표) 대비 실적 비교
            _sw_i = _nr_labels.index(_sm_w[0])
            _sw_key = {"신규회원 본부": ("신규", "본부"), "신규회원 지부": ("신규", "지부"), "기존회원": ("기존", None)}[_sm_w[0]]
            _sw_ag = _load_active_target(sel_year)
            _sw_col = f"R{sel_month:02d}"
            if not _sw_ag.empty and _sw_col in _sw_ag.columns:
                _sw_mask = _sw_ag["NEW_OLD_DIV_NM"] == _sw_key[0]
                _sw_mask &= _sw_ag["ORG_DIV_NM"].isna() if _sw_key[1] is None else (_sw_ag["ORG_DIV_NM"] == _sw_key[1])
                _sw_at = float(_sw_ag[_sw_mask][_sw_col].astype(float).sum())
            else:
                _sw_at = 0.0
            _sw_pt = float(fee_rows[_sw_i]["m_tgt"])
            _sw_a1, _sw_p1 = _nr_rows[_sw_i][2], _nr_rows[_sw_i][3]
            if _sw_at > 0 and _sw_pt > 0 and _sw_a1 > 0 and _sw_p1 > 0:
                # 쉬운 설명: 회원 수(목표 대비) / 걷힌 돈(목표 대비) / 목표 납입율까지 부족한 금액
                _sw_ad = _sw_a1 - _sw_at
                _sw_pd = _sw_p1 - _sw_pt
                _sw_act_txt = (f"활동회원은 목표보다 <b>{abs(_sw_ad):,.0f}건 {'많았고' if _sw_ad >= 0 else '적었고'}</b>"
                               f"({_sw_a1 / _sw_at * 100:.0f}% 달성)")
                _sw_pay_txt = (f"납입은 목표보다 <b>{_eok(abs(_sw_pd))} {'많이' if _sw_pd >= 0 else '적게'} 걷혔습니다</b>"
                               f"({_sw_p1 / _sw_pt * 100:.0f}% 달성)")
                if _sw_ad >= 0 and _sw_pd < 0:
                    _sw_why = "회원은 늘었는데 돈은 덜 걷혔습니다 → <b>미납·출금실패 점검 필요</b>"
                elif _sw_ad >= 0:
                    _sw_why = "돈도 더 걷혔지만 회원이 늘어난 만큼은 따라오지 못했습니다 → <b>미납·출금실패 점검 필요</b>"
                elif _sw_pd < 0:
                    _sw_why = "회원도 돈도 목표에 못 미쳤습니다 → <b>회원 이탈·납입중단 점검 필요</b>"
                else:
                    _sw_why = "회원 1명당 납입이 목표 기준보다 적습니다 → <b>소액·감액 약정 점검 필요</b>"
                # 이번 달 활동회원 기준으로 목표 납입율을 맞추려면 더 걷혔어야 할 금액
                _sw_goal_rate = _goal_m[_sw_i]
                _sw_need = (_sw_goal_rate / 100 * _sw_a1 * 10000 - _sw_p1) if _sw_goal_rate else 0
                _sw_need_txt = (f" 목표 납입율({_sw_goal_rate:.1f}%)을 맞추려면 약 <b>{_eok(_sw_need)}</b>이 더 걷혔어야 합니다."
                                if _sw_need > 0 else "")
                _sm_detail = (f"🔎 <b>{_sm_w[0]}</b>: {_sw_act_txt}, {_sw_pay_txt}. {_sw_why}.{_sw_need_txt}")
        elif _sm_gaps:
            _sm_parts.append("<b>모든 회원구분 목표 달성</b>")
        _sy_rate, _sy_goal = _nr_y_rates[4], _goal_y[4]
        _sm_ytd = f"누계 납입율 <b>{_sy_rate:.1f}%</b>" + (f" (목표 대비 <b>{_sy_rate / _sy_goal * 100:.1f}%</b>)" if _sy_goal else "")
        _sm_ok = (not _sm_goal) or _sm_rate >= _sm_goal
        _sm_bd = "#2E7D32" if _sm_ok else "#C62828"
        st.markdown(
            f'<div style="background:linear-gradient(160deg,#ffffff 0%,#eef4fb 100%);border-left:6px solid {_sm_bd};'
            f'border-radius:10px;padding:12px 18px;margin:4px 0 12px 0;box-shadow:0 3px 10px rgba(21,101,192,0.12);'
            f'font-size:15px;color:#263238;line-height:1.6;">'
            f'<span style="font-weight:900;color:#0D47A1;margin-right:8px;">📌 요약</span>'
            f'{", ".join(_sm_parts)}. <span style="color:#546E7A;">| {_sm_ytd}</span>'
            + (f'<div style="margin-top:6px;padding-top:6px;border-top:1px dashed #CFD8DC;font-size:14px;color:#37474F;">{_sm_detail}</div>' if _sm_detail else '')
            + '</div>',
            unsafe_allow_html=True)

        st.markdown(_nrh, unsafe_allow_html=True)

        # ── 목표 대비 달성 막대그래프 (당월 / 누계) ──
        def _ach_status(rate, goal):
            if not goal:
                return "목표없음"
            _r = rate / goal * 100
            return "달성(100%↑)" if _r >= 100 else ("근접(90~100%)" if _r >= 90 else "미달(90%↓)")

        def _bullet_df(rates, goals):
            return pd.DataFrame([{
                "구분": _nr_labels[i], "_o": i, "납입율": round(rates[i], 1),
                "목표": round(goals[i], 1) if goals[i] else None,
                "달성률": f"{rates[i] / goals[i] * 100:.1f}%" if goals[i] else "-",
                "라벨": f"{rates[i]:.1f}%" + (f" (달성 {rates[i] / goals[i] * 100:.0f}%)" if goals[i] else ""),
                "상태": _ach_status(rates[i], goals[i]),
            } for i in range(5)])

        _st_dom = ["달성(100%↑)", "근접(90~100%)", "미달(90%↓)", "목표없음"]
        _st_rng = ["#2E7D32", "#FFB300", "#C62828", "#90A4AE"]

        def _bullet_chart(df):
            _xmax = max([v for v in list(df["납입율"]) + list(df["목표"].dropna())] + [1]) * 1.28
            _y = alt.Y("구분:N", sort=_nr_labels, axis=alt.Axis(title=None, labelFontSize=12, labelFontWeight="bold"))
            _x = alt.X("납입율:Q", scale=alt.Scale(domain=[0, _xmax]), axis=alt.Axis(title="납입율(%)", format=".0f", labelFontSize=10))
            _tt = [alt.Tooltip("구분:N"), alt.Tooltip("납입율:Q", format=".1f", title="납입율(%)"),
                   alt.Tooltip("목표:Q", format=".1f", title="목표(%)"), alt.Tooltip("달성률:N", title="목표대비 달성률")]
            _bar = alt.Chart(df).mark_bar(height=22, cornerRadiusEnd=4).encode(
                y=_y, x=_x,
                color=alt.Color("상태:N", scale=alt.Scale(domain=_st_dom, range=_st_rng),
                                legend=alt.Legend(orient="bottom", title=None, labelFontSize=11)),
                tooltip=_tt)
            _goal = alt.Chart(df.dropna(subset=["목표"])).mark_tick(color="#212121", thickness=3, size=34).encode(
                y=_y, x=alt.X("목표:Q"), tooltip=_tt)
            _txt = alt.Chart(df).mark_text(align="left", dx=6, fontSize=12, fontWeight="bold", color="#263238").encode(
                y=_y, x=alt.X("납입율:Q"), text="라벨:N")
            return alt.layer(_bar, _goal, _txt).properties(width="container", height=230)

        st.markdown('<div style="height:16px"></div>', unsafe_allow_html=True)
        _bc1, _bc2 = st.columns(2, gap="medium")
        _bttl = "font-weight:800;font-size:15px;color:#1565C0;border-bottom:3px solid #FFB300;padding-bottom:6px;margin-bottom:8px;"
        with _bc1:
            st.markdown(f'<div style="{_bttl}">▼ 당월 납입율 목표 대비 달성 현황</div>', unsafe_allow_html=True)
            st.altair_chart(_bullet_chart(_bullet_df(_nr_m_rates, _goal_m)), use_container_width=True)
        with _bc2:
            st.markdown(f'<div style="{_bttl}">▼ 누계 납입율 목표 대비 달성 현황</div>', unsafe_allow_html=True)
            st.altair_chart(_bullet_chart(_bullet_df(_nr_y_rates, _goal_y)), use_container_width=True)
        st.caption("막대 = 실제 납입율, 검은 세로선 = 목표 납입율 | 색상: 초록 목표 100% 이상 · 주황 90~100% · 빨강 90% 미만")
        st.caption(f"납입율 = 납입(원) / (활동회원(건) × 10,000) × 100 | 활동회원(건): 2-1표, 납입(원): 3-1표 기준 | 목표대비 달성률 = 납입율 / 목표(납입율) × 100 | 목표(납입율): {sel_year}년 연목표(연사업·사단) {sel_month}월 — 당월 '신규기존납입율', 누계 '신규기존누계납입율'")
    else:
        st.info("활동회원 데이터가 없어 납입율을 계산할 수 없습니다.")

    # ===== 3-4. 회비현황 (캠페인별) =====
    st.markdown('<div style="height:40px"></div>', unsafe_allow_html=True)
    st.subheader("3-4. 회비현황 (캠페인별)")
    st.caption("💡 납입회비를 클릭하시면 세부사항을 볼 수 있습니다.")

    _BRND_MERGE_33 = {
        "방송": "방송/광고", "재송출": "방송/광고", "영상광고": "방송/광고", "뉴미디어": "방송/광고",
        "회원 온라인개발": "회원", "회원 오프라인개발": "회원", "회원 콜개발": "회원", "회원 기타": "회원",
    }
    _BRND_ORDER_33 = ["디지털", "방송/광고", "마케팅콜개발", "회원", "기업", "교육기관", "지역개발", "대면모금"]



    with st.spinner("캠페인별 회비 집계 중..."):
        fee_camp_df = load_fee_campaign_data(sel_year, sel_month)

    # 신규/기존: 3-1과 동일한 MSTR 기준
    _nb_opt = "3-1 기준"
    _nb_desc = "3-1 표와 동일 — 매월 월말 활동회원 중 회원 가입연도·후원 등록연도가 모두 당해이면 신규, 그 외 기존 (누계 = 월별 합)"

    if not fee_camp_df.empty:
        if "M_NEW" not in fee_camp_df.columns:
            fee_camp_df["M_NEW"] = 0.0
            fee_camp_df["Y_NEW"] = 0.0
        fee_camp_df["ORIG_BRND"] = fee_camp_df["CMMN_BRND_NM"].replace({"직원개발": "지역개발", "콜개발": "마케팅콜개발"})
        fee_camp_df["MERGED_BRND"] = fee_camp_df["ORIG_BRND"].replace(_BRND_MERGE_33)

        # 캠페인별 활동건 로드
        with st.spinner("캠페인별 활동건 집계 중..."):
            _act34 = _load_active_for_fee34(sel_year, sel_month)
        _act34_map = {}
        if not _act34.empty:
            _act34c = _act34.copy()
            _act34c["CMMN_BRND_NM"] = _act34c["CMMN_BRND_NM"].replace({"직원개발": "지역개발", "콜개발": "마케팅콜개발"}).replace(_BRND_MERGE_33)
            for _, _ar in _act34c.iterrows():
                _k34 = str(_ar["MKTG_CMPGN_NM"])
                _act34_map[_k34] = _act34_map.get(_k34, 0) + float(_ar["ACT_CASES"])

        # 공통브랜드별 집계
        brnd_agg = fee_camp_df.groupby("MERGED_BRND").agg(MONTH_PAY=("MONTH_PAY", "sum"), YTD_PAY=("YTD_PAY", "sum"),
                                                           M_NEW=("M_NEW", "sum"), Y_NEW=("Y_NEW", "sum")).reset_index()
        grand_month = float(brnd_agg["MONTH_PAY"].sum())
        grand_ytd = float(brnd_agg["YTD_PAY"].sum())
        grand_mn = float(brnd_agg["M_NEW"].sum())
        grand_yn = float(brnd_agg["Y_NEW"].sum())

        # 팝업 데이터 구축
        _fee33_popup = {}
        _grand_act = sum(_act34_map.values())
        for brnd in _BRND_ORDER_33:
            bsub = fee_camp_df[fee_camp_df["MERGED_BRND"] == brnd]
            if bsub.empty:
                continue
            cats = []
            brnd_act = 0
            for cat_nm, cg in bsub.groupby("CMPGN_CTGR_NM"):
                camps = []
                cat_act = 0
                for mk_nm, mg in cg.groupby("MKTG_CMPGN_NM"):
                    mp = round(float(mg["MONTH_PAY"].sum()))
                    yp = round(float(mg["YTD_PAY"].sum()))
                    mn = round(float(mg["M_NEW"].sum()))
                    yn = round(float(mg["Y_NEW"].sum()))
                    ob = str(mg["ORIG_BRND"].mode().iloc[0]) if not mg["ORIG_BRND"].mode().empty else brnd
                    ma = round(_act34_map.get(str(mk_nm), 0), 1)
                    if mp > 0 or yp > 0:
                        _c33 = {"n": str(mk_nm), "ob": ob, "mp": mp, "yp": yp, "mn": mn, "yn": yn, "ma": ma}
                        # 대면모금: 마케팅캠페인명 클릭 시 매칭되는 CRM 세부캠페인명 표시
                        if brnd == "대면모금":
                            _dg = mg.groupby("CRM_CMPGN_NM").agg(MONTH_PAY=("MONTH_PAY", "sum"), YTD_PAY=("YTD_PAY", "sum"),
                                                                 M_NEW=("M_NEW", "sum"), Y_NEW=("Y_NEW", "sum")).reset_index()
                            _dg = _dg.sort_values("YTD_PAY", ascending=False)
                            _c33["det"] = [{"n": str(_r["CRM_CMPGN_NM"]), "mp": round(float(_r["MONTH_PAY"])), "yp": round(float(_r["YTD_PAY"])),
                                            "mn": round(float(_r["M_NEW"])), "yn": round(float(_r["Y_NEW"]))}
                                           for _, _r in _dg.iterrows() if _r["MONTH_PAY"] > 0 or _r["YTD_PAY"] > 0]
                        camps.append(_c33)
                        cat_act += ma
                camps.sort(key=lambda x: x["yp"], reverse=True)
                cat_mp = round(float(cg["MONTH_PAY"].sum()))
                cat_yp = round(float(cg["YTD_PAY"].sum()))
                if cat_mp > 0 or cat_yp > 0:
                    cats.append({"name": str(cat_nm), "mp": cat_mp, "yp": cat_yp,
                                 "mn": round(float(cg["M_NEW"].sum())), "yn": round(float(cg["Y_NEW"].sum())),
                                 "camps": camps, "ma": round(cat_act, 1)})
                brnd_act += cat_act
            cats.sort(key=lambda x: x["yp"], reverse=True)
            bm = round(float(bsub["MONTH_PAY"].sum()))
            by = round(float(bsub["YTD_PAY"].sum()))
            _fee33_popup[brnd] = {"brand": brnd, "mp": bm, "yp": by, "mn": round(float(bsub["M_NEW"].sum())),
                                  "yn": round(float(bsub["Y_NEW"].sum())), "basis": _nb_opt, "cats": cats, "ma": round(brnd_act, 1)}

        # 표 렌더링 (3-2 스타일)
        th33 = "background-color:#4a4a4a;color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:12px;"
        fh = '<div id="fee33-table"><style>#fee33-table td { text-align:center !important; }</style>'
        fh += '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
        _thn = th33 + "background-color:#1565C0;"
        _tho = th33 + "background-color:#E65100;"
        fh += (f'<thead><tr><th rowspan="2" style="{th33}">공통브랜드</th><th colspan="3" style="{th33}">당월(원)</th>'
               f'<th colspan="3" style="{th33}">누계(원)</th><th rowspan="2" style="{th33}">구성비(%)</th></tr>'
               f'<tr><th style="{_thn}">신규</th><th style="{_tho}">기존</th><th style="{th33}">합계</th>'
               f'<th style="{_thn}">신규</th><th style="{_tho}">기존</th><th style="{th33}">합계</th></tr></thead><tbody>')
        for brnd in _BRND_ORDER_33:
            ba = brnd_agg[brnd_agg["MERGED_BRND"] == brnd]
            bm = int(ba["MONTH_PAY"].sum()) if not ba.empty else 0
            by_ = int(ba["YTD_PAY"].sum()) if not ba.empty else 0
            bmn = int(ba["M_NEW"].sum()) if not ba.empty else 0
            byn = int(ba["Y_NEW"].sum()) if not ba.empty else 0
            bpct = round(by_ / grand_ytd * 100, 1) if grand_ytd > 0 else 0
            has_popup = brnd in _fee33_popup
            td = "padding:5px;border:1px solid #ddd;white-space:nowrap;"
            _pa = f'data-fee33-popup="{brnd}" title="클릭 시 상세보기" ' if has_popup else ""
            _pc = "cursor:pointer;" if has_popup else ""
            fh += '<tr>'
            fh += f'<td style="{td}">{brnd}</td>'
            fh += f'<td {_pa}style="{td}{_pc}color:#1565C0;">{bmn:,}</td>'
            fh += f'<td {_pa}style="{td}{_pc}color:#E65100;">{bm - bmn:,}</td>'
            fh += f'<td {_pa}style="{td}{_pc}font-weight:700;">{bm:,}</td>'
            fh += f'<td style="{td}color:#1565C0;">{byn:,}</td>'
            fh += f'<td style="{td}color:#E65100;">{by_ - byn:,}</td>'
            fh += f'<td style="{td}font-weight:700;">{by_:,}</td>'
            fh += f'<td style="{td}">{bpct:.1f}%</td>'
            fh += '</tr>'
        # 합계행
        td_tot = "padding:5px;border:1px solid #555;white-space:nowrap;background:#222222;color:white;font-weight:bold;"
        fh += f'<tr><td style="{td_tot}">합계</td>'
        fh += f'<td style="{td_tot}">{int(grand_mn):,}</td>'
        fh += f'<td style="{td_tot}">{int(grand_month - grand_mn):,}</td>'
        fh += f'<td style="{td_tot}">{int(grand_month):,}</td>'
        fh += f'<td style="{td_tot}">{int(grand_yn):,}</td>'
        fh += f'<td style="{td_tot}">{int(grand_ytd - grand_yn):,}</td>'
        fh += f'<td style="{td_tot}">{int(grand_ytd):,}</td>'
        fh += f'<td style="{td_tot}">100.0%</td></tr>'
        fh += '</tbody></table></div>'
        st.markdown(fh, unsafe_allow_html=True)
        st.caption(f"※ 신규/기존 기준 — {_nb_desc} / 기존 = 합계 − 신규")
        st.caption(f"출처: BRONZE_CRM — TM_PM_MBRFEE_ACMSLT × TM_CM_CMPGN_MNG 기준 (캠페인별, {sel_year}-{sel_month:02d}, 법인: I)")

        # JS 팝업
        import json as _json33
        _f33_json = _json33.dumps(_fee33_popup, ensure_ascii=False)
        stc.html(f"""<script>
(function(){{
var doc=window.parent.document;
if(doc._fee33Cleanup){{try{{doc._fee33Cleanup()}}catch(e){{}}}}
var D={_f33_json};
var ov=doc.getElementById('fee33-overlay');
if(ov)ov.remove();
ov=doc.createElement('div');ov.id='fee33-overlay';
ov.style.cssText='display:none;position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:rgba(0,0,0,0.3);justify-content:center;align-items:flex-start;padding-top:60px;';
ov.innerHTML='<div id="fee33-box" style="background:#fff;border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.18);max-width:1200px;width:96%;max-height:82vh;overflow-y:auto;"></div>';
var st33=doc.createElement('style');st33.id='fee33-style';
var old33=doc.getElementById('fee33-style');if(old33)old33.remove();
st33.textContent='@keyframes fee33pop{{from{{opacity:0;transform:scale(.95)}}to{{opacity:1;transform:scale(1)}}}}#fee33-box{{animation:fee33pop .2s ease}}td[data-fee33-popup]{{cursor:pointer}}td[data-fee33-popup]:hover{{background:rgba(39,113,163,0.12) !important}}';
doc.head.appendChild(st33);
doc.body.appendChild(ov);
ov.addEventListener('click',function(e){{if(e.target===ov)ov.style.display='none'}});
var box=doc.getElementById('fee33-box');
function fmt(v){{return v==null?'0':Number(v).toLocaleString()}}
function pct(v,t){{return t>0?(v/t*100).toFixed(1)+'%':'0.0%'}}
// 당월·누계 신규/기존/합계 6칸
function nob(o,base){{
  var mn=o.mn||0,yn=o.yn||0;
  var c='padding:'+(base.p||'4px 8px')+';border:1px solid '+(base.b||'#eee')+';text-align:right;';
  return '<td style="'+c+(base.dark?'':'color:#1565C0;')+'">'+fmt(mn)+'</td>'
        +'<td style="'+c+(base.dark?'':'color:#E65100;')+'">'+fmt(o.mp-mn)+'</td>'
        +'<td style="'+c+'font-weight:700">'+fmt(o.mp)+'</td>'
        +'<td style="'+c+(base.dark?'':'color:#1565C0;')+'">'+fmt(yn)+'</td>'
        +'<td style="'+c+(base.dark?'':'color:#E65100;')+'">'+fmt(o.yp-yn)+'</td>'
        +'<td style="'+c+'font-weight:700">'+fmt(o.yp)+'</td>';
}}
function render(key){{
  var d=D[key];if(!d)return;
  var h='<div style="background:linear-gradient(135deg,#1565C0,#1976D2);color:#fff;padding:14px 20px;border-radius:14px 14px 0 0;display:flex;justify-content:space-between;align-items:center">';
  h+='<span style="font-size:15px;font-weight:700">'+d.brand+' — 회비 캠페인별 상세 <span style="font-size:12px;font-weight:500;opacity:.85">(신규/기존: '+(d.basis||'')+')</span></span>';
  h+='<span id="fee33-close" style="cursor:pointer;font-size:20px;padding:0 6px;border-radius:6px">✕</span></div>';
  h+='<div style="padding:4px 20px 0;display:flex;gap:8px;align-items:center">';
  h+='<input id="fee33-search" type="text" placeholder="캠페인명 검색..." style="flex:1;padding:5px 10px;font-size:12px;border:1px solid #ccc;border-radius:4px;outline:none">';
  h+='<button id="fee33-download" style="padding:4px 12px;font-size:11px;border:1px solid #1565C0;border-radius:4px;background:#1565C0;color:#fff;cursor:pointer;white-space:nowrap">엑셀 다운로드</button>';
  h+='<button id="fee33-expand" style="padding:4px 12px;font-size:11px;border:1px solid #ccc;border-radius:4px;background:#f5f5f5;cursor:pointer;white-space:nowrap">전체 펼치기</button>';
  h+='<button id="fee33-collapse" style="padding:4px 12px;font-size:11px;border:1px solid #ccc;border-radius:4px;background:#f5f5f5;cursor:pointer;white-space:nowrap">전체 접기</button>';
  h+='</div>';
  h+='<div style="padding:12px 22px 18px">';
  var th='background:#f0f2f5;padding:5px 8px;text-align:center;border:1px solid #e0e0e0;font-weight:600;font-size:11px;white-space:nowrap;';
  h+='<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0">';
  var thN=th+'background:#e3f2fd;color:#1565C0;min-width:78px';var thO=th+'background:#fff3e0;color:#E65100;min-width:78px';var thT=th+'min-width:85px';
  h+='<thead><tr>';
  h+='<th rowspan="2" style="'+th+'min-width:80px;text-align:left">공통브랜드</th>';
  h+='<th rowspan="2" style="'+th+'min-width:120px;text-align:left">캠페인카테고리</th>';
  h+='<th rowspan="2" style="'+th+'min-width:140px;text-align:left">마케팅캠페인명</th>';
  h+='<th colspan="3" style="'+th+'">당월(원)</th>';
  h+='<th colspan="3" style="'+th+'">누계(원)</th>';
  h+='<th rowspan="2" style="'+th+'min-width:60px">구성비(%)</th>';
  h+='</tr><tr><th style="'+thN+'">신규</th><th style="'+thO+'">기존</th><th style="'+thT+'">합계</th>';
  h+='<th style="'+thN+'">신규</th><th style="'+thO+'">기존</th><th style="'+thT+'">합계</th></tr></thead><tbody>';
  h+='<tr style="background:#222;color:#fff;font-weight:bold">';
  h+='<td colspan="3" style="padding:6px 8px;border:1px solid #555;text-align:center">합계</td>';
  h+=nob(d,{{p:'6px 8px',b:'#555',dark:true}});
  h+='<td style="padding:6px 8px;border:1px solid #555;text-align:right">100.0%</td>';
  h+='</tr>';
  for(var ci=0;ci<d.cats.length;ci++){{
    var cat=d.cats[ci];
    var stbg=ci%2===0?'#e8f5e9':'#e3f2fd';
    var obSet={{}};for(var _r=0;_r<cat.camps.length;_r++){{if(cat.camps[_r].ob)obSet[cat.camps[_r].ob]=1;}};var obList=Object.keys(obSet).join(', ');
    h+='<tr data-fee33cat="'+ci+'" style="background:'+stbg+';font-weight:bold;cursor:pointer" title="클릭하여 펼치기/접기">';
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;font-size:11px">'+obList+'</td>';
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left"><span class="fee33-arrow-'+ci+'" style="display:inline-block;transition:transform .2s;margin-right:4px;font-size:10px">▶</span>'+cat.name+'</td>';
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;font-weight:700">소계</td>';
    h+=nob(cat,{{}});
    h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+pct(cat.yp,d.yp)+'</td>';
    h+='</tr>';
    for(var ri=0;ri<cat.camps.length;ri++){{
      var c=cat.camps[ri];
      var bg2=ri%2===0?'#fff':'#fafafa';
      var hasDet=c.det&&c.det.length>0;
      var subKey=ci+'-'+ri;
      h+='<tr class="fee33-det-'+ci+'"'+(hasDet?' data-fee33sub="'+subKey+'" title="클릭하여 CRM 세부캠페인 보기"':'')+' style="display:none;background:'+bg2+(hasDet?';cursor:pointer':'')+'">';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;color:#666;font-size:11px">'+(c.ob||'')+'</td>';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;color:#999"></td>';
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:left;max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap'+(hasDet?';color:#1565C0;font-weight:600':'')+'" title="'+c.n+'">'+(hasDet?'<span class="fee33-subarrow-'+subKey+'" style="display:inline-block;transition:transform .2s;margin-right:4px;font-size:9px">▶</span>':'')+c.n+'</td>';
      h+=nob(c,{{}});
      h+='<td style="padding:4px 8px;border:1px solid #eee;text-align:right">'+pct(c.yp,d.yp)+'</td>';
      h+='</tr>';
      if(hasDet){{
        for(var di=0;di<c.det.length;di++){{
          var dd=c.det[di];
          h+='<tr class="fee33-sub-'+subKey+' fee33-subof-'+ci+'" style="display:none;background:#fffde7;font-size:11px">';
          h+='<td style="padding:3px 8px;border:1px solid #eee"></td><td style="padding:3px 8px;border:1px solid #eee"></td>';
          h+='<td style="padding:3px 8px 3px 22px;border:1px solid #eee;text-align:left;color:#555;max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+dd.n+'">└ '+dd.n+'</td>';
          h+=nob(dd,{{p:'3px 8px'}});
          h+='<td style="padding:3px 8px;border:1px solid #eee;text-align:right;color:#555">'+pct(dd.yp,d.yp)+'</td>';
          h+='</tr>';
        }}
      }}
    }}
  }}
  h+='</tbody></table></div>';
  box.innerHTML=h;box.scrollTop=0;box._currentKey=key;
  doc.getElementById('fee33-close').addEventListener('click',function(){{ov.style.display='none'}});
  // 대면모금: 마케팅캠페인명 클릭 → CRM 세부캠페인 펼치기/접기
  box.querySelectorAll('tr[data-fee33sub]').forEach(function(tr){{
    tr.addEventListener('click',function(e){{
      e.stopPropagation();
      var k=tr.getAttribute('data-fee33sub');
      var subs=box.querySelectorAll('.fee33-sub-'+k);
      var open=subs.length&&subs[0].style.display!=='none';
      subs.forEach(function(r){{r.style.display=open?'none':'table-row'}});
      var ar=box.querySelector('.fee33-subarrow-'+k);if(ar)ar.style.transform=open?'':'rotate(90deg)';
    }});
  }});
  // 펼치기/접기
  box.querySelectorAll('tr[data-fee33cat]').forEach(function(tr){{
    tr.addEventListener('click',function(){{
      var idx=tr.getAttribute('data-fee33cat');
      var rows=box.querySelectorAll('.fee33-det-'+idx);
      var show=rows.length>0&&rows[0].style.display==='none';
      rows.forEach(function(r){{r.style.display=show?'table-row':'none'}});
      if(!show){{box.querySelectorAll('.fee33-subof-'+idx).forEach(function(r){{r.style.display='none'}});box.querySelectorAll('[class^="fee33-subarrow-'+idx+'-"]').forEach(function(a){{a.style.transform=''}});}}
      var arrow=box.querySelector('.fee33-arrow-'+idx);
      if(arrow)arrow.style.transform=show?'rotate(90deg)':'rotate(0deg)';
    }});
  }});
  // 전체 펼치기/접기
  doc.getElementById('fee33-expand').addEventListener('click',function(){{
    for(var i=0;i<d.cats.length;i++){{
      box.querySelectorAll('.fee33-det-'+i).forEach(function(r){{r.style.display='table-row'}});
      var a=box.querySelector('.fee33-arrow-'+i);if(a)a.style.transform='rotate(90deg)';
    }}
  }});
  doc.getElementById('fee33-collapse').addEventListener('click',function(){{
    for(var i=0;i<d.cats.length;i++){{
      box.querySelectorAll('.fee33-det-'+i).forEach(function(r){{r.style.display='none'}});
      box.querySelectorAll('.fee33-subof-'+i).forEach(function(r){{r.style.display='none'}});
      var a=box.querySelector('.fee33-arrow-'+i);if(a)a.style.transform='rotate(0deg)';
    }}
  }});
  // 검색
  var searchInput=doc.getElementById('fee33-search');
  searchInput.addEventListener('input',function(){{
    var q=searchInput.value.trim().toLowerCase();
    box.querySelectorAll('tr[data-fee33cat]').forEach(function(tr){{
      var idx=tr.getAttribute('data-fee33cat');
      var catName=d.cats[idx].name.toLowerCase();
      var catMatch=!q||catName.indexOf(q)>=0;
      var anyMatch=false;
      box.querySelectorAll('.fee33-det-'+idx).forEach(function(r){{
        var cells=r.querySelectorAll('td');
        var txt='';cells.forEach(function(c){{txt+=c.textContent.toLowerCase()}});
        var match=!q||txt.indexOf(q)>=0;
        r.style.display=match?'table-row':'none';
        if(match)anyMatch=true;
      }});
      tr.style.display=(catMatch||anyMatch)?'table-row':'none';
      var arrow=box.querySelector('.fee33-arrow-'+idx);
      if(arrow)arrow.style.transform=(catMatch||anyMatch)?'rotate(90deg)':'rotate(0deg)';
    }});
  }});
  searchInput.addEventListener('keydown',function(e){{e.stopPropagation()}});
  // 엑셀 다운로드
  doc.getElementById('fee33-download').addEventListener('click',function(){{
    var d2=D[box._currentKey];if(!d2)return;
    function nv(o){{var mn=o.mn||0,yn=o.yn||0;return [mn,o.mp-mn,o.mp,yn,o.yp-yn,o.yp]}}
    var rows=[['신규/기존 기준: '+(d2.basis||'')],
              ['공통브랜드','캠페인카테고리','마케팅캠페인명','당월 신규(원)','당월 기존(원)','당월 합계(원)','누계 신규(원)','누계 기존(원)','누계 합계(원)','구성비(%)']];
    for(var ci=0;ci<d2.cats.length;ci++){{
      var cat=d2.cats[ci];
      var obS={{}};for(var _x=0;_x<cat.camps.length;_x++){{if(cat.camps[_x].ob)obS[cat.camps[_x].ob]=1;}};var obL=Object.keys(obS).join(', ');
      rows.push([obL,cat.name,'소계'].concat(nv(cat),[pct(cat.yp,d2.yp)]));
      for(var ri=0;ri<cat.camps.length;ri++){{
        var c=cat.camps[ri];
        rows.push([c.ob||'',cat.name,c.n].concat(nv(c),[pct(c.yp,d2.yp)]));
      }}
    }}
    rows.push(['합계','',''].concat(nv(d2),['100.0%']));
    var csv='\\uFEFF';
    rows.forEach(function(r){{csv+=r.map(function(v){{var s=String(v==null?'':v);if(s.indexOf(',')>=0||s.indexOf('"')>=0)return '"'+s.replace(/"/g,'""')+'"';return s}}).join(',')+\"\\n\"}});
    var blob=new Blob([csv],{{type:'text/csv;charset=utf-8'}});
    var a=document.createElement('a');a.href=URL.createObjectURL(blob);
    a.download=d2.brand+'_회비캠페인별상세.csv';a.click();URL.revokeObjectURL(a.href);
  }});
}}
function onClick(e){{
  var td=e.target.closest('td[data-fee33-popup]');
  if(td){{var key=td.getAttribute('data-fee33-popup');if(D[key]){{render(key);ov.style.display='flex';}}}}
}}
doc.addEventListener('click',onClick);
doc._fee33Cleanup=function(){{doc.removeEventListener('click',onClick);var o=doc.getElementById('fee33-overlay');if(o)o.remove();var s=doc.getElementById('fee33-style');if(s)s.remove();}};
}})();
</script>""", height=0)

        # ── 3-4 그래프: 공통브랜드별 월별 납입회비 추이 (억원, 전년 동월 대비 툴팁) ──
        def _brand_monthly(yr):
            _d = load_fee_brand_monthly(yr, sel_month)
            if _d.empty:
                return pd.Series(dtype=float)
            _d = _d.copy()
            _d["BRND"] = (_d["CMMN_BRND_NM"].replace({"직원개발": "지역개발", "콜개발": "마케팅콜개발"})
                          .replace(_BRND_MERGE_33))
            _d["_m"] = _d["PAY_MT"].astype(str).str[-2:].astype(int)
            _d["PAY_AMT"] = _d["PAY_AMT"].astype(float)
            return _d.groupby(["BRND", "_m"])["PAY_AMT"].sum()

        with st.spinner("공통브랜드별 월별 회비 집계 중..."):
            _bmc = _brand_monthly(sel_year)
            _bmp = _brand_monthly(sel_year - 1)

        if len(_bmc):
            _br_rows = []
            for (_b, _m), _v in _bmc.items():
                if _b not in _BRND_ORDER_33:
                    continue
                _pv = float(_bmp.get((_b, _m), 0)) if len(_bmp) else 0.0
                _br_rows.append({
                    "월": f"{_m}월", "공통브랜드": _b, "납입억": round(_v / 1e8, 2),
                    "당월납입": f"{_v:,.0f}원",
                    "전년동월": f"{_pv:,.0f}원" if _pv else "-",
                    "증감액": f"{_v - _pv:+,.0f}원" if _pv else "-",
                    "증감율": f"{(_v - _pv) / _pv * 100:+.1f}%" if _pv else "-",
                })
            _br_df = pd.DataFrame(_br_rows)
            if not _br_df.empty:
                # 같은 월 라벨끼리 겹치지 않도록: 월별 금액 순위에 따라 위/아래 번갈아 배치
                _br_df["_rk"] = _br_df.groupby("월")["납입억"].rank(method="first", ascending=False)
                _br_df["_pos"] = _br_df["_rk"].apply(lambda r: "up" if int(r) % 2 == 1 else "down")
                _br_rng = ["#1565C0", "#E53935", "#FB8C00", "#43A047", "#8E24AA", "#00ACC1", "#6D4C41", "#F06292"]
                _br_scale = alt.Scale(domain=_BRND_ORDER_33, range=_br_rng)
                _br_x = alt.X("월:N", sort=[f"{m}월" for m in range(1, 13)], axis=alt.Axis(labelFontSize=11, labelAngle=0, title="월"))
                _br_tt = [alt.Tooltip("월:N"), alt.Tooltip("공통브랜드:N"), alt.Tooltip("당월납입:N", title="당월 납입"),
                          alt.Tooltip("전년동월:N", title=f"{sel_year - 1}년 동월"),
                          alt.Tooltip("증감액:N", title="전년 동월 대비 증감액"),
                          alt.Tooltip("증감율:N", title="전년 동월 대비 증감율")]
                _br_line = alt.Chart(_br_df).mark_line(
                    strokeWidth=3, point=alt.OverlayMarkDef(size=140, filled=True, stroke="white", strokeWidth=1.5)
                ).encode(x=_br_x, y=alt.Y("납입억:Q", axis=alt.Axis(labelFontSize=10, format=",.1f", title="납입액(억원)")),
                         color=alt.Color("공통브랜드:N", scale=_br_scale,
                                         legend=alt.Legend(orient="right", title="공통브랜드", titleFontSize=11, labelFontSize=11, symbolSize=140)),
                         tooltip=_br_tt)
                _br_lbl = alt.Chart(_br_df).encode(
                    x=_br_x, y="납입억:Q", text=alt.Text("납입억:Q", format=",.1f"),
                    color=alt.Color("공통브랜드:N", scale=_br_scale, legend=None))
                _br_up = _br_lbl.transform_filter(alt.FieldEqualPredicate(field="_pos", equal="up")).mark_text(dy=-13, fontSize=10, fontWeight="bold")
                _br_dn = _br_lbl.transform_filter(alt.FieldEqualPredicate(field="_pos", equal="down")).mark_text(dy=15, fontSize=10, fontWeight="bold")
                st.markdown('<div style="height:24px"></div>', unsafe_allow_html=True)
                st.markdown(f'<div style="font-weight:800;font-size:16px;color:#1565C0;border-bottom:3px solid #FFB300;padding-bottom:8px;margin-bottom:12px;">'
                            f'▼ {sel_year}년 공통브랜드별 월별 납입회비 추이 (억원)</div>', unsafe_allow_html=True)
                st.altair_chart(alt.layer(_br_line, _br_up, _br_dn).properties(width="container", height=380), use_container_width=True)
                st.caption(f"점에 마우스오버 시 {sel_year - 1}년 동월 대비 증감액·증감율을 확인할 수 있습니다. | 공통브랜드는 3-4표와 동일한 통합 기준")

        # ── 3-4 TOP5: 공통브랜드 / 캠페인카테고리 / 마케팅캠페인 (당월 · 누계) ──
        def _amt_kr(v):
            return f"{v / 1e8:,.1f}억원" if abs(v) >= 1e8 else f"{v / 1e4:,.0f}만원"

        _t5_dims = [("공통브랜드", "MERGED_BRND"), ("캠페인카테고리", "CMPGN_CTGR_NM"), ("마케팅캠페인", "MKTG_CMPGN_NM")]
        _t5_medal = ["🥇", "🥈", "🥉", "4", "5"]
        _t5_card = ("background:linear-gradient(160deg,#ffffff 0%,#eef4fb 100%);border:2px solid #1565C0;border-top:6px solid #1565C0;"
                    "border-radius:14px;padding:14px 16px;box-shadow:0 6px 18px rgba(21,101,192,0.15);height:100%;")
        _t5_ttl = "font-weight:900;font-size:16px;color:#0D47A1;border-bottom:3px solid #FFB300;padding-bottom:6px;margin-bottom:8px;"

        def _t5_html(dim_lbl, col, val_col):
            # Snowflake NUMBER는 Decimal로 오므로 float로 변환 후 계산
            _g = fee_camp_df.groupby(col)[val_col].sum().astype(float).sort_values(ascending=False)
            _tot = float(_g.sum())
            _top = _g[_g > 0].head(5)
            _mx = float(_top.iloc[0]) if len(_top) else 1
            h = f'<div style="{_t5_card}"><div style="{_t5_ttl}">{dim_lbl} TOP5</div>'
            for _i, (_n, _v) in enumerate(_top.items()):
                _pct = _v / _tot * 100 if _tot else 0
                _w = max(_v / _mx * 100, 3)
                _rk = (f'<span style="font-size:16px;">{_t5_medal[_i]}</span>' if _i < 3 else
                       f'<span style="display:inline-block;width:20px;text-align:center;font-weight:800;color:#78909C;">{_t5_medal[_i]}</span>')
                h += ('<div style="margin:7px 0;">'
                      '<div style="display:flex;justify-content:space-between;align-items:center;gap:6px;">'
                      f'<span style="font-size:13px;font-weight:700;color:#263238;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="{_n}">{_rk} {_n}</span>'
                      f'<span style="font-size:13px;font-weight:900;color:#0D47A1;white-space:nowrap;">{_amt_kr(_v)} <span style="color:#2E7D32;font-size:12px;">{_pct:.1f}%</span></span></div>'
                      f'<div style="height:7px;background:#E3F2FD;border-radius:4px;margin-top:3px;"><div style="width:{_w:.1f}%;height:100%;'
                      'background:linear-gradient(90deg,#64B5F6,#1565C0);border-radius:4px;"></div></div></div>')
            if not len(_top):
                h += '<div style="font-size:13px;color:#90A4AE;">데이터 없음</div>'
            _t5_share = _top.sum() / _tot * 100 if _tot else 0
            h += f'<div style="font-size:12px;color:#546E7A;margin-top:8px;">TOP5 합계 비중 <b>{_t5_share:.1f}%</b> (전체 {_amt_kr(_tot)})</div></div>'
            return h

        for _t5_period, _t5_col in [(f"{sel_month}월 당월", "MONTH_PAY"), (f"1~{sel_month}월 누계", "YTD_PAY")]:
            st.markdown('<div style="height:18px"></div>', unsafe_allow_html=True)
            st.markdown(f'<div style="font-weight:800;font-size:16px;color:#1565C0;border-bottom:3px solid #FFB300;padding-bottom:8px;margin-bottom:12px;">'
                        f'▼ {_t5_period} 납입회비 TOP5 (공통브랜드 · 캠페인카테고리 · 마케팅캠페인)</div>', unsafe_allow_html=True)
            _t5c = st.columns(3, gap="small")
            for _ci, (_dl, _dc) in enumerate(_t5_dims):
                with _t5c[_ci]:
                    st.markdown(_t5_html(_dl, _dc, _t5_col), unsafe_allow_html=True)
        st.caption("공통브랜드는 3-4표와 동일한 통합 기준 | 비중 = 해당 기간 전체 캠페인 납입회비 대비")

    else:
        st.info("캠페인별 회비 데이터가 없습니다.")


    # ── 회비현황 KPI 박스 (상단 placeholder 렌더링) ──
    def _fk_rate(pay, act):
        return pay / (act * 10000) * 100 if act else None

    def _fk_ach(val, goal):
        return val / goal * 100 if (val is not None and goal) else None

    def _fk_pct(v):
        return "-" if v is None else f"{v:.1f}%"

    _fk_tot = fee_rows[4] if "fee_rows" in dir() and len(fee_rows) > 4 else None
    _fk_gm = globals().get("_goal_m") or [None] * 5
    _fk_gy = globals().get("_goal_y") or [None] * 5
    _fk_act_m = globals().get("_act_total", 0)
    _fk_act_y = globals().get("_ytd_total", 0)

    if _fk_tot is not None:
        _fk_rate_m = _fk_rate(_fk_tot["m_pay"], _fk_act_m)
        _fk_rate_y = _fk_rate(_fk_tot["y_pay"], _fk_act_y)
        _fk_new_y = _fk_rate(fee_rows[2]["y_pay"], globals().get("_ytd_new_sub", 0))
        _fk_old_y = _fk_rate(fee_rows[3]["y_pay"], globals().get("_ytd_old", 0))
        _fk_per_m = _fk_tot["m_pay"] / _fk_tot["m_members"] if _fk_tot["m_members"] else 0
        _fk_per_y = _fk_tot["y_pay"] / _fk_tot["y_members"] if _fk_tot["y_members"] else 0

        # 당월 납입 TOP3 마케팅캠페인 (3-4 캠페인별 회비 기준)
        _fk_top = []
        if "fee_camp_df" in dir() and not fee_camp_df.empty:
            _fk_cg = fee_camp_df.groupby("MKTG_CMPGN_NM")["MONTH_PAY"].sum().sort_values(ascending=False)
            _fk_all = float(_fk_cg.sum())
            _fk_top = [(str(n), float(v), float(v) / _fk_all * 100 if _fk_all else 0) for n, v in _fk_cg.head(3).items() if v > 0]

        # 회원개발 탭과 동일한 카드 스타일
        _fk_card = (
            "background:linear-gradient(160deg,#ffffff 0%,#eef4fb 100%);"
            "border:2px solid #1565C0;border-top:6px solid #1565C0;border-radius:14px;padding:18px 22px;"
            "box-shadow:0 6px 18px rgba(21,101,192,0.18);"
            "height:340px;display:flex;flex-direction:column;justify-content:space-evenly;"
        )
        _fk_title = (
            "font-weight:900;font-size:19px;margin-bottom:6px;color:#0D47A1;letter-spacing:-0.3px;"
            "border-bottom:3px solid #FFB300;padding-bottom:8px;white-space:nowrap;"
        )
        _fk_row = "display:flex;justify-content:space-between;align-items:center;padding:5px 2px;"
        _fk_lbl = "color:#263238;font-size:18px;font-weight:700;white-space:nowrap;"
        _fk_val = "font-weight:900;color:#0D47A1;font-size:30px;line-height:1.1;letter-spacing:-0.5px;"
        _fk_amt = "font-weight:900;color:#0D47A1;font-size:22px;line-height:1.1;letter-spacing:-0.5px;white-space:nowrap;"
        _fk_cnt = "font-size:16px;color:#2E7D32;font-weight:800;line-height:1.2;margin-top:2px;"
        _fk_sub = "font-size:13px;color:#546E7A;margin-top:6px;line-height:1.5;"
        _fk_sep = "border-top:2px solid #CFD8DC;margin-top:4px;padding-top:8px;"

        def _fk_pv(main, sub, main_css=_fk_val):
            return (f'<span style="display:flex;flex-direction:column;align-items:flex-end;">'
                    f'<span style="{main_css}">{main}</span><span style="{_fk_cnt}">{sub}</span></span>')

        with _fee_kpi_slot:
            _fk1, _fk2, _fk3, _fk4 = st.columns(4, gap="small")
            with _fk1:
                _fk_m_html = _fk_pv("{:,.0f}원".format(_fk_tot["m_pay"]), "목표대비 {:.1f}%".format(_fk_tot["m_rate"]), _fk_amt)
                _fk_y_html = _fk_pv("{:,.0f}원".format(_fk_tot["y_pay"]), "목표대비 {:.1f}%".format(_fk_tot["y_rate"]), _fk_amt)
                # 연목표 = 신규(본부+지부) + 기존, 1~12월 목표 합계
                _fk_all_cols = [f"R{m:02d}" for m in range(1, 13)]
                _fk_annual_tgt = (_get_fee_goal("신규", "본부", _fk_all_cols)
                                  + _get_fee_goal("신규", "지부", _fk_all_cols)
                                  + _get_fee_goal("기존", None, _fk_all_cols))
                _fk_annual_ach = _fk_pct(_fk_ach(_fk_tot["y_pay"], _fk_annual_tgt))
                st.markdown(f'''<div style="{_fk_card}">
                  <div style="{_fk_title}display:flex;justify-content:space-between;align-items:baseline;">납입회비<span style="font-size:14px;font-weight:800;color:#2E7D32;">연목표 대비 {_fk_annual_ach}</span></div>
                  <div style="{_fk_row}"><span style="{_fk_lbl}">당월</span>{_fk_m_html}</div>
                  <div style="{_fk_row}"><span style="{_fk_lbl}">누계</span>{_fk_y_html}</div>
                  <div style="{_fk_sub}{_fk_sep}">명당 납입액: 당월 <b>{_fk_per_m:,.0f}원</b> / 누계 <b>{_fk_per_y:,.0f}원</b></div>
                </div>''', unsafe_allow_html=True)
            with _fk2:
                st.markdown(f'''<div style="{_fk_card}">
                  <div style="{_fk_title}">납입율(%)</div>
                  <div style="{_fk_row}"><span style="{_fk_lbl}">당월</span>{_fk_pv(_fk_pct(_fk_rate_m), "목표대비 " + _fk_pct(_fk_ach(_fk_rate_m, _fk_gm[4])))}</div>
                  <div style="{_fk_row}"><span style="{_fk_lbl}">누계</span>{_fk_pv(_fk_pct(_fk_rate_y), "목표대비 " + _fk_pct(_fk_ach(_fk_rate_y, _fk_gy[4])))}</div>
                  <div style="{_fk_sub}">목표: 당월 {_fk_pct(_fk_gm[4])} / 누계 {_fk_pct(_fk_gy[4])}</div>
                </div>''', unsafe_allow_html=True)
            with _fk3:
                st.markdown(f'''<div style="{_fk_card}">
                  <div style="{_fk_title}">신규/기존 누계 납입율(%)</div>
                  <div style="{_fk_row}"><span style="{_fk_lbl}">신규</span>{_fk_pv(_fk_pct(_fk_new_y), "목표대비 " + _fk_pct(_fk_ach(_fk_new_y, _fk_gy[2])))}</div>
                  <div style="{_fk_row}"><span style="{_fk_lbl}">기존</span>{_fk_pv(_fk_pct(_fk_old_y), "목표대비 " + _fk_pct(_fk_ach(_fk_old_y, _fk_gy[3])))}</div>
                  <div style="{_fk_sub}">목표: 신규 {_fk_pct(_fk_gy[2])} / 기존 {_fk_pct(_fk_gy[3])}</div>
                </div>''', unsafe_allow_html=True)
            with _fk4:
                _fk_medal = ["🥇", "🥈", "🥉"]
                _fk_lines = ""
                for _fi, (_fn, _fv, _fp) in enumerate(_fk_top):
                    _big = _fi == 0
                    _ncss = f"font-weight:900;color:#0D47A1;font-size:{22 if _big else 16}px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"
                    _pcss = f"font-weight:900;color:#2E7D32;font-size:{26 if _big else 18}px;white-space:nowrap;"
                    _fk_lines += (f'<div style="{_fk_row}{_fk_sep if _fi else ""}gap:8px;">'
                                  f'<span style="{_ncss}" title="{_fn} ({_fv:,.0f}원)">{_fk_medal[_fi]} {_fn}</span>'
                                  f'<span style="{_pcss}">{_fp:.1f}%</span></div>')
                if not _fk_lines:
                    _fk_lines = f'<div style="{_fk_sub}">데이터 없음</div>'
                st.markdown(f'''<div style="{_fk_card}">
                  <div style="{_fk_title}">당월 납입 TOP3 마케팅캠페인</div>
                  {_fk_lines}
                  <div style="{_fk_sub}">당월 캠페인별 납입회비(3-4) 대비 비중</div>
                </div>''', unsafe_allow_html=True)
            st.markdown('<div style="height:36px"></div>', unsafe_allow_html=True)

            # ── 2개년 월별 납입율 비교 (선: 전체, 막대: 신규/기존) ──
            # 납입율 = 월 납입(원) / (월 활동회원(건) × 10,000) × 100  (3-3표와 동일 정의)
            def _fee_rate_rows(_yr, _last_m):
                _rows = []
                for _m in range(1, _last_m + 1):
                    _f = _load_fee_month(_yr, _m)
                    _a = _load_active_for_fee(_yr, _m)
                    if _f.empty or _a.empty:
                        continue
                    _pay = {k: float(_f[_f["NEW_OLD"] == k]["PAY_AMT"].sum()) for k in ("신규회원", "기존회원")}
                    _act = {k: float(_a[_a["NEW_OLD"] == k]["ACT_CASES"].sum()) for k in ("신규회원", "기존회원")}
                    _rate = lambda p, a: p / (a * 10000) * 100 if a > 0 else None
                    _rows.append({"월": f"{_m}월", "_m": _m, "연도": str(_yr),
                                  "신규": _rate(_pay["신규회원"], _act["신규회원"]),
                                  "기존": _rate(_pay["기존회원"], _act["기존회원"]),
                                  "전체": _rate(sum(_pay.values()), sum(_act.values()))})
                return _rows

            with st.spinner("월별 납입율 집계 중... (최초 1회 수 분 소요)"):
                _fr_cur = _fee_rate_rows(sel_year, sel_month)
                _fr_prev = _fee_rate_rows(sel_year - 1, 12)

            if _fr_cur:
                _prev_total = {r["_m"]: r["전체"] for r in _fr_prev}
                _month_sort_f = [f"{m}월" for m in range(1, 13)]
                _py_s, _cy_s = str(sel_year - 1), str(sel_year)

                # 막대: 연도 × 신규/기존
                _bar_f = []
                for _r in _fr_prev + _fr_cur:
                    for _k in ("신규", "기존"):
                        if _r[_k] is not None:
                            _bar_f.append({"월": _r["월"], "구분": f"{_r['연도']} {_k}", "납입율": round(_r[_k], 1)})
                _bar_f = pd.DataFrame(_bar_f)
                _bar_dom = [f"{_py_s} 신규", f"{_py_s} 기존", f"{_cy_s} 신규", f"{_cy_s} 기존"]
                _bar_rng = ["#90CAF9", "#FFCC80", "#1565C0", "#EF6C00"]

                # 선: 2026 실선 / 2025 회색 점선
                _ln_cur = pd.DataFrame([{
                    "월": r["월"], "납입율": round(r["전체"], 1), "라벨": f"{r['전체']:.1f}",
                    "전년동월": round(_prev_total[r["_m"]], 1) if _prev_total.get(r["_m"]) is not None else None,
                    "증감": (f"{r['전체'] - _prev_total[r['_m']]:+.1f}%p" if _prev_total.get(r["_m"]) is not None else "-"),
                } for r in _fr_cur if r["전체"] is not None])
                _ln_prev = pd.DataFrame([{"월": r["월"], "납입율": round(r["전체"], 1)} for r in _fr_prev if r["전체"] is not None])

                _all_vals = list(_bar_f["납입율"]) + list(_ln_cur["납입율"]) + (list(_ln_prev["납입율"]) if not _ln_prev.empty else [])
                _y_dom = [max(0, int(min(_all_vals)) - 5), min(110, int(max(_all_vals)) + 5)]
                _yenc = alt.Y("납입율:Q", scale=alt.Scale(domain=_y_dom, clamp=True),
                              axis=alt.Axis(labelFontSize=10, format=".0f", title="납입율(%)"))
                _xenc = alt.X("월:N", sort=_month_sort_f, scale=alt.Scale(paddingInner=0.18),
                              axis=alt.Axis(labelFontSize=11, labelAngle=0, title="월"))

                _fbars = alt.Chart(_bar_f).mark_bar(cornerRadiusTopLeft=2, cornerRadiusTopRight=2, opacity=0.9).encode(
                    x=_xenc,
                    # 같은 달 막대끼리 간격 최소화 (막대 폭은 밴드에 맞춰 자동으로 두껍게)
                    xOffset=alt.XOffset("구분:N", sort=_bar_dom, scale=alt.Scale(paddingInner=0.04)),
                    y=_yenc,
                    color=alt.Color("구분:N", scale=alt.Scale(domain=_bar_dom, range=_bar_rng),
                                    legend=alt.Legend(orient="right", title="신규/기존", titleFontSize=11, labelFontSize=11, symbolSize=140)),
                    tooltip=[alt.Tooltip("월:N"), alt.Tooltip("구분:N"), alt.Tooltip("납입율:Q", format=".1f", title="납입율(%)")],
                )
                _flayers = [_fbars]
                if not _ln_prev.empty:
                    _flayers.append(alt.Chart(_ln_prev.assign(연도=f"{_py_s}년 전체")).mark_line(
                        strokeWidth=2.5, strokeDash=[6, 4], color="#9E9E9E",
                        point=alt.OverlayMarkDef(size=60, filled=True, color="#9E9E9E")
                    ).encode(x=alt.X("월:N", sort=_month_sort_f), y="납입율:Q",
                             tooltip=[alt.Tooltip("월:N"), alt.Tooltip("납입율:Q", format=".1f", title=f"{_py_s}년 납입율(%)")]))
                _flayers.append(alt.Chart(_ln_cur).mark_line(
                    strokeWidth=3.5, color="#0D47A1",
                    point=alt.OverlayMarkDef(size=160, filled=True, color="#0D47A1", stroke="white", strokeWidth=1.5)
                ).encode(x=alt.X("월:N", sort=_month_sort_f), y="납입율:Q",
                         tooltip=[alt.Tooltip("월:N"),
                                  alt.Tooltip("납입율:Q", format=".1f", title=f"{_cy_s}년 납입율(%)"),
                                  alt.Tooltip("전년동월:Q", format=".1f", title=f"{_py_s}년 동월(%)"),
                                  alt.Tooltip("증감:N", title="전년 동월 대비")]))
                _flayers.append(alt.Chart(_ln_cur).mark_text(dy=-20, fontSize=16, fontWeight="bold", color="#0D47A1",
                                                          stroke="white", strokeWidth=4, strokeOpacity=0.9).encode(
                    x=alt.X("월:N", sort=_month_sort_f), y="납입율:Q", text="라벨:N"))
                # 흰 테두리 위에 본 글자를 한 번 더 그려 막대와 겹쳐도 선명하게
                _flayers.append(alt.Chart(_ln_cur).mark_text(dy=-20, fontSize=16, fontWeight="bold", color="#0D47A1").encode(
                    x=alt.X("월:N", sort=_month_sort_f), y="납입율:Q", text="라벨:N"))

                st.markdown(f'<div style="font-weight:800;font-size:16px;color:#1565C0;border-bottom:3px solid #FFB300;padding-bottom:8px;margin-bottom:12px;">'
                            f'▼ {_py_s}~{_cy_s}년 월별 납입율 비교 (선: 전체 납입율 — {_cy_s}년 실선 / {_py_s}년 회색 점선, 막대: 신규/기존)</div>',
                            unsafe_allow_html=True)
                st.altair_chart(alt.layer(*_flayers).properties(width="container", height=360), use_container_width=True)
                st.caption("납입율 = 월 납입(원) / (월 활동회원(건) × 10,000) × 100 | 3-3표와 동일 기준 · 진한 실선 점에 마우스오버 시 전년 동월 대비 증감(%p)")
                st.markdown('<div style="height:28px"></div>', unsafe_allow_html=True)

elif selected_tab == TAB_LABELS[3] and not HIDE_REF_TAB:
    st.caption(f"법인: 사단법인 | 기준: {sel_year}년 {sel_month}월")

    REF_BIZ_LIST = [
        "국내아동권리보호사업", "해외아동결연", "해외교육지원사업",
        "희망학교지원사업", "식수위생지원사업", "보건의료지원사업",
        "해외지역개발사업", "재난구호지원사업", "대북지원사업",
        "전체사업지원", "좋은이웃후원",
    ]


    with st.spinner("참고탭 데이터 집계 중..."):
        ref_df = load_ref_tab_data(sel_year, sel_month)
        try:
            boy_ref_df = load_active_by_biz(sel_year - 1, 12)
        except NameError:
            boy_ref_df = pd.DataFrame()

    # --- 개발 데이터: 탭1과 동일한 df_month, df_ytd 재생성 후 (후원사업 × 신규기존) 집계 ---
    raw_df = load_data(sel_year)
    df_all = build_summary(raw_df)
    if exclude_fake and sel_year == 2025:
        exclude_set = set(EXCLUDED_MEMBERS_2025)
        df_all = df_all[~df_all.apply(lambda r: (r["MBER_NO"], r["STRD_MT"]) in exclude_set, axis=1)]
    month_start_int = int(f"{sel_year}{sel_month:02d}01")
    month_end_int = int(f"{sel_year}{sel_month:02d}31")
    ytd_start_int = int(f"{sel_year}0101")
    df_month = df_all[(df_all["OCCUR_DATE"] >= month_start_int) & (df_all["OCCUR_DATE"] <= month_end_int)]
    df_ytd = df_all[(df_all["OCCUR_DATE"] >= ytd_start_int) & (df_all["OCCUR_DATE"] <= month_end_int)]

    def _agg_dev(df):
        d = df[df["후원사업"].notna()].copy()
        if d.empty:
            return {}
        result = {}
        for (biz, mt), g in d.groupby(["후원사업", "회원구분"]):
            result[(biz, mt)] = {"명": int(g["MBER_NO"].nunique()), "건": float(g["개발건"].sum())}
        return result

    dev_m = _agg_dev(df_month)
    dev_y = _agg_dev(df_ytd)

    # --- 활동+회비 데이터: ref_df에서 (후원사업 × 신규기존) 집계 ---
    # SQL에서 이미 BIZ_CATEGORY로 매핑 + GROUP BY 완료 → Python 재매핑 불필요
    act_data = {}
    if not ref_df.empty:
        for _, row in ref_df.iterrows():
            biz = row["BIZ_NAME"]
            no = row["NEW_OLD"]
            act_data[(biz, no)] = {
                "members": int(row["ACTIVE_MEMBERS"]),
                "cases": float(row["ACTIVE_CASES"]),
                "month_pay": float(row["MONTH_PAY"]),
                "ytd_pay": float(row["YTD_PAY"]),
            }

    # --- 연도초 활동회원(건): 후원사업별 고정값 (2026년 기준) ---
    BOY_BIZ_FIXED = {
        "국내아동권리보호사업": 297289.58,
        "해외아동결연": 601882.50,
        "해외교육지원사업": 35145.75,
        "희망학교지원사업": 16274.54,
        "식수위생지원사업": 40782.59,
        "보건의료지원사업": 205097.57,
        "해외지역개발사업": 83321.72,
        "재난구호지원사업": 11019.15,
        "대북지원사업": 3366.45,
        "전체사업지원": 14743.99,
        "좋은이웃후원": 2384.23,
    }
    boy_biz = {}
    if sel_year == 2026:
        boy_biz = BOY_BIZ_FIXED.copy()
    elif not boy_ref_df.empty:
        boy_mapped = boy_ref_df.copy()
        boy_mapped["후원사업"] = boy_mapped["BIZ_NAME"].map(BIZ_NAME_MAP)
        boy_mapped = boy_mapped[boy_mapped["후원사업"].notna()]
        for biz, g in boy_mapped.groupby("후원사업"):
            boy_biz[biz] = float(g["ACTIVE_CASES"].sum())

    # --- 표 데이터 구축 함수 ---
    def build_table_rows(biz_list, member_type, dev_m_dict, dev_y_dict, act_dict, boy_dict):
        rows = []
        for biz in biz_list:
            dm = dev_m_dict.get((biz, member_type), {"명": 0, "건": 0.0})
            dy = dev_y_dict.get((biz, member_type), {"명": 0, "건": 0.0})
            ac = act_dict.get((biz, member_type), {"members": 0, "cases": 0.0, "month_pay": 0.0, "ytd_pay": 0.0})
            boy_val = boy_dict.get(biz, 0.0) if member_type == "기존회원" else 0.0
            ytd_dev = dy["건"]
            act_cases = ac["cases"]
            if member_type == "신규회원":
                act_rate = round(act_cases / ytd_dev * 100, 1) if ytd_dev > 0 else 0.0
            else:
                denom = boy_val + ytd_dev
                act_rate = round(act_cases / denom * 100, 1) if denom > 0 else 0.0
            rows.append({
                "후원사업": biz, "boy": boy_val,
                "개발명": dm["명"], "개발건": dm["건"],
                "누계개발명": dy["명"], "누계개발건": ytd_dev,
                "활동명": ac["members"], "활동건": act_cases, "누계활동건": act_cases,
                "납입원": ac["month_pay"], "누계납입원": ac["ytd_pay"],
                "활동율": act_rate,
                "누계납입율": round(ac["ytd_pay"] / (act_cases * 10000) * 100, 1) if act_cases > 0 else 0.0,
            })
        # 합계
        t = {}
        for k in ["boy", "개발명", "개발건", "누계개발명", "누계개발건", "활동명", "활동건", "누계활동건", "납입원", "누계납입원"]:
            t[k] = sum(r[k] for r in rows)
        if member_type == "신규회원":
            t_rate = round(t["활동건"] / t["누계개발건"] * 100, 1) if t["누계개발건"] > 0 else 0.0
        else:
            denom = t["boy"] + t["누계개발건"]
            t_rate = round(t["활동건"] / denom * 100, 1) if denom > 0 else 0.0
        rows.append({
            "후원사업": "합계", "boy": t["boy"],
            "개발명": t["개발명"], "개발건": t["개발건"],
            "누계개발명": t["누계개발명"], "누계개발건": t["누계개발건"],
            "활동명": t["활동명"], "활동건": t["활동건"], "누계활동건": t["누계활동건"],
            "납입원": t["납입원"], "누계납입원": t["누계납입원"],
            "활동율": t_rate,
            "누계납입율": round(t["누계납입원"] / (t["누계활동건"] * 10000) * 100, 1) if t["누계활동건"] > 0 else 0.0,
        })
        return rows

    def build_total_rows(new_rows, old_rows):
        rows = []
        for i in range(len(new_rows)):
            n, o = new_rows[i], old_rows[i]
            boy = n["boy"] + o["boy"]
            ytd_dev = n["누계개발건"] + o["누계개발건"]
            act_c = n["활동건"] + o["활동건"]
            denom = boy + ytd_dev
            act_rate = round(act_c / denom * 100, 1) if denom > 0 else 0.0
            ytd_pay_total = n["누계납입원"] + o["누계납입원"]
            rows.append({
                "후원사업": n["후원사업"], "boy": boy,
                "개발명": n["개발명"] + o["개발명"], "개발건": n["개발건"] + o["개발건"],
                "누계개발명": n["누계개발명"] + o["누계개발명"], "누계개발건": ytd_dev,
                "활동명": n["활동명"] + o["활동명"], "활동건": act_c,
                "누계활동건": act_c,
                "납입원": n["납입원"] + o["납입원"], "누계납입원": ytd_pay_total,
                "활동율": act_rate,
                "누계납입율": round(ytd_pay_total / (act_c * 10000) * 100, 1) if act_c > 0 else 0.0,
            })
        # 합계
        t = {}
        for k in ["boy", "개발명", "개발건", "누계개발명", "누계개발건", "활동명", "활동건", "누계활동건", "납입원", "누계납입원"]:
            t[k] = sum(r[k] for r in rows)
        denom = t["boy"] + t["누계개발건"]
        t_rate = round(t["활동건"] / denom * 100, 1) if denom > 0 else 0.0
        rows.append({
            "후원사업": "합계", "boy": t["boy"],
            "개발명": t["개발명"], "개발건": t["개발건"],
            "누계개발명": t["누계개발명"], "누계개발건": t["누계개발건"],
            "활동명": t["활동명"], "활동건": t["활동건"], "누계활동건": t["누계활동건"],
            "납입원": t["납입원"], "누계납입원": t["누계납입원"],
            "활동율": t_rate,
            "누계납입율": round(t["누계납입원"] / (t["누계활동건"] * 10000) * 100, 1) if t["누계활동건"] > 0 else 0.0,
        })
        return rows

    # --- HTML 렌더링 ---
    def render_ref_table(title, rows, member_type, month_label):
        hdr_bg = "#4a4a4a"
        dev_bg = "#808000"
        act_bg = "#4682B4"
        fee_bg = "#2E8B57"
        rate_bg = "#CD853F"
        th_base = "color:white;padding:6px 5px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;"
        th_sub = "color:white;padding:5px 4px;text-align:center;border:1px solid #ddd;font-weight:600;white-space:nowrap;font-size:11px;"

        html = f'<h4 style="margin-top:24px;margin-bottom:8px;">{title}</h4>'
        html += '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:0;">'
        html += '<thead><tr>'
        html += f'<th rowspan="2" style="background:{hdr_bg};{th_base}min-width:50px;">구분</th>'
        html += f'<th rowspan="2" style="background:{hdr_bg};{th_base}min-width:120px;">후원사업</th>'
        html += f'<th rowspan="2" style="background:{hdr_bg};{th_base}min-width:90px;">연도초<br>활동회원(건)</th>'
        html += f'<th colspan="4" style="background:{dev_bg};{th_base}">개발</th>'
        html += f'<th colspan="3" style="background:{act_bg};{th_base}">활동</th>'
        html += f'<th colspan="2" style="background:{fee_bg};{th_base}">회비</th>'
        html += f'<th colspan="2" style="background:{rate_bg};{th_base}">비율</th>'
        html += '</tr><tr>'
        for c in ["개발(명)", "개발(건)", "누계개발(명)", "누계개발(건)"]:
            html += f'<th style="background:{dev_bg};{th_sub}">{c}</th>'
        for c in ["활동(명)", "활동(건)", "누계활동(건)"]:
            html += f'<th style="background:{act_bg};{th_sub}">{c}</th>'
        for c in ["납입(원)", "누계납입(원)"]:
            html += f'<th style="background:{fee_bg};{th_sub}">{c}</th>'
        for c in ["활동율", "누계납입율"]:
            html += f'<th style="background:{rate_bg};{th_sub}">{c}</th>'
        html += '</tr></thead><tbody>'

        td = "padding:5px;border:1px solid #ddd;white-space:nowrap;"
        for r in rows:
            is_total = r["후원사업"] == "합계"
            bg = "background-color:#222222;color:white;font-weight:bold;" if is_total else ""
            html += '<tr>'
            html += f'<td style="{bg}{td}text-align:center;">{month_label}</td>'
            html += f'<td style="{bg}{td}text-align:left;">{r["후원사업"]}</td>'
            boy_str = "" if member_type == "신규회원" and not is_total else f'{r["boy"]:,.1f}'
            if member_type == "전체" and r["후원사업"] != "합계":
                boy_str = f'{r["boy"]:,.1f}'
            html += f'<td style="{bg}{td}text-align:right;">{boy_str}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["개발명"]:,}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["개발건"]:,.1f}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["누계개발명"]:,}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["누계개발건"]:,.1f}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["활동명"]:,}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["활동건"]:,.1f}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["누계활동건"]:,.1f}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["납입원"]:,.0f}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["누계납입원"]:,.0f}</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["활동율"]:.1f}%</td>'
            html += f'<td style="{bg}{td}text-align:right;">{r["누계납입율"]:.1f}%</td>'
            html += '</tr>'
        html += '</tbody></table>'
        return html

    month_label = f"{sel_month}월"

    new_rows = build_table_rows(REF_BIZ_LIST, "신규회원", dev_m, dev_y, act_data, boy_biz)
    old_rows = build_table_rows(REF_BIZ_LIST, "기존회원", dev_m, dev_y, act_data, boy_biz)
    total_rows = build_total_rows(new_rows[:-1], old_rows[:-1])

    st.markdown(render_ref_table("1) 신규회원", new_rows, "신규회원", month_label), unsafe_allow_html=True)
    st.divider()
    st.markdown(render_ref_table("2) 기존회원", old_rows, "기존회원", month_label), unsafe_allow_html=True)
    st.divider()
    st.markdown(render_ref_table("3) 전체회원 (신규 + 기존)", total_rows, "전체", month_label), unsafe_allow_html=True)
    st.caption("출처: BRONZE_CRM — MSTR FN_MM_SPNSR_DVLP + F_MM_SPNSR_ACT 로직 재현 (사단법인, 후원사업별×신규기존)")

    with st.expander("디버그: 데이터 매핑 진단", expanded=False):
        # 개발 데이터 — 매핑되지 않은 BIZ_NAME 확인
        unmapped_dev = df_all[df_all["후원사업"].isna() & df_all["BIZ_NAME"].notna()]["BIZ_NAME"].unique()
        if len(unmapped_dev) > 0:
            st.warning(f"개발 데이터 매핑 누락 BIZ_NAME ({len(unmapped_dev)}개): {', '.join(str(x) for x in unmapped_dev)}")
        else:
            st.success("개발 데이터: 모든 BIZ_NAME 매핑 완료")

        # 활동 데이터 — SQL에서 매핑 완료, REF_BIZ_LIST와 비교
        if not ref_df.empty:
            ref_biz_names = set(ref_df["BIZ_NAME"].unique())
            ref_list_set = set(REF_BIZ_LIST)
            extra_in_data = ref_biz_names - ref_list_set
            if extra_in_data:
                st.info(f"활동 데이터에만 있는 사업명 (표에 미표시): {', '.join(str(x) for x in extra_in_data)}")
            st.dataframe(ref_df, use_container_width=True, hide_index=True)

        # 개발건 합계 검증 (tab1 1-1/1-2와 비교)
        st.subheader("개발건 합계 검증")
        new_dev_total = sum(r["개발건"] for r in new_rows[:-1])
        old_dev_total = sum(r["개발건"] for r in old_rows[:-1])
        tab3_total = new_dev_total + old_dev_total
        tab1_total = df_month["개발건"].sum() if not df_month.empty else 0
        tab1_ytd_total = df_ytd["개발건"].sum() if not df_ytd.empty else 0
        st.text(f"tab3 당월 개발건 합계 (신규+기존): {tab3_total:,.1f}")
        st.text(f"tab1 당월 개발건 합계 (1-1 전체): {tab1_total:,.1f}")
        st.text(f"차이: {tab3_total - tab1_total:,.1f} (매핑 누락 BIZ_NAME에 의한 차이)")
        new_ytd_total = sum(r["누계개발건"] for r in new_rows[:-1])
        old_ytd_total = sum(r["누계개발건"] for r in old_rows[:-1])
        tab3_ytd = new_ytd_total + old_ytd_total
        st.text(f"tab3 누계 개발건 합계: {tab3_ytd:,.1f}")
        st.text(f"tab1 누계 개발건 합계 (1-2 전체): {tab1_ytd_total:,.1f}")
        st.text(f"차이: {tab3_ytd - tab1_ytd_total:,.1f}")
# Co-authored with CoCo
