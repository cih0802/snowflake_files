import io,json,sys,collections
sys.path.insert(0,'/workspace/scripts'); import sfconn
d=json.load(io.open('/workspace/tmp/o262_audit/category_gap_xref.json',encoding='utf-8'))
D=[r for r in d if not r['gold_ref'] and not r['n_doc_hits']]
extra=[r for r in d if r['BRONZE_컬럼']=='REGIST_DEPT_CD']
cn=sfconn.conn(); c=cn.cursor(); c.execute('USE WAREHOUSE GN_DW_DEV_WH')
# code dictionary domains
c.execute("SELECT CD_ID, DTL_CD_ID, DTL_CD_NM FROM GN_DW.BRONZE_CRM.TC_CMMN_DTL_CD")
dom=collections.defaultdict(dict)
for g,k,nm in c.fetchall(): dom[g][str(k).strip()]=nm
c.execute("SELECT CD_ID, CD_NM FROM GN_DW.BRONZE_CRM.TC_CMMN_CD"); gnm={g:n for g,n in c.fetchall()}
out=[]
for r in D+extra:
    fq=r['_fq']; col='"%s"'%r['BRONZE_컬럼']
    c.execute('SELECT COUNT(*), COUNT(%s), COUNT(DISTINCT %s), MIN(%s)::VARCHAR, MAX(%s)::VARCHAR FROM %s'%(col,col,col,col,fq))
    n,f,dd,mn,mx=c.fetchone()
    c.execute('SELECT %s::VARCHAR v, COUNT(*) k FROM %s WHERE %s IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 12'%(col,fq,col))
    top=[(v,k) for v,k in c.fetchall()]
    c.execute('SELECT DISTINCT TRIM(%s::VARCHAR) FROM %s WHERE %s IS NOT NULL LIMIT 300'%(col,fq,col))
    vals=set(x[0] for x in c.fetchall())
    best=[]
    if vals and len(vals)<=200:
        for g,m in dom.items():
            hit=len(vals & set(m))
            if hit: best.append((hit, -len(m), g))
        best.sort(reverse=True)
    cand=[(g,h,-sz,gnm.get(g)) for h,sz,g in best[:4]]
    full=[x for x in cand if x[1]==len(vals)]
    grade='D'
    if full:
        grade='B' if len(full)==1 else 'C'
    out.append(dict(src=r['원천시스템'],tbl=r['BRONZE_테이블'],col=r['BRONZE_컬럼'],fq=fq,dt=r['_dt'],n=n,filled=f,distinct=dd,min=mn,max=mx,top=top,code_cand=cand,full_match=len(full),grade=grade))
json.dump(out,io.open('/workspace/tmp/o262b/d_measure.json','w',encoding='utf-8'),ensure_ascii=False,default=str)
print('done',len(out))
