import io, os, re, collections
ROOT = "/workspace/05_SV-Agent_ai"
pat = re.compile(r"\[O206-C 합계 규칙\][^\[]*")
c = collections.Counter()
for f in sorted(os.listdir(ROOT)):
    if not f.endswith(".sql"):
        continue
    with io.open(os.path.join(ROOT, f), encoding="utf-8") as h:
        for line in h:
            for m in pat.finditer(line):
                c[m.group(0)] += 1
for s, n in c.items():
    print("[%d] %s" % (n, s))
    print("----")
