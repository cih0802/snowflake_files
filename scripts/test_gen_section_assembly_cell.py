#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_gen_section_assembly_cell.py — `gen_section_assembly.code_cell` 음성 테스트
# Co-authored with CoCo

[2026-08-30 O124 신설 · `R3-2` 집행 · 착수표 ⑨ 의 근본 원인에 대한 회귀 방어]

🔴 왜 필요한가
--------------------------------------------------------------------------
착수표 ⑨ 의 `09_보고서필드_조립가능성.md` 5건은 **오타가 아니라 생성기 결함**이었다.
종전 코드 = `` `{r['GOLD_매핑'][:60]}` `` — 값을 60자로 **자른 뒤 백틱으로 감싼다.**
🔴 문제는 자르는 순서가 아니라 **값 자체가 백틱을 품고 있다**는 점이다 ⇒ 절단면에서
**백틱이 홀수 개 남아 코드 스팬이 닫히지 않는다.** `doc_line_length_gate.split_row` 는
백틱마다 `in_code` 를 토글하고 `in_code` 인 동안 `|` 를 세지 않으므로, 홀수 백틱이면
`in_code` 가 **행 끝까지 켜진 채 남아** 열수가 **4 → 2** 로 무너진다.
🔴 이 결함은 산출물을 손으로 고쳐도 **재생성에서 되살아난다** ⇒ 방어는 생성기 쪽에 있어야 한다.

🔴🔴 **[O124-B 자기정정] 초판 docstring 은 「감싼 뒤 자르는 것이 아니라 자른 값을 감싸는데」로
적어 원인을 「절단 순서」로 오귀속했다.** 종전 코드는 이미 자른 뒤 감쌌고, 유일한 근본 처방은
**값의 백틱 제거**다. ⇒ 🟢 그래서 축1(백틱 균형)이 이 테스트의 **본질 축**이고,
🆕 **축5 가 실제 게이트 파서로 그것을 교차 검증**한다(자기신고 대신 도구 대조).

단정 축
--------------------------------------------------------------------------
㉠ **백틱 균형** = 출력의 백틱 개수는 항상 **정확히 2**(여는 것 + 닫는 것)이거나 0(빈 값)이다.
㉡ **열수 보존**(핵심 축) = 그 셀을 넣어 만든 표 행의 셀 수가 **헤더와 같다**.
   🔴 이 축이 실사고를 직접 재현한다 — 종전 구현을 넣으면 이 단정이 깨진다(축4 가 실증).
㉢ **절단 표시** = 한도를 넘으면 `…` 로 잘렸음을 밝힌다(조용한 소실 금지).
㉣ **음성** = 종전 구현(`` `v[:n]` ``)을 그 자리에서 만들어 **실제로 깨지는 것을 확인**한다.
㉤ 🆕 **게이트 교차 검증** = 판정을 이 테스트가 자체 계산하지 않고
   **`doc_line_length_gate.split_row` 에 물어본다**(같은 것을 다르게 재는 지점 제거 · `R3-9 ㉡`).


사용
--------------------------------------------------------------------------
    python3 scripts/test_gen_section_assembly_cell.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

FAILS = []
N = [0]


def check(cond, axis, msg):
    N[0] += 1
    print('  %s %s — %s' % ('🟢' if cond else '🔴', axis, msg))
    if not cond:
        FAILS.append('%s: %s' % (axis, msg))


def cells(row):
    """마크다운 표 행의 셀 수 — 이스케이프된 `\\|` 는 구분자가 아니다."""
    return len(row.strip().strip('|').replace('\\|', '\u0000').split('|'))


# 🔴 실사고 값을 그대로 쓴다(창작 금지) — `09` 119행의 `GOLD_매핑` 원문 형태.
REAL = ('⛔ 불가 — 목표 원천 `TM_CM_MBER_DVLP_GOAL` 11컬럼 시간축이 '
        '`STDYY`+`STDR_MT` 뿐 — 일자 컬럼 부재')
CASES = [
    REAL,
    '`FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 243,545/243,545 전건 센티넬이라 도달불가다',
    'DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT',
    'a|b|c 파이프가 들어 있는 값',
    '`홀수 백틱',
    '',
    None,
    '짧다',
]


