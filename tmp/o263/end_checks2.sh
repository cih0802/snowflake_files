#!/bin/sh
cd /workspace
python3 scripts/handoff_write.py --index >/tmp/o263_hi.out 2>&1; echo "handoff_index rc=$?"
python3 scripts/line_len.py "99_NEXT_SESSION_조각/99_NEXT_SESSION-O0263-A.md" >/tmp/o263_ll2.out 2>&1; echo "line_len rc=$?"
(cd "80_인수인계_프로젝트완료 및 유지보수용" && python3 build_handoff.py --apply >/tmp/o263_bh2.out 2>&1); echo "build_handoff rc=$?"
tail -1 /tmp/o263_bh2.out
python3 scripts/stage_mount_size_gate.py >/tmp/o263_sm.out 2>&1; echo "stage_mount rc=$?"
python3 scripts/session_brief.py --write >/tmp/o263_sb.out 2>&1; echo "brief rc=$?"
echo END
