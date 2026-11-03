#!/bin/sh
# O275-G 최종 검증 — 결과 /workspace/tmp/restructure/o275g_final.txt
cd /workspace || exit 1
O=/tmp/o275g_final.txt
python3 scripts/session_brief.py --write </dev/null >/tmp/b.out 2>&1; echo "brief rc=$?" > $O.tmp
n=0; f=0
for t in scripts/test_*.py; do
  n=$((n+1)); timeout 900 python3 "$t" </dev/null >/tmp/t.out 2>&1; r=$?
  if [ $r -ne 0 ]; then f=$((f+1)); echo "TEST $t rc=$r" >> $O.tmp; fi
done
echo "tests TOTAL=$n FAIL=$f" >> $O.tmp
for g in doc_line_length_gate handoff_ddl_gate rename_stale_gate live_change_gate sv_unit_gate table_ddl_column_gate stage_mount_size_gate; do
  timeout 900 python3 scripts/$g.py </dev/null >/tmp/g.out 2>&1; echo "gate $g rc=$?" >> $O.tmp
done
cp $O.tmp $O
echo DONE >> $O
