# O211 — native eval 데이터셋 3종 재등록(새 계정 nj58180 · 코퍼스 단위 = 경영·기획 21 · 회원 13 · 마케팅 14)
# 정답 = 기대 도구(ground_truth_invocations) + 기대 행동 서술(수치 없음) · o209_eval_ds.py 와 같은 규칙 · 컬럼 = 스킬 규격
# 사용: python3 tmp/o211_eval_ds.py
# Co-authored with CoCo
import csv, json, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
SRC = '/workspace/12_agent개선과제/06_O208_문항코퍼스.csv'
SET = {'경영·기획': 'AGENT_EXECUTIVE', '회원': 'AGENT_MEMBER', '마케팅': 'AGENT_MARKETING'}
# [O211 v2] 도구를 쓰지 않는 것이 정답인 문항 = ground_truth_invocations [] (가드레일 · 스킬 규격)
# 근거 = X6 판정 무도구정답(미정의 지표 계산 전 확인 · GA 답변불가 고정 문구 · 회원 단위 LTV 원천 없음)
# Q03·Q13 은 커버리지 조회로 도구를 쓰는 것이 정상이라 제외한다
NOTOOL = {'Q05', 'Q06', 'Q17', 'Q19', 'Q20', 'Q21', 'Q23', 'Q24', 'Q25', 'Q26', 'Q27', 'Q30'}
VER = '_V2' if '--v2' in sys.argv else ''
if VER:
    SET = {k: v for k, v in SET.items() if v != 'AGENT_MEMBER'}  # MEMBER 는 해당 문항 0 — v1 그대로
rows = list(csv.DictReader(open(SRC, encoding='utf-8')))
cur = conn().cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ETL_WH')
cur.execute('USE DATABASE GN_DW'); cur.execute('USE SCHEMA SERVING')  # 데이터셋 등록 함수가 세션 스키마를 요구한다


def expect(r):
    tools = [t.strip() for t in r['정답 도구'].split(';') if t.strip()]
    if VER and r['문항ID'] in NOTOOL:
        s = '데이터 도구를 호출해 수치를 계산하지 않는다.'
        if r['계산 전 확인'] == 'Y':
            s += ' 사전에 정해진 산식이 없는 지표라고 밝히고 쓸 가정을 1~3줄로 제시한 뒤 계산할지 묻는다.'
        else:
            s += ' 현재 데이터로는 답변할 수 없다고 밝히고 가능한 대안을 안내한다.'
        if r['비고']:
            s += f" 유의: {r['비고']}."
        return [], s
    s = f"{r['기대 기준']} 기준으로 {' · '.join(tools)} 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기)."
    if r['계산 전 확인'] == 'Y':
        s += ' 정의된 산식이 없는 지표이므로 바로 계산하지 않고 쓸 가정을 1~3줄로 제시한 뒤 계산할지 묻는다.'
    if r['비고']:
        s += f" 유의: {r['비고']}."
    return tools, s


for unit, agent in SET.items():
    tbl = f'GN_DW.SERVING.EVAL_O211_{agent}{VER}'
    cur.execute(f'CREATE TABLE IF NOT EXISTS {tbl} (INPUT_QUERY STRING, EXPECTED_OUTPUT VARIANT, QUESTION_ID STRING, TRACK STRING)')
    cur.execute(f'SELECT COUNT(*) FROM {tbl}')
    if cur.fetchone()[0] == 0:
        for r in rows:
            if r['질문단위_수정안'] != unit:
                continue
            tools, out = expect(r)
            gt = json.dumps({'ground_truth_invocations': [{'tool_name': t} for t in tools], 'ground_truth_output': out},
                            ensure_ascii=False)
            cur.execute(f'INSERT INTO {tbl} SELECT %s, PARSE_JSON(%s), %s, %s', (r['질문'], gt, r['문항ID'], 'tea'))
    cur.execute(f'SELECT COUNT(*), COUNT_IF(ARRAY_SIZE(EXPECTED_OUTPUT:ground_truth_invocations) = 0) FROM {tbl}')
    print(agent, tbl, cur.fetchone())
    if VER:
        ds = f'O211_{agent.split("_")[1]}_DS{VER}'
        cur.execute(f"CALL SYSTEM$CREATE_EVALUATION_DATASET('Cortex Agent', '{tbl}', '{ds}', "
                    "OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'EXPECTED_OUTPUT'))")
        print(ds, cur.fetchone())
