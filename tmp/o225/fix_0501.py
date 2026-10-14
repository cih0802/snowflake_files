import io
p = '/workspace/05_SV-Agent_ai/05_01_SV_DDL_MEMBER_MONTHLY.sql'
old = "캠페인별/후원사업별 활동회원수는 SV_MEMBER_SPONSOR_BIZ 로 라우팅."
new = ("캠페인별/후원사업별 활동회원수는 SV_MEMBER_SPONSOR_BIZ 로 라우팅. "
       "🆕 [O225-C] 이 뷰의 campaign 차원은 「그 달 후원 캠페인」이 하나인 회원×월만 연결된다 — 다중 캠페인 월은 (미매핑)이므로 "
       "캠페인별 회비 금액(청구·납입·미납)의 정확한 합계는 SV_PAYMENT_BILLING_STATUS(청구 행 단위 귀속)로 답하고, "
       "이 뷰로 캠페인별 값을 낼 때는 (미매핑) 행과 IS_MULTI_CAMPAIGN 비중을 함께 밝힌다.")
s = io.open(p, encoding='utf-8').read()
n = s.count(old)
assert n == 1, n
io.open(p, 'w', encoding='utf-8').write(s.replace(old, new))
print('replaced', n)
