# -*- coding: utf-8 -*-
"""[2026-08-11 O59-L] 06_DDL 규칙7 39건의 **문안 문맥**을 덤프해 진짜/오탐을 가른다.

🔴 왜 문맥이 필요한가: O59-D/E 에서 같은 검사의 신규 유입 17건 중 **15건이 오탐**이었다.
   문맥 없이 39건을 일괄 치환하면 **규약 상수·불변식 임계·논리 공집합·grain 서술을 지운다**(의미 파괴).
사용: python3 scripts/o59l_rule7_context.py
"""
import io
import re
import sys

sys.path.insert(0, '/workspace/scripts')
import audit_ddl_rule7 as a

# O53 신규 4블록 = 손 편집 금지(06_DDL 헤더 line 15~19 · 정본은 dbt schema.yml + 생성기)
O53_NEW = {'DIM_MONTH', 'DIM_MEMBER_CURRENT', 'DIM_MEMBER_ACQUISITION', 'FACT_DEV_ACHIEVEMENT'}

for t, body in a.blocks():
    rows = []
    for line in body.split('\n'):
        m = re.match(r"\s+([A-Z0-9_]+)\s+\S+.*?COMMENT\s+'(.*)'\s*,?\s*(?:--.*)?$", line)
        if not m:
            continue
        col, cmt = m.group(1), m.group(2)
        hits = a.hits_for(cmt)
        if hits:
            rows.append((col, hits, cmt))
    if not rows:
        continue
    flag = '  ⛔ O53 신규 블록 — 손 편집 금지(yml→생성기)' if t in O53_NEW else ''
    print('\n' + '=' * 100)
    print('### %s  (%d건)%s' % (t, len(rows), flag))
    for col, hits, cmt in rows:
        print('  ── %s   %s' % (col, ', '.join('%s:%s' % h for h in hits)))
        clean = a.WHITE.sub('', cmt)
        for name, val in hits:
            for mm in re.finditer(re.escape(val), clean):
                s = max(0, mm.start() - 70)
                e = min(len(clean), mm.end() + 70)
                print('       [%s] …%s…' % (val, clean[s:e].replace('\n', ' ')))
                break
