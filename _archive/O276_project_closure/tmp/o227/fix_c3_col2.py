#!/usr/bin/env python3
"""O227 C3 컬럼 2차 정리 — 1차 scrub 이 남긴 빈 괄호 조각·날짜 판정·내부 절차 참조를 대상 298행에만 정리(파일만 · 기본 dry-run).
사용: python3 tmp/o227/fix_c3_col2.py [--apply]  · 테이블 컬럼 라이브 ALTER 는 fix_c3_col_live.py 가 맡는다.
Co-authored with CoCo"""
import hashlib, io, json, re, sys
import yaml

W = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
G = '/workspace/03_top-down_gold/06_DDL.sql'


def clean(t):
    t = re.sub(r'\(\s*하드블로커\)', '', t)
    t = re.sub(r'\s*·\s*\d{4}-\d{2}-\d{2}\s*판정', '', t)
    t = re.sub(r'\s*·\s*순서9-K 표 분리 근거', '', t)
    t = re.sub(r'\[\s*\d{4}-\d{2}-\d{2}\s*\]\s*', '', t)
    t = re.sub(r'\(\s*·\s*', '(', t)
    t = re.sub(r'\s*·\s*\)', ')', t)
    t = re.sub(r'\(\s+', '(', t)
    t = re.sub(r'\s+\)', ')', t)
    t = re.sub(r'\(\s*\)', '', t)
    t = t.replace('모델 결함 아님 ·.', '모델 결함 아님).')
    t = re.sub(r'\(\d{4}-\d{2}-\d{2} 실측 ·\.', '.', t)
    # 여는 ** 직후 공백만 제거(** 출현 순서가 짝수번째 = 여는 표시)
    parts = t.split('**')
    for n in range(1, len(parts), 2):
        parts[n] = parts[n].lstrip()
    t = '**'.join(parts)
    t = re.sub(r'\s{2,}', ' ', t).replace(' .', '.').replace('..', '.').strip()
    return t


BAD = r'\(\s|\s\)|\(\)|\d{4}-\d{2}-\d{2} 판정|순서9-K|하드블로커\)|·\s*\.'
rows = [l.rstrip('\n').split('\t')[:2] for l in io.open('/workspace/tmp/o227/c3_col.tsv', encoding='utf-8')]
for p in (W, G):
    a, b = (hashlib.sha256(open(p, 'rb').read()).hexdigest() for _ in range(2))
    assert a == b, p
WL = io.open(W, encoding='utf-8').read().split('\n')
GL = io.open(G, encoding='utf-8').read().split('\n')
mstart = {s[len('  - name: '):]: i for i, s in enumerate(WL) if s.startswith('  - name: ')}
mb = sorted(mstart.values()) + [len(WL)]
tstart = {}
for i, s in enumerate(GL):
    m = re.match(r'CREATE OR REPLACE (?:TRANSIENT )?TABLE GN_DW\.GOLD\.(\w+)', s)
    if m:
        tstart[m.group(1)] = i
chg, bad = 0, []
for obj, col in rows:
    if obj.startswith('WIDE_'):
        i0 = mstart[obj]; i1 = next(x for x in mb if x > i0)
        k = next(k for k in range(i0, i1) if WL[k].strip() == '- name: ' + col)
        j = k + 1
        assert WL[j].lstrip().startswith('description: "'), (obj, col, WL[j][:60])
        old = yaml.safe_load(WL[j].strip())['description']
        new = clean(old)
        ind = WL[j][:len(WL[j]) - len(WL[j].lstrip())]
        WL[j] = ind + 'description: ' + json.dumps(new, ensure_ascii=False)
    else:
        i0 = tstart[obj]
        k = next(k for k in range(i0, i0 + 400) if re.match(r'\s+' + col + r'\s', GL[k]))
        m = re.search(r"COMMENT '((?:[^']|'')*)'", GL[k])
        old = m.group(1).replace("''", "'")
        new = clean(old)
        GL[k] = GL[k][:m.start(1)] + new.replace("'", "''") + GL[k][m.end(1):]
    chg += old != new
    if re.search(BAD, new):
        bad.append(f'{obj}.{col}: ' + re.search('.{0,30}(?:' + BAD + ').{0,30}', new).group(0))
print('변경', chg, '· 결함 잔존', len(bad))
for x in bad:
    print('  ', x)
if '--apply' in sys.argv and not bad:
    txt = '\n'.join(WL)
    yaml.safe_load(txt)
    io.open(W, 'w', encoding='utf-8').write(txt)
    io.open(G, 'w', encoding='utf-8').write('\n'.join(GL))
    print('APPLIED')
