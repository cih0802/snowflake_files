#!/usr/bin/env python3
"""agent_tool_claim_gate 음성 테스트 (2026-08-29 O119 신설 · R3-2)

🔴 **왜 필요한가**: O119 가 시정한 결함은 **정상 입력으로는 보이지 않는다.**
   두 스펙의 문안이 실질적으로 같았는데 게이트가 blocking 모순을 냈고, 갈린 원인은
   **YAML 물리적 줄바꿈 위치**뿐이었다. 게이트를 그냥 돌리면 「FAIL 1건」만 보이고
   그것이 오탐인지 알 수 없다 ⇒ **줄바꿈만 옮긴 대조군**을 넣어야 드러난다.

축1 wrap 불변성  — 같은 문안의 줄바꿈 위치를 옮겨도 stance 가 바뀌지 않는다(회귀 방지).
축2 오탐 재현    — 시정 전 구현(줄바꿈 미접기)에서는 판정이 갈렸음을 실증한다.
축3 태도 감지    — 순수 긍정/순수 부정/무언급을 각각 +1/-1/0 으로 읽는다(기능 보존).
축4 개념 미등장  — 개념이 없으면 0 이다(문서 전체의 '불가' 에 오염되지 않는다).
축5 라이브 판정  — 실제 스펙에서 「후원사업별」 blocking 모순이 0 건이다.
"""
import re
import sys
from itertools import combinations

sys.path.insert(0, "/workspace/scripts")

import agent_tool_claim_gate as G

FAILS = []
ASSERTS = 0


def check(cond, label):
    global ASSERTS
    ASSERTS += 1
    if not cond:
        FAILS.append(label)
        print(f"  🔴 FAIL  {label}")
    else:
        print(f"  🟢 ok    {label}")


def legacy_stance(desc, concept):
    """시정 전 구현 — 줄바꿈을 접지 않는다. 축2 의 대조군 전용이다."""
    st = 0
    for sent in re.split(r"(?<=[.。·\n])", desc):
        if concept not in sent:
            continue
        neg = any(c in sent for c in G.NEG_CUES)
        pos = any(c in sent for c in G.POS_CUES)
        if neg and not pos:
            return -1
        if pos and not neg:
            st = 1
    return st


# 같은 문안 · 줄바꿈 위치만 다른 두 판본(실제 두 스펙의 형태를 축약 재현).
WRAP_A = (
    "회원×후원약정 팩트. 🔴 **캠페인별/후원사업별 활동회원 수의 정본 도구**다.\n"
    "      이 도구의 캠페인·후원사업별 합계는 다중후원 정상현상으로 서로 겹칠 수 있다(N 비가산 — SUM 금지, 같게 기대하지 말 것)."
)
WRAP_B = (
    "회원×후원약정 팩트. 🔴 **캠페인별/후원사업별 활동회원 수의 정본 도구**다.\n"
    "      이 도구의 캠페인·후원사업별 합계는 다중후원 정상현상으로 전체 활동회원수보다\n"
    "      클 수 있다(N 비가산, SUM 금지)."
)

print("== 축1 wrap 불변성 (같은 문안 · 줄바꿈 위치만 다름)")
sa = G.stance(WRAP_A, "후원사업별")
sb = G.stance(WRAP_B, "후원사업별")
print(f"   stance(A)={sa}  stance(B)={sb}")
check(sa == sb, "줄바꿈 위치를 옮겨도 stance 동일 (wrap 무관)")
# 🔴🔴 [2026-08-29 O119-B 추가] **일치만으로는 부족하다 — 「무엇으로」 일치하는지도 본다.**
#   O119 초판은 둘을 `-1`(불가)로 일치시켰고 그것은 **사실과 반대**였다(문안은 「분해 가능하다」).
#   ⇒ 이 단정이 O119 초판을 실패시킨다(회귀 방지의 핵심).
check(sa == 1, "일치 방향이 옳다 — 「분해 가능하다」 문안은 +1(가능)이어야 한다")

print("== 축2 오탐 재현 (시정 전 구현에서는 갈렸다)")
la = legacy_stance(WRAP_A, "후원사업별")
lb = legacy_stance(WRAP_B, "후원사업별")
print(f"   legacy(A)={la}  legacy(B)={lb}")
check(la != lb, "시정 전 구현은 판정이 갈린다 = 이 테스트가 진짜 결함을 재현한다")

