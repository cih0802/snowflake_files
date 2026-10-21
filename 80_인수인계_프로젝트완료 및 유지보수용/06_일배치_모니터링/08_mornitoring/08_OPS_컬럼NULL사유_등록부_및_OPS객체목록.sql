-- =============================================================================
-- Purpose    : 08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql
-- Target     : TABLE GN_DW.OPS.NULL_REASON_CODE, TABLE GN_DW.OPS.COLUMN_NULL_REGISTRY, VIEW GN_DW.OPS.V_OPS_OBJECT_INVENTORY
-- Run order  : 운영계 #3
-- Depends on : GN_DW.INFORMATION_SCHEMA.TABLES, GN_DW.INFORMATION_SCHEMA.PROCEDURES, GN_DW.INFORMATION_SCHEMA.FUNCTIONS, GN_DW.INFORMATION_SCHEMA.STAGES
-- Issue      : O216-G, DEC-55
-- =============================================================================
-- ============================================================================
-- 08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql
-- ----------------------------------------------------------------------------
--  [2026-10-12 O216-G · 사용자 승인] OPS 스키마 수기 객체 3종의 정본 DDL.
--   ① OPS.NULL_REASON_CODE — NULL 사유 코드 마스터(분류 정본 = 문서30 DEC-55 §55-C · 지침 R2-7)
--   ② OPS.COLUMN_NULL_REGISTRY — SILVER·GOLD 「전건 NULL」 컬럼의 사유 등록부(컬럼 1행)
--   ③ OPS.V_OPS_OBJECT_INVENTORY — OPS 스키마 객체 목록(관리 주체 자동 판정 · 수기 관리 불요)
--
-- ▶ 왜 테이블인가(문서 부록이 아니라)
--   · SQL 로 「사유별 NULL 컬럼 수」·「재배선 조건 충족 여부」를 질의할 수 있다.
--   · 컬럼 COMMENT 의 사유 코드 `[NULL: <코드>]` ↔ 등록부 코드를 **게이트로 대조**할 수 있다(문서는 못 한다).
--   · 이력은 이 테이블이 아니라 원장·세션이력에 둔다(UPDATED_* 는 최종 변경 1건만).
--
-- ▶ 왜 OPS 인가(GOLD 가 아니다)
--   · GOLD 는 소비 계층(SV·Agent 가 읽는다) — 메타데이터 등록부를 섞으면 Analyst 탐색 대상이 된다.
--   · OPS = ETL 운영 인프라(`02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql:165`) · dbt store_failures 와 같은 축.
--
-- ▶ 실행 규약
--   · 실행 롤 = GN_DW_ADMIN · 재실행 안전(테이블 = IF NOT EXISTS · 코드 = MERGE · 뷰 = OR REPLACE … COPY GRANTS).
--   · WARN: `CREATE OR REPLACE TABLE` 로 바꾸지 마라 — 등록부 내용(다음 세션 산출물)이 사라진다.
--   · 재구축 순서 = `60_repeat_어카운트시작/12_GN_DW_재구축_실행순서.md` §2-1 순 17.
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ETL_WH;

-- ----------------------------------------------------------------------------
-- ① NULL 사유 코드 마스터
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS GN_DW.OPS.NULL_REASON_CODE (
    REASON_CODE      VARCHAR   NOT NULL COMMENT '사유 코드(영문 대문자 · 컬럼 COMMENT 의 [NULL: <코드>] 와 같은 값).',
    REASON_NAME      VARCHAR   NOT NULL COMMENT '사유 이름(한국어).',
    REASON_DESC      VARCHAR            COMMENT '판정 기준 — 이 코드를 붙이는 조건.',
    REWIRE_POSSIBLE  BOOLEAN            COMMENT '원천·결정이 바뀌면 재배선될 수 있는가(TRUE = 대기성 · FALSE = 영구).',
    SORT_ORDER       NUMBER(3,0)        COMMENT '표시 순서.',
    CONSTRAINT PK_NULL_REASON_CODE PRIMARY KEY (REASON_CODE)
) COMMENT = 'NULL 사유 코드 마스터. [Grain: REASON_CODE]. [주의: 분류 정본은 문서30 DEC-55 §55-C · 코드 추가는 이 파일 MERGE 로만]. [원천: 수기 · 08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql].';

