#!/bin/sh
# O275 세션 종료 일괄 — 결과는 /tmp/end/*.out · 요약 /tmp/end/summary.txt
cd /workspace || exit 1
mkdir -p /tmp/end
: > /tmp/end/summary.txt
for c in "doc_census.py" "session_brief.py --write" "gen_measure_backlog.py --write" "decision_closure_gate.py"; do
  n=$(echo "$c" | cut -d' ' -f1)
  python3 scripts/$c </dev/null >/tmp/end/$n.out 2>&1; r=$?
  echo "$n rc=$r :: $(tail -1 /tmp/end/$n.out | cut -c1-140)" >> /tmp/end/summary.txt
done
for t in scripts/test_*.py; do
  timeout 900 python3 "$t" </dev/null >/tmp/end/t.out 2>&1; r=$?
  [ $r -ne 0 ] && echo "TEST $t rc=$r :: $(tail -2 /tmp/end/t.out | tr '\n' ' ' | cut -c1-200)" >> /tmp/end/summary.txt
done
echo "END_DONE" >> /tmp/end/summary.txt
