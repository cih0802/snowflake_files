#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_gen_unresolved_issue_summary.py — `gen_unresolved_issue_summary.py` 음성 테스트
# Co-authored with CoCo

[2026-08-30 O124 신설 · `R3-2` 집행 · 지침 「게이트·생성기를 새로 만들면 음성 테스트를 같이 만든다」]

🔴 왜 필요한가
--------------------------------------------------------------------------
이 생성기의 위험은 **분모**다. 정상 입력만 돌리면 「42건」이 나오고 그것이 맞는지 알 수 없다.
그래서 **판정식마다 오탐 축과 재현율 축을 쌍으로** 단정한다:
  ㉠ **재현율 축** = 실제 항목 형태(`A-7` · `F-1` · `M-1-B` · `N-6-C` · `#81` · 이모지 접두)를 잡는가.
  ㉡ **오탐 축** = 항목이 아닌 제목(`## 1. 개요` · `## 배경`)을 항목으로 세지 않는가.
  ㉢ **상태 우선순위** = 「🔴 최우선」이 「🔴 회신 대기」보다 먼저 매칭되는가(순서 의존 버그 방어).
  ㉣ **닫힌 것을 버리지 않는가** = `🟢 해소`·`❌ 철회`가 **결과에 남는가**(`O111 ㉢` 관측축 보존).
     🔴 이 축이 없으면 「필터로 지워 건수를 예쁘게 만들기」가 통과한다.
  ㉤ **정본 손상 0** = `--write` 없이 호출하면 파일을 쓰지 않는가.

사용
--------------------------------------------------------------------------
    python3 scripts/test_gen_unresolved_issue_summary.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import gen_unresolved_issue_summary as G  # noqa: E402

FAILS = []
N = [0]


def check(cond, axis, msg):
    N[0] += 1
    print('  %s %s — %s' % ('🟢' if cond else '🔴', axis, msg))
    if not cond:
        FAILS.append('%s: %s' % (axis, msg))


def ids_of(titles):
    """제목 목록에서 이 생성기가 항목으로 인식하는 ID 를 뽑는다(추출 로직과 동일 경로)."""
    out = []
    for t in titles:
        bare = G.DECO.sub('', t)
        m = G.ITEM_ID.match(bare)
        out.append(m.group(0) if m else None)
    return out


