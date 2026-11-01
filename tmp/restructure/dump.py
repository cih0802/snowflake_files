import json, sys
V = json.load(open('/workspace/tmp/restructure/verdict.json'))
for t in sys.argv[1:]:
    v = V[t]
    print(f'## {t}  subdirs={[(s["name"], s["files"]) for s in v["subdirs"]]}')
    for r in v['rows']:
        print(f'  [{r["status"]}] {r["name"]} :: {r["head"][:110]}')
