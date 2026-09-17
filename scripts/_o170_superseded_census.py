#!/usr/bin/env python3
# O170 — 99_NEXT 승계(=현행 아님) 인수인계 절의 조각별 규모 실측.
# 🔴 판정만 한다(쓰기 없음). 은퇴 대상 선정은 사람이 한다(`R1-6-24`).
# 🔴🔴 판정식을 창작하지 않는다 — `session_brief.superseded()` 를 **import 해서** 쓴다.
#   🔎 왜 = 초판은 자작 판정식(`"~~" in title or "승계됐다" in title`)을 썼고 **현행 절까지 승계로 잡았다**
#      (내 절 제목이 「§0-WWWW/O171 은 승계됐다」를 담기 때문 · `J8` 자기참조).
#      정본은 방향을 구별한다 = `로 승계`·`시작점은`(자기 승계)만 신호이고
#      `는 승계됐다`(다른 절 → 이 절)는 **현행 절이 스스로 적는 문구**다.
import glob
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from session_brief import superseded  # noqa: E402  🔴 분모를 하나로 둔다

HEAD = re.compile(r"^## ")
CHUNKS = sorted(glob.glob("99_NEXT_SESSION_조각/99_NEXT_SESSION-*.md"))

rows = []
live = []
for p in CHUNKS:
    lines = io.open(p, encoding="utf-8").read().split("\n")
    idx = [i for i, l in enumerate(lines) if HEAD.match(l)]
    idx.append(len(lines))
    for k in range(len(idx) - 1):
        a, b = idx[k], idx[k + 1]
        title = lines[a]
        nb = len("\n".join(lines[a + 1:b]).encode("utf-8"))
        rec = (p, a + 1, nb, b - a, title)
        if superseded(title):
            rows.append(rec)
        else:
            live.append(rec)

tot = sum(r[2] for r in rows)
print("승계 절 %d개 · 본문 합계 %d B" % (len(rows), tot))
print("🔴 현행(비승계) 절 %d개 · 본문 %d B — 은퇴 대상이 아니다:"
      % (len(live), sum(r[2] for r in live)))
for p, ln, nb, nl, t in live:
    print("   · %s:%d  %d B  %s" % (os.path.basename(p), ln, nb, t[:96]))

print("")
print("조각별 = 승계본문B / 파일B (비율) · 절수")
full = []
for p in CHUNKS:
    sub = [r for r in rows if r[0] == p]
    liv = [r for r in live if r[0] == p]
    if not sub:
        continue
    s = sum(r[2] for r in sub)
    f = os.path.getsize(p)
    mark = "  ⇐ 조각 전체가 승계" if not liv else "  (현행 절 %d 혼재)" % len(liv)
    if not liv:
        full.append(p)
    print("  %s  %6d / %6d  (%2.0f%%)  절 %d%s"
          % (os.path.basename(p), s, f, 100.0 * s / f, len(sub), mark))

print("")
print("🟢 「조각째 은퇴」 가능(현행 절 0) = %d개 조각 · 합계 %d B"
      % (len(full), sum(os.path.getsize(p) for p in full)))
