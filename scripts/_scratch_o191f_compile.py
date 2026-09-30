#!/usr/bin/env python3
"""O191-F 임시 — SILVER 모델 Jinja 치환 후 LIMIT 0 컴파일 · 열 수/이름을 라이브 테이블(ALTER 후) 순서와 대조."""
import io, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn  # noqa: E402
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
c = conn().cursor(); c.execute('use warehouse GN_DW_ETL_WH')
for m in sys.argv[1:]:
    s = io.open(os.path.join(ROOT, f'10_dbt_pipeline/models/silver/crm/{m}.sql'), encoding='utf-8').read()
    s = re.sub(r"\{\{\s*source\('bronze_crm','(\w+)'\)\s*\}\}", r'GN_DW.BRONZE_CRM.\1', s, flags=re.I)
    s = re.sub(r"\{\{\s*ref\('(\w+)'\)\s*\}\}", r'GN_DW.SILVER.\1', s)
    s = re.sub(r"\{\{\s*gn_member_master_filter\('([\w.]+)'\)\s*\}\}", r'\1 IS NOT NULL', s)
    s = re.sub(r'\{\{.*?\}\}|\{%.*?%\}', '', s, flags=re.S)
    try:
        c.execute(f'select * from ({s}) limit 0')
        cols = [d[0] for d in c.description]
        c.execute(f"select column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='SILVER' and table_name='{m}' order by ordinal_position")
        live = [r[0] for r in c.fetchall()]
        print(f'{m}: OK cols={len(cols)} live={len(live)} 순서일치={cols == live}' + ('' if cols == live else f' diff={[x for x in cols if x not in live]}/{[x for x in live if x not in cols]}'))
    except Exception as e:
        print(f'{m}: FAIL {str(e)[:300]}')
