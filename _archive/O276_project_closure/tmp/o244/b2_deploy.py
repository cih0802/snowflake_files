# O244 B② — SV_MEMBER_EVENT(05_02) · SV_MEMBER_COHORT(05_03) COMMENT 교정 라이브 반영(사용자 승인 2026-10-18)
# 실행 범위 = 파일 첫 줄 ~ 마지막 GRANT 줄(USE ROLE GN_DW_ADMIN · CREATE OR ALTER · GRANT 3) · 스모크 SELECT 는 제외
import io, sys, datetime
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

FILES = ['05_02_SV_DDL_MEMBER_EVENT.sql', '05_03_SV_DDL_MEMBER_COHORT.sql']
D = '/workspace/05_SV-Agent_ai/'
log = io.open('/workspace/tmp/o244/b2_deploy.out', 'w', encoding='utf-8')
cn = conn()
for f in FILES:
    lines = io.open(D + f, encoding='utf-8').read().split('\n')
    last = max(i for i, l in enumerate(lines) if l.lstrip().upper().startswith('GRANT '))
    body = '\n'.join(lines[:last + 1])
    log.write('== %s · lines 1..%d · %s\n' % (f, last + 1, datetime.datetime.now().isoformat()))
    for cur in cn.execute_string(body, remove_comments=False):
        r = cur.fetchone()
        log.write('  OK %s | %s\n' % (cur.sfqid, (str(r[0]) if r else '')[:100]))
cur = cn.cursor()
for sv, dim in [('SV_MEMBER_EVENT', 'CMMN_BRND_NM'), ('SV_MEMBER_COHORT', 'MARKETING_CAMPAIGN')]:
    cur.execute("select COMMENT from GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS where SEMANTIC_VIEW_SCHEMA='SERVING' "
                "and SEMANTIC_VIEW_NAME=%s and NAME=%s", (sv, dim))
    c = (cur.fetchone() or [''])[0] or ''
    log.write('VERIFY %s.%s 직원개발=%s 16종=%s 15종=%s 25년영상=%s\n' % (
        sv, dim, '직원개발' in c, '16종' in c, '15종' in c, '25년 이전컨텐츠(영상광고)' in c))
cn.close()
log.close()
print('done')
