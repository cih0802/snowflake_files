# O209 — MEMBER·MARKETING native eval 데이터셋(코퍼스 단위 = 회원 13 · 마케팅 14)
# 정답 = 기대 도구(ground_truth_invocations.tool_name) + 기대 행동 서술(수치 없음 · 값 대조는 하지 않는다)
# 사용: python3 tmp/o209_eval_ds.py
# Co-authored with CoCo
import csv, json, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
SRC = '/workspace/12_agent개선과제/06_O208_문항코퍼스.csv'
STAMP = '20261007_O209'
SET = {'회원': 'AGENT_MEMBER', '마케팅': 'AGENT_MARKETING'}
rows = list(csv.DictReader(open(SRC, encoding='utf-8')))
cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
cur.execute('USE DATABASE GN_DW'); cur.execute('USE SCHEMA SERVING')


def expect(r):
    tools = [t.strip() for t in r['정답 도구'].split(';') if t.strip()]
    s = f"{r['기대 기준']} 기준으로 {' · '.join(tools)} 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기)."
    if r['계산 전 확인'] == 'Y':
        s += ' 정의된 산식이 없는 지표이므로 바로 계산하지 않고 쓸 가정을 1~3줄로 제시한 뒤 계산할지 묻는다.'
    if r['비고']:
        s += f" 유의: {r['비고']}."
    return tools, s


for unit, agent in SET.items():
    tbl = f'GN_DW.SERVING.EVAL_DATASET_{agent}_{STAMP}'
    cur.execute(f'CREATE TABLE IF NOT EXISTS {tbl} (QUESTION_ID INT, INPUT_QUERY STRING, GROUND_TRUTH VARIANT, '
                'CATEGORY STRING, TRACK STRING, AUTHOR STRING, CREATED_AT TIMESTAMP_NTZ, NOTES STRING)')
    cur.execute(f'SELECT COUNT(*) FROM {tbl}')
    if cur.fetchone()[0] == 0:
        i = 0
        for r in rows:
            if r['질문단위_수정안'] != unit:
                continue
            i += 1
            tools, out = expect(r)
            gt = json.dumps({'ground_truth_invocations': [{'tool_name': t} for t in tools], 'ground_truth_output': out},
                            ensure_ascii=False)
            cat = 'instruction_compliance' if r['계산 전 확인'] == 'Y' else 'core_use_case'
            cur.execute(f'INSERT INTO {tbl} SELECT %s, %s, PARSE_JSON(%s), %s, %s, CURRENT_USER(), CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, %s',
                        (i, r['질문'], gt, cat, 'tsa', f"O209 {r['문항ID']} · 기대 행동만(값 대조 없음)"))
    name = f'{agent.lower()}_o209_{STAMP.split("_")[0]}'
    cur.execute(f"CALL SYSTEM$CREATE_EVALUATION_DATASET('Cortex Agent', '{tbl}', '{name}', "
                "OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH'))")
    print(agent, tbl, name, cur.fetchone())
