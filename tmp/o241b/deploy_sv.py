# O241-R/M — 변경 SV 파일 배포(파일 단위 execute_string · 실패 시 그 파일에서 멈춤) · Co-authored with CoCo
import io, sys, glob, os
B = os.path.dirname(os.path.abspath(__file__)) + '/../../'
sys.path.insert(0, B + 'scripts')
from sfconn import conn
cn = conn(); cn.cursor().execute('USE ROLE GN_DW_ADMIN'); cn.cursor().execute('USE WAREHOUSE GN_DW_DEV_WH')
files = sys.argv[1:]
for f in files:
    try:
        n = 0
        for cur in cn.execute_stream(io.open(f, encoding='utf-8'), remove_comments=True):
            n += 1
        print('OK', os.path.basename(f), n, flush=True)
    except Exception as e:
        print('🔴', os.path.basename(f), str(e)[:400], flush=True); sys.exit(1)
