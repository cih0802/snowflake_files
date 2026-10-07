# O206-C — 전 SV O206 출력 규칙에 「합계·분모는 SQL 로」 조항 추가 (멱등 · 해시 2회 · 단일 파일 순차 쓰기)
# 사용: python3 tmp/o206c_sv_total_rule.py [--apply]
# Co-authored with CoCo
import glob, hashlib, io, sys

ANCHOR = '이 규칙은 출력 이름만 바꾸며 필터·집계·정렬 로직을 바꾸지 않는다.'
ADD = (' [O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — '
       '그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다. '
       '중복제거 회원수(COUNT DISTINCT)는 그룹 값을 더하면 틀리므로 전체 값을 따로 COUNT DISTINCT 한다.')
MARK = '[O206-C 합계 규칙]'


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


apply = '--apply' in sys.argv
files = sorted(glob.glob('05_SV-Agent_ai/05_*_SV_DDL_*.sql') + ['05_SV-Agent_ai/22_ML_SV_DDL.sql', '05_SV-Agent_ai/23_MSTR_SV_DDL.sql'])
tot = 0
for p in files:
    if sha(p) != sha(p):
        print('UNSTABLE', p); continue
    t = io.open(p, encoding='utf-8').read()
    if MARK in t:
        print('SKIP', p); continue
    n = t.count(ANCHOR)
    new = t.replace(ANCHOR, ANCHOR + ADD)
    tot += n
    print(('APPLY ' if apply else 'DRY   ') + p, 'n=%d' % n)
    if apply and n:
        io.open(p, 'w', encoding='utf-8', newline='').write(new)
print('합계 =', tot)
