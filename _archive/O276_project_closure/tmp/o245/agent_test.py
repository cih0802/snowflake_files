# O245 — ML 특성 「○」 칸 Agent 응답 테스트(사용자 지시 2026-10-18 · DATA_AGENT_RUN · 🔴 LLM 호출 과금)
# 원문 = tmp/o245/agent_test/<tag>.txt · 요약 = _summary.json · 기대값 = _expected.json (SV 직접 질의)
# 사용: python3 tmp/o245/agent_test.py expected | run
import io, json, os, re, sys, time
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

OUT = '/workspace/tmp/o245/agent_test' + ('_retest' if os.environ.get('RETEST') else '')
A = 'AGENT_MEMBER'
# (tag, 표 칸, 질문, 기대 SV, 기대 차원 토큰, 기대값 SQL 또는 None)
Q = [
    ('M1', '회원중단×법인구분', 'ML 회원 단위 중단 예측 최신 기준월에서 법인구분(사단·사복)별 예측 대상 회원수와 모델 중단분류 회원수를 알려줘',
     'SV_ML_MEMBER_RISK', 'CPR_DIV_NAME',
     "select CPR_DIV_NAME, PREDICTED_MEMBERS, MODEL_CHURN_MEMBERS from SEMANTIC_VIEW(GN_DW.SERVING.SV_ML_MEMBER_RISK DIMENSIONS ma.CPR_DIV_NAME METRICS mr.PREDICTED_MEMBERS, mr.MODEL_CHURN_MEMBERS WHERE mr.STDR_MT = (select max(STDR_MT) from GN_DW.SERVING.ML_MEMBER_RISK_V)) order by 1"),
    ('M2', '회원중단×등록부서', 'ML 중단 예측 최신 기준월 기준으로 등록부서별 중단위험 고위험 회원수 상위 5개 부서',
     'SV_ML_MEMBER_RISK', 'REGIST_DEPT_NAME',
     "select REGIST_DEPT_NAME, count(distinct MBER_NO) n from (select a.REGIST_DEPT_NAME, r.MBER_NO from GN_DW.SERVING.ML_MEMBER_RISK_V r join GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V a on a.STDR_MT=r.STDR_MT and a.MBER_NO=r.MBER_NO where r.CHURN_GRADE='고위험' and r.STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_MEMBER_RISK_V)) group by 1 order by 2 desc limit 5"),
    ('M3', '회원중단×활동약정수', 'ML 회원 중단 예측 최신 기준월에서 활동 약정 수별 예측 대상 회원수와 평균 중단확률을 보여줘',
     'SV_ML_MEMBER_RISK', 'ACTIVE_SPNSR_CNT',
     "select a.ACTIVE_SPNSR_CNT, count(distinct r.MBER_NO) n, round(avg(r.CHURN_PROB)*100,2) p from GN_DW.SERVING.ML_MEMBER_RISK_V r join GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V a on a.STDR_MT=r.STDR_MT and a.MBER_NO=r.MBER_NO where r.STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_MEMBER_RISK_V) group by 1 order by 1 limit 6"),
    ('M4', '회원중단×납입방식(규칙9 정정)', 'ML 회원 중단 예측에서 납입방식별 모델 중단분류 회원수를 알려줘. 최신 기준월로.',
     'SV_ML_MEMBER_RISK', 'PAYMENT_METHOD_NAME',
     "select a.PAYMENT_METHOD_NAME, count(distinct iff(r.CHURN_CLASS='1', r.MBER_NO, null)) n from GN_DW.SERVING.ML_MEMBER_RISK_V r join GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V a on a.STDR_MT=r.STDR_MT and a.MBER_NO=r.MBER_NO where r.STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_MEMBER_RISK_V) group by 1 order by 2 desc limit 5"),
    ('M5', '회원중단×유지기간(규칙9 정정)', 'ML 중단 예측 최신 기준월에서 유지기간대별 평균 중단확률은?',
     'SV_ML_MEMBER_RISK', 'TENURE_BAND',
     "select a.TENURE_BAND, round(avg(r.CHURN_PROB)*100,2) p from GN_DW.SERVING.ML_MEMBER_RISK_V r join GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V a on a.STDR_MT=r.STDR_MT and a.MBER_NO=r.MBER_NO where r.STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_MEMBER_RISK_V) group by 1 order by 1"),
    ('C1', '중단×카테고리 : 후원사업', 'ML 중단 예측 최신 기준월 활동회원을 후원사업별로 나눠서 활동회원수와 중단 고위험 회원수를 보여줘',
     'SV_ML_CHURN_CAMPAIGN', 'SPONSORSHIP_NAME',
     "select SPONSORSHIP_NAME, count(distinct MBER_NO) act, count(distinct iff(MEMBER_CHURN_GRADE='고위험', MBER_NO, null)) high from GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V where STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V) group by 1 order by 2 desc limit 5"),
    ('C2', '중단×카테고리×후원사업', '최신 기준월 고려인캠페인 카테고리 활동회원 중 후원사업별 중단 고위험 회원수',
     'SV_ML_CHURN_CAMPAIGN', 'SPONSORSHIP_NAME',
     "select SPONSORSHIP_NAME, count(distinct MBER_NO) act, count(distinct iff(MEMBER_CHURN_GRADE='고위험', MBER_NO, null)) high from GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V where CMPGN_CTGR_NM='고려인캠페인' and STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_CHURN_BY_SPONSORSHIP_V) group by 1 order by 2 desc limit 5"),
    ('C3', '중단×카테고리×법인구분', '최신 기준월 중단 예측 × 캠페인카테고리에서 법인구분별 중단 고위험 활동회원수',
     'SV_ML_CHURN_CAMPAIGN', 'CPR_DIV_NAME',
     "select a.CPR_DIV_NAME, count(distinct iff(c.MEMBER_CHURN_GRADE='고위험', c.MBER_NO, null)) high from GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V c join GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V a on a.STDR_MT=c.STDR_MT and a.MBER_NO=c.MBER_NO where c.STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V) group by 1 order by 1"),
    ('S1', '후원건이탈×등록부서', 'ML 후원건 단위 이탈 예측 최신 기준월에서 등록부서별 모델 이탈분류 회원수 상위 5개',
     'SV_ML_SPONSOR_RISK', 'REGIST_DEPT_NAME',
     "select a.REGIST_DEPT_NAME, count(distinct iff(s.CHURN_CLASS='1', s.MBER_NO, null)) n from GN_DW.SERVING.ML_SPONSOR_RISK_V s join GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V a on a.STDR_MT=s.STDR_MT and a.MBER_NO=s.MBER_NO where s.STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_SPONSOR_RISK_V) group by 1 order by 2 desc limit 5"),
    ('S2', '후원건이탈×활동약정수', '후원건 이탈 예측 최신 기준월에서 회원의 활동 약정 수별 평균 이탈확률',
     'SV_ML_SPONSOR_RISK', 'ACTIVE_SPNSR_CNT',
     "select a.ACTIVE_SPNSR_CNT, round(avg(s.CHURN_PROB)*100,2) p, count(*) n from GN_DW.SERVING.ML_SPONSOR_RISK_V s join GN_DW.SERVING.ML_MEMBER_ATTR_ASOF_V a on a.STDR_MT=s.STDR_MT and a.MBER_NO=s.MBER_NO where s.STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_SPONSOR_RISK_V) group by 1 order by 1 limit 6"),
    ('O1', '일시전환×후원사업', '일시후원 회원의 정기 전환 예측(최신 기준월)에서 후원사업별 모델 전환분류 회원수와 예측 대상 일시회원수',
     'SV_ML_ONCE_CONVERSION', 'SPONSORSHIP_NAME',
     "select SPONSORSHIP_NAME, count(distinct iff(CONVERT_CLASS='1', ONCE_MBER_NO, null)) conv, count(distinct ONCE_MBER_NO) n from GN_DW.SERVING.ML_ONCE_CONVERSION_V where STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_ONCE_CONVERSION_V) group by 1 order by 3 desc"),
    ('O2', '일시전환×금액대', '일시후원 정기 전환 예측 최신 기준월에서 후원금액대별 평균 전환확률과 예측 대상 일시회원수',
     'SV_ML_ONCE_CONVERSION', 'AMOUNT_BAND',
     "select AMOUNT_BAND, round(avg(CONVERT_PROB)*100,2) p, count(distinct ONCE_MBER_NO) n from GN_DW.SERVING.ML_ONCE_CONVERSION_V where STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_ONCE_CONVERSION_V) group by 1 order by 3 desc limit 5"),
    ('O3', '일시전환×납입방식', '일시회원 정기 전환 예측에서 납입방식별 모델 전환분류 회원수(최신 기준월)',
     'SV_ML_ONCE_CONVERSION', 'PAYMENT_METHOD_NAME',
     "select PAYMENT_METHOD_NAME, count(distinct iff(CONVERT_CLASS='1', ONCE_MBER_NO, null)) conv from GN_DW.SERVING.ML_ONCE_CONVERSION_V where STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_ONCE_CONVERSION_V) group by 1 order by 2 desc"),
    ('O4', '일시전환×법인구분·유지기간', '일시후원 정기 전환 예측 최신 기준월에서 법인구분과 유지기간대별 예측 대상 일시회원수',
     'SV_ML_ONCE_CONVERSION', 'CPR_DIV_NAME',
     "select CPR_DIV_NAME, TENURE_BAND, count(distinct ONCE_MBER_NO) n from GN_DW.SERVING.ML_ONCE_CONVERSION_V where STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_ONCE_CONVERSION_V) group by 1,2 order by 3 desc limit 6"),
    ('N1', '일시전환×연령대(데이터 없음 기대)', '일시후원 정기 전환 예측을 연령대별로 나눠줘', 'SV_ML_ONCE_CONVERSION', '(데이터 없음)', None),
    ('N2', '일시전환×캠페인카테고리(데이터 없음 기대)', '일시후원 정기 전환 예측을 캠페인카테고리별로 보여줘', 'SV_ML_ONCE_CONVERSION', '(데이터 없음)', None),
    ('R1', '회원중단×캠페인카테고리(라우팅)', 'ML 회원 단위 중단 예측을 캠페인카테고리별로 고위험 회원수로 보여줘. 최신 기준월.',
     'SV_ML_CHURN_CAMPAIGN', 'CMPGN_CTGR_NM',
     "select CMPGN_CTGR_NM, count(distinct iff(MEMBER_CHURN_GRADE='고위험', MBER_NO, null)) high from GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V where STDR_MT=(select max(STDR_MT) from GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V) group by 1 order by 2 desc limit 5"),
]


