#!/bin/sh
# O228 세션 종료 일괄 — rc 는 파이프 없이 파일로(R0-8-2)
cd /workspace
for c in "scripts/doc_census.py" "scripts/gen_measure_backlog.py --write" "scripts/decision_closure_gate.py" "scripts/clause_order_gate.py" "scripts/doc_coord_gate.py" "scripts/line_len.py tmp/o228/04_c3_sv.md tmp/o228/handoff_entry.md tmp/o228/history_entry.md tmp/o228/ledger_close.py 99_NEXT_SESSION_조각/99_NEXT_SESSION-O0228-A.md 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"; do
  python3 $c </dev/null >/tmp/o228end.out 2>&1; r=$?; echo "$c rc=$r :: $(tail -1 /tmp/o228end.out)"
done
for t in scripts/test_*.py; do python3 "$t" </dev/null >/tmp/o228t.out 2>&1; r=$?; [ $r -ne 0 ] && echo "🔴 $t rc=$r"; done
echo TESTS_DONE
python3 scripts/session_brief.py --write </dev/null >/tmp/o228brief.out 2>&1; echo "BRIEF_RC=$?"
