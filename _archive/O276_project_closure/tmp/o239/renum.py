import re
p = '/workspace/문서실행순서_보조주석.md'
lines = open(p, encoding='utf-8').read().split('\n')
out = []
for l in lines:
    m = re.match(r'^\| (\d+) \| (`[^`]+`)', l)
    if m and int(m.group(1)) >= 47 and int(m.group(1)) <= 54 and '05_' not in m.group(2)[:5]:
        l = '| %d |%s' % (int(m.group(1)) + 1, l[len('| ' + m.group(1) + ' |'):])
    out.append(l)
    if l.startswith('| 46 | `05_25_SV_DDL_CAMPAIGN_MONTHLY.sql`'):
        out.append('| 47 | `05_26_SV_DDL_GA_CHILD_UNPAID.sql` | [O239] 결연아동코드(공#122)·미납서비스 전환율(공#81) SV(신규 · 추천안 A/B 병기 · 잠정) · 선행 = GOLD.FACT_GA_CHILD_VIEW · FACT_UNPAID_SERVICE_CONV(06_DDL·dbt build) · 🔴 09_2 전 필수(도구 analyst_ga_child_unpaid) · 개발계 덧입히기 = `05_SV-Agent_ai/29_O239_G1잔여_배포순서.sql` |')
open(p, 'w', encoding='utf-8').write('\n'.join(out))
print('ok')
