import io, hashlib
p = '/workspace/05_SV-Agent_ai/05_03_SV_DDL_MEMBER_COHORT.sql'
raw = io.open(p, encoding='utf-8').read()
h1 = hashlib.sha256(raw.encode()).hexdigest()
assert h1 == hashlib.sha256(io.open(p, encoding='utf-8').read().encode()).hexdigest()
R = [
    ('surv.SURV_LTV_CAP_MONTHS AS surv.LTV_CAP_MONTHS', 'surv.SURV_LTV_CAP_AVG_ACTIVE_MONTHS AS surv.LTV_CAP_AVG_ACTIVE_MONTHS', 1),
    ('surv.LTV_CAP_MONTHS IS NOT NULL', 'surv.LTV_CAP_AVG_ACTIVE_MONTHS IS NOT NULL', 2),
    ('SURV_LTV_CAP_MONTHS', 'SURV_LTV_CAP_AVG_ACTIVE_MONTHS', None),
    ('값 = 80(상한 80개월 · 마지막 경과월 N−1 에 표지)',
     '값 = 상한 N(🆕 O249 계산형 = CEIL(관측 중 회원 평균 유지개월) · 2026-10-20 = 80 · 마지막 경과월 N−1 에 표지)', 1),
    ('확정 조건 = 상한 80개월 + 무기한',
     '확정 조건 = 상한(🆕 O249 = 관측 중 회원 평균 유지개월 올림 · 현재 80) + 무기한', 1),
    ('답할 때 상한 80개월 값과 무기한',
     '답할 때 상한(관측 중 회원 평균 유지개월 기준 · 그 값 N개월을 밝힌다) 값과 무기한', 1),
]
t = raw
for a, b, n in R:
    c = t.count(a)
    if n is not None:
        assert c == n, (a, c)
    t = t.replace(a, b)
assert 'LTV_CAP_MONTHS' not in t.replace('LTV_CAP_AVG_ACTIVE_MONTHS', '')
io.open(p, 'w', encoding='utf-8').write(t)
print('ok', h1[:12], hashlib.sha256(t.encode()).hexdigest()[:12])
