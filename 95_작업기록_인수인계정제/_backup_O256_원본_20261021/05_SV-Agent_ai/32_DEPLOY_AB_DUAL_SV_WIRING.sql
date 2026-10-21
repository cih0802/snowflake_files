-- ============================================================================
-- 32_DEPLOY_AB_DUAL_SV_WIRING.sql — O241 추천안 A/B 병기 완성(공91·공98 B안) 배포 순서
-- Co-authored with CoCo
--   작성 = trialadmin(mn11232) · 2026-10-16 · 사용자 결정 = 공91 ㉡ 직전 발송 1건 귀속 · 공91 B·공98 B 계획대로
--   🔴 D1·D3·D4 는 👤 사용자가 GN_DW_ADMIN 으로 실행한다(R4-1 · dbt·SV·Agent 라이브 배포).
--   롤백 기준점(이 계정 실측 2026-10-16) = AGENT_MEMBER VERSION$3 · AGENT_MARKETING VERSION$3 · dbt 직전 버전
--     (O240 문서의 VERSION$7·$5 는 이전 계정 번호다 — 이 계정에서는 번호가 다시 시작됐다)
-- ----------------------------------------------------------------------------
-- 변경 요지
--   ① GOLD.FACT_MESSAGE_DISPATCH.D5_GIFT_PART_AMT 신설 — 발송 D+1~D+5 선물금(원) · 선물금 1건 = 창 안 가장 가까운
--      직전 발송일 1개 귀속(QUALIFY) · (회원, 발송일)의 비통보성 발송 1행에만 적재
--   ② SILVER.BIGQUERY_SESSION.SESSION_END_TS · GOLD.FACT_BIGQUERY_SESSION.SESSION_END_TS·SESSION_DURATION_SEC 신설
--   ③ SV 3종 = SV_SERVICE.D5_GIFT_AMT(공91B) · SV_RELATION_ACTIVITY.TOTAL_GIFT_AMT 동의어(공91A) ·
--      SV_GA_SESSION.AVG_SESSION_DURATION_SEC(공98B) + A 동의어 + 병기 규칙 + VQR
--   ④ Agent 2종 = MEMBER ⑤ 공91 A/B 병기 · MARKETING ⑤ 공98 A/B 병기(EXECUTIVE = 해당 도구 없음 · 변경 없음)
--   ⑤ 코퍼스 = 변경 없음(공91·98 은 사전 FORMULA 공란이라 오버레이 비대상 · o237_build_formula_map.py:147)
--   🔴 계획 §2-3 의 「--full-refresh 필수」는 틀렸다 — dbt_project.yml 의 silver·gold.fact 는
--      on_schema_change = append_new_columns + pre-hook purge 다 ⇒ 일반 build 로 열이 추가되고
--      FMD 는 TRUNCATE 재적재 · GA 계열은 전체 범위 vars 로 백필한다(O237-C [C0] 선례).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- [D0] 사전 기대값(라이브 SILVER 직접식 · trialadmin 2026-10-16 실측 · 렌더 등가 SQL)
--   공91B 귀속 = 선물금 28,182건 · 1,303,750,000원(쌍별로 붙이면 34,215쌍 · 1,592,300,000원 = +22% 부풀림)
--   공91B 2026-09 발송분 = 75,330,000원
--   공98 2026-09 첫 일자 기준 세션 59,715 · A = 31.8742초(라이브 팩트 31.8742 와 일치) · B ≈ 90.2701초 · 0초 세션 13,788
--   선물금 원천 ACTIVITY_KEY 유일(185,213 = 185,213) ⇒ 귀속 파티션 키로 쓸 수 있다

-- [D1-a] 기존 테이블 열 추가(COMMENT 정본 = 03_top-down_gold/06_DDL.sql · 🔴 06_DDL 전체 재실행 금지 = GOLD 전량 비워짐)
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD COLUMN IF NOT EXISTS D5_GIFT_PART_AMT NUMBER(38,0)
    COMMENT '공91 추천안B(잠정) 발송 매칭 선물금(원) = 발송 D+1~D+5 안 선물금 GFTMNEY 합. 선물금 1건은 창 안 가장 가까운 직전 발송일 1개에만 귀속하고, 그 (회원, 발송일)의 비통보성 발송 1행에만 싣는다(기간 합 가산). 처리통보성 제목·매칭 없음은 0.';
