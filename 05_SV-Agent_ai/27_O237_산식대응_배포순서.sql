-- ============================================================================
-- O237 산식 대응 개선 — 배포 실행 순서(사람 실행 · 라이브 객체 CREATE OR ALTER/REPLACE 포함 = R4-4-3 승인 대상)
--   · 정본 매핑표(LLM 소비용) = 12_agent개선과제/tools/O237_formula_wiring_overlay.csv
--     생성기 = 12_agent개선과제/tools/o237_build_formula_map.py (--check = 라이브 SV 필드 실재 대조)
--   · dbt 불필요(GOLD 무변경 · 신규 metric 은 기존 컬럼만 쓴다)
--   · 사전 검증(ua91864 · 2026-10-16 · GN_DW.OPS probe SV 5종 생성 → 조회 → DROP) = 5종 컴파일 OK ·
--     202609 값 = 중단(건) 23,583.1199 · 1명당 2.1587 · 평균약정 21,587원 · 납입율 96.03% · 누계납입율(1~9월) 96.3905%(GOLD 직접 = 동일) ·
--     평균납입금액 20,729원 · 캠페인별 미납(건) 247,171.69 · 캠페인 신규중단율 98.43% · 서신 0.123% · 선물금 0.0858% · 증액 0.0723%
-- Co-authored with CoCo
-- ============================================================================

-- [1] SV 5종 재배포(각 파일 전체 실행 — USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크)
--   05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql        (+6 metric · PAYMENT_RATE_FEE 동의어 '납입률' 제거)
--   05_SV-Agent_ai/05_09_SV_DDL_MEMBER_FEE.sql            (+1 metric · PAYMENT_RATE_FEE 동의어 '납입율' 제거)
--   05_SV-Agent_ai/05_19_SV_DDL_PAYMENT_BILLING_STATUS.sql (+1 metric)
--   05_SV-Agent_ai/05_24_SV_DDL_CAMPAIGN_CUM_STOP.sql      (+1 metric)
--   05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql                (+3 metric · 잠정 · 분모 현업 확인 대상)

-- [2] 코퍼스 재적재 + Cortex Search 재생성(열 +2 = COVERAGE · ANSWER_GUIDE)
--   05_SV-Agent_ai/26_BIZ_DEFINITION_CORPUS_DDL_적재.sql 전체 실행
--   🔴 선행 = 워크스페이스 CSV 가 O237 판(2,156행 · 17열)인지 확인 — 재생성 명령:
--     python3 12_agent개선과제/tools/o237_build_formula_map.py && python3 12_agent개선과제/tools/build_biz_definition_corpus.py

-- [3] Agent 3종 버전업(정본 spec 반영 = 검색 열 +4 · [O237 산식 대응] 규칙 1문장)
--   05_SV-Agent_ai/09_2_AGENT_버전업.sql

-- [4] 배포 후 검증
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 4-1 신규 metric 실재(기대 12행)
SHOW SEMANTIC METRICS IN SCHEMA GN_DW.SERVING
->> SELECT "semantic_view_name", "name" FROM $1
    WHERE "name" IN ('STOP_AMT_CNT_SUM', 'CNT_PER_ACTIVE_MEMBER', 'AVG_PLEDGE_AMT', 'PAY_IN_RATE',
                     'REGULAR_ONETIME_FEE_SUM', 'ONETIME_ONETIME_FEE_SUM', 'AVG_PAID_PER_MEMBER', 'UNPAID_CNT_EQ',
                     'CUM_STOP_RATE_DEV', 'D5_LETTER_RATE', 'D5_GIFT_RATE', 'D5_INCREASE_RATE')
    ORDER BY 1, 2;

-- 4-2 코퍼스 대응 상태(기대 = O237-B 반영본 C1 64 · C2 17 · C3 8 · C4 19 · C5 30 · G1 5 · G2 3 · 합 146)
SELECT COVERAGE, COUNT(*) AS N
FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS
WHERE HAS_FORMULA = 'Y'
GROUP BY ROLLUP(COVERAGE)
ORDER BY COVERAGE;

-- 4-3 검색 상위 1건이 산식 행을 돌려주고 COVERAGE 가 붙는지(예: 공62 납입율)
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('GN_DW.SERVING.SEARCH_BIZ_DEFINITION',
  '{"query":"납입율 계산식","columns":["DOC_ID","TITLE","COVERAGE","TOOL_NAME","SV_FIELD"],"filter":{"@eq":{"HAS_FORMULA":"Y"}},"limit":3}')):results AS TOP3;

-- 4-4 라이브 필드 실재 대조(워크스페이스 터미널) — 기대 = 라이브 부재 0 · PENDING 전부 라이브(B 포함 · 개수는 도구 출력으로 확인)
--   python3 12_agent개선과제/tools/o237_build_formula_map.py --check

