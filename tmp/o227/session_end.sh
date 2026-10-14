#!/bin/sh
# O227 세션 종료 일괄 — rc 는 파이프 없이 파일로(R0-8-2)
cd /workspace
for c in "scripts/doc_census.py" "scripts/gen_measure_backlog.py --write" "scripts/decision_closure_gate.py" "scripts/line_len.py tmp/o227/02_col_evidence.md tmp/o227/handoff_entry_b.md tmp/o227/history_entry_b.md 99_NEXT_SESSION_조각/99_NEXT_SESSION-O0227-B.md 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"; do
  python3 $c </dev/null >/tmp/o227/end.out 2>&1; r=$?; echo "$c rc=$r :: $(tail -1 /tmp/o227/end.out)"
done
for t in scripts/test_*.py; do python3 "$t" </dev/null >/tmp/o227/t.out 2>&1; r=$?; [ $r -ne 0 ] && echo "🔴 $t rc=$r"; done
echo TESTS_DONE
python3 scripts/session_brief.py --write </dev/null >/tmp/o227/brief.out 2>&1; echo "BRIEF_RC=$?"
