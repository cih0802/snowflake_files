# O246-D ⑤ — SV_ML 3종 ma 폴백 각주 COMMENT 보강(구조 변경 없음 · 백업 = tmp/o246/<SV>.ddl.beforeD.sql)
import re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
FB = (' 🆕 [O246-D] 기준월 당월 행이 없으면 직전 12개월 내 최근 실적 월 값을 쓴다(폴백) — '
      '답변에 「기준월 말 시점」이라 쓰지 말고 「기준월(없으면 직전 실적 월) 기준」으로 쓴다.')
DIMS = ['AMOUNT_BAND', 'TENURE_BAND', 'NEW_EXISTING', 'PAYMENT_METHOD_NAME']
OLD_TBL = "comment='예측 대상 회원의 기준월 말 시점 특성(성별·연령대·지역·회원상태·회원구분·후원금액대·유지기간대·신규기존·납입방식)."
NEW_TBL = ("comment='예측 대상 회원의 기준월 시점 특성(성별·연령대·지역·회원상태·회원구분 = 기준월 말 · "
           "후원금액대·유지기간대·신규기존·납입방식 = 기준월 행 없으면 직전 12개월 내 최근 실적 월 폴백).")
OLD_CI = '(기준월 말 시점 · 모델 피처 아님)'
NEW_CI = ('(성별·연령대·지역·회원상태·회원구분 = 기준월 말 시점 · 금액대·유지기간·신규기존·납입방식 = 기준월 행 없으면 '
          '직전 실적 월 값 · 각주에 「기준월(없으면 직전 실적 월) 기준」으로 밝힌다 · 모델 피처 아님)')
c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN')
for v in ['SV_ML_MEMBER_RISK', 'SV_ML_CHURN_CAMPAIGN', 'SV_ML_SPONSOR_RISK']:
    d = open('/workspace/tmp/o246/%s.ddl.beforeD.sql' % v, encoding='utf-8').read()
    for k in DIMS:
        rx = re.compile(r"(MA\.%s as ma\.%s with synonyms=\([^)]*\) comment=')((?:[^']|'')*)(')" % (k, k))
        hits = rx.findall(d)
        assert len(hits) == 1, (v, k, len(hits))
        d = rx.sub(lambda m: m.group(1) + m.group(2) + FB + m.group(3), d)
    assert d.count(OLD_TBL) == 1, (v, 'tbl')
    d = d.replace(OLD_TBL, NEW_TBL)
    n = d.count(OLD_CI)
    assert n >= 1, (v, 'ci')
    d = d.replace(OLD_CI, NEW_CI)
    d = re.sub(r'^create or replace semantic view [A-Z_]+', 'create or replace semantic view GN_DW.SERVING.' + v, d, count=1, flags=re.I)
    open('/workspace/tmp/o246d/%s.ddl.sql' % v, 'w', encoding='utf-8').write(d)
    c.execute(d)
    c.execute("SELECT GET_DDL('SEMANTIC_VIEW','GN_DW.SERVING.%s')" % v)
    a = c.fetchone()[0]
    print(v, 'OK', 'O246-D', a.count('[O246-D]'), 'ci', a.count('직전 실적 월 값 · 각주'), 'old_ci', a.count(OLD_CI), 'len', len(a))
