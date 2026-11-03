# O266 — 05_31 의 @@COMMON@@ 자리에 05_25 의 SV 공통 블록(AI_SQL_GENERATION 시작 2줄)을 그대로 이식한다(셸 경유 금지 · R1-7-9).
import io
src = io.open('/workspace/05_SV-Agent_ai/05_25_SV_DDL_CAMPAIGN_MONTHLY.sql', encoding='utf-8').read().split('\n')
start = next(i for i, l in enumerate(src) if l.startswith("  AI_SQL_GENERATION '"))
common = src[start] + '\n' + src[start + 1]
assert common.count('[O241-R') == 1 and common.count('[O216') == 1
p = '/workspace/05_SV-Agent_ai/05_31_SV_DDL_MKTG_CAMPAIGN_COST.sql'
t = io.open(p, encoding='utf-8').read()
assert t.count('  @@COMMON@@\n') == 1
t = t.replace('  @@COMMON@@\n', common + '\n')
io.open(p, 'w', encoding='utf-8').write(t)
print('ok', len(common))
