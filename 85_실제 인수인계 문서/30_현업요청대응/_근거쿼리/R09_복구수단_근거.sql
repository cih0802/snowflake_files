-- doc_id: R09 · 복구 수단(Time Travel · Fail-safe) 실측 근거(읽기 전용) · 설명 = 30_현업요청대응/R09_장애대응복구.md §2
-- Q01 계정 보존 파라미터
SHOW PARAMETERS LIKE '%RETENTION%' IN ACCOUNT;
-- Q02 스키마별 보존기간
SELECT schema_name, retention_time, is_transient, is_managed_access FROM GN_DW.INFORMATION_SCHEMA.SCHEMATA ORDER BY 1;
-- Q03 스키마별 테이블 종류(permanent/transient) · 용량 · 보존기간 최대·최소
SELECT table_schema, is_transient, COUNT(*) n_tables, ROUND(SUM(bytes)/POWER(1024,3),3) gb, MIN(retention_time) min_ret, MAX(retention_time) max_ret FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE table_type='BASE TABLE' GROUP BY 1,2 ORDER BY 1,2;
-- Q04 DB 보존기간
SHOW DATABASES LIKE 'GN_DW';
