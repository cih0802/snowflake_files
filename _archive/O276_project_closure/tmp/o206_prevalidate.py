# O206 — dbt 모델을 ref → 라이브 FQN 으로 렌더해 사전 검증(컴파일 + 그룹별 기대값) · dbt 명령 아님(R4-1)
# 사용: python3 tmp/o206_prevalidate.py
# Co-authored with CoCo
import re, sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

SILVER = {'CRM_CODE', 'CRM_MSG_TEMPLATE', 'CRM_ORG'}
src = open('/workspace/10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_SERVICE_COHORT.sql', encoding='utf-8').read()
src = re.sub(r'\{\{\s*config\(.*?\)\s*\}\}', '', src, flags=re.S)
src = re.sub(r"\{\{\s*ref\('([A-Z_]+)'\)\s*\}\}",
             lambda m: f"GN_DW.{'SILVER' if m.group(1) in SILVER else 'GOLD'}.{m.group(1)}", src)
body = '\n'.join(l for l in src.split('\n') if not l.strip().startswith('--'))
open('/workspace/tmp/o206_rendered.sql', 'w', encoding='utf-8').write(body)

c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
c.execute('CREATE OR REPLACE TEMPORARY VIEW SANDBOX.PUBLIC.O206_WMSC_PREVIEW AS ' + body) if False else None
t = time.time()
q = f"""
with v as ({body})
select SERVICE_GROUP_CD, RECEIVE_YEAR, MATCH_BASIS,
       count(distinct MEMBER_DK) members,
       count(distinct iff(RECEIVED_SADAN_FLAG, MEMBER_DK, null)) sadan,
       count(distinct iff(RECEIVED_SABOK_FLAG, MEMBER_DK, null)) sabok,
       count(distinct iff(RECEIVED_TONGHAP_FLAG, MEMBER_DK, null)) tonghap,
       count(distinct iff(CULTURE_EVENT_PART_ROWS > 0, MEMBER_DK, null)) culture_part,
       count(distinct iff(ONLINE_EVENT_PART_ROWS > 0, MEMBER_DK, null)) online_part,
       any_value(CHRG_DEPT_NAMES) dept_sample
from v where RECEIVED_FLAG and RECEIVE_YEAR >= 2024
group by 1,2,3 order by 1,2,3
"""
c.execute(q)
cols = [d[0] for d in c.description]
print(' | '.join(cols))
for r in c.fetchall():
    print(' | '.join('' if x is None else str(x)[:60] for x in r))
print('elapsed %.1fs' % (time.time() - t), 'qid', c.sfqid)
