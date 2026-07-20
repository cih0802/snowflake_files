-- FACT_TARGET_BIZ: 사업목표 팩트 (CRM_BIZ_TARGET, 월×조직×후원사업×캠페인) — 원천=CRM 확정(2026-07-20). CRM 신규 목표 테이블 입고 대기(E-6) 스키마-only (현재 0행)
-- Co-authored with CoCo
-- ✅ 단위 확정(2026-07-20): SILVER=건(TARGET_CNT) = GOLD measure(#152~155). 기존 "금액 vs 건" 단위충돌 해소 → TARGET_TYPE 피벗으로 건 measure 배선.
--    당초→ANNUAL_GOAL_CNT · 추경1차/2차→SUPP_GOAL_CNT. 누계(ANNUAL/SUPP_CUM)는 SV running sum(P7)로 파생 → 물리 NULL 유지.
--    ⚠️ 추경 다버전(1차·2차) 공존 시 SUM은 근사 — 최신버전 우선이 필요하면 SILVER에 CONFIRMED_DATE 반입 후 QUALIFY latest로 정제.
-- 🔷 조인키: SILVER는 이름 제공(조직=이름·코드 병행). DIM BK가 아닌 이름 컬럼에 조인. ORG=본부/지부 vs DIM_ORG.DEPARTMENT=부서 grain 불일치 가능 → 미매칭 Unknown(0). 크로스워크(문서32) 확보 시 교정.


with t as (
    select * from GN_DW.SILVER.CRM_BIZ_TARGET
)

select
    COALESCE(CASE WHEN TRY_TO_NUMBER(t.MONTH_KEY) BETWEEN 199101 AND 203512
          AND MOD(TRY_TO_NUMBER(t.MONTH_KEY), 100) BETWEEN 1 AND 12
         THEN TRY_TO_NUMBER(t.MONTH_KEY) END, 0)  as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,            -- 이름 크로스워크(미매칭→0)
    COALESCE(s.SPONSORSHIP_SK, 0)                  as SPONSORSHIP_SK,    -- 이름 매칭(미매칭→0)
    c.CAMPAIGN_SK                                  as CAMPAIGN_SK,       -- 선택 grain: 무매핑=NULL(N/A)
    SUM(CASE WHEN t.TARGET_TYPE = '당초'   THEN t.TARGET_CNT END)  as ANNUAL_GOAL_CNT,   -- 연사업목표(건) #152
    SUM(CASE WHEN t.TARGET_TYPE LIKE '추경%' THEN t.TARGET_CNT END) as SUPP_GOAL_CNT,     -- 추경목표(건) #153
    CAST(NULL AS NUMBER(18,4))                     as ANNUAL_CUM_GOAL_CNT, -- 누계(#154): SV running sum 파생(P7)
    CAST(NULL AS NUMBER(18,4))                     as SUPP_CUM_GOAL_CNT,   -- 누계(#155): SV running sum 파생(P7)
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '50eaa2d8-6f32-46e5-ad87-91e23c3b74a4'                    AS DW_BATCH_ID
from t
left join GN_DW.GOLD.DIM_ORG o
    on o.DEPARTMENT = t.ORG_NM
left join GN_DW.GOLD.DIM_SPONSORSHIP s
    on s.SPONSORSHIP_NAME = t.SPONSOR_BIZ_NM
left join GN_DW.GOLD.DIM_CAMPAIGN c
    on c.CAMPAIGN_NAME = t.CAMPAIGN_NM
group by 1, 2, 3, 4