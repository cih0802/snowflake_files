#!/usr/bin/env python3
"""`stage_mount_size_gate` 음성 테스트 — 오염 기반 + 역방향 오탐 + 초판 결함 회귀.

🔴 이 테스트의 계약 = **고치기 전 구현으로 돌리면 실패해야 한다.**
   축4 는 O167 초판이 실제로 낸 결함(`split('  ')` 로 0건)을 고정한다.
"""
import io
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stage_mount_size_gate as G  # noqa: E402

FAIL = []


def ok(cond, msg):
    if cond:
        print('  ✅', msg)
    else:
        print('  🔴', msg)
        FAIL.append(msg)


def axis1_formula():
    print('축1 패딩식 경계값')
    # 🔴 로컬이 16의 배수여도 한 블록을 더 붙인다 — 이 축이 「+16」을 고정한다.
    for local, exp in ((0, 16), (1, 16), (15, 16), (16, 32), (17, 32), (31, 32), (32, 48)):
        ok(G.expected(local) == exp, f'expected({local}) == {exp} (실제 {G.expected(local)})')


def axis2_tab_parser():
    print('축2 탭 파서 — 초판 결함(공백 분리 → 0건) 회귀 고정')
    sample = ('name\tsize\tmd5\tlast_modified\n'
              '/versions/live/a.md\t100\tdeadbeef\tTue, 15 Sep 2026 07:09:00 GMT\n'
              '/versions/live/dir/Untitled 3.sql\t48\tcafe\tTue, 15 Sep 2026 07:09:00 GMT\n'
              'noise line without prefix\n')

    class R:
        returncode = 0
        stdout = sample
        stderr = ''

    orig = G.subprocess.run
    G.subprocess.run = lambda *a, **k: R()
    try:
        out = G.stage_list()
    finally:
        G.subprocess.run = orig
    ok(len(out) == 2, f'항목 2건 파싱 (실제 {len(out)})')
    ok('dir/Untitled 3.sql' in out, '🔴 공백 포함 파일명이 살아남는다 — 초판은 여기서 죽었다')
    ok(out.get('a.md') == 100, 'size 정수 파싱')
    # 🔴 오염: 구현을 공백 분리로 되돌리면 공백 파일명이 깨져야 한다(판정식 자체의 실증).
    broken = {}
    for line in sample.splitlines():
        if not line.startswith(G.PREFIX):
            continue
        parts = [p for p in line.split('  ') if p]
        if len(parts) >= 2 and parts[1].strip().isdigit():
            broken[parts[0][len(G.PREFIX):]] = int(parts[1])
    ok(len(broken) == 0, f'종전 구현(공백 분리)은 0건을 낸다 — 실제 {len(broken)}건 ⇒ 결함 재현됨')


def axis3_contamination_and_reverse():
    print('축3 오염(드리프트 심기) + 역방향(정상은 통과)')
    d = tempfile.mkdtemp()
    clean = os.path.join(d, 'clean.md')
    dirty = os.path.join(d, 'dirty.md')
    io.open(clean, 'w', encoding='utf-8').write('x' * 100)
    io.open(dirty, 'w', encoding='utf-8').write('y' * 100)
    stage = {'clean.md': G.expected(100),
             'dirty.md': G.expected(100) + 16}   # 🔴 심은 오염 = 한 블록 어긋남

    orig_root, orig_list = G.ROOT, G.stage_list
    G.ROOT = d
    G.stage_list = lambda: stage
    try:
        rc = G.run(only_md=True)
    finally:
        G.ROOT, G.stage_list = orig_root, orig_list
    ok(rc == 1, f'심은 드리프트 1건을 blocking 으로 잡는다 (rc={rc})')

    G.ROOT = d
    G.stage_list = lambda: {'clean.md': G.expected(100)}
    try:
        rc2 = G.run(only_md=True)
    finally:
        G.ROOT, G.stage_list = orig_root, orig_list
    ok(rc2 == 0, f'역방향 = 정상 파일만 있으면 통과한다 (rc={rc2}) — 오탐 없음')


def axis4_zero_is_undecided():
    print('축4 0건은 「깨끗하다」가 아니라 「미판정」이다 (O111 ㉠)')
    orig = G.stage_list
    G.stage_list = lambda: {}
    try:
        G.run(only_md=True)
        ok(False, '0건에서 SystemExit 이 나야 한다')
    except SystemExit as e:
        ok('미판정' in str(e), f'미판정으로 중단한다: {str(e)[:60]}')
    finally:
        G.stage_list = orig


if __name__ == '__main__':
    axis1_formula()
    axis2_tab_parser()
    axis3_contamination_and_reverse()
    axis4_zero_is_undecided()
    print(f'\n{"🔴 FAIL " + str(len(FAIL)) if FAIL else "🟢 PASS — 4축 전건 통과"}')
    sys.exit(1 if FAIL else 0)
