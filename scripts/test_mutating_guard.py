#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""음성 테스트 — `mutating_guard` 의 `--apply` 드라이런 가드와 `MUTATES` 11곳 삽입.

🆕 [2026-09-23 O181 신설 · 인수인계 `O180-B-3` **I2** 처방의 짝]
🔴 **왜 손으로 만들었는가** = `new_tool.py` 는 `test_*` 이름을 거절한다(O178 가드).

🔴🔴 **이 테스트가 방어하는 결함의 성질** = `O180-B-0 ㉢` —
   **「가드를 심었다」는 「가드가 동작한다」가 아니다.**
   실사고(O180-B) = `except Exception: return None` 이 함수명 오류를 삼켜 가드가 통째로
   건너뛰어졌고, 보호 대상에 파괴 연산이 **실제로 집행**됐다.
   ⇒ 🟢 판정식 = **가드는 「거부되는지」를 기계가 단정해야 한다.**

🔴🔴 **왜 대상 도구를 무방비로 실행하지 않는가** = 그 실행이 바로 O180-B 사고다.
   `_o170_reserve` 는 가드가 죽으면 **원장 조각을 재작성**한다.
   🟢 그래서 **쓰기를 차단한 하니스**에서 돌린다 — 임시 `sitecustomize.py` 가
   `open`/`io.open` 의 쓰기 모드와 `os.remove`·`os.replace` 를 **예외로 바꾼다**.
   · 가드가 살아 있으면 ⇒ 쓰기에 닿기 전에 `sys.exit(0)` ⇒ **rc=0 + DRY-RUN 문구**
   · 가드가 죽으면 ⇒ 첫 쓰기 시도에서 예외 ⇒ **rc≠0** (그리고 파일은 무변경)
   ⇒ 🔴 어느 쪽이든 **실해가 없다**. 이것이 이 하니스의 존재 이유다.

축 (각 축이 스스로를 센다 — 🔴 개수를 문서에 적지 마라)
  ① `require_apply` 는 `--apply` 부재 시 `SystemExit(0)` 을 낸다 + 안내 문구 3요소
  ② `--apply` 가 있으면 **반환**한다(역방향 오탐 축 — 가드가 집행을 막아버리면 안 된다)
  ③ `has_apply` 는 판정 정본이다(부분 일치·접두 오탐 없음)
  ④ 🔴 **삽입 전건 축** = `gate_census.MUTATES` 중 `KNOWN_NO_FLAG` 대상 11건이
     `require_apply` 를 호출하고 **그 호출이 부작용보다 앞**에 있다(소스 축)
  ⑤ 🔴 **실행 축(쓰기 차단 하니스)** = 11건 무인자 실행이 전건 rc=0 + DRY-RUN 문구
  ⑥ 🔴 **오염 기반 축** = 가드 호출을 제거한 **사본**을 같은 하니스로 돌리면
     DRY-RUN 이 나오지 않는다(원본 무변경 · 결함 재현)
  ⑦ 🔴 **기지목록 종결 축** = `test_mutating_tool_safety.KNOWN_NO_FLAG` 가 **비어 있다**
     (I2 의 종결 정의 = 「목록에서 이름을 빼는 것」)

종료코드 = 0 전건 통과 · 1 단정 실패.
Co-authored with CoCo
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

fails = []
axes = 0

# 🔴 대상 11건 = O180-B 착수 실측이 확정한 I2 분모. 이 목록은 **여기 1곳**에만 둔다.
TARGETS = [
    'nl_routing_smoke',
    '_o169_sv_redeploy',
    '_o170_reserve',
    '_o170_handoff_append',
    'deploy_ml_semantic_views',
    'deploy_sv',
    'gen_o53_ad_combined',
    'move_o63_history_entry',
    'o54_sv_note_patch',
    'patch_o63_wide_yml',
    'patch_o63k_view_mislabel',
]

