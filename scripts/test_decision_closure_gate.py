#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_decision_closure_gate.py — `decision_closure_gate.py` 음성 테스트

🔴 **축 수를 이 문단에 적지 마라**(`R3-9 ㉦`) — 테스트가 스스로 세어 출력한다.
   종전 판본이 「5축」을 적어 두었고 O124 가 축을 늘리자 그 문구가 즉시 stale 이 됐다.

[2026-08-28 O111-B 신설 · `R3-2` 집행 · **O111 이 남긴 부채를 같은 세션에서 갚는다**]
[2026-08-30 O124 확장 · 신설 제외 축 A~E 의 **오탐 축 + 재현율 축**을 쌍으로 단정]

🔴 왜 필요한가
--------------------------------------------------------------------------
O111 이 이 게이트에 **제외 규칙 `GENERATED_ID_LINE`** 을 넣었는데 음성 테스트를 만들지 않았다
(`R3-2` 확정위반 1건으로 자기신고했다). 제외 규칙은 **가장 위험한 종류의 변경**이다 —
`index_row_gate` 에서 이미 실증됐듯이 **제외를 넓히면 검출이 조용히 꺼지고 출력은 🟢 가 된다.**
⇒ `test_index_row_gate.py` 축4 와 **같은 형태**로 양방향을 단정한다:
  ㉠ **오탐 축** = 자동 생성 `- ID:` 줄은 인용처로 세지 않는다(고칠 자리가 없으므로).
  ㉡ **재현율 축** = 같은 ID 의 **실제 인용처(표 행·서술문)는 여전히 잡힌다.**
🔴 ㉡ 이 없으면 「제외를 `.*` 로 넓혀 전부 끄기」도 통과한다.

사용
--------------------------------------------------------------------------
    python3 scripts/test_decision_closure_gate.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import decision_closure_gate as G  # noqa: E402

FAILS = []
N = [0]


def check(cond, axis, msg):
    N[0] += 1
    print('  %s %s — %s' % ('🟢' if cond else '🔴', axis, msg))
    if not cond:
        FAILS.append('%s: %s' % (axis, msg))


