import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, '/tmp')
from sfconn import conn, q

cn = conn()
_, tr = q("""select table_schema, table_name, table_type from GN_DW.INFORMATION_SCHEMA.TABLES
             where table_schema in ('GOLD','SERVING','SILVER','BRONZE_CRM','BRONZE_AGENCY','BRONZE_ERP','BRONZE_GA4')""", cn)
_, cr = q("""select table_schema, table_name, column_name, data_type, ordinal_position, comment
             from GN_DW.INFORMATION_SCHEMA.COLUMNS
             where table_schema in ('GOLD','SERVING','SILVER','BRONZE_CRM','BRONZE_AGENCY','BRONZE_ERP','BRONZE_GA4')
             order by table_schema, table_name, ordinal_position""", cn)

# [2026-08-07 O47] FK 를 **실선언에서 읽는다.** 종전에는 소비 생성기가
#   `DIM_<컬럼명에서 _SK 제거>` 이름 규칙으로 FK 를 추측했고, 접두어가 붙은 FK 9종을
#   전부 놓쳐 「도달불가」로 오판했다(실측: `FAP.PERF_DATE_SK→DIM_DATE`·`FMC.ACQ_*_SK`·
#   `FMF.LAST_*_DATE_SK`·`FAP.MKTG_CAMPAIGN_SK`). 이름 규칙은 FK 의 정본이 아니다(P96-①).
cur = cn.cursor()
cur.execute("show imported keys in schema GN_DW.GOLD")
_ik_cols = [c[0] for c in cur.description]
_ik = cur.fetchall()
_ix = {n: i for i, n in enumerate(_ik_cols)}
cn.close()

# fks: {fact_table: {fk_column: pk_table}} · fk_targets: {fact: [pk_table, ...]}
out_fks, out_fk_targets = {}, {}
for r in _ik:
    ft, fc, pt = r[_ix["fk_table_name"]], r[_ix["fk_column_name"]], r[_ix["pk_table_name"]]
    out_fks.setdefault(ft, {})[fc] = pt
    out_fk_targets.setdefault(ft, [])
    if pt not in out_fk_targets[ft]:
        out_fk_targets[ft].append(pt)


out = {"views": [], "tables": [], "view_cols": {}, "gold_cols": {}, "silver_cols": {},
       "bronze_cols": {}, "bronze_types": {}, "col_comments": {},
       "fks": out_fks, "fk_targets": out_fk_targets}
for s, t, ty in tr:
    if s == 'GOLD' and ty == 'VIEW':
        out["views"].append(t)
    if s == 'GOLD' and ty == 'BASE TABLE':
        out["tables"].append(t)
for s, t, c, dt, op, cm in cr:
    if s == 'GOLD':
        out["view_cols"].setdefault(t, []).append(c) if t in out["views"] else None
        out["gold_cols"].setdefault(t, []).append(c)
        out["col_comments"][f"{t}.{c}"] = cm or ""
    elif s == 'SILVER':
        out["silver_cols"].setdefault(t, []).append(c)
    elif s.startswith('BRONZE'):
        out["bronze_cols"].setdefault(t, []).append(c)
        out["bronze_types"][f"{t}.{c}"] = dt
        out["col_comments"][f"{t}.{c}"] = cm or ""

json.dump(out, open('/tmp/schema.json', 'w'), ensure_ascii=False)
print("views", len(out["views"]), "tables", len(out["tables"]),
      "silver", len(out["silver_cols"]), "bronze", len(out["bronze_cols"]),
      "fk_edges", sum(len(v) for v in out_fks.values()))