def main():
    print('[test_gen_unresolved_issue_summary]')

    # ── 축1: 재현율 — 실제 항목 형태를 전건 인식한다 ────────────────────
    print('\n축1 — 재현율: 실제 항목 ID 형태를 인식한다')
    real = [
        'A-7/O5. 어의 확인',
        'F-1. 신규본부 / 신규지부 — 축이 없습니다 🔴',
        'M-1-B. 🔴 **[2026-08-11 O59-R 확장] 라벨이 갈려 있습니다**',
        'N-6-C. GOLD 설계 변경 범위',
        '#81. 미납클릭 인정 여부',
        'AD-2. `CRM_DEV_CNT` 가 소수값인 이유 🔵',
        '🟢 **N-6. [2026-08-13 O71 실측] 라이브 대조**',      # ← 이모지·`**` 접두
    ]
    want = ['A-7', 'F-1', 'M-1-B', 'N-6-C', '#81', 'AD-2', 'N-6']
    got = ids_of(real)
    for w, g, t in zip(want, got, real):
        check(g == w, '축1-a', '%r → %r (기대 %r)' % (t[:34], g, w))

    # ── 축2: 오탐 — 항목이 아닌 제목을 세지 않는다 ──────────────────────
    print('\n축2 — 오탐: 항목이 아닌 제목은 세지 않는다')
    noise = [
        '1. 개요',
        '배경',
        '0. 결론 한 줄',
        '문서 계보',
        '재생성',
        '2026-08-30 측정',                 # 숫자 시작 — ID 가 아니다
    ]
    for t, g in zip(noise, ids_of(noise)):
        check(g is None, '축2-a', '항목으로 세지 않는다: %r' % t[:30])

    # ── 축3: 상태 판정 우선순위 (순서 의존 버그 방어) ────────────────────
    print('\n축3 — 상태: 「최우선」이 일반 🔴 보다 먼저 매칭된다')
    check(G.status_of('F-3. 발송 오픈 🔴 **최우선**') == '🔴 최우선',
          '축3-a', '🔴 + 최우선 → `🔴 최우선`')
    check(G.status_of('F-4. 산출식 🔴') == '🔴 회신 대기',
          '축3-b', '🔴 단독 → `🔴 회신 대기`')
    check(G.status_of('M-3. 출처 표기만 미확정 🟢') == '🟢 해소',
          '축3-c', '🟢 → `🟢 해소`')
    check(G.status_of('N-6-B. ❌ **철회**') == '❌ 철회',
          '축3-d', '❌ → `❌ 철회`(🟢 보다 먼저 판정된다)')
    check(G.status_of('H-1. 무엇을 바로잡았는지') == '⚪ 표기 없음',
          '축3-e', '표기가 없으면 창작하지 않는다')
    # 🔴 오탐 축 = 🟢 와 ❌ 가 같은 제목에 있으면 「철회」가 이긴다(강한 신호 우선).
    check(G.status_of('🟢 ❌ 철회했다') == '❌ 철회',
          '축3-f', '두 표기가 겹치면 `❌ 철회` 가 이긴다(우선순위 고정)')

    # ── 축4: 서술/질의 구분 ─────────────────────────────────────────────
    print('\n축4 — 종류: 경위·참고 절을 「질의」로 세지 않는다')
    for t in ('H-1. 무엇을 바로잡았는지', 'I-1. 무엇을 발견했는지',
              'I-3. 왜 저희가 스스로 확정할 수 없는지', 'K-3. 참고 — 함께 확정되어야 하는 것',
              'N-5. 내부 파급 (현업 회신 불요 · 우리 소관 기록)'):
        check(bool(G.NARRATIVE.search(t)), '축4-a', '서술로 분류: %r' % t[:32])
    for t in ('H-3. 질문', 'F-3. 발송 오픈 — C-9 폐기 결정을 되돌려야 합니까?',
              'M-2. 코드군을 찾을 수 없습니다'):
        check(not G.NARRATIVE.search(t), '축4-b', '질의로 분류: %r' % t[:32])

    # ── 축5: 🔴🔴 닫힌 것을 버리지 않는다 (관측축 보존 · O111 ㉢) ─────────
    print('\n축5 — 🔴 닫힌 항목이 결과에서 사라지지 않는다')
    items = G.field_items()
    check(len(items) > 0, '축5-a', '정본에서 항목을 실제로 추출한다 · %d건' % len(items))
    stat = {}
    for it in items:
        stat[it['status']] = stat.get(it['status'], 0) + 1
    check('🟢 해소' in stat,
          '축5-b', '🔴 `🟢 해소` 항목이 결과에 남아 있다 · %d건' % stat.get('🟢 해소', 0))
    check('❌ 철회' in stat,
          '축5-c', '🔴 `❌ 철회` 항목이 결과에 남아 있다 · %d건' % stat.get('❌ 철회', 0))
    check(all(it['where'] and ':' in it['where'] for it in items),
          '축5-d', '전건이 `파일:행` 좌표를 갖는다(색인의 유일한 가치)')
    check(len({it['where'] for it in items}) == len(items),
          '축5-e', '좌표 중복 0 — 같은 절을 두 번 세지 않는다')

    # ── 축6: 출력 계약 ──────────────────────────────────────────────────
    print('\n축6 — 출력 계약: 분모 선언 + 자동 생성물 경고 + 인용 금지 문구')
    text, nf, nd, nt = G.build()
    for token in ('## 0. 분모 선언', '이 파일은 자동 생성물이다',
                  '판정·수치를 인용하려면', '`O111 ㉠`'):
        check(token in text, '축6-a', '출력에 계약 문구가 있다: %r' % token)
    check(('현업 **%d**' % nf) in text,
          '축6-b', '축별 합계가 본문 수치와 일치한다(현업 %d)' % nf)
    check(nd > 0 and nt > 0, '축6-c', 'dbt %d · 착수표 %d 축도 비어 있지 않다' % (nd, nt))
    check(max(len(l) for l in text.split('\n')) <= 2000,
          '축6-d', '한 줄 2000자 초과 0 (`R1-5-1`)')

    # ── 축7: 🔴 미리보기는 파일을 쓰지 않는다 ────────────────────────────
    print('\n축7 — 음성: `build()` 는 파일을 쓰지 않는다')
    before = os.path.getmtime(G.OUT) if os.path.exists(G.OUT) else None
    G.build()
    after = os.path.getmtime(G.OUT) if os.path.exists(G.OUT) else None
    check(before == after, '축7-a', '`build()` 호출로 산출물 mtime 이 바뀌지 않는다')

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
