-- =============================================================================
-- Purpose    : O259 조직도 Silver 정제 — SILVER 테이블 2종 선생성 + picker 뷰 (기존 환경 갱신)
-- Target     : TABLE GN_DW.SILVER.CRM_ORG_CLEAN, TABLE GN_DW.SILVER.CRM_ORG_SUCCESSION, VIEW GN_DW.SILVER.V_ORG_PICKER
-- Run order  : 기존 환경 갱신 #34 ([D1] → 👤 dbt build → [D2] → [D3])
-- Depends on : SCHEMA GN_DW.SILVER · (D2) dbt 모델 CRM_ORG_CLEAN 적재 완료
-- Issue      : O259, O188-E, O252, DEC-63
-- =============================================================================
-- 왜 이 파일이 필요한가
--   GN_DW_DBT 는 SILVER 에 CREATE TABLE 권한이 없다(07_ENVIRONMENT_RBAC_setup.sql §D.9 · 구조 = DDL · 데이터 = dbt).
--   이 단계를 건너뛰면 dbt 가 003001 로 실패한다(38_DEPLOY_MAP_SEEDS.sql 과 같은 사유).
--   정본 = /04_silver_design/08_SILVER_테이블DDL_20260714.sql 끝의 같은 블록(아래는 그 사본 · IF NOT EXISTS · 멱등).
--   WARN: 08 SILVER DDL 파일 전체를 재실행하지 마라(CREATE OR REPLACE ⇒ SILVER 전량 비워짐 · R2-9).
--   권한: SILVER FUTURE GRANTS 가 TABLE(DBT DML · ANALYST/ENGINEER SELECT)·VIEW(ANALYST/ENGINEER SELECT)를 덮는다 ⇒ 추가 GRANT 불요.
--   WARN: V_ORG_PICKER 는 dbt 모델이 아니다 — SILVER pre-hook(silver_purge = TRUNCATE)이 뷰에서 실패하므로 DDL 소유로 둔다.
-- =============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D1] 테이블 2종 (dbt build 전)
CREATE TABLE IF NOT EXISTS GN_DW.SILVER.CRM_ORG_CLEAN (
    DEPT_ID                 VARCHAR(20)     NOT NULL COMMENT '부서ID (PK, →CRM_ORG)',
    DEPT_NM                 VARCHAR(50)     COMMENT '부서명',
    UPPER_DEPT_ID           VARCHAR(20)     COMMENT '상위부서ID (조직트리 · 원천 그대로)',
    ACMSLT_UPPER_DEPT_ID    VARCHAR(20)     COMMENT '실적상위부서ID (실적트리 · 원천 그대로)',
    ACMSLT_DEPT_YN          VARCHAR(1)      COMMENT '실적부서 여부 (원천 그대로)',
    USE_YN                  VARCHAR(1)      COMMENT '사용여부 (원천 그대로 · 폐기 판정에 단독 사용 금지 — ORG_STATUS 를 쓴다)',
    LAST_UPDT_DT            TIMESTAMP_NTZ(9) COMMENT '최종수정일시 (원천 그대로 · NULL·9999-12-31 = 비활성 버전)',
    ORG_STATUS              VARCHAR(10)     NOT NULL COMMENT '활성 트리 기준 상태 ACTIVE·RETIRED (O259 D1 · 자기와 모든 상위가 USE_YN=Y 이고 LAST_UPDT_DT 유효)',
    RETIRE_REASON           VARCHAR(20)     COMMENT '폐기 사유 SELF_USE_YN·SELF_LAST_UPDT·NOT_IN_TREE·UPPER_RETIRED — ACTIVE 이면 개념이 없어 NULL',
    IS_ACTIVE_ORG           BOOLEAN         NOT NULL COMMENT '활성 조직 트리 소속 여부 (= ORG_STATUS ACTIVE · GOLD.DIM_ORG 와 같은 값)',
    ORG_PATH                VARCHAR         COMMENT '조직트리 경로(루트 제외 · 폐기 노드 포함) — 루트 자신과 루트에서 닿지 않는 노드는 경로가 없어 NULL',
    ORG_LEVEL               NUMBER(3,0)     COMMENT '조직트리 레벨(루트=0) — 루트에서 닿지 않는 노드는 NULL',
    ACTIVE_PATH             VARCHAR         COMMENT '활성 트리 경로 — RETIRED 노드는 활성 경로가 없어 NULL',
    ACTIVE_LEVEL            NUMBER(3,0)     COMMENT '활성 트리 레벨 — RETIRED 노드는 NULL',
    ACTIVE_UPPER_DEPT_ID    VARCHAR(20)     COMMENT '활성 트리 상위부서ID — RETIRED 노드와 루트는 활성 상위가 없어 NULL',
    ACMSLT_DIV_GROUP_ID     VARCHAR(20)     COMMENT '실적트리 ZB 상위(본부/지부 구분 · O191) — ZB 에 닿지 않으면 NULL',
    ACMSLT_DIV_GROUP_NM     VARCHAR(50)     COMMENT 'ZB 상위 부서명 — ZB 에 닿지 않으면 NULL',
    ACMSLT_DIV_ID           VARCHAR(20)     COMMENT '실적트리 ZC 상위(본부/지부 단위 · O191) — ZC 에 닿지 않으면 NULL',
    ACMSLT_DIV_NM           VARCHAR(50)     COMMENT 'ZC 상위 부서명 — ZC 에 닿지 않으면 NULL',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 (공통감사)',
    PRIMARY KEY (DEPT_ID)
) COMMENT = '조직 마스터 활성 트리 정제(O259). [Grain: DEPT_ID (1행=1부서 · CRM_ORG 전 행 · 삭제 금지 O16)]. [주의: 폐기 판정은 ORG_STATUS 하나 · USE_YN 단독 사용 금지 · 화면 선택은 V_ORG_PICKER]. [원천: CRM → BRONZE_CRM.TM_CM_DEPT_INFO → SILVER.CRM_ORG].';

