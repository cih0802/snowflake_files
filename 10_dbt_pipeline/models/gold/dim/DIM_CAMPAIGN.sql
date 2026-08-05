-- DIM_CAMPAIGN: 캠페인 차원 (CRM_CAMPAIGN 기반, 분류 4축 라벨)
-- Co-authored with CoCo
-- ⚠️ ORG_SK(주관조직 O10 미확정)=0 센티넬.
-- [2026-07-16 BRONZE 재입고 반영] 캠페인 분류가 원천에서 채워짐 → 3건 교정 + 2컬럼 신설:
--   1) CAMPAIGN_TYPE : CAST(CMPGN_CTGR_CD AS VARCHAR)(숫자코드 "17") → CMPGN_CTGR_NM(라벨) 로 교체.
--   2) BIZ_CASE_TYPE : CMPGN_TYPE1_BSN(국내/통합/해외) → CMPGN_TYPE2_NM(굿즈/기타/사례/사업) 로 **의미혼입 교정**.
--      종전 모델은 유형1을 사업/사례 자리에 넣었다(O16 과 동일한 위치매핑 오류). 전건 NULL 이라 무증상이었을 뿐이다.
--   3) DOMESTIC_OVERSEAS : CAST(NULL AS VARCHAR)(파생규칙 대기) → CMPGN_TYPE1_NM 으로 해소.
--   4) INFLOW_PATH(신설) : MM293 개발인입경로 라벨. ⚠️ 종전 여기 적혀 있던 *현업 "주요캠페인" 분류축*
--      표기는 2026-08-05 O37 에서 **거짓으로 판정·회수**했다(아래 O37 절 참조).
--   5) MARKETING_CAMPAIGN(신설) : MK_CMPGN_NM (Q16 해소).
-- ⚠️ 라벨 NULL 은 코드사전 미등재(고아)를 뜻한다 — 결측이 아니다.
-- [2026-08-05 O37] PARENT_CAMPAIGN_NAME 신설 + 거짓 주석 회수 2건.
--   1) PARENT_CAMPAIGN(=UPPER_CMPGN_CD)은 라벨이 아니라 **자기참조 코드**(값 도메인=CAMPAIGN_BK)다.
--      현업이 말하는 "주요캠페인"을 코드로만 보고 있었다 → 자기조인으로 라벨 신설(O25/G3 동일 패턴).
--      CRM_CAMPAIGN 은 CMPGN_CD 유일이므로 이 자기조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
--   2) 🔴 종전 주석 4)의 *INFLOW_PATH = 현업 "주요캠페인" 분류축* 은 **거짓이므로 회수**한다.
--      실제값이 디지털·방송·영상광고·지역개발·마케팅콜개발·대면모금·직원개발 = **모집 채널** 축이다.
--      "주요캠페인(캠페인카테고리)"에 해당하는 축은 CAMPAIGN_TYPE(MM294)이다(실측 확인).
{{ config(
    materialized='incremental',
    unique_key='CAMPAIGN_SK',
    tags=['gold_pending']
) }}

with c as (
    select * from {{ ref('CRM_CAMPAIGN') }}
),

-- [2026-08-05 O37] 상위캠페인 라벨 해소용. PK(CMPGN_CD) 유일 → fan-out 없음.
parent as (
    select CMPGN_CD as PARENT_CD, CMPGN_NM as PARENT_NM from {{ ref('CRM_CAMPAIGN') }}
),

-- [2026-08-05 O37] 홍보방법 라벨 = CM008. 하드코딩 CASE 금지(P31 — 사전과 조용히 갈라진다).
--   `DTL_CD_ID` 유일(119=119 실측)이라 fan-out 없음. USE_YN 무필터(프로젝트 규약).
--   🔴 종전에는 `PR_MTH_CD` 를 코드 그대로만 올려 라벨이 없었다 — 이 축을 SV 에 노출하면
--      Analyst 가 코드값을 추측해 0행 무증상 오답을 낸다(§6.9-(5)).
code_promo as (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'CM008'
)

select
    {{ gold_sk(['c.CMPGN_CD']) }}                 as CAMPAIGN_SK,
    c.CMPGN_CD                                    as CAMPAIGN_BK,
    c.BRND_NM                                     as BRAND,
    c.UPPER_CMPGN_CD                              as PARENT_CAMPAIGN,      -- 🔴 코드(라벨 아님)
    c.CMPGN_NM                                    as CAMPAIGN_NAME,
    c.PR_MTH_CD                                   as PROMO_METHOD,
    c.CMPGN_CTGR_NM                               as CAMPAIGN_TYPE,        -- MM294 카테고리 라벨 = 현업 "주요캠페인"
    c.CMPGN_TYPE1_NM                              as DOMESTIC_OVERSEAS,    -- MM295 국내/통합/해외
    c.CMPGN_TYPE2_NM                              as BIZ_CASE_TYPE,        -- MM296 굿즈/기타/사례/사업
    c.MBER_INFLOW_PATH_NM                         as INFLOW_PATH,          -- MM293 개발인입경로(=모집 채널)
    c.MK_CMPGN_NM                                 as MARKETING_CAMPAIGN,   -- Q16 마케팅캠페인
    TRY_TO_DATE(c.CMPGN_STRT_DE, 'YYYYMMDD')      as CAMPAIGN_OPEN_DATE,
    0                                             as ORG_SK,               -- ⚠️ 센티넬(O10 주관조직 미확정)
    -- [2026-08-05 O37] 상위캠페인 라벨. 상위가 없으면 NULL — '(미매핑)'으로 창작하지 않는다(P21).
    p.PARENT_NM                                   as PARENT_CAMPAIGN_NAME,
    -- [2026-08-05 O37] 홍보방법 라벨. 원천 코드가 없으면 NULL — '(미매핑)'으로 창작하지 않는다(P21).
    cp.DTL_CD_NM                                  as PROMO_METHOD_NAME,
    {{ gold_meta('CRM') }}
from c
left join parent p      on p.PARENT_CD  = c.UPPER_CMPGN_CD
left join code_promo cp on cp.DTL_CD_ID = c.PR_MTH_CD

union all
-- unknown 멤버(SK=0): 팩트 CAMPAIGN_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL,
    {{ gold_meta('CRM') }}
