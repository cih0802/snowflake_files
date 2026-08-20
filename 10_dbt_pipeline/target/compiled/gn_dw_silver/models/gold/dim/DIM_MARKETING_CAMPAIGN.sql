-- DIM_MARKETING_CAMPAIGN: 마케팅캠페인 conformed 차원 — AGENCY(광고) ↔ CRM(개발실적) 결합축
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-06 O44] 신설 — 광고 ↔ CRM 후원 결합의 유일한 성립 grain
-- ----------------------------------------------------------------------------
-- 🔴 왜 신설하는가: `DIM_CAMPAIGN.MARKETING_CAMPAIGN` 은 **라벨 컬럼**이라 광고 팩트가
--   참조할 수 없다. 양측이 같은 SK 를 쓰게 하려면 독립 차원이어야 한다(conformed dimension).
--
-- 실측 근거(2026-08-06):
--   · 마스터 323행 — 차원으로 작기 때문에 브로드캐스트 조인으로 비용이 거의 없다
--   · CRM 개발실적 도달 = `DIM_CAMPAIGN` 경유 **2,278,685/2,291,878 = 99.42%**
--   · AGENCY 광고 도달 = `SILVER.AGENCY_AD_PERFORMANCE.CAMPAIGN_NM` 이름매칭 **218,402/243,545 = 89.7%**
--   · 마케팅캠페인 grain 결합 실측: 79 캠페인 · 광고행 216,481(폭발 0) ·
--     광고비 34,209,625,719원 · 개발 463,279건 → **개발단가 73,842원**
--
-- 🔴 이름매칭을 쓰는 이유와 그 한계(P36): AGENCY 원천 3종에 **캠페인 코드 컬럼이 0개**다
--   (`CMPGN_NM`·`UPPER_CMPGN_NM`·`MKT_CMPGN_NM` 전부 이름). 따라서 이름매칭이 유일한 경로이며
--   **10.3% 는 도달하지 못한다.** 커버리지를 「완전」으로 서술하지 말 것.
--
-- 순서9 규약: dim = incremental(merge) + full_refresh:false. 구조 소유주 = `03_top-down_gold/06_DDL.sql`.
-- ============================================================================


with m as (
    select * from GN_DW.SILVER.CRM_MARKETING_CAMPAIGN
),

-- 이 마케팅캠페인에 매달린 개발캠페인 수. 🔴 소비 측이 **팬아웃 위험을 차원에서 즉시 보도록**
--   차원에 실어 둔다(문서를 찾아가야만 알 수 있으면 아무도 모른다 — O44 P86-③).
-- 🔴 [2026-08-06 교정 P89] 종전에는 `ref('DIM_CAMPAIGN')` 을 읽었다 →
--   DIM_CAMPAIGN 이 이 차원의 `MKTG_CAMPAIGN_SK` 를 참조하므로 **dbt DAG 순환**이 되어
--   deploy 가 `Found a cycle: DIM_CAMPAIGN --> DIM_MARKETING_CAMPAIGN` 로 실패했다.
--   → 같은 사실을 **SILVER 원천에서 직접** 센다. 부수 이득: 종전은 라벨(`MK_CMPGN_NM`)로
--   조인했는데 지금은 **코드**(`MKTG_CMPGN_NM`)로 조인한다 — 라벨 조인은 P36 위반이었고
--   실제로 동명 마케팅캠페인 2건이 한 그룹으로 뭉쳐 322개로 집계되고 있었다(코드 기준 323).
dev_fan as (
    select TO_VARCHAR(MKTG_CMPGN_NM) as MK_CD, count(*) as CNT
    from GN_DW.SILVER.CRM_CAMPAIGN
    where MKTG_CMPGN_NM is not null
    group by 1
)

select
    ABS(HASH(COALESCE(CAST(m.MK_CMPGN_CD AS VARCHAR), '∅')))      as MKTG_CAMPAIGN_SK,
    m.MK_CMPGN_CD                         as MKTG_CAMPAIGN_BK,
    m.MK_CMPGN_NM                         as MKTG_CAMPAIGN_NAME,
    m.USE_YN                              as USE_YN,
    -- 🔴 팬아웃 경고축: 이 값이 1 보다 크면 **개발캠페인 단위로 광고비를 내리면 복제**된다.
    --   실측 2026-08-06 · **이 컬럼의 모집단 = 마스터 전체 323개**: 평균 105.0 · 최대 13,176 · 합 33,915.
    --   실측 2026-08-06 · **광고 도달분 81개 한정**: 평균 120.4 · 최대 901 · 합 9,750.
    --   ⚠️ 설계문서가 인용해 온 「9,037종 · 평균 118.9」은 **오늘 데이터로 재현되지 않는다**(P89).
    --      같은 문서의 `218,402/243,545 = 89.7%` 는 재현된다 — 즉 일부 수치만 낡았다.
    coalesce(f.CNT, 0)                    as DEV_CAMPAIGN_CNT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '17b6585e-5115-4071-a904-810c19eaeb12'                    AS DW_BATCH_ID
from m
left join dev_fan f on f.MK_CD = m.MK_CMPGN_CD

union all
-- unknown 멤버(SK=0): 팩트 MKTG_CAMPAIGN_SK=0(미매핑) 조인 유실 방지.
--   🔴 광고측 10.3% 미도달분이 여기 모인다 — 이 버킷을 「미집행」으로 읽으면 안 된다.
select 0, '(미매핑)', '(미매핑)', NULL, 0,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '17b6585e-5115-4071-a904-810c19eaeb12'                    AS DW_BATCH_ID