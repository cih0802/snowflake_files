import json, sys
sys.path.insert(0, "/workspace/95_작업기록_인수인계정제/tools")
from clean80 import strip_comments
a = json.load(open("/tmp/base/target/manifest.json")); b = json.load(open(sys.argv[1]))
def nodes(m):
    out = {}
    for k, v in {**m["nodes"], **m.get("macros", {})}.items():
        if k.startswith("macro.") and v.get("package_name") != "gn_dw" and "dbt" in v.get("package_name", ""):
            continue
        out[k] = v
    return out
na, nb = nodes(a), nodes(b)
print("nodes", len(na), len(nb), "only_base", sorted(set(na) - set(nb))[:5], "only_new", sorted(set(nb) - set(na))[:5])
bad = []
for k in sorted(set(na) & set(nb)):
    x, y = na[k], nb[k]
    for f in ("depends_on", "config", "refs", "sources", "unique_key"):
        if json.dumps(x.get(f), sort_keys=True) != json.dumps(y.get(f), sort_keys=True):
            bad.append((k, f))
    for f in ("raw_code", "macro_sql"):
        if f in x and strip_comments(x[f]) != strip_comments(y[f]):
            bad.append((k, f))
print("mismatch", len(bad)); [print(" ", t) for t in bad[:15]]
