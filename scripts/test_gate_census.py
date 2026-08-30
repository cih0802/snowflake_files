# -*- coding: utf-8 -*-
"""[2026-08-30 O121-B] `gate_census` 음성 테스트 — **분모를 지키는 장치가 실제로 막는가**.

🔴🔴 왜 필요한가: 이 도구의 **초판이 바로 그 결함을 냈다.** 초판은 파일 내용에 `CREATE OR REPLACE`·
   `GRANT` 토큰이 있으면 「라이브를 바꾼다」로 분류했고, 그 결과
   **`audit_ddl_rule7`·`sv_unit_gate`·`table_ddl_column_gate` 를 「실행 금지」로 오분류**했다
   (이들은 DDL 파일을 **입력으로 읽는** 판정 게이트다) ⇒ 분모를 **반대 방향으로** 깨뜨렸을 것이다.
   🟢 그래서 휴리스틱을 버리고 **명시 등재 + 미분류 FAIL** 로 바꿨고, 이 테스트가 그 계약을 단정한다.

🔴 이 테스트가 지키는 계약 4개
   ㉠ 새 스크립트가 생기면 **막는다**(미분류 = FAIL). 이것이 5세션 연속 결함의 유일한 구조적 처방이다.
   ㉡ 등재만 있고 파일이 없으면(유령) **알린다** — 삭제된 도구를 계속 「돌렸다」고 쓰지 않게 한다.
   ㉢ 한 스크립트를 두 분류에 넣으면 **막는다**(분모가 두 번 세어진다).
   ㉣ `MUTATES` 는 `--run` 대상에서 **원리적으로 제외**된다 — 실행 목록에 새면 라이브가 바뀐다(`R4-4-3`).

🟢 라이브·서브프로세스 없이 돈다 — 등재표와 분모만 시험한다.
"""
import sys
import os
import io
import glob
import tempfile
import contextlib

sys.path.insert(0, '/workspace/scripts')
import gate_census as G

results = []


def check(name, cond, detail=''):
    results.append((name, cond, detail))
    print(('  🟢 PASS  ' if cond else '  🔴 FAIL  ') + name
          + ('  — %s' % detail if detail else ''))


def run_audit(tmp_names):
    """분모를 임시 목록으로 갈아끼워 audit() 을 돌린다."""
    orig = G.inventory
    G.inventory = lambda: sorted(tmp_names)
    try:
        return G.audit()
    finally:
        G.inventory = orig


def run_main(tmp_names):
    orig, argv = G.inventory, sys.argv
    G.inventory = lambda: sorted(tmp_names)
    sys.argv = ['gate_census.py']
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            rc = G.main()
    finally:
        G.inventory, sys.argv = orig, argv
    return rc, buf.getvalue()


print('=' * 72)
print('gate_census 음성 테스트 — 분모 계약 4종 + 실물 대조')
print('=' * 72)

REAL = sorted(os.path.basename(p)[:-3] for p in glob.glob('/workspace/scripts/*.py'))

# ① 실물 분모는 통과해야 한다(과탐 아님).
rc, out = run_main(REAL)
check('① 실제 scripts/ 분모는 PASS(미분류·유령·중복 0)', rc == 0, 'rc=%d' % rc)

# ② 🔴 새 스크립트가 생기면 막는다 — 5세션 연속 결함의 구조적 처방.
rc, out = run_main(REAL + ['brand_new_unregistered_tool'])
check('② 미등재 신규 스크립트를 FAIL 로 막는다',
      rc == 1 and 'brand_new_unregistered_tool' in out and '미분류' in out, 'rc=%d' % rc)

# ③ 등재만 있고 파일이 없으면 유령으로 알린다.
rc, out = run_main([n for n in REAL if n != 'doc_type_gate'])
check('③ 파일이 사라진 등재를 유령으로 검출',
      rc == 1 and 'doc_type_gate' in out and '유령' in out, 'rc=%d' % rc)

# ④ 🔴 중복 등재 = 분모 이중계상. 실제로 넣어 보고 잡히는지 본다.
G.OBSERVE['doc_type_gate'] = '중복 주입(테스트)'
try:
    rc, out = run_main(REAL)
    ok = rc == 1 and '중복 등재' in out and 'doc_type_gate' in out
finally:
    del G.OBSERVE['doc_type_gate']
check('④ 같은 스크립트를 두 분류에 넣으면 FAIL', ok, 'rc=%d' % rc)
rc_after, _ = run_main(REAL)
check('④-b 중복 제거 후 다시 PASS(상태 오염 없음)', rc_after == 0, 'rc=%d' % rc_after)

# ⑤ 🔴🔴 MUTATES 는 --run 실행 대상에 원리적으로 없다.
overlap = sorted(set(G.MUTATES) & set(G.JUDGE))
check('⑤ MUTATES ∩ JUDGE = 공집합(실행 목록에 파괴 도구가 새지 않는다)',
      not overlap, '교집합=%s' % (overlap or '없음'))

# ⑥ 🔴 초판 오분류의 회귀 방지 — 이 3종은 **판정 게이트**이며 실행 대상이어야 한다.
misread = [n for n in ('audit_ddl_rule7', 'sv_unit_gate', 'table_ddl_column_gate')
           if n not in G.JUDGE]
check('⑥ 초판이 오분류한 3종이 JUDGE 에 있다(DDL 을 읽을 뿐 바꾸지 않는다)',
      not misread, '누락=%s' % (misread or '없음'))

# ⑦ 🔴 등재에는 「축」이 있어야 한다 — 축이 없으면 다음 세션이 무엇을 재는지 모른다.
axisless = sorted(n for n, v in G.JUDGE.items() if not v.strip())
check('⑦ JUDGE 전건이 판정 축 문구를 갖는다', not axisless, '빈 축=%s' % (axisless or '없음'))

# ⑧ 🔴 배포·은퇴 도구가 MUTATES 에 실제로 있는가(분류가 형해화되지 않았는가).
must_mutate = ['deploy_sv', 'retire_rows', 'retire_sections', 'split_doc']
missing = [n for n in must_mutate if n not in G.MUTATES]
check('⑧ 배포·은퇴·분할 도구가 MUTATES 에 등재돼 있다', not missing,
      '누락=%s' % (missing or '없음'))

# ⑨ TEST 는 등재표에 넣지 않는다(패턴으로 잡는다) — 이중 관리 방지.
in_reg = sorted(n for label, d in G.BUCKETS for n in d if n.startswith('test_'))
check('⑨ test_* 는 등재표에 없다(패턴 단일 관리)', not in_reg, '등재=%s' % (in_reg or '없음'))

# ⑩ 미분류가 생겼을 때 **무엇을 하라고** 알리는가(처방 없는 FAIL 금지).
rc, out = run_main(REAL + ['zzz_probe_tool'])
check('⑩ 미분류 FAIL 이 처방을 함께 낸다(등재하라)',
      rc == 1 and '등재하라' in out, 'rc=%d' % rc)

print('=' * 72)
bad = [n for n, c, _ in results if not c]
if bad:
    print('🔴 음성 테스트 실패 %d/%d: %s' % (len(bad), len(results), bad))
    sys.exit(1)
print('🟢 음성 테스트 %d/%d 통과 — 분모 계약 4종 + 초판 오분류 회귀 축 포함'
      % (len(results), len(results)))
