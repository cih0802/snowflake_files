-- =============================================================================
-- Purpose    : 폐지·개편 실적부서 → 현재 활성 부서-팀 귀속(DEC-63) 배포 순서
-- Target     : TABLE GN_DW.GOLD.DIM_ORG_SUCCESSION, TABLE GN_DW.GOLD.ORG_SUCCESSION_MANUAL
-- Run order  : 기존 환경 갱신 #29
-- Depends on : GN_DW.SILVER.CRM_ORG, GN_DW.GOLD.DIM_ORG, GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN
-- Issue      : DEC-63, DEC-56, DEC-63-D, DEC-63-E
-- =============================================================================
-- ============================================================================
-- 37_DEPLOY_ORG_SUCCESSION.sql — 폐지·개편 실적부서 → 현재 활성 부서-팀 귀속(DEC-63) 배포 순서
--   작성 = TRIALADMIN · 2026-10-21 · 요청 = 현업(주간중단보고 대시보드) 부서-팀 드릴다운에서
--          폐지 부서 중단건을 묶지 말고 현재 부서-팀 KPI 에 합산 · 결정 = DEC-63(DEC-56 보완 · A안)
--   WARN: D2 는 MANUAL: 사용자가 실행한다(dbt 정지점 · R4-1). 운영계는 백필 없이 이 순서 그대로(R2-9).
--   대상 환경 = 이미 구축된 환경(「기존 환경 갱신」). 새로 구축하는 환경은 문서실행순서.md 본 순서에
--               이미 들어 있다(06_DDL · dbt build 전체 · 05_10) ⇒ 이 파일을 따로 돌리지 않는다.
-- ----------------------------------------------------------------------------
-- 변경 요지
--   ① GOLD 신규 테이블 2 = DIM_ORG_SUCCESSION(dbt incremental · unique_key OLD_ORG_SK) ·
--      ORG_SUCCESSION_MANUAL(dbt seed 대상 · 현업 확정분)
--      정본 = 03_top-down_gold/06_DDL.sql 의 같은 2블록(아래 D1 은 그 사본 · IF NOT EXISTS)
--   ② SILVER = 변경 없음(기존 CRM_ORG · CRM_MEMBER_DEV · CRM_MEMBER_SPONSOR_SPAN 만 읽는다)
--   ③ dbt = models/gold/dim/DIM_ORG_SUCCESSION.sql · seeds/ORG_SUCCESSION_MANUAL.csv · seeds/_seeds.yml ·
--      models/gold/_gold_ready_schema.yml(테스트) · tests/assert_org_succession_invariants.sql
--      귀속 규칙 = SELF → MANUAL → AUTO_NAME → AUTO_MEMBER_FLOW(lift≥3·근거≥30) → AUTO_ACMSLT_PARENT →
--                  AUTO_ORG_PARENT(L≥1) → UNMAPPED(소비 측 표기 '(미매핑 폐지부서)')
--   ④ SV = 05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql 에 org_succ 테이블 · 차원 6(CUR_DEPARTMENT · CUR_ORG_PATH 외) ·
--   지표 STOP_REGISTRATIONS · 규칙 (5)·(6) · VQR 2 추가(약정 실적부서 SPNSR_ACMSLT_DEPT_CD 로 조인)
--      (6) = DEC-63-D 부서별 중단률은 분자·분모(전월말 활동 약정)를 같은 귀속 축으로 묶는다(NOTE: 현업 확인 대기)
--   ⑤ Agent = 변경 없음(SV 차원은 Cortex Analyst 도구가 그대로 읽는다)
--   ⑥ DEC-63-E(파급 · NOTE: 현업 선택 대기) = 05_08 SV_DEV_ACHIEVEMENT(목표·실적 함께 귀속) ·
--      05_02 SV_MEMBER_EVENT(개발 DEV 행 귀속) 에도 현재 부서 축 — [D4] 다음에 두 파일 전체 실행
--   WARN: 원천 부서값은 바꾸지 않는다(DEC-56) — 현재 조직 기준 조회 전용 별도 축이다.
--   WARN: DIM_ORG.ORG_SK 조인키 = ABS(HASH(COALESCE(CAST(DEPT_ID AS VARCHAR),'∅')))(매크로 gold_sk) —
--      HASH(DEPT_ID) 로 조인하면 연 3만 건이 빠진다.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D0] 사전 확인 — 원천·의존 객체 실재(기대 = 3행 전부 1 이상)
SELECT 'SILVER.CRM_ORG' AS obj, COUNT(*) AS n FROM GN_DW.SILVER.CRM_ORG
UNION ALL SELECT 'GOLD.DIM_ORG', COUNT(*) FROM GN_DW.GOLD.DIM_ORG
UNION ALL SELECT 'GOLD.FACT_MEMBER_SPONSORSHIP_SPAN', COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN;

