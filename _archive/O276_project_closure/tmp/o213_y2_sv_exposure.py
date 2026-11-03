"""O213 Y2 — GOLD/MSTR/SERVING 카테고리 컬럼이 어느 SV 에 노출됐는지 판정.

입력 ① 카테고리 컬럼 CSV(SQL 출력) ② Y0 보존 SV DDL 28종(tmp/o213_y0/SV_*.sql).
판정 = SV DDL 의 TABLES 절에서 base 테이블을 찾고, 그 SV 본문에 컬럼명이 단어로 나오면 노출.
"""
import csv, glob, io, os, re, sys, collections

SRC, OUT = sys.argv[1], sys.argv[2]
DDL_DIR = "/workspace/tmp/o213_y0"

# SV → base 테이블(schema.table) · 본문
sv_base, sv_body = {}, {}
for p in glob.glob(os.path.join(DDL_DIR, "SV_*.sql")):
    body = io.open(p, encoding="utf-8").read()
    name = os.path.basename(p)[3:-4]
    bases = set(re.findall(r"GN_DW\.(GOLD|SERVING|MSTR)\.([A-Z0-9_]+)", body.upper()))
    sv_base[name] = bases
    sv_body[name] = body.upper()

def in_any_sv(col):
    pat = re.compile(r"\b" + re.escape(col) + r"\b")
    return [sv for sv in sv_body if pat.search(sv_body[sv])]

rows = list(csv.reader(io.open(SRC, encoding="utf-8")))
hdr_i = next(i for i, r in enumerate(rows) if r and r[0] == "TABLE_SCHEMA")
out = io.open(OUT, "w", encoding="utf-8")
out.write("schema\ttable\tcolumn\tndv\tcomment\tbase_of_sv\texposed_in\tjudge\n")
stat = collections.Counter()
for r in rows[hdr_i + 1:]:
    if len(r) < 5:
        continue
    sch, tbl, col, ndv, cmt = r[:5]
    bases = [sv for sv, b in sv_base.items() if (sch, tbl) in b]
    pat = re.compile(r"\b" + re.escape(col) + r"\b")
    exposed = [sv for sv in bases if pat.search(sv_body[sv])]
    anywhere = in_any_sv(col)
    label_ok = False
    if col.endswith("_CD"):
        stem = col[:-3]
        label_ok = bool(in_any_sv(stem + "_NM") or in_any_sv(stem + "_NAME"))
    if tbl.startswith("EVAL_") or (sch == "MSTR" and re.match(r"^(D_|F_|BCHLOG)", tbl)):
        k = "S0_대상외(중간산출·평가)"
    elif exposed or anywhere:
        k = "S1_노출됨"
    elif label_ok:
        k = "S1_노출됨(라벨)"
    elif bases:
        k = "S2_SV차원추가"
    else:
        k = "S3_SV미연결(신설·base확장)"
    stat[k] += 1
    out.write("\t".join([sch, tbl, col, ndv, cmt, ",".join(bases) or "-",
                         ",".join(exposed or anywhere) or "-", k]) + "\n")
out.close()
for k, v in sorted(stat.items()):
    print(k, v)
