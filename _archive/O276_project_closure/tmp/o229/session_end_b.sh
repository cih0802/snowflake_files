#!/bin/sh
cd /workspace
python3 scripts/split_doc.py 20_issue/00_INDEX_이슈원장.md --republish --expect "O228-A 잔여(eval·현업회신 제외) 전건" </dev/null >/tmp/rp.out 2>&1; echo "RP=$?"
python3 scripts/doc_census.py </dev/null >/tmp/dc.out 2>&1; echo "DC=$?"
python3 scripts/session_brief.py --write </dev/null >/tmp/sb.out 2>&1; echo "BRIEF=$?"
python3 scripts/gen_measure_backlog.py --write </dev/null >/tmp/gmb.out 2>&1; echo "GMB=$?"
F=0
for t in scripts/test_*.py; do python3 "$t" </dev/null >/tmp/t.out 2>&1; r=$?; [ $r -ne 0 ] && echo "🔴 $t rc=$r" && F=$((F+1)); done
echo "TESTS_FAIL=$F"
python3 scripts/line_len.py scripts/optional_gates.sh 00_guides/03_init_ihcho_스킬_본문.md 00_guides/03_init_ihcho_스킬_참조_세션종료.md 05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql scripts/campaign_axis_gate.py tmp/o229/handoff_entry_b.md tmp/o229/history_entry_b.md </dev/null | tail -1
