#!/usr/bin/env python3
"""O191-F 임시 — 2차-B 잔여 테이블의 실제 누락 후보 컬럼(감사·메모·개인정보 제외) + 채움률."""
import glob, io, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn  # noqa: E402
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = sys.argv[1:]
EXCL = re.compile(r'^(FRST_|LAST_|_)|(_ID$(?<=RGSTR_ID))|UPDUSR|RGSTR|REGIST_DT|UPDT_DT|UPDT_ID|ATCHFL|FILE_|_URL$|MBTLNUM|TELNO|CTTPC|EMAIL_ADRES|ADRES|ADDR|ZIP|BILLKEY|CRTFC_DATA|CARD_NO|CARD_TRMVT|ACCTNO|ACNUT_NO|PAYER_NM|APPLCNT_NM|BRTHDY|IHIDNUM|PASSWD|_RM$|^RM\d*$|MEMO|CTNT\d*$|_DC$|^CTNT')
files = glob.glob(os.path.join(ROOT, '10_dbt_pipeline/models/silver/**/*.sql'), recursive=True)
used = {}
for f in files:
    t = io.open(f, encoding='utf-8').read().upper()
    for s in set(re.findall(r"SOURCE\('BRONZE_CRM','([A-Z0-9_]+)'\)", t)):
        used.setdefault(s, set()).update(re.findall(r'\b[A-Z][A-Z0-9_]+\b', t))
c = conn().cursor(); c.execute('use warehouse GN_DW_ETL_WH')
for t in T:
    c.execute(f"select column_name, data_type, comment from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='BRONZE_CRM' and table_name='{t}' order by ordinal_position")
    cols = c.fetchall()
    cand = [(n, d, m) for n, d, m in cols if n not in used.get(t, set()) and not EXCL.search(n)]
    if not cand:
        print(f'## {t}: 후보 0'); continue
    exprs = ','.join(f"count(nullif(trim({n}::varchar),''))/count(*) as \"{n}\"" for n, _, _ in cand)
    c.execute(f"select count(*) n, {exprs} from GN_DW.BRONZE_CRM.{t}")
    r = c.fetchone(); desc = [d[0] for d in c.description]
    out = [f"{n}({(m or '')[:14]}):{float(r[desc.index(n)]):.2f}" for n, d, m in cand]
    keep = [n for n, d, m in cand if float(r[desc.index(n)]) > 0]
    print(f'## {t} rows={r[0]} 후보={len(cand)} 채움>0={len(keep)}')
    print('   ' + ' · '.join(out))
