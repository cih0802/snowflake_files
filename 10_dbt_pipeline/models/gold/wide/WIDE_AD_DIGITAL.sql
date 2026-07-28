-- WIDE_AD_DIGITAL: 디지털광고 위성 팩트(FAD_D) 평탄화 소비뷰 — 순서9-I 신설(DEC-8)
-- Co-authored with CoCo
-- grain = AD_PERF_DK (FAD_D 와 1:1). 실측 197,686행 (DGT).
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
{{ config(
    materialized='view',
    post_hook=[
      "COMMENT ON VIEW {{ this }} IS '디지털광고 위성 팩트 평탄화 (FAD_D × DATE·CAMPAIGN·AD_CREATIVE·DEVICE, grain=AD_PERF_DK, 197,686행). 코어 measure 동반 노출(1:1이라 fan-out 없음) — 단 WIDE_AD_PERFORMANCE 와 합산 시 이중계상 주의. _SRC 는 비가산(N), 집계는 base 재계산.'",
      "ALTER VIEW {{ this }} ALTER COLUMN AD_PERF_DK COMMENT '광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키', COLUMN AD_SOURCE_TYPE COMMENT '광고 원천유형 — 본 뷰는 DIGITAL 만', COLUMN PERF_DATE_SK COMMENT '광고 실적일 YYYYMMDD', COLUMN AD_COST COMMENT '[코어] GA 광고비(원)', COLUMN IMPRESSIONS COMMENT '[코어] 노출수 — CTR 분모', COLUMN CLICKS COMMENT '[코어] 클릭수 — CTR 분자', COLUMN GA_CONV_MEMBERS COMMENT '[코어] GA전환수(명) — CVR 분자(O16 교정 후 디지털 전용)', COLUMN GA_CONV_CNT COMMENT '[코어] GA전환수(건/VU) — CPA 분모(O16 교정 후 디지털 전용)', COLUMN PAGE_TYPE COMMENT '페이지유형', COLUMN AD_GROUP_NM COMMENT '광고그룹명', COLUMN GROUP_DIV COMMENT '그룹구분', COLUMN CREATIVE_TYPE COMMENT '소재유형(원천 표기)', COLUMN AD_TYPE_NM COMMENT '광고유형명(대행사 표기) — ⚠️AD_SOURCE_TYPE 과 다른 개념', COLUMN READ_CNT COMMENT '읽음수', COLUMN MEDIA_POTENTIAL_CUST_CNT COMMENT '매체 잠재고객수', COLUMN CRM_DEV_CNT COMMENT 'CRM 개발건수', COLUMN CTR_SRC COMMENT 'CTR(대행사 산정) — 비가산 N. DW 재계산=SUM(CLICKS)/SUM(IMPRESSIONS)', COLUMN CVR_SRC COMMENT 'CVR(대행사 산정) — 비가산 N. DW 재계산=SUM(GA_CONV_MEMBERS)/SUM(CLICKS)', COLUMN CPC_SRC COMMENT 'CPC(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(CLICKS)', COLUMN CPM_SRC COMMENT 'CPM(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(IMPRESSIONS)*1000', COLUMN CPA_SRC COMMENT 'CPA(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(GA_CONV_CNT)', COLUMN DEV_UNIT_PRICE_SRC COMMENT '개발단가(대행사 산정) — 비가산 N', COLUMN VTR_SRC COMMENT 'VTR(대행사 산정) — 비가산 N, base 부재로 재계산 불가', COLUMN DW_SOURCE_SYSTEM COMMENT '원천 시스템 식별', COLUMN PERF_FULL_DATE COMMENT 'DIM_DATE.FULL_DATE — 실적일 일자', COLUMN PERF_YEAR COMMENT 'DIM_DATE.YEAR — 실적일 년', COLUMN PERF_MONTH COMMENT 'DIM_DATE.MONTH — 실적일 월', COLUMN PERF_QUARTER COMMENT 'DIM_DATE.QUARTER — 실적일 분기', COLUMN PERF_IS_HOLIDAY COMMENT 'DIM_DATE.IS_HOLIDAY — 실적일 휴일여부', COLUMN CAMPAIGN_NAME COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명', COLUMN AD_MEDIA_NAME COMMENT 'DIM_AD_CREATIVE.MEDIA_NAME — 매체명', COLUMN AD_CREATIVE COMMENT 'DIM_AD_CREATIVE.CREATIVE — 소재', COLUMN DEVICE_TYPE COMMENT 'DIM_DEVICE.DEVICE_TYPE — M / PC (디지털은 기기 실존)'"
    ]
) }}

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
from {{ ref('FACT_AD_DIGITAL') }} g
join      {{ ref('FACT_AD_PERFORMANCE') }} f  on g.AD_PERF_DK    = f.AD_PERF_DK
left join {{ ref('DIM_DATE') }}            d  on f.PERF_DATE_SK  = d.DATE_SK
left join {{ ref('DIM_CAMPAIGN') }}        c  on f.CAMPAIGN_SK   = c.CAMPAIGN_SK
left join {{ ref('DIM_AD_CREATIVE') }}     ac on f.AD_CREATIVE_SK = ac.AD_CREATIVE_SK
left join {{ ref('DIM_DEVICE') }}          dv on f.DEVICE_SK     = dv.DEVICE_SK
