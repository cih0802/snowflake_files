-- CRM_MARKETING_CAMPAIGN: 마케팅캠페인 마스터 정제 (BRONZE TM_CM_MKTNG_CMPGN_MNG → SILVER)
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-06 O44] 신설 — Q16 오진 철회의 산물
-- ----------------------------------------------------------------------------
-- Q16 은 *"캠페인↔마케팅캠페인 조인키 무효화(`MKTG_CMPGN_NM` 전건 NULL)"* 로 닫혀 있었다.
-- 🔴 그 판정은 틀렸다. 실측(2026-08-06):
--   · `TM_CM_CMPGN_MNG.MKTG_CMPGN_NM` 채움 **33,915/36,143 = 93.8%** · 323 distinct
--   · 브리지 조인 `MK_CMPGN_CD = MKTG_CMPGN_NM::varchar` → **33,915/33,915 = 100% 해소**
--   · AGENCY 광고 캠페인명 → 이 마스터와 **81/110(73.6%) 이름 일치** (2026-08-06 재측정)
--     → 광고행 기준 **218,402/243,545 = 89.7%** 도달
--
-- 왜 별도 SILVER 모델인가: 이 마스터(323행)는 **AGENCY(광고) ↔ CRM(개발실적)을 잇는 유일한
--   conformed 축**이다. `CRM_CAMPAIGN` 안에서 LEFT JOIN 라벨로만 소비하면 광고측이 이 축을
--   참조할 수 없다(차원이 아니라 속성이 된다). 독립 차원으로 승격해야 양측이 같은 키를 쓴다.
--
-- 🔴 팬아웃 경고(설계 근거): 개발캠페인(`CMPGN_CD`) grain 으로 내려가면 일치 광고캠페인명 81종이
--   개발캠페인 **9,750종**에 대응한다(평균 120.4 · 최대 901) → naive 조인 시
--   **218,402행 → 39,669,103행 = 181.6배 폭발**하고 광고비가 그만큼 복제된다(2026-08-06 재측정).
--   ⚠️ 종전 「76종 · 9,037종 · 118.9 · 200배」는 재현 불가로 교체(P89).
--   ⇒ 광고↔개발 결합은 **마케팅캠페인 grain 에서만** 성립한다. 개발캠페인 단위 ROI 는
--     현업의 **광고비 배분 규칙**이 있어야 한다(Q10 재정의 대상 — 원천 입고 사안이 아니다).
-- ============================================================================
SELECT
  NULLIF(TRIM(MK_CMPGN_CD),'')        AS MK_CMPGN_CD,      -- PK. `TM_CM_CMPGN_MNG.MKTG_CMPGN_NM`(NUMBER)의 문자 표현
  NULLIF(TRIM(MK_CMPGN_NM),'')        AS MK_CMPGN_NM,      -- 마케팅캠페인명. AGENCY `CAMPAIGN_NM` 과 이름 매칭되는 축
  NULLIF(TRIM(USE_YN),'')             AS USE_YN,           -- 원천 그대로(제외 금지 — 폐지분도 과거 실적에 붙는다)
  NULLIF(TRIM(RM),'')                 AS RM,               -- 비고
  'CRM'                               AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                 AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                 AS DW_UPDATE_TS,
  NULL                                AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TM_CM_MKTNG_CMPGN_MNG
WHERE MK_CMPGN_CD IS NOT NULL