def expected():
    cn = conn(); cur = cn.cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
    out = {}
    for tag, cell, q, sv, tok, sql in Q:
        if not sql:
            continue
        try:
            cur.execute(sql)
            out[tag] = [[str(x) for x in r] for r in cur.fetchall()]
        except Exception as e:
            out[tag] = 'ERROR ' + str(e)[:300]
    cn.close()
    json.dump(out, io.open(OUT + '/_expected.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('expected', len(out))


def texts(raw):
    try:
        j = json.loads(raw)
    except Exception:
        return '', []
    final, sqls = [], []

    def walk(o):
        if isinstance(o, dict):
            if o.get('type') == 'text' and isinstance(o.get('text'), str):
                final.append(o['text'])
            for k, v in o.items():
                if k == 'sql' and isinstance(v, str):
                    sqls.append(v)
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(j)
    return '\n'.join(final), sqls


def run():
    cn = conn(); cur = cn.cursor(); cur.execute('USE ROLE GN_DW_ADMIN'); cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
    rows = []
    for tag, cell, q, sv, tok, sql in [x for x in Q if not os.environ.get('RETEST') or x[0] in os.environ['RETEST'].split(',')]:
        req = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        t0 = time.time()
        try:
            cur.execute('select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.' + A, req))
            raw = cur.fetchall()[0][0]; ok = True
        except Exception as e:
            raw = '__CALL_FAILED__ %s' % e; ok = False
        io.open('%s/%s.txt' % (OUT, tag), 'w', encoding='utf-8').write(str(raw))
        ans, sqls = texts(raw) if ok else ('', [])
        allsql = ' '.join(sqls)
        txt = str(raw)
        r = dict(tag=tag, cell=cell, ok=ok, sec=round(time.time() - t0, 1),
                 sv_hit=sv in txt, tok_hit=(tok in allsql) if tok != '(데이터 없음)' else None,
                 nodata=bool(re.search(r'데이터(가)? 없|원천 값이 없|산출 불가|제공되지 않|없습니다', ans)) if tok == '(데이터 없음)' else None,
                 sql_n=len(sqls), sql_err=bool(re.search(r'invalid identifier|syntax error|SQL compilation error', txt, re.I)),
                 answer=ans[-1500:])
        rows.append(r)
        print(tag, 'ok=%s %.0fs sv=%s tok=%s nodata=%s sqls=%d err=%s' % (ok, r['sec'], r['sv_hit'], r['tok_hit'], r['nodata'], r['sql_n'], r['sql_err']), flush=True)
    cn.close()
    json.dump(rows, io.open(OUT + '/_summary.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    expected() if sys.argv[1] == 'expected' else run()
