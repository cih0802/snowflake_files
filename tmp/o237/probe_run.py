# 임시 probe SV 생성 → 신규 metric 값 조회 → GOLD 직접 계산과 대조 → probe DROP (라이브 SERVING SV 무변경)
import os
from snowflake.snowpark import Session
t=open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH","/snowflake/session/token")).read().strip()
s=Session.builder.configs({"account":os.environ["SNOWFLAKE_ACCOUNT"],"host":os.environ["SNOWFLAKE_HOST"],"authenticator":"oauth","token":t,"warehouse":"GN_DW_DEV_WH","role":"GN_DW_ADMIN"}).create()
files=["05_01_SV_DDL_MEMBER_MONTHLY","05_09_SV_DDL_MEMBER_FEE","05_19_SV_DDL_PAYMENT_BILLING_STATUS","05_24_SV_DDL_CAMPAIGN_CUM_STOP","05_04_SV_DDL_SERVICE"]
made=[]
try:
    for f in files:
        sql=open("tmp/o237/probe_%s.sql"%f,encoding="utf-8").read()
        s.sql(sql).collect(); nm=sql.split()[5]; assert nm.startswith("GN_DW.OPS.") and nm.endswith("_O237_PROBE"), nm; made.append(nm); print("CREATED", nm)
    Q=[
     ("FMM", "SELECT * FROM SEMANTIC_VIEW(GN_DW.OPS.SV_MEMBER_MONTHLY_O237_PROBE DIMENSIONS month.MONTH_KEY METRICS fmm.STOP_AMT_CNT_SUM, fmm.CNT_PER_ACTIVE_MEMBER, fmm.AVG_PLEDGE_AMT, fmm.PAY_IN_RATE, fmm.REGULAR_ONETIME_FEE_SUM, fmm.ONETIME_ONETIME_FEE_SUM, fmm.PAYMENT_RATE_FEE) WHERE MONTH_KEY=202609"),
     ("FMM_CUM", "SELECT PAY_IN_RATE FROM SEMANTIC_VIEW(GN_DW.OPS.SV_MEMBER_MONTHLY_O237_PROBE DIMENSIONS month.MONTH_KEY METRICS fmm.PAY_IN_RATE) WHERE MONTH_KEY BETWEEN 202601 AND 202609"),
     ("FEE", "SELECT * FROM SEMANTIC_VIEW(GN_DW.OPS.SV_MEMBER_FEE_O237_PROBE DIMENSIONS fee.MONTH_KEY METRICS fee.AVG_PAID_PER_MEMBER) WHERE MONTH_KEY=202609"),
     ("PBS", "SELECT * FROM SEMANTIC_VIEW(GN_DW.OPS.SV_PAYMENT_BILLING_STATUS_O237_PROBE DIMENSIONS pbs.MONTH_KEY METRICS pbs.UNPAID_CNT_EQ) WHERE MONTH_KEY=202609"),
     ("CUM", "SELECT * FROM SEMANTIC_VIEW(GN_DW.OPS.SV_CAMPAIGN_CUM_STOP_O237_PROBE DIMENSIONS fccs.BASE_MONTH_KEY METRICS fccs.CUM_STOP_RATE_DEV, fccs.CUM_STOP_RATE) WHERE BASE_MONTH_KEY=202609"),
     ("SVC", "SELECT * FROM SEMANTIC_VIEW(GN_DW.OPS.SV_SERVICE_O237_PROBE METRICS fse.D5_LETTER_RATE, fse.D5_GIFT_RATE, fse.D5_INCREASE_RATE)"),
    ]
    for k,q in Q:
        r=s.sql(q).collect()
        print(k, [x.as_dict() for x in r][:3] if k!="FMM_CUM" else len(r))
    # 누계납입율 = 1~9월 단일 값(기간 필터 · 그룹 없음)
    r=s.sql("SELECT SUM(PAID_FEE_BILLABLE)/NULLIF(SUM(ACTIVE_CNT)*10000,0)*100 FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY WHERE MONTH_KEY BETWEEN 202601 AND 202609").collect()
    print("GOLD 누계납입율 1~9월 =", r[0][0])
    r=s.sql("SELECT PAY_IN_RATE FROM SEMANTIC_VIEW(GN_DW.OPS.SV_MEMBER_MONTHLY_O237_PROBE METRICS fmm.PAY_IN_RATE WHERE month.MONTH_KEY BETWEEN 202601 AND 202609)").collect()
    print("SV 누계납입율 1~9월 =", r[0][0])
finally:
    for n in made:
        s.sql("DROP SEMANTIC VIEW IF EXISTS "+n).collect(); print("DROPPED", n)
