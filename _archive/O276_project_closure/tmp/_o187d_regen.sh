#!/bin/sh
# [O187-D] 30_output_share 전체 재생성 — 00_생성기-문서명 매핑 §4 순서 그대로. 단계별 rc 를 파일로 남긴다.
cd /workspace
LOG=tmp/_o187d_regen.log
: > $LOG
run() { echo "=== $* ===" >> $LOG; timeout 1500 python3 "$@" </dev/null >> $LOG 2>&1; echo "rc=$? :: $*" >> $LOG; }
run scripts/gen_column_inventory_20260811.py 20260928
run scripts/gen_column_mapping.py
run scripts/run_bronze_audit_host.py
run scripts/gen_code_system_gates.py
run scripts/gen_silver_gold_retention.py
run scripts/gen_metric_gold_mapping.py
run scripts/gen_section_assembly.py
run scripts/gen_unresolved_issue_summary.py --write
run scripts/gen_concept_diagram.py
run scripts/gen_arch_map.py
run scripts/gen_pipeline_erd.py
run scripts/test_generators.py
echo ALLDONE >> $LOG
