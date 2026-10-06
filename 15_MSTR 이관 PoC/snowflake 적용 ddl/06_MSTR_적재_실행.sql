-- ============================================================================
-- 06_MSTR_적재_실행.sql — GN_DW.MSTR 테이블 채우기(적재) · 검증 · 재실행 절차
--   🆕 [2026-10-03 O201-C] 작성
--   🔴 dbt 가 아니다 — MSTR 적재는 저장 프로시저 CALL 이다(dbt 모델·dbt build 와 무관).
--      · 구조(스키마·테이블·뷰·함수·프로시저) = 00~04 파일 · `tools/mstr_pipeline.py --steps deploy --apply`
--      · 데이터 = 이 파일의 [2] CALL · `tools/mstr_pipeline.py --steps run --apply [--hist]` 와 같은 SQL
--      · 검증 = [3] SQL · `tools/mstr_pipeline.py --steps verify --ym <YYYYMM>`(manifest baseline 대조)
--   🔴 선행 = BRONZE_CRM 적재 완료 · 00~04 배포 완료(이 파일 [0])
--   🔴 역할 = GN_DW_ADMIN(프로시저 owner · MSTR 테이블 DML)
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;

-- ----------------------------------------------------------------------------
-- [0] 선행 판정 — 객체 실재 · 원천 기준월
-- ----------------------------------------------------------------------------
SELECT TABLE_TYPE, COUNT(*) AS N
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MSTR'
GROUP BY 1;                                       -- 기대: BASE TABLE · VIEW 모두 > 0

SHOW PROCEDURES LIKE 'USP_RUN_MSTR_1ST' IN SCHEMA GN_DW.MSTR;   -- 1행

SELECT MIN(LEFT(OCCRRNC_DE, 6)) AS FIRST_YM,
       MAX(LEFT(OCCRRNC_DE, 6)) AS LAST_YM,
       COUNT(DISTINCT LEFT(OCCRRNC_DE, 6)) AS YM_CNT
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT;   -- [2] 의 기준월(I_YM)은 LAST_YM 이하에서 고른다

-- ----------------------------------------------------------------------------
-- [1] 적재 전 상태(기록용)
-- ----------------------------------------------------------------------------
SELECT TABLE_NAME, ROW_COUNT
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MSTR' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY 1;

-- ----------------------------------------------------------------------------
-- [2] 적재 — 🆕 [O201-D 운영계] **2026-01 ~ 원천 최신월만** 적재한다(2026 이전 제외)
--   · 매 월 USP_RUN_MSTR_1ST(월, 'OPER', FALSE) = 차원 7종 + 그 달 원장 + 그 달 집계
--   · 🟢 과거 전 월 이력(I_HIST=TRUE)은 더 이상 필요 없다 — 집계의 「후원금액대2(SPNSR_AMT2_CD)」가 쓰던
--     「후원사업별 최초 개발금액」 조회를 원장(F) 대신 원천(BRONZE)에서 직접 읽도록 04 [9] 를 바꿨다
--     (개발계 대조: 조회 결과 2,092,147건 완전 일치 · 202601 baseline PASS).
--   · 🔴 선행 = 수정된 04_sp_script.sql 을 운영계에 배포(00~04 순서 · 이 파일 [0] 로 확인)
--   · 원천 월 상한은 오늘 기준 월까지(센티넬 999912 등 미래월 제외)
--   · 예상 소요 = 개발계 실측 기준 월당 약 30초(Small)
-- ----------------------------------------------------------------------------
EXECUTE IMMEDIATE $$
DECLARE
  V_LOG VARCHAR DEFAULT '';
  V_RET VARCHAR;
  V_YM  VARCHAR;
  RS RESULTSET DEFAULT (
    SELECT DISTINCT LEFT(OCCRRNC_DE, 6) AS YM
    FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
    WHERE LEFT(OCCRRNC_DE, 6) BETWEEN '202401' AND TO_CHAR(CURRENT_DATE(), 'YYYYMM')
    ORDER BY YM);
  C1 CURSOR FOR RS;
BEGIN
  FOR R IN C1 DO
    V_YM := R.YM;
    CALL GN_DW.MSTR.USP_RUN_MSTR_1ST(:V_YM, 'OPER', FALSE) INTO :V_RET;
    V_LOG := V_LOG || V_YM || '=' || IFF(V_RET LIKE '%ERROR%', 'ERROR', 'OK') || ' ';
  END FOR;
  RETURN V_LOG;
END;
$$;
--   기대: 「202601=OK 202602=OK …」 · ERROR 가 있으면 BCHLOG 의 ERRMSG 를 본다
-- CALL GN_DW.MSTR.USP_RUN_MSTR_1ST('202602', 'OPER', FALSE);  -- 이후 월 정기(1개월)

-- ----------------------------------------------------------------------------
-- [3] 검증
-- ----------------------------------------------------------------------------
SELECT TABLE_NAME, ROW_COUNT
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MSTR' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY 1;                                       -- 전건 > 0 (BCHLOG 포함)

SELECT STRD_MT, COUNT(*) AS ROWS_CNT
FROM GN_DW.MSTR.F_MM_SPNSR_DVLP
GROUP BY 1
ORDER BY 1 DESC
LIMIT 12;                                         -- 월별 적재 분포

SELECT *
FROM GN_DW.MSTR.BCHLOG
ORDER BY 1 DESC
LIMIT 20;                                         -- 프로시저 실행 로그 · 오류는 USP_BCHERR 경유

SELECT COUNT(*) AS VIEW_ROWS
FROM GN_DW.SERVING.MSTR_SPNSR_DVLP_V;             -- AGENT_MSTR 가 읽는 서빙 뷰 > 0
--   baseline(리포트 답안) 대조 = python3 "15_MSTR 이관 PoC/tools/mstr_verify.py" manifests/1차.json --ym 202601

-- ----------------------------------------------------------------------------
-- [4] (선택) 월 정기 자동화 — Task (설계안 · 승인 후 생성)
-- ----------------------------------------------------------------------------
-- CREATE TASK GN_DW.MSTR.TSK_RUN_MSTR_1ST
--   WAREHOUSE = GN_DW_ETL_WH
--   SCHEDULE = 'USING CRON 0 6 2 * * Asia/Seoul'
-- AS
--   CALL GN_DW.MSTR.USP_RUN_MSTR_1ST(TO_CHAR(DATEADD(MONTH, -1, CURRENT_DATE()), 'YYYYMM'), 'TASK', FALSE);
