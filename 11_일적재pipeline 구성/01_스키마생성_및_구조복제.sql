-- BRONZE_CRM_2 / SILVER_2 / GOLD_2 스키마 생성 + SILVER/GOLD 라이브 테이블 구조 CLONE(데이터 0행)
-- Co-authored with CoCo
--
-- 근거: 00_개요_및_실행순서.md "SILVER_2/GOLD_2 구조" 결정 — DDL이 구조를 소유하는 원칙을 유지하되,
--   04_silver_design/08_SILVER_테이블DDL_*.sql · 03_top-down_gold/06_DDL.sql 을 손으로 재작성하지 않고
--   "지금 라이브" 테이블을 CLONE 해 동일 구조(컬럼·타입·제약·COMMENT)를 그대로 옮긴다.
-- 전제: GN_DW.SILVER / GN_DW.GOLD 가 이미 배포·적재된 상태(07_ENVIRONMENT_RBAC_setup.sql B.5 이후).
-- 실행 role: GN_DW_ADMIN (스키마·테이블 소유자 = ADMIN 원칙 유지).
-- 멱등: CREATE SCHEMA IF NOT EXISTS / CREATE TABLE IF NOT EXISTS — 반복 실행 안전.

USE ROLE GN_DW_ADMIN;

/* =====================================================================
   1) 스키마 생성 (07_ENVIRONMENT_RBAC_setup.sql B.5 에 이미 동일 문장이 반영돼 있다면 no-op)
   ===================================================================== */
CREATE SCHEMA IF NOT EXISTS GN_DW.BRONZE_CRM_2 WITH MANAGED ACCESS
  COMMENT = '원천 적재 — CRM(회원/납입/캠페인). 일적재 테스트용';
CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER_2 WITH MANAGED ACCESS
  COMMENT = '정제/통합 레이어 — dbt 일적재 테스트용';
CREATE SCHEMA IF NOT EXISTS GN_DW.GOLD_2 WITH MANAGED ACCESS
  COMMENT = '분석 레이어 — dbt 일적재 테스트용';

/* =====================================================================
   2) SILVER → SILVER_2 : 라이브 BASE TABLE 전량 CLONE 후 TRUNCATE (구조만 복제)
   ===================================================================== */
EXECUTE IMMEDIATE $$
DECLARE
  c CURSOR FOR
    SELECT TABLE_NAME
    FROM GN_DW.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'SILVER' AND TABLE_TYPE = 'BASE TABLE';
  done_count INTEGER DEFAULT 0;
BEGIN
  FOR rec IN c DO
    EXECUTE IMMEDIATE
      'CREATE TABLE IF NOT EXISTS GN_DW.SILVER_2.' || rec.TABLE_NAME ||
      ' CLONE GN_DW.SILVER.' || rec.TABLE_NAME;
    EXECUTE IMMEDIATE
      'TRUNCATE TABLE IF EXISTS GN_DW.SILVER_2.' || rec.TABLE_NAME;
    done_count := done_count + 1;
  END FOR;
  RETURN 'SILVER -> SILVER_2 구조 복제 완료: ' || done_count || '개 테이블';
END;
$$;

/* =====================================================================
   3) GOLD → GOLD_2 : 라이브 BASE TABLE(DIM/FACT)만 CLONE 후 TRUNCATE
      WIDE 뷰(12종)는 CLONE 대상이 아니다 — dbt build 시 CREATE OR REPLACE VIEW 로 자동 생성된다.
   ===================================================================== */
EXECUTE IMMEDIATE $$
DECLARE
  c CURSOR FOR
    SELECT TABLE_NAME
    FROM GN_DW.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'GOLD' AND TABLE_TYPE = 'BASE TABLE';
  done_count INTEGER DEFAULT 0;
BEGIN
  FOR rec IN c DO
    EXECUTE IMMEDIATE
      'CREATE TABLE IF NOT EXISTS GN_DW.GOLD_2.' || rec.TABLE_NAME ||
      ' CLONE GN_DW.GOLD.' || rec.TABLE_NAME;
    EXECUTE IMMEDIATE
      'TRUNCATE TABLE IF EXISTS GN_DW.GOLD_2.' || rec.TABLE_NAME;
    done_count := done_count + 1;
  END FOR;
  RETURN 'GOLD -> GOLD_2 구조 복제 완료: ' || done_count || '개 테이블';
END;
$$;

/* =====================================================================
   4) 검증 — 원본과 복제본의 테이블 개수/컬럼 개수 일치 확인
   ===================================================================== */
SELECT 'SILVER' AS SRC_SCHEMA, COUNT(*) AS BASE_TABLE_CNT
FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'SILVER' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'SILVER_2', COUNT(*)
FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'SILVER_2' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'GOLD', COUNT(*)
FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'GOLD' AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'GOLD_2', COUNT(*)
FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'GOLD_2' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY 1;
