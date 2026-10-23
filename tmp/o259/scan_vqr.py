import io, os, re
ROOT = "/workspace/05_SV-Agent_ai"
pat = re.compile(r"GROUP BY ROLLUP|ROLLUP\s*\(", re.I)
out = []
for f in sorted(os.listdir(ROOT)):
    if not (f.startswith("05_") or f.startswith("22_") or f.startswith("25_") or f.startswith("34_")) or not f.endswith(".sql"):
        continue
    with io.open(os.path.join(ROOT, f), encoding="utf-8") as h:
        for i, line in enumerate(h, 1):
            if pat.search(line) and "O206-C" not in line and "핵심 규칙" not in line:
                out.append("%s:%d\n%s\n" % (f, i, line.rstrip()))
io.open("/tmp/o259_vqr.txt", "w", encoding="utf-8").write("\n".join(out))
print(len(out))