print("== 축3 태도 감지 (기능 보존)")
check(G.stance("후원사업별 분해는 산출된다. 정본 도구다.", "후원사업별") == 1, "순수 긍정 = +1")
check(G.stance("후원사업별 분해는 원천에 축이 부재해 산출 불가다.", "후원사업별") == -1, "순수 부정 = -1")
check(G.stance("후원사업별 축이 존재한다.", "후원사업별") == 0, "단서 없음 = 0")

print("== 축4 개념 미등장 (다른 문장의 부정에 오염되지 않는다)")
check(G.stance("소재별 분해는 불가하다. 개발단가는 산출된다.", "후원사업별") == 0,
      "개념이 없으면 0 (문서 전체의 '불가' 에 오염 0)")

print("== 축5 라이브 판정 (실제 스펙에서 모순 0)")
tools = G.load_tools()
by_sv = {}
for agent, tool, sv, desc in tools:
    by_sv.setdefault(sv, []).append((agent, tool, desc))
bad = []
for sv, v in by_sv.items():
    if len(v) < 2:
        continue
    for (a1, _t1, d1), (a2, _t2, d2) in combinations(v, 2):
        s1, s2 = G.stance(d1, "후원사업별"), G.stance(d2, "후원사업별")
        if s1 and s2 and s1 != s2:
            bad.append(f"{sv}: {a1}={s1} ↔ {a2}={s2}")
print("   「후원사업별」 모순 {}건 {}".format(len(bad), bad))
check(not bad, "라이브 스펙에서 「후원사업별」 blocking 모순 0건")

print("== 축8 가산성 분리 (O119-B 신설 · 진짜 부정을 잃지 않는가)")
# 🟢 가산성만 말하는 문장 ⇒ 「불가」가 아니다.
check(G.stance("후원사업별 합계는 N 비가산이므로 SUM 금지, 같게 기대하지 말 것.", "후원사업별") == 0,
      "가산성만 말하는 문장은 중립(0) — 「불가」로 읽지 않는다")
# 🔴 가산성 단서가 있어도 **무관한 진짜 부정**이 있으면 -1 이어야 한다(부정 감지를 끄지 않았다).
check(G.stance("후원사업별 목표는 원천에 축이 부재하다. 그리고 합계는 비가산이니 SUM 금지.",
               "후원사업별") == -1,
      "진짜 부정(원천 축 부재)은 가산성 단서와 무관하게 살아 있다")
# 🔴 긍정 + 가산성 경고 조합 ⇒ 긍정으로 읽어야 한다(실제 스펙의 형태).
check(G.stance("후원사업별 분해는 정본 도구다. 다만 합계는 비가산이라 SUM 금지.", "후원사업별") == 1,
      "긍정 + 가산성 경고 = +1 (실제 스펙 형태)")
check(bool(G.ADDITIVITY_CUES), "ADDITIVITY_CUES 가 선언돼 있다")

print("== 축9 축③ 스펙 표면 규칙7 (O119-B 신설 · 형제 표면 편입)")
# 🔴 이 표면은 O119-B 전까지 **어느 게이트 분모에도 없었다**(P194 형제 표면).
#   착수 시 8건 → 판정 결과 진짜 1건(`+18.5%`) + 오탐 7건 ⇒ 진짜 제거 + 예외 정비로 0.
import sv_rule7_scan as _R  # noqa: E402
check(_R.NUM_EXEMPT is __import__("sv_unit_gate").NUM_EXEMPT,
      "축③ 예외가 sv_unit_gate.NUM_EXEMPT 와 동일 객체다(3게이트 공유 · 복제 0)")
live_r7 = [t for _a, _t, _s, d in tools for _n, t, _p in _R.violations(d)]
print(f"   스펙 description 규칙7 위반 = {len(live_r7)}건 {live_r7[:6]}")
check(not live_r7, "라이브 스펙 description 규칙7 위반 0건")
# 🔴 무력화 방지 — 스펙 문안에 실측치를 넣으면 잡혀야 한다.
check(bool(_R.violations("합치면 청구액이 과대계상된다(실측 +18.5%).")),
      "무력화 아님 — 스펙 문안의 실측 백분율은 여전히 검출된다")
check(not _R.violations("회원 획득 코호트 팩트(FMC, grain=**회원 1행**)."),
      "grain 정의(grain 이 앞)는 면제된다")
check(bool(_R.violations("grain 기준 적재 2,170,572행이다.")),
      "무력화 아님 — grain 근방의 **큰 수**는 면제되지 않는다(자릿수 제한이 작동한다)")

print()
print(f"단정 {ASSERTS}건 · 실패 {len(FAILS)}건")
if FAILS:
    print("🔴 테스트 실패")
    sys.exit(1)
print("🟢 테스트 통과")
