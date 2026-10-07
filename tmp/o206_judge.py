# O206 — 저장된 스모크 원문 재판정: table 블록 헤더(rowType.name) · chart 필드/제목 · text 마크다운 표 헤더
# 사용: python3 tmp/o206_judge.py [디렉터리]
# Co-authored with CoCo
import glob, json, os, re, sys

D = sys.argv[1] if len(sys.argv) > 1 else '/workspace/tmp/o206_smoke'
HANGUL = re.compile(r'[가-힣]')
ENG_ID = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')


def bad(name):
    return name is not None and not HANGUL.search(str(name)) and ENG_ID.match(str(name)) is not None


tot = {'PASS': 0, 'FAIL': 0, 'NO_TABLE': 0}
for p in sorted(glob.glob(f'{D}/*.json')):
    d = json.load(open(p, encoding='utf-8'))
    if 'content' not in d:
        print(os.path.basename(p), 'ERROR', str(d)[:200]); continue
    heads, bads = [], []
    for c in d['content']:
        if c.get('type') == 'table':
            names = [r['name'] for r in c['table']['result_set']['resultSetMetaData']['rowType']]
            heads.append(names); bads += [n for n in names if bad(n)]
        elif c.get('type') == 'chart':
            spec = json.loads(c['chart']['chart_spec'])
            s = json.dumps(spec, ensure_ascii=False)
            for f in re.findall(r'"(?:field|title)"\s*:\s*"([^"]+)"', s):
                if f not in ('key', 'value') and bad(f):
                    bads.append('chart:' + f)
        elif c.get('type') == 'text':
            L = c['text'].splitlines()
            for i, l in enumerate(L[1:], 1):
                if re.match(r'^\s*\|[\s\-:|]+\|\s*$', l):
                    cells = [x.strip().strip('*') for x in L[i - 1].strip().strip('|').split('|')]
                    heads.append(cells); bads += ['md:' + x for x in cells if bad(x)]
    v = 'NO_TABLE' if not heads else ('FAIL' if bads else 'PASS')
    tot[v] += 1
    print(f'{os.path.basename(p):8} {v:8} 표={len(heads)} 영문헤더={sorted(set(bads))}')
    for h in heads[:2]:
        print('         ', h)
print(tot)
