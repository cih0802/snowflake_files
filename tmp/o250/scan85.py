#!/usr/bin/env python3
"""O250-C · 85 산출물 중 O248~O250 이후 변경과 닿는 파일 스캔(읽기 전용)."""
import io
import os
import re

root = "/workspace/85_실제 인수인계 문서"
toks = {
    "신규·변경 객체(O248~O250)": r"FACT_AD_INFLOW_ALLOC|FACT_MEMBER_EVENT_COHORT|SV_AD_INFLOW_ALLOC|SV_MEMBER_EVENT_COHORT"
                              r"|LTV_CAP_MONTHS|ML_MEMBER_PRED_AXIS|ML_FEE_FORECAST_AXIS",
    "SV 열거(SV_ML_CHURN_CAMPAIGN 포함)": r"SV_ML_CHURN_CAMPAIGN",
    "SV 개수 서술": r"SV\s*\d+\s*종|\d+\s*종\s*SV|SV\s*\d+\s*개",
    "Agent 버전": r"VERSION\$\d",
    "Agent 도구 수": r"도구\s*\d+\s*종",
    "DIM_SEND_REQUEST": r"DIM_SEND_REQUEST",
    "80 패키지 파일수": r"50[0-9]\s*files|50[0-9]\s*개|511",
}
hit = {k: set() for k in toks}
files = 0
for d, _, fs in os.walk(root):
    if "/_ENV" in d:
        continue
    for f in fs:
        if not f.endswith((".md", ".sql", ".csv", ".html")):
            continue
        files += 1
        t = io.open(os.path.join(d, f), encoding="utf-8", errors="ignore").read()
        for k, p in toks.items():
            if re.search(p, t):
                hit[k].add(os.path.relpath(os.path.join(d, f), root))
print("scanned", files)
for k, v in hit.items():
    print(f"{k}: {len(v)}", sorted(v))
print("UNION", len(set().union(*hit.values())))
