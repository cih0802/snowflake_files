#!/bin/sh
# O275-C 음성 테스트 전건 — 결과 /tmp/endc/summary.txt (실패만 행 · 끝에 집계)
cd /workspace || exit 1
mkdir -p /tmp/endc
: > /tmp/endc/summary.txt
n=0; f=0
for t in scripts/test_*.py; do
  n=$((n+1))
  timeout 900 python3 "$t" </dev/null >/tmp/endc/t.out 2>&1; r=$?
  if [ $r -ne 0 ]; then f=$((f+1)); echo "TEST $t rc=$r :: $(tail -2 /tmp/endc/t.out | tr '\n' ' ' | cut -c1-200)" >> /tmp/endc/summary.txt; fi
done
echo "TOTAL=$n FAIL=$f" >> /tmp/endc/summary.txt
echo "END_DONE" >> /tmp/endc/summary.txt
