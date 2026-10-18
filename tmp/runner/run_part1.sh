#!/bin/bash
set -e

export TARGET_ENV="DEV"
export STATE="/workspace/tmp/runner/state_part1.json"
export RUN_FILES="02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql|08_mornitoring/07_OPS_알림수신자관리_및_파이프라인_이메일알림_표준.sql|08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql|50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql|50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql|50_handoff/06_데이터마이그 GN_DW_SILVER_DDL.sql|50_handoff/07_데이터마이그 C_CONSUMER.sql|04_silver_design/08_SILVER_테이블DDL_20260714.sql|04_silver_design/09_SILVER_AD_CREATIVE_CAMPAIGN_MAP_적재.sql|03_top-down_gold/06_DDL.sql|15_MSTR 이관 PoC/snowflake 적용 ddl/00_mstr_schema_role.sql|15_MSTR 이관 PoC/snowflake 적용 ddl/01_table_script.sql|15_MSTR 이관 PoC/snowflake 적용 ddl/02_view_script.sql|15_MSTR 이관 PoC/snowflake 적용 ddl/03_function_script.sql|15_MSTR 이관 PoC/snowflake 적용 ddl/04_sp_script.sql|15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql"

python3 /workspace/tmp/runner/run.py > /workspace/tmp/runner/part1.log 2>&1
