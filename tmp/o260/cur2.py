import io, glob, re
for p in sorted(glob.glob("/workspace/50_handoff/0[1238]_*")):
    L = io.open(p, encoding="utf-8").read().split("\n")
    n = 0
    for i, x in enumerate(L):
        if "2026-10-16 현행" not in x:
            continue
        y = re.sub(r"\(🔴 2026-10-16 현행 = ([^)]*)\)",
                   lambda m: "(🔴 2026-10-23 현행 = " + m.group(1)
                   .replace("브론즈 65", "브론즈 64")
                   .replace("총계 81", "총계 80")
                   .replace("ERP 3", "ERP 3 · GSC 2") + ")", x)
        if y != x:
            L[i] = y
            n += 1
    io.open(p, "w", encoding="utf-8").write("\n".join(L))
    print(p.rsplit("/", 1)[1], "changed", n)