-- [5] Agent 스모크(👤 Snowflake Intelligence) — 기대 = 근사 질문 없이 해당 도구로 계산
--   ① 「2026년 9월 납입율 계산해줘」 → analyst_member_monthly · PAY_IN_RATE(≈96.03%) · 납부율(85.92%)과 구분해 설명
--   ② 「2026년 9월 기준 연도별 캠페인 신규 중단율」 → analyst_campaign_cum_stop · CUM_STOP_RATE_DEV
--   ③ 「최종캠페인별 회원수」 → G1(남은 5건 중 하나) = 「현재 산출 불가 — 모델 추가 예정」 + 대체 지표 제시(근사 계산 금지) · 🔴 [O237-B] 종전 ③ 「캠페인별 납입율」은 B 반영 후 ⑤ 계열(산출 가능)로 옮겼다
--   ④ 「서비스별 서신 참여율」 → D5_LETTER_RATE + 분모 해석(발송 대상) 명시

-- [6] 롤백
--   SV = tmp/o237/bak/<파일>.O237-before 를 정본 자리로 되돌려 같은 파일 재실행
--   Agent = 09_2 의 이전 VERSION 으로 ALTER AGENT … (09_2 롤백 절 참조)
--   코퍼스 = tmp/o237/bak/O217_biz_definition_corpus.csv.O237-before 를 output 으로 되돌리고 tmp/o237/bak/26.O237-before 로 26 재실행

-- ============================================================================
-- 🆕 [O237-B] 캠페인 월 팩트 + 서비스 코호트 확장 — 위 [1]~[3] 과 **함께 한 번에** 진행한다(코퍼스·Agent 는 B 반영본이 정본)
--   🔴 전체 실행 순서 = B1 → B2 → B3 → [1] SV 5종 + B4 SV 2종 → [2]=B5 코퍼스 → [3]=B6 Agent → [4] → [5]·B7 스모크
--      (Agent 를 SV 보다 먼저 올리면 analyst_campaign_monthly 가 죽은 도구가 된다 — 배포는 실패하지 않으므로 순서로 막는다)
--   · 사전 검증(ua91864 · 2026-10-16 · 모델 렌더본 임시 테이블 · 라이브 무변경)
--     FACT_CAMPAIGN_MONTHLY = 202601·202609 의 활동·전월말·중단·개발·감액·이탈·납입·미납 8종 FMM 합과 DIFF 0 · 키 중복 0 ·
--       누계중단 246,039.2325 · 누계개발 249,973.7993 · 연도초 1,535,186.1022 = FCCS 와 같다
--     WIDE_MEMBER_SERVICE_COHORT = 기존 45열이 라이브 뷰와 양방향 MINUS 0(6,602,895행) · 신규 6열은 미수신 행 전부 NULL/FALSE
-- ============================================================================
-- [B1] 👤 05_25b [0] FACT_CAMPAIGN_MONTHLY 테이블 단독 생성(06_DDL 블록 복사 · IF NOT EXISTS) + FK 2줄
-- [B2] 👤 dbt build --select FACT_CAMPAIGN_MONTHLY WIDE_MEMBER_SERVICE_COHORT
-- [B3] 05_25b [1]~[4] 대사(기대 = [1] BAD_* 전부 0 · [2] DIFF 0)
-- [B4] SV = 05_SV-Agent_ai/05_25_SV_DDL_CAMPAIGN_MONTHLY.sql(신규) · 05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql(+6 차원 · +6 metric)
-- [B5] 26 코퍼스(위 [2] 와 같은 실행 1회 · 기대 COVERAGE = C1 64 · C2 17 · C3 8 · C4 19 · C5 30 · G1 5 · G2 3)
-- [B6] 09_2 Agent 3종(위 [3] 과 같은 실행 1회 · 도구 +1 analyst_campaign_monthly · [O237-B] 규칙)
--   🔴 09_2 의 COPY FILES 대상에 신규 리소스가 없다 — spec 파일만 바뀌므로 추가 작업 없음
-- [B7] 스모크(👤 Snowflake Intelligence)
--   ⑤ 「2026년 9월 기준 캠페인별 활동율」 → analyst_campaign_monthly · ROLLUP 전체 = 팩트 직접식
--   ⑥ 「연도별 캠페인 미납율」 → 연도마다 마지막 마감 기준월 1개씩
--   ⑦ 「서신참여회원의 6개월 유지율」(MEMBER) → analyst_service_cohort · D5_LETTER_FLAG + RETAINED_6M_RATE
--   ⑧ 「캠페인별 납입방식 활동율」 → SETTLE_METHOD 분해 + 「잠정 축」 문구
-- [B8] 롤백 = tmp/o237b/bak/*.O237B-before 를 정본 자리로 되돌린다(모델·yml·06_DDL·05_18·Agent 3종) · 신규 05_25·FACT 는 DROP
