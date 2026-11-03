#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_split_doc_expect.py — `--expect` 신선도·영속성 가드 음성 테스트 (5축)

[2026-08-28 O111-B 신설 · `R3-2` 집행 · `R1-6-23` 의 검증 장치]

🔴 왜 이 테스트가 필요한가 — **이 가드는 「사고를 재현해야만」 검증된다.**
--------------------------------------------------------------------------
가드가 막아야 하는 두 사고는 정상 경로에서 **절대 나타나지 않는다**:
  ㉠ **O107** = `--rebalance` 가 **낡은 내용**을 읽어 전 조각을 그것으로 재기록 ⇒ 편집 소실
  ㉡ **O111** = `--republish` 직후에는 있던 행이 나중에 보니 **없다** ⇒ 조용한 소실
🔴 두 번 다 **게이트 6종이 전부 🟢** 였다(`verify()` 는 자기일관성만 보고,
   `R1-7-2` 는 같은 시점 2회 읽기만 본다) ⇒ **이 축은 게이트가 원리적으로 못 본다.**
⇒ 이 파일은 두 사고를 **주입**해서 가드가 실제로 **쓰기를 막는지**를 단정한다.
   🔴 「가드를 넣었다」는 것과 「가드가 막는다」는 것은 다르다.

사용
--------------------------------------------------------------------------
    python3 scripts/test_split_doc_expect.py
