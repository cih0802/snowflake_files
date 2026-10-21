#!/usr/bin/env python3
"""O250 · 36_ DDL 을 문장 파일 tmp/o250/stmt1~4.sql 로 다시 나눈다(뷰 2 · SV 2)."""
import re

t = open("/workspace/05_SV-Agent_ai/36_O250_ML예측_7축확장.sql", encoding="utf-8").read()
body = t.split("USE SCHEMA GN_DW.SERVING;", 1)[1]
parts = re.split(r"\n(?=CREATE OR REPLACE VIEW|CREATE OR ALTER SEMANTIC VIEW|-- ▣ 5\. GRANT)", body)
for i, p in enumerate(parts):
    p = p.strip()
    if p.startswith("CREATE"):
        p = p[:p.rfind(";") + 1]
        open(f"/workspace/tmp/o250/stmt{i}.sql", "w", encoding="utf-8").write(p)
        print(i, p[:60].replace("\n", " "), len(p))
