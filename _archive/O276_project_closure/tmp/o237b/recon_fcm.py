# FACT_CAMPAIGN_MONTHLY 렌더본 ↔ FMM 202609 합계 대사(읽기 전용)
import os, sys
sys.path.insert(0, 'tmp/o237b')
from render import render
from snowflake.snowpark import Session
t=open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH","/snowflake/session/token")).read().strip()
s=Session.builder.configs({"account":os.environ["SNOWFLAKE_ACCOUNT"],"host":os.environ["SNOWFLAKE_HOST"],"authenticator":"oauth","token":t,"warehouse":"GN_DW_ANALYTICS_WH","role":"GN_DW_ADMIN","database":"GN_DW","schema":"OPS"}).create()
g=lambda n:'GN_DW.GOLD.'+n
m={n:g(n) for n in ['FACT_MEMBER_MONTHLY','FACT_MEMBER_SPONSORSHIP_SPAN','FACT_MEMBER_FEE','FACT_MEMBER_EVENT','DIM_CAMPAIGN']}
m['CRM_MEMBER_AMT_CHANGE']='GN_DW.SILVER.CRM_MEMBER_AMT_CHANGE'
sql=render('10_dbt_pipeline/models/gold/fact/FACT_CAMPAIGN_MONTHLY.sql', m)
open('tmp/o237b/fcm_rendered.sql','w').write(sql)
s.sql("create or replace temporary table FCM_PROBE as "+sql).collect()
q="""with f as (select * from FCM_PROBE where BASE_MONTH_KEY = %d),
m as (select SUM(ACTIVE_CNT) a, SUM(PREV_MONTH_END_ACTIVE_CNT) p, SUM(STOP_AMT_CNT) st, SUM(DEV_CNT) d, SUM(DECREASE_CNT) dc, SUM(CHURN_CNT) ch, SUM(PAID_FEE_BILLABLE) pf, SUM(UNPAID_BILLED_AMT) up from GN_DW.GOLD.FACT_MEMBER_MONTHLY where MONTH_KEY=%d)
select (select SUM(ACTIVE_CNT) from f)-a d_active, (select SUM(PREV_MONTH_END_ACTIVE_CNT) from f)-p d_prev, (select SUM(STOP_CNT) from f)-st d_stop,
 (select SUM(DEV_CNT) from f)-d d_dev, (select SUM(DECREASE_CNT) from f)-dc d_dec, (select SUM(CHURN_CNT) from f)-ch d_churn, (select SUM(PAID_FEE_BILLABLE) from f)-pf d_paid, (select SUM(UNPAID_BILLED_AMT) from f)-up d_unpaid,
 (select SUM(YEAR_START_ACTIVE_CNT) from f) ys, (select SUM(CUM_STOP_CNT) from f) cs, (select SUM(CUM_DEV_CNT) from f) cd,
 (select SUM(STOP_CNT) from f where CAMPAIGN_SK=0)/NULLIF((select SUM(STOP_CNT) from f),0) stop_sk0,
 (select SUM(ACTIVE_CNT) from f where CAMPAIGN_SK=0)/NULLIF((select SUM(ACTIVE_CNT) from f),0) act_sk0,
 (select SUM(ACTIVE_CNT) from f where PAYMENT_SK=0)/NULLIF((select SUM(ACTIVE_CNT) from f),0) act_pay0,
 (select COUNT(*) from f) n_rows from m"""
for mk in (202601, 202609):
    print(mk, s.sql(q % (mk, mk)).collect()[0].as_dict())
print('total rows', s.sql("select count(*) from FCM_PROBE").collect()[0][0])
print('dup keys', s.sql("select count(*) from (select BASE_MONTH_KEY,CAMPAIGN_SK,PAYMENT_SK from FCM_PROBE group by 1,2,3 having count(*)>1)").collect()[0][0])
