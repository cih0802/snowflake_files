-- ============================================================================
-- 28_O237C_G1해소_배포순서.sql — O237-C 배포 실행 순서(사람 실행 · 라이브 DDL·dbt 포함 = R4-4-3 승인 대상)
--   · 대상 = G1 3건 해소: 공#31 최종캠페인 · 공#79 후원사업별 미납율 · 신규#33 클릭대비 전환율(5일·30일)
--   · 사전 검증(ua91864 · 2026-10-16 · 라이브 GOLD 대상 렌더 등가 SQL · 라이브 무변경)
--     LAST_CAMPAIGN = 1,621,462명 채움(DIM_MEMBER 1,800,737) · fan-out 0 · DIM_CAMPAIGN 미매칭 2
--     FACT_SPONSORSHIP_MONTHLY 202609 = 활동 1,574,434.2317 · 미납 2,471,716,927원(FMM 과 DIFF 0) · 전체 미납율 15.6991%
--     클릭대비 전환(2025~ · 클릭일 기준 · 인정 개발) = 클릭 126,799명 · D+1~5 377명 · D+1~30 1,839명
--   · 백업 = tmp/o237c/bak/*.O237C-before
-- Co-authored with CoCo
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- [C0] 🔴 GA(BigQuery) 백필 — 2026-10-16 전체 빌드에서 GA 계열이 새로 생성되며 롤링 창(오늘−3일) 밖이라 0행이 됐다
--   실측 = SILVER.BIGQUERY_REFINED_DATA 11,324,179행(20240121~20261003) · SILVER.BIGQUERY_* / GOLD.FACT_BIGQUERY_* 전부 0행
--   ⇒ SV_GA_BEHAVIOR·SV_GA_SESSION 이 빈 결과를 낸다. 정본 명령 = 10_dbt_pipeline/02_dbt_parse_compile_build.sql:32 (그대로 실행)
-- EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select BIGQUERY_BASIC+ BIGQUERY_SESSION+ FACT_MESSAGE_DISPATCH+ FACT_BIGQUERY_SESSION+ --vars ''{"bigquery_dt_ranges": [["1945-01-01", "9999-12-31"]]}''';
--   🟢 이 명령이 FACT_MESSAGE_DISPATCH+ 를 포함하므로 아래 [C3] 의 FMD 는 이때 함께 빌드돼도 된다(멱등)
--   🔴 순서 = [C1] → [C2] → [C0] → [C3](C2 의 ALTER 가 먼저여야 신규 열 COMMENT 가 남는다 — dbt 가 먼저 만들면 IF NOT EXISTS 로 건너뛴다)
--   백필 후 G1 잔여 2(결연아동코드 URL 파싱 · 미납서비스 전환율 GA 클릭) 설계를 이어간다(사용자 결정)

-- [C1] 신규 테이블 단독 생성(🔴 06_DDL.sql 전체를 다시 돌리지 마라 — CREATE OR REPLACE 로 GOLD 전량이 비워진다)
--      06_DDL.sql 의 「FACT_SPONSORSHIP_MONTHLY」 CREATE 블록을 IF NOT EXISTS 로 바꿔 실행한 뒤 FK 1줄
-- ALTER TABLE GN_DW.GOLD.FACT_SPONSORSHIP_MONTHLY ADD CONSTRAINT FK_FSM_DIM_SPONSORSHIP
--     FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GN_DW.GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK) NOT ENFORCED NORELY;

-- [C2] 기존 테이블 열 추가(append_new_columns 로도 추가되지만 COMMENT 정본을 위해 먼저 ALTER)
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS LAST_CAMPAIGN VARCHAR
    COMMENT '최종캠페인 코드(공#31 · 잠정) = 회원의 가장 최근 시작 후원약정 대표캠페인(FACT_MEMBER_SPONSORSHIP_SPAN.SPNSR_CMPGN_CD). 후원약정이 없는 회원은 NULL. CRM 발송명단 LAST_CMPGN 과는 정의가 다르다.';
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD COLUMN IF NOT EXISTS CLICK_DEV_D5_MEMBERS NUMBER(1,0)
    COMMENT '클릭 후 D+1~D+5 안에 인정 개발(FME DEV_CNT>0)이 있는 클릭 발송 1/0. 클릭이 없는 행·처리통보성 제목은 0. 잠정(창 길이 현업 확인).';
ALTER TABLE GN_DW.GOLD.FACT_MESSAGE_DISPATCH ADD COLUMN IF NOT EXISTS CLICK_DEV_D30_MEMBERS NUMBER(1,0)
    COMMENT '클릭 후 D+1~D+30 안에 인정 개발이 있는 클릭 발송 1/0(D5 를 포함한다). 잠정.';

-- [C3] 👤 dbt build(Workspaces dbt 또는 EXECUTE DBT PROJECT)
--   dbt build --select DIM_MEMBER FACT_SPONSORSHIP_MONTHLY FACT_MESSAGE_DISPATCH FACT_AD_PERFORMANCE
--   🆕 [O238 W3-L4] FACT_AD_PERFORMANCE = 영상 코드형 상위캠페인(U####) → 마케팅캠페인 4순위 경로(MKTG_MAP_METHOD = 'UPPER_CODE')
--      사전 측정 = 영상 미매핑 광고비 6,495,060,604.55 → 5,924,770,020.00원(3,406행 연결 · 95.9% → 87.5%)

-- [C4] 대사(기대 = 주석 값)
-- 4-1 LAST_CAMPAIGN 채움(기대 ≈ 1,621,462 · 신규 열 비NULL > 0)
SELECT COUNT(*) AS ROWS_, COUNT(LAST_CAMPAIGN) AS FILLED FROM GN_DW.GOLD.DIM_MEMBER;
-- 4-2 FSM 월별 합 = FMM 합(기대 = BAD 0 · 전 월) · 키 중복 0
WITH f AS (SELECT BASE_MONTH_KEY MK, SUM(ACTIVE_CNT) A, SUM(UNPAID_BILLED_AMT) U, SUM(PAID_FEE_BILLABLE) P
           FROM GN_DW.GOLD.FACT_SPONSORSHIP_MONTHLY GROUP BY 1),
     m AS (SELECT MONTH_KEY MK, SUM(ACTIVE_CNT) A, SUM(UNPAID_BILLED_AMT) U, SUM(PAID_FEE_BILLABLE) P
           FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY WHERE MONTH_KEY > 0 GROUP BY 1)
SELECT COUNT(*) MONTHS,
       COUNT_IF(ABS(COALESCE(f.A,0)-COALESCE(m.A,0)) > 0.001) BAD_ACTIVE,
       COUNT_IF(ABS(COALESCE(f.U,0)-COALESCE(m.U,0)) > 0.5)   BAD_UNPAID,
       COUNT_IF(ABS(COALESCE(f.P,0)-COALESCE(m.P,0)) > 0.5)   BAD_PAID
FROM m FULL OUTER JOIN f ON f.MK = m.MK;
SELECT COUNT(*) - COUNT(DISTINCT BASE_MONTH_KEY, SPONSORSHIP_SK) AS DUP_KEYS FROM GN_DW.GOLD.FACT_SPONSORSHIP_MONTHLY;
-- 4-3 클릭 전환(기대 2025~ = 클릭 126,799 · D5 ≤ 377 · D30 ≤ 1,839 — 처리통보성 제목 제외분만큼 작을 수 있다)
SELECT COUNT(DISTINCT IFF(OPEN_MEMBERS = 1, MEMBER_DK, NULL))          AS CLICK_MEMBERS,
       COUNT(DISTINCT IFF(CLICK_DEV_D5_MEMBERS = 1, MEMBER_DK, NULL))  AS DEV_D5,
       COUNT(DISTINCT IFF(CLICK_DEV_D30_MEMBERS = 1, MEMBER_DK, NULL)) AS DEV_D30
FROM GN_DW.GOLD.FACT_MESSAGE_DISPATCH WHERE DATE_SK >= 20250101;

-- [C5] SV 5종 재배포(각 파일 전체 실행)
--   05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql     (last_campaign 별칭 · 차원 3)
--   05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql (fsm 테이블 · 차원 2 · metric 4)
--   05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql            (클릭 전환 metric 5 · 규칙 (5) 예외)
--   05_SV-Agent_ai/05_25_SV_DDL_CAMPAIGN_MONTHLY.sql   (🆕 소규모 이상치 규칙 = 분모 100건 미만 순위 제외 · 사용자 결정)
--   05_SV-Agent_ai/05_07_SV_DDL_AD.sql                 (🆕 O238 W1 RT_TYPE 동의어 「특집」 = 값 '방송')
-- 4-4 영상 연결(기대 UPPER_CODE 3,406행 · 영상 미매핑 ≈ 5,924,770,020원)
SELECT MKTG_MAP_METHOD, COUNT(*) N, SUM(AD_COST) COST FROM GN_DW.GOLD.FACT_AD_PERFORMANCE
WHERE AD_SOURCE_TYPE = 'VIDEO' GROUP BY 1 ORDER BY 1;

-- [C6] 코퍼스 재적재 = 05_SV-Agent_ai/26_BIZ_DEFINITION_CORPUS_DDL_적재.sql 전체 실행
--   기대 COVERAGE(HAS_FORMULA='Y') = C1 65 · C2 17 · C3 8 · C4 20 · C5 31 · G1 2 · G2 3 · 합 146
--   CSV 는 이미 재생성됨(o237_build_formula_map.py → build_biz_definition_corpus.py · 2,156행)
SELECT COVERAGE, COUNT(*) N FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS WHERE HAS_FORMULA = 'Y' GROUP BY ROLLUP(COVERAGE) ORDER BY 1;

-- [C7] Agent = 변경 없음(도구 analyst_member_monthly · analyst_member_sponsor_biz · analyst_service 이미 배선)

-- [C8] 스모크(👤 또는 DATA_AGENT_RUN)
--   ① AGENT_MEMBER 「최종캠페인별 회원수」 → LAST_CAMPAIGN_NAME · 「잠정」 문구
--   ② AGENT_MEMBER 「2026년 9월 후원사업별 미납율」 → SPONSORSHIP_UNPAID_RATE · 전체 ≈ 15.70%
--   ③ AGENT_MEMBER 「2025년 이후 클릭대비 전환율」 → 5일·30일 두 값과 회원수

-- [C9] 롤백 = tmp/o237c/bak/*.O237C-before 를 정본 자리로 되돌린 뒤 같은 파일 재실행 · FACT_SPONSORSHIP_MONTHLY 는 DROP
--   🔴 05_10 백업은 첫 편집 이후 사본이다(fsm TABLES·RELATIONSHIPS 가 이미 들어 있음) — 롤백 시 그 두 블록을 손으로 걷어낸다
