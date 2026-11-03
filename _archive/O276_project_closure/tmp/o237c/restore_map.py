import io, hashlib, sys
P = "/workspace/12_agent개선과제/tools/o237_build_formula_map.py"
T = "/workspace/tmp/o237c/o237_map_tail.txt"
src = io.open(P, encoding="utf-8").read()
lines = src.split("\n")
# 잘린 마지막 줄(406행 조각) 앞까지만 유지 — 앵커 assert
assert lines[404].startswith('    "🆕 5일·30일 두 창을 함께 낸다'), lines[404]
assert lines[405] == '    " 🔴 클릭일 기준 D+1~5 · D+1~30 · 문자(', repr(lines[405])
keep = "\n".join(lines[:405]) + "\n"
tail = io.open(T, encoding="utf-8").read()
out = keep + tail
io.open(P, "w", encoding="utf-8", newline="").write(out)
back = io.open(P, encoding="utf-8").read()
assert back == out, "readback mismatch"
print("lines", back.count("\n"), "sha", hashlib.sha256(back.encode("utf-8")).hexdigest())
