# O242 — eval 정답지 V6 = V5 + MEMBER Q01 개정(사용자 결정 2026-10-18: analyst_ml_churn_campaign(+ma 축) 허용)
# native eval 기대 도구 목록은 OR 를 표현하지 못한다(목록 = 전부 필수) ⇒ 질문을 한 도구로 답하는 churn_campaign 을 기대 도구로 두고
# 기존 경로(cohort + sponsor_risk)는 정답 서술에서 허용으로 밝힌다.
# Co-authored with CoCo
import json, sys
sys.path.insert(0, sys.path[0] + '/../../scripts')
from sfconn import conn
EXP = {'ground_truth_invocations': [{'tool_name': 'analyst_ml_churn_campaign'}],
       'ground_truth_output': 'GN_DW 기준으로 analyst_ml_churn_campaign 도구 결과에 근거해 한국어로 답한다(표 헤더 한글 · 기준 표기). '
       '캠페인카테고리별 12개월 중단 예측(높은·낮은 캠페인 비교)과 캠페인별 회원 특성(기준월 말 시점 · 성별·연령대·회원구분·후원금액대 등)을 제시한다. '
       '유의: 실적(12개월 중단률)과 ML 중단 예측은 표를 분리한다. analyst_member_cohort · analyst_ml_sponsor_risk 로 나눠 답해도 정답이다.'}
c = conn().cursor()
for s in ('USE ROLE GN_DW_ADMIN', 'USE WAREHOUSE GN_DW_ETL_WH', 'USE SCHEMA GN_DW.SERVING'):
    c.execute(s)
for ag in ('EXECUTIVE', 'MEMBER', 'MARKETING'):
    t = f'GN_DW.SERVING.EVAL_O224_AGENT_{ag}_V6'
    c.execute(f'CREATE OR REPLACE TABLE {t} AS SELECT * FROM GN_DW.SERVING.EVAL_O224_AGENT_{ag}_V5')
    if ag == 'MEMBER':
        c.execute(f"UPDATE {t} SET EXPECTED_OUTPUT = PARSE_JSON(%s) WHERE QUESTION_ID = 'Q01'", (json.dumps(EXP, ensure_ascii=False),))
        assert c.rowcount == 1, c.rowcount
    c.execute(f'SELECT COUNT(*) FROM {t}'); print(t, c.fetchone())
    c.execute(f"CALL SYSTEM$CREATE_EVALUATION_DATASET('Cortex Agent', '{t}', 'O224_{ag}_DS_V6', "
              "OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'EXPECTED_OUTPUT'))")
    print('DS', ag, str(c.fetchone())[:160])
