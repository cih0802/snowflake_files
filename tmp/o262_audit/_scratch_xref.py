import io,os,re,json,collections
cat=json.load(io.open('/workspace/tmp/o262_audit/category_gap.json',encoding='utf-8'))
def files(roots,ext):
    for r in roots:
        for dp,dn,fn in os.walk(r):
            dn[:]=[d for d in dn if d not in('_archive','__pycache__','target','logs')]
            for f in fn:
                if f.endswith(ext): yield os.path.join(dp,f)
gold={p:io.open(p,encoding='utf-8').read() for p in files(['/workspace/10_dbt_pipeline/models/gold'],'.sql')}
docs={}
for p in files(['/workspace/20_issue/10_진단_원인분석_조각','/workspace/20_issue/20_현업확인_요청_조각','/workspace/20_issue/30_설계_의사결정_조각','/workspace/20_issue/50_dbt_파이프라인_미결조치_조각','/workspace/20_issue/90_해소완료_로그_조각'],'.md'):
    docs[p]=io.open(p,encoding='utf-8').read().split('\n')
for p in ['/workspace/20_issue/31_코드군_매핑등재부.md','/workspace/20_issue/32_컬럼개명표.md','/workspace/20_issue/40_입고대기_원천의존.md']:
    docs[p]=io.open(p,encoding='utf-8').read().split('\n')
out=[]
for r in cat:
    col=r['BRONZE_컬럼']; rx=re.compile(r'(?<![A-Za-z0-9_])'+re.escape(col)+r'(?![A-Za-z0-9_])')
    g=[os.path.basename(p) for p,t in gold.items() if rx.search(t)]
    hits=[]
    for p,ls in docs.items():
        for i,l in enumerate(ls,1):
            if rx.search(l) and re.search(r'보류|미승격|미노출|현업|결정|제외|PII|승격|배선',l):
                hits.append('%s:%d'%(p.replace('/workspace/',''),i))
    r['gold_ref']=g; r['doc_hits']=hits[:4]; r['n_doc_hits']=len(hits)
    out.append(r)
json.dump(out,io.open('/workspace/tmp/o262_audit/category_gap_xref.json','w',encoding='utf-8'),ensure_ascii=False)
c=collections.Counter(('GOLD참조' if r['gold_ref'] else '-')+'/'+('기록' if r['n_doc_hits'] else '무기록') for r in out)
print(c)
