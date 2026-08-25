-- WIDE_AD_DIGITAL: 디지털광고 위성 팩트(FAD_D) 평탄화 소비뷰 — 순서9-I 신설(DEC-8)
-- Co-authored with CoCo
-- grain = AD_PERF_DK (FAD_D 와 1:1). 원천유형 DIGITAL 단독 지분이다.
-- 🔴 행수를 여기에 적지 않는다(규칙 7) — 종전 하드코딩이 재적재로 stale 이 됐다. 규모는 이슈원장 §O51-F.
--
-- ⚠️ 설계 의도: 분석가·SV·Agent 가 **이 뷰 하나로 디지털광고 분석을 끝낼 수 있게** 만든다.
--    위성은 코어와 1:1 이므로 코어 measure 를 함께 노출해도 fan-out 이 없다.
--    → "페이지유형별 CTR", "광고그룹별 전환수" 같은 질문에 조인 없이 답할 수 있다.
-- ⚠️ 중복 합산 금지: 코어 measure 는 `WIDE_AD_PERFORMANCE` 에도 존재한다. 두 뷰를 함께 합산하면
--    디지털 행이 이중 계상된다. **전체 광고 집계는 코어 뷰만** 사용할 것.
-- ⚠️ 기기축 동반: 디지털은 기기(M/PC)가 실존하므로 DEVICE_TYPE 을 노출한다(DEC-10 실배선).
-- ⚠️ **비율 지표 사용 원칙(DEC-9)**: `_SRC` 는 대행사가 계산해 넘긴 값으로 **비가산(N)**이다.
--    집계 시에는 반드시 base 로 재계산할 것 — 예: CTR = SUM(CLICKS)/SUM(IMPRESSIONS).
--    `_SRC` 는 대행사 산식과 DW 산식을 **대조**하는 용도이며, 행 단위 참조만 유효하다.
--    VTR_SRC 는 base 가 원천에 없어 재계산이 불가하다(대조 대상 아님).
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-10 O51-F] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.
--   🔄 종전 「DROP 예정」 결정 철회(2026-08-10): 이 뷰는 dbt 모델이라 물리 DROP 은 다음 build 가 되살리며,
--     DEC-8/DEC-10 이 위성 단독 완결을 설계 의도로 명시한다. 보존 + COMMENT 이관으로 확정했다.


select
    g.AD_PERF_DK,
    f.AD_SOURCE_TYPE,
    f.PERF_DATE_SK,
    -- [코어 measure] 위성과 1:1 이므로 동반 노출 안전. 비율 재계산의 base 이기도 하다.
    f.AD_COST, f.IMPRESSIONS, f.CLICKS,
    f.GA_CONV_MEMBERS, f.GA_CONV_CNT,
    -- [위성 고유속성]
    g.PAGE_TYPE, g.AD_GROUP_NM, g.GROUP_DIV, g.CREATIVE_TYPE, g.AD_TYPE_NM,
    g.READ_CNT, g.MEDIA_POTENTIAL_CUST_CNT, g.CRM_DEV_CNT,
    -- [대행사 산정 _SRC] 전량 비가산 N — 집계 금지, 대조용
    g.CTR_SRC, g.CVR_SRC, g.CPC_SRC, g.CPM_SRC, g.CPA_SRC,
    g.DEV_UNIT_PRICE_SRC, g.VTR_SRC,
    g.DW_SOURCE_SYSTEM,
    -- [차원 속성] 단독 사용 가능하도록 동반
    d.FULL_DATE           as PERF_FULL_DATE,
    d.YEAR                as PERF_YEAR,
    d.MONTH               as PERF_MONTH,
    d.QUARTER             as PERF_QUARTER,
    d.IS_HOLIDAY          as PERF_IS_HOLIDAY,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    ac.MEDIA_NAME         as AD_MEDIA_NAME,
    ac.CREATIVE           as AD_CREATIVE,
    dv.DEVICE_TYPE        as DEVICE_TYPE
from GN_DW.GOLD.FACT_AD_DIGITAL g
join      GN_DW.GOLD.FACT_AD_PERFORMANCE f  on g.AD_PERF_DK    = f.AD_PERF_DK
left join GN_DW.GOLD.DIM_DATE            d  on f.PERF_DATE_SK  = d.DATE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN        c  on f.CAMPAIGN_SK   = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_AD_CREATIVE     ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
left join GN_DW.GOLD.DIM_DEVICE          dv on f.DEVICE_SK     = dv.DEVICE_SK