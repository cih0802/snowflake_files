-- doc_id: A3 · as_of: 2026-10-20 · 🔴 미실행 · 목적: GN_DW_ANALYST 사용자 CoCo 차단(사용자 단위 우회안) 적용·동기화·롤백 · 설명: A3_CoCo_ANALYST_차단.md
-- 🔴 운영계에서 단계별 승인 후 블록 단위로 실행한다.
-- 🔴 차단은 사용자 단위다 — 그 사용자는 어떤 롤로 접속해도 CoCo 가 막힌다(롤 단위 차단은 플랫폼에 없다 · md §2).

-- =====================================================================
-- [0] 사전 확인 (읽기 전용 · A3_CoCo_ANALYST_차단_근거.sql 과 같음)
-- =====================================================================
USE ROLE ACCOUNTADMIN;
SHOW GRANTS OF ROLE GN_DW_ANALYST;                                   -- 대상 사용자 목록
SHOW PARAMETERS LIKE 'CORTEX_CODE%' IN USER <TEST_USER>;              -- 적용 전 값(-1 기대)

-- =====================================================================
-- [1] 테스트 사용자 1명 적용 (S3 게이트 승인 후)
-- =====================================================================
ALTER USER <TEST_USER> SET
  CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = 0
  CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = 0
  CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER = 0;

SHOW PARAMETERS LIKE 'CORTEX_CODE%' IN USER <TEST_USER>;              -- 0 · level = USER 확인

-- 확인 항목(사람이 수행) — md §4-3 체크표에 기록
--   ㉠ Snowsight CoCo 패널이 차단되는가
--   ㉡ Snowflake Intelligence(CoWork)에서 Agent 3종 질의가 계속 되는가
--   ㉢ SQL 로 Agent 호출(DATA_AGENT_RUN 등)·Cortex Analyst 가 계속 되는가
--   ㉣ CLI·Desktop 사용 시 차단되는가(해당 사용자가 쓰는 경우만)

-- =====================================================================
-- [1-R] 테스트 롤백
-- =====================================================================
ALTER USER <TEST_USER> UNSET
  CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER,
  CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER,
  CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER;

-- =====================================================================
-- [2] 롤 동기화 — ANALYST 직접 보유 사용자에게 0, 빠진 사용자는 원복
--     ⚠️ 권한 요건 미확정: 다른 사용자의 파라미터를 바꾸려면 그 사용자에 대한 OWNERSHIP 또는
--        동등 권한이 필요하다 ⇒ 소유 롤(USERADMIN/ACCOUNTADMIN)을 운영계에서 확인한 뒤 생성한다(md §5 Q3).
--     · 등록부(OPS.COCO_BLOCK_REGISTRY)에 「이 절차가 0 으로 만든 사용자」만 남긴다 ⇒
--       사람이 따로 0 으로 둔 사용자를 원복하지 않는다.
-- =====================================================================
USE ROLE GN_DW_ADMIN;
CREATE TABLE IF NOT EXISTS GN_DW.OPS.COCO_BLOCK_REGISTRY (
    USER_NAME   STRING        NOT NULL COMMENT '이 절차가 CoCo 한도를 0 으로 설정한 사용자',
    REASON_ROLE STRING        NOT NULL COMMENT '차단 근거 롤(GN_DW_ANALYST)',
    BLOCKED_AT  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT '설정 시각',
    CONSTRAINT PK_COCO_BLOCK_REGISTRY PRIMARY KEY (USER_NAME)
)
COMMENT = 'A3 CoCo 차단 동기화 등록부 — USP_SYNC_COCO_BLOCK 만 쓴다';

CREATE TABLE IF NOT EXISTS GN_DW.OPS.COCO_BLOCK_EXEMPT (
    USER_NAME STRING NOT NULL COMMENT '차단 예외 사용자(승인 근거를 NOTE 에)',
    NOTE      STRING COMMENT '승인자·사유',
    CONSTRAINT PK_COCO_BLOCK_EXEMPT PRIMARY KEY (USER_NAME)
)
COMMENT = 'A3 CoCo 차단 예외 — ANALYST 이지만 CoCo 를 허용할 사용자';

