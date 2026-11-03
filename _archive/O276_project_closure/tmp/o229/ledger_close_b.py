import glob, hashlib, io
hits = []
for p in sorted(glob.glob("20_issue/00_INDEX_이슈원장_조각/*.md")):
    L = io.open(p, encoding="utf-8").read().split("\n")
    hits += [(p, k) for k, s in enumerate(L) if "**`O229`**" in s]
assert len(hits) == 1, hits
p, k = hits[0]
h = [hashlib.sha256(open(p, "rb").read()).hexdigest() for _ in range(2)]
assert h[0] == h[1], "hash unstable"
L = io.open(p, encoding="utf-8").read().split("\n")
old = L[k]
add = (" · 🆕 O229-B = dbt 003001(소유자 선반영 · 👤 build PASS) · GAP 9 · 선택 게이트 스킬(`optional_gates.sh`) · "
       "원장 재균형 · eval = 운영계(사용자)")
cells = old.rstrip().rstrip("|").split(" | ")
cells[1] = cells[1] + add
L[k] = " | ".join(cells) + " |"
assert len(L[k]) < 1900, len(L[k])
io.open(p, "w", encoding="utf-8").write("\n".join(L))
print(p, k + 1, len(L[k]))
