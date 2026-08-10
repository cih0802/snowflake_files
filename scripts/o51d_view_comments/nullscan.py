# -*- coding: utf-8 -*-
"""[2026-08-07 O51-E] 전건/준전건 NULL 컬럼 탐지 → 문안이 그 사실을 말하는지 대조.
🔴 전건 NULL 컬럼은 소비자가 「값이 없다」를 「0이다」·「해당없음」으로 오독하는 최대 오답원이다(P21·DEC-27 §17-C).
1단계 TABLESAMPLE 로 후보 선별 → 2단계 후보만 정확 count(비용 절감)."""
import sys, io, yaml, collections
sys.path.insert(0,'/workspace/scripts')
from sfconn import conn, q
T=['WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT','WIDE_SERVICE_EVENT','WIDE_EVENT_PARTICIPATION',
   'WIDE_MEMBER_FEE','WIDE_DEV_ACHIEVEMENT','DIM_MEMBER_CURRENT','DIM_MEMBER_ACQUISITION']
desc={}
for f in ('/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml',
          '/workspace/10_dbt_pipeline/models/gold/_gold_ready_schema.yml'):
    for m in yaml.safe_load(io.open(f,encoding='utf-8'))['models']:
        if m['name'] in T:
            for c in (m.get('columns') or []): desc[(m['name'],c['name'])]=c['description']
cn=conn()
cands=[]
for t in T:
    cols=[c for (v,c) in desc if v==t]
    cols=[c for (v,c) in sorted(desc) if v==t]
    sel=", ".join(f'count("{c}") as "{c}"' for c in cols)
    _,r=q(f'select count(*) as N_, {sel} from GN_DW.GOLD.{t} sample (1)', cn)
    n=r[0][0]
    zero=[cols[i] for i in range(len(cols)) if r[0][i+1]==0]
    print(f"{t:<26} 표본 {n:>9,}행 · 표본 전건NULL 후보 {len(zero)}: {', '.join(zero) if zero else '-'}")
    cands += [(t,c) for c in zero]
print(f"\n후보 {len(cands)}건 → 전수 정확 확인")
out=[]
for t,c in cands:
    _,r=q(f'select count(*) N_, count("{c}") NN from GN_DW.GOLD.{t}', cn)
    tot,nn=r[0]
    d=desc[(t,c)]
    mentions = any(k in d for k in ('전건 NULL','NULL','해당없음','미노출','부재'))
    flag = '✅문안 언급' if mentions else '🔴문안 미언급'
    print(f"  {t}.{c:<24} {nn:,}/{tot:,} 비NULL  {flag}")
    out.append((t,c,tot,nn,mentions,d))
cn.close()
io.open('/tmp/nullscan_result.txt','w',encoding='utf-8').write(
  "\n".join(f"{t}.{c}\t{nn}/{tot}\t{'언급' if m else '미언급'}\t{d}" for t,c,tot,nn,m,d in out))
