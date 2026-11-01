#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SV DDL(`05_*_SV_DDL_*.sql`·`22_ML_SV_DDL.sql`) 의 규칙7 위반을 **라이브 도달 여부로 분리**해 계수한다.
Co-authored with CoCo

왜 필요한가 (2026-08-28 O105)
  `audit_ddl_rule7` 의 분모는 `06_DDL.sql`(GOLD) + SILVER DDL 뿐이고 **SV DDL 은 아예 없다**
  ⇒ SV COMMENT 에 실측 수치가 들어가도 **어떤 게이트도 잡지 않는다**(O59-N 이 SILVER 에서 겪은 것과 동형).
  그런데 SV COMMENT 는 Cortex Analyst 가 프롬프트 context 로 **직접 읽는 표면**이라 stale 수치의
  오답 파급이 GOLD DDL 보다 크다.

🔴 라이브 도달 여부를 반드시 분리한다
  · `COMMENT = '...'` / `COMMENT='...'` 안의 문자열  → **라이브에 실린다 = 진짜 위반**
  · 줄 앞이 `--` 인 SQL 주석                          → 라이브 미도달 = 문서 stale(경고 등급)
  이 구분 없이 총계만 세면 **위반 규모를 과대**하게 보고한다(분모 오염 · `P128` 축).

사용법
  python3 scripts/sv_rule7_scan.py            # 요약
  python3 scripts/sv_rule7_scan.py --detail   # 스니펫까지
