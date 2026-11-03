#!/bin/sh
# O229 Inspection — 브리핑 GATES 밖 게이트 + 음성 테스트 전건 (rc 는 파이프 없이 · R0-8-2)
cd /workspace
OUT=tmp/o229/insp_gates
mkdir -p $OUT
for g in decision_closure_gate rename_stale_gate sv_comment_object_gate sv_code_label_gate sv_unit_gate live_change_gate gold_erd_coverage_gate handoff_ddl_gate table_ddl_column_gate wide_select_yml_gate doc_line_length_gate stage_mount_size_gate o54_sv_value_gate gate_census; do
  timeout 240 python3 scripts/$g.py </dev/null >$OUT/$g.out 2>&1
  echo "GATE $g rc=$?"
done
for t in scripts/test_*.py; do
  n=$(basename $t .py)
  timeout 240 python3 $t </dev/null >$OUT/$n.out 2>&1
  echo "TEST $n rc=$?"
done
echo DONE
