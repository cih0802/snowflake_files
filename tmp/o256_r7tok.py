"""O256-B — 05_10 규칙7 라이브 위반 토큰과 주변 문맥(읽기 전용)."""
import re, sys
sys.path.insert(0, "/workspace/scripts")
import sv_rule7_scan as R
P = "/workspace/05_SV-Agent_ai/05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql"
t = open(P, encoding="utf-8").read()
for m in re.finditer(r"COMMENT\s*=\s*'((?:[^']|'')*)'|AI_SQL_GENERATION\s*'((?:[^']|'')*)'", t, re.S):
    s = m.group(1) or m.group(2) or ""
    for name, tok, pos in R.violations(s):
        ln = t[:m.start()].count("\n") + 1
        print(f"line~{ln} 축={name} 토큰={tok!r}")
        print("   …", s[max(0, pos - 120):pos + 80].replace("\n", " "), "…")