MERGE INTO GN_DW.OPS.NULL_REASON_CODE t
USING (
    SELECT * FROM VALUES
      ('SRC_NO_LINK',     '원천에 연결 축 부재',   '원천 테이블에 이 컬럼을 채울 키·축이 없다(예: 캠페인 코드 부재 · Q10·B3·PAY-1).',            FALSE, 10),
      ('SRC_NOT_LOADED',  '원천 미입고',           '정의·원천 시스템은 확인됐으나 DW 로 아직 들어오지 않았다(외부 입고 대기 · 문서40).',          TRUE,  20),
      ('SRC_EMPTY',       '원천 값 전무',          '원천 컬럼은 있으나 값이 전부 비어 있다(원천 실측으로 확인).',                                  TRUE,  30),
      ('NO_DEFINITION',   '정의 없음',             '정본 지표 정의·원천 필드가 모두 없다(창작 금지 · R2-7).',                                     FALSE, 40),
      ('DESIGN_PENDING',  '설계 결정 대기',        '산출 규칙이 설계·현업 결정 대기다(결정 번호를 BASIS 에 적는다).',                            TRUE,  50),
      ('RETIRED_SLOT',    '폐기 슬롯',             '결정으로 의도적 영구 NULL 이다(정본은 다른 컬럼 · 예: DEC-57 FUNDRAISING_COST · O175 AD_COST).', FALSE, 60),
      ('CONCEPT_ABSENT',  '개념 부재',             '그 행 유형에는 개념 자체가 없다(R2-7-2 · 센티넬 (해당없음) 과 구분해 쓴다).',                   FALSE, 70),
      ('COLLECTION_GAP',  '수집 공백',             '원천이 특정 기간 수집하지 않았다(백필로 채워지지 않는다 · 예: GA4 UTM 2025-06-26 이전).',       FALSE, 80),
      ('UNCLASSIFIED',    '미분류(조사 필요)',     '전건 NULL 로 검출됐으나 사유를 아직 판정하지 않았다 — 등록부 초기값 · 남기면 안 된다.',          TRUE,  99)
    AS v(REASON_CODE, REASON_NAME, REASON_DESC, REWIRE_POSSIBLE, SORT_ORDER)
) s ON t.REASON_CODE = s.REASON_CODE
WHEN MATCHED THEN UPDATE SET REASON_NAME = s.REASON_NAME, REASON_DESC = s.REASON_DESC,
                             REWIRE_POSSIBLE = s.REWIRE_POSSIBLE, SORT_ORDER = s.SORT_ORDER
WHEN NOT MATCHED THEN INSERT (REASON_CODE, REASON_NAME, REASON_DESC, REWIRE_POSSIBLE, SORT_ORDER)
                      VALUES (s.REASON_CODE, s.REASON_NAME, s.REASON_DESC, s.REWIRE_POSSIBLE, s.SORT_ORDER);

-- ----------------------------------------------------------------------------
-- ② 컬럼 NULL 사유 등록부 — 범위 = SILVER·GOLD 의 **전건 NULL** 컬럼만(부분 NULL 제외 · 사용자 결정 2026-10-12)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS GN_DW.OPS.COLUMN_NULL_REGISTRY (
    TABLE_SCHEMA      VARCHAR        NOT NULL COMMENT '스키마(SILVER · GOLD).',
    TABLE_NAME        VARCHAR        NOT NULL COMMENT '테이블·뷰 이름.',
    COLUMN_NAME       VARCHAR        NOT NULL COMMENT '컬럼 이름.',
    REASON_CODE       VARCHAR        NOT NULL COMMENT 'NULL 사유 코드(OPS.NULL_REASON_CODE).',
    BASIS             VARCHAR                 COMMENT '근거 — 결정·회신·이슈 번호(예: DEC-57 · 현업 회신 42 · Q10 · DEC-55 §55-C).',
    REWIRE_CONDITION  VARCHAR                 COMMENT '재배선 조건 — 무엇이 바뀌면 채울 수 있는가(영구면 NULL).',
    ROWS_TOTAL        NUMBER(18,0)            COMMENT '측정 시점 테이블 행 수.',
    ROWS_NONNULL      NUMBER(18,0)            COMMENT '측정 시점 NULL 이 아닌 행 수(전건 NULL 이면 0).',
    MEASURED_ACCOUNT  VARCHAR                 COMMENT '측정 계정(CURRENT_ACCOUNT · 계정마다 데이터가 다르다).',
    MEASURED_AT       TIMESTAMP_NTZ           COMMENT '측정 시각.',
    NOTE              VARCHAR                 COMMENT '보충 설명(수치 없이).',
    UPDATED_BY        VARCHAR                 COMMENT '최종 변경 세션 라벨(예: O217-A).',
    UPDATED_AT        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ COMMENT '최종 변경 시각.',
    CONSTRAINT PK_COLUMN_NULL_REGISTRY PRIMARY KEY (TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME),
    CONSTRAINT FK_COLUMN_NULL_REGISTRY_REASON FOREIGN KEY (REASON_CODE) REFERENCES GN_DW.OPS.NULL_REASON_CODE (REASON_CODE)
) COMMENT = 'SILVER·GOLD 전건 NULL 컬럼 사유 등록부. [Grain: TABLE_SCHEMA × TABLE_NAME × COLUMN_NAME]. [주의: 컬럼 COMMENT 의 [NULL: <코드>] 와 같은 코드를 유지 · 부분 NULL 컬럼은 대상 아님 · 변경 이력은 원장·세션이력]. [원천: 수기 · 08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql].';

