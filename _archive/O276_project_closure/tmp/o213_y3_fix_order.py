"""O213 Y3 정정 — 생성기 v1 이 뒤집어 쓴 `별칭.노출명 AS 별칭.물리컬럼` 을 `별칭.물리컬럼 AS 별칭.노출명` 으로 되돌린다.
대상 = spec 에서 expose != col 인 행 · 판정 = 정본 파일에 뒤집힌 문자열이 정확히 1회 있을 때만 치환."""
import csv, io, re, sys

APPLY = "--apply" in sys.argv
FILES = {
    "SV_MEMBER_EVENT": "05_2_SV_DDL_MEMBER_EVENT.sql", "SV_MEMBER_COHORT": "05_3_SV_DDL_MEMBER_COHORT.sql",
    "SV_MEMBER_SPONSOR_BIZ": "05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql", "SV_MEMBER_MONTHLY": "05_1_SV_DDL_MEMBER_MONTHLY.sql",
    "SV_SERVICE": "05_4_SV_DDL_SERVICE.sql", "SV_EVENT_PARTICIPATION": "05_5_SV_DDL_EVENT_PARTICIPATION.sql",
    "SV_RELATION_ACTIVITY": "05_12_SV_DDL_RELATION_ACTIVITY.sql", "SV_MEMBER_STATUS_ASOF": "05_17_SV_DDL_MEMBER_STATUS_ASOF.sql",
    "SV_GA_BEHAVIOR": "05_15_SV_DDL_GA_BEHAVIOR.sql", "SV_AD": "05_7_SV_DDL_AD.sql"}
D = "/workspace/05_SV-Agent_ai/"
bad = 0
fix = {}
for r in csv.DictReader(io.open("/workspace/tmp/o213_y3_sv_spec.tsv", encoding="utf-8"), delimiter="\t"):
    if r["expose"] == r["col"]:
        continue
    p = D + FILES[r["sv"]]
    t = fix.get(p) or io.open(p, encoding="utf-8").read()
    wrong = f"{r['alias']}.{r['expose']} AS {r['alias']}.{r['col']}"
    right = f"{r['alias']}.{r['col']} AS {r['alias']}.{r['expose']}"
    if "--reverse" in sys.argv:
        # 🔴 [O213 실측] SV 문법 = `별칭.차원명 AS 물리식` — 이 스크립트의 정방향 「정정」이 틀렸다 ⇒ 되돌린다
        wrong, right = right, wrong
    n = t.count(wrong)
    print(("OK " if n == 1 else "🔴 ") + f"{r['sv']}: {wrong} ×{n}")
    if n != 1:
        bad += 1
        continue
    fix[p] = t.replace(wrong, right)
if APPLY and not bad:
    for p, t in fix.items():
        io.open(p, "w", encoding="utf-8").write(t)
print("bad", bad, "files", len(fix), "mode", "APPLY" if APPLY and not bad else "DRY-RUN")
sys.exit(1 if bad else 0)
