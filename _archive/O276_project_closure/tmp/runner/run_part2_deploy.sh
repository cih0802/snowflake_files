#!/bin/bash
set -e

export TARGET_ENV="DEV"
export STATE="/workspace/tmp/runner/state_part2_deploy.json"
export RUN_FILES="10_dbt_pipeline/01_deploy_dbt_project.sql|02_GN_DW_building/08_After_Deploy_DBT.sql"

python3 /workspace/tmp/runner/run.py > /workspace/tmp/runner/part2_deploy.log 2>&1
