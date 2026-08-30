# -*- coding: utf-8 -*-
"""[2026-08-30 O121] `agent_object_ref_gate` 음성 테스트 — **잡아야 할 것을 잡는가**.

🔴 왜 필요한가: 이 게이트는 처음 돌린 순간 **PASS(위반 0)** 였다. 그런데 O121 이 손으로 재니
   `AGENT_OVERALL` 에 실제 오기가 1건 있었고(시정 후 0), 「0건」이 「없다」인지 「내 판정식이
   못 본다」인지는 PASS 만으로 구별되지 않는다(`91_사고사례집.md` §C24 ㉠). ⇒ 검출력을 직접 단정한다.

🔴🔴 특히 이 게이트에는 **면제 3종**이 있다 — 넓히면 무력화된다(`▣ZZZ6 ㉦`):
   ㉠ 부정 서술 면제(`NEG_RE`) ㉡ `SV_*` 제외 ㉢ `KNOWN_ABSENT`.
   ⇒ 축3·축7 이 **면제를 빼면 잡힌다**를 양방향으로 단정한다.

🔴🔴 그리고 축6 이 **이 세션의 실사고를 그대로 재현**한다 = O120-B 는 `tool_spec.description`
   만 고쳤고 `instructions.system` 의 같은 오기를 놓쳤다. ⇒ **표면이 어디든 잡히는가**를 단정한다.
   이 축이 FAIL 하면 분모가 다시 좁아진 것이다.

🟢 라이브 접속 없이 돈다 — 인벤토리를 주입한다.
"""
import sys
import os
import io
import tempfile
import contextlib

sys.path.insert(0, '/workspace/scripts')
import agent_object_ref_gate as G

# 라이브를 흉내낸 최소 인벤토리. `SV_BUDGET` 은 **일부러 넣지 않는다** —
# 실제로도 Semantic View 는 INFORMATION_SCHEMA.TABLES 에 없다(O118 판정식).
FAKE_INV = {
    'schemas': ['BRONZE_AGENCY', 'BRONZE_BIGQUERY', 'BRONZE_CRM', 'GOLD', 'SERVING', 'SILVER'],
    'objects': {
        'BRONZE_AGENCY': ['DGT_AD_CMPGN_DTLS'],
        'BRONZE_BIGQUERY': [],
        'BRONZE_CRM': ['TM_CM_MBER_DVLP_GOAL'],
        'GOLD': ['WIDE_AD_COMBINED'],
        'SERVING': ['ML_DVLP_FORECAST_V'],
        'SILVER': ['BIGQUERY_REFINED_DATA', 'GA4_BASIC'],
    },
}

SPEC_HEAD = 'models:\n  orchestration: auto\ninstructions:\n'


def spec(system='x', description='y'):
    """표면 2곳(`instructions.system` · `tools[0].tool_spec.description`)을 따로 채운다."""
    return (SPEC_HEAD
            + '  system: "%s"\n' % system
            + 'tools:\n- tool_spec:\n    type: cortex_analyst_text_to_sql\n'
            + '    name: analyst_x\n'
            + "    description: '%s'\n" % description)


def _run(tmpdir, spec_text, inv=None, known_absent=None, neg=None, not_table_reason=None):
    d = os.path.join(tmpdir, 'cortex_project/agents/A_TEST')
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, 'agent_spec.yaml'), 'w', encoding='utf-8').write(spec_text)

    o_root, o_glob, o_ka, o_neg = G.ROOT, G.AGENT_GLOB, G.KNOWN_ABSENT, G.NEG_RE
    o_ntr = G.NOT_TABLE_REASON
    G.ROOT = tmpdir
    G.AGENT_GLOB = os.path.join(tmpdir, 'cortex_project/agents/*/agent_spec.yaml')
    if known_absent is not None:
        G.KNOWN_ABSENT = known_absent
    if neg is not None:
        G.NEG_RE = neg
    if not_table_reason is not None:
        G.NOT_TABLE_REASON = not_table_reason
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            rc = G.run(inv=inv if inv is not None else FAKE_INV, verbose_advisory=True)
    finally:
        G.ROOT, G.AGENT_GLOB, G.KNOWN_ABSENT, G.NEG_RE = o_root, o_glob, o_ka, o_neg
        G.NOT_TABLE_REASON = o_ntr
    return rc, buf.getvalue()


results = []


def check(name, cond, detail=''):
    results.append((name, cond, detail))
    print(('  🟢 PASS  ' if cond else '  🔴 FAIL  ') + name
          + ('  — %s' % detail if detail else ''))


print('=' * 72)
print('agent_object_ref_gate 음성 테스트 — 면제 3종 + 분모(표면) 축 포함')
print('=' * 72)

