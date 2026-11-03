-- B-C 통합 데이터 마이그레이션 SQL (Direct INSERT OVERWRITE from GN_DW_SHARED to GN_DW)
-- 동일 계정 내 마운트된 Direct Share(GN_DW_SHARED)에서 타겟 DB(GN_DW)로 직접 고속 이관
-- 작성일시: 2026-10-13
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   기존 03번(B_BROKER: CSV 언로드)과 07번(C_CONSUMER: 스테이지 CSV 적재)의 다단계 절차 대신,
--   동일 계정에 마운트된 Direct Share(GN_DW_SHARED)로부터 타겟 DB(GN_DW)로 직접 데이터를 복사(INSERT OVERWRITE)한다.
--
-- ⚠️ 기술적 제약 사항 (CLONE 불가)
--   Snowflake 정책상 Direct Share로 수신한 Imported Database/Schema/Table은 CLONE 할 수 없습니다.
--   (오류: "Cannot clone from a schema/table that was imported from a share")
--   따라서 스테이지 파일 export/import 없이 DB 간 직접 SQL(INSERT OVERWRITE)을 수행하는 것이 가장 저비용·최고속 방법입니다.
--
-- 이관 대상 / SCOPE (총 80개 테이블)
--   ① BRONZE_CRM (53 테이블)
--   ② BRONZE_AGENCY (4 테이블)
--   ③ BRONZE_ERP (2 테이블)
--   ④ BRONZE_GA4 (2 테이블)
--   ⑤ BRONZE_GSC (3 테이블)
--   ⑥ SILVER (4 테이블: BIGQUERY_REFINED_DATA, ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA, ANNUAL_MBRFEE_PRDT_ACTL_DATA, MM_SPNSR_CLS_AGGR_DATA)
--   ⑦ ML (12 테이블: ML_RST_DATA_*)
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- 1. 대용량 작업 처리를 위해 임시로 웨어하우스 사이즈 상향 (권장: LARGE)
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';

-- 2. GN_DW_SHARED -> GN_DW 직접 이관 익명 블록 실행
EXECUTE IMMEDIATE $$
DECLARE
  c1 CURSOR FOR
    SELECT table_schema, table_name
    FROM GN_DW_SHARED.INFORMATION_SCHEMA.TABLES
    WHERE table_type = 'BASE TABLE'
      AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY', 'BRONZE_GA4', 'BRONZE_GSC')
            OR (table_schema = 'SILVER' AND table_name IN ('BIGQUERY_REFINED_DATA','ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA','ANNUAL_MBRFEE_PRDT_ACTL_DATA','MM_SPNSR_CLS_AGGR_DATA'))
            OR  table_schema = 'ML' );
  cnt INTEGER DEFAULT 0;
  v_sql STRING;
BEGIN
  FOR rec IN c1 DO
    IF (rec.table_schema = 'SILVER' AND rec.table_name = 'BIGQUERY_REFINED_DATA') THEN
      -- SILVER.BIGQUERY_REFINED_DATA: 월별(YYYYMM)로 랜덤 하루(1일)씩 샘플링 복사 (03번 B_BROKER 규칙 적용)
      v_sql := 'INSERT OVERWRITE INTO GN_DW."SILVER"."BIGQUERY_REFINED_DATA" '
            || 'WITH distinct_dates AS ('
            || '  SELECT DISTINCT EVENT_DATE, SUBSTR(EVENT_DATE, 1, 6) AS ym '
            || '  FROM GN_DW_SHARED."SILVER"."BIGQUERY_REFINED_DATA"'
            || '), '
            || 'sampled_dates AS ('
            || '  SELECT EVENT_DATE '
            || '  FROM ('
            || '    SELECT EVENT_DATE, ROW_NUMBER() OVER (PARTITION BY ym ORDER BY RANDOM()) AS rn '
            || '    FROM distinct_dates'
            || '  ) WHERE rn = 1'
            || ') '
            || 'SELECT * FROM GN_DW_SHARED."SILVER"."BIGQUERY_REFINED_DATA" '
            || 'WHERE EVENT_DATE IN (SELECT EVENT_DATE FROM sampled_dates)';
      EXECUTE IMMEDIATE :v_sql;
    ELSE
      -- 그 외 모든 테이블: 전체 데이터 직접 복사
      v_sql := 'INSERT OVERWRITE INTO GN_DW."' || rec.table_schema || '"."' || rec.table_name || '" '
            || 'SELECT * FROM GN_DW_SHARED."' || rec.table_schema || '"."' || rec.table_name || '"';
      EXECUTE IMMEDIATE :v_sql;
    END IF;
    cnt := cnt + 1;
  END FOR;
  RETURN 'MIGRATION 완료: ' || cnt || '개 테이블';
END;
$$;

-- 3. 웨어하우스 사이즈 원복
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';

-- 4. 이관 결과 검증 쿼리
-- (1) 스키마별 테이블 수 및 행 수 대조 (GN_DW vs GN_DW_SHARED)
SELECT
  t.table_schema,
  COUNT(*) AS tables,
  SUM(t.row_count) AS gn_dw_rows,
  SUM(s.row_count) AS shared_rows
FROM GN_DW.INFORMATION_SCHEMA.TABLES t
LEFT JOIN GN_DW_SHARED.INFORMATION_SCHEMA.TABLES s
  ON t.table_schema = s.table_schema AND t.table_name = s.table_name
WHERE t.table_type = 'BASE TABLE'
  AND t.table_schema IN ('BRONZE_AGENCY', 'BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_GA4', 'BRONZE_GSC', 'ML', 'SILVER')
GROUP BY 1 ORDER BY 1;

-- (2) ARRAY 및 VARIANT 컬럼 보존 상태 확인 (SILVER.ITEMS, ML.PREDICTION/PREDICT)
SELECT 'SILVER.BIGQUERY_REFINED_DATA' AS target, TYPEOF(ITEMS) AS ptype, COUNT(*) AS cnt
FROM GN_DW.SILVER.BIGQUERY_REFINED_DATA
GROUP BY 1, 2
UNION ALL
SELECT 'ML.ML_RST_DATA_SPNSR_CHURN_12M', TYPEOF(PREDICTION), COUNT(*)
FROM GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M
GROUP BY 1, 2
UNION ALL
SELECT 'ML.ML_RST_DATA_ONCE_CONVERSION', TYPEOF(PREDICT), COUNT(*)
FROM GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION
GROUP BY 1, 2;
