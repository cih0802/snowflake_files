# O216 — 신규 계정 CK24285 eval 인프라 재구축 + 데이터셋 V3(A안 · 6차 롤백 결정 존중)
# V2 = O211 규칙 그대로 재현(데이터셋 이름도 O211_* 그대로 · 기존 resolved.yaml 무수정 재사용)
# V3 = A안 정정: EXEC Q03·Q04·Q05·Q06·Q07 → 회원 분석 어시스턴트 안내(무도구) · X1·X2 → analyst_mstr_spnsr_dvlp
#      MEMBER R15 → analyst_ga_behavior 제외(MEMBER 에 없는 도구 · O215-A-0 ㉠)
# 사용: python3 tmp/o216_eval_ds.py v2 | v3
# Co-authored with CoCo
import csv, json, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
SRC = '/workspace/12_agent개선과제/06_O208_문항코퍼스.csv'
SET = {'경영·기획': 'AGENT_EXECUTIVE', '회원': 'AGENT_MEMBER', '마케팅': 'AGENT_MARKETING'}
NOTOOL = {'Q05', 'Q06', 'Q17', 'Q19', 'Q20', 'Q21', 'Q23', 'Q24', 'Q25', 'Q26', 'Q27', 'Q30'}
V3_GUIDE = {'Q03', 'Q04', 'Q05', 'Q06', 'Q07'}          # EXEC → AGENT_MEMBER 안내
V3_MSTR = {'X1', 'X2'}                                   # EXEC → MSTR 도구(O212-B 규칙)
V3_DROP = {'AGENT_MEMBER': {'analyst_ga_behavior'}}
MODE = sys.argv[1]
assert MODE in ('v2', 'v3')
rows = list(csv.DictReader(open(SRC, encoding='utf-8')))
cur = conn().cursor()
cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ETL_WH')  # O216-B: ACCOUNTADMIN → GN_DW_ADMIN(eval 요건 실측 충족)
cur.execute('USE DATABASE GN_DW'); cur.execute('USE SCHEMA SERVING')
cur.execute('CREATE STAGE IF NOT EXISTS GN_DW.SERVING.EVAL_CONFIG_STAGE DIRECTORY = (ENABLE = TRUE)')


def expect(r, agent):
    qid = r['문항ID']
    tools = [t.strip() for t in r['정답 도구'].split(';') if t.strip()]
    if MODE == 'v3' and agent == 'AGENT_EXECUTIVE' and qid in V3_GUIDE:
        s = ('이 Agent 에는 해당 회비 예측·회비 분해 도구가 없다 — 데이터 도구로 수치를 만들지 않고 '
             '「회원 분석 어시스턴트에서 조회 가능합니다」라고 안내한다.')
        if r['계산 전 확인'] == 'Y':
            s += ' 사전 산식이 없는 지표임도 함께 밝힌다.'
        return [], s
    if MODE == 'v3' and agent == 'AGENT_EXECUTIVE' and qid in V3_MSTR:
        return (['analyst_mstr_spnsr_dvlp'],
                'MSTR 기준으로 analyst_mstr_spnsr_dvlp 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 「MSTR 기준」 표기 · '
                '개발 실적을 캠페인카테고리·개발인입경로 축으로 물으면 MSTR 도구 · O212-B).')
    if MODE == 'v3':
        tools = [t for t in tools if t not in V3_DROP.get(agent, set())]
    if agent != 'AGENT_MEMBER' and qid in NOTOOL:
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
    short = agent.split('_')[1]
    if MODE == 'v2':
        sfx = '' if agent == 'AGENT_MEMBER' else '_V2'
        tbl, ds = f'GN_DW.SERVING.EVAL_O211_{agent}{sfx}', f'O211_{short}_DS{sfx}'
    else:
        tbl, ds = f'GN_DW.SERVING.EVAL_O216_{agent}_V3', f'O216_{short}_DS_V3'
    cur.execute(f'CREATE TABLE IF NOT EXISTS {tbl} (INPUT_QUERY STRING, EXPECTED_OUTPUT VARIANT, QUESTION_ID STRING, TRACK STRING)')
    cur.execute(f'SELECT COUNT(*) FROM {tbl}')
    if cur.fetchone()[0] == 0:
        for r in rows:
            if r['질문단위_수정안'] != unit:
                continue
            tools, out = expect(r, agent)
            gt = json.dumps({'ground_truth_invocations': [{'tool_name': t} for t in tools], 'ground_truth_output': out},
                            ensure_ascii=False)
            cur.execute(f'INSERT INTO {tbl} SELECT %s, PARSE_JSON(%s), %s, %s', (r['질문'], gt, r['문항ID'], 'tea'))
    cur.execute(f'SELECT COUNT(*), COUNT_IF(ARRAY_SIZE(EXPECTED_OUTPUT:ground_truth_invocations) = 0) FROM {tbl}')
    print(agent, tbl, cur.fetchone())
    try:
        cur.execute(f"CALL SYSTEM$CREATE_EVALUATION_DATASET('Cortex Agent', '{tbl}', '{ds}', "
                    "OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'EXPECTED_OUTPUT'))")
        print(ds, cur.fetchone())
    except Exception as e:  # noqa: BLE001
        print('🔴', ds, str(e)[:300])
