import io
p = '/workspace/문서실행순서.md'
s = io.open(p, encoding='utf-8').read()
R = [
    ('35. 🆕 [O259] SV 소계 행 제거 — /05_SV-Agent_ai/05_01~05_26 각 전체 →',
     '35. 🆕 [O259] SV 소계 행 제거 — /05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql ~ 05_26_SV_DDL_GA_CHILD_UNPAID.sql 각 전체 →'),
    ('보강 — /05_SV-Agent_ai/05_01~05_30 각 전체 →',
     '보강 — /05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql ~ 05_30_SV_DDL_ML_FEE_FORECAST_AXIS.sql 각 전체 →'),
]
for a, b in R:
    assert s.count(a) == 1, a
    s = s.replace(a, b)
io.open(p, 'w', encoding='utf-8').write(s)
print('ok')
