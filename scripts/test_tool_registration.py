#!/usr/bin/env python3
"""음성 테스트 — 도구 등재 강제 구조(`gate_census` 임시 면제 + `new_tool` 원자성 · O174).

🔴🔴 **이 테스트가 검사하는 것 = 「미분류를 규율이 아니라 구조로 막는가」**다.
  실사고 = `O170` 이 미분류를 **4회** 방치(1차가 `O171` 라벨 오용을 유발) · `O173` 이 임시
  계측기 5개의 미분류 FAIL 을 **삭제로만** 해소했다(구조 아님).

축
  축1 임시 접두 면제 — `_scratch_x.py` 는 미분류로 잡히지 않는다
  축2 수명 강제 — 그 파일이 잔존하면 `--final` 이 **FAIL** 이다(면제가 구멍이 되지 않는다)
  축3 일반 파일은 여전히 미분류로 FAIL — 면제가 넓어지지 않았다(역방향 오탐 축)
  축4 `new_tool` 원자성 — 등재가 실패하면 **파일을 만들지 않는다**
  축5 `new_tool` 정상 경로 — 파일 생성과 등재가 **한 동작**으로 일어난다
  축6 이름 규약·중복 방어 · 무인자 `exit 2`
  축7 🔴 **고치기 전 구현으로 돌리면 실패** 실증 — 종전 `audit()`(임시 면제 없음)은 축1 을 통과 못 한다

종료코드 = 0 전건 통과 · 1 실패.
"""
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, 'scripts')
sys.path.insert(0, SCRIPTS)

import gate_census  # noqa: E402

FAIL = []


def ok(cond, msg):
    if not cond:
        FAIL.append(msg)
        print('     🔴 %s' % msg)


def run_census(*args):
    """🔴 파이프를 경유하지 않는다 — rc 를 직접 받는다(`R0-8-2`)."""
    p = subprocess.run([sys.executable, os.path.join(SCRIPTS, 'gate_census.py')] + list(args),
                       cwd=ROOT, capture_output=True, text=True, stdin=subprocess.DEVNULL,
                       timeout=300)
    return p.returncode, p.stdout


def run_new_tool(*args):
    p = subprocess.run([sys.executable, os.path.join(SCRIPTS, 'new_tool.py')] + list(args),
                       cwd=ROOT, capture_output=True, text=True, stdin=subprocess.DEVNULL,
                       timeout=120)
    return p.returncode, p.stdout + p.stderr