-- 🆕 [O241 재실행] SILVER 도 소유자(GN_DW_ADMIN)가 먼저 추가해야 한다 — 누락 시 dbt(GN_DW_DBT) 가
--    append_new_columns ALTER 에서 003001(MODIFY 권한 없음)로 실패한다(실측 2026-10-16 · 쿼리 01c7c6d5-0304-f8f1-0005-878a0007fa52).
ALTER TABLE GN_DW.SILVER.BIGQUERY_SESSION ADD COLUMN IF NOT EXISTS SESSION_END_TS TIMESTAMP_NTZ
    COMMENT '그 일자 안 세션 마지막 이벤트 시각(공98 추천안B 재료).';
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_SESSION ADD COLUMN IF NOT EXISTS SESSION_END_TS TIMESTAMP_NTZ
    COMMENT '그 일자 안 세션 마지막 이벤트 시각 [SILVER.BIGQUERY_SESSION 승계].';
ALTER TABLE GN_DW.GOLD.FACT_BIGQUERY_SESSION ADD COLUMN IF NOT EXISTS SESSION_DURATION_SEC NUMBER
    COMMENT '공98 추천안B(잠정) UA식 세션 지속시간(초) = 세션 전체 마지막 − 첫 이벤트 시각. 세션의 첫 일자 행에만 값 · 자정 경계 다음 일자 행은 0(평균 = SUM ÷ 세션키 COUNT DISTINCT). 단일 이벤트 세션은 0.';

-- [D1-b] 👤 dbt 재배포 + build(GA = 전체 범위 백필 · FMD = 하위 WIDE 포함)
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION O241_20261016
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';
USE ROLE GN_DW_DBT;
USE WAREHOUSE GN_DW_ETL_WH;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ARGS = 'build --select BIGQUERY_SESSION+ FACT_MESSAGE_DISPATCH+ --vars ''{"bigquery_dt_ranges": [["1945-01-01", "9999-12-31"]]}''';

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
-- [D2] 대사(기대 = 주석 값)
-- 2-1 공91B 합계·월(기대 1,303,750,000 · 2026-09 = 75,330,000 · NULL 0)
SELECT SUM(D5_GIFT_PART_AMT)                                                        AS amt_all,
       SUM(IFF(DATE_SK BETWEEN 20260901 AND 20260930, D5_GIFT_PART_AMT, 0))          AS amt_202609,
       COUNT_IF(D5_GIFT_PART_AMT IS NULL)                                            AS null_rows
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH;
-- 2-2 (회원, 발송일) 당 금액 적재 행 ≤ 1(기대 0)
SELECT COUNT(*) AS bad_pairs FROM (
  SELECT MEMBER_DK, DATE_SK FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH
  WHERE D5_GIFT_PART_AMT > 0 GROUP BY 1, 2 HAVING COUNT(*) > 1);
-- 2-3 공98 A·B(기대 2026-09 A ≈ 31.87 · B ≈ 90.27 — 월 경계 세션 때문에 B 는 소수점 차이 가능 · NULL 0)
SELECT SUM(ENGAGEMENT_TIME_MSEC) / 1000 / NULLIF(COUNT(DISTINCT BIGQUERY_SESSION_KEY), 0) AS a_sec,
       SUM(SESSION_DURATION_SEC) / NULLIF(COUNT(DISTINCT BIGQUERY_SESSION_KEY), 0)         AS b_sec,
       COUNT_IF(SESSION_DURATION_SEC IS NULL)                                              AS null_rows
