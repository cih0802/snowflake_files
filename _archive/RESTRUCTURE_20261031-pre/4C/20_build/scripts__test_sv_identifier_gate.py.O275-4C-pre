# -*- coding: utf-8 -*-
"""[2026-08-18 O84] `sv_identifier_gate` 음성 테스트 — **잡아야 할 것을 잡는가**.

🔴 왜 필요한가: 게이트를 새로 만들면 「PASS 했다」가 곧 「검사가 작동한다」가 아니다
   (`P106`·`P224`·O82-B 가 `index_row_gate` 에서 음성 테스트 4종을 요구한 것과 같은 이유).
   특히 이 게이트는 **면제 목록 2종**(`RETIRED_IDENTS`·`UNDEPLOYED_PREFIX`)을 갖는데,
   면제가 **무력화**로 기울면 진짜 오기가 조용히 통과한다 ⇒ 면제를 빼면 잡히는지 반드시 본다.

🟢 라이브 접속 없이 돈다 — 인벤토리를 주입한다(게이트 판정 로직만 시험한다).
"""
import sys, os, tempfile, io, contextlib

sys.path.insert(0, '/workspace/scripts')
import sv_identifier_gate as G

FAKE_INV = {
    'SV_MEMBER_EVENT': {'FME', 'TOTAL_DEV_CNT', 'ORG_DEPARTMENT'},
    'SV_AD':           {'FAP', 'TOTAL_AD_COST'},
}


def _run(tmpdir, doc_text, agent_text, inv=None, retired=None, undeployed_prefix=None):
    """임시 표면을 분모로 게이트를 돌리고 (종료코드, 출력) 을 준다."""
    os.makedirs(os.path.join(tmpdir, 'docs'), exist_ok=True)
    os.makedirs(os.path.join(tmpdir, 'cortex_project/agents/A_TEST'), exist_ok=True)
    open(os.path.join(tmpdir, 'docs/d.md'), 'w', encoding='utf-8').write(doc_text)
    open(os.path.join(tmpdir, 'cortex_project/agents/A_TEST/agent_spec.yaml'),
         'w', encoding='utf-8').write(agent_text)

    o_root, o_glob, o_docs = G.ROOT, G.AGENT_GLOB, G.DOC_GLOBS
    o_ret, o_pre = G.RETIRED_IDENTS, G.UNDEPLOYED_PREFIX
    G.ROOT = tmpdir
    G.AGENT_GLOB = os.path.join(tmpdir, 'cortex_project/agents/*/agent_spec.yaml')
    G.DOC_GLOBS = ['docs/*.md', 'cortex_project/agents/*/agent_spec.yaml']
    if retired is not None:
        G.RETIRED_IDENTS = retired
    if undeployed_prefix is not None:
        G.UNDEPLOYED_PREFIX = undeployed_prefix
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            rc = G.run(inv=inv if inv is not None else FAKE_INV)
    finally:
        G.ROOT, G.AGENT_GLOB, G.DOC_GLOBS = o_root, o_glob, o_docs
        G.RETIRED_IDENTS, G.UNDEPLOYED_PREFIX = o_ret, o_pre
    return rc, buf.getvalue()


SPEC_OK = """tool_resources:
  analyst_member_event:
    semantic_view: GN_DW.SERVING.SV_MEMBER_EVENT
"""
SPEC_ML = """tool_resources:
  analyst_ml_x:
    semantic_view: GN_DW.SERVING.SV_ML_FOO
"""
SPEC_TYPO = """tool_resources:
  analyst_typo:
    semantic_view: GN_DW.SERVING.SV_MEMBER_EVNET
"""

results = []


def check(name, cond, detail=''):
    results.append((name, cond, detail))
    print(('  🟢 PASS  ' if cond else '  🔴 FAIL  ') + name + (f'  — {detail}' if detail else ''))


print('=' * 72)
print('sv_identifier_gate 음성 테스트 6종')
print('=' * 72)

with tempfile.TemporaryDirectory() as td:
    # ① 정상 = 통과해야 한다(과탐 아님)
    rc, out = _run(td, '`SV_MEMBER_EVENT.TOTAL_DEV_CNT` 를 쓴다.\n', SPEC_OK)
    check('① 정상 참조는 PASS', rc == 0, f'rc={rc}')

with tempfile.TemporaryDirectory() as td:
    # ② 없는 식별자 = 잡아야 한다
    rc, out = _run(td, '`SV_MEMBER_EVENT.NO_SUCH_METRIC` 을 쓴다.\n', SPEC_OK)
    check('② 부재 식별자를 FAIL 로 검출', rc == 1 and 'NO_SUCH_METRIC' in out, f'rc={rc}')

with tempfile.TemporaryDirectory() as td:
    # ③ SV 이름 오타 = 잡아야 한다(미배포 접두가 아니므로 일반 FAIL)
    rc, out = _run(td, 'x\n', SPEC_TYPO)
    check('③ SV 오타를 FAIL 로 검출', rc == 1 and 'SV_MEMBER_EVNET' in out, f'rc={rc}')

with tempfile.TemporaryDirectory() as td:
    # ④ 미배포 접두 = 별 버킷으로 분류하되 **여전히 FAIL** 이어야 한다
    rc, out = _run(td, 'x\n', SPEC_ML, undeployed_prefix='SV_ML_')
    check('④ 미배포 SV 를 별 버킷 + FAIL 유지',
          rc == 1 and '미배포 드리프트' in out, f'rc={rc}')

with tempfile.TemporaryDirectory() as td:
    # ⑤ 🔴 면제가 **무력화가 아님**을 증명 — 은퇴 등재를 비우면 그 참조가 FAIL 로 잡힌다
    doc = '`SV_MEMBER_EVENT.AVG_RETENTION_MONTHS` 는 제거됐다.\n'
    rc_ex, out_ex = _run(td, doc, SPEC_OK,
                         retired={('SV_MEMBER_EVENT', 'AVG_RETENTION_MONTHS'): '사유'})
    rc_no, out_no = _run(td, doc, SPEC_OK, retired={})
    check('⑤ 은퇴 등재 = 면제 · 등재 제거 = FAIL(무력화 아님)',
          rc_ex == 0 and rc_no == 1, f'등재 rc={rc_ex} · 미등재 rc={rc_no}')

with tempfile.TemporaryDirectory() as td:
    # ⑥ ③ 축(백틱)은 advisory — 종료코드를 바꾸지 않아야 한다
    rc, out = _run(td, '`WHOLLY_UNKNOWN_TOKEN` 만 있다.\n', SPEC_OK)
    check('⑥ 백틱 미상 토큰은 advisory(종료코드 무영향)',
          rc == 0 and '미포함 1건' in out, f'rc={rc}')

print('=' * 72)
bad = [n for n, c, _ in results if not c]
if bad:
    print(f'🔴 음성 테스트 실패 {len(bad)}/{len(results)}: {bad}')
    sys.exit(1)
print(f'🟢 음성 테스트 {len(results)}/{len(results)} 통과 — 면제 2종이 무력화가 아님을 포함해 확인')
