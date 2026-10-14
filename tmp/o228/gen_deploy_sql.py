#!/usr/bin/env python3
"""O228 ③ — deploy_c3_sv.py 와 같은 22문을 사용자 실행용 SQL 1파일로 낸다(세션 범위에 SV OWNERSHIP 없음 · 003001).
산출 = tmp/o228/c3_sv_deploy.sql · 실행 = 👤 Snowsight 워크시트(GN_DW_ADMIN) · 확인 = deploy_c3_sv.py verify
Co-authored with CoCo
"""
import io, re, sys
sys.argv = [sys.argv[0], 'dry']
src = io.open('/workspace/tmp/o228/deploy_c3_sv.py', encoding='utf-8').read()
ns = {}
exec(compile(src[:src.index('cur = conn()')], 'd', 'exec'), ns)
out = ['-- O228 C3 SV 재배포(COMMENT 문안만 변경 · CREATE OR ALTER) · 생성 = tmp/o228/gen_deploy_sql.py',
       '-- 👤 GN_DW_ADMIN 으로 전체 실행(Run All) · 끝나면 에이전트가 deploy_c3_sv.py verify 로 대조',
       'USE ROLE GN_DW_ADMIN;', 'USE WAREHOUSE GN_DW_ETL_WH;', 'USE SCHEMA GN_DW.SERVING;', '']
for f, sv in ns['pairs']:
    out.append(f'-- {sv} ← {f}')
    out.append(ns['cut'](io.open(ns['path'](f), encoding='utf-8').read(), sv).rstrip() + ';')
    out.append('')
io.open('/workspace/tmp/o228/c3_sv_deploy.sql', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('문', len(ns['pairs']))