"""
import glob
import re
import sys

sys.path.insert(0, "/workspace/scripts")
from sv_unit_gate import NUM_EXEMPT  # noqa: E402  의미 예외를 1벌로 공유(O59-E 선례)
import audit_ddl_rule7 as rule7  # noqa: E402  위반 패턴(NUM 4축)을 1벌로 공유

TARGETS = sorted(glob.glob("/workspace/05_SV-Agent_ai/05_*_SV_DDL_*.sql")) + [
    "/workspace/05_SV-Agent_ai/22_ML_SV_DDL.sql"
]

# COMMENT = '...' 의 값 구간. SV DDL 은 홑따옴표 리터럴을 쓰고 내부 이스케이프는 '' 이다.
# 🔴🔴 [2026-08-28 O105 자기적발] 초판은 `COMMENT =` 만 봤고 **`AI_SQL_GENERATION` 지시문을 놓쳤다.**
#   그 지시문도 SV 에 저장돼 Cortex Analyst 가 읽는 **라이브 도달 표면**이고, 실제로 그 안에
#   `약 36%` 가 있었는데 초판 스캔은 그것을 「문서 주석」 버킷으로 오분류했다
#   ⇒ **게이트를 만든 그 자리에서 게이트의 분모를 의심해야 한다**(`P224`·`P106`).
#   구문 주의: `COMMENT` 는 `=` 를 쓰지만 `AI_SQL_GENERATION`·`AI_QUESTION_CATEGORIZATION` 은
#   `=` 없이 리터럴이 바로 온다 ⇒ `=` 를 선택적으로 둔다.
CMT = re.compile(
    r"(?:COMMENT|AI_SQL_GENERATION|AI_QUESTION_CATEGORIZATION)\s*=?\s*'((?:[^']|'')*)'",
    re.S,
)


def spans_exempt(text):
    return [(m.start(), m.end()) for pat, _ in NUM_EXEMPT for m in pat.finditer(text)]


def violations(text):
    """그 문자열 안의 규칙7 위반 토큰을 (축, 토큰, 위치) 로 돌려준다."""
    ex = spans_exempt(text)
    out = []
    for name, pat in rule7.NUM:
        for m in pat.finditer(text):
            if any(a <= m.start() < b for a, b in ex):
                continue
            out.append((name, m.group(0), m.start()))
    return out


def main() -> None:
    detail = "--detail" in sys.argv
    tot_live = tot_doc = 0
    print("=" * 78)
    print("SV DDL 규칙7 스캔 — 라이브 도달(COMMENT) ↔ 문서 주석(--) 분리")
    print("=" * 78)
    for p in TARGETS:
        raw = open(p, encoding="utf-8").read()
        # 1) 라이브 도달분 = COMMENT 리터럴 안
        live = []
        for m in CMT.finditer(raw):
            body = m.group(1)
            line = raw[: m.start()].count("\n") + 1
            for name, tok, _ in violations(body):
                live.append((line, name, tok))
        # 2) 문서 주석분 = '--' 로 시작하는 줄 중 COMMENT 리터럴에 걸리지 않는 것
        cmt_spans = [(m.start(), m.end()) for m in CMT.finditer(raw)]
        doc = []
        off = 0
        for i, s in enumerate(raw.split("\n"), 1):
            if s.lstrip().startswith("--"):
                inside = any(a <= off < b for a, b in cmt_spans)
                if not inside:
                    for name, tok, _ in violations(s):
                        doc.append((i, name, tok))
            off += len(s) + 1
        tot_live += len(live)
        tot_doc += len(doc)
        if live or doc:
            print(f"\n## {p.split('/')[-1]}  라이브 {len(live)} · 문서주석 {len(doc)}")
            if detail:
                for r in live:
                    print(f"   🔴 LIVE  L{r[0]:<5} {r[1]:<5} {r[2]}")
                for r in doc:
                    print(f"   🟠 DOC   L{r[0]:<5} {r[1]:<5} {r[2]}")
    print("\n" + "=" * 78)
    print(f"🔴 라이브 도달 위반(진짜 위반) = {tot_live}건")
    print(f"🟠 문서 주석 stale(경고)      = {tot_doc}건")
    print("=" * 78)
    # 🔴🔴 [2026-08-29 O119-B] **라이브 축을 blocking 으로 승격했다** — 이 스캐너의 자체 TODO 이행.
    #   종전 문안 = *"아직 blocking 게이트가 아니다 — 기지 부채가 커서 0 을 요구하면 매번 실패한다.
    #   처방 = SILVER_BASELINE 선례대로 기준선을 두고 신규 유입만 실패시킬 것."*
    #   🟢 **기준선이 불필요해졌다** — O119-B 가 라이브 도달 위반 **7 → 0** 으로 만들었고,
    #     그 7건은 부채가 아니라 **공유 예외 누락으로 인한 오탐**이었다(신뢰구간 수준 6 · `0%` 1).
    #     ⇒ 기준선을 두면 「오탐을 부채로 등재」하게 되므로 **예외를 고치는 것이 옳은 처방**이었다
    #       (`sv_unit_gate` 의 `CMT_BASELINE` 이 `10,000` 을 부채로 등재했던 O59-E 실패와 같은 축).
    #   🔴 **문서 주석(`--`)은 blocking 이 아니다** — 라이브에 도달하지 않으므로 Agent 오답 경로가 없다.
    #     그 47건은 경고로 남긴다(기지 부채이고 성격이 다르다).
    #   ⚠️ **왜 라이브만 막는가** = 이 규칙의 취지는 「Analyst 가 프롬프트 context 로 읽는 문안에
    #     적재량을 박지 마라」다 ⇒ 판정 축은 **라이브 도달 여부**이고 파일 존재 여부가 아니다.
    if tot_live:
        print("🔴 게이트 실패 — 라이브 도달 위반은 blocking 이다(Analyst 가 읽는 표면이다).")
        print("   🔴 판정 전에 그 토큰이 **실측치인가 정의·관례인가**를 가려라 —")
        print("      정의·관례이면 `sv_unit_gate.NUM_EXEMPT`(두 게이트 공유)에 예외를 추가한다.")
        sys.exit(1)
    print("✅ 게이트 통과 — 라이브 도달 위반 0건")
    print("🟠 문서 주석 stale 은 blocking 이 아니다(라이브 미도달 · 기지 부채) — 경고로만 낸다.")


if __name__ == "__main__":
    main()
