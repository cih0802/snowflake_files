#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""음성 테스트 — `MUTATES` 도구의 안전장치와 `new_tool.py` 의 `test_*` 거절.

🆕 [O178 신설 · `O176-A-3 ㉦㉧` 시정의 짝]
🔴 **왜 손으로 만들었는가** = `new_tool.py` 로 `test_*` 를 만들면 TEST 패턴과 분류 dict 양쪽에
   걸려 `test_gate_census` 축⑨(중복 등재)가 FAIL 한다. 그 거절을 이번에 구현했고,
   이 파일이 **그 거절을 단정한다**(자기참조 축 · `J8`).

🔴🔴 **이 테스트가 방어하는 결함의 성질** = 「등재와 구현이 어긋난다」(`O176-A-0` 판정식 1).
   ㉠ `apply_table_comment_drift` 는 `gate_census` 에 **`MUTATES`(승인 대상)** 로 등재돼 있었는데
      정작 **집행을 멈출 수단이 없었다** — `argparse` 가 없어 `--help` 조차 라이브 `ALTER` 를 냈다.
   ㉡ `new_tool.py` 는 「`test_*` 는 손으로 만든다」가 **문서에만** 있었고 코드는 받아들였다.
   ⇒ 🟢 판정식 = **분류가 약속하는 계약을 코드가 실제로 지키는지 기계가 단정하게 만든다.**

축 (각 축이 스스로를 센다 — 🔴 개수를 문서에 적지 마라)
  ① `new_tool.py` 가 `test_*` 이름을 **거절**한다(rc=1) · 파일·등재 **부작용 0**
  ② `new_tool.py` 가 정상 이름은 여전히 받아들인다(역방향 오탐 축 · 이름 규약 검사만 통과)
  ③ `MUTATES` 등재 도구 전건이 **`--apply`(또는 동등 집행 플래그)를 요구**한다(소스 축)
  ④ `apply_table_comment_drift` 가 `argparse` 를 갖고 `--apply` 없이는 `execute` 에 닿지 않는다
  ⑤ 🔴 **오염 기반 축** = 「고치기 전 구현」(가드 없는 `new_tool`)을 복원하면 ①이 **실패**한다

