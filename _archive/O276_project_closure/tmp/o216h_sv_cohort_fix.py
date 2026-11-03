import io, sys
p = '/workspace/05_SV-Agent_ai/05_3_SV_DDL_MEMBER_COHORT.sql'
s = io.open(p, encoding='utf-8').read()
a = s.index('🔴🔴 ** 이 축만 「현재 시점」이다**')
b = s.index('N-9)', a) + len('N-9)')
old = s[a:b]
assert s.count(old) == 1
new = ('🟢 캠페인명과 분류 속성 8종(카테고리·브랜드·상위캠페인·홍보방법·모집채널·국내해외·사업사례·마케팅캠페인)은 '
       '**같은 시점의 값**(최신 캠페인 마스터)이다 — 이력 보관을 하지 않으므로 캠페인이 개칭·재분류되면 과거 획득 회원도 '
       '새 이름·새 분류로 함께 보인다. 「획득 당시 이름」을 따로 답할 수 없다고 밝힐 것')
s = s[:a] + new + s[b:]
io.open(p, 'w', encoding='utf-8').write(s)
print('replaced', len(old), '->', len(new))
