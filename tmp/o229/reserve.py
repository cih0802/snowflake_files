import hashlib, io, sys
p = "20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md"
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
if any("**`O229`**" in s for s in L):
    sys.exit("already reserved")
i = next(k for k, s in enumerate(L) if "**`O228`**" in s)
row = ("| 🟡 **`O229`** — O228-A 잔여 중 eval·현업회신 제외 전건(Q29 원인 · 런북 · GAP · WIDE_AD 0행 · 백로그) "
       "(2026-10-14 · jw08094 · ㉡ · 사용자 지시 · 진행 중 · 단위 O229-A) "
       "| 🟡 선점 등재(R1-4-3) | — | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0228-A.md:35` |")
L.insert(i, row)
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print("inserted at", i + 1, "sha_before", h[0][:12])
