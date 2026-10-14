# O224 P0-4 — eval 정답지 V4 = V3(EVAL_O224_*_V3) + 근거 결정이 있는 문항만 덮어쓰기
# 원칙: 정답지를 바꾸면 점수가 오른다 ⇒ 덮어쓰기마다 근거(사용자 결정·라이브 변경)를 REASON 에 적는다 · 그 밖의 문항은 V3 그대로
# 사용: python3 tmp/o224_eval_ds_v4.py dry | apply
# Co-authored with CoCo
import json, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

MODE = sys.argv[1]
assert MODE in ('dry', 'apply')
# (agent, qid) → (도구 목록, 기대 행동 문장, 근거)
OVR = {
    ('AGENT_EXECUTIVE', 'Q13'): (
        ['analyst_mstr_spnsr_dvlp'],
        'MSTR 기준으로 analyst_mstr_spnsr_dvlp 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 「MSTR 기준」 표기). '
        '월 개발 건수 예측 모델은 발행되지 않았으므로 직전 마감월 평균 등 「추세 참고치(모델 예측 아님)」로 답하고 그 산식을 밝힌다. '
        'ML 예측은 금액 단위만 있다는 한계를 밝힌다.',
        'O203 T3 · O207-B 사용자 결정 = 발행된 예측이 없으면 추세 참고치로 답한다(V3 의 「계산 전 확인」 요구와 충돌)'),
    ('AGENT_EXECUTIVE', 'Q15'): (
        ['analyst_ml_dvlp_forecast'],
        'GN_DW 기준으로 analyst_ml_dvlp_forecast 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기). '
        '캠페인이 지정되지 않았으므로 대상 캠페인을 되묻는다 — 예측 상위 캠페인 표를 먼저 보여 주고 되묻는 것도 정답이다.',
        'O211-B ② 사용자 결정 = 두 경로 제시 + 대상 되묻기 = ⭕(정답지 문안을 결정에 맞춘다)'),
    ('AGENT_EXECUTIVE', 'Q18'): (
        ['analyst_ml_feature_importance'],
        'GN_DW 기준으로 analyst_ml_feature_importance 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기). '
        '모델 상대 중요도 상위 요인을 제시하고, 중요도는 인과 효과가 아니며 「20% 증가」를 보장하는 산식이 없다는 한계를 밝힌다.',
        'V3 비고 「요인분석 = 3종 공통」(= 3개 Agent 공통 도구)을 판정 모델이 「분석유형 3종」으로 오독 · 의미 무변경 문안 교정'),
    ('AGENT_MARKETING', 'Q17'): (
        [],
        '광고비 변동 시뮬레이션은 머신러닝 실시간 시뮬레이터(analyst_ml_realtime_simulator)로 추정할 수 있다고 밝히되, '
        '바로 계산하지 않고 쓸 가정(기준월·대상 캠페인·변동률)을 1~3줄로 제시한 뒤 계산할지 묻는다. 추정치는 고정값이 아님을 밝힌다.',
        'O220 실시간 ML 시뮬레이터 신설 + 2단계 가드레일 ⇒ V3 「탄력성 모델 없음」은 거짓이 됐다'),
    ('AGENT_MARKETING', 'Q22'): (
        [],
        '「A캠페인」이 특정되지 않았으므로 데이터 도구로 수치를 만들지 않고 대상 캠페인(캠페인명·공통브랜드·캠페인카테고리 등)을 되묻는다. '
        '신규 가입 가능성 예측 모델은 없다는 점과 가능한 대안(과거 신규 개발 실적 기반 세그먼트)을 안내한다.',
        'V3 비고 「캠페인 미지정 → 되묻기」와 정답 도구 2종이 서로 모순 ⇒ 되묻기를 정답으로 정렬'),
    ('AGENT_MARKETING', 'Q33'): (
        ['analyst_ga_session'],
        'GN_DW 기준으로 analyst_ga_session 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기). '
        '「신규 사용자(first_visit)」 지표는 원천에 없다고 밝히고 유입 채널별 세션·식별 방문 분포를 대안으로 제시한다.',
        'O213 Y3-F SV_GA_SESSION(세션 grain · 유입 9축) 신설 ⇒ 채널 질문의 정본 도구'),
}

c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
c.execute('USE DATABASE GN_DW'); c.execute('USE SCHEMA SERVING')
live = {}
for agent in ('AGENT_EXECUTIVE', 'AGENT_MEMBER', 'AGENT_MARKETING'):
    c.execute(f'DESCRIBE AGENT GN_DW.SERVING.{agent}')
    cols = [d[0] for d in c.description]
    live[agent] = {t['tool_spec']['name'] for t in json.loads(c.fetchone()[cols.index('agent_spec')])['tools']}
hit = 0
for agent in ('AGENT_EXECUTIVE', 'AGENT_MEMBER', 'AGENT_MARKETING'):
    short = agent.split('_')[1]
    c.execute(f'SELECT INPUT_QUERY, EXPECTED_OUTPUT::string, QUESTION_ID, TRACK FROM GN_DW.SERVING.EVAL_O224_{agent}_V3 ORDER BY QUESTION_ID')
    rows = c.fetchall()
    new = []
    for q, exp, qid, tr in rows:
        if (agent, qid) in OVR:
            tools, out, why = OVR[(agent, qid)]
            miss = [t for t in tools if t not in live[agent]]
            assert not miss, (agent, qid, miss)
            exp = json.dumps({'ground_truth_invocations': [{'tool_name': t} for t in tools], 'ground_truth_output': out},
                             ensure_ascii=False)
            hit += 1
            print('OVR', agent, qid, tools, '|', why)
        new.append((q, exp, qid, tr))
    print(agent, 'rows', len(new))
    if MODE != 'apply':
        continue
    tbl, ds = f'GN_DW.SERVING.EVAL_O224_{agent}_V4', f'O224_{short}_DS_V4'
    c.execute(f'CREATE TABLE IF NOT EXISTS {tbl} (INPUT_QUERY STRING, EXPECTED_OUTPUT VARIANT, QUESTION_ID STRING, TRACK STRING)')
    c.execute(f'SELECT COUNT(*) FROM {tbl}')
    if c.fetchone()[0] == 0:
        for r in new:
            c.execute(f'INSERT INTO {tbl} SELECT %s, PARSE_JSON(%s), %s, %s', r)
    c.execute(f'SELECT COUNT(*) FROM {tbl}')
    print(agent, tbl, c.fetchone())
    try:
        c.execute(f"CALL SYSTEM$CREATE_EVALUATION_DATASET('Cortex Agent', '{tbl}', '{ds}', "
                  "OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'EXPECTED_OUTPUT'))")
        print(ds, str(c.fetchone())[:160])
    except Exception as e:  # noqa: BLE001
        print('🔴', ds, str(e)[:300])
assert hit == len(OVR), ('덮어쓰기 누락', hit, len(OVR))
print('덮어쓰기', hit, '/', len(OVR))
