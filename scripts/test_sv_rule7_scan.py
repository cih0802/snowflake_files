#!/usr/bin/env python3
"""sv_rule7_scan · sv_unit_gate 교차 일관성 음성 테스트 (2026-08-29 O119-B 신설 · R3-2)

🔴 **왜 필요한가**: O119 는 `sv_unit_gate`(COMMENT 수치 **0건**)만 보고 「SV COMMENT 규약 위반 종결」을
   선언했다. 같은 규칙을 재는 `sv_rule7_scan` 은 같은 시점에 **라이브 도달 위반 7건**을 냈다.
   ⇒ **게이트를 다 통과했다는 주장은 「내가 돌린 게이트」의 집합에만 유효하다**(`R3-9 ㉡` 실물).
   원인은 백분율 패턴이 두 벌이었던 것이고, 7건은 전부 **오탐**(신뢰구간 수준 6 · `0%` 1)이었다.

축1 예외 유효   — 신뢰구간 수준·`0%` 가 면제된다(오탐 제거).
축2 무력화 아님 — 그 예외가 **진짜 실측 백분율을 통과시키지 않는다**(예외가 규칙을 죽이지 않았다).
축3 교차 일관성 — 두 게이트가 **같은 문안에 같은 판정**을 낸다(이번 결함의 재발 방지 축).
축4 공유 실증   — `sv_rule7_scan` 이 `sv_unit_gate.NUM_EXEMPT` 를 **같은 객체로** 쓴다(복제 0).
축5 라이브 축   — 실제 SV DDL 에서 라이브 도달 위반이 0 이고 blocking 경로가 살아 있다.
축6 표면 분리   — 문서 주석(`--`)은 blocking 이 아니다(라이브 미도달).
"""
import sys
from pathlib import Path

sys.path.insert(0, "/workspace/scripts")

import sv_unit_gate as U
import sv_rule7_scan as R

FAILS, ASSERTS = [], 0


def check(cond, label):
    global ASSERTS
    ASSERTS += 1
    if not cond:
        FAILS.append(label)
        print(f"  🔴 FAIL  {label}")
    else:
        print(f"  🟢 ok    {label}")


def r7_hits(text):
    """sv_rule7_scan 의 판정(= audit_ddl_rule7.NUM + 공유 NUM_EXEMPT)."""
    return [t for _n, t, _p in R.violations(text)]


def unit_hits(text):
    """sv_unit_gate 의 판정(= NUM_BAN + 공유 NUM_EXEMPT)."""
    bad, _ex = U.scan_numbers(text)
    return sorted(bad)


EXEMPT_CASES = [
    ("95% 신뢰구간 하한 합계(만원). 별개 실적이 아니다.", "신뢰구간 수준(95%)"),
    ("99% 신뢰구간 상한.", "신뢰구간 수준(99%)"),
    ("목표가 0 인 구간은 미편성으로 표기한다(달성율 0% 나 무한대로 표기하지 않는다).", "표기 규약 0%"),
]
REAL_CASES = [
    ("커버리지 89.34% 로 채워져 있다.", "실측 소수 백분율"),
    ("회원 20.83% 가 복수 후원을 보유한다.", "실측 소수 백분율"),
    ("적재 행수 2,170,572 행이다.", "실측 천단위 행수"),
    ("다중 캠페인 137건.", "실측 건수(단위 뒤가 비단어)"),
    ("고아 31,486명이다.", "실측 천단위 + 한국어 서술어(천단위 축이 잡는다)"),
    ("전환율은 95.5% 다.", "실측 소수 백분율(신뢰구간 아님)"),
    ("상위 구간 비중 12% 다.", "실측 정수 백분율(신뢰구간 아님)"),
]

print("== 축1 예외 유효 (오탐이 사라지는가)")
for text, why in EXEMPT_CASES:
    check(not r7_hits(text), f"[rule7] 면제됨 — {why}")
    check(not unit_hits(text), f"[unit ] 면제됨 — {why}")

print("== 축2 무력화 아님 (예외가 규칙을 죽이지 않았는가)")
for text, why in REAL_CASES:
    hits = r7_hits(text)
    check(bool(hits), f"[rule7] 여전히 검출 — {why} {hits}")

