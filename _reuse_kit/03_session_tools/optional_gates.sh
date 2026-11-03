#!/bin/sh
# optional_gates.sh — 브리핑 GATES 밖 게이트 선택 실행(세션 정리 후 · 사용자 동의 시) · 🆕 O229-B
# Co-authored with CoCo
# 대상 = scripts/*_gate.py − session_brief.GATES (목록을 여기 적지 않는다 · 코드에서 차집합으로 받는다 · R3-9 ㉦)
# 🔴 인자가 필수인 도구(o54_sv_value_gate · id_collision_gate)는 제외한다 — 무인자 exit 2 는 판정이 아니다.
# 🔴 rc 는 파이프 없이 받는다(R0-8-2) · 스테이지 마운트에서 120초를 넘는 게이트가 있다 ⇒ 게이트당 900초.
# 사용: sh scripts/optional_gates.sh            (background 권장 · 출력 = /tmp/optional_gates/)
cd /workspace || exit 2
O=${OPTIONAL_GATES_OUT:-/tmp/optional_gates}
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
# 🆕 [O268] 조각 게이트 등록표 = 「게이트:조각수」. 무조각 실행이 900초를 넘는 게이트는 `--shard k/n` 으로
#   조각마다 따로 돌리고 조각마다 timeout 을 건다(조각 합집합 = 전체 · 판정식 불변).
#   실측 근거 = O267 `sv_code_label_gate` 무조각 rc=143(900초) → O268 8조각 병렬 전건 완주.
#   🔴 조각 결과를 append(`>>`)로 모으지 마라 — 스테이지 마운트는 append 미지원이다(조각마다 파일 1개).
SHARDED="sv_code_label_gate:8"
for g in $LIST; do
  n=""
  for e in $SHARDED; do [ "${e%%:*}" = "$g" ] && n="${e##*:}"; done
  if [ -n "$n" ]; then
    k=0
    while [ $k -lt $n ]; do
      timeout 900 python3 scripts/$g.py --shard $k/$n </dev/null >$O/$g.$k.out 2>&1
      r=$?
      echo "GATE $g $((k+1))/$n rc=$r"
      [ $r -ne 0 ] && FAIL=$((FAIL+1))
      k=$((k+1))
    done
    continue
  fi
  timeout 900 python3 scripts/$g.py </dev/null >$O/$g.out 2>&1
  r=$?
  echo "GATE $g rc=$r"
  [ $r -ne 0 ] && FAIL=$((FAIL+1))
done
echo "OPTIONAL_GATES_DONE fail=$FAIL (출력 = $O/<게이트>.out)"
