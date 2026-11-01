-- 기존 secret 확인
SHOW SECRETS;

-- Secret 업데이트 (username과 새 PAT으로)
ALTER SECRET git_sec SET 
  USERNAME = 'cih0802'
  PASSWORD = '<새로운_PAT>';


ALTER DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = '순서8 GOLD 활성화: dim=incremental(DDL구조보존)/fact=table, full_refresh:false';


SELECT 'FACT_SERVICE_EVENT' T, COUNT(*) N FROM GN_DW.GOLD.FACT_SERVICE_EVENT
UNION ALL SELECT 'FACT_MEMBER_MONTHLY',    COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY
UNION ALL SELECT 'FACT_MEMBER_EVENT',      COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_EVENT
UNION ALL SELECT 'FACT_EVENT_PARTICIPATION',COUNT(*) FROM GN_DW.GOLD.FACT_EVENT_PARTICIPATION
UNION ALL SELECT 'FACT_GA_BEHAVIOR',       COUNT(*) FROM GN_DW.GOLD.FACT_GA_BEHAVIOR
UNION ALL SELECT 'FACT_TARGET_DEV',        COUNT(*) FROM GN_DW.GOLD.FACT_TARGET_DEV
ORDER BY 1;


ALTER DBT PROJECT GN_DW.SILVER.GN_DW_SILVER_PIPELINE
  ADD VERSION FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline'
  COMMENT = '순서8 GOLD활성화 + 순서8-B SILVER DDL소유전환';


--SILVER 스키마의 테이블 중 컬럼 전체가 null인 것을 추출하는 쿼리
EXECUTE IMMEDIATE $$
DECLARE
  stmt STRING;
  rs RESULTSET;
BEGIN
  SELECT LISTAGG(s, ' UNION ALL ') WITHIN GROUP (ORDER BY table_name)
    INTO :stmt
  FROM (
    SELECT table_name,
      'SELECT ''' || table_name || ''' tbl, COUNT(*) n, ARRAY_COMPACT(ARRAY_CONSTRUCT(' ||
      LISTAGG('IFF(COUNT("' || column_name || '")=0,''' || column_name || ''',NULL)', ',')
        WITHIN GROUP (ORDER BY ordinal_position) ||
      ')) fully_null_cols FROM GN_DW.SILVER."' || table_name || '"' AS s
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema='SILVER'
    GROUP BY table_name
  );
  rs := (EXECUTE IMMEDIATE :stmt);
  RETURN TABLE(rs);
END;
$$