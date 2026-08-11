# -*- coding: utf-8 -*-
"""[2026-08-11 O59-G] BRONZE 전반에 단문자 `)` 오염이 있는지 교차 검사.

가설 A(원천 유래) vs 가설 B(적재 중 오염)의 판별 근거를 만든다.
· B 가 맞다면 `)` 는 **여러 테이블**에 나타난다(같은 적재 경로를 통과했으므로).
· A 가 맞다면 `TD_MS_EVENT_PRTCPNT_DTL` 에만 국지적으로 남는다.
테이블당 스캔 1회(전 TEXT 컬럼을 OR 로 묶는다).
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn, q

TABLES = [
    ('BRONZE_CRM', 'TD_MS_EVENT_PRTCPNT_DTL'),   # 기지 오염 테이블(양성 대조)
    ('BRONZE_CRM', 'TM_MM_FDRM_MBER_INFO'),
    ('BRONZE_CRM', 'TM_MM_FDRM_MBER_SPNSR_DSCNTC'),
    ('BRONZE_CRM', 'TM_MM_FDRM_MBER_DVLP_AMT'),
    ('BRONZE_CRM', 'TM_PM_DNTN_DTLS'),
    ('BRONZE_CRM', 'TM_MM_FDRM_MBER_IRSD'),
    ('BRONZE_CRM', 'TD_MS_PSTMTR_SNDNG_DTL'),
    ('BRONZE_CRM', 'TM_RM_CHILD_MSTR_INFO'),
    ('BRONZE_AGENCY', 'DGT_AD_CMPGN_DTLS'),
]

cn = conn()
print('%-13s %-32s %8s %6s  %s' % ('SCHEMA', 'TABLE', 'TEXT컬럼', ')행', '컬럼별 내역'))
tot = empty = 0
for sch, tbl in TABLES:
    # 🔴 [자기적발] 종전 판정 `column_name not like '\_%'` 는 Snowflake 문자열 이스케이프 때문에
    #   패턴이 `_%`(= 모든 이름)이 되어 **전 컬럼을 제외**했다 ⇒ 전 테이블 「TEXT 컬럼 없음」 공집합 통과.
    #   ⇒ LEFT() 비교로 바꾸고, 아래에서 **컬럼 0 이면 실패**로 본다(P106).
    _, cols = q("select column_name from GN_DW.information_schema.columns "
                "where table_schema='%s' and table_name='%s' and data_type='TEXT' "
                "and LEFT(column_name,1) <> '_' order by ordinal_position" % (sch, tbl), cn)
    names = [r[0] for r in cols]
    if not names:
        empty += 1
        print('%-13s %-32s %8d %6s  🔴 TEXT 컬럼 0 — 판정 불가(공집합)' % (sch, tbl, 0, '-'))
        continue
    where = ' OR '.join('"%s" = \')\'' % c for c in names)
    sel = ', '.join('SUM(IFF("%s" = \')\', 1, 0)) AS "%s"' % (c, c) for c in names)
    _, r = q('select count(*), %s from GN_DW.%s.%s where %s' % (sel, sch, tbl, where), cn)
    n = r[0][0]
    tot += n
    detail = ' · '.join('%s=%s' % (names[i], r[0][i + 1]) for i in range(len(names))
                        if r[0][i + 1]) or '-'
    print('%-13s %-32s %8d %6d  %s' % (sch, tbl, len(names), n, detail))
print('\n합계 `)` 행 %d · 검사 테이블 %d · 🔴 판정불가 %d' % (tot, len(TABLES), empty))
if empty:
    sys.exit('🔴 공집합 — TEXT 컬럼을 못 읽은 테이블이 있다(P106)')
cn.close()
