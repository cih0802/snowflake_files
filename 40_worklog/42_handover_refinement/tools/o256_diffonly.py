"""O256 — diff 파일의 「80 에만 있는 줄」 추출(읽기 전용). 사용: python3 o256_diffonly.py <측정 csv>"""
import csv, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import o256_measure as M

rows = [r for r in csv.DictReader(open(sys.argv[1], encoding="utf-8")) if r["kind"] == "diff"]
for r in rows:
    rel, rel80 = r["rel"], f'{r["sub"]}/{r["rel"]}'
    src = M.bh.run_order_text() if rel == M.bh.RUN_ORDER_DOC else open(M.W + rel, encoding="utf-8").read()
    sim = M.hook(rel80, M.layer1(rel, src)).split("\n")
    cur = open(M.OUTD + rel80, encoding="utf-8").read().split("\n")
    ss = set(sim)
    only = [l for l in cur if l not in ss]
    print(f"== {rel80} · 80전용 {len(only)}줄 · sim전용 {len([l for l in sim if l not in set(cur)])}줄")
    for l in only[:4]:
        print("   80>", l[:160])