print("== 축3 교차 일관성 (두 게이트가 같은 답을 내는가)")
for text, why in EXEMPT_CASES:
    a, b = bool(r7_hits(text)), bool(unit_hits(text))
    check(a == b, f"판정 일치({a}=={b}) — {why}")
# 🔴 정수 백분율은 두 게이트의 패턴 폭이 원래 다르다(rule7 = 정수 허용 · unit = 소수 필수).
#   그 차이 자체는 설계이며, **면제 대상에서 두 게이트가 갈리지 않는 것**이 이 축의 요구다.
print("   ⚠️ 정수 백분율의 검출 폭 차이는 설계다 — 이 축은 「면제 판정이 갈리지 않는가」만 본다.")

print("== 축4 공유 실증 (예외 목록을 복제하지 않았는가)")
check(R.NUM_EXEMPT is U.NUM_EXEMPT, "sv_rule7_scan.NUM_EXEMPT is sv_unit_gate.NUM_EXEMPT (동일 객체)")

print("== 축5 라이브 축 (실제 SV DDL)")
live_total = 0
for p in R.TARGETS:
    raw = Path(p).read_text(encoding="utf-8")
    for m in R.CMT.finditer(raw):
        live_total += len(R.violations(m.group(1)))
print(f"   라이브 도달 위반 = {live_total}건")
check(live_total == 0, "실제 SV DDL 의 라이브 도달 위반 0건")

print("== 축6 표면 분리 (문서 주석은 blocking 이 아니다)")
doc_sample = "-- 실측 89.34% · 2,170,572행 (문서 주석이므로 라이브에 도달하지 않는다)"
check(bool(r7_hits(doc_sample)), "문서 주석의 실측치도 토큰으로는 검출된다(관측 축은 살아 있다)")
check("sys.exit(1)" in Path("/workspace/scripts/sv_rule7_scan.py").read_text(encoding="utf-8"),
      "라이브 축 blocking 경로(sys.exit(1))가 실재한다")
src = Path("/workspace/scripts/sv_rule7_scan.py").read_text(encoding="utf-8")
check("if tot_live:" in src and "if tot_doc:" not in src,
      "blocking 조건이 tot_live 뿐이다(문서 주석은 막지 않는다)")

print("== 축7 알려진 사각지대 (🔴 완화하지 마라 — O119-B 가 영향 범위를 실측했다)")
# 🔴🔴 공유 「소규모」 패턴 `(?<![\d,§#])\d+\s*(?:행|건|명|원)\b` 는 **한국어 조사·서술어가 붙으면
#   놓친다** — `건`·`행` 다음 글자가 한글이면 `\b` 가 성립하지 않는다(`137건이다` 미검출).
#   두 게이트가 **같은 한계를 공유**하므로 교차검증으로도 드러나지 않는다.
# 🟢 **그러나 완화가 정답이 아니다.** O119-B 가 라이브 도달 COMMENT 전수에서 실측했다:
#     `\b` → `(?![0-9])` 로 완화하면 **신규 검출 9건이 전부 오탐**이고 진짜 검출은 **0건**이다.
#     오탐 정체 = `CM013 원천` → `013 원` (코드사전 ID + 「원천」) **6건** · grain 서술 `1행` **3건**.
# 🟢 **잔여 위험이 작은 이유** = 「천단위」 축은 `\b` 가 없어 조사와 무관하게 잡는다
#     (`31,486명이다` 검출됨) ⇒ 사각지대는 **쉼표 없는 소규모 수치 + 조사** 조합으로 한정된다.
# 🔴 다음 세션이 완화하려면 **먼저 `CM\d+` 코드사전 접두와 grain 변형을 예외로 추가**해야 하고,
#   그때도 이 축의 수치를 **다시 실측**해 오탐:진탐 비를 근거로 판단하라(값을 여기 믿지 말고 재라).
check(not r7_hits("다중 캠페인 137건이다."), "알려진 사각지대 재현 — 조사가 붙은 소규모 건수는 미검출")
check(bool(r7_hits("고아 31,486명이다.")), "완화 불요 근거 — 천단위 축이 조사와 무관하게 잡는다")

print()
print(f"단정 {ASSERTS}건 · 실패 {len(FAILS)}건")
if FAILS:
    print("🔴 테스트 실패")
    sys.exit(1)
print("🟢 테스트 통과")