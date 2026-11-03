import os, json, warnings; warnings.filterwarnings("ignore")
import snowflake.connector
cn = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ['SNOWFLAKE_HOST'],
     authenticator='oauth', token=open(os.environ['SNOWFLAKE_TOKEN_FILE_PATH']).read().strip(), warehouse='COMPUTE_WH', role='ACCOUNTADMIN')
cur=cn.cursor()
out={}
for ag in ['AGENT_EXECUTIVE','AGENT_MEMBER','AGENT_MARKETING']:
    cur.execute(f"DESCRIBE AGENT GN_DW.SERVING.{ag}"); cols=[c[0] for c in cur.description]; r=cur.fetchone()
    sp=json.loads(r[cols.index('agent_spec')]); ins=sp.get('instructions',{})
    tools=sp.get('tools',[]); td=sum(len(t.get('tool_spec',{}).get('description') or '') for t in tools)
    out[ag]=dict(default=r[cols.index('default_version_name')], tools=len(tools),
      ins={k:len(v or '') for k,v in ins.items()}, tool_desc=td,
      samples=len(sp.get('sample_questions',[]) or (sp.get('profile') or {}).get('sample_questions',[]) or []))
cur.execute("SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING"); svs=[r[1] for r in cur.fetchall()]
vq={}
for s in svs:
    cur.execute(f"DESCRIBE SEMANTIC VIEW GN_DW.SERVING.{s}")
    rows=cur.fetchall(); vq[s]=len({r[1] for r in rows if r[0]=='AI_VERIFIED_QUERY'})
out['sv_count']=len(svs); out['vqr']=vq
import collections; out['vqr_hist']=dict(collections.Counter(vq.values()))
print(json.dumps(out,ensure_ascii=False,indent=0))
