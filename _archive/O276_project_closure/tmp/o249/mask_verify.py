import sys, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_DEV_WH')
c.execute("SELECT COUNT(*) FROM TABLE(GN_DW.INFORMATION_SCHEMA.POLICY_REFERENCES(POLICY_NAME => 'GN_DW.SECURITY.MP_PII_STRING'))")
print('refs', c.fetchone()[0])
c.execute("SELECT COUNT_IF(MBTLNUM = '***'), COUNT(MBTLNUM) FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO"); print('ADMIN masked/nonnull', c.fetchone())
c.execute('USE SECONDARY ROLES NONE'); c.execute('USE ROLE GN_DW_DBT')
for wh in ['GN_DW_ETL_WH','GN_DW_DBT_WH','GN_DW_ANALYTICS_WH']:
    try:
        c.execute('USE WAREHOUSE '+wh); print('dbt wh', wh); break
    except Exception: pass
c.execute("SELECT COUNT_IF(MBTLNUM = '***'), COUNT(MBTLNUM) FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO"); print('DBT masked/nonnull', c.fetchone())
c.execute('USE ROLE GN_DW_ANALYST'); c.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
c.execute("SELECT COUNT_IF(MBTLNUM = '***'), COUNT(MBTLNUM) FROM GN_DW.BRONZE_CRM.TM_PM_SETLE_INFO"); print('ANALYST masked/nonnull', c.fetchone())
c.execute('USE SECONDARY ROLES ALL')
