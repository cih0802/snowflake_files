"""O270 W9 — 권한 매트릭스(객체 × 기능 역할) 생성기 · 정본 = output/O270_source_class.csv · 손으로 고치지 말고 재생성."""
import csv
W = '/workspace'
FR = [('마케팅', 'GN_DW_FR_MARKETING', {'COMMON', 'AGENCY', 'ERP', 'AGENCY+ERP'}),
      ('회원', 'GN_DW_FR_MEMBER', {'COMMON'}),
      ('경영·기획실', 'GN_DW_FR_EXEC', {'COMMON', 'ERP'}),
      ('팀장', 'GN_DW_FR_LEAD', set())]
rows = [r for r in csv.DictReader(open(W + '/12_agent개선과제/output/O270_source_class.csv', encoding='utf-8'))
        if r['layer'] in ('GOLD', 'SERVING')]
L = ['<!-- LLM-METADATA', 'doc_id: O270_RBAC_MATRIX', 'doc_role: 자동 생성물 — 객체 × 기능 역할 권한 매트릭스(손으로 고치지 마라)',
     'project: GN_DW (굿네이버스)', 'created: 2026-10-30', 'created_by: O270-F', 'index: 20_issue/00_INDEX_이슈원장.md', 'END-METADATA -->', '',
     '# O270 권한 매트릭스(객체 × 기능 역할)', '',
     '> 🔴 자동 생성물 — 생성기 = `12_agent개선과제/output/O270_gen_rbac_matrix.py` · 정본 = `output/O270_source_class.csv`',
     '> ✅ = SELECT 가능 · — = 권한 없음 · 팀장 = Streamlit 전용(SV·테이블·Agent 0)', '',
     '## 1. Agent', '', '| Agent | 마케팅 | 회원 | 경영·기획실 | 팀장 |', '|---|---|---|---|---|',
     '| AGENT_MARKETING | ✅ | — | — | — |', '| AGENT_MEMBER | — | ✅ | — | — |', '| AGENT_EXECUTIVE | — | — | ✅ | — |', '',
     '## 2. 원천 분류별 객체 수', '', '| 분류 | 객체 수 | ' + ' | '.join(f[0] for f in FR) + ' |', '|---|---|' + '---|' * len(FR)]
for c in ('COMMON', 'AGENCY', 'ERP', 'AGENCY+ERP'):
    n = sum(r['source_class'] == c for r in rows)
    L.append('| %s | %d | %s |' % (c, n, ' | '.join('✅' if c in f[2] else '—' for f in FR)))
L += ['', '## 3. 원천 제한 객체(공통 제외)', '', '| 계층 | 객체 | 유형 | 분류 | ' + ' | '.join(f[0] for f in FR) + ' |',
      '|---|---|---|---|' + '---|' * len(FR)]
for r in sorted(rows, key=lambda x: (x['source_class'], x['layer'], x['object'])):
    if r['source_class'] != 'COMMON':
        L.append('| %s | %s | %s | %s | %s |' % (r['layer'], r['object'], r['type'], r['source_class'],
                                                 ' | '.join('✅' if r['source_class'] in f[2] else '—' for f in FR)))
L += ['', '_Co-authored with CoCo_', '']
open(W + '/12_agent개선과제/output/O270_권한매트릭스.md', 'w', encoding='utf-8').write('\n'.join(L))
print('rows', len(L))
