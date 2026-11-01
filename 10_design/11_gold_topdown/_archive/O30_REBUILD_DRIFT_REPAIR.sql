-- ============================================================================
-- 🔴 [APPLIED 2026-08-05 · 아카이브 이관 · 재실행 금지 · ERROR 발생] — O41 판정
--   본 스크립트가 고치려던 드리프트는 **소멸했다.** 두 정본이 모두 동기화됐고
--   2026-08-05 재구축(정본 DDL 만 실행)에서 물리에 그대로 재현됨을 실측했다:
--     · §1 SILVER 개명 2건 → `04_silver_design/08_SILVER_테이블DDL_20260714.sql` 240·374 에 접힘.
--       물리 확인 = `CRM_PAYMENT_BILLING.MBRFEE_PRCS_STAT_CD` · `CRM_SEND_REQUEST.PSTMTR_PRCS_STAT_CD`
--     · §2 DIM_MEMBER 4추가/3삭제 → `06_DDL.sql` 100~120 에 접힘. 물리 30컬럼 일치
--
-- 🔴 **헤더의 "본 스크립트는 멱등이다" 는 틀렸다** — §1 의 `RENAME COLUMN` 에는 가드가 없다.
--   구 이름 `PRCS_STAT_CD` 가 이미 없으므로 재실행하면 **첫 문장에서 ERROR** 로 죽는다.
--   (§2 는 `IF NOT EXISTS`/`IF EXISTS` 라 실제로 멱등이다 — 멱등성은 절마다 다르다.)
--
-- ⚠️ §4 「이 다음에 할 일」은 **2026-08-05 현재 상황과 다시 일치한다**(SERVING 객체 0 · GOLD 뷰 1개).
--   그러나 이번 원인은 정본 미동기화가 아니라 **재구축 자체가 미완**(BRONZE 미적재)이다 → O41 로 별건 등재.
--   실행 순서 정본 = `PAID_재현_런북_20260722.md §11.2-C`.
-- ============================================================================

-- ============================================================================
-- O30_REBUILD_DRIFT_REPAIR.sql
--   전체 환경 재구축(TEARDOWN+setup)이 되돌린 "ALTER-only 구조 변경" 복구
--   작성 2026-08-04 · Co-authored with CoCo
-- ============================================================================
-- ▶ 무슨 일이 있었나 (실측)
--   2026-08-03 20:55~21:38 (-0700) 전체 환경이 재구축됐다.
--     20:55:01  GN_DW DB·스키마 재생성
--     20:59~21:00  BRONZE 51테이블 CREATE OR REPLACE + 데이터 재적재(112.5M행)
--     21:36~21:37  SILVER 38테이블 CREATE OR REPLACE  ← 08_SILVER_테이블DDL 실행
--     21:37~21:38  GOLD   28테이블 CREATE OR REPLACE  ← 06_DDL.sql 실행
--     21:40~21:41  dbt build → ERROR 3 · SKIP 68
--   → 재구축은 **정본 DDL 파일**을 실행한다. 따라서 정본 DDL 에 접히지 않고
--     물리 `ALTER` 로만 존재했던 구조 변경은 **전부 소실**된다.
--
-- ▶ 소실된 것 = 정본 DDL 미동기화 2건 (나머지는 동기화돼 있어 무사)
--   ① O26 SILVER 개명 2컬럼  — 08_SILVER_테이블DDL 에 미반영
--   ② O27 DIM_MEMBER 4추가/3삭제 + COMMENT 8 — 06_DDL.sql 에 미반영
--      (O27_DIM_MEMBER_ALTER.sql §5 가 "정본 DDL 도 같은 세션에 고쳐라"라고
--       명시했는데 그 단계가 실행되지 않았다)
--   🟢 무사했던 것: DEC-30 구조변경(DIM_SEND_TYPE 신설·SEND_TYPE_SK·RECRUIT_HEADCOUNT·
--      PARTCPT_SEQ·EVENT_BK·DIM_AD_CREATIVE.DURATION_SEC 제거) · O25 SILVER 38컬럼 ·
--      O28/O29 COMMENT 가드 21컬럼 — 전부 정본 DDL 에 접혀 있어 재구축이 그대로 복원했다.
--      COMMENT 커버리지 실측 SILVER 696/696 · GOLD 670/670 = 100%(손실 0).
--
-- ▶ 왜 에러가 3건뿐이었나 — 드리프트 방향에 따라 증상이 다르다 (P57)
--   dbt incremental 은 **대상 테이블의 컬럼 목록**으로 INSERT ... SELECT 를 만든다.
--     · 물리에만 있는 컬럼(모델이 안 만듦) → SELECT 에서 `invalid identifier` = **에러**
--     · 모델에만 있는 컬럼(물리에 없음)   → 목록에 안 들어감 = **에러 없이 조용히 폐기**
--   후자는 어떤 테스트에도 걸리지 않는다. 실제로 `DIM_AD_CREATIVE.DURATION_SEC` 가
--   2회 빌드 동안 무증상 폐기됐고, DIM_MEMBER 의 O27 4컬럼도 같은 상태였다.
--
-- ▶ 실행 전제
--   · 역할 = GN_DW_ADMIN (구조 소유주)
--   · 🔴 `CREATE OR REPLACE TABLE` 금지 — FK·GRANT 파괴. ALTER 만 쓴다.
--   · 본 스크립트는 **멱등**이다(IF EXISTS / IF NOT EXISTS · 개명은 §0 가드로 보호).
-- ============================================================================

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- §0. 사전 상태 확인 — 무엇이 어긋나 있는지 먼저 본다
--     기대(복구 전): SILVER 2건이 PRCS_STAT_CD · DIM_MEMBER 가 DROP대상 3컬럼 보유
-- ─────────────────────────────────────────────────────────────────────────────
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE (TABLE_SCHEMA='SILVER' AND TABLE_NAME IN ('CRM_PAYMENT_BILLING','CRM_SEND_REQUEST')
       AND COLUMN_NAME LIKE '%PRCS_STAT_CD')
   OR (TABLE_SCHEMA='GOLD'   AND TABLE_NAME='DIM_MEMBER'
       AND COLUMN_NAME IN ('AREA_CD','AGE','PREV_MBER_STAT_CD','PREV_MEMBER_STATUS_NAME',
                           'NEW_EXISTING_FLAG','LAST_CAMPAIGN','CURRENT_SPONSORSHIP'))