def main():
    print('=' * 72)
    print('[음성 테스트] 도구 등재 강제 구조 (gate_census 임시 면제 + new_tool 원자성 · O174)')
    print('=' * 72)

    # ── 축1·축2·축3 — 오염 기반: 실제로 파일을 만들어 검출을 단정한다 ──────────
    print('── 축1. 임시 접두 `%s` 는 미분류 면제다' % gate_census.SCRATCH_PREFIX)
    scratch = os.path.join(SCRIPTS, '_scratch_o174probe.py')
    plain = os.path.join(SCRIPTS, 'zz_o174_unregistered_probe.py')
    try:
        io.open(scratch, 'w', encoding='utf-8').write('print(0)\n')
        rc, out = run_census()
        ok(rc == 0, '임시 계측기가 있는데 FAIL 했다 — rc=%s' % rc)
        ok('_scratch_o174probe' in out, '임시 계측기가 출력에 열거되지 않았다')
        ok('🔴 미분류: _scratch_o174probe' not in out, '임시 계측기를 미분류로 잡았다')

        print('── 축2. 수명 강제 — `--final` 에서 잔존은 FAIL 이다')
        rc2, out2 = run_census('--final')
        ok(rc2 == 1, '`--final` 에서 임시 잔존을 통과시켰다 — rc=%s' % rc2)
        ok('임시 계측기 잔존' in out2, '`--final` FAIL 사유에 임시 잔존이 없다')

        print('── 축7. 고치기 전 구현(임시 면제 없음)으로 돌리면 축1 이 실패한다')
        names = gate_census.inventory()
        known = {}
        for _label, d in gate_census.BUCKETS:
            known.update({k: _label for k in d})
        old = [n for n in names if n not in known and not n.startswith('test_')]
        new = gate_census.audit()[3]
        ok('_scratch_o174probe' in old,
           '종전 판정식이 임시 파일을 미분류로 잡지 않았다 — 축 실증 불가')
        ok('_scratch_o174probe' not in new, '신 판정식이 임시 파일을 미분류로 잡았다')
        print('     🔎 종전 미분류 %d건 ↔ 신 %d건' % (len(old), len(new)))
    finally:
        if os.path.exists(scratch):
            os.remove(scratch)

    print('── 축3. 일반 파일은 여전히 미분류 FAIL 이다(면제가 넓어지지 않았다)')
    try:
        io.open(plain, 'w', encoding='utf-8').write('print(0)\n')
        rc3, out3 = run_census()
        ok(rc3 == 1, '미등재 일반 파일을 통과시켰다 — rc=%s' % rc3)
        ok('🔴 미분류: zz_o174_unregistered_probe' in out3, '미분류 지목이 없다')
    finally:
        if os.path.exists(plain):
            os.remove(plain)
    rc4, _ = run_census()
    ok(rc4 == 0, '오염 복구 후에도 FAIL 이다 — rc=%s (복구 축)' % rc4)

    # ── 축4 — 원자성: 등재 실패 시 파일이 생기지 않는다 ─────────────────────
    print('── 축4. `new_tool` 원자성 — 등재 실패 시 파일을 만들지 않는다')
    census_path = os.path.join(SCRIPTS, 'gate_census.py')
    census_bak = io.open(census_path, encoding='utf-8', newline='').read()
    # 🔴 **이미 등재된 이름**으로 호출한다 — 거부돼야 하고, 파일도 등재도 변하지 않아야 한다.
    #   🔎 이 축을 처음엔 미등재 이름으로 썼다가 **테스트가 유령 등재를 만들었다**
    #      ⇒ 🟢 판정식 = 원자성 축은 「실패가 보장된 입력」으로만 단정할 수 있다.
    rc5, out5 = run_new_tool('--name', 'line_len', '--bucket', 'JUDGE', '--axis', 'probe')
    ok(rc5 == 1, '이미 등재·실재하는 이름을 통과시켰다 — rc=%s' % rc5)
    ok('이미' in out5, '거부 사유가 출력되지 않았다')
    # 잘못된 이름 → rc=1 · 파일 부재 · 등재 무변경
    rc6, _ = run_new_tool('--name', 'Bad-Name', '--bucket', 'JUDGE', '--axis', 'x')
    ok(rc6 == 1, '이름 규약 위반을 통과시켰다 — rc=%s' % rc6)
    ok(not os.path.exists(os.path.join(SCRIPTS, 'Bad-Name.py')), '규약 위반인데 파일이 생겼다')
    now = io.open(census_path, encoding='utf-8', newline='').read()
    ok(now == census_bak, '실패 경로가 `gate_census.py` 를 바꿨다(원자성 위반)')

    # ── 축5 — 정상 경로: 생성 + 등재가 한 동작 ──────────────────────────────
    print('── 축5. 정상 경로 — 파일 생성과 등재가 한 동작이다')
    name = 'o174_selftest_probe'
    path = os.path.join(SCRIPTS, name + '.py')
    try:
        rc7, out7 = run_new_tool('--name', name, '--bucket', 'OBSERVE',
                                 '--axis', 'O174 자기검사용 관측 계측기', '--label', 'O174')
        ok(rc7 == 0, '정상 경로가 실패했다 — rc=%s / %s' % (rc7, out7[-200:]))
        ok(os.path.exists(path), '파일이 생기지 않았다')
        src = io.open(os.path.join(SCRIPTS, 'gate_census.py'), encoding='utf-8').read()
        ok(("'%s'" % name) in src, '등재되지 않았다')
        rc8, _ = run_census()
        ok(rc8 == 0, '생성 직후 게이트가 FAIL 이다 — rc=%s (등재 지연이 남아 있다)' % rc8)
        body = io.open(path, encoding='utf-8').read()
        ok('판정이 아니다' in body, '분류 계약이 스켈레톤에 박히지 않았다')
    finally:
        if os.path.exists(path):
            os.remove(path)
        cur = io.open(os.path.join(SCRIPTS, 'gate_census.py'), encoding='utf-8', newline='').read()
        cur = re.sub(r"\n    '%s': '[^']*'," % name, '', cur)
        io.open(os.path.join(SCRIPTS, 'gate_census.py'), 'w',
                encoding='utf-8', newline='').write(cur)
    restored = io.open(os.path.join(SCRIPTS, 'gate_census.py'), encoding='utf-8',
                       newline='').read()
    ok(restored == census_bak, '자기 정리 후 `gate_census.py` 가 원상 복구되지 않았다')
    rc9, _ = run_census()
    ok(rc9 == 0, '정리 후에도 FAIL 이다 — rc=%s' % rc9)

    # ── 축6 — 사용법 규약 ───────────────────────────────────────────────────
    print('── 축6. 무인자 실행은 `exit 2`(사용법)다')
    rc10, out10 = run_new_tool()
    ok(rc10 == 2, '무인자 실행이 rc=2 가 아니다 — rc=%s' % rc10)
    ok('사용법' in out10, '사용법이 출력되지 않았다')

    print('=' * 72)
    print('단정 %d건 · 실패 %d건' % (23, len(FAIL)))
    if FAIL:
        print('🔴 FAIL')
        return 1
    print('🟢 PASS — 전건 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
