import io
OLD = 'ma 차원으로 답한다(기준월 말 시점 · 모델 피처 아님)'
NEW = 'ma 차원으로 답한다(성별·연령대·지역·회원상태·회원구분 = 기준월 말 시점 · 금액대·유지기간·신규기존·납입방식 = 기준월 행 없으면 직전 실적 월 값 · 각주에 「기준월(없으면 직전 실적 월) 기준」으로 밝힌다 · 모델 피처 아님)'
src = io.open('/workspace/05_SV-Agent_ai/34_DEPLOY_SV_ML_FALLBACK_NOTE.sql', encoding='utf-8').read()
assert src.count(NEW) >= 1, src.count(NEW)
for f, want in (('22_ML_SV_DDL.sql', 1),):
    p = '/workspace/05_SV-Agent_ai/' + f
    s = io.open(p, encoding='utf-8').read()
    assert s.count(OLD) == want, (f, s.count(OLD))
    io.open(p, 'w', encoding='utf-8').write(s.replace(OLD, NEW))
    print(f, want)
