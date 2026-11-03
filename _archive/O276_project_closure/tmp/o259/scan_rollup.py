import io, os, re, sys
ROOT = "/workspace/05_SV-Agent_ai"
pat = re.compile(r"ROLLUP|GROUPING", re.I)
out = []
for dp, dn, fn in os.walk(ROOT):
    if "_archive" in dp:
        continue
    for f in sorted(fn):
        if not f.endswith((".sql", ".md", ".yml", ".yaml")):
            continue
        p = os.path.join(dp, f)
        with io.open(p, encoding="utf-8", errors="replace") as h:
            for i, line in enumerate(h, 1):
                if pat.search(line):
                    out.append("%s:%d:%s" % (p[len(ROOT) + 1:], i, line.rstrip()[:300]))
with io.open("/tmp/o259_rollup.txt", "w", encoding="utf-8") as h:
    h.write("\n".join(out) + "\n")
print(len(out), "lines", len({o.split(":")[0] for o in out}), "files")