def main():
    print('[test_decision_closure_gate]')

    # ── 축1: 자동 생성 `- ID:` 줄 판정 (O111 이 넣은 제외 규칙) ───────────
    print('\n축1 — `GENERATED_ID_LINE` 이 허브 「조각 선택표」 줄만 고른다')
    hits = [
        '- ID: BLOCKING-3 · O8 · O19 · DEC-7',
        '  - ID: DEC-13 · O8 · O10',
    ]
    for s in hits:
        check(bool(G.GENERATED_ID_LINE.match(s)),
              '축1-a', '자동 생성 줄로 인식: %r' % s[:36])
    # 🔴 오탐 축 = 사람이 쓴 줄을 삼키면 안 된다.
    misses = [
        '| ① | `O8` 행 갱신 | 미갱신 |',                 # 표 행
        '`O8` 은 여전히 미결이다',                        # 서술문
        '- ID 체계를 정리했다(`O8` 포함)',                # `ID:` 가 아니다
        '- IDS: O8',                                     # 유사하지만 다르다
        '결과 - ID: O8 을 인용했다',                      # 줄 **선두**가 아니다
    ]
    for s in misses:
        check(not G.GENERATED_ID_LINE.match(s),
              '축1-b', '사람이 쓴 줄은 제외하지 않는다: %r' % s[:36])

    # ── 축2: 종결 선언 추출 ──────────────────────────────────────────────
    print('\n축2 — `closed_targets` 가 종결 선언만 고른다')
    got = G.closed_targets(['`O8` 의 후원사업 축을 **종결**한다'])
    check('O8' in got, '축2-a', '종결 선언에서 대상 라벨을 뽑는다')
    check(not G.closed_targets(['`O8` 은 아직 닫지 않는다']),
          '축2-b', '부정문(`닫지 않`)은 종결로 읽지 않는다(`NEGATIVE`)')
    check('DEC-41' not in G.closed_targets(['`DEC-41` 로 `O8` 을 종결한다']),
          '축2-c', '결정 자신(`DEC-*`)은 대상이 아니다')
    check('O85' not in G.closed_targets(['`O8` 을 종결한다']),
          '축2-d', '`O8` 이 `O85` 로 번지지 않는다(뒤 숫자 배제)')

    # ── 축3: 🔴🔴 제외 규칙의 **양방향** (핵심 축) ────────────────────────
    print('\n축3 — 제외 규칙 양방향: 노이즈는 빼고 **실제 인용처는 남긴다**')
    old_files, old_excl = G._md_files, G.EXCLUDE_PREFIX
    import pathlib
    import tempfile
    tmp = tempfile.mkdtemp(prefix='dcg_')
    try:
        hub = pathlib.Path(tmp) / '00_INDEX_이슈원장.md'
        hub.write_text('\n'.join([
            '## 조각 목차',
            '- ID: BLOCKING-3 · O8 · O19',      # ← 자동 생성(제외 대상)
        ]) + '\n', encoding='utf-8')
        chunk = pathlib.Path(tmp) / '02_상태상세-001.md'
        chunk.write_text('\n'.join([
            '| 문서 | 좌표 | 상태 |',
            '| `20_현업확인-002.md` | `O8` 행 | 여전히 **미결** |',   # ← 표 행(잡혀야 한다)
            '`O8` 은 fan-out 검증 후로 적혀 있다',                    # ← 서술문(참고로 잡혀야 한다)
        ]) + '\n', encoding='utf-8')

        G._md_files = lambda prefix=None: [hub, chunk]
        G.EXCLUDE_PREFIX = ('01_세션이력',)
        hits = G.citations('O8')
        names = sorted(h[0] for h in hits)
        lines = [h[2] for h in hits]

        check(all('- ID:' not in l for l in lines),
              '축3-a', '🟢 오탐 축 = 자동 생성 `- ID:` 줄이 인용처에서 빠졌다')
        check('00_INDEX_이슈원장.md' not in names,
              '축3-b', '허브의 그 줄만이 유일한 `O8` 이면 허브가 분모에서 사라진다')
        check(any(l.lstrip().startswith('|') for l in lines),
              '축3-c', '🔴 재현율 축 = **표 행 인용처는 그대로 잡힌다**(제외가 검출을 끄지 않았다)')
        check(any(not l.lstrip().startswith('|') and 'O8' in l for l in lines),
              '축3-d', '🔴 재현율 축 = 서술문 인용처도 그대로 잡힌다')
        check(len(hits) == 2,
              '축3-e', '인용처 정확히 2건(표 행 1 + 서술문 1) · 실제 %d건' % len(hits))

        # ── 축4: 제외 문서(이력) 규칙이 살아 있는가 ──────────────────────
        print('\n축4 — `EXCLUDE_PREFIX`(append형 이력)는 분모에서 빠진다')
        hist = pathlib.Path(tmp) / '01_세션이력-001.md'
        hist.write_text('과거에 `O8` 을 이렇게 판정했다\n', encoding='utf-8')
        G._md_files = lambda prefix=None: [hub, chunk, hist]
        hits2 = G.citations('O8')
        check(all('01_세션이력' not in h[0] for h in hits2),
              '축4-a', '이력 문서는 인용처로 세지 않는다(`R1-3-6` 소급 수정 금지)')
        check(len(hits2) == 2, '축4-b', '이력 추가로 건수가 늘지 않는다 · %d건' % len(hits2))

        # ── 축5: 🔴 제외를 넓히면 재현율이 죽는다(이 테스트가 그것을 잡는가) ──
        print('\n축5 — 음성: 제외 규칙을 `.*` 로 넓히면 축3 재현율 단정이 깨져야 한다')
        import re as _re
        saved = G.GENERATED_ID_LINE
        G.GENERATED_ID_LINE = _re.compile(r'^.*$')      # ← 전부 제외(검출 끄기)
        try:
            hits3 = G.citations('O8')
        finally:
            G.GENERATED_ID_LINE = saved
        check(len(hits3) == 0,
              '축5-a', '제외를 전부로 넓히면 인용처가 0 이 된다 ⇒ **축3-c·d 가 이 실패를 잡는다**')
        check(len(G.citations('O8')) == 2,
              '축5-b', '원복 후 다시 2건(테스트가 전역 상태를 오염시키지 않는다)')

        # ── 축6: 🔴🔴 축A 괄호 스코프 — **오탐 축과 재현율 축을 함께** 단정 ────────
        print('\n축6 — 축A: 종결어와 라벨이 같은 괄호 스코프에 있어야 한다')
        # 🔴 실측 오탐 ㉠ = 종결어는 괄호 밖 · 세션 라벨은 괄호 안(날짜 스탬프).
        got = G.closed_targets(
            ['### 7-A. 🆕 **`DEC42` 결정 (2026-08-20 O96) — 연 grain 은 종결 · 월 grain 은 미결**'])
        check('O96' not in got,
              '축6-a', '오탐 축 = 괄호 안 날짜 스탬프 세션 라벨을 대상으로 뽑지 않는다')
        # 🔴 실측 오탐 ㉡ = 종결어는 괄호 **안**(다른 대상) · 라벨은 괄호 **밖**.
        got = G.closed_targets(
            ['> **거짓이었다.** `DEC42` 는 **O96 이 이미 사용**한 라벨이다'
             '(`FACT_BUDGET.PLAN_BUDGET_YEAR` 부분 종결 · 정본 `30-001 §7-A`)'])
        check('O96' not in got,
              '축6-b', '오탐 축 = 괄호 안의 종결어가 괄호 밖 라벨을 끌어오지 않는다')
        # 🔴🔴 재현율 축 = `DEC-41` 의 실제 종결 선언은 **그대로 잡혀야 한다**.
        got = G.closed_targets(
            ['> 🟢 이 절이 **정식 정본**이다. 이 결정으로 '
             '**`O8`(회원 다중후원 귀속 규칙)의 FMM 축이 닫힌다.**'])
        check('O8' in got,
              '축6-c', '🔴 재현율 축 = 괄호가 라벨 **직후**에 끼어도 진성 종결은 잡는다')
        check('O8' in G.closed_targets(['`O8`(주1)(주2)의 축이 닫혔다(2026-08-20 O92)']),
              '축6-d', '재현율 축 = 괄호 다중·중첩에도 같은 스코프 판정이 산다')
        check(G.paren_scopes('a(b(c))d')[0].strip().startswith('a'),
              '축6-e', '`paren_scopes` 가 괄호 밖 잔여를 첫 세그먼트로 낸다')

        # ── 축7: 축B — 미확정 절 + 표 행 종결어 ────────────────────────────
        print('\n축7 — 축B: 종결 선언은 확정된 절의 서술문이어야 한다')
        body = ['이 결정으로 `O8` 이 종결된다']
        check('O8' not in G.closed_targets(body, head='31. 🔴 결정 대기 — DEC-45: …'),
              '축7-a', '오탐 축 = `결정 대기` 절은 아무것도 닫지 않는다')
        check('O8' not in G.closed_targets(body, head='31. 🔴 결정 보류 — DEC-99'),
              '축7-b', '`결정 보류` 도 미확정으로 읽는다')
        check('O8' in G.closed_targets(body, head='28. ✅ 결정 — DEC-41: …'),
              '축7-c', '🔴 재현율 축 = 확정 절(`✅ 결정`)은 그대로 잡는다')
        check('O8' in G.closed_targets(body, head='30. 결정 전환 이력 — DEC-7'),
              '축7-d', '오탐 방지 = `결정 전환` 은 미확정이 아니다(제외를 넓히지 않았다)')
        check('O8' not in G.closed_targets(
                  ['| ② | 브릿지 정규화 | `O8` 센티넬 해소 경로가 열린다 | 신규 모델 1종 |']),
              '축7-e', '오탐 축 = 선택지 비교표의 **표 행**은 종결 선언이 아니다')
        check('O8' in G.closed_targets(['`O8` 의 FMM 축이 닫혔다']),
              '축7-f', '🔴 재현율 축 = 서술문 종결 선언은 그대로 잡는다')

        # ── 축8: 축C — 적발표 블록 ────────────────────────────────────────
        print('\n축8 — 축C: 「적발표」 자기선언 블록만 제외한다')
        lines = [
            '| 인용처 | 좌표 | 상태 |',
            '| `20_현업확인-002.md` | `:121` | 여전히 **미결** |',
            '| `90_해소완료_로그.md` | — | 이 표는 「적발표」이고 stale 정본이 아니다 ⇒ **오탐**이다 |',
            '',
            '| 진짜 stale 표 | 상태 |',
            '| `O8` 행 | 미갱신 |',
        ]
        marked = G.catch_table_lines(lines)
        check(marked == {1, 2, 3},
              '축8-a', '오탐 축 = 선언이 있는 블록 **전체**(1~3)만 제외 · 실제 %s' % sorted(marked))
        check(5 not in marked and 6 not in marked,
              '축8-b', '🔴 재현율 축 = 선언이 없는 다른 표는 그대로 남는다')
        check(G.catch_table_lines(['| 적발표 라는 말만 있는 표 |']) == set(),
              '축8-c', '「적발표」 단어만으로는 제외하지 않는다(두 조건 AND)')
        check(G.catch_table_lines(['| 오탐 이라는 말만 있는 표 |']) == set(),
              '축8-d', '「오탐」 단어만으로도 제외하지 않는다(두 조건 AND)')

        # ── 축9: 축E — 세션 근거철 ────────────────────────────────────────
        print('\n축9 — 축E: 세션 근거철은 인용처가 아니다(자기참조 루프 차단)')
        for name in ('_o124_evidence.md', '_o99_evidence.md'):
            check(bool(G.EVIDENCE_FILE.match(name)), '축9-a', '근거철로 인식: %s' % name)
        for name in ('o124_evidence.md', '_o124_notes.md', '_evidence_o124.md',
                     '00_INDEX_이슈원장.md'):
            check(not G.EVIDENCE_FILE.match(name),
                  '축9-b', '근거철이 아닌 것은 제외하지 않는다: %s' % name)

        # ── 축10: 축D — 허브 stem 판정 ────────────────────────────────────
        print('\n축10 — 축D: `<stem>_조각/` 이 있는 문서만 허브로 본다')
        hubs = G.hub_stems()
        check('00_INDEX_이슈원장' in hubs,
              '축10-a', '분할된 원장은 허브로 인식된다 · 허브 %d종' % len(hubs))
        check('32_컬럼개명표' not in hubs,
              '축10-b', '🔴 재현율 축 = 미분할 정본은 허브가 아니다(분모에 남는다)')
        check(all(not h.endswith('_조각') for h in hubs),
              '축10-c', 'stem 에서 `_조각` 접미가 벗겨져 있다')

        # ── 축11: 🔴 관측 축이 실제로 채워지는가 (제외를 조용히 버리지 않는다) ──
        print('\n축11 — 음성: 제외분이 `observed` 로 관측된다(O111 ㉢)')
        obs = []
        G.closed_targets(['이 결정으로 `O8` 이 종결된다'],
                         head='31. 🔴 결정 대기 — DEC-45', observed=obs)
        check(any(a == 'B1' for a, _, _ in obs),
              '축11-a', '축B1 제외가 관측 버킷에 남는다 · %d건' % len(obs))
        obs = []
        G.closed_targets(
            ['### 7-A. **`DEC42` 결정 (2026-08-20 O96) — 연 grain 은 종결**'], observed=obs)
        check(any(a == 'A' for a, _, _ in obs),
              '축11-b', '축A 제외가 관측 버킷에 남는다(버려지지 않는다)')
    finally:
        G._md_files, G.EXCLUDE_PREFIX = old_files, old_excl
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)

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
