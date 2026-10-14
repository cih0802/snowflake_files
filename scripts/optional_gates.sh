#!/bin/sh
# optional_gates.sh — 브리핑 GATES 밖 게이트 선택 실행(세션 정리 후 · 사용자 동의 시) · 🆕 O229-B
# Co-authored with CoCo
# 대상 = scripts/*_gate.py − session_brief.GATES (목록을 여기 적지 않는다 · 코드에서 차집합으로 받는다 · R3-9 ㉦)
# 🔴 인자가 필수인 도구(o54_sv_value_gate · id_collision_gate)는 제외한다 — 무인자 exit 2 는 판정이 아니다.
# 🔴 rc 는 파이프 없이 받는다(R0-8-2) · 스테이지 마운트에서 120초를 넘는 게이트가 있다 ⇒ 게이트당 900초.
# 사용: sh scripts/optional_gates.sh            (background 권장 · 출력 = /tmp/optional_gates/)
cd /workspace || exit 2
O=/tmp/optional_gates
mkdir -p $O
LIST=$(python3 -c "
import glob, os, sys
sys.path.insert(0, 'scripts')
import session_brief as b
inb = set()
for g in b.GATES:
    s = ' '.join(map(str, g)) if isinstance(g, (list, tuple)) else str(g)
    inb |= {os.path.basename(x)[:-3] for x in glob.glob('scripts/*_gate.py') if os.path.basename(x)[:-3] in s}
skip = {'o54_sv_value_gate', 'id_collision_gate'}
print(' '.join(sorted({os.path.basename(x)[:-3] for x in glob.glob('scripts/*_gate.py')
                       if not os.path.basename(x).startswith('test_')} - inb - skip)))
")
FAIL=0
for g in $LIST; do
  timeout 900 python3 scripts/$g.py </dev/null >$O/$g.out 2>&1
  r=$?
  echo "GATE $g rc=$r"
  [ $r -ne 0 ] && FAIL=$((FAIL+1))
done
echo "OPTIONAL_GATES_DONE fail=$FAIL (출력 = $O/<게이트>.out)"