종료코드 = 0 전건 통과 · 1 단정 실패.
Co-authored with CoCo
"""
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, 'scripts')
NEW_TOOL = os.path.join(SCRIPTS, 'new_tool.py')
CENSUS = os.path.join(SCRIPTS, 'gate_census.py')
TARGET = os.path.join(SCRIPTS, 'apply_table_comment_drift.py')

fails = []
axes = 0


def check(label, ok):
    global axes
    axes += 1
    if not ok:
        fails.append(label)


def run_new_tool(name, extra=None):
    cmd = [sys.executable, NEW_TOOL, '--name', name,
           '--bucket', 'JUDGE', '--axis', 'O178 음성 테스트용 임시 호출']
    if extra:
        cmd += extra
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return p.returncode, (p.stdout or '') + (p.stderr or '')


def main():
    census_before = io.open(CENSUS, encoding='utf-8', newline='').read()

    # ── 축① `test_*` 거절 + 부작용 0 ───────────────────────────────────────
    victim = 'test_o178_axis_probe'
    rc, out = run_new_tool(victim)
    check('①-rc `test_*` 는 rc=1 로 거절돼야 한다', rc == 1)
    check('①-msg 거절 사유에 「패턴 단일 관리」 취지가 있어야 한다',
          'test_' in out and ('패턴' in out or '중복' in out))
    check('①-파일 부작용 0', not os.path.exists(os.path.join(SCRIPTS, victim + '.py')))
    census_after = io.open(CENSUS, encoding='utf-8', newline='').read()
    check('①-등재 부작용 0(gate_census 무변경)', census_after == census_before)
    check('①-등재표에 그 이름이 없다', ("'%s'" % victim) not in census_after)

    # ── 축② 역방향 오탐 — 정상 이름은 거절 사유가 달라야 한다 ─────────────
    #   🔴 실제로 파일을 만들면 정리가 필요해지므로, **이미 있는 이름**으로 호출해
    #      「`test_*` 거절」이 아닌 **다른** 사유로 막히는지를 본다(부작용 0 유지).
    rc2, out2 = run_new_tool('gate_census')
    check('②-정상 이름은 `test_*` 거절 경로로 가지 않는다',
          rc2 == 1 and '패턴 단일 관리' not in out2)

    # ── 축③ MUTATES 전건이 집행 플래그를 요구하는가(소스 축) ──────────────
    #   🔴🔴 [O178 실측] 이 축을 만들자 **13건**이 걸렸다 — O176 은 1건(`apply_table_comment_drift`)만
    #      봤다. 같은 결함이 **쌍둥이와 일회성 스크립트에 널려 있었다**.
    #   🟢 그래서 판정을 **「0건」이 아니라 「기지목록 대비 증가 0」**으로 둔다 —
    #      `P103-⑤`(항상 빨간 게이트는 무시된다) + `index_row_gate` 의 「골든 대비 증가」와 같은 축.
    #   🔴 **기지목록은 면제가 아니라 백로그다** — 여기서 이름이 빠지는 것이 종결이고,
    #      이름을 **추가하는 것은 금지**다(추가하려면 그 도구를 고쳐라).
    #   ✅ O178 이 이 목록에서 뺀 것 = `apply_table_comment_drift` · `apply_silver_comment_drift`(쌍둥이 동시).
    KNOWN_NO_FLAG = {
        'nl_routing_smoke',            # 스모크 — 라이브 조회 위주 · 집행성 재판정 필요
        '_o169_sv_redeploy',           # 일회성(O169) — 은퇴 후보
        '_o170_reserve',               # 일회성(O170) — 은퇴 후보
        '_o170_handoff_append',        # 일회성(O170) · 🔴 `cat >>` 유실 사고 계열
        'deploy_ml_semantic_views',    # SV 배포 — `extract_sv_deploy` 경로로 통합 후보
        'deploy_sv',                   # SV 배포 — 동상
        'gen_o53_ad_combined',         # 일회성 생성 — 분류 재판정 필요(GEN?)
        'move_o63_history_entry',      # 일회성(O63)
        'o54_sv_note_patch',           # 일회성(O54)
        'patch_o63_wide_yml',          # 일회성(O63)
        'patch_o63k_view_mislabel',    # 일회성(O63)
    }
    m = re.search(r'^MUTATES = \{$(.*?)^\}$', census_before, re.M | re.S)
    check('③-MUTATES 분류 dict 를 찾을 수 있다', m is not None)
    if m:
        names = re.findall(r"^\s*'([a-z0-9_]+)'\s*:", m.group(1), re.M)
        check('③-MUTATES 가 비어 있지 않다', len(names) > 0)
        missing = []
        for n in names:
            p = os.path.join(SCRIPTS, n + '.py')
            if not os.path.exists(p):
                continue
            src = io.open(p, encoding='utf-8', newline='').read()
            # 집행 플래그 = --apply / --rebalance / --rollover / --republish / --to-outdir 계열
            if not re.search(r"--(apply|rebalance|rollover|republish|to-outdir|final)", src):
                missing.append(n)
        new_bad = sorted(set(missing) - KNOWN_NO_FLAG)
        check('③-기지목록 대비 **신규** 무플래그 MUTATES 0건 — 있으면: %s' % ', '.join(new_bad),
              not new_bad)
        # 🔴 역방향 = 고쳐졌는데 기지목록에 남아 있으면 목록이 stale 이다(이것도 결함이다)
        stale = sorted(KNOWN_NO_FLAG - set(missing))
        check('③-기지목록 stale 0건(고쳤으면 목록에서 빼라) — stale: %s' % ', '.join(stale),
              not stale)

    # ── 축④ 대상 도구가 argparse + apply 게이트를 갖는가 ──────────────────
    tsrc = io.open(TARGET, encoding='utf-8', newline='').read()
    check('④-argparse 를 쓴다', 'import argparse' in tsrc)
    check('④-`--apply` 플래그가 있다', "'--apply'" in tsrc)
    check('④-`--help` 경로가 문서만 출력한다', 'if a.help' in tsrc and 'print(__doc__)' in tsrc)
    # `execute` 는 apply 분기 **뒤**에 있어야 한다(dry-run 이 라이브를 만지지 않는다)
    i_apply = tsrc.find('if not a.apply')
    i_exec = tsrc.find('cur.execute')
    check('④-dry-run 분기가 execute 보다 앞에 있다', 0 < i_apply < i_exec)

    # ── 축⑤ 오염 기반 — 「고치기 전 구현」으로 되돌리면 ①이 실패한다 ──────
    #   🔴 파일을 건드리지 않고, 가드 구문을 제거한 **사본**을 만들어 돌린다(원본 무변경).
    nsrc = io.open(NEW_TOOL, encoding='utf-8', newline='').read()
    guard = "if a.name.startswith('test_'):"
    check('⑤-현행 구현에 가드가 실재한다', guard in nsrc)
    probe = os.path.join(SCRIPTS, '_scratch_o178_pre_fix_new_tool.py')
    try:
        # 가드 블록(조건 + 이어지는 print 4줄 + return)을 무력화한다
        broken = nsrc.replace(guard, "if False:  # 가드 제거(오염 주입)")
        io.open(probe, 'w', encoding='utf-8', newline='').write(broken)
        p = subprocess.run([sys.executable, probe, '--name', victim,
                            '--bucket', 'JUDGE', '--axis', 'pre-fix 재현'],
                           capture_output=True, text=True, timeout=120)
        pre_out = (p.stdout or '') + (p.stderr or '')
        # 고치기 전 구현은 **거절하지 않는다** ⇒ 등재를 시도한다(= 결함 재현)
        reproduced = ('패턴 단일 관리' not in pre_out)
        check('⑤-고치기 전 구현에서는 `test_*` 거절이 일어나지 않는다(결함 재현)', reproduced)
        # 🔴 오염 축이 실제로 등재를 남겼으면 즉시 되돌린다(부작용 0 을 유지한다)
        now = io.open(CENSUS, encoding='utf-8', newline='').read()
        if now != census_before:
            io.open(CENSUS, 'w', encoding='utf-8', newline='').write(census_before)
        leaked = os.path.join(SCRIPTS, victim + '.py')
        if os.path.exists(leaked):
            os.remove(leaked)
        check('⑤-오염 축 종료 후 gate_census 원복',
              io.open(CENSUS, encoding='utf-8', newline='').read() == census_before)
        check('⑤-오염 축 종료 후 유출 파일 0', not os.path.exists(leaked))
    finally:
        if os.path.exists(probe):
            os.remove(probe)
        check('⑤-임시 계측기 잔존 0(`gate_census --final` 축)', not os.path.exists(probe))

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
