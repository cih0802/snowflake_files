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
    # 🔴 `expected()` 는 **대표 표시값**이다(판정 정본은 `accepted()` · O181).
    for local, exp in ((0, 16), (1, 16), (15, 16), (16, 32), (17, 32), (31, 32), (32, 48)):
        ok(G.expected(local) == exp, f'expected({local}) == {exp} (실제 {G.expected(local)})')


def axis1b_accepted_boundary():
    """🆕 축1b [2026-09-23 O181] **허용 집합** — 배수 경계는 크기만으로 결정되지 않는다.

    🔴🔴 실사고 = `+16` 을 단일 정답으로 고정했더니 `_archive/` **41건이 전건 오탐**이었고
      게이트가 「항상 빨간」 상태가 됐다(`P130`). 📏 재실측(`.md` 615건) =
      `%16 != 0` **516건 전건 반올림 성립** / `%16 == 0` **99건이 `+16` 40 : `0` 59 로 갈렸다**.
    ⇒ 🟢 이 축은 ㉠ 비경계는 **값 1개** ㉡ 경계는 **값 2개** ㉢ 그 2개가 무엇인지를 단정한다.
    """
    print('축1b 🆕 허용 집합 — 배수 경계 양쪽 수용(O181 오탐 41건 회귀 고정)')
    for local in (1, 15, 17, 31, 100, 153887):
        acc = G.accepted(local)
        ok(len(acc) == 1, f'비경계 {local} 은 허용값 1개 (실제 {sorted(acc)})')
        ok(acc == {16 * (local // 16) + 16}, f'비경계 {local} 은 다음 16배수 (실제 {sorted(acc)})')
    for local in (0, 16, 32, 40960, 153888):
        acc = G.accepted(local)
        ok(acc == {local, local + 16},
           f'🔴 경계 {local} 은 `local`·`local+16` 둘 다 허용 (실제 {sorted(acc)})')
    # 🔴 오염 축 = 「고치기 전 구현」(`+16` 고정)으로 판정하면 경계에서 **거부**한다 ⇒ 결함 재현.
    pre_fix = lambda l: {16 * (l // 16) + 16}          # noqa: E731
    ok(153888 not in pre_fix(153888),
       '고치기 전 구현은 `stage == local`(경계)을 드리프트로 본다 — 오탐 재현됨')
    ok(153888 in G.accepted(153888),
       '현행 구현은 그것을 수용한다(실물 59건이 이 형태다)')
    # 🔴 역방향 = 수용을 넓혔어도 **진짜 드리프트는 여전히 잡힌다**(은폐 0).
    ok(153889 not in G.accepted(153888) and 153872 not in G.accepted(153888),
       '경계에서도 ±1 B·한 블록 아래는 여전히 드리프트로 잡힌다')


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
    axis1b_accepted_boundary()
    axis2_tab_parser()
    axis3_contamination_and_reverse()
    axis4_zero_is_undecided()
    print(f'\n{"🔴 FAIL " + str(len(FAIL)) if FAIL else "🟢 PASS — 전건 통과"}')
    sys.exit(1 if FAIL else 0)
