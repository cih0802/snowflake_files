-- O53 — `GOLD.WIDE_AD_COMBINED`(dbt 소유 GOLD 뷰) 모델 + yml columns[] 기계 생성.
-- Co-authored with CoCo
--
-- 무엇을 만드는가
--   광고 팩트 3종(FAP 코어 + FAD 디지털위성 + FAB 방송위성)을 `AD_PERF_DK` 로 1:1 pre-join 한
--   **51컬럼 GOLD 뷰**. SV_AD 의 새 base 다(재배선은 O53 6단계).
--
-- 왜 GOLD 뷰인가 (사용자 제약 3개를 동시에 만족하는 유일 형태)
--   ① 데이터 중복 저장 불가        → 뷰(물리 저장 0)
--   ② SV 는 GOLD 만 본다           → 스키마를 SERVING → GOLD 로 올린다
--   ③ 다음 주 신설 코드 즉시 반영   → dbt 모델 1곳 수정 + ref() 위상정렬·리니지·build 게이트
--   DEC-34 분류상 **③(팩트를 재구성 → ref() 필수)** 에 정확히 해당한다.
--   ⚠️ 대가: SV_AD 가 「dbt build 없이는 배포 불가」 계열로 편입된다.
--
-- 종전 대비 달라지는 것
--   · 스키마 SERVING → GOLD · 소유주 SQL 스크립트(05_7_SV_DDL_AD.sql 내부) → dbt 모델
--   · **방송 시간축 4컬럼 추가**(AD_START_TIME·AD_END_TIME·BROADCAST_DATE·PRG_START_TIME)
--     → helper 뷰가 이 4컬럼을 빼고 있어 SV_AD 에서 방송 시각 축이 도달 불가였다.
--
-- 문안: 신규 작성 0 — `06_DDL.sql` 의 세 팩트 인라인 COMMENT 를 파싱해 이관한다.
--   · 이름이 바뀐 2컬럼(BRDC_AD_VIEW_RT_SRC·BRDC_CPC_SRC)은 접두 사유를 덧붙인다.
--   · 방송 전용 컬럼에는 **디지털행 NULL = 원천 부재** 경고를 덧붙인다(P20 — 시간축 NULL 3분류).
--   · 시간축 4컬럼에는 **VIDEO 전용 · REBRDC 구조적 부재** 를 덧붙인다(원장 §429 기지 사실).
--
-- ⚠️ 컬럼 COMMENT 정본 = `_wide_schema.yml` columns[] (materialized='gn_view_commented').
--   SELECT 컬럼·순서를 바꾸면 `scripts/gen_o53_ad_combined.py` 로 **동시 재생성**할 것 —
--   Snowflake 는 CREATE VIEW 컬럼목록과 SELECT 개수·순서가 정확히 일치해야 한다.


select
    -- ── 코어(FAP) — 3원천 공통 ──
    fap.AD_PERF_DK,
    fap.PERF_DATE_SK,
    fap.CAMPAIGN_SK,
    fap.MKTG_CAMPAIGN_SK,
    fap.AD_CREATIVE_SK,
    fap.DEVICE_SK,
    fap.AD_COST,
    fap.IMPRESSIONS,
    fap.CLICKS,
    fap.INBOUND_CALL,
    fap.GA_CONV_MEMBERS,
    fap.GA_CONV_CNT,
    fap.DAY_OF_WEEK,
    fap.WEEK_OF_YEAR,
    fap.AD_SOURCE_TYPE,
    -- ── 디지털 위성(FAD) — 방송행은 NULL(원천 부재) ──
    dig.PAGE_TYPE,
    dig.AD_GROUP_NM,
    dig.GROUP_DIV,
    dig.CREATIVE_TYPE,
    dig.AD_TYPE_NM,
    dig.READ_CNT,
    dig.MEDIA_POTENTIAL_CUST_CNT,
    dig.CRM_DEV_CNT,
    dig.CTR_SRC,
    dig.CVR_SRC,
    dig.CPC_SRC,
    dig.CPM_SRC,
    dig.CPA_SRC,
    dig.DEV_UNIT_PRICE_SRC,
    dig.VTR_SRC,
    -- ── 방송 위성(FAB) — 디지털행은 NULL(원천 부재) · 시간축 4컬럼은 VIDEO 전용 ──
    brc.TIME_BAND,
    brc.CM_POSITION,
    brc.RT_TYPE,
    brc.AD_START_TIME,
    brc.AD_END_TIME,
    brc.BROADCAST_DATE,
    brc.PROGRAM_NM,
    brc.CHANNEL_COMPANY,
    brc.CHANNEL_COMPANY_TYPE,
    brc.SPOT_TYPE,
    brc.DURATION_SEC,
    brc.DAY_DIV,
    brc.PRG_START_TIME,
    brc.CTV_DIV,
    brc.BRDC_DIV,
    brc.AD_CNT,
    brc.CONV_CALL_CNT,
    brc.DVLP_MEMBER_CNT,
    brc.DVLP_CNT,
    brc.AD_VIEW_RT_SRC as BRDC_AD_VIEW_RT_SRC,
    brc.CPC_SRC as BRDC_CPC_SRC
from GN_DW.GOLD.FACT_AD_PERFORMANCE fap
-- 위성은 AD_PERF_DK 로 원천유형별 완전분할이라 LEFT JOIN 이 행수를 늘리지 않는다(fan-out 0).
--   1:N 위성인 FACT_AD_BROADCAST_CASE 는 **의도적으로 제외**한다 — 사례 수만큼 광고비가 복제된다.
left join GN_DW.GOLD.FACT_AD_DIGITAL   dig on fap.AD_PERF_DK = dig.AD_PERF_DK
left join GN_DW.GOLD.FACT_AD_BROADCAST brc on fap.AD_PERF_DK = brc.AD_PERF_DK