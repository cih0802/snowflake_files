import io
OLD = "COMMENT = '예측 대상 회원의 기준월 말 시점 특성(성별·연령대·지역·회원상태·회원구분·후원금액대·유지기간대·신규기존·납입방식). grain = 기준월 × 회원."
NEW = "COMMENT = '예측 대상 회원의 기준월 시점 특성(성별·연령대·지역·회원상태·회원구분 = 기준월 말 · 후원금액대·유지기간대·신규기존·납입방식 = 기준월 행 없으면 직전 12개월 내 최근 실적 월 폴백). grain = 기준월 × 회원."
for f, want in (('22_ML_SV_DDL.sql', 2), ('25_ML_CHURN_CMPGN_CTGR_DDL.sql', 1)):
    p = '/workspace/05_SV-Agent_ai/' + f
    s = io.open(p, encoding='utf-8').read()
    assert s.count(OLD) == want, (f, s.count(OLD))
    io.open(p, 'w', encoding='utf-8').write(s.replace(OLD, NEW))
    print(f, want)
