#!/bin/sh
# O263 세션 종료 점검 — rc 를 파이프 없이 받는다(R0-8-2)
cd /workspace
python3 scripts/split_doc.py 20_issue/00_INDEX_이슈원장.md --republish --expect "O229 이후 점검 · 낡은 문서 갱신" >/tmp/o263_rp.out 2>&1; echo "republish_ledger rc=$?"
python3 scripts/line_len.py "60_repeat_어카운트시작/13_운영계_반영_20261005이후.md" "60_repeat_어카운트시작/readme.md" "문서실행순서.md" "20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-024.md" "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md" "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-003.md" "60_repeat_어카운트시작/11_O누적작업_점검_재현_절차_조각/11_O누적작업_점검_재현_절차-001.md" "99_NEXT_SESSION_조각/99_NEXT_SESSION-O0263-A.md" >/tmp/o263_ll.out 2>&1; echo "line_len rc=$?"
python3 scripts/index_row_gate.py >/tmp/o263_irg.out 2>&1; echo "index_row rc=$?"
python3 scripts/doc_heading_gate.py >/tmp/o263_dhg.out 2>&1; echo "doc_heading rc=$?"
python3 scripts/doc_census.py >/tmp/o263_dc.out 2>&1; echo "doc_census rc=$?"
python3 scripts/doc_coord_gate.py >/tmp/o263_dcg.out 2>&1; echo "doc_coord rc=$?"
python3 scripts/gen_measure_backlog.py --write >/tmp/o263_gmb.out 2>&1; echo "measure_backlog rc=$?"
python3 scripts/decision_closure_gate.py >/tmp/o263_dcl.out 2>&1; echo "decision_closure rc=$?"
for t in scripts/test_*.py; do python3 "$t" >/tmp/t.out 2>&1; r=$?; [ $r -ne 0 ] && echo "FAIL $t rc=$r"; done; echo "tests done"
echo END
