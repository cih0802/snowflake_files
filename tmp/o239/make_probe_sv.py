import sys
src = open('/workspace/05_SV-Agent_ai/05_26_SV_DDL_GA_CHILD_UNPAID.sql', encoding='utf-8').read()
s = src.index('CREATE OR ALTER SEMANTIC VIEW')
e = src.index(');', src.index('AI_VERIFIED_QUERIES')) + 2
body = (src[s:e]
        .replace('GN_DW.SERVING.SV_GA_CHILD_UNPAID', 'GN_DW.OPS.O239_PROBE_SV')
        .replace('GN_DW.GOLD.FACT_GA_CHILD_VIEW', 'GN_DW.OPS.O239_PROBE_GCV')
        .replace('GN_DW.GOLD.FACT_UNPAID_SERVICE_CONV', 'GN_DW.OPS.O239_PROBE_USC'))
open('/workspace/tmp/o239/probe_sv.sql', 'w', encoding='utf-8').write(body)
print(len(body))
