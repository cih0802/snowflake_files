"""O270 W5 — SV·SERVING 뷰 DDL 파일에 접근 역할 GRANT 줄 추가(일회성 · 2026-10-29 O270-F · 사용자 승인).
규칙 = 기존 `... TO ROLE GN_DW_VIEWER;` GRANT 줄 바로 뒤에 같은 객체·같은 권한의 접근 역할 줄 1개(이미 있으면 건너뜀).
역할 = 12_agent개선과제/output/O270_source_class.csv 의 source_class. --dry 면 쓰지 않는다."""
import csv, glob, re, sys
W = '/workspace'
AR = {'COMMON': 'GN_DW_AR_SRC_COMMON', 'AGENCY': 'GN_DW_AR_SRC_AGENCY',
      'ERP': 'GN_DW_AR_SRC_ERP', 'AGENCY+ERP': 'GN_DW_AR_SRC_AGENCY_ERP'}
cls = {r['object']: r['source_class'] for r in csv.DictReader(open(W + '/12_agent개선과제/output/O270_source_class.csv', encoding='utf-8'))
       if r['layer'] == 'SERVING'}
pat = re.compile(r'^(\s*GRANT\s+([A-Z, ]+?)\s+ON\s+(SEMANTIC VIEW|VIEW)\s+(?:GN_DW\.)?(?:SERVING\.)?([A-Z0-9_]+)\s+TO\s+ROLE\s+)GN_DW_VIEWER\s*;\s*$', re.I)
dry = '--dry' in sys.argv
touched, added, unknown, covered = {}, 0, set(), set()
FILES = sorted(glob.glob(W + '/05_SV-Agent_ai/*.sql')) + [W + '/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql']
for f in FILES:
    L = open(f, encoding='utf-8').read().split('\n')
    out, n = [], 0
    for i, l in enumerate(L):
        out.append(l)
        m = pat.match(l)
        if not m:
            continue
        obj = m.group(4).upper()
        c = cls.get(obj)
        if c is None:
            unknown.add(obj)
            continue
        covered.add(obj)
        new = '%sGN_DW_%s;' % (m.group(1).replace('GN_DW_VIEWER', ''), AR[c][len('GN_DW_'):])
        new = re.sub(r'TO\s+ROLE\s+$', 'TO ROLE ', m.group(1)) + AR[c] + ';'
        if any(AR[c] in x and obj in x.upper() for x in L):
            continue
        out.append(new + '  -- O270 원천별 접근 역할')
        n += 1
    if n:
        touched[f.split('/')[-1]] = n
        added += n
        if not dry:
            open(f, 'w', encoding='utf-8').write('\n'.join(out))
sv_all = {k for k in cls if k.startswith('SV_')}
print('files', len(touched), 'added', added, 'dry' if dry else 'WRITTEN')
print('SV 미커버(파일에 VIEWER GRANT 줄 없음) =', sorted(sv_all - covered))
print('분류표 밖 객체 =', sorted(unknown))
for k, v in touched.items():
    print(' ', k, v)
