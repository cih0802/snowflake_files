# CSV 인벤토리의 설명 컬럼을 06_DDL.sql 각 컬럼 정의에 COMMENT로 주입.
# Co-authored with CoCo
import csv, re, sys

CSV = "/workspace/gold 스키마 컬럼 인벤토리_20260629.csv"
DDL = "/workspace/03_top-down_gold/06_DDL.sql"

# (table, column) -> 설명
desc = {}
with open(CSV, encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        t = (row["테이블명"] or "").strip()
        c = (row["컬럼명"] or "").strip()
        d = (row["설명"] or "").strip()
        if t and c and d:
            desc[(t, c)] = d

lines = open(DDL, encoding="utf-8").read().split("\n")
cur_table = None
in_create = False
type_re = re.compile(r"^(\s+)([A-Z][A-Z0-9_]*)\s+(NUMBER|VARCHAR|DATE|BOOLEAN|TIMESTAMP_NTZ|FLOAT|VARIANT)")
create_re = re.compile(r"CREATE OR REPLACE TABLE GN_DW\.GOLD\.([A-Z0-9_]+)")
injected = 0
missing = []

out = []
for ln in lines:
    m_create = create_re.search(ln)
    if m_create:
        cur_table = m_create.group(1)
        in_create = True
        out.append(ln)
        continue
    if in_create and ln.lstrip().startswith(")"):
        # end of column block (closing paren, possibly with table COMMENT)
        in_create = False
        out.append(ln)
        continue

    if in_create and cur_table:
        m = type_re.match(ln)
        if m and "COMMENT" not in ln.upper():
            col = m.group(2)
            key = (cur_table, col)
            if key in desc:
                # split off any existing inline '-- comment'
                code = ln
                cpos = code.find("--")
                inline = ""
                if cpos != -1:
                    inline = code[cpos:]
                    code = code[:cpos]
                code = code.rstrip()
                trailing_comma = code.endswith(",")
                if trailing_comma:
                    code = code[:-1].rstrip()
                text = desc[key].replace("'", "''")
                newln = f"{code} COMMENT '{text}'" + ("," if trailing_comma else "")
                out.append(newln)
                injected += 1
                continue
            else:
                missing.append(key)
    out.append(ln)

GEN = "scripts/add_gold_comments.py"
_prov = f"-- 컬럼 COMMENT 주입기(생성기): {GEN} — 재실행 시 이 스크립트로 갱신"
if not any(_prov in l for l in out[:6]):
    out.insert(0, _prov)
open(DDL, "w", encoding="utf-8").write("\n".join(out))
print(f"[{GEN}] injected COMMENT on {injected} columns → {DDL}")
if missing:
    print(f"no-desc columns ({len(missing)}):", missing[:20])
