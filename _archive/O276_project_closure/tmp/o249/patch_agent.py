import io, hashlib
p = '/workspace/cortex_project/agents/AGENT_MARKETING/agent_spec.yaml'
a = io.open(p, encoding='utf-8').read()
b = io.open(p, encoding='utf-8').read()
assert hashlib.sha256(a.encode()).digest() == hashlib.sha256(b.encode()).digest()
old = 'SURV_LTV_CAP_MONTHS 로 그룹 · 상한 80개월 값과 무기한(9999 = 관측 최대) 값을 나란히'
new = ('SURV_LTV_CAP_AVG_ACTIVE_MONTHS 로 그룹 · 상한(🆕 O249 = 관측 중 회원 평균 유지개월 올림 · 그 N개월을 밝힌다) 값과 '
       '무기한(9999 = 관측 최대) 값을 나란히')
assert a.count(old) == 1, a.count(old)
t = a.replace(old, new)
assert 'LTV_CAP_MONTHS' not in t.replace('LTV_CAP_AVG_ACTIVE_MONTHS', '')
io.open(p, 'w', encoding='utf-8').write(t)
print('ok', len(a), len(t))
