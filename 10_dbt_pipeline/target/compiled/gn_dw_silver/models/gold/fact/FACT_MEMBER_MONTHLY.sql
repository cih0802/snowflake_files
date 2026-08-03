-- FACT_MEMBER_MONTHLY: 회원 월 팩트 (billing ∪ FME 스파인) — A1: 개발/중단 FME 롤업 + HAS_BILLING 출처플래그
-- Co-authored with CoCo
-- ✅ A1(2026-07-21): 스파인 = 회비(CRM_PAYMENT_BILLING) ∪ 개발/중단(FACT_MEMBER_EVENT 월 롤업).
--    · 개발/중단이 난 달(납입無 ~2.26M 월×회원)도 포함 → DEV/STOP 온전 집계(과소집계 해소).
--    · HAS_BILLING=TRUE  → 구 billing 스파인(≈37.79M)과 동일. 회비/청구/미납 지표 불변. (보수적 소비: WHERE HAS_BILLING)
--    · HAS_BILLING=FALSE → 개발/중단만 있는 월(회비 measure NULL). (정확 소비: 필터 없이 전체)
-- ⚠️ 스캐폴드 잔여(전건 0/NULL): ACTIVE/증감/누계/미납건·CAMPAIGN/SPONSORSHIP/PAYMENT_SK·DEV_TYPE·밴드·플래그
--    → 상태이력(CRM_MEMBER_STATUS_HIST)·금액변경(CRM_MEMBER_AMT_CHANGE) 원천 + O8 grain 규칙(B2) 후속.
-- ✅ W3(DEC-24, 2026-07-31): REASON_SK 배선 — 미납(F) 대표사유 = 최종차수(MBRFEE_SQNC 최대)의 결과코드.
--    코드그룹 매핑(SETLE_CD→PM002/PM032/PM018/PM033/PM019) + DIM_REASON 해시 조인.
--    🔴 F 행에 한정. S 행 매핑 시 라벨 의미 역전 — 절대 금지.
--    ⚠️ 대표 1개로 축약하므로 복수사유 1.45% 소실. 사유분포분석은 SILVER 직접 조회.
-- ✅ W4(DEC-22, 2026-07-31): ML 파생 4종 배선.
--    요건1 = AMT_INCREASE/DECREASE_CUM_CNT (월말까지 누적 증/감액 이력 횟수, CRM_MEMBER_AMT_CHANGE)
--    요건3 = PAID_SPONSOR_BIZ_CNT·IS_MULTI_PAID_BIZ (그 달 납입 발생 사업수, 회비·PAY_AMT>0 한정)
--    🔴 정본 (건)=약정금액÷10,000 과 다른 실제 개수·횟수 — INCREASE_CNT(#151)·DECREASE_CNT(#38)와 혼용 금지(CONF-2).
--    ⚠️ 요건2(연속미납횟수)는 스파인 sparse(gap>1 3.94%·최대370개월)로 run-length 오판 → W4 제외, dense 스파인 선행 필요.
-- ⚠️ DEV_CNT = FME 사건수(금액/10000 아님 — 06_DDL 주석/별도트랙).
-- 순서9(G-1/G-2 해소): incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
-- 순서9-C(#80/DEC-4): UNPAID_FLAG_EOM/BOM — 미납 = PAY_STAT_CD IN ('F', NULL).


with b as (
    select * from GN_DW.SILVER.CRM_PAYMENT_BILLING
),

-- 회비/청구 집계 (월×회원) — 구 로직 유지(멱등)
billing as (
    select
        COALESCE(CASE WHEN TRY_TO_NUMBER(MBRFEE_MT) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(MBRFEE_MT) END, CASE WHEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) END, 0) as MONTH_KEY,  -- 회비월 우선, 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월
        MBER_NO                                       as MEMBER_DK,
        SUM(PAY_AMT)                                  as PAID_FEE,
        SUM(RQEST_AMT)                                as BILLED_AMT,
        -- #80(DEC-4): 월×회원에 미납 청구행(PAY_STAT_CD='F' OR NULL)이 하나라도 있으면 월말 미납.
        BOOLOR_AGG(PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL)  as UNPAID_FLAG_EOM
    from b
    where MBER_NO is not null                         -- 순수 불량 5행 제외(NOT NULL MEMBER_DK)
    group by MONTH_KEY, MEMBER_DK
),

-- W3(DEC-24): 월×회원 대표 미납사유. F행 한정, 최종차수(MBRFEE_SQNC 최대)의 결과코드로 REASON_SK 산출.
-- DIM_REASON 직접 조인으로 FK 무결성 보장(해시 독립계산 시 33건 orphan 발생 → 방지).
reason_rep as (
    select
        ranked.MONTH_KEY, ranked.MEMBER_DK,
        COALESCE(dr.REASON_SK, 0) as REASON_SK
    from (
        select
            COALESCE(CASE WHEN TRY_TO_NUMBER(MBRFEE_MT) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(MBRFEE_MT) END, CASE WHEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) END, 0) as MONTH_KEY,
            MBER_NO as MEMBER_DK,
            CASE
                WHEN SETLE_CD = '1' AND LENGTH(RQEST_RST_CD) <= 2 THEN 'PM002'
                WHEN SETLE_CD = '1' AND LENGTH(RQEST_RST_CD) > 2  THEN 'PM032'
                WHEN SETLE_CD = '2'  THEN 'PM018'
                WHEN SETLE_CD = '12' THEN 'PM033'
                WHEN SETLE_CD = '5'  THEN 'PM019'
            END as CODE_GROUP,
            RQEST_RST_CD,
            ROW_NUMBER() OVER (
                PARTITION BY
                    COALESCE(CASE WHEN TRY_TO_NUMBER(MBRFEE_MT) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(MBRFEE_MT) END, CASE WHEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) END, 0),
                    MBER_NO
                ORDER BY MBRFEE_SQNC DESC NULLS LAST, RQEST_DE DESC, RQEST_RST_CD
            ) as rn
        from b
        where PAY_STAT_CD = 'F'
          and MBER_NO is not null
          and RQEST_RST_CD is not null
    ) ranked
    left join GN_DW.GOLD.DIM_REASON dr
        on dr.REASON_TYPE = ranked.CODE_GROUP
       and dr.REASON_CODE = ranked.RQEST_RST_CD
    where ranked.rn = 1
),

