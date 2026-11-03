#!/usr/bin/env python3
"""O159 임시 — 세션 트랜스크립트(JSONL) 요약 추출.

용도: 현재 세션(85844620)의 role/도구호출/응답 길이를 나열해
      자기검토(3단계)의 분모를 확정한다.
"""
import json
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/tr.json"

rows = []
with open(path, encoding="utf-8") as fh:
    for ln, line in enumerate(fh, 1):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append((ln, json.loads(line)))
        except json.JSONDecodeError as exc:
            print("PARSE_FAIL line", ln, exc)

print("총 JSONL 레코드 =", len(rows))
for ln, obj in rows:
    if not isinstance(obj, dict):
        print(ln, type(obj))
        continue
    role = obj.get("role") or obj.get("type") or "?"
    content = obj.get("content")
    tools = []
    text = ""
    if isinstance(content, list):
        for part in content:
            if not isinstance(part, dict):
                continue
            ptype = part.get("type")
            if ptype == "text":
                text += part.get("text", "")
            elif ptype in ("tool_use", "tool_call"):
                tools.append(str(part.get("name")))
            elif ptype in ("tool_result",):
                tools.append("RESULT")
    else:
        text = str(content or "")
    head = " ".join(text.split())[:220]
    print("---", ln, role, "chars=%d" % len(text), "tools=%s" % ",".join(tools))
    if head:
        print("   ", head)
