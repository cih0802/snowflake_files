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
--    GOLD 가 AGENCY_CONV_MEMBERS·AGENCY_CONV_CNT 로 개명 노출해 **재방송 개발실적이 'GA 전환'으로 혼입**됐다
--    (실측 2026-07-28: AGENCY_CONV_MEMBERS 의 28.60% · AGENCY_CONV_CNT 의 60.32%가 REBRDC). 문서10 §8-I(8).
--    개발실적은 AGENCY_AD_BROADCAST.DVLP_MEMBER_CNT·DVLP_CNT 로 이관됐다.
--    ⚠️ 결과: GOLD GA_CONV_* 합계가 감소한다(설계상 의도된 교정 — 종전 값은 의미혼입 상태였다).
-- 🔴🔴 [2026-09-17 O171] DIGITAL 분기의 UPPER_CAMPAIGN_NM 을 **NULL 로 환원**했다.
--    원인 = 원천 12번 `DGT_AD_CMPGN_DTLS` 의 28번째 컬럼이 개명됐다:
--           `UPPER_CMPGN_NM`('상위캠페인') → **`CMPGN_UTM_NM`('utm_campaign')**
--    ⇒ DIGITAL 원천에서 **상위캠페인 개념 자체가 사라졌다**(다른 컬럼으로 대체된 것이 아니다).
--    🔴 그 자리에 utm_campaign 을 끼우지 않은 이유 = 이 컬럼은 VIDEO 분기가 **진짜 상위캠페인**을 넣는
--       자리다. utm 을 같은 컬럼에 넣으면 한 컬럼에 **개념 2종이 섞여** 집계가 조용히 틀린다
--       — 위 O16 사례(재방송 개발실적이 'GA 전환'으로 혼입)와 **동형 결함**이다.
--    🟢 utm 값은 버려지지 않는다 = `SILVER.AGENCY_AD_ROW_DGT.CMPGN_UTM_NM`(원천 무손실 staging)에 있다.
--    🟢 승격을 보류한 이유(2026-09-17 사용자 결정) = AGENCY 원천은 계속 바뀐다 ⇒ 변동 컬럼을 공통
--       스키마에 올리면 개명마다 DDL·ALTER·OWNERSHIP 절차를 다시 탄다. staging 에만 두면 **1곳 수정**으로 끝난다.
--    ⇒ 리포트가 utm 을 실제로 요구하면 그때 `CAMPAIGN_UTM_NM` 으로 승격한다(요건이 명확해진 뒤).
--    📏 실측 근거(개명 전) = `UPPER_CAMPAIGN_NM` 은 **SILVER 종단 컬럼**이다:
--       조인 사용 0건 · GOLD 승격 0건(`30_output_share/06_BRONZE노출감사.md`) · SV/Agent 참조 0건.
--       `DIM_MARKETING_CAMPAIGN` 이름매칭은 `CAMPAIGN_NM` 단독이다(그 모델 `:13`).
-- 🔴🔴 [2026-09-17 O171-D] DIGITAL 의 AD_DATE 를 **COALESCE 폴백**으로 산출한다(사용자 결정).
--    원인 = 원천 12번 DGT 가 2026-06 전후로 **시간축 방식이 바뀌는 중**이다(개발 진행 중).
--      · 2026-06-01 이후 = `DATE` 컬럼을 채운다(신방식)
--      · 2026-05-31 이전 = `DATE` 가 **비어 있고** 텍스트 `YEAR`·`MONTH`·`DAY` 만 있다(구방식·고정분)
--    ⇒ 실측(2026-09-17) = 203,138행 중 `DATE` NULL **194,058(95.53%)** · 전건 텍스트축 보유.
--    🔴 종전에 이 테스트는 **널 0/235,572** 를 실측하고 warn→error 승격됐다(문서50 `-015:6`) —
--       즉 불변식이 실제로 깨진 것이고 테스트가 정확히 잡았다. severity 강등으로 덮지 않는다.
--    🟢 폴백식의 신뢰 근거 = `DATE` 가 **있는** 9,080행에서 파생값과 **9,080/9,080 일치 · 불일치 0**.
--       경계도 깨끗하다 — `DATE` NULL 행의 파생 최대값이 **2026-05-31** 이고 6월 이후는 **0건**이다.
--    ⚠️ 08 DDL 의 「staging 텍스트 시간축 숫자 파싱 금지」는 값이 `'2025년'`·`'03월'` 형태일 때의
--       처방이다. 실측 값은 `'2025'`·`'3'`·`'6'` 이고, 그 규약이 신뢰하라고 한 `DATE` 쪽이 비었다
--       ⇒ 08 DDL 에 이 예외를 명시했다(규약 개정 · 근거 병기).
--    🔴 **파싱은 코어(이 모델)에서만 한다** — staging(AGENCY_AD_ROW_DGT)은 원천 무손실이므로 손대지 않았다.
--    🔴 `TRY_TO_DATE` 를 쓴다(`DATE_FROM_PARTS` 금지) — 후자는 `month=13` 같은 불량값을 **조용히 롤오버**한다.
-- 🔴🔴 [2026-09-28 O182] 원천 12번 재편(DGT 36→41 · VIDEO 32→37 · REBRDC 34→21) 반영. **출력 계약(컬럼)은 불변**이다.
--    · DIGITAL = `DATE` 는 전건 채워졌으나 **3,531행이 1970-01-01**(에포크 기본값) ⇒ 그 값만 NULL 로 보고 텍스트축 폴백.
--      실측: 폴백 후 미해결 0 · 최소 2026-06-01 · 정상 `DATE` 행과 텍스트축 불일치 0.
--      월 텍스트에 '월' 접미가 섞일 수 있어 숫자만 남긴다(`REGEXP_REPLACE`).
--      비용 = `AD_COST`(구 GA_AD_COST · 사용자 결정 「연속성 유지」) — 마크업·VAT·최종정산은 staging 에만 보존.
--      전환(명) = `SPNSER_MBER_CNT`('후원자수(명)' · 구 GA_CONV_MBER_CNT 자리).
--    · VIDEO = `BRDC_DATE` 우선(송출일 기준 유지) · NULL 3,336행(CTV 시트)만 텍스트축 폴백.
--      ⚠️ `BRDC_DATE` 가 있는 7,606행은 텍스트축과 날짜가 다르다 — 송출일 ≠ 텍스트 일자. 종전대로 송출일을 쓴다.
--      캠페인명 = `CMPGN_NM`(구 MKT_CMPGN_NM 소멸 · 🔴 채움 3,336/46,353 = CTV 시트만) ⇒ 캠페인 축 도달률이 크게 준다.
--      노출·클릭·기기 = 신규 원천값 배선(사용자 결정 「모두 배선」 · 종전 DEC-10 「방송=기기 없음」은 CTV 행에서 깨졌다).
--      전환콜 = 원천 소멸 ⇒ NULL. 비용 = `LAST_AD_COST`(구 ACTL_PUR_AD_COST_KRW).
--    · REBROADCAST = 날짜 `BRDC_DATE`(구 DATE) · 채널 `CHNNL_NM`(구 CHNNL_CMPNY). 비용 = `BRDC_SCHDL_COST` 유지.
WITH dgt AS (
    SELECT
        *,
        COALESCE(
            NULLIF("DATE", '1970-01-01'::DATE),     -- O182: 에포크 기본값은 날짜가 아니다
            TRY_TO_DATE("YEAR"
                        || LPAD(REGEXP_REPLACE("MONTH", '[^0-9]', ''), 2, '0')
                        || LPAD(REGEXP_REPLACE("DAY",   '[^0-9]', ''), 2, '0'), 'YYYYMMDD')
        )                                   AS AD_DATE_RESOLVED
    FROM {{ ref('AGENCY_AD_ROW_DGT') }}
),
video AS (
    SELECT
        *,
        COALESCE(
            BRDC_DATE,                              -- 송출일 우선(종전 기준)
            TRY_TO_DATE("YEAR"
                        || LPAD(REGEXP_REPLACE("MONTH", '[^0-9]', ''), 2, '0')
                        || LPAD(REGEXP_REPLACE("DAY",   '[^0-9]', ''), 2, '0'), 'YYYYMMDD')
        )                                   AS AD_DATE_RESOLVED
    FROM {{ ref('AGENCY_AD_ROW_VIDEO') }}
)
SELECT
    AD_PERF_DK                              AS AD_PERF_DK,
    AD_SOURCE_TYPE                                 AS AD_SOURCE_TYPE,
    'DIGITAL'                               AS SOURCE_SYSTEM,
    AD_DATE_RESOLVED                        AS AD_DATE,
    YEAR(AD_DATE_RESOLVED)                  AS AD_YEAR,
    MONTH(AD_DATE_RESOLVED)                 AS AD_MONTH,
    {{ clean_str('CMPGN_NM') }}             AS CAMPAIGN_NM,
    CAST(NULL AS VARCHAR)                   AS UPPER_CAMPAIGN_NM,   -- O171: 원천 개념 소멸(개명) · utm 은 AGENCY_AD_ROW_DGT.UTM_CMPGN_NM(O182 원천 개명)
    {{ clean_str('MEDIA_NM') }}             AS MEDIA_CHANNEL_NM,
    {{ clean_str('DEVICE') }}               AS DEVICE_NM,
    {{ clean_str('MATR') }}                 AS CREATIVE_NM,
    CAST(NULL AS VARCHAR)                   AS PROGRAM_NM,
    EXPS_CNT                                AS IMPRESSION_CNT,
    CLICK_CNT                               AS CLICK_CNT,
    SPNSER_MBER_CNT                         AS CONV_MEMBER_CNT,      -- O182: 원천 '후원자수(명)'(구 GA_CONV_MBER_CNT)
    CONV_VU_CNT                             AS CONV_UNIT_CNT,        -- 진짜 GA 전환(VU/건)
    CAST(NULL AS FLOAT)                     AS INBOUND_CALL_CNT,
    CAST(NULL AS FLOAT)                     AS CONV_CALL_CNT,
    CAST(NULL AS FLOAT)                     AS AD_CNT,
    AD_COST                                 AS AD_COST,              -- O182: 구 GA_AD_COST(연속성 유지 결정)
    'GA'                                    AS COST_TYPE,
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS'       AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    '{{ invocation_id }}'                   AS DW_BATCH_ID,
    -- 🆕 [2026-09-29 O188] 신규지표 #9 직접모금비 — REBRDC 비용 분해(DGT·VIDEO 는 원천 개념 부재 ⇒ NULL)
    CAST(NULL AS FLOAT)                     AS CONTENTS_PUR_COST,
    CAST(NULL AS FLOAT)                     AS CALL_CTR_OPER_COST,
    CAST(NULL AS FLOAT)                     AS TOT_COST