-- 프로시저 소유 롤 = 사용자 파라미터 변경 권한이 있는 롤(운영계 확인 후 <OWNER_ROLE> 치환)
USE ROLE <OWNER_ROLE>;
CREATE OR REPLACE PROCEDURE GN_DW.OPS.USP_SYNC_COCO_BLOCK(DRY_RUN BOOLEAN)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS OWNER
AS
$$
PARAMS = [
    'CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER',
    'CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER',
    'CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER',
]


def q(name):
    return '"' + name.replace('"', '""') + '"'


def run(session, dry_run):
    grants = session.sql('SHOW GRANTS OF ROLE GN_DW_ANALYST').collect()
    target = {r['grantee_name'] for r in grants if r['granted_to'] == 'USER'}
    exempt = {r['USER_NAME'] for r in session.table('GN_DW.OPS.COCO_BLOCK_EXEMPT').collect()}
    target -= exempt
    blocked = {r['USER_NAME'] for r in session.table('GN_DW.OPS.COCO_BLOCK_REGISTRY').collect()}
    add, remove = sorted(target - blocked), sorted(blocked - target)
    if not dry_run:
        for u in add:
            session.sql('ALTER USER ' + q(u) + ' SET ' + ' '.join(p + ' = 0' for p in PARAMS)).collect()
            session.sql("INSERT INTO GN_DW.OPS.COCO_BLOCK_REGISTRY (USER_NAME, REASON_ROLE) VALUES (?, 'GN_DW_ANALYST')",
                        params=[u]).collect()
        for u in remove:
            session.sql('ALTER USER ' + q(u) + ' UNSET ' + ', '.join(PARAMS)).collect()
            session.sql('DELETE FROM GN_DW.OPS.COCO_BLOCK_REGISTRY WHERE USER_NAME = ?', params=[u]).collect()
    return {'dry_run': dry_run, 'block': add, 'unblock': remove, 'exempt': sorted(exempt)}
$$;

CALL GN_DW.OPS.USP_SYNC_COCO_BLOCK(TRUE);                            -- 먼저 DRY RUN 결과를 검토한다
-- CALL GN_DW.OPS.USP_SYNC_COCO_BLOCK(FALSE);                        -- 승인 후 실제 적용

-- [2-T] 정기 동기화 — 롤 부여·회수가 사람 손으로 일어나므로 매일 1회(및 온보딩 직후 수동 CALL)
CREATE TASK IF NOT EXISTS GN_DW.OPS.TSK_SYNC_COCO_BLOCK
  WAREHOUSE = GN_DW_ETL_WH
  SCHEDULE = 'USING CRON 0 7 * * * Asia/Seoul'
  COMMENT = 'A3 CoCo 차단 동기화(GN_DW_ANALYST 직접 보유 사용자)'
AS
  CALL GN_DW.OPS.USP_SYNC_COCO_BLOCK(FALSE);
-- ALTER TASK GN_DW.OPS.TSK_SYNC_COCO_BLOCK RESUME;                  -- 승인 후

-- =====================================================================
-- [2-R] 전체 롤백 — 등록부 사용자만 원복 후 객체 제거
-- =====================================================================
-- ALTER TASK GN_DW.OPS.TSK_SYNC_COCO_BLOCK SUSPEND;
-- 등록부 사용자 원복(목록 = SELECT USER_NAME FROM GN_DW.OPS.COCO_BLOCK_REGISTRY;) — 사용자마다:
--   ALTER USER <U> UNSET CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER,
--     CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER, CORTEX_CODE_DESKTOP_DAILY_EST_CREDIT_LIMIT_PER_USER;
-- DROP TASK GN_DW.OPS.TSK_SYNC_COCO_BLOCK;
-- DROP PROCEDURE GN_DW.OPS.USP_SYNC_COCO_BLOCK(BOOLEAN);
-- DROP TABLE GN_DW.OPS.COCO_BLOCK_REGISTRY;
-- DROP TABLE GN_DW.OPS.COCO_BLOCK_EXEMPT;
