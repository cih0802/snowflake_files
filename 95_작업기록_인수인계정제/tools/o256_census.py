"""O256 — 헤더 대상 SQL 실태(읽기 전용). 원본 기준 · 80 대상 집합(측정 csv)에 한정."""
import csv, re, sys, collections
rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8")))
srcs = sorted({r["rel"] for r in rows if r["rel"].endswith(".sql") and "mstr DDL 원본" not in r["rel"]})
KEYS = ["Purpose", "Target", "Run order", "Depends on", "Issue"]
by = collections.Counter(); has = collections.Counter(); first = collections.Counter()
for rel in srcs:
    top = rel.split("/")[0] + ("/" + rel.split("/")[1] if rel.startswith("10_dbt_pipeline/") else "")
    by[top] += 1
    t = open("/workspace/" + rel, encoding="utf-8", errors="replace").read()
    head = "\n".join(t.split("\n")[:25])
    for k in KEYS:
        if re.search(r"(?im)^\s*(--|\{#|/\*)?\s*\**" + re.escape(k), head):
            has[k] += 1
    fl = t.lstrip().split("\n", 1)[0][:3]
    first[fl] += 1
print("SQL 대상", len(srcs))
for k, v in sorted(by.items()):
    print(f"  {v:4d} {k}")
print("헤더 키 보유(상단25줄):", dict(has))
print("첫 줄 시작:", first.most_common(8))
