-- AGENCY_AD_BROADCAST_CASE: REBRDC 사례 반복군 CASE1_*~CASE3_* 언피벗 → GOLD FACT_AD_BROADCAST_CASE
-- Co-authored with CoCo
-- 설계: DEC-8 · 설계 §3-A(FAD_BC) — 원천 5속성 × 3반복 = 15컬럼을 CASE_SEQ 축으로 정규화.
-- ⚠️ 정규화 이득: 사례가 4개로 늘어도 DDL 변경이 불필요하다(행 추가로 흡수).
-- ⚠️ grain = AD_PERF_DK × CASE_SEQ (코어 FAD 에 1:N). 코어 조인 시 fan-out 주의 —
--    코어 measure 와 함께 집계하면 사례 수만큼 중복 합산된다. 사례 분석 전용으로 사용할 것.
-- ⚠️ 전 속성이 NULL 인 사례는 적재하지 않는다(희소행 방지 — 설계 §3-A FAD_BC 각주).
-- ⚠️ CASEn_CHILD_NM(아동명)은 **미적재** — PII 판정 대기(O14). staging(AGENCY_AD_ROW_REBRDC)에는 보존돼 있어
--    현업 판정 후 여기에 컬럼을 추가하면 즉시 노출 가능하다.
-- 🔴🔴 [2026-09-28 O182] 원천 12번 재편으로 REBRDC 의 CASE1_*~CASE3_* 반복군 15컬럼이 **전부 소멸**했다.
--    ⇒ 언피벗할 원천이 없다. 스키마 계약(08 DDL · GOLD FACT_AD_BROADCAST_CASE)은 유지하고 **0행 스캐폴드**로 둔다
--       (CRM_BIZ_TARGET 과 같은 `WHERE 1=0` 관용구). 위 두 줄의 O14 PII 판정도 대상 소멸로 무의미해졌다.
--    🔴 원천이 사례 컬럼을 다시 제공하면 git 이력의 종전 언피벗 본문으로 복원한다(컬럼명은 staging 에서 먼저 확인).
SELECT
    CAST(NULL AS VARCHAR(32))               AS AD_PERF_DK,
    CAST(NULL AS NUMBER(9,0))               AS CASE_SEQ,
    CAST(NULL AS VARCHAR)                   AS BIZ_DIV,          -- 사업구분   (원천 소멸)
    CAST(NULL AS VARCHAR)                   AS FAMILY_TYPE,      -- 가족유형   (원천 소멸)
    CAST(NULL AS VARCHAR)                   AS APPEAL_POINT,     -- 어필포인트 (원천 소멸)
    CAST(NULL AS VARCHAR)                   AS CASE_DIV,         -- 사례구분   (원천 소멸)
    'AGENCY'                                AS DW_SOURCE_SYSTEM,
    'BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS'    AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ      AS DW_UPDATE_TS,
    '{{ invocation_id }}'                   AS DW_BATCH_ID
FROM {{ ref('AGENCY_AD_ROW_REBRDC') }}
WHERE 1=0
