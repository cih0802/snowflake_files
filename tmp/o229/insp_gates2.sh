#!/bin/sh
# O229 후속 — 장시간 게이트 재실행(timeout 900) + 시정 영향 테스트
cd /workspace
O=tmp/o229/insp_gates2
mkdir -p $O
for g in sv_code_label_gate doc_line_length_gate; do
  timeout 900 python3 scripts/$g.py </dev/null >$O/$g.out 2>&1
  echo "GATE $g rc=$?"
done
for t in test_sv_rule7_scan test_audit_ddl_rule7 test_live_change_gate test_gate_census test_sv_enum_exemption; do
  timeout 300 python3 scripts/$t.py </dev/null >$O/$t.out 2>&1
  echo "TEST $t rc=$?"
done
echo DONE
