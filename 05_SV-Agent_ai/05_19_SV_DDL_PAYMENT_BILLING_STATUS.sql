-- ============================================================================
-- 05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql — Semantic View DDL 정본: SV_PAYMENT_BILLING_STATUS (🆕 O213 Y3-D)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 🔴 선행 = dbt build `FACT_PAYMENT_BILLING_STATUS`(테이블은 06_DDL 로 선생성 · build 전에는 0행)
--     ⇒ 이 파일은 build 뒤에 실행한다(0행 상태에서 배포하면 Agent 가 「데이터 없음」으로 답한다).
--   · 근거(2026-10-08 실측 · SILVER.CRM_PAYMENT_BILLING 회원 귀속 50,835,082행):
--     사전 검증 = 신규 팩트 12,102행 · 청구액·납입액·미납액·원천행수 4종이 FACT_MEMBER_FEE 와 원 단위 일치.
--     202608 청구구분 = 정기청구 922,963건(17,497,729,843원) · 코드 Y 2,375건 · OCR신규 634건 · 개별청구 84건 · 코드 NULL 1,116건(391,000원).
--     🔴 [O213-C 정정] 코드 NULL 을 종전 「16건」으로 적었다 — 원천 회비월 = 202608 만 센 값이었다. 팩트·SV 는 회비월 무효 시
--       납입월로 폴백(FACT_MEMBER_FEE 와 같은 규칙)하므로 회비월 NULL · 청구액 NULL 인 납입행 1,100건이 202608 로 들어온다
--       (원천 실측 = 회비월 202608 16건 391,000원 + 폴백 1,100건 청구액 0건 ⇒ 청구액 합은 391,000원 그대로).
--   · 🟢 [O213-C] build 후 배포·스모크 = SV·팩트·FACT_MEMBER_FEE 청구액 955,144,520,496원 3값 일치(GN_DW_ANALYST).
--   · 🔴 청구결과(PM002 · 101종 중 89종 사전 불일치)·처리결과(코드그룹 미특정)는 넣지 않았다 — 문서20 현업 확인.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS
  TABLES (
    pbs AS GN_DW.GOLD.FACT_PAYMENT_BILLING_STATUS
      WITH SYNONYMS ('회비 청구 처리', '청구 처리 현황', '청구 상태')
      COMMENT = '회비 청구 처리 상태 팩트(1행 = 월 × 후원사업 × 회비구분 × 납입유형 × 청구구분 × 처리상태 × 환급사유). 「청구구분별 청구 건수」「처리상태별 청구액」「환급사유별 건수」 질문용. [원천: CRM(eCRM) → BRONZE_CRM.TM_PM_MBRFEE_ACMSLT·TM_PM_DNTN_DTLS → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_PAYMENT_BILLING_STATUS]. 🔴 회원 축이 없다 — 회원 단위 회비는 SV_MEMBER_FEE·SV_MEMBER_MONTHLY 소관이며 한 표에 합산하지 않는다.',
    sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업')
      COMMENT = '후원사업 차원(납입 대상 후원사업).'
  )
  RELATIONSHIPS (
    pbs_to_sponsorship AS pbs (SPONSORSHIP_SK) REFERENCES sponsorship
  )
  DIMENSIONS (
    pbs.MONTH_KEY AS pbs.MONTH_KEY WITH SYNONYMS ('회비월', '기준월', '연월') COMMENT = '회비월 YYYYMM(정수 · 회비월 우선 · 납입월 폴백 · 0 = Unknown월).',
    pbs.MONTH_LABEL AS CASE WHEN pbs.MONTH_KEY > 0 THEN TO_CHAR(FLOOR(pbs.MONTH_KEY / 100)) || '-' || LPAD(TO_CHAR(MOD(pbs.MONTH_KEY, 100)), 2, '0') END WITH SYNONYMS ('회비월 표시', '월') COMMENT = '회비월 표시용 문자열 YYYY-MM(O212-B 회비월 라벨 규칙 · 0 = Unknown월은 NULL). 답변 표에는 이 값을 쓴다.',
    pbs.FEE_DIV_NAME AS pbs.FEE_DIV_NAME WITH SYNONYMS ('회비구분', '정기/선물금/일시/긴급구호') COMMENT = '회비구분(PM010 · 정기·선물금·일시·긴급구호). 기부금 행은 NULL(원천에 회비구분 개념 없음).',
    pbs.PAYMENT_TYPE AS pbs.PAYMENT_TYPE WITH SYNONYMS ('납입유형', '회비/기부금') COMMENT = '납입유형(회비 · 기부금).',
    pbs.RQEST_DIV_CD AS pbs.RQEST_DIV_CD WITH SYNONYMS ('청구구분코드') COMMENT = '청구구분 원천 코드(PM024). 라벨 없는 코드 Y 를 구분할 때 쓴다.',
    pbs.RQEST_DIV_NAME AS pbs.RQEST_DIV_NAME WITH SYNONYMS ('청구구분', '청구 구분', '정기청구/개별청구') COMMENT = '청구구분(PM024 · 정기청구·OCR신규·개별청구). 🔴 원천 코드 Y 는 코드사전에 없어 라벨이 NULL 이다(현업 확인 대상) — 「청구구분별」 표에는 NULL 행을 「코드 Y」로 따로 밝힌다.',
    pbs.PRCS_STAT_CD AS pbs.PRCS_STAT_CD WITH SYNONYMS ('처리상태코드') COMMENT = '회비 처리상태 원천 코드(PM013). 라벨 없는 코드 F 를 구분할 때 쓴다.',
    pbs.PRCS_STAT_NAME AS pbs.PRCS_STAT_NAME WITH SYNONYMS ('처리상태', '회비 처리상태', '청구/완료') COMMENT = '회비 처리상태(PM013 · 청구·완료). 🔴 원천 코드 F 는 코드사전에 없어 라벨이 NULL 이다(현업 확인 대상) — 의미를 추정하지 않는다.',
    pbs.RETUN_RSN_NAME AS pbs.RETUN_RSN_NAME WITH SYNONYMS ('환급사유', '환불사유', '반환사유') COMMENT = '환급사유(PM042 · 11종 · 예: 청구 후 후원중단·회원 오신청·회비이중납부·회원요청). 환급이 아닌 청구행은 NULL(개념 없음) — 환급사유 질문은 값이 있는 행으로 한정한다.',
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명') COMMENT = '납입 대상 후원사업명.'
  )
  METRICS (
    pbs.BILLING_ROW_CNT AS SUM(pbs.BILLING_ROWS)
      WITH SYNONYMS ('청구(건)', '청구 건수', '청구건')
      COMMENT = '청구행 수 합(건). F(가산).',
    pbs.BILLED_AMT_SUM AS SUM(pbs.BILLED_AMT)
      WITH SYNONYMS ('청구액(원)', '청구금액', '청구액')
      COMMENT = '청구액 합(원). F(가산) · FACT_MEMBER_FEE 의 청구액과 같은 식.',
    pbs.PAID_FEE_SUM AS SUM(pbs.PAID_FEE)
      WITH SYNONYMS ('납입액(원)', '납입금액', '납입액')
      COMMENT = '납입 총액(원) = 회비 + 기부금. F(가산).',
    pbs.UNPAID_AMT_SUM AS SUM(pbs.UNPAID_BILLED_AMT)
      WITH SYNONYMS ('미납액(원)', '미납 청구액', '미납액')
      COMMENT = '미납 청구액(원) = 결제상태 실패 또는 미기록인 청구액(DEC-3). F(가산).',
    pbs.BILLED_MEMBER_MAX AS MAX(pbs.BILLED_MEMBERS)
      WITH SYNONYMS ('청구 회원수(조합 최대)')
      COMMENT = '🔴 참고용 — 팩트 행(조합)마다 센 고유 회원수의 최대값이다. 고유 회원수는 조합을 넘어 더할 수 없으므로 「몇 명에게 청구했나」 질문은 SV_MEMBER_FEE 로 답한다.'
  )
  COMMENT = '회비 청구 처리 상태 SV(🆕 O213 Y3-D). 「청구구분·처리상태·환급사유별 청구 건수·금액」 질문에 쓴다. 활성: 청구(건)·청구액·납입액·미납액 · 회비월/회비구분/납입유형/청구구분/처리상태/환급사유/후원사업 축. 🔴 회원 단위 질문·고유 회원수는 SV_MEMBER_FEE 소관이며 이 SV 와 한 표에 합산하지 않는다(같은 원천 · 다른 grain). 비활성: 청구결과·처리결과(코드 사전 불일치 · 현업 확인 대상).'
  AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "청구액(원)" · "청구(건)"). 동의어가 없으면 COMMENT 첫 구절을 쓴다. 영문 식별자·코드명을 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. [O206-C 합계 규칙] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다.
  핵심 규칙: (1) 회비월 미지정 시 데이터에 존재하는 최신 회비월 하나로 한정하고 밝힌다(MONTH_KEY = 0 Unknown월 제외). (2) 회비월은 MONTH_LABEL(YYYY-MM)로 표시한다. (3) 청구구분·처리상태 라벨이 NULL 인 행은 원천 코드(RQEST_DIV_CD · PRCS_STAT_CD)를 함께 반환해 「코드 Y」「코드 F」로 밝히고 의미를 추정하지 않는다. (4) 환급사유 질문은 RETUN_RSN_NAME IS NOT NULL 로 한정한다. (5) 고유 회원수를 묻는 질문에는 이 SV 로 답하지 않는다 — SV_MEMBER_FEE 로 안내한다.'
  AI_VERIFIED_QUERIES (
    vqr_o213_rqest_div AS (
      QUESTION '2026년 8월 회비 청구구분별 청구 건수와 청구액'
      VERIFIED_BY '(O213 · 원천 직접 집계 대조 · 정기청구 922,963건 17,497,729,843원 · 코드 Y 2,375건 · OCR신규 634건 · 개별청구 84건)'
      SQL 'SELECT pbs.RQEST_DIV_NAME AS "청구구분", pbs.RQEST_DIV_CD AS "청구구분코드", SUM(pbs.BILLING_ROWS) AS "청구(건)", SUM(pbs.BILLED_AMT) AS "청구액(원)" FROM pbs WHERE pbs.MONTH_KEY = 202608 GROUP BY ROLLUP(pbs.RQEST_DIV_NAME, pbs.RQEST_DIV_CD) ORDER BY 3 DESC NULLS FIRST'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인) — SV 청구액 합 = 팩트 청구액 합 = FACT_MEMBER_FEE 청구액 합
SELECT (SELECT BILLED_AMT_SUM FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS METRICS pbs.BILLED_AMT_SUM)) AS sv_val,
       (SELECT SUM(BILLED_AMT) FROM GN_DW.GOLD.FACT_PAYMENT_BILLING_STATUS)                                       AS fact_val,
       (SELECT SUM(BILLED_AMT) FROM GN_DW.GOLD.FACT_MEMBER_FEE)                                                   AS fmf_val;
