-- CRM_MEMBER_SPONSOR_SPAN: 회원×후원사업 활동구간(시작월~중단월) — 활동회원 as-of 판정 기반, O93 신설.
-- Co-authored with CoCo
--
-- 왜 신설했나 — 정본 #51「월말활동회원」의 as-of 판정에는 **구간**이 필요한데
--   기존 두 모델 어느 쪽도 구간을 만들 수 없다:
--   · `CRM_MEMBER_SPONSOR_BIZ` = 중단일은 있지만 **MBER_NO 도 시작일도 없다**(키가 SPNSR_NO).
--   · `CRM_MEMBER_STATUS_HIST` = 상태이력이지만 회원 커버리지가 부분이다(이력 없는 회원이 존재).
--   ⇒ 후원 마스터(`TM_MM_FDRM_MBER_SPNSR`)를 붙여 `MBER_NO` + **등록일**을 얻는다.
--
-- 🟢 [CONF-3 해소] 정본 #51 비고의 두 문장은 모순이 아니었다 — 층위가 다르다:
--   ㉠ *"마지막 중단일이 마지막 재후원일보다 커야함"* = **비활동(중단)을 정의하는** 문장
--   ㉡ *"재후원 후원사업의 넘버링이 (중단된) 후원사업의 넘버링보다 크다는 조건이 필요"*
--      = 같은 날일 때의 **tie-break**
--   🔴 그리고 이 모델에서는 **㉡ 이 애초에 필요하지 않다** — 재후원을 하면 원천에
--      **새 후원사업 행이 생기고 그 행의 `SPNSR_DSCNTC_DE` 가 NULL** 이다.
--      즉 「재후원 넘버링이 더 크다」는 조건이 **후원사업 행 자체에 이미 반영**되어 있다.
--      ⇒ 날짜 비교·동일자 tie-break 없이 「미중단 사업 보유」 하나로 판정이 끝난다.
--   🟢 이 방식이 현업 앵커와 더 정확히 맞는다(판정 근거·실측 대조는 `20_issue/30_설계_의사결정.md` §29).
--      🔴 R2-6: 검증 수치는 여기 적지 않는다 — 정본은 그 문서다.
--
-- ⚠️ 시작일은 **후원(SPNSR_NO) 등록일의 근사**다. 원천에 후원사업(SPNSR_BSNS_NO) 단위 시작일이 없다.
--    같은 후원 아래 사업이 나중에 추가되면 그 사업의 시작을 실제보다 **이르게** 본다
--    ⇒ as-of 활동을 과대평가할 수 있는 방향이다. 사업 단위 시작일이 입고되면 교체할 자리다.
-- ⚠️ `SPNSR_DSCNTC_DE` 는 TEXT(YYYYMMDD)다. 월키는 앞 6자리를 쓴다 — 무효값은 NULL(=미중단)로
--    떨어지므로, 그 경우 **활동으로 과대 판정**된다. 채움 상태는 `_crm_schema.yml` 이 관측한다.

SELECT
  s.MBER_NO                                       AS MBER_NO,
  bz.SPNSR_NO                                     AS SPNSR_NO,
  bz.SPNSR_BSNS_NO                                AS SPNSR_BSNS_NO,
  bz.SPNSR_BSNS_ID                                AS SPNSR_BSNS_ID,
  bz.SPNSR_AMT                                    AS SPNSR_AMT,
  -- 시작 월키 = 후원 등록월(근사 · 위 주석 참조)
  {{ month_key_clamp("TRY_TO_NUMBER(TO_CHAR(s.FRST_REGIST_DT, 'YYYYMM'))") }}
                                                  AS START_MONTH_KEY,
  -- 중단 월키 = 후원사업 중단일의 YYYYMM. NULL = 미중단(현재까지 활동).
  {{ month_key_clamp("TRY_TO_NUMBER(SUBSTR(bz.SPNSR_DSCNTC_DE, 1, 6))") }}
                                                  AS DSCNTC_MONTH_KEY,
  bz.SPNSR_DSCNTC_DE                              AS SPNSR_DSCNTC_DE,
  bz.SPNSR_DSCNTC_YN                              AS SPNSR_DSCNTC_YN,
  'CRM'                                           AS DW_SOURCE_SYSTEM,
  'BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS+TM_MM_FDRM_MBER_SPNSR' AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()                             AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                             AS DW_UPDATE_TS,
  NULL                                            AS DW_BATCH_ID
FROM {{ ref('CRM_MEMBER_SPONSOR_BIZ') }} bz
-- 🟢 fan-out 0: 후원 마스터는 SPNSR_NO 유일(실측 확인 · 근거는 문서30 §29).
--    dedup 을 걸지 않는 이유 = 유일성이 성립하므로 QUALIFY 가 무의미하고, 걸면 유일성 붕괴를
--    조용히 감추게 된다. 유일성은 `_crm_schema.yml` 의 unique 테스트가 지킨다.
JOIN (
    SELECT
      NULLIF(TRIM(SPNSR_NO), '') AS SPNSR_NO,
      NULLIF(TRIM(MBER_NO), '')  AS MBER_NO,
      FRST_REGIST_DT
    FROM {{ source('bronze_crm', 'TM_MM_FDRM_MBER_SPNSR') }}
    WHERE SPNSR_NO IS NOT NULL AND MBER_NO IS NOT NULL
) s
  ON s.SPNSR_NO = bz.SPNSR_NO
