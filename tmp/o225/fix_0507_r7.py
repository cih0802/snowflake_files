import io
p = '/workspace/05_SV-Agent_ai/05_07_SV_DDL_AD.sql'
s = io.open(p, encoding='utf-8').read()
pairs = [
    ("값이 갈리면(광고비 약 4.3%) 매핑 행수 최다 값을", "값이 갈리면(소수 · 실측은 이슈원장 §O225) 매핑 행수 최다 값을"),
    ("갈리는 비중이 커서(광고비 기준 97.2%·95.7%·72.0%) 대표값이 왜곡된다.", "갈리는 비중이 커서(실측은 이슈원장 §O225) 대표값이 왜곡된다."),
]
for a, b in pairs:
    n = s.count(a)
    assert n == 1, (a, n)
    s = s.replace(a, b)
io.open(p, 'w', encoding='utf-8').write(s)
print('ok')
