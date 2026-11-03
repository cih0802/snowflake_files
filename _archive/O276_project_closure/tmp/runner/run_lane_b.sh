#!/bin/bash
set -e

export TARGET_ENV="DEV"
export STATE="/workspace/tmp/runner/state_lane_b.json"
export RUN_FILES="15_MSTR 이관 PoC/snowflake 적용 ddl/06_MSTR_적재_실행.sql"

python3 /workspace/tmp/runner/run.py > /workspace/tmp/runner/lane_b.log 2>&1
