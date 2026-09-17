#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""_o169_axis1_biwi.py 음성 테스트.

🔴 원칙(`R3-2`) = **통과만 보면 그 도구가 무엇을 못 잡는지 모른다.**
   ⇒ ㉠ 오염 기반 축(일부러 깨서 검출·복구를 양축 단정)
     ㉡ 역방향 오탐 축(정상 입력을 「위반」으로 만들지 않는가)
     ㉢ 고치기 전 구현으로 돌리면 **실패**하는 회귀 축(실사고 재현)
"""
import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
import rename_stale_gate as G  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    'biwi', os.path.join(ROOT, 'scripts', '_o169_axis1_biwi.py'))
B = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(B)

T = B.TOKEN
fails = []


def check(name, cond, detail=''):
    if cond:
        print('  🟢 %s' % name)
    else:
        print('  🔴 %s %s' % (name, detail))
        fails.append(name)


def unqualified(line):
    return [x for x in G.RX.finditer(line)
            if x.group(1) == T and not G.qualified(line, x.start(), x.group(1))]


print('[축1] 기본 병기 — 자격 없는 출현이 자격을 얻는가')
src = '| SKIP 된 모델 9 | `%s`·`DIM_SERVICE` |' % T
out = B.annotate(src)
check('자격 획득', not unqualified(out), out)
check('원문 무삭제', out.replace(B.MARK, '') == src, out)

print('[축2] 🔴 회귀 — 스키마 수식 식별자를 깨지 않는가 (예행에서 적발한 실사고)')
src = '오탐 1 = `GOLD.%s` 의 grain 정의' % T
out = B.annotate(src)
check('식별자 파손 없음', not B.CORRUPT_RX.search(out), out)
check('`GOLD.구` 미출현', 'GOLD.구' not in out, out)
check('자격 획득', not unqualified(out), out)
# 🔴 고치기 전 구현(삽입점 = m.start())으로 돌리면 이 축이 실패한다는 실증
i = src.index(T)
naive = src[:i] + B.MARK + src[i:]
check('고치기 전 구현은 실패한다(음성 실증)', bool(B.CORRUPT_RX.search(naive)), naive)

print('[축3] 인용문 내부 — 원문을 개변하지 않고 말미 병기로 가르는가')
src = '> · ㉠ *"실제 조인은 `%s`"* 라고 적혀 있다' % T
out = B.annotate(src)
check('축B 선택(말미 병기)', out.endswith(B.TAIL), out[-60:])
check('인용 원문 무변경', out[:-len(B.TAIL)] == src.rstrip(), out[:80])
check('자격 획득', not unqualified(out), out)

print('[축4] 역방향 오탐 — 이미 병기된 줄을 건드리지 않는가')
for src in ('구 `%s` 는 소멸했다' % T,
            '`%s` 는 **객체 소멸**이다' % T,
            '종전 `%s` 를 썼다' % T,
            '`%s` → `DIM_MEMBER` 개명 대응표' % T):
    check('무변경 유지: %s' % src[:28], B.annotate(src) == src, B.annotate(src))

print('[축5] 대상 아님 — 다른 개명 이름은 손대지 않는가')
src = '`FACT_MEMBER_LIFECYCLE` 를 쓴다'
check('타 이름 무변경', B.annotate(src) == src, B.annotate(src))

print('[축6] 멱등 — 두 번 돌려도 같은가')
src = '| base = `GOLD.%s`(24컬럼) |' % T
one = B.annotate(src)
check('멱등', B.annotate(one) == one, one)

print('[축7] 사후단정 verify() 가 위반을 잡는가(오염 기반)')
src = '`%s` 를 쓴다' % T
check('정상은 통과', B.verify(src, B.annotate(src)) is None)
check('원문 삭제를 잡는다',
      B.verify(src, '구 `DIM_MEMBER` 를 쓴다') is not None)
check('잔여 미자격을 잡는다',
      B.verify(src, src + ' 그리고 `%s` 또 하나' % T) is not None)
long_line = '구 `%s` ' % T + 'x' * 2050
check('2000자 초과를 잡는다', B.verify(src, long_line) is not None)

print('[축8] 제외 목록(지시 축)이 비어 있지 않고 좌표 형식인가')
check('EXCLUDE 비어있지 않음', len(B.EXCLUDE) > 0)
check('EXCLUDE 전건 (경로, 정수줄)',
      all(isinstance(p, str) and isinstance(n, int) for p, n in B.EXCLUDE))

print('')
if fails:
    print('🔴 FAIL — %d축' % len(fails))
    sys.exit(1)
print('🟢 PASS — 전축 통과')
