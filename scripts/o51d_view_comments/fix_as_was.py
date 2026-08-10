# -*- coding: utf-8 -*-
"""[2026-08-07 O51-D-B] `(as-was)` 표기 일괄 교정 — 전 schema.yml 대상.
🔴 DIM_ORG 는 DEC-2(2026-07-07)에서 **SCD1 확정**됐다. `(as-was)` 는 SCD2 시절 잔재이며 **거짓**이다.
   `10_WIDE VIEW 코멘트.sql` 헤더가 2026-07-07 에 이미 이 사실을 적었는데도 본문 문안은 그대로 남아
   O51-C 에서 **3뷰(WIDE_TARGET_DEV·WIDE_TARGET_BIZ·WIDE_BUDGET)의 물리 COMMENT 로 실제 배포됐다**
   ⇒ P62-B(자기교정은 전파되지 않는다)의 물리 계층 실증. 멱등이므로 반복 실행 가능."""
import io, sys
sys.path.insert(0,'/workspace/scripts/o51d_view_comments')
from build_yml import TRANSFER_FIX

FILES = ['/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml',
         '/workspace/10_dbt_pipeline/models/gold/_gold_ready_schema.yml']
total = 0
for f in FILES:
    t = io.open(f, encoding='utf-8').read(); n = 0
    for a, b in TRANSFER_FIX:
        cnt = t.count(f'description: "{a}"')
        if cnt:
            t = t.replace(f'description: "{a}"', f'description: "{b}"'); n += cnt
    if n: io.open(f,'w',encoding='utf-8').write(t)
    print(f"{f.split('/')[-1]}: {n}건 교정"); total += n
print(f"합 {total}건")
