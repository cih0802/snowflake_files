-- doc_id: R00 · 현업요청 대응 라이브 대조 근거(읽기 전용) · 설명 = 30_현업요청대응/_라이브대조.md
-- Q01 스키마별 테이블·뷰 수 · 보존기간
SELECT table_schema, table_type, COUNT(*) cnt, MAX(retention_time) retention_days FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE table_schema<>'INFORMATION_SCHEMA' GROUP BY 1,2 ORDER BY 1,2;
-- Q02 테이블·뷰 전수(행수·코멘트 유무)
SELECT table_schema, table_name, table_type, row_count, bytes, created, last_altered, IFF(comment IS NULL,0,1) has_comment, retention_time FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE table_schema<>'INFORMATION_SCHEMA' ORDER BY 1,2;
-- Q03 프로시저·함수·스테이지·시퀀스
SELECT 'PROCEDURE' obj_type, procedure_schema sch, procedure_name name, procedure_language lang, procedure_owner owner FROM GN_DW.INFORMATION_SCHEMA.PROCEDURES
UNION ALL SELECT 'FUNCTION', function_schema, function_name, function_language, function_owner FROM GN_DW.INFORMATION_SCHEMA.FUNCTIONS
UNION ALL SELECT 'STAGE', stage_schema, stage_name, stage_type, stage_owner FROM GN_DW.INFORMATION_SCHEMA.STAGES
UNION ALL SELECT 'SEQUENCE', sequence_schema, sequence_name, data_type, sequence_owner FROM GN_DW.INFORMATION_SCHEMA.SEQUENCES ORDER BY 1,2,3;
-- Q04 스키마 목록 · 보존기간 · 관리접근
SELECT schema_name, schema_owner, retention_time, is_managed_access, created, comment FROM GN_DW.INFORMATION_SCHEMA.SCHEMATA ORDER BY 1;
-- Q05 Semantic View
SHOW SEMANTIC VIEWS IN DATABASE GN_DW;
-- Q06 Agent
SHOW AGENTS IN DATABASE GN_DW;
-- Q07 dbt project
SHOW DBT PROJECTS IN DATABASE GN_DW;
-- Q08 Task
SHOW TASKS IN DATABASE GN_DW;
-- Q09 Alert
SHOW ALERTS IN DATABASE GN_DW;
-- Q10 Cortex Search
SHOW CORTEX SEARCH SERVICES IN DATABASE GN_DW;
-- Q11 Streamlit
SHOW STREAMLITS IN DATABASE GN_DW;
-- Q12 Warehouse
SHOW WAREHOUSES;
-- Q13 Database
SHOW DATABASES LIKE 'GN_DW';