def main():
    import gen_section_assembly as G
    print('[test_gen_section_assembly_cell]')

    # ── 축1: 백틱 균형 ──────────────────────────────────────────────────
    print('\n축1 — 백틱은 정확히 2개(또는 빈 값이면 0개)')
    for v in CASES:
        out = G.code_cell(v, 60)
        n = out.count('`')
        check(n in (0, 2), '축1-a', 'backtick %d · %r → %r' % (n, str(v)[:26], out[:38]))

    # ── 축2: 🔴🔴 열수 보존 (실사고 재현 축) ─────────────────────────────
    print('\n축2 — 🔴 그 셀을 넣은 표 행의 열수가 헤더와 같다')
    header = '| 필드값 | GOLD 매핑 | 판정 | 왜 안 되는가 |'
    want = cells(header)
    for v in CASES:
        row = '| 기준일시 | %s | ⛔ 원천부재 | 사유 |' % G.code_cell(v, 60)
        check(cells(row) == want,
              '축2-a', '열수 %d = 헤더 %d · %r' % (cells(row), want, str(v)[:26]))

    # ── 축3: 절단 표시 · 개행 제거 ────────────────────────────────────────
    print('\n축3 — 절단은 `…` 로 밝히고 개행은 넣지 않는다')
    out = G.code_cell(REAL, 20)
    check(out.endswith('…`'), '축3-a', '한도 초과 시 `…` 로 끝난다 · %r' % out)
    check(len(out) < len(REAL), '축3-b', '실제로 짧아졌다')
    check('\n' not in G.code_cell('두\n줄', 60), '축3-c', '개행이 셀에 들어가지 않는다')
    check(G.code_cell('', 60) == '—' and G.code_cell(None, 60) == '—',
          '축3-d', '빈 값은 코드 스팬으로 감싸지 않는다(`—`)')
    check(G.code_cell('짧다', 60) == '`짧다`',
          '축3-e', '한도 이내면 `…` 를 붙이지 않는다')

    # ── 축4: 🔴 음성 — 종전 구현은 이 단정을 깬다 ────────────────────────
    print('\n축4 — 음성: 종전 구현(`v[:n]` 을 감싸기)은 축1·축2 를 깬다')
    legacy = '`%s`' % REAL[:60]
    check(legacy.count('`') % 2 == 1,
          '축4-a', '종전 구현은 백틱이 홀수다(%d개) ⇒ 축1 이 이 실패를 잡는다' % legacy.count('`'))
    legacy_row = '| 기준일시 | %s | ⛔ 원천부재 | 사유 |' % legacy
    # 🔴 코드 스팬이 닫히지 않으면 렌더러는 그 뒤 `|` 를 구분자로 읽지 않는다.
    #    여기서는 그 효과를 「닫히지 않은 스팬 = 뒤쪽 파이프 무효」로 모사해 단정한다.
    head, _, tail = legacy_row.partition('`')
    broken = cells(head + '`' + tail.replace('|', ' ', 99))
    check(broken != want,
          '축4-b', '🔴 종전 구현 행은 열수가 %d 로 무너진다(헤더 %d) ⇒ 실사고 재현' % (broken, want))
    check(cells('| 기준일시 | %s | ⛔ 원천부재 | 사유 |' % G.code_cell(REAL, 60)) == want,
          '축4-c', '🟢 현행 구현은 같은 값에서 열수를 지킨다')

    # ── 축5: 🆕 🔴🔴 실제 게이트 파서로 교차 검증 (자기신고 제거 · `R3-9 ㉡`) ──
    #   🔴 위 `cells()` 는 이 테스트가 만든 근사 파서다. 판정의 정본은 게이트이므로
    #     같은 행을 **게이트 자신에게** 물어 두 축이 일치하는지 본다.
    print('\n축5 — 🔴 판정을 `doc_line_length_gate.split_row` 에 물어본다')
    import doc_line_length_gate as D
    hdr = '| 필드값 | GOLD 매핑 | 판정 | 왜 안 되는가 |'
    n_hdr = len(D.split_row(hdr))
    check(n_hdr == want,
          '축5-a', '게이트 파서와 이 테스트의 헤더 열수가 같다(%d)' % n_hdr)
    for v in CASES:
        row = '| 기준일시 | %s | ⛔ 원천부재 | 사유 |' % G.code_cell(v, 60)
        n = len(D.split_row(row))
        check(n == n_hdr,
              '축5-b', '게이트 판정 열수 %d = 헤더 %d · %r' % (n, n_hdr, str(v)[:24]))
    # 🔴 음성 = 종전 구현 행을 게이트에 물으면 **실제로 열수가 무너진다**(모사 아님).
    legacy_row2 = '| 기준일시 | %s | ⛔ 원천부재 | 사유 |' % ('`%s`' % REAL[:60])
    n_bad = len(D.split_row(legacy_row2))
    check(n_bad != n_hdr,
          '축5-c', '🔴 종전 구현 행은 **게이트 파서에서** 열수 %d(헤더 %d) ⇒ 실사고 그대로다'
          % (n_bad, n_hdr))
    check(n_bad == 2,
          '축5-d', '무너진 값이 실측 기록(열수 2)과 일치한다 · 실제 %d' % n_bad)

    print('\n[결과] 단정 %d건 · 실패 %d건' % (N[0], len(FAILS)))
    if FAILS:
        for f in FAILS:
            print('  🔴 %s' % f)
        print('🔴 FAIL')
        return 1
    print('🟢 PASS — %d단정 전건 통과' % N[0])
    return 0


if __name__ == '__main__':
    sys.exit(main())
