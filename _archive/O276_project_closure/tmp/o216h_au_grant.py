import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
c = conn().cursor()
def q(s):
    try:
        c.execute(s); return c.fetchall()[:3]
    except Exception as e:
        return 'ERR ' + str(e)[:160]
c.execute('USE ROLE ACCOUNTADMIN')
for r in ('USAGE_VIEWER', 'GOVERNANCE_VIEWER'):
    print(r, q(f'GRANT DATABASE ROLE SNOWFLAKE.{r} TO ROLE GN_DW_ADMIN'))
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
for v in ('SNOWFLAKE_COCO_USAGE_HISTORY', 'SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY', 'CORTEX_AGENT_USAGE_HISTORY',
          'CORTEX_AISQL_USAGE_HISTORY', 'USERS', 'CORTEX_ANALYST_USAGE_HISTORY', 'QUERY_ATTRIBUTION_HISTORY',
          'WAREHOUSE_METERING_HISTORY', 'METERING_DAILY_HISTORY'):
    print(v, q(f'SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.{v}'))