ORDER BY 1,2,3;

-- ─────────────────────────────────────────────────────────────────────────────
-- §1. O26 SILVER 개명 2건 복구
--     근거 = BRONZE 실측 도메인이 완전 분리라 동명이의 해소가 필요하다(2026-08-04 재확인):
--       TM_PM_MBRFEE_ACMSLT.PRCS_STAT_CD : R 144,028 · S 46,247,143 · F 449
--       TM_MS_PSTMTR_SNDNG.PRCS_STAT_CD  : 0 170 · 1 3,631
--     교집합 0 → 개명은 원천 파괴가 아니라 변별토큰 부여다(P32 원천충실도 기준 충족).
--     ⚠️ RENAME 은 구 COMMENT 를 승계한다(P33) → COMMENT 를 반드시 함께 갱신한다.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE GN_DW.SILVER.CRM_PAYMENT_BILLING RENAME COLUMN PRCS_STAT_CD TO MBRFEE_PRCS_STAT_CD;
ALTER TABLE GN_DW.SILVER.CRM_SEND_REQUEST    RENAME COLUMN PRCS_STAT_CD TO PSTMTR_PRCS_STAT_CD;

ALTER TABLE GN_DW.SILVER.CRM_PAYMENT_BILLING ALTER COLUMN MBRFEE_PRCS_STAT_CD COMMENT
'처리상태 코드 raw (정본 PM013). 🔴회비 전용 — 기부금 원천에도 동명 컬럼이 있으나 정본이 코드그룹 미지정이라 O16형 의미혼입 방지를 위해 NULL 유지. 미납 판정은 PAY_STAT_CD(DEC-3) 불변. [O26] MBRFEE_ 접두 = 원천 테이블 TM_PM_MBRFEE_ACMSLT 변별토큰 — CRM_SEND_REQUEST.PSTMTR_PRCS_STAT_CD(MS061)와 동명이의였다. BRONZE 실측 도메인 완전 분리: 여기 R 144,028·S 46,247,143·F 449 vs PSTMTR 0/1 (2026-08-04 재확인)';

ALTER TABLE GN_DW.SILVER.CRM_SEND_REQUEST ALTER COLUMN PSTMTR_PRCS_STAT_CD COMMENT
'처리상태 코드 raw (정본 MS061). PSTMTR 채널 전용 — 그 외 NULL. [O26] PSTMTR_ 접두 = 원천 테이블 TM_MS_PSTMTR_SNDNG 변별토큰 — CRM_PAYMENT_BILLING.MBRFEE_PRCS_STAT_CD(PM013)와 동명이의였다. BRONZE 실측 도메인 완전 분리: 여기 0=170·1=3,631 vs MBRFEE R/S/F (2026-08-04 재확인)';

