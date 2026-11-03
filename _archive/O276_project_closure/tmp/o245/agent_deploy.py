# O245 — Agent 2종 버전업(09_2 [0-B] 동기화 → [0-C] 대조 → [2] live 소진 → [3] ADD VERSION → [5] 확인) · 사용자 승인 2026-10-18
import io, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

AG = ['AGENT_EXECUTIVE', 'AGENT_MARKETING']
WS = 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents/'
log = io.open('/workspace/tmp/o245/agent_deploy.out', 'w', encoding='utf-8')
cn = conn()
cur = cn.cursor()
cur.execute('USE ROLE GN_DW_ADMIN')
for a in AG:
    cur.execute("COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/%s/ FROM '%s%s/' PATTERN = '.*agent_spec[.]yaml'" % (a, WS, a))
    log.write('COPY %s %s\n' % (a, cur.fetchall()))
cur.execute("LIST '%s' PATTERN = '.*agent_spec[.]yaml'" % WS)
src = {r[0].split('/')[-2]: r[1] for r in cur.fetchall()}
cur.execute("LIST @GN_DW.OPS.AGENT_SPEC_STAGE PATTERN = '.*agent_spec[.]yaml'")
dst = {r[0].split('/')[-2]: r[1] for r in cur.fetchall()}
for a in AG:
    ok = src.get(a) == dst.get(a)
    log.write('VERIFY %s ws=%s stage=%s %s\n' % (a, src.get(a), dst.get(a), 'OK' if ok else 'SIZE_MISMATCH'))
    if not ok:
        log.close()
        sys.exit('size mismatch ' + a)
for a in AG:
    cur.execute('SHOW VERSIONS IN AGENT GN_DW.SERVING.%s' % a)
    cols = [d[0] for d in cur.description]
    if any(r[cols.index('name')] is None for r in cur.fetchall()):
        cur.execute("ALTER AGENT GN_DW.SERVING.%s COMMIT COMMENT = 'live 소진(O245 버전업 직전 스냅샷)'" % a)
        log.write('LIVE_COMMIT %s\n' % a)
    cur.execute("ALTER AGENT GN_DW.SERVING.%s ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/%s' "
                "COMMENT = 'O245 = 추경 데이터 없음 문안 · 추경목표(공153·공155) 산출 불가 규칙'" % (a, a))
    log.write('ADD_VERSION %s %s qid=%s\n' % (a, cur.fetchall(), cur.sfqid))
    cur.execute('SHOW VERSIONS IN AGENT GN_DW.SERVING.%s' % a)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    for r in rows[-2:]:
        log.write('  %s default=%s created=%s\n' % (r[cols.index('name')], r[cols.index('is_default')], r[cols.index('created_on')]))
cn.close()
log.close()
print('done')
