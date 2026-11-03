import io, sys
p = '/workspace/05_SV-Agent_ai/05_07_SV_DDL_AD.sql'
s = io.open(p, encoding='utf-8').read()
i = s.find("핵심 규칙:")
j = s.find("'\n", i)
tail = s[j - 160:j + 1]
print('rule_len', j - i)
print('tail', repr(tail))
if len(sys.argv) > 1 and sys.argv[1] == 'apply':
    add = (" (🆕 O225-C 캠페인 속성 분해) 광고비는 마케팅캠페인 단위로만 붙어 있다 — UTM(MKTG_UTM_NM)·국내/해외·사업/사례별로는"
           " 이 SV 로 나눈다(국내/해외·사업/사례는 대표값이므로 *_IS_MULTI 비중을 밝힌다). 🔴 캠페인 인입경로·마케팅채널·캠페인 카테고리별"
           " 광고비는 이 SV 로 내지 않는다 — 마케팅캠페인 하나 아래 값이 갈리는 비중이 커서(광고비 기준 97.2%·95.7%·72.0%) 대표값이 왜곡된다."
           " 그 축의 성과(개발·회비)는 회원 측 SV(SV_MEMBER_EVENT·SV_MEMBER_FEE·SV_PAYMENT_BILLING_STATUS)로 안내한다.")
    s2 = s[:j] + add + s[j:]
    io.open(p, 'w', encoding='utf-8').write(s2)
    print('applied')
