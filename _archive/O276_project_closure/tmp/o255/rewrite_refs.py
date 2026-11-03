#!/usr/bin/env python3
"""O255 · 배포순서 파일 이름 변경 후 현행 문서의 참조를 새 이름으로 치환한다.
대상 = 현행(정본·실행) 문서만 · 이력(20_issue/·99_NEXT_SESSION_조각/·_archive/·80·85 산출물)은 원문 무변경 원칙으로 제외.
기본 = dry-run(파일별 건수) · --apply 로 쓰기 · 쓰기 직후 되읽어 옛 이름 0 · 새 이름 건수 = 치환 건수 확인.
"""
import sys
sys.path.insert(0, "/workspace/tmp/o255")
from rename_deploy import MAP  # noqa: E402  (같은 표를 공유한다)

STEMS = [(o[:-4], n[:-4]) for o, n in MAP]
FILES = [
    "문서실행순서.md",
    "문서실행순서_llm실행.md",
    "문서실행순서_보조주석.md",
    "05_SV-Agent_ai/00_README.md",
    "05_SV-Agent_ai/05_27_SV_DDL_AD_INFLOW_ALLOC.sql",
    "05_SV-Agent_ai/05_28_SV_DDL_MEMBER_EVENT_COHORT.sql",
    "05_SV-Agent_ai/05_29_SV_DDL_ML_MEMBER_PRED_AXIS.sql",
    "05_SV-Agent_ai/05_30_SV_DDL_ML_FEE_FORECAST_AXIS.sql",
    "05_SV-Agent_ai/09_2_AGENT_버전업.sql",
    "05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql",
] + ["05_SV-Agent_ai/" + n for _, n in MAP]
apply = "--apply" in sys.argv
total = 0
for rel in FILES:
    p = "/workspace/" + rel
    src = open(p, encoding="utf-8").read()
    dst, n = src, 0
    for o, nw in STEMS:
        k = dst.count(o)
        n += k
        dst = dst.replace(o, nw)
    total += n
    if not n:
        print(f"   0  {rel}"); continue
    if apply:
        with open(p, "w", encoding="utf-8") as w:
            w.write(dst)
        back = open(p, encoding="utf-8").read()
        left = sum(back.count(o) for o, _ in STEMS)
        print(("🟢" if back == dst and left == 0 else "🔴"), f"{n:3d}  {rel}  (잔존 {left})")
    else:
        print(f"dry {n:3d}  {rel}")
print("합계", total)
