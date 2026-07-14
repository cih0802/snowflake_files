-- GN_DW SILVER dbt 파이프라인 배포·오케스트레이션 DDL — 현행 운영계약: 온디맨드 build (2026-07-14 갱신).
-- Co-authored with CoCo
-- ============================================================================
-- 배포·검증 이력 (2026-07-14, 본 세션 실측):
--   · CREATE DBT PROJECT → SHOW → compile → run(32객체) → GA4 매크로 회귀수정 → test PASS=9 → ADD VERSION(VERSION$2 default).
--   · 32객체 멱등검증 완료(BEFORE=AFTER, Δ0). 상세: 04_silver_design/10_SILVER_RUN_이력_비교_20260714.md.
--   · [순서 8-B 개정] SILVER = DDL 소유(04_silver_design/08_SILVER_테이블DDL) + dbt 는 데이터만 갱신:
--     incremental + pre-hook TRUNCATE + append + full_refresh:false (구조·제약·주석 보존, 멱등 Δ0).
--     (구 materialized='table'/INSERT OVERWRITE 를 구조보존형으로 대체.) GOLD 는 순서 8 활성화(enabled:true).
-- ★ 운영 방침 결정(2026-07-14): BRONZE 원천이 "정기 갱신·주기 불규칙" → 고정 CRON TASK 안티패턴.
--   → 현행 = 온디맨드 build 계약(§C). CRON TASK 는 보류(§D, 참고용). 최종형은 트리거 기반(§E).
-- 워크스페이스 스테이지: snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- (A) DBT PROJECT 객체 — [배포 완료] VERSION$2 가 default. 재배포 불필요.
-- ─────────────────────────────────────────────────────────────────────────
-- CREATE DBT PROJECT IF NOT EXISTS GN_DW.SILVER.GN_DW_SILVER_PIPELINE
--   FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
--   COMMENT = 'BRONZE→SILVER 정제 파이프라인(32객체). 정본 09_SILVER_적재쿼리_20260714. 순서 7.';

-- 워크스페이스 파일 수정 후 배포객체에 반영(신규 버전 = default):
-- ALTER DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE
--   ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
--   COMMENT = '<변경 요약>';

-- 확인:
-- SHOW DBT PROJECTS IN SCHEMA GN_DW.SILVER;
-- SHOW VERSIONS IN DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE;

-- ─────────────────────────────────────────────────────────────────────────
-- (B) 검증 — 테이블 불변(안전). SILVER 데이터 재작성 없음.
-- ─────────────────────────────────────────────────────────────────────────
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='parse';
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='compile';

-- ═════════════════════════════════════════════════════════════════════════
-- (C) ★현행 운영계약: 온디맨드 build (= run + test 통합) — [권장 실행경로]
--     · build 는 모델 생성 직후 해당 모델의 test 를 함께 수행 → 조용한 회귀(GA4 0행 등)를
--       test 실패로 즉시 게이트. (run 단독은 0행도 SUCCESS 로 통과하므로 위험.)
--     · BRONZE 적재 주체(커넥터/배치)가 적재 완료 후 아래 한 줄을 호출하도록 배선하면 됨.
--     · dbt ref DAG 가 의존순서 자동보장: CRM_CODE→CRM_*, MEMBER_SPONSOR_BIZ→SPONSOR_RELATION,
--       (GA4_IDENTITY+CRM_MEMBER)→IDENTITY_MEMBER_XREF. 도메인(CRM/ERP/AGENCY/GA4) 상호 독립(threads=4 병렬).
-- ═════════════════════════════════════════════════════════════════════════
-- 전체 재정제(권장):
EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build';

-- 부분 재정제(원천 일부만 갱신 시):
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build --select silver.ga4+';   -- GA4 샤드 입고 시(하류 XREF 포함)
-- EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build --select silver.crm';     -- CRM 도메인만

-- ─────────────────────────────────────────────────────────────────────────
-- (D) [보류] 고정 CRON TASK — 주기 불규칙이라 현재 부적합. 정기·정시 확정 시에만 사용.
--     ⚠️ run 이 아닌 build 로 게이트. 저작만: CREATE/RESUME 보류.
-- ─────────────────────────────────────────────────────────────────────────
-- CREATE TASK IF NOT EXISTS GN_DW.SILVER.TASK_SILVER_DAILY
--   WAREHOUSE = COMPUTE_WH
--   SCHEDULE  = 'USING CRON 0 5 * * * Asia/Seoul'   -- 매일 05:00 KST
--   SUSPEND_TASK_AFTER_NUM_FAILURES = 1              -- 회귀 시 즉시 정지
--   COMMENT   = 'BRONZE→SILVER 32객체 재정제(dbt build). 주기 확정 시에만 RESUME.'
-- AS
--   EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build';
-- ALTER TASK GN_DW.SILVER.TASK_SILVER_DAILY RESUME;   -- 가동(주기 확정 후)

-- ─────────────────────────────────────────────────────────────────────────
-- (E) [최종 목표형] 트리거 기반 TASK — 불규칙 도착에 정합. BRONZE 적재 메커니즘 확정 후 구현.
--     · BRONZE 핵심 테이블에 STREAM 생성 → WHEN 절로 신규 데이터 있을 때만 실행(빈 실행/낭비 제거).
--     · 아래는 설계 스케치(테이블·스트림명은 실제 적재 대상으로 교체).
-- ─────────────────────────────────────────────────────────────────────────
-- CREATE STREAM IF NOT EXISTS GN_DW.SILVER.STRM_BRONZE_TRIGGER ON TABLE GN_DW.BRONZE_CRM.<핵심원천>;
-- CREATE TASK IF NOT EXISTS GN_DW.SILVER.TASK_SILVER_TRIGGERED
--   WAREHOUSE = COMPUTE_WH
--   SCHEDULE  = '60 MINUTE'                                   -- 폴링 주기(또는 SCHEDULE 없이 상위 태스크 체인)
--   SUSPEND_TASK_AFTER_NUM_FAILURES = 1
--   WHEN SYSTEM$STREAM_HAS_DATA('GN_DW.SILVER.STRM_BRONZE_TRIGGER')
-- AS
--   EXECUTE DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE ARGS='build';

-- ─────────────────────────────────────────────────────────────────────────
-- (F) 모니터링
-- ─────────────────────────────────────────────────────────────────────────
-- SELECT * FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME=>'TASK_SILVER_DAILY')) ORDER BY SCHEDULED_TIME DESC;
-- 행수 스냅샷 비교(04_silver_design/10_SILVER_RUN_이력_비교_20260714.md 의 비교쿼리 참조).
