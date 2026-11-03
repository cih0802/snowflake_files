#!/bin/sh
# O272-D 세션 종료 일괄(1회용) — 종료코드는 파일로 받는다(R0-8-2)
cd /workspace || exit 2
mkdir -p /tmp/o272
for s in "scripts/doc_census.py" "scripts/session_brief.py --write" "scripts/gen_measure_backlog.py --write" "scripts/decision_closure_gate.py" "scripts/index_row_gate.py"; do
  python3 $s </dev/null >/tmp/o272/end_step.out 2>&1; r=$?
  echo "STEP $s rc=$r :: $(tail -1 /tmp/o272/end_step.out | cut -c1-160)"
done
n=0; f=0
for t in scripts/test_*.py; do
  n=$((n+1))
  timeout 600 python3 "$t" </dev/null >/tmp/o272/t.out 2>&1; r=$?
  if [ $r -ne 0 ]; then f=$((f+1)); echo "FAIL $t rc=$r :: $(tail -1 /tmp/o272/t.out | cut -c1-160)"; fi
done
echo "TESTS total=$n fail=$f"
