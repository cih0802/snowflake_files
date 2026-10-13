#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_split_doc_dryrun.py — `--dry-run` 이 **아무것도 쓰지 않는지** 음성 테스트 (3축)

[2026-10-13 O218 신설 · `R3-2` 집행]

🔴 왜 이 테스트가 필요한가
--------------------------------------------------------------------------
O217-B 가 `split_doc.py <원장> --rebalance --dry-run` 을 돌렸는데 **18조각이 실제로 재기록**됐다.
원인 = `main()` 이 `--rebalance` 분기에 `a.dry_run` 을 넘기지 않았고 `rebalance()` 에 그 인자가 없었다.
⇒ 함수 단위 테스트(`test_split_doc_expect.py`)는 이 결함을 원리적으로 못 본다 —
   **CLI 라우팅**을 거쳐야 재현된다. 이 파일은 `main()` 을 argv 로 직접 호출한다.

사용
--------------------------------------------------------------------------
    python3 scripts/test_split_doc_dryrun.py
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


def tree(root):
    """경로 → (크기, 내용) — 한 바이트라도 바뀌면 다르다."""
    out = {}
    for d, _, fs in os.walk(root):
        for f in fs:
            p = os.path.join(d, f)
            with io.open(p, 'rb') as fh:
                out[os.path.relpath(p, root)] = fh.read()
    return out


def run_main(argv):
    old = sys.argv
    sys.argv = ['split_doc.py'] + argv
    try:
        return S.main()
    finally:
        sys.argv = old


def main():
    print('[test_split_doc_dryrun]')
    tmp = tempfile.mkdtemp(prefix='dryrun_')
    old_root, old_arch = S.ROOT, S.ARCHIVE
    try:
        S.ROOT = tmp
        S.ARCHIVE = os.path.join(tmp, '_archive')
        hub = os.path.join(tmp, '30_설계_의사결정.md')
        outdir = '30_설계_의사결정_조각'
        for n in (1, 2):
            body = '\n'.join(['## §%d 절' % n, '내용 %d' % n] + ['줄%d' % i for i in range(40)])
            head = S.chunk_header(hub, n, 2, 0, 40)
            w(os.path.join(tmp, outdir, '30_설계_의사결정-%03d.md' % n),
              '\n'.join(head) + '\n' + body + '\n')
        w(hub, '<!-- SPLIT-OUTDIR: %s -->\n<!-- SPLIT-BOUNDARY: section -->\n# 허브\n' % outdir)

        # ── 축1: 🔴 O217-B 재현 — CLI `--rebalance --dry-run` ──────────────
        print('\n축1 — `--rebalance --dry-run` 은 파일을 한 바이트도 쓰지 않는다')
        before = tree(tmp)
        rc = run_main([hub, '--rebalance', '--dry-run', '--label', 'TEST'])
        after = tree(tmp)
        check(rc == 0, '축1-a', 'rc 0 · 실제 rc=%s' % rc)
        check(after == before, '축1-b', '🔴 조각·허브 내용 불변(O217-B 피해 = 18조각 재기록)')
        check(not os.path.isdir(S.ARCHIVE), '축1-c', '스냅샷도 만들지 않는다')

        # ── 축2: 지원하지 않는 연산은 조용히 쓰지 말고 거부 ─────────────────
        print('\n축2 — `--republish --dry-run` · `--rollover --dry-run` 은 거부(rc 2) · 무쓰기')
        for flag in ('--republish', '--rollover'):
            rc = run_main([hub, flag, '--dry-run', '--label', 'TEST'])
            check(rc == 2 and tree(tmp) == before, '축2%s' % flag, 'rc=%s · 무쓰기=%s'
                  % (rc, tree(tmp) == before))

        # ── 축3: 대조군 — dry-run 없이는 정상 수행(가드가 작업을 막지 않는다) ──
        print('\n축3 — 대조군: `--rebalance` 단독은 정상 집행')
        rc = run_main([hub, '--rebalance', '--label', 'TEST'])
        check(rc == 0, '축3-a', 'rc 0 · 실제 rc=%s' % rc)
        check(os.path.isdir(S.ARCHIVE) and os.listdir(S.ARCHIVE), '축3-b', '스냅샷이 생겼다(실집행 증거)')
    finally:
        S.ROOT, S.ARCHIVE = old_root, old_arch
        shutil.rmtree(tmp, ignore_errors=True)

    print('\n[결과] 단정 %d건 · 실패 %d건' % (N[0], len(FAILS)))
    if FAILS:
        for f in FAILS:
            print('  🔴 %s' % f)
        print('🔴 FAIL')
        return 1
    print('🟢 PASS — 3축 %d단정 전건 통과' % N[0])
    return 0


if __name__ == '__main__':
    sys.exit(main())
