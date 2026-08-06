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
cn.close()

out = {"views": [], "tables": [], "view_cols": {}, "gold_cols": {}, "silver_cols": {},
       "bronze_cols": {}, "bronze_types": {}, "col_comments": {}}
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
      "silver", len(out["silver_cols"]), "bronze", len(out["bronze_cols"]))
