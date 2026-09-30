#!/usr/bin/env python3
"""O191-G 임시 — 2차-B 신설 SILVER 컬럼(COMMENT 태그 O191-E/F) 라이브 채움 실측."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn  # noqa: E402
c = conn().cursor(); c.execute('use warehouse GN_DW_ETL_WH')
c.execute("""select table_name, column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS
 where table_schema='SILVER' and (comment ilike '%O191-E 2차-B%' or comment ilike '%O191-F 2차-B%')
 order by table_name, ordinal_position""")
by = {}
for t, col in c.fetchall(): by.setdefault(t, []).append(col)
tot = zero = 0
for t, cols in by.items():
    ex = ','.join(f'count("{x}")' for x in cols)
    c.execute(f'select count(*),{ex} from GN_DW.SILVER.{t}')
    r = c.fetchone(); n = r[0]
    z = [cols[i] for i, v in enumerate(r[1:]) if v == 0]
    tot += len(cols); zero += len(z)
    print(f'{t}: rows={n} cols={len(cols)} 0건={len(z)} {z if z else ""}')
print(f'TOTAL cols={tot} 0건={zero}')
