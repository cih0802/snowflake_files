import io
p = '/workspace/05_SV-Agent_ai/22_ML_SV_DDL.sql'
a = io.open(p, encoding='utf-8').read()
assert a == io.open(p, encoding='utf-8').read()
R = [
    ("WITH SYNONYMS ('후원사업별 개발 예측', '마케팅캠페인명별 개발 예측', '공통브랜드별 개발 예측', '채널별 개발 예측', '개발 예측 배분')",
     "WITH SYNONYMS ('후원사업별 개발 예측', '마케팅캠페인명별 개발 예측', '공통브랜드별 개발 예측', '채널별 개발 예측', '개발 예측 배분', '개발구분별 개발 예측', '신규 개발 예측', '증액 개발 예측', '재후원 개발 예측')"),
    ("COMMENT = '[배분] 후원사업 / 마케팅캠페인명 / 공통브랜드 / 마케팅채널. 🔴 반드시 1개 값으로 필터한다.'",
     "COMMENT = '[배분] 후원사업 / 마케팅캠페인명 / 공통브랜드 / 마케팅채널 / 🆕 [O249] 개발구분(값 = 신규·증액·재후원). 🔴 반드시 1개 값으로 필터한다.'"),
    ("WITH SYNONYMS ('배분 대상', '후원사업', '마케팅캠페인명', '공통브랜드', '마케팅채널') COMMENT = '[배분] 축 값.",
     "WITH SYNONYMS ('배분 대상', '후원사업', '마케팅캠페인명', '공통브랜드', '마케팅채널', '개발구분') COMMENT = '[배분] 축 값."),
    ("「후원사업별·마케팅캠페인명별·공통브랜드별·마케팅채널별 개발 예측」은 fa 표(배분 추정)만 쓴다",
     "「후원사업별·마케팅캠페인명별·공통브랜드별·마케팅채널별 개발 예측」과 🆕 [O249] 「신규·증액·재후원(개발구분)별 개발 예측」은 fa 표(배분 추정 · ALLOC_AXIS = ''개발구분'')만 쓴다 — 개발구분 「신규」(신규 후원 개발)는 회원 신규/기존 구분과 다른 축이다"),
    ('SQL \'SELECT TS AS "예측월", FORECAST_AMT AS "개발금액 예측(원)"',
     'SQL \'SELECT TS AS "예측월", FORECAST_AMT AS "개발금액 예측(만원)"'),
]
t = a
for x, y in R:
    assert t.count(x) == 1, (x[:40], t.count(x))
    t = t.replace(x, y)
io.open(p, 'w', encoding='utf-8').write(t)
L = t.split('\n')
s = next(i for i, l in enumerate(L) if l.startswith('CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST'))
e = next(i for i, l in enumerate(L) if i > s and l.startswith('GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_ML_DVLP_FORECAST TO ROLE GN_DW_SERVICE'))
io.open('/workspace/tmp/o249/sv_dvlp.sql', 'w', encoding='utf-8').write('USE ROLE GN_DW_ADMIN;\nUSE SCHEMA GN_DW.SERVING;\n' + '\n'.join(L[s:e + 1]) + '\n')
print('ok', s + 1, e + 1)
