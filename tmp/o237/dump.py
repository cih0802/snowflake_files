import os,csv,json
from snowflake.snowpark import Session
t=open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH","/snowflake/session/token")).read().strip()
s=Session.builder.configs({"account":os.environ["SNOWFLAKE_ACCOUNT"],"host":os.environ["SNOWFLAKE_HOST"],"authenticator":"oauth","token":t,"warehouse":"GN_DW_DEV_WH","role":"GN_DW_ADMIN"}).create()
r=s.sql("SELECT DOC_ID,DOC_TYPE,TITLE,FORMULA,TOOL_NAME,SV_FIELD,LIMITATION,SOURCE_FILE FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS WHERE HAS_FORMULA='Y' ORDER BY DOC_ID").collect()
with open("tmp/o237/formula_rows.csv","w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(r[0].as_dict().keys()); [w.writerow(x) for x in r]
d=s.sql("SHOW SEMANTIC DIMENSIONS IN SCHEMA GN_DW.SERVING").collect()
by={}
for x in d:
    x=x.as_dict(); by.setdefault(x["semantic_view_name"],[]).append(x["table_name"]+"."+x["name"])
with open("tmp/o237/sv_dims.txt","w",encoding="utf-8") as f:
    for k in sorted(by): f.write(k+": "+", ".join(by[k])+"\n")
print(len(r), len(d))
