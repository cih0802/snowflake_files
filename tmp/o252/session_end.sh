#!/bin/sh
# O252 세션 종료 절차 — rc 를 파이프 뒤에서 읽지 않는다(R0-8-2)
cd /workspace
run() { name="$1"; shift; "$@" </dev/null >"/tmp/o252_end_$name.out" 2>&1; echo "$name rc=$?"; }
run republish python3 scripts/split_doc.py 20_issue/00_INDEX_이슈원장.md --republish --label O252 --expect "TMP_O252_MODEL 삭제 승인"
run index_row python3 scripts/index_row_gate.py
run line_len python3 scripts/line_len.py 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md 99_NEXT_SESSION_조각/99_NEXT_SESSION-O0252-A.md 20_issue/01_세션이력_조각/01_세션이력-089.md
run census python3 scripts/doc_census.py
run measure python3 scripts/gen_measure_backlog.py --write
run closure python3 scripts/decision_closure_gate.py
for t in scripts/test_*.py; do python3 "$t" </dev/null >/tmp/o252_t.out 2>&1; r=$?; [ $r -ne 0 ] && echo "NEG FAIL $t rc=$r"; done
echo "NEG done"
run brief python3 scripts/session_brief.py --write
echo ALL_DONE
