# O249 — 마케팅캠페인 미연결 CRM 캠페인 명단(공147·W6 현업 확인 첨부용)
import sys, csv, io, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
c = conn().cursor()
c.execute("""
SELECT c.CAMPAIGN_BK, c.CAMPAIGN_NAME, c.CAMPAIGN_TYPE, c.PARENT_CAMPAIGN_NAME, c.BRAND, c.CMMN_BRND_NM, c.INFLOW_PATH,
       c.MARKETING_CAMPAIGN, c.USE_YN, c.CAMPAIGN_OPEN_DATE,
       COUNT(e.MEMBER_DK) AS DEV_EVENTS_SINCE_2024
FROM GN_DW.GOLD.DIM_CAMPAIGN c
LEFT JOIN GN_DW.GOLD.FACT_MEMBER_EVENT e ON e.CAMPAIGN_SK = c.CAMPAIGN_SK AND e.DATE_SK >= 20240101
WHERE COALESCE(c.MKTG_CAMPAIGN_SK, 0) = 0
GROUP BY ALL
ORDER BY DEV_EVENTS_SINCE_2024 DESC, c.CAMPAIGN_BK""")
cols = [d[0] for d in c.description]
rows = c.fetchall()
with io.open('/workspace/12_agent개선과제/output/O249_마케팅캠페인_미연결_CRM캠페인.csv', 'w', encoding='utf-8-sig', newline='') as f:
    w = csv.writer(f); w.writerow(cols); w.writerows(rows)
print(len(rows), 'rows ·', sum(1 for r in rows if r[-1]), 'with dev since 2024 ·', sum(r[-1] for r in rows), 'events')
