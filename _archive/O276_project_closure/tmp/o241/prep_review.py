# O241 ⑥ 수동 대조 자료 생성(일회용) — 미배선 121건 × SV 필드 카탈로그
import csv, io, re, os, sys
os.chdir('/workspace')
sys.path.insert(0, 'scripts')
import gen_metric_gold_mapping as G

cls = G.load_classification()
dic = {}
dic.update(G.load_dictionary(G.DOC_COMM, '공'))
dic.update(G.load_dictionary(G.DOC_NEW, '신'))
rows = list(csv.DictReader(io.open('tmp/o241/unwired_121.csv', encoding='utf-8-sig')))

cat = []
ITEM = re.compile(r'^ {4}(\w+)\.(\w+)\s+AS\s')
for fn in sorted(os.listdir('05_SV-Agent_ai')):
    if not re.match(r'05_\d+_SV_DDL_.+\.sql$', fn):
        continue
    lines = open('05_SV-Agent_ai/' + fn, encoding='utf-8').read().splitlines()
    sv = ''
    sec = ''
    cur = None
    for ln in lines + ['  END']:
        m0 = re.search(r'SEMANTIC VIEW [\w.]*?(SV_\w+)', ln)
        if m0 and not sv:
            sv = m0.group(1)
        if ln.strip().startswith('--'):
            continue
        im = ITEM.match(ln)
        if im or re.match(r'^ {0,2}\S', ln):
            if cur:
                body = ' '.join(cur[1])
                s = re.search(r'WITH SYNONYMS \(([^)]*)\)', body)
                syn = re.findall(r"'([^']*)'", s.group(1)) if s else []
                c = re.search(r"COMMENT = '(.{0,100})", body)
                cat.append((sv, sec, cur[0], syn, c.group(1) if c else '', fn))
                cur = None
            m1 = re.match(r'^ {2}(DIMENSIONS|METRICS|FACTS)\b', ln)
            if m1:
                sec = m1.group(1)[0]
            if im:
                cur = (im.group(2), [ln])
        elif cur:
            cur[1].append(ln)

with io.open('tmp/o241/sv_field_catalog.tsv', 'w', encoding='utf-8') as w:
    for c in cat:
        w.write('\t'.join([c[0], c[1], c[2], '|'.join(c[3]), c[4].replace('\t', ' '), c[5]]) + '\n')


def n(s):
    return re.sub(r'[\s()\[\]/·,%*=~:\-—]', '', (s or '').lower()).replace('률', '율')


with io.open('tmp/o241/unwired_review.md', 'w', encoding='utf-8') as o:
    for r in rows:
        k = r['지표#']
        c = cls.get(k, {})
        d = dic.get(k, {})
        nm = n(r['지표명'])
        cands = []
        for sv, sec, f, syn, cm, fn in cat:
            sc = 0
            for s in syn:
                ns = n(s)
                if ns == nm:
                    sc = max(sc, 3)
                elif len(nm) >= 2 and len(ns) >= 2 and (nm in ns or ns in nm):
                    sc = max(sc, 1)
            if sc:
                cands.append((sc, f'{sv}.{f}({sec})'))
        cands = sorted(cands, reverse=True)[:10]
        o.write(f"{k}|{r['지표명']}|{c.get('type')}|{c.get('src')}|배속={c.get('place_raw', '')[:50]}\n")
        o.write(f"  정의={d.get('def', '')[:120]}\n  식={d.get('formula', '')[:120]}\n")
        o.write('  후보: ' + ' ; '.join(f'{s}:{x}' for s, x in cands) + '\n')
print(len(cat), 'fields', len(rows), 'rows')
