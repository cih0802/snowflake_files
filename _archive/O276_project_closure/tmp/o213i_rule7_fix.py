# O213-I 마감 — 규칙7(SV COMMENT 수치 혼입) 위반 9토큰 시정 · 7차 신설 문안 한정(05_9 기존 2건은 범위 밖)
import hashlib, io, sys
D = '/workspace/05_SV-Agent_ai/'
R = {
 '05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql': [('결측 아님 · 캠페인 37,204 중 5,211 · 2026-10-08 실측)', '결측 아님 · 근거 = 문서20 N-29 머리 실측)')],
 '05_2_SV_DDL_MEMBER_EVENT.sql':        [('결측 아님 · 캠페인 37,204 중 5,211 · 2026-10-08 실측)', '결측 아님 · 근거 = 문서20 N-29 머리 실측)')],
 '05_3_SV_DDL_MEMBER_COHORT.sql':       [('결측 아님 · 캠페인 37,204 중 5,211 · 2026-10-08 실측)', '결측 아님 · 근거 = 문서20 N-29 머리 실측)')],
 '05_12_SV_DDL_RELATION_ACTIVITY.sql':  [('결연 차원(1결연 = 1행)', '결연 차원(결연당 한 행)')],
 '05_4_SV_DDL_SERVICE.sql':             [('발송 요청 차원(요청 1건 = 1행)', '발송 요청 차원(요청당 한 행)')],
}
h = lambda p: hashlib.sha256(open(p, 'rb').read()).hexdigest()
for f, reps in R.items():
    p = D + f; h0 = h(p); assert h0 == h(p)
    t = io.open(p, encoding='utf-8').read()
    for a, b in reps:
        assert t.count(a) == 1, (f, a, t.count(a)); t = t.replace(a, b)
    if '--apply' in sys.argv:
        assert h(p) == h0
        io.open(p, 'w', encoding='utf-8', newline='').write(t); print('WROTE', f)
    else:
        print('DRY OK', f)