-- W4 요건3(DEC-22): 그 달 실제 납입한 후원사업 수 (회비 한정, PAY_AMT>0).
-- 🔴 약정 보유 사업수 아님 — 납입 발생 사업수. 정본 (건)=금액/10,000 과 무관한 실제 개수.
paid_biz as (
    select
        COALESCE(CASE WHEN TRY_TO_NUMBER(MBRFEE_MT) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(MBRFEE_MT), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(MBRFEE_MT) END, CASE WHEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(TO_CHAR(PAY_DE,'YYYYMM')) END, 0) as MONTH_KEY,
        MBER_NO                                       as MEMBER_DK,
        COUNT(DISTINCT SPNSR_BSNS_ID)                 as PAID_SPONSOR_BIZ_CNT
    from b
    where PAYMENT_TYPE = '회비'
      and MBER_NO is not null
      and PAY_AMT > 0
      and SPNSR_BSNS_ID is not null
    group by MONTH_KEY, MEMBER_DK
),

-- W4 요건1(DEC-22) step1: 금액변경 이력을 월×회원 증액/감액 횟수로 집계.
-- 범위 밖 발생일 88행(19000101 등)은 month_key_clamp → 0(Unknown월) 라우팅.
amt_month as (
    select
        COALESCE(CASE WHEN TRY_TO_NUMBER(SUBSTR(OCCRRNC_DE,1,6)) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(SUBSTR(OCCRRNC_DE,1,6)), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(SUBSTR(OCCRRNC_DE,1,6)) END, 0) as MONTH_KEY,
        MBER_NO                                            as MEMBER_DK,
        SUM(CASE WHEN RDCAMT_YN = 'N' THEN 1 ELSE 0 END)   as INC_CNT,
        SUM(CASE WHEN RDCAMT_YN = 'Y' THEN 1 ELSE 0 END)   as DEC_CNT
    from GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE
    where MBER_NO is not null
    group by MONTH_KEY, MEMBER_DK
),

