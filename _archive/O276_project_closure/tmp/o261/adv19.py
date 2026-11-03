import io, re, glob
pairs = [l for l in io.open('/workspace/tmp/o261/g_code_label2.out', encoding='utf-8') if '열거 누락(§6.9-(5)):' in l]
files = sorted(glob.glob('/workspace/05_SV-Agent_ai/*.sql')) + ['/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql']
txt = {f: io.open(f, encoding='utf-8').read() for f in files}
SVP = re.compile(r'CREATE\s+OR\s+(?:ALTER|REPLACE)\s+SEMANTIC\s+VIEW\s+GN_DW\.\w+\.(\w+)', re.I)
for l in pairs:
    m = re.search(r'\): (\w+)\.(\w+) ▸', l)
    sv, dim = m.group(1), m.group(2)
    shown = False
    for f, t in txt.items():
        for s in SVP.finditer(t):
            if s.group(1).upper() != sv:
                continue
            end = t.find(';\n', s.end())
            seg = t[s.start():end]
            d = re.search(r'\w+\.%s\s+AS\s+.*?COMMENT\s*=\s*\'((?:[^\']|\'\')*)\'' % dim, seg, re.I | re.S)
            if d and not shown:
                print(sv, dim, '|', f.split('/')[-1], '|', d.group(1)[:260].replace('\n', ' '))
                shown = True
    if not shown:
        print(sv, dim, '| (소스 정의 미발견)')
