# O268 — 운영계 LLM 실행카드 경로·블록 실재 대조(임시 · 근거 파일은 tmp/o268/card_check.out)
import os
import re
import sys

sys.path.insert(0, '/workspace/scripts')
import run_sql_block as R

card = open('/workspace/문서실행순서_운영계_LLM실행카드.md', encoding='utf-8').read()
paths = sorted(set(re.findall(r'`((?:05_SV-Agent_ai|15_MSTR[^`]*|10_dbt_pipeline|scripts|04_silver_design|60_repeat_[^`/]*)/[^`]+?\.(?:sql|py|md))`', card)))
bad = 0
for p in paths:
    ok = os.path.isfile('/workspace/' + p)
    bad += not ok
    print(('OK  ' if ok else 'MISS') + ' ' + p)
for f, blk in re.findall(r'블록 `([^`]+\.sql)` · `([^`]+)`', card):
    names = [b for b, _ in R.split_blocks(open('/workspace/' + f, encoding='utf-8').read())]
    miss = [b for b in blk.split(',') if b not in names]
    bad += bool(miss)
    print(('OK  ' if not miss else 'MISS') + f' 블록 {f} {blk} {miss or ""}')
for f, blk in re.findall(r'블록 같은 파일(?:\((\d+)\))? · `([^`]+)`', card):
    print('INFO 같은 파일 참조', f or '(직전)', blk)
print('BAD', bad)
sys.exit(1 if bad else 0)
