# O241 ⑥ 2단계 — 미배선 121건 × O237 overlay(SV_FIELD) × SV 카탈로그 실재 대조(일회용)
import csv, io, re, os
os.chdir('/workspace')
rows = list(csv.DictReader(io.open('tmp/o241/unwired_121.csv', encoding='utf-8-sig')))
ov = {}
for r in csv.DictReader(io.open('12_agent개선과제/tools/O237_formula_wiring_overlay.csv', encoding='utf-8-sig')):
    m = re.match(r'MET_(CMN|NEW)-(\d+)$', r['DOC_ID'])
    if m:
        ov[('공' if m.group(1) == 'CMN' else '신') + m.group(2)] = r
cat = {}
for ln in io.open('tmp/o241/sv_field_catalog.tsv', encoding='utf-8'):
    p = ln.rstrip('\n').split('\t')
    cat.setdefault((p[0].upper(), p[2].upper()), p)
out = io.open('tmp/o241/unwired_overlay_join.tsv', 'w', encoding='utf-8')
stat = {'overlay있음': 0, '필드실재': 0, '필드부재': 0, 'overlay없음': 0}
for r in rows:
    k = r['지표#']
    o = ov.get(k)
    if not o:
        stat['overlay없음'] += 1
        out.write(f"{k}\t{r['지표명']}\t-\t-\toverlay없음\n")
        continue
    stat['overlay있음'] += 1
    fields = [f.strip() for f in re.split(r'\s*·\s*', o['SV_FIELD']) if f.strip()]
    res = []
    for f in fields:
        parts = f.split('.')
        if len(parts) >= 3:
            key = (parts[0].upper(), parts[-1].upper())
            ok = key in cat
            stat['필드실재' if ok else '필드부재'] += 1
            res.append(f"{parts[0]}.{parts[-1]}{'' if ok else '❌부재'}")
        else:
            res.append(f + '(형식?)')
    out.write(f"{k}\t{r['지표명']}\t{o['COVERAGE']}\t{o['TOOL_NAME']}\t{' ; '.join(res)}\n")
out.close()
print(stat)
