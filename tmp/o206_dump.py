# O206 — 스모크 원문 구조 덤프(텍스트 블록·SQL)
# Co-authored with CoCo
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
texts, sqls = [], []
def walk(x, path=''):
    if isinstance(x, dict):
        if x.get('type') == 'text' and isinstance(x.get('text'), str):
            texts.append((path, x['text']))
        for k, v in x.items():
            if isinstance(v, str) and k in ('sql', 'query', 'statement') and 'SELECT' in v.upper():
                sqls.append((path + '/' + k, v))
            walk(v, path + '/' + k)
    elif isinstance(x, list):
        for i, v in enumerate(x):
            walk(v, path + f'[{i}]')
walk(d)
print('TEXT', len(texts), 'SQL', len(sqls))
for p, t in texts:
    print('---', p[:90], len(t)); print(t[:int(sys.argv[2]) if len(sys.argv) > 2 else 600])
for p, s in sqls:
    print('===', p[:90]); print(s[:700])
