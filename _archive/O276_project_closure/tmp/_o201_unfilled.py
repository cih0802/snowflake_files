#!/usr/bin/env python3
# O201 ⑤ — GOLD 미주입 집합: O170 집합(95) 대비 집합 차이 + SV 노출 후보
# 🔴 판정식 = 총계가 아니라 집합 차이(_o170_evidence.md §E4-3 · §E7-3)
import io, json, os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts'))
import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location(
    'o170diff_src', os.path.join(ROOT, 'scripts', '_o170_unfilled_diff.py'))
src = io.open(spec.origin, encoding='utf-8').read()
# O167 사전만 재사용한다(원문 전사 · assert 95 포함) — 출력부는 실행하지 않는다
ns = {}
exec(src.split('# --- 라이브 현재 미주입 ---')[0], ns)
o170 = set(ns['prev_corrected'])                       # O167 95 + IS_HOLIDAY = 96
o170 -= {('FACT_MEMBER_EVENT', 'UNPAID_STOP_CNT'),
         ('FACT_MEMBER_EVENT', 'UNPAID_STOP_MEMBERS')}  # §E4-3 해소 2
o170.add(('FACT_AD_DIGITAL', 'CRM_DEV_CNT'))           # §E7-3 신규 1
assert len(o170) == 95, len(o170)

CEN = json.load(io.open('/tmp/census.json', encoding='utf-8'))
cur, kind = set(), {}
for key, ent in CEN.items():
    if not key.startswith('GOLD.'):
        continue
    t = key[5:]
    for c, m in ent['cols'].items():
        if c.startswith('DW_'):
            continue
        if (m['nonzero'] or 0) == 0:
            cur.add((t, c))
            kind[(t, c)] = '0행' if ent['rows'] == 0 else ('전건NULL' if (m['nonnull'] or 0) == 0 else '전건0')

resolved = sorted(o170 - cur)
newly = sorted(cur - o170)

from sfconn import conn, q
cn = conn()
_, svs = q("SHOW SEMANTIC VIEWS IN DATABASE GN_DW", cn)
ddl = {}
for r in svs:
    name = r[1]
    _, d = q("SELECT GET_DDL('SEMANTIC_VIEW', 'GN_DW.SERVING.%s')" % name, cn)
    ddl[name] = d[0][0]
cn.close()

expose = []
for t, c in sorted(cur):
    hits = [n for n, d in ddl.items() if re.search(r'\b%s\b' % re.escape(c), d)]
    if hits:
        expose.append((t, c, kind[(t, c)], hits))

out = io.StringIO()
p = lambda *a: print(*a, file=out)
p('O170 집합 = %d · JU93656 현재 = %d' % (len(o170), len(cur)))
p('해소(O170 有 · 현재 無) = %d' % len(resolved))
for t, c in resolved:
    p('  🟢 %s.%s' % (t, c))
p('신규(현재 有 · O170 無) = %d' % len(newly))
for t, c in newly:
    p('  🔴 %s.%s [%s]' % (t, c, kind[(t, c)]))
p('SV 노출 후보(컬럼명 토큰이 SV DDL 에 등장) = %d' % len(expose))
for t, c, k, h in expose:
    p('  ⚠ %s.%s [%s] ← %s' % (t, c, k, ','.join(h)))
txt = out.getvalue()
io.open(os.path.join(ROOT, 'tmp', '_o201_unfilled.out'), 'w', encoding='utf-8').write(txt)
print(txt.split('SV 노출 후보')[0][:3000])
print('SV 노출 후보 = %d (전문 = tmp/_o201_unfilled.out)' % len(expose))