with tempfile.TemporaryDirectory() as td:
    rc, out = _run(td, spec(
        system='원천은 GN_DW.BRONZE_AGENCY.DGT_AD_CMPGN_DTLS 다',
        description='광고 팩트 GOLD.WIDE_AD_COMBINED 를 쓴다'))
    check('① 실재 객체만 쓰면 PASS(과탐 아님)', rc == 0, 'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    rc, out = _run(td, spec(system='GA4 원천은 GN_DW.BRONZE_GA4 다'))
    check('② 부재 스키마(BRONZE_GA4)를 ① blocking 으로 검출',
          rc == 1 and 'BRONZE_GA4' in out and '스키마 라이브 부재' in out, 'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    # 🔴 면제㉠ 양방향 — 부정 서술이면 면제, 같은 토큰에서 부정어를 빼면 FAIL 이어야 한다.
    neg_txt = 'GN_DW.BRONZE_GA4 스키마는 실재하지 않는다'
    pos_txt = 'GN_DW.BRONZE_GA4 스키마에서 가져온다'
    rc_n, out_n = _run(td, spec(system=neg_txt))
    rc_p, out_p = _run(td, spec(system=pos_txt))
    check('③ 부정서술 면제 = PASS · 부정어 제거 = FAIL(면제가 무력화 아님)',
          rc_n == 0 and rc_p == 1, '부정 rc=%d · 긍정 rc=%d' % (rc_n, rc_p))

with tempfile.TemporaryDirectory() as td:
    # 🔴🔴 [O121-B 신설] 면제㉠ **과대 여부**를 단정한다.
    #    초판 `NEG_RE` 는 `없다|없고|부재` 를 맨 토큰으로 가져서 **객체와 무관한 부정어**로도
    #    면제됐다(무력화 경로). 좁힌 뒤에는 아래 ㉠은 FAIL 이고 ㉡㉢은 계속 면제여야 한다.
    wide = 'GN_DW.BRONZE_GA4 로 답한다. 캠페인 축이 없다'
    keep1 = 'GN_DW.BRONZE_GA4 라는 스키마는 실재하지 않는다'
    keep2 = 'GN_DW.BRONZE_GA4 는 테이블이 없고 대체 경로를 쓴다'
    rc_w, _ = _run(td, spec(system=wide))
    rc_k1, _ = _run(td, spec(system=keep1))
    rc_k2, _ = _run(td, spec(system=keep2))
    check('③-B 🔴 객체와 무관한 부정어는 더는 면제하지 않는다(과대 면제 차단)',
          rc_w == 1 and rc_k1 == 0 and rc_k2 == 0,
          '무관부정 rc=%d · 실재하지않 rc=%d · 테이블이없 rc=%d' % (rc_w, rc_k1, rc_k2))

with tempfile.TemporaryDirectory() as td:
    rc, out = _run(td, spec(description='광고 팩트(GOLD.FACT_AD_COMBINED)를 쓴다'))
    check('④ 부재 객체(GOLD.FACT_AD_COMBINED)를 ② blocking 으로 검출',
          rc == 1 and 'FACT_AD_COMBINED' in out and '객체 라이브 부재' in out, 'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    # 스키마를 잘못 적은 경우 — 같은 이름이 다른 스키마에 있으면 그것을 알려야 한다.
    rc, out = _run(td, spec(description='GA 기반은 GOLD.GA4_BASIC 이다'))
    check('⑤ 스키마 오배치를 검출하고 실제 소재를 알린다',
          rc == 1 and '스키마가 틀렸다' in out and 'SILVER' in out, 'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    # 🔴🔴 O121 실사고 재현 — 표면이 description 이든 instructions.system 이든 잡혀야 한다.
    rc_s, out_s = _run(td, spec(system='GA4 는 GN_DW.BRONZE_BIGQUERY.events_YYYYMMDD 다'))
    rc_d, out_d = _run(td, spec(description='GA4 는 GN_DW.BRONZE_BIGQUERY.events_YYYYMMDD 다'))
    check('⑥ 🔴 분모는 전문이다 — system·description 양쪽에서 검출(O120-B 실사고)',
          rc_s == 1 and rc_d == 1
          and 'events_YYYYMMDD' in out_s and 'events_YYYYMMDD' in out_d,
          'system rc=%d · description rc=%d' % (rc_s, rc_d))

with tempfile.TemporaryDirectory() as td:
    # 🔴 면제㉡ 양방향 — SV 는 제외(오탐 회피)이지만 그것이 SERVING 전체를 끄지 않아야 한다.
    rc_sv, out_sv = _run(td, spec(description='semantic_view GN_DW.SERVING.SV_BUDGET 를 쓴다'))
    rc_nv, out_nv = _run(td, spec(description='뷰 GN_DW.SERVING.NOT_A_REAL_VIEW 를 쓴다'))
    check('⑦ SV 제외 = PASS · 같은 스키마의 비-SV 오기 = FAIL(제외가 스키마를 끄지 않는다)',
          rc_sv == 0 and rc_nv == 1 and 'NOT_A_REAL_VIEW' in out_nv,
          'SV rc=%d · 비SV rc=%d' % (rc_sv, rc_nv))

with tempfile.TemporaryDirectory() as td:
    # 🔴 면제㉢ 양방향 — KNOWN_ABSENT 등재는 면제, 비우면 FAIL.
    txt = spec(description='구 객체 GOLD.FACT_AD_COMBINED 를 쓴다')
    rc_ka, _ = _run(td, txt, known_absent={('GOLD', 'FACT_AD_COMBINED'): '사유'})
    rc_no, _ = _run(td, txt, known_absent={})
    check('⑧ KNOWN_ABSENT 등재 = 면제 · 미등재 = FAIL(무력화 아님)',
          rc_ka == 0 and rc_no == 1, '등재 rc=%d · 미등재 rc=%d' % (rc_ka, rc_no))

with tempfile.TemporaryDirectory() as td:
    # ③ 축 = advisory. 빈 스키마를 원천처럼 언급해도 종료코드를 바꾸지 않는다.
    rc, out = _run(td, spec(system='GA4 원천은 BRONZE_BIGQUERY 에 있다'))
    check('⑨ 빈 스키마 언급은 advisory(종료코드 무영향)',
          rc == 0 and '빈 스키마를 원천으로 발행 (advisory · 종료코드 무영향) — 1건' in out,
          'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    # ④ 축 = advisory. 미수식 UPPER_SNAKE 토큰이 blocking 이 되면 안 된다.
    rc, out = _run(td, spec(system='원천은 GN_DW.BRONZE_CRM(TM_XX_NO_SUCH_TABLE) 이다'))
    check('⑩ 미수식 테이블명은 advisory(종료코드 무영향)',
          rc == 0 and 'TM_XX_NO_SUCH_TABLE' in out, 'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    # ① 이 잡은 것을 ② 가 다시 세지 않는다 — 같은 결함을 두 번 발행하면 건수가 거짓이 된다.
    rc, out = _run(td, spec(system='GN_DW.BRONZE_GA4.SOME_TABLE 을 쓴다'))
    check('⑪ 부재 스키마 하위 객체를 중복 계상하지 않는다(① 1건만)',
          rc == 1 and out.count('스키마 라이브 부재') == 1
          and '객체 라이브 부재' not in out, 'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    # 축⑤ 관측 = 표면 인벤토리가 실제 표면을 나열하는가(분모 가시화가 살아 있는가).
    rc, out = _run(td, spec(system='x' * 250, description='y' * 250))
    check('⑫ 표면 인벤토리가 instructions.system 과 description 을 함께 나열',
          rc == 0 and 'instructions.system' in out
          and 'tools.[0].tool_spec.description' in out, 'rc=%d' % rc)

with tempfile.TemporaryDirectory() as td:
    # 🔴🔴 [O121-B 신설] 면제㉣ `NOT_TABLE_REASON` 양방향 — 규명 등재는 **잡음 끄기가 아니다.**
    #    등재하면 「규명」으로 분리되고, 등재를 비우면 **미규명으로 다시 올라와야** 한다.
    #    O121 은 이 6건을 「라이브 미포함 6건」으로만 보고하고 규명하지 않았다(자기결함 재현 축).
    txt = spec(system='원천은 GN_DW.BRONZE_CRM(TM_XX_PROBE_TOKEN) 이다')
    rc_reg, out_reg = _run(td, txt, not_table_reason={'TM_XX_PROBE_TOKEN': '테스트 사유'})
    rc_no, out_no = _run(td, txt, not_table_reason={})
    check('⑬ 규명 등재 = 미규명 0 · 등재 비우면 미규명으로 복귀(무력화 아님)',
          rc_reg == 0 and rc_no == 0
          and '미규명 0건 · 규명 등재 1건' in out_reg
          and '미규명 1건 · 규명 등재 0건' in out_no,
          '등재 rc=%d · 미등재 rc=%d' % (rc_reg, rc_no))

with tempfile.TemporaryDirectory() as td:
    # 🔴 축④ 는 advisory 이므로 미규명이 있어도 종료코드를 바꾸지 않는다 —
    #    그러나 **출력에 처방이 함께** 나와야 한다(처방 없는 경고 금지).
    rc, out = _run(td, spec(system='원천은 GN_DW.BRONZE_CRM(TM_YY_UNKNOWN_TOKEN) 이다'),
                   not_table_reason={})
    check('⑭ 미규명 advisory 가 처방을 함께 낸다(등재하거나 고쳐라)',
          rc == 0 and 'NOT_TABLE_REASON' in out and '사유와 함께' in out, 'rc=%d' % rc)

print('=' * 72)
bad = [n for n, c, _ in results if not c]
if bad:
    print('🔴 음성 테스트 실패 %d/%d: %s' % (len(bad), len(results), bad))
    sys.exit(1)
print('🟢 음성 테스트 %d/%d 통과 — 면제 **4종 전부 양방향**(과대 면제 차단 포함) + 분모(표면) 축'
      % (len(results), len(results)))
