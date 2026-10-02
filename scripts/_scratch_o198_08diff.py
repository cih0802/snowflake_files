"""O198 임시 계측기 — 08 보존율 +104행 분해(DDL 스냅샷별 SILVER 컬럼 집합 대조 · 읽기 전용)."""
import csv, collections, io, re, sys

DDL = "04_silver_design/08_SILVER_테이블DDL_20260714.sql"
SNAPS = ["O189-A-o189_ddl_sync", "O192-A-o192-compact", "O192-A-o192-tblcmt"]
CT = re.compile(r"CREATE (?:OR REPLACE )?TABLE (?:IF NOT EXISTS )?GN_DW\.SILVER\.(\w+)\s*\(", re.I)
AT = re.compile(r"ALTER TABLE (?:IF EXISTS )?GN_DW\.SILVER\.(\w+)\s+ADD COLUMN (?:IF NOT EXISTS )?(\w+)", re.I)
COL = re.compile(r"^\s{2,}([A-Z_][A-Z0-9_]*)\s+[A-Z]")
SKIP = {"PRIMARY", "CONSTRAINT", "FOREIGN", "UNIQUE", "CLUSTER"}


def cols(path):
    out, cur = set(), None
    for l in io.open(path, encoding="utf-8"):
        m = CT.search(l)
        if m:
            cur = m.group(1).upper()
            continue
        if cur and l.lstrip().startswith(")"):
            cur = None
            continue
        if cur:
            c = COL.match(l)
            if c and c.group(1) not in SKIP:
                out.add((cur, c.group(1)))
        for t, c in AT.findall(l):
            out.add((t.upper(), c.upper()))
    return out


cur08 = list(csv.DictReader(io.open("30_output_share/08_SILVER→GOLD_보존율.csv", encoding="utf-8-sig")))
R = {(r["SILVER_TABLE"], r["COLUMN"]) for r in cur08}
now = cols(DDL)
print("08 rows", len(R), "· DDL now", len(now), "· 08∖DDL", len(R - now), "· DDL∖08", len(now - R))
for s in SNAPS:
    old = cols("_archive/08_SILVER_테이블DDL_20260714.sql." + s)
    add = sorted((now - old) & R)
    rem = sorted((old - now) & R)
    print(f"\n[{s}] old {len(old)} · 08∩(now−old) {len(add)} · 08∩(old−now) {len(rem)}")
    print("  add by table", dict(collections.Counter(t for t, _ in add)))
    if len(sys.argv) > 1 and sys.argv[1] == s:
        for k in add:
            print("   +", *k)
