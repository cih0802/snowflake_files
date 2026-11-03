import io
p = '/workspace/05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql'
old = "🔴🔴 **캠페인 축은 이 SV 에 없다** — 종전 문안이 grain 에 「캠페인」을 적었으나 캠페인 차원이 배선돼 있지 않고 base 의 캠페인 키도 전건 센티넬이다(원천 CRM_SEND* 에 캠페인 키가 부재 · 결측이 아니라 구조적 부재) ⇒ 「캠페인별 발송」 질문에는 **축 부재를 밝히고** 캠페인으로 분해하지 말 것"
new = "🆕 [O225-C] 캠페인 축 = 문자(SND) 발송 캠페인만 배선(원천 SND_MEMBER_LIST.CMPGN_CD) — 이메일·알림톡·우편은 원천에 캠페인 키가 없어 (미매핑)(구조적 부재) ⇒ 「캠페인별 발송」은 SND 기준임을 밝힌다"
s = io.open(p, encoding='utf-8').read()
n = s.count(old)
assert n == 2, n
io.open(p, 'w', encoding='utf-8').write(s.replace(old, new))
print('replaced', n)
