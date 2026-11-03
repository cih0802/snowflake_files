#!/usr/bin/env python3
"""O247 · D14 실행순서 실재 대조 — 문서실행순서.md 의 경로가 원본·80번 패키지에 있는지(읽기 전용)."""
import re
import sys
from pathlib import Path

ROOT = Path("/workspace")
P80 = ROOT / "80_인수인계_프로젝트완료 및 유지보수용"
OUT = Path(sys.argv[1])


def sections(text):
    cur, out = None, {}
    for line in text.splitlines():
        if line.startswith("# "):
            cur = line[2:].strip()
            out[cur] = []
        elif cur:
            out[cur].append(line)
    return out


def paths(lines):
    got = []
    for ln in lines:
        m = re.match(r"^\s*(\d+)\.\s*(?:🆕\s*\[[^\]]*\]\s*)?/(\S.*?\.sql)", ln)
        if m:
            got.append((int(m.group(1)), m.group(2).strip()))
    return got


rows = ["# doc_id: D14 · as_of: 2026-10-20 · 실행순서 파일 실재 대조 · 생성 = tmp/o247/d14_order_check.py · 설명 = D14_인수인계서.md",
        "원본,절,순번,경로,워크스페이스,80번_01_실행순서"]
summary = []
for label, doc in (("원본", ROOT / "문서실행순서.md"), ("80번", P80 / "01_실행순서_배포SQL" / "문서실행순서.md")):
    secs = sections(doc.read_text(encoding="utf-8"))
    for name, lines in secs.items():
        ps = paths(lines)
        miss_ws = miss_80 = 0
        for n, p in ps:
            ws = (ROOT / p).exists()
            pk = (P80 / "01_실행순서_배포SQL" / p).exists()
            miss_ws += not ws
            miss_80 += not pk
            rows.append(f'{label},"{name}",{n},"{p}",{"O" if ws else "X"},{"O" if pk else "X"}')
        summary.append(f"{label} · {name} · 경로 {len(ps)} · 워크스페이스 부재 {miss_ws} · 80번 부재 {miss_80}")
OUT.write_text("\n".join(rows) + "\n", encoding="utf-8-sig")
print("\n".join(summary))
