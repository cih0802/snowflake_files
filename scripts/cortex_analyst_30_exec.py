#!/usr/bin/env python3
"""생성된 Cortex Analyst SQL 실행 검증 스크립트"""

import json
import os
import sys

sys.path.insert(0, '/workspace/scripts')
import sfconn

with open("/tmp/cortex_30_result.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print(f"=== 생성된 SQL Live 실행 검증 (총 {len(data)}건 중 PASS 건) ===")
pass_cnt = 0
exec_pass_cnt = 0
exec_fail_cnt = 0

cn = sfconn.conn()
cur = cn.cursor()

for idx, item in enumerate(data, 1):
    if item["status"] != "PASS":
        print(f"[{idx:02d}] ⏭️ SKIP [{item['agent']}|{item['id']}] (SQL 미생성)")
        continue
    pass_cnt += 1
    sql = item["detail"]
    try:
        cur.execute(sql)
        rows = cur.fetchall()
        exec_pass_cnt += 1
        print(f"[{idx:02d}] 🟢 EXEC OK ({len(rows)}행) [{item['agent']}|{item['id']}] {item['question'][:25]}...")
    except Exception as e:
        exec_fail_cnt += 1
        err_msg = str(e).strip().replace('\n', ' ')
        print(f"[{idx:02d}] 🔴 EXEC FAIL [{item['agent']}|{item['id']}] {item['question'][:25]}... -> {err_msg[:80]}")

print(f"\n=== Live 실행 요약 ===")
print(f"총 검증 {pass_cnt}건 중 실행 성공: {exec_pass_cnt}건, 실행 실패: {exec_fail_cnt}건")
