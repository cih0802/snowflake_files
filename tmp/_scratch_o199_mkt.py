import io, re
src = io.open('/workspace/tmp/_scratch_o199_member_mkt.py', encoding='utf-8').read()
exec(src.split('# ---- MEMBER ----')[0])  # defines MR_NEW, sub, block
p = '/workspace/cortex_project/agents/AGENT_MARKETING/agent_spec.yaml'
s = io.open(p, encoding='utf-8').read()
start = "    description: 'ML 회원단위 예측(중단·증액·충성 · grain=기준월×회원). 원천=GN_DW.ML(머신러닝 산출물) → SERVING.ML_MEMBER_RISK_V. 🔴🔴"
assert s.count(start) == 1
a = s.index(start); b = s.index("\n", a)
old = s[a:b]
keep = old[old.index("🆕 [O198 · 나눔마케팅 배선]"):]
s = s[:a] + MR_NEW[:-1] + "\n      " + keep + s[b:]
assert '회원번호·회원상태·결제수단' not in s
io.open(p, 'w', encoding='utf-8').write(s)
print('MARKETING ok')
