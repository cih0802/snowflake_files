# O224 P0-3b — 실패 문항(① 도구선택)의 실제 호출 도구 추출(OUTPUT/GROUND_TRUTH 원문에서 도구명 토큰 수집)
import csv, json, re, sys, collections
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
tag = sys.argv[1]
AG = {'executive': 'AGENT_EXECUTIVE', 'member': 'AGENT_MEMBER', 'marketing': 'AGENT_MARKETING'}
rows = list(csv.DictReader(open(f'/workspace/tmp/o224/p03_{tag}.csv', encoding='utf-8')))
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
TOK = re.compile(r'\b(analyst_[a-z0-9_]+|search_biz_definition|data_to_chart|web_search)\b')
for k, agent in AG.items():
    c.execute(f"""SELECT e.QUESTION_ID, ANY_VALUE(r.OUTPUT)::string, ANY_VALUE(r.GROUND_TRUTH)::string,
                  ANY_VALUE(r.METRIC_CALLS)::string
                  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','{agent}','CORTEX AGENT','o224_{k}_{tag}')) r
                  JOIN GN_DW.SERVING.EVAL_O224_{agent}_V3 e ON e.INPUT_QUERY = r.INPUT
                  WHERE r.METRIC_NAME = 'tool_selection_accuracy' GROUP BY 1""")
    for qid, outp, gt, calls in c.fetchall():
        r = next(x for x in rows if x['agent'] == agent and x['qid'] == qid)
        if r['class'] == '⭕':
            continue
        used = collections.Counter(TOK.findall(outp or ''))
        gtt = sorted(set(TOK.findall(gt or '')))
        why = ''
        m = re.search(r'"(?:explanation|reason|criteria)[^"]*"\s*:\s*"([^"]{0,260})', calls or '')
        if m:
            why = m.group(1)
        print(agent, qid, r['class'], 'TS', r['TS'], 'AC', r['AC'], '| 정답', gtt or '[]', '| 출력 언급', dict(used), '|', why[:200])
