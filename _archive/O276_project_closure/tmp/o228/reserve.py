import hashlib, io, sys
p = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
i = next(k for k, s in enumerate(L) if s.startswith("| 🟢 **`O227`**"))
if any("**`O228`**" in s for s in L):
    sys.exit("already reserved")
row = ("| 🟡 **`O228`** — 계정 이전(JW08094) 후 O227-B ② 마감(드리프트 0 · MKT eval) + COMMENT C3 단계 ③ SV 집행 "
       "(2026-10-14 · jw08094 · ㉡ · 사용자 승인 · 진행 중 · 단위 O228-A) "
       "| 🟡 선점 등재(R1-4-3) | — | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0227-B.md:37` |")
L.insert(i, row)
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print("inserted at", i + 1, "sha_before", h[0][:12])
