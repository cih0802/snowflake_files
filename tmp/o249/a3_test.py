# O249-B — A3 ㉢ 롤 경로 검증(GN_DW_ANALYST 로 Agent·Analyst SQL 호출) · 🔴 LLM 과금 1회
import sys, json, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, '/workspace/scripts'); sys.path.insert(0, '/workspace/tmp/o245')
from sfconn import conn
from agent_test import texts
c = conn().cursor()
c.execute('USE ROLE GN_DW_ANALYST'); c.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
c.execute('SELECT CURRENT_ROLE()'); print('role', c.fetchone()[0])
c.execute("SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT_COHORT DIMENSIONS mec.DVLP_DIV_NM METRICS mec.EVENT_MEMBERS WHERE mec.MONTHS_AFTER = 12) LIMIT 2")
print('SV ok', c.fetchall())
req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': '최근 12개월 개발인입경로별 개발단가 상위 3개만 알려줘'}]}]}, ensure_ascii=False)
c.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.AGENT_MARKETING', req))
ans, sqls = texts(c.fetchall()[0][0])
print('AGENT ok', len(ans), 'chars ·', len(sqls), 'sql ·', ans[:300].replace('\n', ' '))
