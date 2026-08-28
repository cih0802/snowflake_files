#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_session_brief.py — `session_brief.py` 추출기의 **음성 테스트**.

[2026-08-28 O106 신설 · `R3-2` 의 집행]

🔴 왜 음성 테스트인가
--------------------------------------------------------------------------
`R3-2` = *"새로 만든 게이트를 **실패 케이스**로 음성 테스트했는가? 통과만 보면
그 게이트가 무엇을 **못 잡는지** 모른다."*
O106 이 이 도구를 만들며 실제로 **두 번** 틀렸다:
  · 착수표 추출이 「4열 이상 표 행」을 전부 먹어 허브 조각 목차까지 실렸다.
  · stale 대조가 「같은 줄 문서명 1개」만 봐서 17건 중 13건만 잡았다.
⇒ 정상 입력만 돌려서는 **둘 다 발견되지 않았다.** 합성 입력으로 경계를 고정한다.

실행
--------------------------------------------------------------------------
    python3 scripts/test_session_brief.py        # 전건 통과해야 exit 0
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import session_brief as sb                                   # noqa: E402

FAILS = []


def check(name, got, want):
    if got == want:
        print('  ✅ %s' % name)
    else:
        print('  🔴 %s — got=%r want=%r' % (name, got, want))
        FAILS.append(name)


def L(text):
    """합성 입력을 `family_lines` 형식으로 만든다."""
    return [('SYNTH.md', i, ln) for i, ln in enumerate(text.split('\n'), 1)]


# ── 축 1: 착수표 — 취소선 = 완료 ────────────────────────────────────────
TASKS = """
| 순 | 작업 | 정지점 | 왜 이 순서인가 |
|---|---|---|---|
| ~~①~~ | ~~끝난 일~~ | — | ✅ 완료 |
| **②** | 🔴 열린 일 | 없음 | 이유 |
| ~~③~~ | ✅ **[O99 완료]** 다른 끝난 일 | — | 이유 |
| **④** | 🟠 또 열린 일 | 🔴 승인 필요 | 이유 |
"""

# ── 축 2: 다른 표는 착수표가 아니다(헤더 서명 한정) ─────────────────────
NOT_TASKS = """
| 조각 | 구 행범위 | 줄 | KB | 선두 절 |
|---|---|---|---|---|
| `x-001.md` | 1~155 | 155 | 16.0 | 아무 절 |
| `x-002.md` | 156~310 | 155 | 13.7 | 다른 절 |

| # | 결함 | 조문 | 비고 |
|---|---|---|---|
| ㉠ | 뭔가 틀렸다 | R2-8 | — |
"""

# ── 축 3: 절 상태 이모지 ────────────────────────────────────────────────
SECTIONS = """
## 🟢 O91 — 끝난 절
본문
## 🔴🔴 O88-C — 열린 절
본문
## ✅ O70 — 닫힌 절
본문
## 🟠 O99 — 부분 미결
본문
## 제목만 있고 이모지 없는 절
본문
"""

# ── 축 4: 「여기서 시작한다」 적층 — 취소선 아닌 것 중 최신 ──────────────
HANDOFF = """
## 0-AAA. 🔴 [2026-08-19 O88 필독 — **여기서 시작한다.**]
### ▣ 옛 항목
## 0-BBB. 🔴 [2026-08-20 O91 필독 — ~~여기서 시작한다~~ ⇒ 위 절이 먼저다]
### ▣ 승계된 항목
## 0-CCC. 🔴 [2026-08-28 O105 필독 — **여기서 시작한다.**]
### ▣ 최신 항목 하나
### ▣ 최신 항목 둘
"""


def main():
    print('[음성 테스트] session_brief 추출기')

    print(' 축1 착수표 — 취소선·✅ 는 완료로 제외')
    t = sb.open_tasks(L(TASKS))
    check('열린 행 수', len(t), 2)
    check('열린 순번', [x['order'] for x in t], ['②', '④'])
    check('정지점 추출', t[1]['stop'], '🔴 승인 필요')

    print(' 축2 헤더 서명 한정 — 조각목차·결함표는 착수표가 아니다')
    check('비착수표 0건', len(sb.open_tasks(L(NOT_TASKS))), 0)
    check('혼합 입력도 착수표만', len(sb.open_tasks(L(NOT_TASKS + TASKS))), 2)

    print(' 축3 절 상태 — 🟢/✅ 제외 · 무표기 제외')
    s = sb.open_sections('x', L(SECTIONS))
    check('열린 절 수', len(s), 2)
    check('열린 절 선두', s[0]['title'].startswith('🔴🔴 O88-C'), True)

    print(' 축4 인수인계 — 취소선 아닌 것 중 최신 날짜')
    cur, subs = sb.current_handoff(L(HANDOFF))
    check('현행 절 날짜', cur['date'], '2026-08-28')
    check('현행 절 O105', 'O105' in cur['title'], True)
    check('현행 절 하위 항목 수', len(subs), 2)

    print(' 축5 빈 입력 — 예외 없이 0건')
    check('빈 착수표', len(sb.open_tasks(L(''))), 0)
    check('빈 절', len(sb.open_sections('x', L(''))), 0)
    check('빈 인수인계', sb.current_handoff(L(''))[0], None)

    print(' 축6 게이트 판정 열 — 힌트 줄이 아니라 판정 줄을 본다 (O109 D5)')
    # 🔴 실제 출력 형태를 그대로 쓴다(창작 금지). 종전 구현은 아래 두 건을 반대로 표시했다.
    typ = ['[문서 유형 게이트] …', '🟡 통과(경고 1건)',
           ' - 여유 부족 1건 — 갱신형은 `--rebalance`, 은퇴 가능하면 `retire_rows.py`']
    cla = ['[조문 번호 순서 게이트] 문서 3종',
           '✅ 게이트 통과 — 조문 93개 · 역전 0 · 중복 0 (경고 0건)']
    crd = ['[문서 좌표 실재 게이트] 스캔 165파일',
           '✅ 게이트 통과 — 경로가 깨진 좌표 0건 (경고 9건은 사람 판단)']
    check('판정 줄 선택(힌트 줄 배제)', sb.gate_verdict(typ), '🟡 통과(경고 1건)')
    check('경고 있는 통과 = 🟡', sb.gate_mark(0, sb.gate_verdict(typ)), '🟡')
    check('경고 0건은 ✅', sb.gate_mark(0, sb.gate_verdict(cla)), '✅')
    check('경고 9건은 🟡', sb.gate_mark(0, sb.gate_verdict(crd)), '🟡')
    check('rc≠0 은 🔴', sb.gate_mark(1, '✅ 게이트 통과 — 0건'), '🔴')
    check('판정 줄 부재 시 마지막 줄', sb.gate_verdict(['[머리말]', '본문뿐']), '본문뿐')

    print('')
    if FAILS:
        print('🔴 실패 %d건: %s' % (len(FAILS), ', '.join(FAILS)))
        return 1
    print('✅ 전건 통과 — 6축 %d개 단정' % 18)
    return 0


if __name__ == '__main__':
    sys.exit(main())
