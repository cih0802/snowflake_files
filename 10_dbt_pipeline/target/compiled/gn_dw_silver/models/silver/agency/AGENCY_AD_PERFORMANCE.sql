-- AGENCY_AD_PERFORMANCE: 광고성과 공통 = DIGITAL ∪ REBROADCAST ∪ VIDEO (원천 1행 grain), 정본 09 STEP5.
-- Co-authored with CoCo
-- 연·월 = DATE 파생(텍스트 파싱 금지) · 인입콜 TRY_TO_NUMBER · 대행사 파생지표는 위성으로 분리(DEC-9).
-- ⚠️ [2026-07-28 DEC-11] 원천을 BRONZE 직접참조 → **staging 3종 ref** 로 변경했다.
--    이유: AD_PERF_DK 를 staging 이 단일지점 발급하므로, 코어가 BRONZE 를 다시 읽으면 DK 가 어긋난다.
-- ⚠️ [2026-07-28 DEC-8] AD_PERF_DK(행 식별자)·AD_SOURCE_TYPE(출처 명시축) 신설.
--    AD_SOURCE_TYPE 은 종전 SOURCE_SYSTEM 과 동일 값이나, GOLD 에서 DW_SOURCE_SYSTEM='AGENCY' 로
--    평탄화돼 소실되던 원천 테이블 출처를 팩트 degenerate 로 복원하기 위해 별도 컬럼으로 승격한다(§3-A-4).
-- ⚠️ [2026-07-28 O16 해소] REBROADCAST 분기의 CONV_MEMBER_CNT·CONV_UNIT_CNT 를 **NULL 로 환원**했다.
--    종전에는 REBRDC.DVLP_MBER_CNT(개발회원수)·DVLP_CNT(개발건수)를 이 자리에 위치매핑했고,
--    GOLD 가 GA_CONV_MEMBERS·GA_CONV_CNT 로 개명 노출해 **재방송 개발실적이 'GA 전환'으로 혼입**됐다
--    (실측 2026-07-28: GA_CONV_MEMBERS 의 28.60% · GA_CONV_CNT 의 60.32%가 REBRDC). 문서10 §8-I(8).
--    개발실적은 AGENCY_AD_BROADCAST.DVLP_MEMBER_CNT·DVLP_CNT 로 이관됐다.
--    ⚠️ 결과: GOLD GA_CONV_* 합계가 감소한다(설계상 의도된 교정 — 종전 값은 의미혼입 상태였다).
SELECT
    AD_PERF_DK                              AS AD_PERF_DK,
    AD_SOURCE_TYPE                                 AS AD_SOURCE_TYPE,
    'DIGITAL'                               AS SOURCE_SYSTEM,
    DATE                                    AS AD_DATE,
    YEAR(DATE)                              AS AD_YEAR,
    MONTH(DATE)                             AS AD_MONTH,
    NULLIF(NULLIF(NULLIF(TRIM(CMPGN_NM), ''), 'NULL'), '-')             AS CAMPAIGN_NM,
    NULLIF(NULLIF(NULLIF(TRIM(UPPER_CMPGN_NM), ''), 'NULL'), '-')       AS UPPER_CAMPAIGN_NM,
    NULLIF(NULLIF(NULLIF(TRIM(MEDIA_NM), ''), 'NULL'), '-')             AS MEDIA_CHANNEL_NM,
    NULLIF(NULLIF(NULLIF(TRIM(DEVICE), ''), 'NULL'), '-')               AS DEVICE_NM,
    NULLIF(NULLIF(NULLIF(TRIM(MATR), ''), 'NULL'), '-')                 AS CREATIVE_NM,
    CAST(NULL AS VARCHAR)                   AS PROGRAM_NM,
    EXPS_CNT                                AS IMPRESSION_CNT,
    CLICK_CNT                               AS CLICK_CNT,
    GA_CONV_MBER_CNT                        AS CONV_MEMBER_CNT,      -- 진짜 GA 전환(명)
    CONV_VU_CNT                             AS CONV_UNIT_CNT,        -- 진짜 GA 전환(VU/건)
    CAST(NULL AS FLOAT)                     AS INBOUND_CALL_CNT,
    CAST(NULL AS FLOAT)                     AS CONV_CALL_CNT,
    CAST(NULL AS FLOAT)                     AS AD_CNT,
    GA_AD_COST                              AS AD_COST,
    'GA'                                    AS COST_TYPE,
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS'       AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    '843ce7ab-b507-4121-a0e3-e64a56430f9c'                   AS DW_BATCH_ID
FROM GN_DW.SILVER.AGENCY_AD_ROW_DGT

