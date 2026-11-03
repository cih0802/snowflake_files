# O224 P0-3c — AC<0.7 문항의 판정 근거(METRIC_CALLS 원문 발췌) + 답변 앞부분
import csv, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
tag = sys.argv[1]
AG = {'executive': 'AGENT_EXECUTIVE', 'member': 'AGENT_MEMBER', 'marketing': 'AGENT_MARKETING'}
rows = list(csv.DictReader(open(f'/workspace/tmp/o224/p03_{tag}.csv', encoding='utf-8')))
bad = {(r['agent'], r['qid']) for r in rows if r['AC'] and float(r['AC']) < 0.7}
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
with open(f'/workspace/tmp/o224/p03c_{tag}.txt', 'w', encoding='utf-8') as f:
    for k, agent in AG.items():
        c.execute(f"""SELECT e.QUESTION_ID, ANY_VALUE(r.INPUT), ANY_VALUE(r.OUTPUT)::string, ANY_VALUE(r.METRIC_CALLS)::string,
                      ANY_VALUE(e.EXPECTED_OUTPUT:ground_truth_output)::string
                      FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('GN_DW','SERVING','{agent}','CORTEX AGENT','o224_{k}_{tag}')) r
                      JOIN GN_DW.SERVING.EVAL_O224_{agent}_V3 e ON e.INPUT_QUERY = r.INPUT
                      WHERE r.METRIC_NAME = 'answer_correctness' GROUP BY 1""")
        for qid, inp, outp, calls, gto in c.fetchall():
            if (agent, qid) not in bad:
                continue
            ans = re.sub(r'\s+', ' ', outp or '')
            why = re.sub(r'\s+', ' ', calls or '')
            f.write(f'## {agent} {qid}\n- 질문: {inp}\n- 기대: {gto}\n- 답변(앞 500자): {ans[:500]}\n')
            m = re.search(r'(?:explanation|reasoning|criteria)', why)
            f.write(f'- 판정(발췌 700자): {why[m.start():m.start()+700] if m else why[:700]}\n\n')
print('bad', len(bad))
