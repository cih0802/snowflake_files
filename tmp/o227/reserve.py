import hashlib, io, sys
p = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
i = next(k for k, s in enumerate(L) if s.startswith("| 🟢 **`O226`**"))
if any("**`O227`**" in s for s in L):
    sys.exit("already reserved")
row = ("| 🟡 **`O227`** — O226-A 잔여 착수(② MEMBER R14 조문 치환 · ③ COMMENT C3 단계 집행) "
       "(2026-10-14 · xh20001 · ㉡ · 사용자 승인 · 진행 중 · 단위 O227-A) "
       "| 🟡 선점 등재(R1-4-3) | — | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0226-A.md:35` |")
L.insert(i, row)
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print("inserted at", i + 1, "sha_before", h[0][:12])
