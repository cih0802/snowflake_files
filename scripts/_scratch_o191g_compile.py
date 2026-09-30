#!/usr/bin/env python3
"""O191-G 임시 — GOLD 모델 매크로 치환 후 LIMIT 0 컴파일 · 라이브 GOLD 컬럼 순서 대조."""
import glob, io, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn  # noqa: E402
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sk(m):
    cols = re.findall(r"'([^']+)'", m.group(1))
    return 'ABS(HASH(' + " || '|' || ".join(f"COALESCE(CAST({c} AS VARCHAR),'-')" for c in cols) + '))'


def render(s):
    s = re.sub(r'\{\{\s*config\(.*?\)\s*\}\}', '', s, flags=re.S)
    s = re.sub(r"\{\{\s*source\('bronze_crm','(\w+)'\)\s*\}\}", r'GN_DW.BRONZE_CRM.\1', s, flags=re.I)
    s = re.sub(r"\{\{\s*ref\('(CRM_\w+)'\)\s*\}\}", r'GN_DW.SILVER.\1', s)
    s = re.sub(r"\{\{\s*ref\('(\w+)'\)\s*\}\}", r'GN_DW.GOLD.\1', s)
    s = re.sub(r"\{\{\s*gold_sk\(\[(.*?)\]\)\s*\}\}", sk, s)
    s = re.sub(r"\{\{\s*gold_meta\('(\w+)'\)\s*\}\}",
               r"'\1' AS DW_SOURCE_SYSTEM, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_LOAD_TS, "
               r"CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_UPDATE_TS, 'x' AS DW_BATCH_ID", s)
    s = re.sub(r"\{\{\s*date_sk\('(.*?)'\)\s*\}\}", r"TRY_TO_NUMBER(TO_CHAR(\1,'YYYYMMDD'))", s)
    s = re.sub(r"\{\{\s*gn_member_master_filter\('([\w.]+)'\)\s*\}\}", r'\1 IS NOT NULL', s)
    return s


c = conn().cursor(); c.execute('use warehouse GN_DW_ETL_WH')
for m in sys.argv[1:]:
    p = glob.glob(os.path.join(ROOT, f'10_dbt_pipeline/models/gold/*/{m}.sql'))[0]
    s = render(io.open(p, encoding='utf-8').read())
    left = re.findall(r'\{\{.*?\}\}|\{%.*?%\}', s, flags=re.S)
    try:
        c.execute(f'select * from ({s}) limit 0')
        cols = [d[0] for d in c.description]
        c.execute(f"select column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='GOLD' "
                  f"and table_name='{m}' order by ordinal_position")
        live = [r[0] for r in c.fetchall()]
        ok = cols == live
        print(f'{m}: OK cols={len(cols)} live={len(live)} 순서일치={ok} 잔여jinja={len(left)}' +
              ('' if ok else f' model_only={[x for x in cols if x not in live]} live_only={[x for x in live if x not in cols]}'))
    except Exception as e:
        print(f'{m}: FAIL {str(e)[:300]}')
