# O244 B② — sv_code_label_gate blocking 3건 라이브 실측(게이트와 같은 연결 sfconn · 읽기 전용)
import io, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn, q

cn = conn()
out = io.open('/workspace/tmp/o244/b2_measure.md', 'w', encoding='utf-8')
_, r = q("select current_role(), current_account()", cn)
out.write('# O244 B② 실측 (sfconn)\n\nrole/account = %s\n\n' % (r[0],))
for title, sql in [
    ('FACT_MEMBER_EVENT.CMMN_BRND_NM_AT_EVENT',
     'select CMMN_BRND_NM_AT_EVENT, count(*) from GN_DW.GOLD.FACT_MEMBER_EVENT group by 1 order by 1'),
    ('FACT_MEMBER_COHORT.ACQ_MKTG_CMPGN_NM (값 검사 7종)',
     "select ACQ_MKTG_CMPGN_NM, count(*) from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_MKTG_CMPGN_NM in "
     "('24년 이전컨텐츠','그외 지역개발캠페인','유어턴(통합A)','유어턴(통합B)','기존회원캠페인 및 기타',"
     "'25년 이전컨텐츠(영상광고)','TS/TM') group by 1 order by 1"),
    ('ACQ_MKTG_CMPGN_NM 유사값(유어턴·25년)',
     "select ACQ_MKTG_CMPGN_NM, count(*) from GN_DW.GOLD.FACT_MEMBER_COHORT where ACQ_MKTG_CMPGN_NM ilike '%유어턴%' "
     "or ACQ_MKTG_CMPGN_NM ilike '25년%' or ACQ_MKTG_CMPGN_NM ilike '%이전컨텐츠%' group by 1 order by 1"),
    ('ACQ_MKTG_CMPGN_NM 상위 20',
     'select ACQ_MKTG_CMPGN_NM, count(*) c from GN_DW.GOLD.FACT_MEMBER_COHORT group by 1 order by c desc limit 20'),
]:
    try:
        _, rows = q(sql, cn)
        out.write('## %s\n\n| 값 | 행수 |\n|---|---:|\n' % title)
        for v, c in rows:
            out.write('| %s | %s |\n' % ('NULL' if v is None else v, c))
        out.write('\n종수(NULL 제외) = %d\n\n' % sum(1 for v, _ in rows if v is not None))
    except Exception as e:
        out.write('## %s\n\nERROR %s\n\n' % (title, str(e)[:200]))
out.close()
cn.close()
print('done')