CREATE TABLE IF NOT EXISTS GN_DW.SILVER.CRM_ORG_SUCCESSION (
    OLD_DEPT_ID             VARCHAR(20)     NOT NULL COMMENT '원래 부서ID (PK · 팩트 실적부서값 그대로)',
    OLD_DEPARTMENT          VARCHAR(50)     COMMENT '원래 부서명',
    OLD_IS_ACTIVE_ORG       BOOLEAN         COMMENT '원래 부서 활성 여부',
    OLD_UPPER_DEPT_ID       VARCHAR(20)     COMMENT '원래 조직트리 상위부서ID (원천 그대로) — 루트는 상위가 없어 NULL',
    OLD_UPPER_CUR_DEPT_ID   VARCHAR(20)     COMMENT '원래 상위부서를 같은 규칙으로 귀속한 현재 부서ID — 상위가 없거나 귀속 실패면 NULL',
    CUR_DEPT_ID             VARCHAR(20)     COMMENT '귀속된 현재 활성 부서ID — 귀속 규칙 전부 실패(UNMAPPED·MANUAL_UNMAPPED)면 NULL',
    CUR_DEPARTMENT          VARCHAR(50)     COMMENT '귀속된 현재 부서명 — CUR_DEPT_ID 가 NULL 이면 NULL',
    CUR_ORG_PATH            VARCHAR         COMMENT '귀속된 현재 부서의 활성 경로 — CUR_DEPT_ID 가 NULL 이면 NULL',
    CUR_ORG_LEVEL           NUMBER(3,0)     COMMENT '귀속된 현재 부서 레벨 — CUR_DEPT_ID 가 NULL 이면 NULL',
    CUR_UPPER_DEPT_ID       VARCHAR(20)     COMMENT '귀속된 현재 부서의 활성 상위부서ID(상위부서→팀 쌍) — 귀속 실패 또는 루트면 NULL',
    MAP_METHOD              VARCHAR(20)     COMMENT '귀속 방식 SELF·MANUAL·MANUAL_UNMAPPED·AUTO_NAME·AUTO_MEMBER_FLOW·AUTO_ACMSLT_PARENT·AUTO_ORG_PARENT·UNMAPPED',
    IS_REMAPPED             BOOLEAN         COMMENT '다른 부서로 귀속되었는가',
    IS_CONFIRMED            BOOLEAN         COMMENT '현업 확정(SELF·MANUAL) 여부',
    FLOW_CAND_DEPT_ID       VARCHAR(20)     COMMENT '회원 흐름 후보 부서ID — 후보(근거 10건 이상)가 없으면 NULL',
    FLOW_EVIDENCE_CNT       NUMBER(18,0)    COMMENT '회원 흐름 근거 건수 — 후보가 없으면 NULL',
    FLOW_SHARE              NUMBER(10,4)    COMMENT '회원 흐름 점유율 — 후보가 없으면 NULL',
    FLOW_LIFT               NUMBER(12,2)    COMMENT '회원 흐름 lift — 후보가 없으면 NULL',
    CONFIRMED_BY            VARCHAR         COMMENT '현업 확정자(seed) — seed 행이 없으면 NULL',
    CONFIRMED_DT            VARCHAR         COMMENT '현업 확정일(seed) — seed 행이 없으면 NULL',
    NOTE                    VARCHAR         COMMENT '비고(seed) — seed 행이 없으면 NULL',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 (공통감사)',
    PRIMARY KEY (OLD_DEPT_ID)
) COMMENT = '폐지·개편 부서 → 현재 활성 부서 귀속(O259 · DEC-63 규칙 Silver 이관). [Grain: OLD_DEPT_ID (1행=1부서)]. [주의: 원천 실적부서값은 바꾸지 않는다(DEC-56) · 미귀속은 CUR_* NULL]. [원천: SILVER.CRM_ORG_CLEAN · CRM_MEMBER_DEV · CRM_MEMBER_SPONSOR_SPAN · GOLD.ORG_SUCCESSION_MANUAL(seed)].';

