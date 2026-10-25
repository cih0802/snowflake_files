-- =============================================================================
-- Purpose    : BRONZE VIDEO 전 37컬럼 무손실 staging + AD_PERF_DK 발급 (DEC-11 · 설계 §3-A-7)
-- Target     : SILVER.AGENCY_AD_ROW_VIDEO (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source bronze_agency.VIDEO_AD_CMPGN_DTLS
-- Issue      : DEC-11, O182
-- =============================================================================
-- AGENCY_AD_ROW_VIDEO: BRONZE VIDEO 전 37컬럼 무손실 staging + AD_PERF_DK 발급 (DEC-11 · 설계 §3-A-7)
-- WARN: [2026-09-28 O182] 원천 12번 재편(32→37컬럼) 반영 — 원천 이름 그대로 보존.
--    제거 6 = DUR_PD_MATR_CHN · CONV_CALL_CNT · BRDC_MT · CTV_DIV_NM · MKT_CMPGN_NM · SPNSR_BSNS_NM
--    개명 2 = ACTL_PUR_AD_COST_KRW→LAST_AD_COST('최종광고비') · CPC(TEXT)→CPC_CALL_CNT(FLOAT 'CPC_CALL')
--    신규 11 = MONTH · AD_TY_NM(TV/CTV/기타/미확인) · BDGT_SOURCE_NM · DEVICE_NM · DAY · SPNSER_CNT('후원자수')
--            · DVLP_CNT('개발건수') · CMPGN_NM · MATR_TY_NM · EXPSR_CNT('노출수') · CLICK_CNT
--    WARN: 실측(2026-09-28): 46,353행 · `BRDC_DATE` NULL 3,336행 — 전건 AD_TY_NM='CTV' 계열 시트이며
--       텍스트 `YEAR`·`MONTH`('03월' 형태)·`DAY` 는 채워져 있다 ⇒ 날짜 보정은 코어에서 한다.
-- WARN: AD_PERF_DK **발급 단일지점** — 코어(FAD)·위성(FAD_B)이 동일 DK 를 쓰도록 여기서만 계산한다.
-- WARN: 원천 무손실: BRONZE 37컬럼을 이름 그대로 보존(개명·형변환 금지). 정제는 하류에서.
-- WARN: DUP_SEQ: 전컬럼 중복 실측 30그룹·최대 3중복 → 해시 단독으로는 충돌하므로 순번 결합 필수.
-- WARN: [2026-10-23 O260] 원천 13번 개명 — 19번째 `UPPER_CMPGN_NM`('상위캠페인') → `UPPER_CMPGN_CD`('상위캠페인코드').
--    값은 원래 코드였다(FACT_AD_PERFORMANCE O238 video_code_mk 가 UPPER_CODE 로 조인) ⇒ 의미 변화 없음 · 이름만 원천에 맞춘다.
--    🔴 ROW_HASH 는 OBJECT_CONSTRUCT(*) 의 **키 이름까지** 해시한다 ⇒ 값이 있는 행의 AD_PERF_DK 가 전부 바뀐다.
--       DK 는 build 마다 재계산되는 degenerate 키라 하류(FACT·위성)는 같은 build 에서 함께 바뀐다 — DK 를 외부에 보관한 곳이 있으면 재매핑 대상.
--    실측(값 분포·DK 변경 행수)은 원천 반영 계정에서 한다(O259 D4 · 2026-10-23 새 개발계 UM80684 = GN_DW 미구축).
WITH src AS (
    SELECT
        CHNNL_NM                AS CHNNL_NM,
        DOW                     AS DOW,
        BRDC_DATE               AS BRDC_DATE,
        TIME_RNG                AS TIME_RNG,
        DAY_DIV_NM              AS DAY_DIV_NM,
        PRG_STRT_TIME           AS PRG_STRT_TIME,
        SCHDL_NM                AS SCHDL_NM,
        CM                      AS CM,
        CM_AREA                 AS CM_AREA,
        AD_STRT_TIME            AS AD_STRT_TIME,
        AD_END_TIME             AS AD_END_TIME,
        SPOT_TY                 AS SPOT_TY,
        AD_VIEW_RT              AS AD_VIEW_RT,
        AD_CNT                  AS AD_CNT,
        AD_SEC                  AS AD_SEC,
        LAST_AD_COST            AS LAST_AD_COST,
        INBOUND_CALL_CNT        AS INBOUND_CALL_CNT,
        CPC_CALL_CNT            AS CPC_CALL_CNT,
        UPPER_CMPGN_CD          AS UPPER_CMPGN_CD,          -- O260: 구 UPPER_CMPGN_NM
        MATR_NM                 AS MATR_NM,
        DMST_OVSEA_DIV_NM       AS DMST_OVSEA_DIV_NM,
        BSNS_CASE_DIV_NM        AS BSNS_CASE_DIV_NM,
        CMPGN_TY_NM             AS CMPGN_TY_NM,
        CHNNL_CMPNY_TY_NM       AS CHNNL_CMPNY_TY_NM,
        WEEK                    AS WEEK,
        MONTH                   AS MONTH,
        AD_TY_NM                AS AD_TY_NM,
        BDGT_SOURCE_NM          AS BDGT_SOURCE_NM,
        DEVICE_NM               AS DEVICE_NM,
        YEAR                    AS YEAR,
        DAY                     AS DAY,
        SPNSER_CNT              AS SPNSER_CNT,
        DVLP_CNT                AS DVLP_CNT,
        CMPGN_NM                AS CMPGN_NM,
        MATR_TY_NM              AS MATR_TY_NM,
        EXPSR_CNT               AS EXPSR_CNT,
        CLICK_CNT               AS CLICK_CNT,
        MD5(TO_JSON(OBJECT_CONSTRUCT(*)))   AS ROW_HASH,
        -- OBJECT_CONSTRUCT 는 NULL 값을 키에서 뺀다 ⇒ 키 0개 = 37컬럼 전부 NULL 인 빈 행
        ARRAY_SIZE(OBJECT_KEYS(OBJECT_CONSTRUCT(*))) = 0   AS IS_ALL_NULL_ROW
    FROM {{ source('bronze_agency','VIDEO_AD_CMPGN_DTLS') }}
),
seq AS (
    SELECT
        src.*,
        ROW_NUMBER() OVER (PARTITION BY ROW_HASH ORDER BY NULL) AS DUP_SEQ
    FROM src
    --  [2026-10-13] 운영계 dbt build 실패 대응 — not_null_AGENCY_AD_PERFORMANCE_AD_DATE 165건.
    --   원인 = 원천에 전 컬럼 NULL 빈 행 165건 적재(엑셀 공백 행 추정) → 코어에서 AD_DATE NULL.
    --   처방 = 빈 행만 제외(값이 하나라도 있는 행은 보존 · 원천 무손실 원칙의 예외는 「정보 0 행」뿐).
    --   WARN: 빈 행끼리는 같은 ROW_HASH 라 그들만의 파티션이다 ⇒ 실데이터 행의 DUP_SEQ·AD_PERF_DK 는 불변.
    WHERE NOT IS_ALL_NULL_ROW
)

SELECT
    MD5('VIDEO' || '|' || ROW_HASH || '|' || DUP_SEQ)   AS AD_PERF_DK,
    'VIDEO'                 AS AD_SOURCE_TYPE,
    ROW_HASH                AS ROW_HASH,
    DUP_SEQ                 AS DUP_SEQ,
    CHNNL_NM, DOW, BRDC_DATE, TIME_RNG, DAY_DIV_NM, PRG_STRT_TIME, SCHDL_NM,
    CM, CM_AREA, AD_STRT_TIME, AD_END_TIME, SPOT_TY, AD_VIEW_RT, AD_CNT, AD_SEC,
    LAST_AD_COST, INBOUND_CALL_CNT, CPC_CALL_CNT, UPPER_CMPGN_CD, MATR_NM,
    DMST_OVSEA_DIV_NM, BSNS_CASE_DIV_NM, CMPGN_TY_NM, CHNNL_CMPNY_TY_NM, WEEK, MONTH,
    AD_TY_NM, BDGT_SOURCE_NM, DEVICE_NM, YEAR, DAY, SPNSER_CNT, DVLP_CNT,
    CMPGN_NM, MATR_TY_NM, EXPSR_CNT, CLICK_CNT,
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS'     AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    '{{ invocation_id }}'                   AS DW_BATCH_ID
FROM seq
