-- ============================================================================
-- 07_MSTR_일일적재_TASK.sql — MSTR 일일 적재(전월 + 당월) Task 정본 · 🆕 O207-C 확정(2026-10-07 · 사용자 결정 「일일 적재 확정」)
--   · 실행 역할 = GN_DW_ADMIN(프로시저 소유 · EXECUTE AS OWNER) · 운영계에서 실행한다.
--   · 근거 = `15_MSTR 이관 PoC/10_MSTR_일일적재_dbt연동_준비.md` §1~§4 · 실측(개발계 BCHLOG 2026-10-06):
--       1개 월 호출 ≈ 23초(차원 7종 재적재 포함) ⇒ 전월 + 당월 ≈ 1분.
--   · 🔴 프로시저는 dbt 산출물이 아니라 BRONZE_CRM 을 직접 읽는다 ⇒ 진짜 선행조건은 「BRONZE 적재 완료」다.
--       dbt 뒤에 붙이는 이유 = GOLD(dbt)와 MSTR 가 **같은 날 같은 BRONZE 상태**를 보게 하려는 것(Agent 가 두 기준을 함께 답한다).
--   · 🔴 일 배치 경로(USP_RUN_MSTR_1ST → USP_F_MM_SPNSR_DVLP_SUM)는 `DELETE … WHERE STRD_MT = 기준월` 만 한다
--       (라이브 GET_DDL 확인 2026-10-07) ⇒ 전월·당월 2회 호출은 다른 월을 지우지 않는다.
--       🔴 `USP_F_MM_SPNSR_DVLP_SUM_INIT`(전체 DELETE)은 일 배치에서 호출하지 마라.
--   · 🆕 [O207 운영계 반영 · 2026-10-07 · O208 개발계 동기화] 운영계는 [2] 대안(고정 07:30 KST)으로 생성했다.
--       [1] AFTER 는 운영계에서 실패했다 — dbt 일 배치 Task = GN_DW.OPS."daily"(06:01 KST · 소유 GN_DW_DBT) ·
--       Snowflake DAG 는 predecessor 와 **같은 스키마 · 같은 소유 역할**이어야 한다
--       (오류 ① 「Cannot have predecessor daily from a different schema」 ② GN_DW.OPS 에 만들면
--        「cannot have the given predecessor since they do not share the same owner role」).
--       운영계 EXECUTE TASK 1회 = SUCCEEDED(1분 15초) · mstr_verify 202601·202610 PASS(manifests/1차.json baseline).
--       🔴 운영계 RESUME 여부는 운영계 이력에 기록이 없다 — 운영계에서 SHOW TASKS 로 state 를 확인하라.
--       🔴 [1] 을 다시 쓰려면 MSTR Task 를 GN_DW.OPS 에 GN_DW_DBT 소유로 만들고 MSTR 프로시저 권한을 그 역할에 줘야 한다(미결정).
-- ============================================================================

USE ROLE GN_DW_ADMIN;

-- [0] 운영계 dbt 일 배치 Task 이름 확인(Snowsight dbt 프로젝트 스케줄도 Task 로 만들어진다)
SHOW TASKS IN DATABASE GN_DW;
-- SHOW TASKS IN ACCOUNT;   -- 위에서 안 보이면(다른 DB 에 스케줄을 만든 경우)

-- ----------------------------------------------------------------------------
-- [1] 🟢 권고안 = dbt Task 완료 직후 실행(AFTER) · 🔴 운영계에서는 DAG 제약으로 불가했다(머리 주석 O207 운영계 반영)
--   · 고정 07:00 보다 나은 점: dbt 소요(약 1시간)가 길어져도 겹치지 않고, 짧아지면 바로 시작한다 ·
--     dbt 가 실패하면 MSTR 도 돌지 않아 두 기준의 기준일이 어긋나지 않는다(실패 시 수동 재실행 = [4]).
--   · <DBT_TASK_FQN> 을 [0] 결과로 바꾼다(예: GN_DW.OPS.TSK_DBT_DAILY). 🔴 predecessor 는 같은 DB 안 Task 여야 한다.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TASK GN_DW.MSTR.TSK_RUN_MSTR_DAILY
  WAREHOUSE = GN_DW_ETL_WH
  AFTER <DBT_TASK_FQN>
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
  COMMENT = 'O207-C MSTR 일일 적재 — dbt 일 배치 완료 직후 전월·당월 재적재(USP_RUN_MSTR_1ST · I_HIST=FALSE)'
AS
BEGIN
  LET prev_ym VARCHAR := TO_CHAR(DATEADD(MONTH, -1, CONVERT_TIMEZONE('Asia/Seoul', CURRENT_TIMESTAMP())), 'YYYYMM');
  LET cur_ym  VARCHAR := TO_CHAR(CONVERT_TIMEZONE('Asia/Seoul', CURRENT_TIMESTAMP()), 'YYYYMM');
  LET r1 VARCHAR;
  LET r2 VARCHAR;
  CALL GN_DW.MSTR.USP_RUN_MSTR_1ST(:prev_ym, 'TASK', FALSE) INTO :r1;
  CALL GN_DW.MSTR.USP_RUN_MSTR_1ST(:cur_ym,  'TASK', FALSE) INTO :r2;
  -- 프로시저는 실패를 예외가 아니라 'ERROR …' 문자열로 돌려준다 ⇒ Task 실패로 바꿔야 SUSPEND·알림이 동작한다
  IF (CONTAINS(:r1, 'ERROR') OR CONTAINS(:r2, 'ERROR')) THEN
    LET e EXCEPTION (-20001, 'MSTR 일일 적재 실패');
    RAISE e;
  END IF;
  RETURN 'OK ' || :prev_ym || ',' || :cur_ym;
END;

-- ----------------------------------------------------------------------------
-- [2] 대안 = 고정 시각(dbt 가 Snowflake Task 가 아니어서 AFTER 를 쓸 수 없을 때만)
--   · 07:00 보다 07:30 KST 를 권한다(dbt 6:01 + 약 1시간 = 7:01 전후 종료 → 여유 30분).
--   · 고정 시각은 dbt 지연 시 같은 BRONZE 를 다른 시점에 읽을 수 있다 — 그래서 권고안이 아니다.
-- ----------------------------------------------------------------------------
-- CREATE OR REPLACE TASK GN_DW.MSTR.TSK_RUN_MSTR_DAILY
--   WAREHOUSE = GN_DW_ETL_WH
--   SCHEDULE = 'USING CRON 30 7 * * * Asia/Seoul'
--   SUSPEND_TASK_AFTER_NUM_FAILURES = 3
--   COMMENT = 'O207-C MSTR 일일 적재 — 고정 07:30 KST(대안)'
-- AS <[1] 과 같은 본문>;

-- [3] 가동 — 생성 후 별도 실행(R4-4-3 · 라이브 스케줄 시작)
-- ALTER TASK GN_DW.MSTR.TSK_RUN_MSTR_DAILY RESUME;

-- [4] 확인 · 수동 재실행
-- EXECUTE TASK GN_DW.MSTR.TSK_RUN_MSTR_DAILY;
-- SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, RETURN_VALUE, ERROR_MESSAGE
--   FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'TSK_RUN_MSTR_DAILY')) ORDER BY SCHEDULED_TIME DESC LIMIT 10;
-- SELECT * FROM GN_DW.MSTR.BCHLOG ORDER BY LOGKEY DESC LIMIT 20;
-- 검증 = python3 "15_MSTR 이관 PoC/tools/mstr_verify.py" manifests/1차.json --ym <당월>