-- ----------------------------------------------------------------------------
-- ③ OPS 객체 목록 — 「OPS 에 무엇이 있는가」를 문서가 아니라 라이브에서 읽는다
--   관리 주체 판정: owner = GN_DW_DBT ⇒ dbt(store_failures · 매 build 재생성) · 그 밖 ⇒ 수기(정본 DDL 파일 필요)
--   WARN: 수기 객체는 COMMENT 의 [원천: 수기 · <DDL 파일 경로>] 로 정본 파일을 밝힌다 — 비어 있으면 「정본 미등록」.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW GN_DW.OPS.V_OPS_OBJECT_INVENTORY COPY GRANTS
COMMENT = 'OPS 스키마 객체 목록(테이블·뷰·프로시저·함수·스테이지). [Grain: OBJECT_TYPE × OBJECT_NAME]. [주의: MANAGED_BY = dbt 는 build 가 재생성하므로 손대지 않는다 · 수기 객체는 DDL_FILE 이 비면 정본 미등록]. [원천: 수기 · 08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql] (데이터 = GN_DW.INFORMATION_SCHEMA).'
AS
WITH o AS (
    SELECT IFF(TABLE_TYPE = 'VIEW', 'VIEW', 'TABLE') AS OBJECT_TYPE, TABLE_NAME AS OBJECT_NAME,
           TABLE_OWNER AS OWNER, CREATED, LAST_ALTERED, ROW_COUNT, COMMENT
    FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'OPS'
    UNION ALL
    SELECT 'PROCEDURE', PROCEDURE_NAME, PROCEDURE_OWNER, CREATED, LAST_ALTERED, NULL, COMMENT
    FROM GN_DW.INFORMATION_SCHEMA.PROCEDURES WHERE PROCEDURE_SCHEMA = 'OPS'
    UNION ALL
    SELECT 'FUNCTION', FUNCTION_NAME, FUNCTION_OWNER, CREATED, LAST_ALTERED, NULL, COMMENT
    FROM GN_DW.INFORMATION_SCHEMA.FUNCTIONS WHERE FUNCTION_SCHEMA = 'OPS'
    UNION ALL
    SELECT 'STAGE', STAGE_NAME, STAGE_OWNER, CREATED, LAST_ALTERED, NULL, COMMENT
    FROM GN_DW.INFORMATION_SCHEMA.STAGES WHERE STAGE_SCHEMA = 'OPS'
)
SELECT OBJECT_TYPE,
       OBJECT_NAME,
       OWNER,
       IFF(OWNER = 'GN_DW_DBT', 'dbt', '수기')                                        AS MANAGED_BY,
       REGEXP_SUBSTR(COMMENT, '수기 · ([^\\]]+)\\]', 1, 1, 'e', 1)                    AS DDL_FILE,
       CREATED,
       LAST_ALTERED,
       ROW_COUNT,
       COMMENT
FROM o;

-- ----------------------------------------------------------------------------
-- 검증
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS REASON_CODES FROM GN_DW.OPS.NULL_REASON_CODE;                    -- 9
SELECT COUNT(*) AS REGISTRY_ROWS FROM GN_DW.OPS.COLUMN_NULL_REGISTRY;               -- 초기 0 · 다음 세션이 채운다
SELECT MANAGED_BY, OBJECT_TYPE, COUNT(*) FROM GN_DW.OPS.V_OPS_OBJECT_INVENTORY GROUP BY 1, 2 ORDER BY 1, 2;
SELECT OBJECT_TYPE, OBJECT_NAME FROM GN_DW.OPS.V_OPS_OBJECT_INVENTORY
WHERE MANAGED_BY = '수기' AND DDL_FILE IS NULL;                                       -- 정본 미등록 수기 객체(0 이어야 한다)
