# WIDE_MEMBER_SERVICE_COHORT 확장 렌더본 검증(읽기 전용 · 임시 테이블) — 기존 열 = 라이브 뷰와 동일 · 신규 열 분포
import os, sys
sys.path.insert(0, 'tmp/o237b')
from render import render
from snowflake.snowpark import Session
t=open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH","/snowflake/session/token")).read().strip()
s=Session.builder.configs({"account":os.environ["SNOWFLAKE_ACCOUNT"],"host":os.environ["SNOWFLAKE_HOST"],"authenticator":"oauth","token":t,"warehouse":"GN_DW_ANALYTICS_WH","role":"GN_DW_ADMIN","database":"GN_DW","schema":"OPS"}).create()
m={n:'GN_DW.GOLD.'+n for n in ['DIM_DATE','DIM_EVENT','DIM_MEMBER_ACQUISITION','DIM_SEND_REQUEST','DIM_SPONSORSHIP','FACT_EVENT_ATTENDANCE','FACT_MEMBER_EVENT','FACT_MEMBER_FEE','FACT_MEMBER_MONTHLY','FACT_MEMBER_SPONSORSHIP_SPAN','FACT_MESSAGE_DISPATCH']}
for n in ['CRM_CODE','CRM_MSG_TEMPLATE','CRM_ORG']: m[n]='GN_DW.SILVER.'+n
sql=render('10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_SERVICE_COHORT.sql', m)
s.sql("create or replace temporary table COH_PROBE as "+sql).collect()
cols=[r[0] for r in s.sql("select column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema='GOLD' and table_name='WIDE_MEMBER_SERVICE_COHORT' order by ordinal_position").collect()]
print('live cols', len(cols))
keycols=', '.join(cols)
diff=s.sql(f"select (select count(*) from (select {keycols} from COH_PROBE minus select {keycols} from GN_DW.GOLD.WIDE_MEMBER_SERVICE_COHORT)) a, (select count(*) from (select {keycols} from GN_DW.GOLD.WIDE_MEMBER_SERVICE_COHORT minus select {keycols} from COH_PROBE)) b, (select count(*) from COH_PROBE) n, (select count(*) from GN_DW.GOLD.WIDE_MEMBER_SERVICE_COHORT) n_live").collect()[0].as_dict()
print('old-col diff', diff)
print(s.sql("""select SERVICE_GROUP_NAME, COUNT_IF(RECEIVED_FLAG) rcv, COUNT_IF(D5_LETTER_FLAG) letter, COUNT_IF(D5_GIFT_FLAG) gift, COUNT_IF(D5_INCREASE_FLAG) inc,
 ROUND(AVG(IFF(RETAINED_3M_FLAG,1,0)) FILTER... ,1) x from COH_PROBE group by 1""".replace(" ROUND(AVG(IFF(RETAINED_3M_FLAG,1,0)) FILTER... ,1) x"," COUNT(RETAINED_3M_FLAG) obs3, COUNT_IF(RETAINED_3M_FLAG) ret3, COUNT(RETAINED_12M_FLAG) obs12, COUNT_IF(RETAINED_12M_FLAG) ret12, COUNT(PAID_AFTER_3M_FLAG) obsp, COUNT_IF(PAID_AFTER_3M_FLAG) paid")).collect())
print('nonrcv non-null', s.sql("select COUNT_IF(RETAINED_3M_FLAG is not null or PAID_AFTER_3M_FLAG is not null or D5_LETTER_FLAG) from COH_PROBE where not RECEIVED_FLAG").collect()[0][0])
