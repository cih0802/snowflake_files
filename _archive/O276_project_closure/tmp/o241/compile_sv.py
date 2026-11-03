# O241 ⑥ — 수정 SV DDL 문법 검증(임시 이름 생성 → 즉시 DROP · 라이브 SV 무변경)
import os, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn
os.chdir('/workspace')
cn = conn()
cur = cn.cursor()
cur.execute('USE WAREHOUSE COMPUTE_WH')
ok, bad = 0, []
for f in sorted(os.listdir('tmp/o241/bak')):
    fn = f.replace('.O241-before', '')
    t = open('05_SV-Agent_ai/' + fn, encoding='utf-8').read()
    m = re.search(r'^CREATE OR ALTER SEMANTIC VIEW GN_DW\.SERVING\.(SV_\w+)(.*?)(?=^GRANT |^-- GRANT|^USE )', t, re.S | re.M)
    if not m:
        bad.append((fn, '문장 추출 실패'))
        continue
    body = re.sub(r'(\s*--[^\n]*)*\s*$', '', m.group(2)).rstrip().rstrip(';')
    tmp = 'ZZ_O241_' + m.group(1)
    sql = 'CREATE OR REPLACE SEMANTIC VIEW GN_DW.SERVING.' + tmp + body
    try:
        cur.execute(sql)
        ok += 1
    except Exception as e:
        bad.append((fn, str(e)[:300]))
    finally:
        try:
            cur.execute('DROP SEMANTIC VIEW IF EXISTS GN_DW.SERVING.' + tmp)
        except Exception:
            pass
print('OK', ok, 'FAIL', len(bad))
for b in bad:
    print(' ', b)
cn.close()
