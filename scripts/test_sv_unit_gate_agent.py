# -*- coding: utf-8 -*-
"""[2026-09-15 O164] `sv_unit_gate.judge_agent_surface` 음성 테스트.

🔴 왜 이 테스트가 필요한가(`R3-2` · 절차서 §5-1):
   이 축의 판정은 **여러 세션 동안 인라인**이어서 라이브 없이 단정할 수 없었다.
   그 결과 **결함 두 개가 검사되지 않은 채 살아 있었다**(O164 `D7`):
     ㉠ 판정식이 **총수 리터럴 부분문자열**(`'11종' in comment`)이라
        분해 표기(`실적 SV 8종 … + ML 예측 3종 …`)를 **내용이 옳은데 FAIL** 시켰다.
     ㉡ 기대 표 키가 **`AGENT_OVERALL`** 이었고 라이브 실물은 **`AGENT_EXECUTIVE`** 여서
        그 Agent 는 **조용히 검사되지 않았다**(`.get()` → None → skip).

🟢 축1·축2 가 「고치기 전 코드에서 반드시 실패하는」 축이다.
🔴 라이브에 붙지 않는다 — Agent 목록을 **주입**한다.
"""
import sys

sys.path.insert(0, '/workspace/scripts')
import sv_unit_gate as G

# 라이브 실물(2026-09-15 `SHOW AGENTS IN SCHEMA GN_DW.SERVING`)을 축약 재현.
LIVE = [
    ('AGENT_MEMBER',
     '굿네이버스 회원 도메인 분석 Agent. 실적 SV 8종(월실적·상태전이) '
     '+ 머신러닝(ML) 예측 3종(회원단위 이탈위험) 종합 분석.'),
    ('AGENT_EXECUTIVE',
     '굿네이버스 전사 경영/재무 요약 및 AI 미래 예측 Agent. 실적 SV 4종(예산편성) '
     '+ 머신러닝(ML) 미래예측 4종(개발금액전망) 종합 지원.'),
    ('AGENT_MARKETING',
     '굿네이버스 마케팅/광고 분석 Agent. SV 7종: 광고효율 종합 분석.'),
]


def noop_scanner(_text):
    """`scan_numbers` 호환 — 수치 축은 이 테스트의 대상이 아니다."""
    return set(), set()


RESULTS = []


def check(name, agents, want_n, expect_sub=None, expect_not_sub=None, expected_map=None):
    saved = G.EXPECTED_AGENT_SVS
    if expected_map is not None:
        G.EXPECTED_AGENT_SVS = expected_map
    try:
        bad = G.judge_agent_surface(agents, noop_scanner)
    finally:
        G.EXPECTED_AGENT_SVS = saved
    blob = ' | '.join(f'{a} {b}' for a, b in bad)
    ok = (len(bad) == want_n)
    detail = f'결함 {len(bad)}건 (기대 {want_n})'
    if ok and expect_sub:
        for t in expect_sub:
            if t not in blob:
                ok, detail = False, f'{detail} · 출력에 `{t}` 부재'
                break
    if ok and expect_not_sub:
        for t in expect_not_sub:
            if t in blob:
                ok, detail = False, f'{detail} · 출력에 `{t}` 존재(오탐)'
                break
    RESULTS.append(ok)
    print(('  🟢 ' if ok else '  🔴 ') + f'{name} — {detail}')
    if not ok and blob:
        print(f'       ▸ {blob[:300]}')


print('=' * 72)
print('[음성 테스트] sv_unit_gate.judge_agent_surface')
print('=' * 72)

# 🔴 축1 = D7 ㉠ 재현: 분해 표기를 오탐하면 안 된다(종전 코드는 여기서 FAIL 했다)
check('축1 분해 표기(8종+3종=11) → 오탐 0 이어야 한다', LIVE, 0,
      expect_not_sub=['AGENT_MEMBER'])

# 🔴 축2 = D7 ㉡ 재현: 기대 표 키 오기는 「조용한 미검사」가 아니라 FAIL 이어야 한다
check('축2 기대 표 키 오기(AGENT_OVERALL) → 유령 등재 FAIL', LIVE, 1,
      expect_sub=['AGENT_OVERALL', '라이브에 없다'],
      expected_map={'AGENT_MEMBER': 11, 'AGENT_OVERALL': 8, 'AGENT_MARKETING': 7})

# 🔴 축3 = 검사를 끄지 않았다는 단정 — 합이 틀리면 반드시 잡는다
check('축3 분해 합 불일치(8종+2종=10 ≠ 11) → FAIL', [
    ('AGENT_MEMBER', '실적 SV 8종 + ML 예측 2종.'),
    ('AGENT_EXECUTIVE', '실적 SV 4종 + ML 4종.'),
    ('AGENT_MARKETING', 'SV 7종.'),
], 1, expect_sub=['합 10', '기대 총수 11'])

# 🟢 축4 = 총수 단일 표기도 통과해야 한다(두 서식을 모두 허용한다는 단정)
check('축4 총수 단일 표기(11종) → 통과', [
    ('AGENT_MEMBER', '회원 도메인 Agent. 소관 SV 11종.'),
    ('AGENT_EXECUTIVE', '실적 SV 4종 + ML 4종.'),
    ('AGENT_MARKETING', 'SV 7종.'),
], 0)

# 🔴 축5 = 총수와 분해가 함께 적힌 경우(합이 부풀어도 총수 일치로 통과)
check('축5 총수+분해 병기(11종 = 8종+3종) → 통과(경계)', [
    ('AGENT_MEMBER', '소관 SV 11종 — 실적 8종 + ML 3종.'),
    ('AGENT_EXECUTIVE', '실적 SV 4종 + ML 4종.'),
    ('AGENT_MARKETING', 'SV 7종.'),
], 0)

# 🔴 축6 = 선언 자체가 없으면 FAIL(침묵 통과 금지)
check('축6 종수 선언 부재 → FAIL', [
    ('AGENT_MEMBER', '회원 도메인 분석 Agent.'),
    ('AGENT_EXECUTIVE', '실적 SV 4종 + ML 4종.'),
    ('AGENT_MARKETING', 'SV 7종.'),
], 1, expect_sub=['선언 부재'])

# 🔴 축7 = 기대 표에 없는 Agent 는 무시한다(분모 밖 오탐 0)
check('축7 기대 표 밖 Agent → 오탐 0', LIVE + [('AGENT_SANDBOX', '실험용.')], 0)

# 🔴 축8 = 빈 입력이면 기대 3종 전부 유령으로 잡힌다(조용한 0 금지)
check('축8 빈 입력 → 유령 3건', [], 3, expect_sub=['라이브에 없다'])

print('=' * 72)
failed = sum(1 for ok in RESULTS if not ok)
print(f'{"🔴" if failed else "🟢"} 축 {len(RESULTS)}개 · 실패 {failed}건')
sys.exit(1 if failed else 0)
