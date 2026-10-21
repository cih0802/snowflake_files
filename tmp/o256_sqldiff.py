import json, sys, difflib, collections
sys.path.insert(0, "/workspace/95_작업기록_인수인계정제/tools")
from clean80 import strip_comments
a = json.load(open("/tmp/base/target/manifest.json"))["nodes"]; b = json.load(open("/tmp/new/target/manifest.json"))["nodes"]
kinds = collections.Counter(); shown = 0
for k in a:
    x, y = a[k].get("compiled_code"), b.get(k, {}).get("compiled_code")
    if not x or not y or strip_comments(x) == strip_comments(y):
        continue
    xs, ys = strip_comments(x).split(" "), strip_comments(y).split(" ")
    d = [t for t in difflib.ndiff(xs, ys) if t[:1] in "+-"]
    kinds[" ".join(d)[:120]] += 1
    if shown < 3:
        print("==", k, d[:12]); shown += 1
print("패턴 종류", len(kinds))
for p, c in kinds.most_common(6):
    print(c, p)