-- ─────────────────────────────────────────────────────────────────────────────
-- §2. O27 DIM_MEMBER 구조 복구
--     = O27_DIM_MEMBER_ALTER.sql §2·§3·§4 재실행(그 파일은 멱등이므로 파일째 실행해도 된다).
--     여기서는 자기완결성을 위해 §2·§3 만 옮겨 둔다. COMMENT 8컬럼(§4)은
--     O27_DIM_MEMBER_ALTER.sql §4 를 그대로 실행할 것 — 본 파일에 사본을 두면 정본이 이중화된다(P23).
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS AREA_CD                 VARCHAR(10);
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS AGE                     NUMBER(2,0);
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS PREV_MBER_STAT_CD       VARCHAR(10);
ALTER TABLE GN_DW.GOLD.DIM_MEMBER ADD COLUMN IF NOT EXISTS PREV_MEMBER_STATUS_NAME VARCHAR(100);

ALTER TABLE GN_DW.GOLD.DIM_MEMBER DROP COLUMN IF EXISTS NEW_EXISTING_FLAG;    -- 시점귀속(#113) → 정소재지 FMM
ALTER TABLE GN_DW.GOLD.DIM_MEMBER DROP COLUMN IF EXISTS LAST_CAMPAIGN;        -- 대표규칙 = O8 현업 미결 · 소비처 0
ALTER TABLE GN_DW.GOLD.DIM_MEMBER DROP COLUMN IF EXISTS CURRENT_SPONSORSHIP;  -- 동시 다중후원 정상(14.2%·최대14)

-- → 이어서 `03_top-down_gold/O27_DIM_MEMBER_ALTER.sql` §4 (COMMENT 8컬럼) 실행

-- ─────────────────────────────────────────────────────────────────────────────
-- §3. 복구 검증 — 모델 산출 컬럼 == 물리 컬럼 인가
--     기대: 아래 3건 모두 0행(어긋난 컬럼 없음)
-- ─────────────────────────────────────────────────────────────────────────────
-- (3-1) SILVER 개명 반영 — 기대: 구 이름 0건 · 신 이름 각 1건
SELECT TABLE_NAME, COLUMN_NAME
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='SILVER' AND COLUMN_NAME LIKE '%PRCS_STAT_CD'
ORDER BY 1,2;
--   기대 = CRM_PAYMENT_BILLING.MBRFEE_PRCS_STAT_CD · CRM_SEND_REQUEST.PSTMTR_PRCS_STAT_CD 뿐

-- (3-2) DIM_MEMBER 컬럼 수 — 기대 30
SELECT COUNT(*) AS COLS   -- 기대 30
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='DIM_MEMBER';

-- (3-3) DROP 3컬럼 소멸 + ADD 4컬럼 존재 — 기대: 4행(ADD분)만 조회
SELECT COLUMN_NAME, DATA_TYPE
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD' AND TABLE_NAME='DIM_MEMBER'
  AND COLUMN_NAME IN ('AREA_CD','AGE','PREV_MBER_STAT_CD','PREV_MEMBER_STATUS_NAME',
                      'NEW_EXISTING_FLAG','LAST_CAMPAIGN','CURRENT_SPONSORSHIP')
ORDER BY COLUMN_NAME;

-- ─────────────────────────────────────────────────────────────────────────────
-- §4. 이 다음에 할 일 (사용자)
-- ─────────────────────────────────────────────────────────────────────────────
--   ① dbt build            ← 3 ERROR·68 SKIP 해소. 빈 테이블 9종 재적재.
--                             GOLD 뷰 5종(DIM_MEMBER_CURRENT·WIDE_MEMBER_MONTHLY·
--                             WIDE_MEMBER_EVENT·WIDE_EVENT_PARTICIPATION·WIDE_SERVICE_EVENT)
--                             은 build 가 생성한다 — 현재 미존재.
--   ② O27_DIM_MEMBER_ALTER.sql §6 검증 9종 재실행
--      🔴 단, §6 의 기대값(행수 7,925,716 · 적중률 등)은 재구축 **이전** 측정치다.
--         BRONZE 가 재적재됐으므로 값이 같다는 보장이 없다 — 어긋나면 원인 규명 전 인용 금지(PROC-3 c).
--   ③ 05_SV-Agent_ai/05_SV_DDL.sql 전체 실행
--      🔴 SERVING 스키마가 **객체 0건**이다(실측 2026-08-04). SV 6종·FACT_AD_COMBINED·
--         DIM_MONTH 전멸 + Agent 2종도 재구축에 사라졌을 가능성 → 별도 확인 필요.
--         §7 GRANT 가 같은 파일에 있어 자기완결적이다.
--
-- ▶ 재발 방지 (P57)
--   구조 변경 DoD 에 **③ 정본 DDL 동기화**를 물리 ALTER 와 같은 세션에 못 박는다.
--   완료 판정은 문서가 아니라 "정본 DDL 로 임시 테이블을 만들어 물리와 컬럼 집합을 대조"로 한다.
--   (본 세션에서 실제로 그렇게 검증했다: DDL 30컬럼 == 물리 30컬럼 · 차집합 양방향 0)
-- ============================================================================
-- Co-authored with CoCo