UNION ALL

SELECT
    AD_PERF_DK,
    AD_SOURCE_TYPE,
    'REBROADCAST',
    DATE,
    YEAR(DATE),
    MONTH(DATE),
    CAST(NULL AS VARCHAR),                                  -- CAMPAIGN_NM: 원천 부재
    CAST(NULL AS VARCHAR),                                  -- UPPER_CAMPAIGN_NM: 원천 부재
    NULLIF(NULLIF(NULLIF(TRIM(CHNNL_CMPNY), ''), 'NULL'), '-'),                         -- MEDIA_CHANNEL_NM
    CAST(NULL AS VARCHAR),                                  -- DEVICE_NM: 방송=기기 개념 없음(DEC-10)
    NULLIF(NULLIF(NULLIF(TRIM(BRDC_NM), ''), 'NULL'), '-'),                             -- CREATIVE_NM
    NULLIF(NULLIF(NULLIF(TRIM(BRDC_NM), ''), 'NULL'), '-'),                             -- PROGRAM_NM
    CAST(NULL AS FLOAT),                                    -- IMPRESSION_CNT: 원천 부재
    CAST(NULL AS FLOAT),                                    -- CLICK_CNT: 원천 부재
    CAST(NULL AS FLOAT),                                    -- CONV_MEMBER_CNT: O16 — GA 개념 없음(개발실적은 FAD_B)
    CAST(NULL AS FLOAT),                                    -- CONV_UNIT_CNT:   O16 — GA 개념 없음(개발실적은 FAD_B)
    TRY_TO_NUMBER(NULLIF(NULLIF(NULLIF(TRIM(INBOUND_CALL_CNT), ''), 'NULL'), '-')),     -- 실측 REBRDC=TEXT
    CAST(NULL AS FLOAT),                                    -- CONV_CALL_CNT: 영상 전용
    AD_CNT,
    BRDC_SCHDL_COST,
    '편성',
    'AGENCY',
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS',
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    '843ce7ab-b507-4121-a0e3-e64a56430f9c'
FROM GN_DW.SILVER.AGENCY_AD_ROW_REBRDC

UNION ALL

SELECT
    AD_PERF_DK,
    AD_SOURCE_TYPE,
    'VIDEO',
    BRDC_DATE,
    YEAR(BRDC_DATE),
    MONTH(BRDC_DATE),
    NULLIF(NULLIF(NULLIF(TRIM(MKT_CMPGN_NM), ''), 'NULL'), '-'),
    NULLIF(NULLIF(NULLIF(TRIM(UPPER_CMPGN_NM), ''), 'NULL'), '-'),
    NULLIF(NULLIF(NULLIF(TRIM(CHNNL_NM), ''), 'NULL'), '-'),
    CAST(NULL AS VARCHAR),                                  -- DEVICE_NM: 방송=기기 개념 없음(DEC-10)
    NULLIF(NULLIF(NULLIF(TRIM(MATR_NM), ''), 'NULL'), '-'),
    NULLIF(NULLIF(NULLIF(TRIM(SCHDL_NM), ''), 'NULL'), '-'),
    CAST(NULL AS FLOAT),                                    -- IMPRESSION_CNT: 원천 부재
    CAST(NULL AS FLOAT),                                    -- CLICK_CNT: 원천 부재
    CAST(NULL AS FLOAT),                                    -- CONV_MEMBER_CNT: GA 개념 없음
    CAST(NULL AS FLOAT),                                    -- CONV_UNIT_CNT:   GA 개념 없음
    INBOUND_CALL_CNT,
    CONV_CALL_CNT,
    AD_CNT,
    ACTL_PUR_AD_COST_KRW,
    '집행',
    'AGENCY',
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS',
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    '843ce7ab-b507-4121-a0e3-e64a56430f9c'
FROM GN_DW.SILVER.AGENCY_AD_ROW_VIDEO