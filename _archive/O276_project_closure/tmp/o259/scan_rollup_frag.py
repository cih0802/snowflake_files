import io, os, re, collections
ROOT = "/workspace/05_SV-Agent_ai"
pat = re.compile(r"ROLLUP|GROUPING", re.I)
frag = collections.Counter()
where = collections.defaultdict(list)
for dp, dn, fn in os.walk(ROOT):
    if "_archive" in dp:
        continue
    for f in sorted(fn):
        if not f.endswith((".sql", ".md")):
            continue
        p = os.path.join(dp, f)
        with io.open(p, encoding="utf-8", errors="replace") as h:
            for i, line in enumerate(h, 1):
                for m in pat.finditer(line):
                    s = line[max(0, m.start() - 160):m.end() + 160].strip()
                    frag[s] += 1
                    where[s].append("%s:%d" % (f, i))
with io.open("/tmp/o259_frag.txt", "w", encoding="utf-8") as h:
    for s, n in frag.most_common():
        h.write("[%d] %s\n    @ %s\n" % (n, s, " ".join(where[s][:40])))
print(len(frag))
