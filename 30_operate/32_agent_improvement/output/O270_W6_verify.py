"""O270 W6 — 역할별 허용/차단 검증(개발계 ZS83821 · 2026-10-29).
테스트 사용자(현재 세션 사용자)에게 기능 역할을 임시 부여 → 검증 → 회수. 증거 = 12_agent개선과제/output/O270_W6_검증증거.csv"""
import os, csv
import snowflake.connector
tok = lambda: open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
def conn(role):
    return snowflake.connector.connect(host=os.environ.get('SNOWFLAKE_HOST'), account=os.environ.get('SNOWFLAKE_ACCOUNT'),
                                       authenticator='oauth', token=tok(), role=role, warehouse='GN_DW_ANALYTICS_WH')
OBJ = {  # 객체 → 분류
    'GOLD.FACT_MEMBER_MONTHLY': 'COMMON', 'GOLD.DIM_MARKETING_CAMPAIGN': 'COMMON',
    'GOLD.WIDE_AD_COMBINED': 'AGENCY', 'SERVING.ML_REALTIME_SIMULATOR_V': 'AGENCY',
    'GOLD.FACT_BUDGET': 'ERP', 'GOLD.FACT_EXPENSE_RESOLUTION': 'ERP',
    'GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST': 'AGENCY+ERP',
    'SERVING.SV_MEMBER_MONTHLY': 'COMMON', 'SERVING.SV_AD': 'AGENCY', 'SERVING.SV_BUDGET': 'ERP',
    'BRONZE_AGENCY.DGT_AD_CMPGN_DTLS': 'BRONZE', 'SILVER.CRM_MEMBER': 'SILVER',
}
ALLOW = {'GN_DW_FR_MARKETING': {'COMMON', 'AGENCY', 'ERP', 'AGENCY+ERP'}, 'GN_DW_FR_MEMBER': {'COMMON'},
         'GN_DW_FR_EXEC': {'COMMON', 'ERP'}, 'GN_DW_FR_LEAD': set()}
AGENT = {'GN_DW_FR_MARKETING': 'AGENT_MARKETING', 'GN_DW_FR_MEMBER': 'AGENT_MEMBER', 'GN_DW_FR_EXEC': 'AGENT_EXECUTIVE'}
adm = conn('SECURITYADMIN'); ac = adm.cursor()
ac.execute('SELECT CURRENT_USER()'); user = ac.fetchone()[0]
rows = []
try:
    for fr in ALLOW:
        ac.execute(f'GRANT ROLE {fr} TO USER "{user}"')
        c = conn(fr).cursor()
        for sec in ('NONE', 'ALL'):
            c.execute(f'USE SECONDARY ROLES {sec}')
            for o, k in OBJ.items():
                q = (f'SELECT 1 FROM SEMANTIC_VIEW(GN_DW.{o} DIMENSIONS {"date.PERF_DATE" if False else ""}) LIMIT 1'
                     if '.SV_' in o else f'SELECT 1 FROM GN_DW.{o} LIMIT 1')
                if '.SV_' in o:
                    q = f'DESCRIBE SEMANTIC VIEW GN_DW.{o}'
                try:
                    c.execute(q); got = 'OK'
                except Exception as e:
                    got = 'DENY' if ('not authorized' in str(e) or 'does not exist' in str(e)) else 'ERR:' + str(e)[:80]
                exp = 'OK' if k in ALLOW[fr] else 'DENY'
                rows.append([fr, sec, o, k, exp, got, 'PASS' if (sec == 'NONE' and got == exp) else ('INFO' if sec == 'ALL' else 'FAIL')])
            try:
                c.execute('SHOW AGENTS IN SCHEMA GN_DW.SERVING')
                seen = sorted(r[1] for r in c.fetchall())
            except Exception:
                seen = []  # 스키마 USAGE 없음 = Agent 0
            exp = [AGENT[fr]] if fr in AGENT else []
            rows.append([fr, sec, 'AGENT', 'USAGE', ','.join(exp), ','.join(seen),
                         'PASS' if (sec == 'NONE' and seen == exp) else ('INFO' if sec == 'ALL' else 'FAIL')])
finally:
    for fr in ALLOW:
        ac.execute(f'REVOKE ROLE {fr} FROM USER "{user}"')
    ac.execute(f'SHOW GRANTS TO USER "{user}"')
    left = [r[1] for r in ac.fetchall() if r[1].startswith('GN_DW_FR_')]
    print('임시 부여 회수 후 잔존 FR =', left)
with open('/workspace/12_agent개선과제/output/O270_W6_검증증거.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f); w.writerow(['role', 'secondary', 'object', 'class', 'expected', 'got', 'verdict']); w.writerows(rows)
from collections import Counter
print(Counter((r[1], r[6]) for r in rows))
for r in rows:
    if r[6] == 'FAIL': print('FAIL', r)
for r in rows:
    if r[1] == 'ALL' and r[4] != r[5]: print('ALL-diff', r[0], r[2], r[4], r[5]); break
