# SV DDL 파일의 CREATE OR ALTER SEMANTIC VIEW 문을 추출해 GN_DW.OPS.<SV>_O237_PROBE 로 이름만 바꾼다(라이브 SV 무변경 · 검증 후 DROP)
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
i = re.search(r'(?m)^CREATE OR ALTER SEMANTIC VIEW', s).start()
j = re.search(r'\n(-- GRANT|GRANT )', s[i:]).start() + i
stmt = s[i:j].rstrip().rstrip(';')
m = re.match(r'CREATE OR ALTER SEMANTIC VIEW (GN_DW\.SERVING\.\w+)', stmt)
name = m.group(1)
stmt = 'CREATE OR REPLACE SEMANTIC VIEW GN_DW.OPS.' + name.split('.')[-1] + '_O237_PROBE' + stmt[m.end():]
open(sys.argv[2], 'w', encoding='utf-8').write(stmt)
print(name, len(stmt), stmt.count("'") % 2)