"""

import io
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import split_doc as S  # noqa: E402

FAILS = []
N = [0]


def check(cond, axis, msg):
    N[0] += 1
    print('  %s %s — %s' % ('🟢' if cond else '🔴', axis, msg))
    if not cond:
        FAILS.append('%s: %s' % (axis, msg))


def w(path, text):
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(path, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)


def r(path):
    with io.open(path, encoding='utf-8') as fh:
        return fh.read()


def main():
    print('[test_split_doc_expect]')

    # ── 축1: 순수 함수 — 신선도 가드 ────────────────────────────────────
    print('\n축1 — `expect_guard` 판정')
    check(S.expect_guard('t', '본문에 TOKEN_A 있다', ['TOKEN_A']) == 0,
          '축1-a', '토큰이 있으면 통과(rc 0)')
    check(S.expect_guard('t', '본문에 없다', ['TOKEN_A']) == 1,
          '축1-b', '토큰이 없으면 **차단**(rc 1) — O107 형을 막는 지점')
    check(S.expect_guard('t', '아무거나', None) == 0,
          '축1-c', '`--expect` 미지정이면 검사 대상이 없다(rc 0) · 🔴 그래서 조문이 의무화한다')
    check(S.expect_guard('t', 'A 만 있다', ['A', 'B']) == 1,
          '축1-d', '여러 토큰 중 하나만 없어도 차단(부분 통과 금지)')

    tmp = tempfile.mkdtemp(prefix='expect_')
    try:
        # ── 축2: 순수 함수 — 영속성 가드 ────────────────────────────────
        print('\n축2 — `persist_guard` 판정 (디스크 되읽기)')
        p1 = os.path.join(tmp, 'a.md')
        w(p1, '살아 있는 TOKEN_LIVE\n')
        check(S.persist_guard('t', [p1], ['TOKEN_LIVE']) == 0,
              '축2-a', '디스크에 있으면 통과')
        check(S.persist_guard('t', [p1], ['TOKEN_GONE']) == 1,
              '축2-b', '디스크에 없으면 **차단** — O111 형(쓰기 미반영·타 주체 덮음)을 잡는 지점')
        check(S.persist_guard('t', [os.path.join(tmp, 'nope.md')], ['X']) == 1,
              '축2-c', '파일 자체가 없으면 차단(부재를 통과로 읽지 않는다)')

        # ── 축3: 🔴🔴 O107 재현 — `--rebalance` 가 낡은 내용을 읽는 상황 ──
        print('\n축3 — O107 재현: 재균형이 낡은 내용을 읽으면 **쓰지 않고 중단**해야 한다')
        old_root = S.ROOT
        S.ROOT = tmp
        S.ARCHIVE = os.path.join(tmp, '_archive')
        hub = os.path.join(tmp, '30_설계_의사결정.md')
        outdir = '30_설계_의사결정_조각'
        body1 = '\n'.join(['## §A 절', '내용 1'] + ['줄%d' % i for i in range(40)])
        body2 = '\n'.join(['## §B 절', '내용 2'] + ['줄%d' % i for i in range(40)])
        for n, body in ((1, body1), (2, body2)):
            head = S.chunk_header(hub, n, 2, 0, 40)
            w(os.path.join(tmp, outdir, '30_설계_의사결정-%03d.md' % n),
              '\n'.join(head) + '\n' + body + '\n')
        w(hub, '<!-- SPLIT-OUTDIR: %s -->\n<!-- SPLIT-BOUNDARY: section -->\n# 허브\n' % outdir)

        before = {n: r(os.path.join(tmp, outdir, '30_설계_의사결정-%03d.md' % n))
                  for n in (1, 2)}
        rc = S.rebalance(hub, 'section', 0.7, snap_label='TEST',
                         expect=['이_토큰은_조각에_없다'])
        check(rc == 1, '축3-a', '없는 토큰을 기대하면 재균형이 **FAIL**(rc 1) · 실제 rc=%s' % rc)
        same = all(r(os.path.join(tmp, outdir, '30_설계_의사결정-%03d.md' % n)) == before[n]
                   for n in (1, 2))
        check(same, '축3-b', '🔴 FAIL 시 **조각을 한 바이트도 쓰지 않았다**(O107 의 피해가 이것이었다)')
        check(not os.path.isdir(S.ARCHIVE) or not os.listdir(S.ARCHIVE),
              '축3-c', '차단이 스냅샷보다 **먼저** 일어난다(불필요한 스냅샷 0)')

        # 🟢 대조군(재현율) — 실재하는 토큰이면 정상 수행돼야 한다.
        print('     ↳ 대조군: 실재 토큰이면 재균형이 정상 수행돼야 한다')
        rc2 = S.rebalance(hub, 'section', 0.7, snap_label='TEST', expect=['내용 1', '내용 2'])
        check(rc2 == 0, '축3-d', '실재 토큰이면 통과(rc 0) — 가드가 정상 작업을 막지 않는다 · rc=%s' % rc2)
        after = '\n'.join(r(os.path.join(tmp, outdir, f))
                          for f in sorted(os.listdir(os.path.join(tmp, outdir))))
        check('내용 1' in after and '내용 2' in after,
              '축3-e', '재기록 후에도 두 절의 본문이 살아 있다')

        # ── 축4: 🔴 O111 재현 — 쓴 뒤 내용이 사라지는 상황 ────────────────
        print('\n축4 — O111 재현: 쓴 뒤 되읽어 없으면 **FAIL 로 알린다**')
        #   실제 사고는 외부 주체가 덮은 것이라 재현이 불가하므로, 되읽기 대상 경로를
        #   비워서 **같은 관측**(쓴 뒤 토큰 부재)을 만든다.
        victim = os.path.join(tmp, outdir, '30_설계_의사결정-001.md')
        w(victim, '덮였다\n')
        check(S.persist_guard('rebalance', [victim], ['내용 1']) == 1,
              '축4-a', '재기록 대상이 덮이면 영속성 FAIL — **조용한 소실이 소리를 낸다**')

        # ── 축5: `--expect` 미지정이면 종전과 동일하게 동작한다(회귀) ──────
        print('\n축5 — `--expect` 미지정 = 종전 동작 유지(회귀 없음)')
        for n, body in ((1, body1), (2, body2)):
            head = S.chunk_header(hub, n, 2, 0, 40)
            w(os.path.join(tmp, outdir, '30_설계_의사결정-%03d.md' % n),
              '\n'.join(head) + '\n' + body + '\n')
        rc3 = S.rebalance(hub, 'section', 0.7, snap_label='TEST')
        check(rc3 == 0, '축5-a', '토큰 미지정이면 정상 수행(rc 0) · rc=%s' % rc3)
    finally:
        S.ROOT = old_root
        shutil.rmtree(tmp, ignore_errors=True)

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