-- [D1] GOLD 테이블 2종(WARN: 06_DDL 전체 재실행 금지 = GOLD 전량 비워짐 · 이 2문장만)
--   GN_DW_DBT 는 GOLD 에 CREATE TABLE 권한이 없다(CREATE VIEW 만) ⇒ seed 테이블도 DDL 이 먼저 만든다.
--   DBT 의 DML 권한은 07_ENVIRONMENT_RBAC_setup.sql 의 FUTURE TABLES GRANT 가 자동 부여한다.
CREATE TABLE IF NOT EXISTS GN_DW.GOLD.DIM_ORG_SUCCESSION (
    OLD_ORG_SK          NUMBER(38,0)    NOT NULL PRIMARY KEY COMMENT '원천 부서 대리키 (= DIM_ORG.ORG_SK · 팩트 부서 컬럼과 조인)',
    OLD_DEPT_ID         VARCHAR         NOT NULL COMMENT '원천 실적부서코드 (SILVER.CRM_ORG.DEPT_ID · DEC-56 원천 그대로)',
    OLD_DEPARTMENT      VARCHAR         COMMENT '원천 부서명 (당시 부서 · DEC-56)',
    OLD_IS_ACTIVE_ORG   BOOLEAN         COMMENT '원천 부서가 현재 활성 조직 트리 소속인가 (= DIM_ORG.IS_ACTIVE_ORG)',
    CUR_ORG_SK          NUMBER(38,0)    COMMENT '귀속 현재 부서 대리키 (FK→DIM_ORG · 활성 부서만). NULL = 귀속 대상 없음(MAP_METHOD UNMAPPED·MANUAL_UNMAPPED)',
    CUR_DEPT_ID         VARCHAR         COMMENT '귀속 현재 부서코드. NULL 사유 = CUR_ORG_SK 와 같다',
    CUR_DEPARTMENT      VARCHAR         COMMENT '귀속 현재 부서명 — 드릴다운 축. NULL 사유 = CUR_ORG_SK 와 같다 · 소비 측 표기 = (미매핑 폐지부서)',
    CUR_ORG_PATH        VARCHAR         COMMENT '귀속 현재 부서 조직표 경로(루트 제외). NULL 사유 = CUR_ORG_SK 와 같다',
    CUR_ORG_LEVEL       NUMBER(38,0)    COMMENT '귀속 현재 부서 조직 트리 깊이(루트=0). NULL 사유 = CUR_ORG_SK 와 같다',
    MAP_METHOD          VARCHAR         NOT NULL COMMENT '귀속 근거. SELF·MANUAL·MANUAL_UNMAPPED·AUTO_NAME·AUTO_MEMBER_FLOW·AUTO_ACMSLT_PARENT·AUTO_ORG_PARENT·UNMAPPED',
    IS_REMAPPED         BOOLEAN         NOT NULL COMMENT '원천 부서와 다른 현재 부서로 귀속됐는가',
    IS_CONFIRMED        BOOLEAN         NOT NULL COMMENT '확정 여부 — SELF 또는 현업 확정(MANUAL·MANUAL_UNMAPPED). FALSE = 자동 추정',
    FLOW_CAND_DEPT_ID   VARCHAR         COMMENT '회원 흐름 lift 1위 후보 부서코드(참고). NULL = 후보 없음(근거 10건 미만 또는 활성 부서)',
    FLOW_EVIDENCE_CNT   NUMBER(38,0)    COMMENT '회원 흐름 후보의 근거 개발 건수(2022년~). NULL 사유 = FLOW_CAND_DEPT_ID 와 같다',
    FLOW_SHARE          NUMBER(10,4)    COMMENT '회원 흐름 후보 점유율. NULL 사유 = FLOW_CAND_DEPT_ID 와 같다',
    FLOW_LIFT           NUMBER(12,2)    COMMENT '회원 흐름 후보 lift = 점유율 ÷ 전체 개발 기준선. NULL 사유 = FLOW_CAND_DEPT_ID 와 같다',
    CONFIRMED_BY        VARCHAR         COMMENT '현업 확정자(seed ORG_SUCCESSION_MANUAL). NULL = 현업 확정 아님',
    CONFIRMED_DT        VARCHAR         COMMENT '현업 확정일 YYYYMMDD(seed). NULL 사유 = CONFIRMED_BY 와 같다',
    NOTE                VARCHAR         COMMENT '현업 확정 비고(seed). NULL 사유 = CONFIRMED_BY 와 같다',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '폐지·개편 부서 현재 조직 귀속 차원. [Grain: OLD_ORG_SK (1행=1부서 · DIM_ORG 와 1:1)]. [주의: DEC-56 원천 부서값 보존 · 현재 조직 기준 조회 전용 축 · IS_CONFIRMED=FALSE 는 자동 추정]. [원천: SILVER.CRM_ORG · GOLD.DIM_ORG · SILVER.CRM_MEMBER_SPONSOR_SPAN · SILVER.CRM_MEMBER_DEV · seed ORG_SUCCESSION_MANUAL].';

CREATE TABLE IF NOT EXISTS GN_DW.GOLD.ORG_SUCCESSION_MANUAL (
    OLD_DEPT_ID         VARCHAR         COMMENT '폐지·개편 원천 부서코드(SILVER.CRM_ORG.DEPT_ID)',
    CUR_DEPT_ID         VARCHAR         COMMENT '귀속할 현재 활성 부서코드. NULL = 귀속하지 않기로 현업 확정(MANUAL_UNMAPPED)',
    CONFIRMED_BY        VARCHAR         COMMENT '현업 확정자',
    CONFIRMED_DT        VARCHAR         COMMENT '현업 확정일 YYYYMMDD',
    NOTE                VARCHAR         COMMENT '확정 비고(분할 부서 판단 근거 등)'
) COMMENT = '폐지·개편 부서 귀속 현업 확정분. [Grain: OLD_DEPT_ID]. [주의: dbt seed 적재 · 손으로 INSERT 하지 말고 CSV 를 고친다 · 조직 개편 시 갱신]. [원천: 현업 수기 · seeds/ORG_SUCCESSION_MANUAL.csv].';

-- [D1 확인] 소유자 = GN_DW_ADMIN · DBT 권한(기대 = DELETE·INSERT·SELECT·TRUNCATE·UPDATE)
SHOW GRANTS ON TABLE GN_DW.GOLD.DIM_ORG_SUCCESSION;
SHOW GRANTS ON TABLE GN_DW.GOLD.ORG_SUCCESSION_MANUAL;

-- ============================================================================
-- WARN: [D2] MANUAL: dbt 재배포 + build — 사용자가 실행한다(아래는 주석 · 정지점)
--   ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
--     ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
--   USE ROLE GN_DW_DBT;
--   USE WAREHOUSE GN_DW_ETL_WH;
--   EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select ORG_SUCCESSION_MANUAL DIM_ORG_SUCCESSION';
--   기대(개발 환경 SR61467 2026-10-21) = PASS=11 WARN=0 ERROR=0 · seed 0행(헤더만)
--   결과 확인 = 문서실행순서_llm실행.md §6.2
-- ============================================================================

-- [D3] 대사(기대 = 개발 환경 SR61467 2026-10-21 실측 · 운영계는 수치가 다를 수 있고 등식은 같아야 한다)
-- 3-1 행수 = DIM_ORG(SK≠0) 와 1:1 · 키 중복 0(기대 1,314 · 1,314 · 0)
SELECT (SELECT COUNT(*) FROM GN_DW.GOLD.DIM_ORG_SUCCESSION)                                   AS succ_rows,
       (SELECT COUNT(*) FROM GN_DW.GOLD.DIM_ORG WHERE ORG_SK <> 0)                            AS org_rows,
       (SELECT COUNT(*) - COUNT(DISTINCT OLD_DEPT_ID) FROM GN_DW.GOLD.DIM_ORG_SUCCESSION)     AS dup_dept;
-- 3-2 귀속 방법별 부서 수(기대 SELF 223 · AUTO_NAME 109 · AUTO_MEMBER_FLOW 72 · AUTO_ACMSLT_PARENT 135 ·
--     AUTO_ORG_PARENT 222 · UNMAPPED 553 · seed 반영 전이라 MANUAL 0)
SELECT MAP_METHOD, COUNT(*) AS depts FROM GN_DW.GOLD.DIM_ORG_SUCCESSION GROUP BY 1 ORDER BY 2 DESC;
-- 3-3 중단 연도별 합계 보존(기대 2024 143,153/0/1,000 · 2025 153,263/2/894 · 2026 129,707/0/621
--     · no_join 2 = 원천 실적부서 NULL)
SELECT LEFT(s.DSCNTC_MONTH_KEY::VARCHAR, 4)                                AS yr,
       COUNT(*)                                                            AS stop_rows,
       COUNT_IF(o.OLD_DEPT_ID IS NULL)                                     AS no_join,
       COUNT_IF(o.OLD_DEPT_ID IS NOT NULL AND o.CUR_DEPT_ID IS NULL)       AS unmapped
FROM GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN s
LEFT JOIN GN_DW.GOLD.DIM_ORG_SUCCESSION o ON o.OLD_DEPT_ID = s.SPNSR_ACMSLT_DEPT_CD
WHERE s.DSCNTC_MONTH_KEY >= 202401
GROUP BY 1 ORDER BY 1;

-- ============================================================================
-- WARN: 이 파일은 여기(D3)까지만 실행문이다. D4 는 **다른 파일을 열어 전체 실행**한다.
--    WARN: D2 전에 D4 를 돌리면 SV 생성은 되지만 귀속 축이 비어 '(미매핑 폐지부서)' 1행만 나온다.
-- ============================================================================

-- [D4] SV = 05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql 전체 실행(끝 스모크 포함)
--   기대(개발 환경) = 14/14 문장 OK · 현재 부서 축 합계 = 팩트 중단 약정 수(1,381,827 = 1,381,827)
--    확인 질의 — 2026 현재 부서별 중단 약정(기대 전체 129,707 · 매체운영팀 48,172 · 마케팅기획2팀 18,696):
-- SELECT CUR_DEPARTMENT, SUM(STOP_REGISTRATIONS) FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
--          DIMENSIONS CUR_DEPARTMENT, DSCNTC_MONTH_KEY METRICS STOP_REGISTRATIONS)
-- WHERE DSCNTC_MONTH_KEY BETWEEN 202601 AND 202612 GROUP BY ROLLUP (CUR_DEPARTMENT) ORDER BY 2 DESC;