FROM dgt

UNION ALL

SELECT
    AD_PERF_DK,
    AD_SOURCE_TYPE,
    'REBROADCAST',
    BRDC_DATE,                                              -- O182: 구 DATE
    YEAR(BRDC_DATE),
    MONTH(BRDC_DATE),
    CAST(NULL AS VARCHAR),                                  -- CAMPAIGN_NM: 원천 부재(CMPGN_CD 컬럼 신설됐으나 전건 NULL)
    CAST(NULL AS VARCHAR),                                  -- UPPER_CAMPAIGN_NM: 원천 부재
    {{ clean_str('CHNNL_NM') }},                            -- MEDIA_CHANNEL_NM (O182: 구 CHNNL_CMPNY)
    CAST(NULL AS VARCHAR),                                  -- DEVICE_NM: 방송=기기 개념 없음(DEC-10)
    {{ clean_str('BRDC_NM') }},                             -- CREATIVE_NM
    {{ clean_str('BRDC_NM') }},                             -- PROGRAM_NM
    CAST(NULL AS FLOAT),                                    -- IMPRESSION_CNT: 원천 부재
    CAST(NULL AS FLOAT),                                    -- CLICK_CNT: 원천 부재
    CAST(NULL AS FLOAT),                                    -- CONV_MEMBER_CNT: O16 — GA 개념 없음(개발실적은 FAD_B)
    CAST(NULL AS FLOAT),                                    -- CONV_UNIT_CNT:   O16 — GA 개념 없음(개발실적은 FAD_B)
    TRY_TO_NUMBER({{ clean_str('INBOUND_CALL_CNT') }}),     -- 실측 REBRDC=TEXT
    CAST(NULL AS FLOAT),                                    -- CONV_CALL_CNT: 영상 전용
    AD_CNT,
    BRDC_SCHDL_COST,
    '편성',
    'AGENCY',
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS',
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    '{{ invocation_id }}',
    CONTENTS_PUR_COST,                                      -- O188: 콘텐츠구입비
    CALL_CTR_OPER_COST,                                     -- O188: 콜센터운영비
    TOT_COST                                                -- O188: 편성비+콘텐츠구입비+콜센터운영비(staging 실측 2,104/2,104 일치)
