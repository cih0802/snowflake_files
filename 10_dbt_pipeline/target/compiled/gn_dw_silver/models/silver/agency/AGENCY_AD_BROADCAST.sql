-- AGENCY_AD_BROADCAST: 방송광고(VIDEO ∪ REBRDC) 고유속성 → GOLD FACT_AD_BROADCAST
-- Co-authored with CoCo
-- 설계: DEC-8(위성 분리) · DEC-9(_SRC 보존) · 설계 §3-A-2
-- ⚠️ AD_PERF_DK 는 staging 이 발급한 값을 **그대로 승계**(재계산 금지) → 코어 FAD 와 1:1 보장.
-- ⚠️ 두 원천의 컬럼 집합이 다르므로, 각 분기에서 **없는 속성은 명시적으로 NULL** 로 둔다.
--    이 NULL 은 '원천에 개념이 없음'이며 결측이 아니다(예: RT_TYPE 은 재방송 전용, SPOT_TYPE 은 영상 전용).
-- ⚠️ O16 해소 — REBRDC 개발실적(DVLP_MEMBER_CNT·DVLP_CNT)을 **여기 별도 컬럼으로 분리**한다.
--    종전에는 SILVER UNION 이 이 두 값을 DIGITAL 의 GA 지표 자리에 위치매핑하고 GOLD 가
--    GA_CONV_MEMBERS·GA_CONV_CNT 로 개명 노출해, 재방송 개발실적이 'GA 전환'으로 혼입됐다
--    (실측 2026-07-28: GA_CONV_MEMBERS 의 28.60% · GA_CONV_CNT 의 60.32%). 문서10 §8-I(8).
--    → 코어 GA_CONV_* 는 DIGITAL 전용으로 환원, 개발실적은 본 위성이 고유 이름으로 보유한다.
--    VIDEO 분기에서는 개발실적 개념이 없어 NULL 이다.
SELECT
    AD_PERF_DK                                  AS AD_PERF_DK,
    NULLIF(NULLIF(NULLIF(TRIM(TIME_RNG), ''), 'NULL'), '-')                 AS TIME_BAND,               -- 시간대 ← VIDEO.TIME_RNG
    NULLIF(NULLIF(NULLIF(TRIM(CM_AREA), ''), 'NULL'), '-')                  AS CM_POSITION,             -- CM위치 ← VIDEO.CM_AREA
    CAST(NULL AS VARCHAR)                       AS RT_TYPE,                 -- 재방송 전용 → VIDEO 는 개념 없음
    NULLIF(NULLIF(NULLIF(TRIM(AD_STRT_TIME), ''), 'NULL'), '-')             AS AD_START_TIME,           -- 광고시작시간
    NULLIF(NULLIF(NULLIF(TRIM(AD_END_TIME), ''), 'NULL'), '-')              AS AD_END_TIME,             -- 광고종료시간
    BRDC_DATE                                   AS BROADCAST_DATE,          -- 송출일(≠실적일)
    NULLIF(NULLIF(NULLIF(TRIM(SCHDL_NM), ''), 'NULL'), '-')                 AS PROGRAM_NM,              -- 편성/프로그램명
    NULLIF(NULLIF(NULLIF(TRIM(CHNNL_NM), ''), 'NULL'), '-')                 AS CHANNEL_COMPANY,         -- 채널사
    NULLIF(NULLIF(NULLIF(TRIM(CHNNL_CMPNY_TY_NM), ''), 'NULL'), '-')        AS CHANNEL_COMPANY_TYPE,    -- 채널사유형
    NULLIF(NULLIF(NULLIF(TRIM(SPOT_TY), ''), 'NULL'), '-')                  AS SPOT_TYPE,               -- SPOT유형
    TRY_TO_NUMBER(NULLIF(NULLIF(NULLIF(TRIM(AD_SEC), ''), 'NULL'), '-'))    AS DURATION_SEC,            -- 광고 초수 ← VIDEO.AD_SEC(TEXT)
    NULLIF(NULLIF(NULLIF(TRIM(DAY_DIV_NM), ''), 'NULL'), '-')               AS DAY_DIV,                 -- 요일구분(평일/주말)
    NULLIF(NULLIF(NULLIF(TRIM(PRG_STRT_TIME), ''), 'NULL'), '-')            AS PRG_START_TIME,          -- 프로그램 시작시간
    NULLIF(NULLIF(NULLIF(TRIM(CTV_DIV_NM), ''), 'NULL'), '-')               AS CTV_DIV,                 -- CTV구분
    CAST(NULL AS VARCHAR)                       AS BRDC_DIV,                -- 재방송 전용 → VIDEO 는 개념 없음
    AD_CNT                                      AS AD_CNT,                  -- 광고횟수
    CONV_CALL_CNT                               AS CONV_CALL_CNT,           -- 전환콜(인입콜과 별개)
    CAST(NULL AS FLOAT)                         AS DVLP_MEMBER_CNT,         -- O16: 재방송 전용 개발회원수
    CAST(NULL AS FLOAT)                         AS DVLP_CNT,                -- O16: 재방송 전용 개발건수
    AD_VIEW_RT                                  AS AD_VIEW_RT_SRC,          -- N(비가산) 재계산 불가
    TRY_TO_NUMBER(NULLIF(NULLIF(NULLIF(TRIM(CPC), ''), 'NULL'), '-'))       AS CPC_SRC,                 -- N(비가산) DW=AD_COST/CLICKS
    'AGENCY'                                    AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS'         AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ          AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ          AS DW_UPDATE_TS,
    '669c7dcc-1689-4020-9ee5-1be787ae11b1'                       AS DW_BATCH_ID
