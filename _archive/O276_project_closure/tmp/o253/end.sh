cd /workspace
export SESSION_LABEL=O253
python3 scripts/doc_census.py </dev/null >/tmp/e1.out 2>&1; echo "census=$?"
python3 scripts/gen_measure_backlog.py --write </dev/null >/tmp/e3.out 2>&1; echo "backlog=$?"
python3 scripts/decision_closure_gate.py </dev/null >/tmp/e4.out 2>&1; echo "closure=$?"
for t in scripts/test_*.py; do python3 "$t" </dev/null >/tmp/t.out 2>&1; r=$?; [ $r -ne 0 ] && echo "FAILTEST $t rc=$r"; done; echo tests_done
python3 scripts/session_brief.py --write </dev/null >/tmp/e2.out 2>&1; echo "brief=$?"
