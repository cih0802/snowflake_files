# O224 — xh20001 eval 데이터셋 재등록(DS V3 규칙 그대로 · 이름만 O224_*) + 정답 도구 실재 검사
# 규칙 원본 = tmp/o216_eval_ds.py v3(A안) — 판정식(expect)은 import 해 1벌로 공유하지 않고 아래에 동일 사본을 둔다
#   (원본은 모듈 수준에서 DB 에 연결·적재하므로 import 불가) ⇒ 원본과의 차이는 이름(O216→O224)과 dry-run 뿐이다.
# 사용: python3 tmp/o224_eval_ds.py dry      # 문항별 정답 도구 ↔ 라이브 Agent 도구 대조만(쓰기 0)
#       python3 tmp/o224_eval_ds.py apply    # 테이블 생성·적재 + SYSTEM$CREATE_EVALUATION_DATASET
# Co-authored with CoCo
import csv, json, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
SRC = '/workspace/12_agent개선과제/06_O208_문항코퍼스.csv'
SET = {'경영·기획': 'AGENT_EXECUTIVE', '회원': 'AGENT_MEMBER', '마케팅': 'AGENT_MARKETING'}
NOTOOL = {'Q05', 'Q06', 'Q17', 'Q19', 'Q20', 'Q21', 'Q23', 'Q24', 'Q25', 'Q26', 'Q27', 'Q30'}
V3_GUIDE = {'Q03', 'Q04', 'Q05', 'Q06', 'Q07'}
V3_MSTR = {'X1', 'X2'}
V3_DROP = {'AGENT_MEMBER': {'analyst_ga_behavior'}}
MODE = sys.argv[1]
assert MODE in ('dry', 'apply')
rows = list(csv.DictReader(open(SRC, encoding='utf-8')))
cur = conn().cursor()
cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ETL_WH')
cur.execute('USE DATABASE GN_DW'); cur.execute('USE SCHEMA SERVING')


def expect(r, agent):
    qid = r['문항ID']
    tools = [t.strip() for t in r['정답 도구'].split(';') if t.strip()]
    if agent == 'AGENT_EXECUTIVE' and qid in V3_GUIDE:
        s = ('이 Agent 에는 해당 회비 예측·회비 분해 도구가 없다 — 데이터 도구로 수치를 만들지 않고 '
             '「회원 분석 어시스턴트에서 조회 가능합니다」라고 안내한다.')
        if r['계산 전 확인'] == 'Y':
            s += ' 사전 산식이 없는 지표임도 함께 밝힌다.'
        return [], s
    if agent == 'AGENT_EXECUTIVE' and qid in V3_MSTR:
        return (['analyst_mstr_spnsr_dvlp'],
                'MSTR 기준으로 analyst_mstr_spnsr_dvlp 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 「MSTR 기준」 표기 · '
                '개발 실적을 캠페인카테고리·개발인입경로 축으로 물으면 MSTR 도구 · O212-B).')
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


live = {}
for agent in SET.values():
    cur.execute(f'DESCRIBE AGENT GN_DW.SERVING.{agent}')
    cols = [c[0] for c in cur.description]
    spec = json.loads(cur.fetchone()[cols.index('agent_spec')])
    live[agent] = {t['tool_spec']['name'] for t in spec.get('tools', [])}

bad = 0
for unit, agent in SET.items():
    short = agent.split('_')[1]
    picked = [r for r in rows if r['질문단위_수정안'] == unit]
    plan = [(r, *expect(r, agent)) for r in picked]
    miss = [(r['문항ID'], t) for r, tools, _ in plan for t in tools if t not in live[agent]]
    bad += len(miss)
    print(agent, '문항', len(plan), '무도구', sum(1 for _, t, _ in plan if not t), '부재도구', miss)
    if MODE != 'apply':
        continue
    tbl, ds = f'GN_DW.SERVING.EVAL_O224_{agent}_V3', f'O224_{short}_DS_V3'
    cur.execute(f'CREATE TABLE IF NOT EXISTS {tbl} (INPUT_QUERY STRING, EXPECTED_OUTPUT VARIANT, QUESTION_ID STRING, TRACK STRING)')
    cur.execute(f'SELECT COUNT(*) FROM {tbl}')
    if cur.fetchone()[0] == 0:
        for r, tools, out in plan:
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
print('부재도구 합', bad)
if MODE == 'apply' and bad:
    print('🔴 부재도구가 있는 채로 적재했다 — 정답지 결함')
