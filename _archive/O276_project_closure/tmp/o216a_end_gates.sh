#!/bin/sh
# O216-A 세션 종료 게이트 · 음성 테스트 일괄(rc 를 파이프 없이 수집 · R0-8-2)
cd /workspace
P='60_repeat_어카운트시작/12_GN_DW_재구축_실행순서.md 60_repeat_어카운트시작/13_운영계_반영_20261005이후.md 20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md tmp/o216a_history_entry.md'
python3 scripts/line_len.py $P >/tmp/e_ll.out 2>&1; echo "line_len rc=$?"
python3 scripts/doc_census.py >/tmp/e_dc.out 2>&1; echo "doc_census rc=$?"
python3 scripts/index_row_gate.py >/tmp/e_ir.out 2>&1; echo "index_row rc=$?"
python3 scripts/doc_heading_gate.py >/tmp/e_dh.out 2>&1; echo "doc_heading rc=$?"
python3 scripts/clause_order_gate.py >/tmp/e_co.out 2>&1; echo "clause_order rc=$?"
python3 scripts/doc_coord_gate.py >/tmp/e_cg.out 2>&1; echo "doc_coord rc=$?"
python3 scripts/decision_closure_gate.py >/tmp/e_dcl.out 2>&1; echo "decision_closure rc=$?"
python3 scripts/gen_measure_backlog.py --write >/tmp/e_mb.out 2>&1; echo "measure_backlog rc=$?"
# 🆕 [O216-F] Agent·eval·SV 게이트 편입 — eval V8 stale 이 이 묶음 밖이라 O202~O216-E 내내 미검출이었다
for g in agent_tool_claim_gate agent_object_ref_gate agent_source_lineage_gate eval_expectation_gate sv_identifier_gate; do python3 scripts/$g.py >/tmp/e_$g.out 2>&1; echo "$g rc=$?"; done
n=0; f=0
for t in scripts/test_*.py; do n=$((n+1)); python3 "$t" >/tmp/e_t.out 2>&1; r=$?; if [ $r -ne 0 ]; then f=$((f+1)); echo "FAIL $t rc=$r"; fi; done
echo "tests total=$n fail=$f"
