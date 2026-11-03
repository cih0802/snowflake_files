"""O272-B 52번 블록 음성/양성 테스트 입력 생성기(임시 · SANDBOX 대상) — 라이브 GN_DW 무변경."""
import sys
sys.path.insert(0, '/workspace/scripts')
import run_sql_file as r

SRC = '/workspace/05_SV-Agent_ai/52_FIX_PROD_MANAGED_ACCESS_OPS_SILVER_ZL50263.sql'
s = [x for x in r.parse_statements(open(SRC, encoding='utf-8').read())
     if not r.is_comment_only(x) and 'EXECUTE IMMEDIATE $$' in x]
assert len(s) == 2, len(s)
a = (s[0].replace("'GN_DW.OPS'", "'SANDBOX.O272_P_OPS'")
     .replace("'GN_DW.OPS.O272_OPS_FUTURE_GRANTS_BAK'", "'SANDBOX.O272_P_BAK.OPS_BAK'")
     .replace("'ALTER SCHEMA ' || sch ||", "'ALTER SCHEMA ' || sch || '_NOPE' ||"))
b = (s[1].replace("'GN_DW.SILVER'", "'SANDBOX.O272_P_SILVER'")
     .replace("'GN_DW.OPS.O272_SILVER_FUTURE_GRANTS_BAK'", "'SANDBOX.O272_P_BAK.SILVER_BAK'"))
assert 'GN_DW.' not in a and 'GN_DW.' not in b and '_NOPE' in a
setup = """CREATE OR REPLACE SCHEMA SANDBOX.O272_P_BAK;
CREATE OR REPLACE SCHEMA SANDBOX.O272_P_OPS WITH MANAGED ACCESS;
CREATE OR REPLACE SCHEMA SANDBOX.O272_P_SILVER WITH MANAGED ACCESS;
GRANT SELECT ON FUTURE TABLES IN SCHEMA SANDBOX.O272_P_OPS TO ROLE GN_DW_VIEWER;
GRANT SELECT, INSERT ON FUTURE TABLES IN SCHEMA SANDBOX.O272_P_SILVER TO ROLE GN_DW_DBT;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SANDBOX.O272_P_SILVER TO ROLE GN_DW_ANALYST;
"""
open('/tmp/o272/t_setup.sql', 'w').write(setup)
open('/tmp/o272/t_fail.sql', 'w').write(a + ';\n')
open('/tmp/o272/t_ok.sql', 'w').write(b + ';\n')
print('GEN_OK blocks =', len(s))