FROM {{ ref('AGENCY_AD_ROW_REBRDC') }}

UNION ALL

SELECT
    AD_PERF_DK,
    AD_SOURCE_TYPE,
    'VIDEO',
    AD_DATE_RESOLVED,
    YEAR(AD_DATE_RESOLVED),
    MONTH(AD_DATE_RESOLVED),
    {{ clean_str('CMPGN_NM') }},                            -- O182: 구 MKT_CMPGN_NM 소멸 → CMPGN_NM(CTV 시트만 채움)
    {{ clean_str('UPPER_CMPGN_NM') }},
    {{ clean_str('CHNNL_NM') }},
    {{ clean_str('DEVICE_NM') }},                           -- O182: 신규(종전 DEC-10 NULL)
    {{ clean_str('MATR_NM') }},
    {{ clean_str('SCHDL_NM') }},
    EXPSR_CNT,                                              -- O182: 신규 노출수
    CLICK_CNT,                                              -- O182: 신규 클릭수
    CAST(NULL AS FLOAT),                                    -- CONV_MEMBER_CNT: GA 개념 없음(후원자수는 위성 DVLP_MEMBER_CNT)
    CAST(NULL AS FLOAT),                                    -- CONV_UNIT_CNT:   GA 개념 없음
    INBOUND_CALL_CNT,
    CAST(NULL AS FLOAT),                                    -- CONV_CALL_CNT: O182 원천 소멸
    AD_CNT,
    LAST_AD_COST,                                           -- O182: 구 ACTL_PUR_AD_COST_KRW
    '집행',
    'AGENCY',
    'BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS',
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    '{{ invocation_id }}',
    CAST(NULL AS FLOAT),                                    -- CONTENTS_PUR_COST: VIDEO 원천 부재
    CAST(NULL AS FLOAT),                                    -- CALL_CTR_OPER_COST: VIDEO 원천 부재
    CAST(NULL AS FLOAT)                                     -- TOT_COST: VIDEO 원천 부재
FROM video
