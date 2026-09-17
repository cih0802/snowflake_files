#!/usr/bin/env python3
# O170 라벨 선점 (R1-4-3) — 원장 §1 대시보드 표 머리 직후에 최소 1행을 삽입한다.
# 🔴 -001 조각 여유가 153 B 뿐이므로 행을 짧게 유지한다(상한 40,960 B).
import io
import sys

PATH = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-001.md"
HEADER = "## 1. 상태 대시보드 (한눈에)"
SEP = "|---|---|---|---|"
ROW = "| \u23f3 **`O170`** \u2014 \uc9d1\ud589\uc911(\uc120\uc810) | \u2014 | \u2014 | \uc6d0\uc7a5 \u00a71 |"

src = io.open(PATH, encoding="utf-8").read()
lines = src.split("\n")

if any("`O170`" in ln for ln in lines):
    print("SKIP: O170 이미 등재")
    sys.exit(0)

hi = next(i for i, ln in enumerate(lines) if ln.strip() == HEADER)
si = next(i for i, ln in enumerate(lines) if i > hi and ln.strip() == SEP)
lines.insert(si + 1, ROW)

out = "\n".join(lines)
nb = len(out.encode("utf-8"))
if nb > 40960:
    print("ABORT: 상한 초과 %d B" % nb)
    sys.exit(1)

io.open(PATH, "w", encoding="utf-8").write(out)
print("OK: 삽입 위치 %d행 · %d B (여유 %d B)" % (si + 2, nb, 40960 - nb))
