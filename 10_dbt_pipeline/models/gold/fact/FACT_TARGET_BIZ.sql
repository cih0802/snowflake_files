-- FACT_TARGET_BIZ: 사업목표 팩트 (ERP_BIZ_TARGET, 월×조직×후원사업×캠페인) — E-6 원천부재 스키마-only (현재 0행)
-- Co-authored with CoCo
-- 🔴 설계충돌(단위): SILVER=금액(TARGET_AMT 원단위) vs GOLD measure=건(#152~155 ANNUAL/SUPP_GOAL_CNT).
--    FACT_BUDGET "재무 오귀속 방지" 원칙 준수 → 금액을 건 슬롯에 강제매핑 금지. 건 measure는 원천부재로 NULL.
--    해소: GOLD DDL에 TARGET_AMT(금액) measure 신설 후 배선(1줄) 또는 현업이 '건' 목표 제공 시 매핑. (E-6/문서40)
-- 🔷 조인키: SILVER는 이름만 제공(조직=이름·코드X, 문서32 크로스워크). DIM BK(코드)가 아닌 이름 컬럼에 조인.
--    ORG=본부/지부 grain vs DIM_ORG.DEPARTMENT=부서 grain 불일치 가능 → 미매칭 시 Unknown(0). 크로스워크 확보 시 교정.
{{ config(
    tags=['gold_pending']
) }}

with t as (
    select * from {{ ref('ERP_BIZ_TARGET') }}
)

select
    COALESCE({{ month_key_clamp('TRY_TO_NUMBER(t.MONTH_KEY)') }}, 0)  as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,            -- 이름 크로스워크(미매칭→0)
    COALESCE(s.SPONSORSHIP_SK, 0)                  as SPONSORSHIP_SK,    -- 이름 매칭(미매칭→0)
    c.CAMPAIGN_SK                                  as CAMPAIGN_SK,       -- 선택 grain: 무매핑=NULL(N/A)
    CAST(NULL AS NUMBER(18,4))                     as ANNUAL_GOAL_CNT,   -- ⚠️ 단위충돌: 금액≠건 → 미매핑(원천부재)
    CAST(NULL AS NUMBER(18,4))                     as SUPP_GOAL_CNT,     -- ⚠️ 추경 건 원천부재
    CAST(NULL AS NUMBER(18,4))                     as ANNUAL_CUM_GOAL_CNT, -- ⚠️ 누계 건 원천부재
    CAST(NULL AS NUMBER(18,4))                     as SUPP_CUM_GOAL_CNT, -- ⚠️ 추경누계 건 원천부재
    {{ gold_meta('ERP') }}
from t
left join {{ ref('DIM_ORG') }} o
    on o.DEPARTMENT = t.ORG_NM
left join {{ ref('DIM_SPONSORSHIP') }} s
    on s.SPONSORSHIP_NAME = t.SPONSOR_BIZ_NM
left join {{ ref('DIM_CAMPAIGN') }} c
    on c.CAMPAIGN_NAME = t.CAMPAIGN_NM
