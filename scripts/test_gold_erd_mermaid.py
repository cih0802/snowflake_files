# 발행된 GOLD ERD HTML 의 Mermaid erDiagram 문법을 검증한다(점선 관계 연산자 포함).
# Co-authored with CoCo
#
# 왜 별 파일인가: 문법 검증은 「관계가 옳은가」를 보지 않는다(초판이 38/38 유효인데 고립 섬이었다).
#   ⇒ 이 검사는 test_gold_erd.py 의 의미 축과 **분리**해 둔다(같은 것을 다르게 재는 지점 · R3-9 ㉡).

import re
import sys

PATHS = [
    "/workspace/30_output_share/GOLD_ERD_테이블별.html",
    "/workspace/30_output_share/GOLD_ERD_테이블별_YAML전용.html",
]

# 엔티티 속성행 = TYPE NAME [PK|FK] · 관계행 = A ||--o{ B : "col" 또는 A ||..o{ B : "col"
ATTR = re.compile(r"^[A-Za-z0-9_]+\s+[A-Za-z0-9_]+(\s+(PK|FK))?$")
REL = re.compile(r'^[A-Za-z0-9_]+\s+\|\|[-.]{2}o\{\s+[A-Za-z0-9_]+\s+:\s+"[^"]*"$')

rc = 0
for path in PATHS:
    try:
        html = open(path, encoding="utf-8").read()
    except FileNotFoundError:
        print(f"⚪ SKIP (미생성) — {path}")
        continue

    blocks = re.findall(r'<div class="mermaid">(.*?)</div>', html, re.S)
    bad, n_solid, n_dotted = [], 0, 0
    for i, b in enumerate(blocks):
        for ln in b.strip().split("\n"):
            s = ln.strip()
            if not s or s in ("erDiagram", "}") or s.endswith("{"):
                continue
            if "o{" in s:
                if REL.match(s):
                    n_dotted += 1 if "||..o{" in s else 0
                    n_solid += 1 if "||--o{" in s else 0
                else:
                    bad.append((i, s))
                continue
            if not ATTR.match(s):
                bad.append((i, s))

    print(f"{'🔴 FAIL' if bad else '🟢 PASS'} — {path.split('/')[-1]}")
    print(f"   블록 {len(blocks)} · 관계선 실선 {n_solid} · 점선 {n_dotted} · 위반 {len(bad)}")
    for i, s in bad[:10]:
        print(f"     · 블록{i}: {s[:120]}")
    if bad:
        rc = 1

sys.exit(rc)
