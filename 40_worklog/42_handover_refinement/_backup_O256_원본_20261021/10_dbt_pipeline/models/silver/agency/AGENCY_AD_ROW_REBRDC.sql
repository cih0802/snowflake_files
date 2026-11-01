-- AGENCY_AD_ROW_REBRDC: BRONZE REBRDC 전 21컬럼 무손실 staging + AD_PERF_DK 발급 (DEC-11 · 설계 §3-A-7)
-- Co-authored with CoCo
-- 🔴🔴 [2026-09-28 O182] 원천 12번 재편(34→21컬럼) 반영 — 원천 이름 그대로 보존.
--    제거 20 = RE_BRDC_TY_NM · BRDC_MT · TIME_RNG_DIV_NM · CELEB_NM · DMST_OVSEA_DIV_NM
--             · CASE1_*~CASE3_* 반복군 15컬럼(아동명 PII 3건 포함 — O14 판정 대상 자체가 소멸)
--    개명 2  = CHNNL_CMPNY→CHNNL_NM · DATE→BRDC_DATE
--    신규 7  = MONTH · DAY · UPPER_CMPGN_CD · CMPGN_CD · CONTENTS_PUR_COST · CALL_CTR_OPER_COST · TOT_COST
--    ⚠️ DIV_NM 값이 재송출/방송이다 = 종전 RE_BRDC_TY_NM(재송출/특집) 자리 ⇒ 하류 RT_TYPE 원천으로 쓴다.
--    ⚠️ 실측(2026-09-28): 2,104행 · `CMPGN_CD`·`UPPER_CMPGN_CD` **전건 NULL**(컬럼만 신설) ·
--       TOT_COST = 편성비+콘텐츠구입비+콜센터운영비 **2,104/2,104 일치**.
--    ⚠️ 사례 반복군이 원천에서 사라졌다 ⇒ 하류 AGENCY_AD_BROADCAST_CASE 는 0행이 된다(스키마 유지).
-- ⚠️ AD_PERF_DK **발급 단일지점** — 코어(FAD)·위성(FAD_B)이 동일 DK 를 쓰도록 여기서만 계산한다.
-- ⚠️ DUP_SEQ: 3종 staging 로직 동일성 유지를 위해 동일하게 부여한다.
WITH src AS (
    SELECT
        DIV_NM                  AS DIV_NM,
        YEAR                    AS YEAR,
        MONTH                   AS MONTH,
        DAY                     AS DAY,
        CHNNL_NM                AS CHNNL_NM,
        BRDC_DATE               AS BRDC_DATE,
        DOW                     AS DOW,
        WEEK                    AS WEEK,
        BRDC_TIME               AS BRDC_TIME,
        BRDC_NM                 AS BRDC_NM,
        BRDC_DIV_NM             AS BRDC_DIV_NM,
        AD_CNT                  AS AD_CNT,
        INBOUND_CALL_CNT        AS INBOUND_CALL_CNT,
        DVLP_MBER_CNT           AS DVLP_MBER_CNT,
        DVLP_CNT                AS DVLP_CNT,
        UPPER_CMPGN_CD          AS UPPER_CMPGN_CD,
        CMPGN_CD                AS CMPGN_CD,
        BRDC_SCHDL_COST         AS BRDC_SCHDL_COST,
        CONTENTS_PUR_COST       AS CONTENTS_PUR_COST,
        CALL_CTR_OPER_COST      AS CALL_CTR_OPER_COST,
        TOT_COST                AS TOT_COST,
        MD5(TO_JSON(OBJECT_CONSTRUCT(*)))   AS ROW_HASH
    FROM {{ source('bronze_agency','REBRDC_AD_CMPGN_DTLS') }}
),
seq AS (
    SELECT
        src.*,
        ROW_NUMBER() OVER (PARTITION BY ROW_HASH ORDER BY NULL) AS DUP_SEQ
    FROM src
)

SELECT
    MD5('REBROADCAST' || '|' || ROW_HASH || '|' || DUP_SEQ)  AS AD_PERF_DK,
    'REBROADCAST'           AS AD_SOURCE_TYPE,
    ROW_HASH                AS ROW_HASH,
    DUP_SEQ                 AS DUP_SEQ,
    DIV_NM, YEAR, MONTH, DAY, CHNNL_NM, BRDC_DATE, DOW, WEEK, BRDC_TIME, BRDC_NM, BRDC_DIV_NM,
    AD_CNT, INBOUND_CALL_CNT, DVLP_MBER_CNT, DVLP_CNT, UPPER_CMPGN_CD, CMPGN_CD,
    BRDC_SCHDL_COST, CONTENTS_PUR_COST, CALL_CTR_OPER_COST, TOT_COST,
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS'    AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    '{{ invocation_id }}'                   AS DW_BATCH_ID
FROM seq
