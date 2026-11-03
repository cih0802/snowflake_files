# O245 — 법인구분 문안 정정: CM019 = 통합·사단·사복 3종(실측 2026-10-18 · M1 기대값 사단 61,202 · 사복 8,128 · 통합 828)
import io, hashlib, shutil
D = '/workspace/05_SV-Agent_ai/'
FIX = [
    ('사단·사복 · 코드사전 CM019', '통합·사단·사복 · 코드사전 CM019'),
    ('코드사전 CM019 · 사단·사복', '코드사전 CM019 · 통합·사단·사복'),
    ('법인구분(사단·사복)', '법인구분(통합·사단·사복)'),
    ("WITH SYNONYMS ('법인구분', '사단 사복')", "WITH SYNONYMS ('법인구분', '사단 사복 통합')"),
]
for f in ('21_ML_SERVING_뷰_DDL.sql', '22_ML_SV_DDL.sql', '25_ML_CHURN_CMPGN_CTGR_DDL.sql'):
    p = D + f
    assert hashlib.sha256(open(p, 'rb').read()).digest() == hashlib.sha256(open(p, 'rb').read()).digest()
    s = io.open(p, encoding='utf-8', newline='').read()
    shutil.copyfile(p, '/workspace/tmp/o245/%s.before2' % f)
    n = 0
    for a, b in FIX:
        n += s.count(a)
        s = s.replace(a, b)
    left = s.count('사단·사복') - s.count('통합·사단·사복')
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print(f, 'replaced', n, 'bare_left', left)
