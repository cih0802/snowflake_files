-- GN_DW 3단계: Semantic View DDL 정본 — SV_TARGET_BIZ (사업목표) · base = GOLD.WIDE_TARGET_BIZ(dbt 소유)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상  [2026-09-29 O188-E 신설]
--   대상 SV = **SV_TARGET_BIZ**. base = `GOLD.WIDE_TARGET_BIZ`(dbt 뷰) ⇒ 🔴 **`dbt build` 이후에만** 배포 가능하다
--   (O188-E 신설 컬럼 ORG_PATH·SRC_* 6개가 뷰에 있어야 컴파일된다).
--   🔴 파일 규약·선행 조건의 정본 = `05_0_SV_DDL.sql` §공통 규약(복제하지 않는다).
--
-- ▶ 설계 결정 (사용자 지시 O188-E 「사업목표 노출」 · 문서20 N-24 ① 회신 전)
--   ① 원천 = `BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV` 의 두 목표유형(연사업 · 팀)은 합이 거의 같다 ⇒ **같은 목표의 다른 분해**로 보인다.
--      ⇒ 두 관점을 **병렬 제공**하고 🔴 **합산은 구조적으로 막는다**(AI_SQL_GENERATION 규칙 1).
--   ② 차원 매칭이 안 되는 행(동명 팀·비조직명·팀 유형 4그룹 후원사업)은 원천 표기 degen(SRC_*)으로 답한다(값 창작 0).
--   ③ 추경 목표(SUPP_GOAL_CNT)는 원천에 없어 전건 NULL ⇒ **metric 에서 제외**(비활성 지표 규약).
--   ④ PK 미선언 — 뷰 grain 이 원천 degen 조합이라 유일성 보증이 없다.
--   ⑤ COMMENT 에 수치를 넣지 않는다(규칙7).
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ
  TABLES (
    tgt AS GN_DW.GOLD.WIDE_TARGET_BIZ
      WITH SYNONYMS ('사업목표', '연사업목표', '팀 목표', '개발 목표')
      COMMENT = '사업목표(개발 건수 목표) 월별 분석 (base: GOLD.WIDE_TARGET_BIZ). [Grain: 월 × 목표유형 × 법인 × 팀 × 후원사업 × 원천 구분]. 🔴 목표유형(연사업/팀)은 같은 목표의 서로 다른 분해다 — 두 유형을 합산하지 말 것. [원천: CRM TM_CM_MBER_DVLP_GOAL_DIV → SILVER.CRM_BIZ_TARGET → GOLD.FACT_TARGET_PROJECT → GOLD.WIDE_TARGET_BIZ].'
  )
  DIMENSIONS (
    tgt.CAL_YEAR   AS tgt.CAL_YEAR   WITH SYNONYMS ('연도', '년') COMMENT = '목표 연도',
    tgt.CAL_MONTH  AS tgt.CAL_MONTH  WITH SYNONYMS ('월')         COMMENT = '목표 월(1~12)',
    tgt.MONTH_KEY  AS tgt.MONTH_KEY  WITH SYNONYMS ('연월')       COMMENT = '목표 연월 YYYYMM',
    tgt.GOAL_TYPE  AS tgt.GOAL_TYPE_NM
      WITH SYNONYMS ('목표유형', '목표 관점', '연사업', '팀별')
      COMMENT = '목표 분해유형. 코드값 2종: ''연사업''(법인×신규/기존×조직구분×팀×후원사업 분해) · ''팀''(법인×조직구분×팀×후원사업 그룹×세부구분 분해). 🔴 두 값은 같은 목표의 다른 분해이므로 합산 금지 — 반드시 하나로 필터하거나 나란히 보여줄 것.',
    tgt.CORP_DIV   AS tgt.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분', '사단', '사복')
      COMMENT = '법인구분. 원천 표기 그대로(사단/사복). 사복 행은 팀 유형에만 있고 목표가 편성되지 않았을 수 있다 — 0 을 실적 부진으로 해석하지 말 것.',
    tgt.TEAM_NAME  AS tgt.SRC_TEAM_NM
      WITH SYNONYMS ('팀', '팀명', '부서', '조직')
      COMMENT = '원천 팀명 그대로. 조직 차원과 이름이 일치하지 않는 값(동명 팀 · 조직명이 아닌 구분값)도 이 축으로 구분된다 — 팀별 질문은 이 축을 쓴다.',
    tgt.ORG_DEPARTMENT AS tgt.ORG_DEPARTMENT
      WITH SYNONYMS ('조직 차원 부서명')
      COMMENT = '조직 차원(DIM_ORG) 매칭 부서명. 활성 조직 트리에서 이름이 유일한 팀만 매칭되고 나머지는 ''(미매핑)''이다 — 팀별 합계는 TEAM_NAME 으로 답하고 이 축은 조직 경로 확인용으로만 쓴다.',
    tgt.ORG_PATH   AS tgt.ORG_PATH
      WITH SYNONYMS ('조직 경로', '부서 경로', '상위 조직')
      COMMENT = '조직표 부서 경로(예: 본부 > 실 > 팀). 조직 차원 매칭 행만 값이 있고 나머지는 NULL.',
    tgt.SPONSOR_BIZ AS tgt.SRC_SPONSOR_BIZ_NM
      WITH SYNONYMS ('후원사업', '사업', '후원사업 그룹')
      COMMENT = '원천 후원사업 표기 그대로. 연사업 유형 = 개별 후원사업명 · 팀 유형 = 후원사업 그룹(국내/결연/해외프로젝트/기타) — 🔴 두 유형의 값 체계가 다르므로 목표유형으로 먼저 나눈다.',
    tgt.NEW_OLD_DIV AS tgt.NEW_OLD_DIV_NM
      WITH SYNONYMS ('신규기존', '신규/기존')
      COMMENT = '신규/기존 구분. 연사업 유형에만 값이 있다(팀 유형은 NULL).',
    tgt.ORG_DIV    AS tgt.ORG_DIV_NM
      WITH SYNONYMS ('조직구분', '본부지부', '본부/지부/대면')
      COMMENT = '조직구분 원천 표기(본부/지부/대면 계열). 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다.',
    tgt.DTL_DIV    AS tgt.DTL_DIV_NM
      WITH SYNONYMS ('세부구분')
      COMMENT = '세부구분 원천 표기. 팀 유형에만 값이 있다.'
  )
  METRICS (
    tgt.TOTAL_GOAL_CNT AS SUM(tgt.ANNUAL_GOAL_CNT)
      WITH SYNONYMS ('목표', '목표건수', '연사업목표(건)', '월 목표(건)', '사업목표')
      COMMENT = '사업목표 건수 합계(당초 목표). F(가산) — 단, 🔴 목표유형(GOAL_TYPE) 안에서만 가산한다. 연 목표 = 해당 연도 월 목표의 합.'
  )
  COMMENT = '사업목표(개발 건수 목표) SV. 목표유형 2관점(연사업·팀)을 병렬 제공하며 합산하지 않는다. 추경 목표는 원천에 없어 제공하지 않는다. 실적 대비 달성률은 이 SV 에 없다(실적 팩트와 교차 집계 불가 · 부서 단위 달성률은 SV_DEV_ACHIEVEMENT).'
  AI_SQL_GENERATION '핵심 규칙: (1) 목표유형: 모든 질의에 GOAL_TYPE 필터 또는 GOAL_TYPE 그룹핑을 반드시 포함한다. 사용자가 유형을 지정하지 않으면 GOAL_TYPE = ''연사업'' 으로 필터한다(기본 관점 · 사용자 결정 N-24①) — 팀 관점은 사용자가 팀·팀별을 말할 때만 쓰고, 두 값을 더한 총계 행은 만들지 않는다(ROLLUP 금지). (2) 팀별 질의는 TEAM_NAME, 후원사업별 질의는 SPONSOR_BIZ 를 쓰고 GOAL_TYPE 로 먼저 나눈다. (3) 기간 미지정 시 최신 연도를 월별로 반환한다. (4) 추경 목표·달성률 요청은 이 SV 로 만들지 않고 사유를 안내한다.';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ TO ROLE GN_DW_SERVICE;

/* 스모크(배포 직후 · 불변식) — SV 합계 == base 뷰 합계(유형별) */
USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT s.GOAL_TYPE, s.TOTAL_GOAL_CNT AS sv_val, b.base_val, s.TOTAL_GOAL_CNT = b.base_val AS ok
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_TARGET_BIZ DIMENSIONS tgt.GOAL_TYPE METRICS tgt.TOTAL_GOAL_CNT) s
JOIN (SELECT GOAL_TYPE_NM, SUM(ANNUAL_GOAL_CNT) AS base_val FROM GN_DW.GOLD.WIDE_TARGET_BIZ GROUP BY 1) b
  ON b.GOAL_TYPE_NM = s.GOAL_TYPE;