FROM GN_DW.SILVER.AGENCY_AD_ROW_VIDEO

UNION ALL

SELECT
    AD_PERF_DK,
    -- 재방송 시간대: 구분명 우선, 없으면 방송시각 사용(설계 §3-A: TIME_RNG_DIV_NM·BRDC_TIME)
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM(TIME_RNG_DIV_NM), ''), 'NULL'), '-'), NULLIF(NULLIF(NULLIF(TRIM(BRDC_TIME), ''), 'NULL'), '-')),
    CAST(NULL AS VARCHAR),                                                  -- CM_POSITION: 영상 전용
    NULLIF(NULLIF(NULLIF(TRIM(RE_BRDC_TY_NM), ''), 'NULL'), '-'),                                       -- RT_TYPE
    CAST(NULL AS VARCHAR),                                                  -- AD_START_TIME: 영상 전용
    CAST(NULL AS VARCHAR),                                                  -- AD_END_TIME: 영상 전용
    DATE,                                                                   -- BROADCAST_DATE ← REBRDC.DATE
    NULLIF(NULLIF(NULLIF(TRIM(BRDC_NM), ''), 'NULL'), '-'),                                             -- PROGRAM_NM
    NULLIF(NULLIF(NULLIF(TRIM(CHNNL_CMPNY), ''), 'NULL'), '-'),                                         -- CHANNEL_COMPANY
    CAST(NULL AS VARCHAR),                                                  -- CHANNEL_COMPANY_TYPE: 영상 전용
    CAST(NULL AS VARCHAR),                                                  -- SPOT_TYPE: 영상 전용
    CAST(NULL AS NUMBER(9,0)),                                              -- DURATION_SEC: 영상 전용
    CAST(NULL AS VARCHAR),                                                  -- DAY_DIV: 영상 전용
    CAST(NULL AS VARCHAR),                                                  -- PRG_START_TIME: 영상 전용
    CAST(NULL AS VARCHAR),                                                  -- CTV_DIV: 영상 전용
    NULLIF(NULLIF(NULLIF(TRIM(BRDC_DIV_NM), ''), 'NULL'), '-'),                                         -- BRDC_DIV
    AD_CNT,
    CAST(NULL AS FLOAT),                                                    -- CONV_CALL_CNT: 영상 전용
    DVLP_MBER_CNT,                                                          -- O16: 개발회원수(고유 이름으로 분리)
    DVLP_CNT,                                                               -- O16: 개발건수(고유 이름으로 분리)
    CAST(NULL AS FLOAT),                                                    -- AD_VIEW_RT_SRC: 영상 전용
    CAST(NULL AS FLOAT),                                                    -- CPC_SRC: 영상 전용
    'AGENCY',
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS',
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    '669c7dcc-1689-4020-9ee5-1be787ae11b1'
FROM GN_DW.SILVER.AGENCY_AD_ROW_REBRDC