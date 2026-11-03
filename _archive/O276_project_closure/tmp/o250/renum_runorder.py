#!/usr/bin/env python3
"""O250-E · 문서실행순서.md 의 개발계·운영계 목록에서 35_·36_ 을 05_27~05_30 정본으로 바꾸고 그 절만 다시 번호를 매긴다.
「기존 환경 갱신」 절은 이미 실행된 이력이므로 번호를 바꾸지 않고 정본 안내만 덧붙인다."""
import re
import sys
from pathlib import Path

p = Path("/workspace/문서실행순서.md")
t = p.read_text(encoding="utf-8")
head, rest = t.split("# 기존 환경 갱신", 1)
R35 = "/05_SV-Agent_ai/35_O249_SV_신설_광고비배분_개발사건코호트.sql"
R36 = "/05_SV-Agent_ai/36_O250_ML예측_7축확장.sql"
NEW35 = ["/05_SV-Agent_ai/05_27_SV_DDL_AD_INFLOW_ALLOC.sql", "/05_SV-Agent_ai/05_28_SV_DDL_MEMBER_EVENT_COHORT.sql"]
NEW36 = ["/05_SV-Agent_ai/05_29_SV_DDL_ML_MEMBER_PRED_AXIS.sql", "/05_SV-Agent_ai/05_30_SV_DDL_ML_FEE_FORECAST_AXIS.sql"]

out, n_sec = [], 0
for line in head.split("\n"):
    m = re.match(r"^(\d+)\. (.+)$", line)
    if line.startswith("# "):
        n_sec += 1
        k = 0
    if not m:
        out.append(line)
        continue
    path = m.group(2)
    items = NEW35 if path == R35 else NEW36 if path == R36 else [path]
    for it in items:
        k += 1
        out.append(f"{k}. {it}")
new_head = "\n".join(out)
for need in NEW35 + NEW36:
    if new_head.count(need) != 2:
        sys.exit(f"🔴 {need} 이 두 목록에 각 1회가 아니다({new_head.count(need)})")
if R35 in new_head or R36 in new_head:
    sys.exit("🔴 35_/36_ 이 신규 구축 목록에 남았다")

note = ("\n> 🆕 [O250-E] 23·26 의 `35_`·`36_` 은 이미 실행된 환경의 이력이다 — 같은 정의가 정본 "
        "`05_27`·`05_28`(35_ 의 SV 2) · `21_` [O250] 절 + `05_29`·`05_30`(36_ 의 뷰 2·SV 2)에 있다. "
        "아직 실행하지 않은 환경은 정본 파일을 쓴다(결과 동일).\n")
anchor = "28. 🆕 [O250] /05_SV-Agent_ai/09_1_AGENT_생성.sql"
i = rest.index(anchor)
j = rest.index("\n", i)
rest = rest[:j + 1] + note + rest[j + 1:]
p.write_text(new_head + "# 기존 환경 갱신" + rest, encoding="utf-8")
back = p.read_text(encoding="utf-8")
dev = re.findall(r"^(\d+)\. ", back.split("# 운영계")[0], re.M)
ops = re.findall(r"^(\d+)\. ", back.split("# 운영계")[1].split("# 기존 환경 갱신")[0], re.M)
print("개발계", dev[-1], "운영계", ops[-1], "연속", dev == [str(x) for x in range(1, len(dev) + 1)], ops == [str(x) for x in range(1, len(ops) + 1)])
