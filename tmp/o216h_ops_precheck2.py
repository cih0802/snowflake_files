import sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
c = conn().cursor()
def q(s):
    try:
        c.execute(s); return c.fetchall()
    except Exception as e:
        return 'ERR ' + str(e)[:300]
c.execute('USE ROLE ACCOUNTADMIN')
g = q('SHOW GRANTS TO ROLE GN_DW_ADMIN')
print('admin_acct', [(r[1], r[2], r[3]) for r in g if r[2] in ('ACCOUNT', 'DATABASE') or 'SNOWFLAKE' in str(r[3])])
print('ml_params', [(r[0], r[1]) for r in q("SHOW PARAMETERS LIKE 'STATEMENT%' IN WAREHOUSE GN_DW_ML_WH")])
print('ml_wh_grants', [(r[1], r[5]) for r in q('SHOW GRANTS ON WAREHOUSE GN_DW_ML_WH')])
print('sec_owner', q("SHOW SCHEMAS LIKE 'SECURITY' IN DATABASE GN_DW"))
c.execute('USE ROLE GN_DW_ADMIN')
print('admin_au', q('SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY'))
print('ml_usage', q("SELECT DATE_TRUNC('month',start_time)::date m, ROUND(SUM(credits_used),3) FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY GROUP BY 1 ORDER BY 1"))
