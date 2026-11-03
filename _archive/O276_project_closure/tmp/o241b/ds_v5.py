# O241 — eval 정답지 V5 = V4 + MARKETING Q25 개정(사용자 결정 2026-10-18: O224-B 대리지표+한계 명시가 정답)
# Co-authored with CoCo
import json, sys
sys.path.insert(0, sys.path[0] + '/../../scripts')
from sfconn import conn
EXP = {'ground_truth_invocations': [{'tool_name': 'analyst_ga_behavior'}],
       'ground_truth_output': 'GN_DW 기준으로 analyst_ga_behavior 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기). '
       'GA4 에 「페이지별 이탈 위험」 지표는 없다고 첫 줄에 밝히고, 가장 가까운 대리 지표(페이지별 참여율 등 · 낮을수록 위험)로 '
       '상위 페이지를 제시하며 대리 지표의 산식·조건(기간·최소 페이지뷰)과 한계를 밝힌다. 개인 단위 이탈 예측 모델은 없다.'}
c = conn().cursor()
for s in ('USE ROLE GN_DW_ADMIN', 'USE WAREHOUSE GN_DW_ETL_WH', 'USE SCHEMA GN_DW.SERVING'):
    c.execute(s)
for ag in ('EXECUTIVE', 'MEMBER', 'MARKETING'):
    t = f'GN_DW.SERVING.EVAL_O224_AGENT_{ag}_V5'
    c.execute(f'CREATE OR REPLACE TABLE {t} AS SELECT * FROM GN_DW.SERVING.EVAL_O224_AGENT_{ag}_V4')
    if ag == 'MARKETING':
        c.execute(f"UPDATE {t} SET EXPECTED_OUTPUT = PARSE_JSON(%s) WHERE QUESTION_ID = 'Q25'", (json.dumps(EXP, ensure_ascii=False),))
        assert c.rowcount == 1, c.rowcount
    c.execute(f'SELECT COUNT(*) FROM {t}'); print(t, c.fetchone())
    c.execute(f"CALL SYSTEM$CREATE_EVALUATION_DATASET('Cortex Agent', '{t}', 'O224_{ag}_DS_V5', "
              "OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'EXPECTED_OUTPUT'))")
    print('DS', ag, str(c.fetchone())[:160])
