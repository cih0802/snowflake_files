USE ROLE GN_DW_ADMIN;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
USE ROLE GN_DW_DBT;
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='compile --select BIGQUERY_BASIC --vars ''{"bigquery_dt_ranges": [["2025-06-01", "2025-06-30"]]}''';