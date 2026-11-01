"""4-A 판정 후보: survey.json -> verdict.json (규칙 기반 · 사람이 검토)."""
import json, re, sys
from collections import defaultdict

S = json.load(open(sys.argv[1]))
README = {'00_README.md', 'README.md', 'readme.md', '00_INDEX.md', '00_README_N07.md',
          '00_INDEX.csv', '00_INDEX_산출물목록.md'}
TEMP = re.compile(r'(^untitled|temp|^tmp|^_o\d|^_|scratch|probe|test_?run|\.out$|\.log$)', re.I)
OLD = re.compile(r'(_bak|backup|_old|구버전|\.O\d+|before|pre-|_v\d+\b(?!.*final))', re.I)
REF = re.compile(r'(부록|이력|참고|reference|sample|예시|근거|evidence|measure|census)', re.I)

# 전역 해시 → 위치
glob_sha = defaultdict(list)
for t, v in S.items():
    for f in v.get('files', []):
        glob_sha[f['sha']].append(f'{t}/{f["name"]}')

res = {}
for t, v in S.items():
    fs = v.get('files', [])
    by_sha, by_norm = defaultdict(list), defaultdict(list)
    for f in fs:
        by_sha[f['sha']].append(f)
        by_norm[f['norm']].append(f)
    rows = []
    for f in fs:
        n = f['name']
        if n in README:
            st, why = '안내', 'README/INDEX'
        elif len(by_sha[f['sha']]) > 1 and by_sha[f['sha']][0] is not f:
            st, why = '중복', f'내용 동일: {by_sha[f["sha"]][0]["name"]}'
        elif len(glob_sha[f['sha']]) > 1 and glob_sha[f['sha']][0] != f'{t}/{n}':
            st, why = '중복', f'내용 동일(타 폴더): {glob_sha[f["sha"]][0]}'
        elif TEMP.search(n):
            st, why = '임시', '이름 패턴(임시/측정/프로브)'
        elif OLD.search(n):
            m = re.search(r'^(.*)_v(\d+)(\.\w+)$', n)
            fam = [x for x in fs if m and re.match(re.escape(m.group(1)) + r'_v\d+', x['name'])]
            top = max(fam, key=lambda x: int(re.search(r'_v(\d+)', x['name']).group(1))) if fam else None
            if top is f:
                st, why = '정본', f'_vN 계열 최신 ({len(fam)}판)'
            else:
                st, why = '구버전', f'이전판: {top["name"]}' if top else '이름 패턴(백업/이전판)'
        elif len(by_norm[f['norm']]) > 1 and f['norm'] and \
                len({x['name'].rsplit('.', 1)[0] for x in by_norm[f['norm']]}) == 1:
            st, why = '정본', '형식 변형(md/csv/xlsx 병행)'
        elif len(by_norm[f['norm']]) > 1 and f['norm']:
            sib = [x for x in by_norm[f['norm']] if x is not f]
            newest = max(by_norm[f['norm']], key=lambda x: (x['name'][:2].isdigit(), x['size']))
            if newest is f:
                st, why = '정본', f'동명 계열 대표 (형제 {len(sib)})'
            else:
                st, why = '구버전', f'동명 계열: {newest["name"]}'
        elif REF.search(n):
            st, why = '참고', '이름 패턴(부록/이력/근거)'
        else:
            st, why = '정본', '-'
        h = next((x for x in f.get('head', []) if x.strip() and not x.startswith(('---', '<!--'))), '')
        rows.append({'name': n, 'size': f['size'], 'status': st, 'why': why, 'head': h})
    res[t] = {'rows': rows, 'subdirs': v.get('subdirs', [])}

json.dump(res, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
cnt = defaultdict(int)
for t in res:
    for r in res[t]['rows']:
        cnt[r['status']] += 1
print(dict(cnt))
for t in res:
    for r in res[t]['rows']:
        if r['status'] in ('중복', '구버전'):
            print(f'{r["status"]}\t{t}/{r["name"]}\t{r["why"]}')
