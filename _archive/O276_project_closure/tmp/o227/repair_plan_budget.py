#!/usr/bin/env python3
"""O227 fix_c3_col.py 사고 복구 — WIDE_BUDGET.PLAN_BUDGET_MONTH 가 블록 스칼라(`>-`)였는데 머리줄만 덮어써
`description: ""` + 본문 잔존으로 YAML 이 깨졌다. 원 헤더(`>-` · _archive O174 사본 확인)로 접어 원문을 복원 → scrub → 1줄화.
Co-authored with CoCo"""
import hashlib, importlib.util, io, json, sys
import yaml

W = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
a, b = (hashlib.sha256(open(W, 'rb').read()).hexdigest() for _ in range(2))
assert a == b
L = io.open(W, encoding='utf-8').read().split('\n')
j = [i for i, s in enumerate(L) if s.strip() == 'description: ""']
assert len(j) == 1 and L[j[0] - 1].strip() == '- name: PLAN_BUDGET_MONTH', j
j = j[0]
ind = L[j][:len(L[j]) - len(L[j].lstrip())]
k = j + 1
while k < len(L) and (L[k].startswith(ind + '  ') or L[k].strip() == ''):
    k += 1
block = '\n'.join([ind + 'description: >-'] + L[j + 1:k])
old = yaml.safe_load(block)['description']
print('복원 원문', len(old), '자 |', old[:80])
src = io.open('/workspace/tmp/o227/fix_c3_col.py', encoding='utf-8').read()
ns = {}
exec(src.split("\nrows = [")[0], ns)   # scrub·ID 정의만 로드(실행부 제외)
new = ns['scrub'](old)
import re
assert not re.findall(r'\b' + ns['ID'] + r'\b', new), new
L[j:k] = [ind + 'description: ' + json.dumps(new, ensure_ascii=False)]
txt = '\n'.join(L)
yaml.safe_load(txt)
io.open(W, 'w', encoding='utf-8').write(txt)
io.open('/workspace/tmp/o227/c3_col_diff.md', 'a', encoding='utf-8')
print('복구 후 |', new)
print('줄 제거', k - j - 1)
