#!/bin/bash
set -e

export TARGET_ENV="DEV"
export STATE="/workspace/tmp/runner/state_lane_a.json"
export RUN_FILES="10_dbt_pipeline/02_dbt_parse_compile_build.sql|08_mornitoring/09_OPS_dbt경고_이메일알림_구축.sql"

python3 /workspace/tmp/runner/run.py > /workspace/tmp/runner/lane_a.log 2>&1
