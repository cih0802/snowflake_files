#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_rename_stale_gate.py — `rename_stale_gate.py` 음성 테스트.

[2026-09-10 O155 신설 · `R3-2` = 게이트를 만들면 음성 테스트를 같이 만든다]

🔴 왜 음성 테스트인가
--------------------------------------------------------------------------
「고친 뒤 통과」는 증거가 아니다. **고치기 전 코드에서 반드시 실패하는 축**이 있어야
그 게이트가 결함을 본다는 증거가 된다(11번 문서 §성공 판정식).

이 파일은 게이트가 **놓쳤던 실물 4종**을 회귀 축으로 고정한다:
* 축2 `(구 FACT_SERVICE_EVENT)` 병기 = **통과해야 한다**(O155 1차 판정식이 오탐한 형태).
* 축3 `FACT_TARGET_MEMBER_DEV` = `FACT_TARGET_DEV` 의 **부분문자열이 아니다**(경계 오탐).
* 축4 파일·라이브가 **똑같이 틀린** 경우 = `comment_drift_gate` 는 🟢 인데 이 게이트는 잡는다.
* 축6 기준선 **증가**는 FAIL · **감소**는 통과(해소 진척을 막지 않는다).
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

import rename_stale_gate as G  # noqa: E402

PASS, FAIL = [], []


def check(axis, cond, detail=''):
    (PASS if cond else FAIL).append(axis)
    sys.stdout.write('  %s %s%s\n' % ('🟢' if cond else '🔴', axis,
                                      (' — ' + detail) if detail else ''))