-- [D5] 현업 회신 반영(반복 절차 · 회신이 올 때마다)
--   ① 검토 xlsx(30_output_share/O252_폐지부서_연결결과_검토요청_20261021.xlsx) 회신을
--      10_dbt_pipeline/seeds/ORG_SUCCESSION_MANUAL.csv 에 옮긴다
--      헤더 = OLD_DEPT_ID,CUR_DEPT_ID,CONFIRMED_BY,CONFIRMED_DT,NOTE · 「연결 안 함」 = CUR_DEPT_ID 빈칸
--   ② MANUAL: D2 와 같은 명령으로 재배포 + build(seed 가 TRUNCATE + INSERT · 모델이 MERGE)
--   ③ 확인 = 3-2 에서 MANUAL·MANUAL_UNMAPPED 부서 수 = seed 행수 · 테스트 assert_org_succession_invariants PASS
--   WARN: GOLD.ORG_SUCCESSION_MANUAL 에 손으로 INSERT 하지 않는다(다음 seed 가 지운다)

-- [D6] 롤백
--   SV = 05_10 의 DEC-63 표지 줄(org_succ 테이블·관계·차원 6·지표 1·규칙 (5)·VQR 1)을 빼고 재실행(CREATE OR ALTER)
--   dbt = 직전 버전으로 ALTER DBT PROJECT … SET DEFAULT_VERSION(신설 테이블은 남아도 무해 — 다른 모델이 참조하지 않는다)
--   GOLD = DROP 하지 않는다(현업 확정 seed 가 들어 있을 수 있다 · 지우려면 사용자 승인)