-- 개발/중단 월 롤업 (월×회원) — FME(일 grain) → 월 집계. A1 핵심.
fme_rollup as (
    select
        FLOOR(DATE_SK / 100)                          as MONTH_KEY,   -- YYYYMMDD→YYYYMM (FME DATE_SK 는 이미 범위클램프; 0 → 0=Unknown월)
        MEMBER_DK,
        SUM(DEV_CNT)                                  as DEV_CNT,      -- 개발 사건수 합
        IFF(SUM(DEV_CNT) > 0, 1, 0)                    as DEV_MEMBERS,  -- 월×회원 grain: 개발발생 1/0 (다월 SUM 시 distinct 회원수)
        SUM(STOP_CNT)                                 as STOP_CNT,      -- 중단 사건수 합
        IFF(SUM(STOP_CNT) > 0, 1, 0)                   as STOP_MEMBERS
    from GN_DW.GOLD.FACT_MEMBER_EVENT
    group by MONTH_KEY, MEMBER_DK
),

-- 통합 스파인 = billing ∪ fme (월×회원 유일)
spine as (
    select MONTH_KEY, MEMBER_DK from billing
    union
    select MONTH_KEY, MEMBER_DK from fme_rollup
),

-- W4 요건1 step2: 월말까지 누적 증액/감액 횟수 (running total).
-- 🟢 sparse 스파인에서도 정확 — 직전 행을 참조하지 않고 "그 월 이하 전체 합"이라 결측월 영향 없음.
--    (요건2 연속미납은 반대로 직전 행 의존이라 gap 3.94%에서 오판 → W4 범위 제외, dense 스파인 선행 필요)
-- 축 = spine ∪ amt_month: 스파인에 없는 월의 변경 이력도 누적에 반영되도록 union 후 running sum.
amt_cum as (
    select
        ax.MEMBER_DK, ax.MONTH_KEY,
        SUM(COALESCE(am.INC_CNT, 0)) OVER (PARTITION BY ax.MEMBER_DK ORDER BY ax.MONTH_KEY
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  as AMT_INCREASE_CUM_CNT,
        SUM(COALESCE(am.DEC_CNT, 0)) OVER (PARTITION BY ax.MEMBER_DK ORDER BY ax.MONTH_KEY
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  as AMT_DECREASE_CUM_CNT
    from (
        select MEMBER_DK, MONTH_KEY from spine
        union
        select MEMBER_DK, MONTH_KEY from amt_month
    ) ax
    left join amt_month am on am.MEMBER_DK = ax.MEMBER_DK and am.MONTH_KEY = ax.MONTH_KEY
),

joined as (
    select
        sp.MONTH_KEY,
        sp.MEMBER_DK,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK, 0 as PAYMENT_SK,
        COALESCE(rr.REASON_SK, 0) as REASON_SK,   -- W3(DEC-24): 미납 대표사유. 비미납/미매핑=0
        COALESCE(fr.DEV_CNT, 0)      as DEV_CNT,
        COALESCE(fr.DEV_MEMBERS, 0)  as DEV_MEMBERS,
        COALESCE(fr.STOP_CNT, 0)     as STOP_CNT,
        0 as UNPAID_CNT,
        0 as ACTIVE_CNT, 0 as ACTIVE_MEMBERS, 0 as ACTIVE_CUM_CNT, 0 as ACTIVE_CUM_MEMBERS,
        0 as INCREASE_CNT, 0 as INCREASE_MEMBERS, 0 as DECREASE_CNT, 0 as CHURN_CNT,
        0 as YEAR_START_ACTIVE_CNT, 0 as YEAR_END_ACTIVE_CNT,
        0 as MONTH_END_ACTIVE_CNT, 0 as PREV_MONTH_END_ACTIVE_CNT,
        0 as CAMPAIGN_UNPAID_CNT, 0 as STATUS_UNPAID_CNT,
        0 as REGULAR_FEE, 0 as REGULAR_ONETIME_FEE, 0 as ONETIME_ONETIME_FEE,
        bl.PAID_FEE,
        bl.BILLED_AMT,
        0 as INBOUND_CALL_CNT, 0 as TS_CALL_CNT,       -- ⚠️ 비-CRM 수기 미수령(C-8)
        CAST(NULL AS VARCHAR)  as DEV_TYPE,
        CAST(NULL AS BOOLEAN)  as NEW_FLAG, CAST(NULL AS BOOLEAN) as INCREASE_FLAG, CAST(NULL AS BOOLEAN) as REDONATE_FLAG,
        CAST(NULL AS DATE)     as JOIN_DATE, CAST(NULL AS DATE) as STOP_DATE,
        CAST(NULL AS VARCHAR)  as AMOUNT_BAND1, CAST(NULL AS VARCHAR) as AMOUNT_BAND2,
        CAST(NULL AS VARCHAR)  as PERIOD_BAND1, CAST(NULL AS VARCHAR) as PERIOD_BAND2,
        0 as SPONSOR_MONTHS, 0 as SPONSOR_YEARS, 0 as PAID_MONTHS,
        CAST(NULL AS VARCHAR)  as NEW_EXISTING_FLAG,
        bl.UNPAID_FLAG_EOM,
        -- W4(DEC-22): ML 전용 파생 4종. 🔴 정본 (건)=금액/10,000 과 다른 실제 개수·횟수 (CONF-2 주의).
        COALESCE(ac.AMT_INCREASE_CUM_CNT, 0)           as AMT_INCREASE_CUM_CNT,
        COALESCE(ac.AMT_DECREASE_CUM_CNT, 0)           as AMT_DECREASE_CUM_CNT,
        -- HAS_BILLING=FALSE(개발/중단 전용 월)는 NULL — 0으로 채우면 "납입 사업 0개"로 오독되어 완납률 왜곡.
        CASE WHEN bl.MEMBER_DK IS NOT NULL THEN COALESCE(pb.PAID_SPONSOR_BIZ_CNT, 0) END  as PAID_SPONSOR_BIZ_CNT,
        CASE WHEN bl.MEMBER_DK IS NOT NULL THEN COALESCE(pb.PAID_SPONSOR_BIZ_CNT, 0) > 1 END as IS_MULTI_PAID_BIZ,
        -- A1: 출처 플래그. billing 매칭 행 존재 여부(billing MEMBER_DK 는 group 키라 매칭 시 non-null).
        IFF(bl.MEMBER_DK IS NOT NULL, TRUE, FALSE)     as HAS_BILLING,
        'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'caf0ed7e-1e99-4c1d-b479-e0fc6272f462'                    AS DW_BATCH_ID
    from spine sp
    left join billing    bl on sp.MONTH_KEY = bl.MONTH_KEY and sp.MEMBER_DK = bl.MEMBER_DK
    left join fme_rollup fr on sp.MONTH_KEY = fr.MONTH_KEY and sp.MEMBER_DK = fr.MEMBER_DK
    left join reason_rep rr on sp.MONTH_KEY = rr.MONTH_KEY and sp.MEMBER_DK = rr.MEMBER_DK
    left join paid_biz   pb on sp.MONTH_KEY = pb.MONTH_KEY and sp.MEMBER_DK = pb.MEMBER_DK
    left join amt_cum    ac on sp.MONTH_KEY = ac.MONTH_KEY and sp.MEMBER_DK = ac.MEMBER_DK
)

select
    j.*,
    -- #80 월초(BOM) = 전월말(EOM) 상태. 회원별 월순 LAG(union 스파인 전체 월 기준; 결측월은 직전 존재월 근사).
    LAG(j.UNPAID_FLAG_EOM) OVER (PARTITION BY j.MEMBER_DK ORDER BY j.MONTH_KEY)  as UNPAID_FLAG_BOM
from joined j