# 🔴 쓰기 차단 하니스 — 읽기는 허용하고 **쓰기만** 예외로 바꾼다.
#   🟢 읽기를 막으면 가드 뒤 경로에 닿기 전에 죽어 축⑥(오염)이 거짓 통과한다.
BLOCKER = '''# -*- coding: utf-8 -*-
import builtins, io, os, sys

def _guard(orig):
    def f(file, mode='r', *a, **k):
        if any(c in str(mode) for c in ('w', 'a', 'x', '+')):
            raise RuntimeError('WRITE-BLOCKED: %s (%s)' % (file, mode))
        return orig(file, mode, *a, **k)
    return f

builtins.open = _guard(builtins.open)
io.open = _guard(io.open)
for _n in ('remove', 'unlink', 'replace', 'rename', 'rmdir'):
    if hasattr(os, _n):
        setattr(os, _n, lambda *a, **k: (_ for _ in ()).throw(
            RuntimeError('FS-BLOCKED')))
'''


def check(label, ok):
    global axes
    axes += 1
    if not ok:
        fails.append(label)


def run_blocked(path, tmpdir, extra=None):
    """쓰기 차단 하니스에서 스크립트를 돌리고 (rc, 출력) 을 준다."""
    env = dict(os.environ)
    env['PYTHONPATH'] = tmpdir + os.pathsep + SCRIPTS + os.pathsep + env.get('PYTHONPATH', '')
    cmd = [sys.executable, path] + (extra or [])
    p = subprocess.run(cmd, cwd=ROOT, env=env, timeout=120,
                       capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return p.returncode, (p.stdout or '') + (p.stderr or '')


def main():
    import mutating_guard as mg

    # ── 축① 무플래그 ⇒ SystemExit(0) + 안내 3요소 ──────────────────────────
    buf = io.StringIO()
    old = sys.stdout
    sys.stdout = buf
    code = 'NOEXIT'
    try:
        mg.require_apply('/x/foo.py', '테스트 집행분', argv=[])
    except SystemExit as e:
        code = e.code
    finally:
        sys.stdout = old
    out = buf.getvalue()
    check('①-무플래그는 SystemExit(0)', code == 0)
    check('①-DRY-RUN 문구', 'DRY-RUN' in out)
    check('①-도구명 표시', 'foo.py' in out)
    check('①-집행분 표시', '테스트 집행분' in out)
    check('①-`--apply` 실행법 안내', '--apply' in out)

    # ── 축② 역방향 오탐 — `--apply` 면 반환한다 ────────────────────────────
    check('②-`--apply` 면 True 반환(집행 허용)',
          mg.require_apply('/x/foo.py', 'p', argv=['--apply']) is True)

    # ── 축③ `has_apply` 판정 정본 ─────────────────────────────────────────
    check('③-정확 일치만 True', mg.has_apply(['--apply']) is True)
    check('③-접두 오탐 없음', mg.has_apply(['--applyx']) is False)
    check('③-부분 문자열 오탐 없음', mg.has_apply(['xx--apply']) is False)
    check('③-빈 인자는 False', mg.has_apply([]) is False)

    # ── 축④ 삽입 전건 + 순서(소스 축) ─────────────────────────────────────
    for n in TARGETS:
        p = os.path.join(SCRIPTS, n + '.py')
        check('④-%s 파일 실재' % n, os.path.exists(p))
        if not os.path.exists(p):
            continue
        src = io.open(p, encoding='utf-8', newline='').read()
        check('④-%s 가드 import' % n, 'from mutating_guard import require_apply' in src)
        i_call = src.find('require_apply(__file__')
        check('④-%s 가드 호출' % n, i_call >= 0)
        # 부작용 = 쓰기 open · 라이브 커서 실행. 🔴 호출이 그보다 앞에 있어야 한다.
        for pat in (r"open\([^)]*['\"][wax]", r"\.execute\(", r"\.cursor\(\)"):
            m = re.search(pat, src)
            if m and i_call >= 0:
                check('④-%s 가드 호출이 부작용(%s :%d)보다 앞'
                      % (n, pat, src[:m.start()].count('\n') + 1),
                      i_call < m.start())
        # `MUTATES` 등재 유지 축 — 🔴 OBSERVE 로 내리지 마라(과금·DDL 보유)
        check('④-%s 소스에 집행 플래그 토큰 실재' % n,
              re.search(r"--(apply|rebalance|rollover|republish|to-outdir|final)", src)
              is not None)

    # ── 축⑤ 실행 축 — 쓰기 차단 하니스에서 전건 DRY-RUN ───────────────────
    tmpdir = tempfile.mkdtemp(prefix='o181_guard_')
    try:
        io.open(os.path.join(tmpdir, 'sitecustomize.py'), 'w',
                encoding='utf-8', newline='').write(BLOCKER)
        for n in TARGETS:
            p = os.path.join(SCRIPTS, n + '.py')
            if not os.path.exists(p):
                continue
            rc, out = run_blocked(p, tmpdir)
            check('⑤-%s 무인자 rc=0 (실측 rc=%s)' % (n, rc), rc == 0)
            check('⑤-%s DRY-RUN 문구' % n, 'DRY-RUN' in out)
            check('⑤-%s 쓰기 차단에 닿지 않았다' % n,
                  'WRITE-BLOCKED' not in out and 'FS-BLOCKED' not in out)

        # ── 축⑥ 오염 기반 — 가드 호출을 제거한 **사본**은 DRY-RUN 을 내지 않는다 ─
        #   🔴 원본은 건드리지 않는다. 사본은 `_scratch_` 접두로 두고 즉시 지운다.
        victim = '_o170_reserve'
        vsrc = io.open(os.path.join(SCRIPTS, victim + '.py'),
                       encoding='utf-8', newline='').read()
        probe = os.path.join(SCRIPTS, '_scratch_o181_pre_fix_reserve.py')
        try:
            broken = re.sub(r'^require_apply\(__file__.*$',
                            '# 가드 제거(오염 주입)', vsrc, count=1, flags=re.M)
            check('⑥-오염 주입이 실제로 호출을 지웠다',
                  'require_apply(__file__' not in broken)
            io.open(probe, 'w', encoding='utf-8', newline='').write(broken)
            rc6, out6 = run_blocked(probe, tmpdir)
            check('⑥-가드 없는 구현은 DRY-RUN 을 내지 않는다(결함 재현)',
                  'DRY-RUN' not in out6)
            check('⑥-가드 없는 구현은 쓰기 차단에 걸린다(집행 시도 실증)',
                  rc6 != 0 or 'BLOCKED' in out6)
            check('⑥-원본 무변경',
                  io.open(os.path.join(SCRIPTS, victim + '.py'),
                          encoding='utf-8', newline='').read() == vsrc)
        finally:
            if os.path.exists(probe):
                os.remove(probe)
            check('⑥-임시 계측기 잔존 0(`gate_census --final` 축)',
                  not os.path.exists(probe))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    # ── 축⑦ 기지목록 종결 — 이름이 빠지는 것이 종결이다 ───────────────────
    tsrc = io.open(os.path.join(SCRIPTS, 'test_mutating_tool_safety.py'),
                   encoding='utf-8', newline='').read()
    m = re.search(r'KNOWN_NO_FLAG = (set\(\)|\{(.*?)\n    \})', tsrc, re.S)
    check('⑦-기지목록 블록을 찾을 수 있다', m is not None)
    if m:
        left = re.findall(r"^\s*'([a-z0-9_]+)'", m.group(2) or '', re.M)
        check('⑦-기지목록이 비었다(I2 종결) — 잔존: %s' % ', '.join(left), not left)

    print('축·단정 %d건 실행' % axes)
    if fails:
        print('🔴 FAIL %d건' % len(fails))
        for f in fails:
            print('   · ' + f)
        return 1
    print('🟢 PASS — 전건 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
