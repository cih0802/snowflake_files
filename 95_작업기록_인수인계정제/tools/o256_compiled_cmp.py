"""O256 — compiled SQL · manifest 대조(현재본 /tmp/new vs 기준선 /tmp/base)."""
import json, os, sys
sys.path.insert(0, "/workspace/95_작업기록_인수인계정제/tools")
from clean80 import strip_comments
out = []
a = json.load(open("/tmp/base/target/manifest.json")); b = json.load(open("/tmp/new/target/manifest.json"))
na, nb = a["nodes"], b["nodes"]
out.append(f"nodes base {len(na)} new {len(nb)} · 집합 동일 {set(na) == set(nb)}")
srt = lambda v: sorted(json.dumps(i, sort_keys=True) for i in (v if isinstance(v, list) else v.get("nodes", []) + v.get("macros", [])))
dep = [k for k in na if k in nb for f in ("depends_on", "refs", "sources") if srt(na[k].get(f, [])) != srt(nb[k].get(f, []))]
cfg = [k for k in na if k in nb and json.dumps(na[k].get("config"), sort_keys=True) != json.dumps(nb[k].get("config"), sort_keys=True)]
out.append(f"의존성 불일치(순서 무시) {len(dep)} · config 불일치 {len(cfg)}")
comp, miss, cmp_n = [], 0, 0
# invocation_id 는 dbt 실행마다 새 UUID 로 렌더된다(감사 컬럼) ⇒ 각 실행의 값을 같은 토큰으로 바꿔 비교한다.
ia, ib = a["metadata"]["invocation_id"], b["metadata"]["invocation_id"]
norm = lambda s, i: strip_comments(s.replace(i, "<INVOCATION_ID>"))
for k in na:
    x, y = na[k].get("compiled_code"), nb.get(k, {}).get("compiled_code")
    if x is None or y is None:
        miss += (x is None) != (y is None); continue
    cmp_n += 1
    if norm(x, ia) != norm(y, ib):
        comp.append(k)
out.append(f"compiled 비교 {cmp_n} · 주석 제외·invocation_id 정규화 후 불일치 {len(comp)} · 한쪽만 compiled {miss}")
out += ["  dep " + k for k in dep[:10]] + ["  cfg " + k for k in cfg[:10]] + ["  sql " + k for k in comp[:10]]
open("/workspace/tmp/o256/dbt_compare.txt", "w").write("\n".join(out) + "\n")
print("\n".join(out))
