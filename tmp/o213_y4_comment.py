# O213-Y4 — 09_1 [1]·[5] Agent COMMENT 이중 정본 동시 갱신(문안 꼬리에 7차 신규 주제 덧붙임 · 각 2회 정확 일치 검증)
# Co-authored with CoCo
import hashlib, io, sys
P = '/workspace/05_SV-Agent_ai/09_1_AGENT_생성.sql'
h = lambda: hashlib.sha256(open(P, 'rb').read()).hexdigest()
h0 = h(); assert h0 == h()
t = io.open(P, encoding='utf-8').read()
R = [
 ("+ 부서 자체 수식 집계(회원실 회비예측·후원분류·기획실 개발목표) 분석.'",
  "+ 부서 자체 수식 집계(회원실 회비예측·후원분류·기획실 개발목표) + 회비 청구 처리(청구구분·처리상태·환급사유) · 회원 속성·발송 카테고리·결연 중단 사유 축 분석.'"),
 ("+ 머신러닝(ML) 예측(개발금액·LTV 월별·기여요인) 종합 지원.'",
  "+ 머신러닝(ML) 예측(개발금액·LTV 월별·기여요인) + 부서별 지출결의·회비 청구 처리 · 광고 매체·예산 과목(장·관·항) 축 종합 지원.'"),
 ("+ 머신러닝(ML) 예측(개발금액·회원 증액 가능성) 분석.'",
  "+ 머신러닝(ML) 예측(개발금액·회원 증액 가능성) + 홈페이지 방문(GA4 세션·후원자유형·국가·기기·유입채널)·구글 검색어·방문자 성별/연령·부서별 지출결의 분석.'"),
]
for a, b in R:
    n = t.count(a); assert n == 2, (a[:30], n)
    t = t.replace(a, b)
if '--apply' in sys.argv:
    assert h() == h0
    io.open(P, 'w', encoding='utf-8', newline='').write(t); print('WROTE', h()[:12])
else:
    print('DRY OK')