def main():
    sys.stdout.write('=' * 62 + '\n')
    sys.stdout.write('test_rename_stale_gate.py — 개명 잔여 게이트 음성 테스트\n')
    sys.stdout.write('=' * 62 + '\n\n')

    # ── 축1 무자격 잔여는 반드시 잡힌다 ────────────────────────────────
    line = '개발 사건 건수는 `FACT_MEMBER_LIFECYCLE` 를 쓴다.'
    m = G.RX.search(line)
    check('축1 무자격 옛 이름 검출',
          m is not None and not G.qualified(line, m.start()),
          '검출=%s' % (m.group(1) if m else None))

    # ── 축2 병기는 통과한다(O155 1차 판정식이 여기서 오탐했다) ──────────
    quals = [
        'GOLD.FACT_MESSAGE_DISPATCH(구 FACT_SERVICE_EVENT)가 죽었다.',
        '`DIM_MEMBER`(구 DIM_MEMBER_CURRENT)를 테이블로 신설하고',
        '| `FACT_TARGET_DEV` | **`FACT_TARGET_MEMBER_DEV`** | 개명 사유 |',
    ]
    okc = 0
    for q in quals:
        mm = G.RX.search(q)
        if mm and G.qualified(q, mm.start()):
            okc += 1
    check('축2 병기 3형태 전건 통과(오탐 0)', okc == len(quals),
          '통과 %d/%d' % (okc, len(quals)))

    # ── 축3 경계 — 개명 후 이름이 옛 이름으로 잡히면 안 된다 ────────────
    news = ['FACT_TARGET_MEMBER_DEV', 'FACT_MEMBER_DEV_ACHIEVEMENT',
            'FACT_MEMBER_SPONSORSHIP_SPAN', 'FACT_EVENT_ATTENDANCE',
            'FACT_MESSAGE_DISPATCH', 'FACT_MEMBER_EVENT', 'DIM_MEMBER']
    leak = [n for n in news if G.RX.search(n)]
    check('축3 개명 후 이름 오탐 0', not leak, '오탐=%s' % (leak or '없음'))

    # ── 축4 파일·라이브 동시 오류 시나리오 = 드리프트 0 인데 이 게이트는 잡는다 ─
    same = "COMMENT = 'Phase-1 회원 상태전이 SV (base: GOLD.FACT_MEMBER_LIFECYCLE)'"
    mm = G.RX.search(same)
    check('축4 드리프트 0 이어도 검출(SV COMMENT 실물)',
          mm is not None and not G.qualified(same, mm.start()),
          'O155 가 이 형태를 라이브에서 적발했다')

    # ── 축5 버킷 분류 — 이력·근거철·생성물이 축1에 섞이지 않는다 ─────────
    cases = [
        ('20_issue/01_세션이력_조각/01_세션이력-004.md', 'HIST'),
        ('99_NEXT_SESSION_조각/99_NEXT_SESSION-030.md', 'HIST'),
        ('20_issue/_o154_evidence.md', 'HIST'),
        ('30_output_share/02_gold 스키마 컬럼 인벤토리_20260904.csv', 'GEN'),
        ('20_issue/00_BRIEF.md', 'GEN'),
        ('30_output_share/01_DW_현업활용가이드.md', 'LIVE'),
        ('10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_FEE.sql', 'LIVE'),
    ]
    wrong = [(r, G.bucket(r), exp) for r, exp in cases if G.bucket(r) != exp]
    check('축5 버킷 분류 7건 전건 일치', not wrong, '오분류=%s' % (wrong or '없음'))

    # ── 축6 기준선 증감 판정 — 증가는 FAIL · 감소는 통과 ────────────────
    tmp = tempfile.mkdtemp(prefix='o155g_')
    try:
        real = G.BASELINE
        fake = os.path.join(tmp, 'baseline.json')
        cur = G.scan()[0]['LIVE']
        # 증가 시나리오 = 기준선을 현재보다 낮게 둔다.
        with io.open(fake, 'w', encoding='utf-8') as fh:
            json.dump({'axis1_total': max(0, len(cur) - 5), 'per_file': {}}, fh)
        G.BASELINE = fake
        rc_up = _run_main()
        # 감소 시나리오 = 기준선을 현재보다 높게 둔다.
        with io.open(fake, 'w', encoding='utf-8') as fh:
            json.dump({'axis1_total': len(cur) + 5, 'per_file': {}}, fh)
        rc_down = _run_main()
        G.BASELINE = real
        check('축6 증가=FAIL · 감소=통과', rc_up == 1 and rc_down == 0,
              'rc 증가=%s · 감소=%s' % (rc_up, rc_down))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # ── 축7 기준선 부재 = FAIL(조용히 통과하지 않는다) ──────────────────
    tmp2 = tempfile.mkdtemp(prefix='o155h_')
    try:
        real = G.BASELINE
        G.BASELINE = os.path.join(tmp2, 'nope.json')
        rc_none = _run_main()
        G.BASELINE = real
        check('축7 기준선 부재 = FAIL', rc_none == 1, 'rc=%s' % rc_none)
    finally:
        shutil.rmtree(tmp2, ignore_errors=True)

    # ── 축8 CLI 무인자 실행이 rc 0/1 만 낸다(크래시 금지) ────────────────
    p = subprocess.run([sys.executable, os.path.join(ROOT, 'scripts',
                                                     'rename_stale_gate.py')],
                       cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    check('축8 CLI 크래시 0', p.returncode in (0, 1), 'rc=%d' % p.returncode)

    sys.stdout.write('\n' + '-' * 62 + '\n')
    if FAIL:
        sys.stdout.write('🔴 축 %d개 · 통과 %d · 실패 %d\n'
                         % (len(PASS) + len(FAIL), len(PASS), len(FAIL)))
        for f in FAIL:
            sys.stdout.write('   🔴 %s\n' % f)
        return 1
    sys.stdout.write('🟢 축 %d개 전건 통과\n' % len(PASS))
    return 0


def _run_main():
    """게이트 `main()` 을 인자 없이 돌려 rc 만 받는다(출력은 버린다)."""
    argv, out = sys.argv, sys.stdout
    sys.argv = ['rename_stale_gate.py']
    sys.stdout = io.StringIO()
    try:
        return G.main()
    finally:
        sys.argv, sys.stdout = argv, out


if __name__ == '__main__':
    sys.exit(main())
