-- ============================================================================
-- 05_11_SV_DDL_TARGET_BIZ.sql — Semantic View DDL 정본: SV_TARGET_BIZ
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ
  TABLES (
    tgt AS GN_DW.GOLD.WIDE_TARGET_BIZ
      WITH SYNONYMS ('사업목표', '연사업목표', '팀 목표', '개발 목표', '회원목표', '회비목표')
      COMMENT = '사업목표 월별 분석 (base: GOLD.WIDE_TARGET_BIZ). [Grain: 월 × 목표유형 × 법인 × 팀 × 후원사업 × 원천 구분]. 🔴 목표유형(GOAL_TYPE)마다 단위가 다르다(건·명·원·비율) — 유형을 섞어 합산하지 말 것. [원천: CRM TM_CM_MBER_DVLP_GOAL_DIV → SILVER.CRM_BIZ_TARGET → GOLD.FACT_TARGET_PROJECT → GOLD.WIDE_TARGET_BIZ].'
  )
  DIMENSIONS (
    tgt.CAL_YEAR   AS tgt.CAL_YEAR   WITH SYNONYMS ('연도', '년') COMMENT = '목표 연도',
    tgt.CAL_MONTH  AS tgt.CAL_MONTH  WITH SYNONYMS ('월')         COMMENT = '목표 월(1~12)',
    tgt.MONTH_KEY  AS tgt.MONTH_KEY  WITH SYNONYMS ('연월')       COMMENT = '목표 연월 YYYYMM',
    tgt.GOAL_TYPE  AS tgt.GOAL_TYPE_NM
      WITH SYNONYMS ('목표유형', '목표 지표', '목표구분', '후원사업 목표', '회원개발 목표')
      COMMENT = '목표 지표 유형(원천 표기 그대로). 단위별: 건 = ''후원사업''(구 연사업 관점) · ''회원개발''(구 팀 관점 · 팀×세부구분 분해) / 명 = ''월말활동회원'' / 원 = ''정기회비'' / 비율 = ''후원사업활동율'' · ''신규기존활동율'' · ''후원사업납입율'' · ''신규기존납입율'' · ''신규기존누계납입율''. 🔴 후원사업·회원개발은 같은 개발 목표의 다른 분해이므로 합산 금지 — 반드시 하나로 필터하거나 나란히 보여줄 것.',
    tgt.CORP_DIV   AS tgt.CPR_DIV_NM
      WITH SYNONYMS ('법인', '법인구분', '사단', '사복')
      COMMENT = '법인구분. 원천 표기 그대로(사단/사복). 값 목록은 SELECT DISTINCT 로 조회한다 — 목표가 편성되지 않은 법인·구분의 0 을 실적 부진으로 해석하지 말 것.',
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
      COMMENT = '원천 후원사업 표기 그대로. 후원사업 유형 = 개별 후원사업명 · 회원개발 유형 = 후원사업 그룹(국내/결연/해외프로젝트/기타) — 🔴 두 유형의 값 체계가 다르므로 목표유형으로 먼저 나눈다. 비율 지표·월말활동회원·정기회비도 후원사업별 값이 있을 수 있다.',
    tgt.NEW_OLD_DIV AS tgt.NEW_OLD_DIV_NM
      WITH SYNONYMS ('신규기존', '신규/기존')
      COMMENT = '신규/기존 구분 원천 표기. 값 = 신규 · 기존 · 🔴 소계 행 ''합계'' · ''신규합계''(비율 지표에만 있다) — 소계 행을 신규/기존과 함께 더하면 이중계상이다. 회원개발 유형은 NULL.',
    tgt.ORG_DIV    AS tgt.ORG_DIV_NM
      WITH SYNONYMS ('조직구분', '본부지부', '본부/지부/대면')
      COMMENT = '조직구분 원천 표기(본부/지부/대면 계열). 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다.',
    tgt.DTL_DIV    AS tgt.DTL_DIV_NM
      WITH SYNONYMS ('세부구분')
      COMMENT = '세부구분 원천 표기. 회원개발 유형에만 값이 있다.'
  )
  METRICS (
    tgt.GOAL_CNT AS SUM(CASE WHEN tgt.GOAL_TYPE_NM IN ('후원사업', '회원개발') THEN tgt.ANNUAL_GOAL_CNT END)
      WITH SYNONYMS ('목표', '목표건수', '개발 목표(건)', '월 목표(건)', '사업목표', '연사업목표(건)')
      COMMENT = '개발 목표 건수(당초). 단위=건. 후원사업·회원개발 유형만 집계. F(가산) — 🔴 GOAL_TYPE 안에서만 가산한다. 연 목표 = 해당 연도 월 목표의 합.',
    tgt.GOAL_MEMBER_CNT AS SUM(CASE WHEN tgt.GOAL_TYPE_NM = '월말활동회원' THEN tgt.ANNUAL_GOAL_CNT END)
      WITH SYNONYMS ('월말활동회원 목표', '활동회원 목표', '회원수 목표')
      COMMENT = '월말 활동회원 목표. 단위=명. S(잔량) — 월 안에서는 신규/기존·후원사업을 더할 수 있으나 🔴 월끼리 더하지 않는다(연 목표 = 12월 값).',
    tgt.GOAL_AMT AS SUM(CASE WHEN tgt.GOAL_TYPE_NM = '정기회비' THEN tgt.ANNUAL_GOAL_CNT END)
      WITH SYNONYMS ('정기회비 목표', '회비 목표', '목표 금액')
      COMMENT = '정기회비 목표 금액. 단위=원. F(가산) — 연 목표 = 월 목표의 합.',
    tgt.GOAL_RATE AS AVG(CASE WHEN tgt.GOAL_TYPE_NM LIKE '%율' THEN tgt.ANNUAL_GOAL_CNT END)
      WITH SYNONYMS ('목표율', '활동율 목표', '납입율 목표', '누계납입율 목표')
      COMMENT = '목표 비율(0~1 · 1 = 100%). 유형 5종 = 후원사업활동율 · 신규기존활동율 · 후원사업납입율 · 신규기존납입율 · 신규기존누계납입율. N(비가산) — 🔴 GOAL_TYPE 1개 · NEW_OLD_DIV 1개 · 월 1개로 고정해 조회한다(평균은 고정 시 원값과 같다).'
  )
  COMMENT = '사업목표 SV. 목표 지표 9종을 단위별 metric(건·명·원·비율)으로 제공하며 유형을 섞어 합산하지 않는다. 추경 목표는 원천에 없어 제공하지 않는다. 실적 대비 달성률은 이 SV 에 없다(실적 팩트와 교차 집계 불가 · 부서 단위 달성률은 SV_DEV_ACHIEVEMENT).'
  AI_SQL_GENERATION '핵심 규칙: (1) 목표유형: 모든 질의에 GOAL_TYPE 필터 또는 GOAL_TYPE 그룹핑을 반드시 포함한다. 건수 목표를 유형 지정 없이 물으면 GOAL_TYPE = ''후원사업'' 으로 필터한다(기본 관점 · 구 연사업 · 사용자 결정 N-24①) — 회원개발은 사용자가 팀·팀별·회원개발·채널을 말할 때만 쓰고, 두 값을 더한 총계 행은 만들지 않는다(ROLLUP 금지). (2) 단위별 metric 을 섞지 않는다: 건=GOAL_CNT · 명=GOAL_MEMBER_CNT · 원=GOAL_AMT · 비율=GOAL_RATE. (3) GOAL_MEMBER_CNT 는 월말 잔량이므로 여러 월을 더하지 않는다 — 연 목표는 12월 값, 기간 질의는 월별로 반환한다. (4) GOAL_RATE 는 GOAL_TYPE 1개로 필터하고 NEW_OLD_DIV 를 그룹핑하거나 하나로 필터한다 — 소계 행(합계·신규합계)과 신규/기존을 함께 평균·합산하지 않는다. 사용자가 전체 비율을 물으면 NEW_OLD_DIV = ''합계'' 행을 쓴다. 비율은 월별로 반환한다. (5) 팀별 질의는 TEAM_NAME, 후원사업별 질의는 SPONSOR_BIZ 를 쓰고 GOAL_TYPE 로 먼저 나눈다. (6) 기간 미지정 시 최신 연도를 월별로 반환한다. (7) 추경 목표·달성률 요청은 이 SV 로 만들지 않고 사유를 안내한다.';

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_TARGET_BIZ TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;
SELECT s.GOAL_TYPE, s.GOAL_CNT, s.GOAL_MEMBER_CNT, s.GOAL_AMT, s.GOAL_RATE, b.base_sum, b.base_avg,
       COALESCE(s.GOAL_CNT, s.GOAL_MEMBER_CNT, s.GOAL_AMT) = b.base_sum
         OR ABS(s.GOAL_RATE - b.base_avg) < 1e-9 AS ok
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_TARGET_BIZ DIMENSIONS tgt.GOAL_TYPE
       METRICS tgt.GOAL_CNT, tgt.GOAL_MEMBER_CNT, tgt.GOAL_AMT, tgt.GOAL_RATE) s
JOIN (SELECT GOAL_TYPE_NM, SUM(ANNUAL_GOAL_CNT) AS base_sum, AVG(ANNUAL_GOAL_CNT) AS base_avg
      FROM GN_DW.GOLD.WIDE_TARGET_BIZ GROUP BY 1) b
  ON b.GOAL_TYPE_NM = s.GOAL_TYPE;