FROM GN_DW.GOLD.FACT_BIGQUERY_SESSION WHERE DATE_SK BETWEEN 20260901 AND 20260930;
-- 2-4 GA 백필 행수(기대 FACT_BIGQUERY_SESSION ≈ 1,190,210 = 배포 전과 같다)
SELECT COUNT(*) FROM GN_DW.GOLD.FACT_BIGQUERY_SESSION;

-- ============================================================================
-- 🔴 이 파일은 여기(D2)까지만 실행문이다. D3·D4 는 **다른 파일을 열어 전체 실행**한다.
--    🔴 D1 전에 D3 를 돌리면 SV 생성이 「invalid identifier D5_GIFT_PART_AMT / SESSION_DURATION_SEC」로 실패한다.
-- ============================================================================

-- [D3] 👤 SV 3종 = 각 파일을 열어 전체 실행(각 파일 끝 스모크 포함)
--   ① 05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql            (D5_GIFT_AMT · 규칙 (5) O241)
--   ② 05_SV-Agent_ai/05_12_SV_DDL_RELATION_ACTIVITY.sql  (TOTAL_GIFT_AMT 동의어 · COMMENT)
--   ③ 05_SV-Agent_ai/05_20_SV_DDL_GA_SESSION.sql         (AVG_SESSION_DURATION_SEC · 규칙 (6) · VQR)
--   🆕 [D3-②] ⑥ 동의어 배선(지표번호 토큰 '공NN'·'신규NN' 만 추가 · 판정표 tmp/o241/wiring_decisions.tsv) —
--      아래 17파일도 각각 전체 실행(위 3파일 포함 총 20파일 · 문법 = 임시 이름 생성 검증 19/19 PASS · 05_12 는 토큰 대상 아님):
--      05_01 · 05_02 · 05_03 · 05_06 · 05_07(CTR COMMENT 수치 제거 포함) · 05_08 · 05_09 · 05_10 · 05_11 ·
--      05_13 · 05_15 · 05_17 · 05_18 · 05_19 · 05_24 · 05_25 · 05_26
--      롤백 = tmp/o241/bak/*.O241-before 를 정본 자리로 되돌린 뒤 재실행
--   ④ D3 확인 — 세 파일 실행 후 주석을 풀어 실행:
-- SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS fse.D5_GIFT_AMT);                      -- 기대 1,303,750,000
-- SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_GA_SESSION
--          METRICS gs.AVG_SESSION_ENGAGEMENT_SEC, gs.AVG_SESSION_DURATION_SEC)
-- WHERE TRUE;                                                                                        -- 전기간 A·B 값(참고)

-- [D4] 👤 Agent 2종 = 05_SV-Agent_ai/09_2_AGENT_버전업.sql 로 MEMBER · MARKETING 버전업(🔴 D3 뒤에 · EXECUTIVE 는 변경 없음)

-- [D5] 스모크(👤 Snowflake Intelligence) — 기대 = A·B 두 값 + 각 정의 1줄 + 「잠정」
--   AGENT_MEMBER    「2026년 9월 선물금참여(원)」     → A = analyst_relation_activity TOTAL_GIFT_AMT · B = analyst_service D5_GIFT_AMT(75,330,000원)
--   AGENT_MARKETING 「2026년 9월 GA 평균세션시간」    → A ≈ 31.87초 · B ≈ 90.27초(analyst_ga_session 1회)
--   AGENT_MEMBER    「연도별 결연아동코드 수」        → O239 회귀(CHILD_CODE_CNT_A·B 병기)
--   AGENT_MEMBER    「클릭월별 미납서비스 전환율」    → O239 회귀(UNPAID_SVC_CONV_RATE_A·B 병기)

-- [D6] 롤백
--   SV  = 세 파일의 O241 변경 줄 되돌린 뒤 재실행(CREATE OR ALTER) · Agent = MEMBER·MARKETING VERSION$3
--   dbt = 직전 버전으로 ALTER DBT PROJECT … SET DEFAULT_VERSION 후 같은 --select build
--         (신설 열은 남아도 무해 — 0/NULL 로 채워질 뿐 기존 지표에 영향 없음 · DROP 은 하지 않는다)
