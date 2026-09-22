#!/usr/bin/env python3
"""id_collision_gate 미정의 번호 전수 열거 축 — 검출·오탐·분모명시·회귀(고치기 전 구현) 4축 단정

🆕 [2026-09-22 O176 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `JUDGE`. 종료코드가 판정이다 — 위반이면 1, 통과면 0.

🔴🔴 **왜 이 테스트가 있는가** = `id_collision_gate` 머리말이 「미정의 번호」 부가 검사를
  **약속해 놓고 O176 까지 구현하지 않았다**. 실제 구현은 계열별 **최대값 비교**뿐이어서
  **최대값보다 작은 미정의는 원리적으로 탐지되지 않았다**.
  · 🔎 실사고 = `P102`(47회) · `P106`(75회) · `P33`(115회)이 정의 형태 0 으로 장기 생존했고,
    착수표 ⑩ ㉤ 는 그중 **2종만** 열어뒀다(같은 class 실측 334종 · 총참조 5,879회).
  🟢 판정식 = **「내가 약속한 검사가 실제로 도는가」를 기계가 단정한다.**

축 구성
  T1 검출   : 정의 형태 없이 참조만 있는 ID 를 주입하면 **열거된다**
  T2 오탐   : 정의 형태가 있는 ID 는 열거되지 **않는다**(역방향)
  T3 분모   : 출력이 **분모(정의 스캔 제외 문서)를 문면에 밝힌다** + 크로스워크 3상태를 구별한다
  T4 회귀   : **최대값 비교만 하던 「고치기 전 구현」으로 돌리면 T1 이 실패한다**
              🔴 이 축이 없으면 T1 은 「원래도 통과했을 것」과 구별되지 않는다(`R3-2`).
"""
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

GATE = Path(__file__).resolve().parent / 'id_collision_gate.py'
FAILS = []
OKS = []


def ok(axis, msg):
    OKS.append(axis)
    print(f'  PASS  {axis} — {msg}')


def bad(axis, msg):
    FAILS.append(axis)
    print(f'  FAIL  {axis} — {msg}')


def run_gate(doc_dir, extra=()):
    """DOC_DIR 를 임시 코퍼스로 바꿔치기한 사본 게이트를 돌린다."""
    src = io.open(GATE, encoding='utf-8').read()
    # DOC_DIR 정의를 임시 경로로 치환한다. 🔴 원본을 건드리지 않는다.
    patched, n = re.subn(r'(?m)^DOC_DIR\s*=.*$',
                         f'DOC_DIR = __import__("pathlib").Path(r"{doc_dir}")',
                         src, count=1)
    if n != 1:
        raise AssertionError(f'DOC_DIR 치환 실패 (n={n}) — 게이트 구조가 바뀌었다')
    tmp = Path(doc_dir).parent / '_gate_under_test.py'
    io.open(tmp, 'w', encoding='utf-8').write(patched)
    r = subprocess.run([sys.executable, str(tmp), *extra],
                       capture_output=True, text=True, timeout=180)
    return r.returncode, r.stdout + r.stderr


def run_gate_legacy(doc_dir):
    """🔴 T4 — 「고치기 전 구현」 재현: 미정의 열거 블록을 제거한 판본."""
    src = io.open(GATE, encoding='utf-8').read()
    patched, n = re.subn(r'(?m)^DOC_DIR\s*=.*$',
                         f'DOC_DIR = __import__("pathlib").Path(r"{doc_dir}")',
                         src, count=1)
    if n != 1:
        raise AssertionError('DOC_DIR 치환 실패')
    # 열거 블록(신설분)만 도려낸다 — 최대값 비교 축은 남긴다.
    start = patched.find('    undefined = {i: refs[i] for i in refs')
    end = patched.find('    if dup and not observe:')
    if start < 0 or end < 0 or end <= start:
        raise AssertionError('신설 블록 경계를 찾지 못했다 — 구조가 바뀌었다')
    patched = patched[:start] + patched[end:]
    tmp = Path(doc_dir).parent / '_gate_legacy.py'
    io.open(tmp, 'w', encoding='utf-8').write(patched)
    r = subprocess.run([sys.executable, str(tmp)],
                       capture_output=True, text=True, timeout=180)
    return r.returncode, r.stdout + r.stderr


