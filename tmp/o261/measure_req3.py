import sys, json
sys.path.insert(0, '/workspace/scripts')
import sfconn

Q = {
 'D0_bronze_cols': """SELECT table_name, column_name, ordinal_position
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'BRONZE_AGENCY'
  AND ((table_name = 'VIDEO_AD_CMPGN_DTLS'  AND column_name IN ('UPPER_CMPGN_NM','UPPER_CMPGN_CD'))
    OR (table_name = 'REBRDC_AD_CMPGN_DTLS' AND column_name IN ('CMPGN_CD','MKTG_CMPGN_NM')))
ORDER BY 1, 3""",
 'D1_silver_cols': """SELECT table_name, column_name
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER'
  AND ((table_name = 'AGENCY_AD_ROW_VIDEO'  AND column_name IN ('UPPER_CMPGN_NM','UPPER_CMPGN_CD'))
    OR (table_name = 'AGENCY_AD_ROW_REBRDC' AND column_name IN ('CMPGN_CD','MKTG_CMPGN_NM')))
ORDER BY 1, 2""",
 'D0b_fill': """SELECT 'VIDEO.UPPER_CMPGN_CD', COUNT(*), COUNT(UPPER_CMPGN_CD), COUNT(DISTINCT UPPER_CMPGN_CD)
FROM GN_DW.BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS
UNION ALL
SELECT 'REBRDC.MKTG_CMPGN_NM', COUNT(*), COUNT(MKTG_CMPGN_NM), COUNT(DISTINCT MKTG_CMPGN_NM)
FROM GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS""",
 'D0c_name_match': """SELECT COUNT(*), COUNT(mk.MKTG_CAMPAIGN_SK)
FROM GN_DW.BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS r
LEFT JOIN GN_DW.GOLD.DIM_MARKETING_CAMPAIGN mk
  ON mk.MKTG_CAMPAIGN_NAME = NULLIF(TRIM(r.MKTG_CMPGN_NM), '')
WHERE NULLIF(TRIM(r.MKTG_CMPGN_NM), '') IS NOT NULL""",
 'D2_1_src': """SELECT AD_SOURCE_TYPE, COUNT(*), SUM(AD_COST)
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE GROUP BY 1 ORDER BY 1""",
 'D2_2_map': """SELECT AD_SOURCE_TYPE, MKTG_MAP_METHOD, COUNT(*)
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE
WHERE AD_SOURCE_TYPE IN ('VIDEO','REBROADCAST') GROUP BY 1,2 ORDER BY 1,2""",
 'D2_3_orphan': """SELECT COUNT(*)
FROM GN_DW.SILVER.AGENCY_AD_PERFORMANCE p
LEFT JOIN GN_DW.SILVER.AGENCY_AD_ROW_VIDEO v ON v.AD_PERF_DK = p.AD_PERF_DK
WHERE p.AD_SOURCE_TYPE = 'VIDEO' AND v.AD_PERF_DK IS NULL""",
}

cn = sfconn.conn()
cur = cn.cursor()
cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
cur.execute('SELECT CURRENT_ACCOUNT(), CURRENT_TIMESTAMP()::STRING')
print('ACCOUNT/TS', cur.fetchone())
for k, sql in Q.items():
    try:
        cur.execute(sql)
        print(k, [tuple(str(x) for x in r) for r in cur.fetchall()])
    except Exception as e:
        print(k, 'ERROR', e)
cn.close()
