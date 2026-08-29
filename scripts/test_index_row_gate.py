#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_index_row_gate.py — `index_row_gate.py` 음성 테스트 (5축)

[2026-08-28 O111 신설 · `R3-2` 집행 · 인수인계 착수항목 ③ 처방
 「게이트를 고치면 음성 테스트를 같이 만든다 — 오탐·재현율 양축을 단정하라」]

🔴 왜 필요한가
--------------------------------------------------------------------------
O82-B 가 이 게이트를 신설할 때 「소실·중복·정상append 4종으로 테스트했다」고
적었지만 **테스트 파일이 남지 않았다** ⇒ 이후 개정(O83·O83-B·O109·O111)이
회귀를 확인할 수단 없이 진행됐다. 이 파일이 그 수단이다.

🔴 이 세션(O111)이 고친 것 = **제외 규칙(`is_generated`)을 「유실」 축에만 적용**하고
   **절대 중복을 별도 관측**으로 노출했다. 두 변경 모두
     ㉠ 정상 문서를 막지 않아야 하고(**오탐 축**)
     ㉡ 실제 사고를 여전히 잡아야 한다(**재현율 축**)
   ⇒ 두 축을 함께 단정한다. 한쪽만 보면 게이트를 무력화하고도 🟢 가 나온다.

사용
--------------------------------------------------------------------------
    python3 scripts/test_index_row_gate.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import index_row_gate as G  # noqa: E402

FAILS = []
N = [0]


def check(cond, axis, msg):
    N[0] += 1
    print('  %s %s — %s' % ('🟢' if cond else '🔴', axis, msg))
    if not cond:
        FAILS.append('%s: %s' % (axis, msg))


T = 'doc.md'
SEC = '1. 상태 대시보드 (한눈에)'
GEN = '조각 목차'          # GENERATED_SECTIONS 의 하나


def k(sec, cell):
    return '%s ¦ %s' % (sec, cell)


def main():
    print('[test_index_row_gate]')

    # ── 축1: 정상 append 는 통과한다 (오탐 축) ────────────────────────────
    print('\n축1 — 정상 append (신설만) = 통과')
    base = [k(SEC, 'O01'), k(SEC, 'O02')]
    now = base + [k(SEC, 'O03')]
    fails, added, obs = G.judge({T: now}, {T: base})
    check(not fails, '축1-a', '신설 1행에 FAIL 이 없다 · fails=%s' % fails)
    check(added and added[0][1] == [k(SEC, 'O03')],
          '축1-b', '신설 행이 added 로 보고된다')

    # ── 축2: 행 유실은 잡는다 (재현율 축 · C5·C7 회귀) ────────────────────
    print('\n축2 — 행 유실 = FAIL')
    fails, _a, _o = G.judge({T: [k(SEC, 'O01')]}, {T: base})
    check(any('행 유실' in f for f in fails),
          '축2-a', '골든에 있던 행이 사라지면 FAIL · fails=%s' % fails)

    # ── 축3: 중복 신설은 잡는다 (재현율 축 · O76-B 실사고 회귀) ────────────
    print('\n축3 — 행 중복 = FAIL')
    fails, _a, _o = G.judge({T: base + [k(SEC, 'O02')]}, {T: base})
    check(any('행 중복' in f for f in fails),
          '축3-a', '같은 키가 2행이 되면 FAIL · fails=%s' % fails)

    # ── 축4: 🔴🔴 자동 생성 표의 **중복**은 이제 잡는다 (O111 시정 회귀) ──
    #   종전에는 `is_generated` 를 중복 축까지 적용해 **도구가 같은 행을 두 번 찍어도
    #   침묵**했다. 유실 축에서 빼는 근거(값이 매번 바뀐다)는 중복 축에 없다.
    print('\n축4 — 자동 생성 표의 중복도 FAIL (O111 시정 · 종전은 침묵)')
    gbase = [k(GEN, '001'), k(GEN, '002')]
    fails, _a, _o = G.judge({T: gbase + [k(GEN, '002')]}, {T: gbase})
    check(any('행 중복' in f for f in fails),
          '축4-a', '자동 생성 표의 중복이 FAIL 로 잡힌다 · fails=%s' % fails)
    #   🟢 반대 축(오탐) = 자동 생성 표의 **값 변경**은 여전히 통과해야 한다.
    #     (`--rebalance` 가 「구 행범위」를 바꾸는 정상 작업 · O83-B 근거)
    print('     ↳ 오탐 축: 자동 생성 표의 값 변경(행 교체)은 통과해야 한다')
    fails, _a, _o = G.judge({T: [k(GEN, '001'), k(GEN, '099')]}, {T: gbase})
    check(not fails,
          '축4-b', '자동 생성 표의 행 교체는 FAIL 이 아니다(O83-B 근거 보존) · fails=%s'
          % fails)
    #   🔴 그리고 **사람 원장** 행의 교체는 여전히 유실로 잡혀야 한다(대조군).
    print('     ↳ 대조군: 사람 원장 행의 교체는 유실로 잡혀야 한다')
    fails, _a, _o = G.judge({T: [k(SEC, 'O01'), k(SEC, 'O99')]}, {T: base})
    check(any('행 유실' in f for f in fails),
          '축4-c', '사람 원장 행 교체 = 유실 FAIL (제외 규칙이 새지 않는다) · fails=%s'
          % fails)

    # ── 축5: 절대 중복 관측 (O111 신설 · 「중복 0」 문구 은폐 회귀) ─────────
    print('\n축5 — 절대 중복 관측: 골든에 이미 있는 중복도 숫자로 노출한다')
    dbase = [k(SEC, 'P1'), k(SEC, 'P1'), k(SEC, 'P2')]
    fails, _a, obs = G.judge({T: list(dbase)}, {T: dbase})
    check(not fails,
          '축5-a', '골든과 같은 중복은 FAIL 이 아니다(정상 표 · `🔷 Phase 배정`) · fails=%s'
          % fails)
    o = obs[T]
    check(o['rows'] == 3 and o['uniq'] == 2,
          '축5-b', '행 %d · 고유 %d 를 함께 보고한다' % (o['rows'], o['uniq']))
    check(o['dup_rows'] == 1 and o['dup_keys'] == 1,
          '축5-c', '중복 %d행 · 키 %d종 을 숫자로 노출한다 (종전 출력은 「중복 0」)'
          % (o['dup_rows'], o['dup_keys']))
    check(o['sample'] and o['sample'][0][0] == k(SEC, 'P1'),
          '축5-d', '중복 키 표본을 함께 보여 준다')
    #   🔴 그리고 그 중복이 **더 늘면** FAIL 이어야 한다(관측이 판정을 무력화하지 않는다).
    fails, _a, _o = G.judge({T: dbase + [k(SEC, 'P1')]}, {T: dbase})
    check(any('행 중복' in f for f in fails),
          '축5-e', '기존 중복이 더 늘면 FAIL (관측 축이 판정 축을 삼키지 않는다)')

    print('\n[결과] 단정 %d건 · 실패 %d건' % (N[0], len(FAILS)))
    if FAILS:
        for f in FAILS:
            print('  🔴 %s' % f)
        print('🔴 FAIL')
        return 1
    print('🟢 PASS — 5축 %d단정 전건 통과' % N[0])
    return 0


if __name__ == '__main__':
    sys.exit(main())
