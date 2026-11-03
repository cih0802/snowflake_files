"""O213 — 정본 DDL 파일에서 지정 객체의 CREATE 문 1개를 잘라 출력(배포용 · 실행은 SQL 도구로)."""
import io, re, sys

path, start_pat, out = sys.argv[1], sys.argv[2], sys.argv[3]
t = io.open(path, encoding="utf-8").read()
i = t.index(start_pat)
# 문장 끝 = 따옴표 밖의 첫 ';'
q, j = False, i
while j < len(t):
    ch = t[j]
    if ch == "'":
        q = not q
    elif ch == ";" and not q:
        break
    j += 1
stmt = t[i:j]
io.open(out, "w", encoding="utf-8").write(stmt)
print(len(stmt), "chars", stmt.count("\n") + 1, "lines")
