# O266 — 46 의 @@MCC_DDL@@ 자리에 06_DDL 의 FACT_MKTG_CAMPAIGN_MONTHLY_COST 블록을 IF NOT EXISTS 판으로 이식(셸 경유 금지 · R1-7-9)
import io
ddl = io.open('/workspace/03_top-down_gold/06_DDL.sql', encoding='utf-8').read()
head = 'CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST ('
i = ddl.index(head)
j = ddl.index("(O266)';", i) + len("(O266)';")
block = ddl[i:j].replace('CREATE OR REPLACE TABLE', 'CREATE TABLE IF NOT EXISTS', 1)
assert ddl.count(head) == 1 and block.count('PRIMARY KEY (MKTG_CAMPAIGN_SK, MONTH_KEY)') == 1
p = '/workspace/05_SV-Agent_ai/46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql'
t = io.open(p, encoding='utf-8').read()
assert t.count('@@MCC_DDL@@') == 1
io.open(p, 'w', encoding='utf-8').write(t.replace('@@MCC_DDL@@', block))
print('ok', block.count('\n') + 1, 'lines')
