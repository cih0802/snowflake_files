# O245 — SV/뷰 DDL 파일 라이브 반영(사용자 승인 2026-10-18) · 실행 범위 = 첫 줄 ~ 마지막 GRANT 줄 · 스모크 제외
# 사용: python3 tmp/o245/deploy_sql.py <로그명> <파일> [<파일> ...]   (경로 = 워크스페이스 기준)
import io, sys, datetime
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

log = io.open('/workspace/tmp/o245/%s.out' % sys.argv[1], 'w', encoding='utf-8')
cn = conn()
rc = 0
for f in sys.argv[2:]:
    lines = io.open('/workspace/' + f, encoding='utf-8').read().split('\n')
    last = max(i for i, l in enumerate(lines) if l.lstrip().upper().startswith('GRANT '))
    log.write('== %s · lines 1..%d · %s\n' % (f, last + 1, datetime.datetime.now().isoformat()))
    try:
        for cur in cn.execute_string('\n'.join(lines[:last + 1]), remove_comments=False):
            r = cur.fetchone()
            log.write('  OK %s | %s\n' % (cur.sfqid, (str(r[0]) if r else '')[:90]))
    except Exception as e:
        rc = 1
        log.write('  🔴 ERROR %s\n' % str(e)[:600])
        break
cn.close()
log.close()
print('rc', rc)
sys.exit(rc)
