#!/usr/bin/env python3
"""생성된 Cortex Analyst SQL 실행 검증 스크립트"""

import json
import subprocess

with open("/tmp/cortex_30_result.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print(f"=== 생성된 SQL Live 실행 검증 (총 {len(data)}건 중 PASS 건) ===")
pass_cnt = 0
exec_pass_cnt = 0
exec_fail_cnt = 0

for idx, item in enumerate(data, 1):
    if item["status"] != "PASS":
        print(f"[{idx:02d}] ⏭️ SKIP [{item['agent']}|{item['id']}] (SQL 미생성)")
        continue
    pass_cnt += 1
    sql = item["detail"]
    # Snowflake CLI or python Snowflake connector via snow sql or snowpark
    # Here we can run snowflake sql via cortex / snow sql
    # Let's save sql to temp file and run snow sql or python
    with open("/tmp/temp_query.sql", "w", encoding="utf-8") as sf:
        sf.write(sql)
    
    cmd = ["snow", "sql", "-f", "/tmp/temp_query.sql"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if proc.returncode == 0:
            exec_pass_cnt += 1
            print(f"[{idx:02d}] 🟢 EXEC OK [{item['agent']}|{item['id']}] {item['question'][:25]}...")
        else:
            exec_fail_cnt += 1
            err_msg = proc.stderr.strip() or proc.stdout.strip()
            print(f"[{idx:02d}] 🔴 EXEC FAIL [{item['agent']}|{item['id']}] {item['question'][:25]}... -> {err_msg[:80]}")
    except Exception as e:
        exec_fail_cnt += 1
        print(f"[{idx:02d}] 🔴 EXEC ERROR: {e}")

print(f"\n=== Live 실행 요약 ===")
print(f"총 검증 {pass_cnt}건 중 실행 성공: {exec_pass_cnt}건, 실행 실패: {exec_fail_cnt}건")
