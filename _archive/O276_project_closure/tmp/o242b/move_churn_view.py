# O242-B — ML_CHURN_BY_CMPGN_CTGR_V 정의를 25 → 21(ATTR 블록 앞)로 글자 그대로 이동 · Co-authored with CoCo
# 이유 = 신규 구축 순서 21 → 22 → 25 에서 21 의 ML_MEMBER_ATTR_ASOF_V 와 22 의 SV 가 이 뷰를 먼저 필요로 한다.
import io, hashlib, shutil, sys
A, Z = '05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql', '05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql'
a = io.open(A, encoding='utf-8').read().split('\n'); z = io.open(Z, encoding='utf-8').read().split('\n')
# 25: 18~75 = 활동 판정 주석 + CREATE VIEW(끝 = ';' 다음 빈 줄 76) · 183~185 = 뷰 GRANT 3줄
assert z[17].startswith('-- 활동 판정(결정적)') and z[74].endswith('AND s.CMPGN_CTGR_NM = a.CMPGN_CTGR_NM;'), (z[17][:30], z[74][-40:])
assert all(z[i].startswith('GRANT SELECT ON VIEW GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V') for i in (182, 183, 184))
# 21: 354 = O241-M 블록 구분선(그 앞에 삽입)
assert a[353].startswith('-- ====') and a[354].startswith('-- [O241-M]'), a[354][:30]
blk, gr = z[17:75], z[182:185]
head = ['-- ============================================================================',
        '-- [O242-B 이동] ML_CHURN_BY_CMPGN_CTGR_V — 원 정의 = 25_ML_CHURN_CMPGN_CTGR_DDL.sql(O224 · 문면 무변경 이동)',
        '--   이유 = 아래 ML_MEMBER_ATTR_ASOF_V(21) 와 22 의 SV 가 이 뷰를 참조한다 ⇒ 신규 구축(21 → 22 → 25)에서 먼저 있어야 한다.',
        '-- ============================================================================']
na = a[:353] + head + blk + gr + [''] + a[353:]
ptr = ['-- [O242-B] ML_CHURN_BY_CMPGN_CTGR_V 정의와 그 GRANT 3줄은 21_ML_SERVING_뷰_DDL.sql 로 옮겼다(문면 무변경 · 신규 구축 순서 의존성).',
       '--   이 파일은 그 뷰가 이미 있다고 보고 SV 만 만든다 ⇒ 단독 실행 전에 21 을 먼저 실행한다.']
nz = z[:17] + ptr + z[75:182] + z[185:]
# 무변경 대조 = 옮긴 줄 묶음이 21 에 그대로 있다
sa = '\n'.join(na)
assert '\n'.join(blk) in sa and '\n'.join(gr) in sa
assert 'CREATE OR REPLACE VIEW GN_DW.SERVING.ML_CHURN_BY_CMPGN_CTGR_V' not in '\n'.join(nz)
print('blk', len(blk), hashlib.sha256('\n'.join(blk).encode()).hexdigest()[:12], 'grant', len(gr))
if '--apply' in sys.argv:
    shutil.copy(A, 'tmp/o242b/bak/21_ML_SERVING_뷰_DDL.sql'); shutil.copy(Z, 'tmp/o242b/bak/25_ML_CHURN_CMPGN_CTGR_DDL.sql')
    io.open(A, 'w', encoding='utf-8', newline='').write(sa)
    io.open(Z, 'w', encoding='utf-8', newline='').write('\n'.join(nz))
    print('WRITE', len(a), '->', len(na), '|', len(z), '->', len(nz))
