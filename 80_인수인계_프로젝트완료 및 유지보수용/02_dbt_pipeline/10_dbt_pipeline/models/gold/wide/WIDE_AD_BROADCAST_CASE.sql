-- WIDE_AD_BROADCAST_CASE: 재방송 사례 위성 팩트(FAD_BC) 평탄화 소비뷰 — 순서9-I 신설(DEC-8)
-- Co-authored with CoCo
-- grain = AD_PERF_DK × CASE_SEQ (FAD_BC 와 1:1, 코어에는 **1:N**). 실측 5,327행.
--
-- ⚠️ **코어 measure 를 의도적으로 노출하지 않는다.** 본 위성은 코어에 1:N 이므로 광고비·인입콜 등을
--    함께 두면 사례 수만큼 중복 합산(fan-out)된다. 형제 뷰(WIDE_AD_BROADCAST/DIGITAL)가 코어
--    measure 를 노출하는 것은 그쪽이 1:1 이기 때문이며, 본 뷰는 카디널리티가 달라 규칙이 반대다.
--    → 사례 속성 **분포·빈도 분석 전용**. 금액·건수 집계가 필요하면 `WIDE_AD_BROADCAST` 를 쓸 것.
-- ⚠️ 사례 건수를 셀 때도 주의: COUNT(*) 는 '사례 수'이지 '방송 횟수'가 아니다.
--    방송 횟수는 COUNT(DISTINCT AD_PERF_DK) 로 세야 한다.
-- ⚠️ 전 속성 NULL 인 사례는 애초에 미적재(희소행 방지) → 방송 1건당 사례 수는 0~3 로 가변이다.
-- ⚠️ 아동명(CASEn_CHILD_NM)은 **미노출** — PII 판정 대기(O14). SILVER staging 에 원형 보존됨.
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).
{{ config(
    materialized='gn_view_commented'
) }}

select
    bc.AD_PERF_DK,
    bc.CASE_SEQ,
    f.AD_SOURCE_TYPE,
    f.PERF_DATE_SK,
    -- [사례 속성 = 본 위성 고유]
    bc.BIZ_DIV, bc.FAMILY_TYPE, bc.APPEAL_POINT, bc.CASE_DIV,
    -- [방송 맥락] 사례를 해석하는 데 필요한 최소 속성만 형제 위성에서 동반 (measure 는 제외)
    b.RT_TYPE, b.PROGRAM_NM, b.CHANNEL_COMPANY, b.BROADCAST_DATE,
    bc.DW_SOURCE_SYSTEM,
    -- [차원 속성] 단독 사용 가능하도록 동반
    d.FULL_DATE           as PERF_FULL_DATE,
    d.YEAR                as PERF_YEAR,
    d.MONTH               as PERF_MONTH,
    d.QUARTER             as PERF_QUARTER,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME
from {{ ref('FACT_AD_BROADCAST_CASE') }} bc
join      {{ ref('FACT_AD_PERFORMANCE') }} f on bc.AD_PERF_DK   = f.AD_PERF_DK
left join {{ ref('FACT_AD_BROADCAST') }}   b on bc.AD_PERF_DK   = b.AD_PERF_DK
left join {{ ref('DIM_DATE') }}            d on f.PERF_DATE_SK  = d.DATE_SK
left join {{ ref('DIM_CAMPAIGN') }}        c on f.CAMPAIGN_SK   = c.CAMPAIGN_SK