-- [D2] picker 뷰 (dbt build 후 · CRM_ORG_CLEAN 이 채워진 뒤)
CREATE OR REPLACE VIEW GN_DW.SILVER.V_ORG_PICKER
COMMENT = '조직 선택용(상위부서 → 팀) — ACTIVE 노드만(O259). [Grain: DEPT_ID]. [주의: 폐기 부서는 나오지 않는다 · 과거 실적을 현재 부서로 보려면 CRM_ORG_SUCCESSION]. [원천: SILVER.CRM_ORG_CLEAN].'
AS
SELECT
    c.DEPT_ID,
    c.DEPT_NM,
    c.ACTIVE_UPPER_DEPT_ID      AS UPPER_DEPT_ID,
    u.DEPT_NM                   AS UPPER_DEPT_NM,
    c.ACTIVE_LEVEL              AS ORG_LEVEL,
    c.ACTIVE_PATH               AS ORG_PATH
FROM GN_DW.SILVER.CRM_ORG_CLEAN c
LEFT JOIN GN_DW.SILVER.CRM_ORG_CLEAN u
       ON u.DEPT_ID = c.ACTIVE_UPPER_DEPT_ID
WHERE c.ORG_STATUS = 'ACTIVE';

-- [D3] 검증 (기대: picker 폐기 0 · CLEAN 1,314 · SUCC 1,314 · 개발계 SR61467 2026-10-23 렌더 기준 ACTIVE 223)
SELECT 'CLEAN' K, COUNT(*) N FROM GN_DW.SILVER.CRM_ORG_CLEAN
UNION ALL SELECT 'CLEAN_ACTIVE', COUNT_IF(ORG_STATUS = 'ACTIVE') FROM GN_DW.SILVER.CRM_ORG_CLEAN
UNION ALL SELECT 'SUCC', COUNT(*) FROM GN_DW.SILVER.CRM_ORG_SUCCESSION
UNION ALL SELECT 'PICKER', COUNT(*) FROM GN_DW.SILVER.V_ORG_PICKER
UNION ALL SELECT 'PICKER_RETIRED', COUNT(*)
          FROM GN_DW.SILVER.V_ORG_PICKER p
          JOIN GN_DW.SILVER.CRM_ORG_CLEAN c ON c.DEPT_ID = p.DEPT_ID
          WHERE c.ORG_STATUS <> 'ACTIVE';
