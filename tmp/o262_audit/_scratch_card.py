import csv,io,sys,json,collections
sys.path.insert(0,'/workspace/scripts'); import sfconn
rows=[r for r in csv.reader(io.open('/workspace/tmp/o262_audit/06_BRONZE노출감사.csv',encoding='utf-8-sig')) if r and not r[0].startswith('#')]
h=rows[0]; rows=[dict(zip(h,r)) for r in rows[1:]]
cand=[r for r in rows if r['판정'] in ('SILVER까지만','미노출(검토대상)')]
cn=sfconn.conn(); c=cn.cursor(); c.execute('USE WAREHOUSE GN_DW_DEV_WH')
c.execute("SELECT table_schema, table_name, column_name, data_type FROM GN_DW.INFORMATION_SCHEMA.COLUMNS WHERE table_schema LIKE 'BRONZE%'")
loc=collections.defaultdict(list)
for s,t,col,dt in c.fetchall(): loc[(t.upper(),col.upper())].append((s,t,dt))
bytab=collections.defaultdict(list)
for r in cand:
    k=(r['BRONZE_테이블'].upper(),r['BRONZE_컬럼'].upper())
    ls=loc.get(k)
    if not ls:
        # GA4 shard tables: prefix match → skip (sharded) 
        r['_err']='NOLOC'; continue
    s,t,dt=ls[0]; r['_fq']='GN_DW.%s."%s"'%(s,t); r['_dt']=dt
    bytab[r['_fq']].append(r)
out=[]
for fq,rs in bytab.items():
    exprs=[]
    for i,r in enumerate(rs):
        q='"%s"'%r['BRONZE_컬럼']
        exprs.append('APPROX_COUNT_DISTINCT(%s) d%d, COUNT(%s) f%d'%(q,i,q,i))
    try:
        c.execute('SELECT COUNT(*) n, %s FROM %s'%(', '.join(exprs),fq)); v=c.fetchone()
        for i,r in enumerate(rs): r['_n']=v[0]; r['_d']=v[1+2*i]; r['_f']=v[2+2*i]
    except Exception as e:
        for r in rs: r['_err']=str(e)[:80]
for r in cand: out.append({k:r.get(k) for k in ('원천시스템','BRONZE_테이블','BRONZE_컬럼','판정','비고','_fq','_dt','_n','_d','_f','_err')})
json.dump(out,io.open('/workspace/tmp/o262_audit/card.json','w',encoding='utf-8'),ensure_ascii=False)
print('done',len(out),sum(1 for r in out if r.get('_err')))