def build_corpus(root):
    """최소 코퍼스 — 정의 있는 ID 1종 + 정의 없이 참조만 있는 ID 1종."""
    d = Path(root) / 'docs'
    d.mkdir(parents=True, exist_ok=True)
    # 🟢 P901 = 정의 형태 보유(신규 선언형) · 참조도 있다  ⇒ 열거되면 안 된다(T2)
    # 🔴 P902 = 참조만 3회 · 정의 형태 없음                ⇒ 열거돼야 한다(T1)
    io.open(d / '10_진단_원인분석.md', 'w', encoding='utf-8').write(
        '# 진단\n'
        '\n'
        '🆕 **P901: 정의 형태가 있는 교훈이다.**\n'
        '\n'
        '- `P901` 을 참조한다.\n'
        '- `P902` 를 참조한다.\n'
        '- `P902` 를 또 참조한다.\n'
        '- `P902` 를 세 번째로 참조한다.\n'
    )
    # 크로스워크 문서 — 정의 스캔에서 제외된다. P903 은 여기에만 정의 형태가 있다.
    io.open(d / '00_INDEX_이슈원장.md', 'w', encoding='utf-8').write(
        '# 원장\n'
        '\n'
        '🆕 **P903: 크로스워크에만 정의 형태가 있다.**\n'
        '\n'
        '- `P903` 참조.\n'
    )
    return d


def main():
    print('[음성 테스트] id_collision_gate 미정의 번호 열거 축 (O176 신설)')
    tmp = tempfile.mkdtemp(prefix='o176_undef_')
    try:
        d = build_corpus(tmp)

        rc, out = run_gate(str(d), extra=('--undefined-all',))
        if rc != 0:
            bad('T0.runs', f'게이트가 rc={rc} 로 죽었다 — 아래 출력 참조\n{out[-500:]}')
            print(f'\nPASS {len(OKS)} · FAIL {len(FAILS)}')
            return 1
        ok('T0.runs', f'임시 코퍼스에서 rc=0')

        # ── T1 검출 ────────────────────────────────────────────────
        if re.search(r'\*\*P902\*\*\s*정의 0\s*·\s*참조 3회', out):
            ok('T1.detect', 'P902(정의 0 · 참조 3회)를 정확한 건수로 열거했다')
        else:
            bad('T1.detect', 'P902 를 열거하지 못했다 — 「약속한 검사」가 돌지 않는다')

        # ── T2 오탐 ────────────────────────────────────────────────
        if re.search(r'\*\*P901\*\*\s*정의 0', out):
            bad('T2.no-false-positive', 'P901 은 정의 형태가 있는데 미정의로 열거됐다(오탐)')
        else:
            ok('T2.no-false-positive', 'P901(정의 보유)은 열거되지 않았다')

        # ── T3 분모 명시 + 크로스워크 3상태 구별 ──────────────────
        has_denom = '정의 스캔 제외' in out and '00_INDEX_이슈원장.md' in out
        has_xwalk = '크로스워크에만 정의 형태 있음' in out and 'P903' in out
        if has_denom and has_xwalk:
            ok('T3.denominator', '분모를 문면에 밝히고 P903 을 크로스워크 전용으로 표시했다')
        elif not has_denom:
            bad('T3.denominator',
                '출력이 분모(정의 스캔 제외 문서)를 밝히지 않는다 — 「정의 0」이 오독된다')
        else:
            bad('T3.denominator',
                'P903(크로스워크에만 정의)이 구별 표시되지 않는다 — 3상태가 한 숫자로 뭉개진다')

        # ── T4 회귀: 고치기 전 구현으로 돌리면 T1 이 실패해야 한다 ──
        rc_l, out_l = run_gate_legacy(str(d))
        if re.search(r'\*\*P902\*\*\s*정의 0', out_l):
            bad('T4.regression',
                '「고치기 전 구현」에서도 P902 가 열거된다 — T1 은 신설 축을 단정하지 못한다')
        elif '정의<참조' in out_l or rc_l == 0:
            ok('T4.regression',
               '고치기 전 구현은 P902 를 열거하지 못한다(최대값 비교만 한다) ⇒ T1 이 신설분을 단정한다')
        else:
            bad('T4.regression', f'고치기 전 판본이 예상 밖으로 동작했다 rc={rc_l}')

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print(f'\nPASS {len(OKS)} · FAIL {len(FAILS)}')
    if FAILS:
        print('🔴 실패 축: ' + ', '.join(FAILS))
        return 1
    print('✅ 4축 전건 통과 — 신설 축이 실제로 돌고, 고치기 전 구현에서는 실패한다')
    return 0


if __name__ == '__main__':
    sys.exit(main())
