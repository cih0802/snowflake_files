# O217-B — SQL 파일 실행기(세미콜론 분리 · 문자열 리터럴 안의 ; 보존 · 문별 결과 1줄)
# 사용법: python3 run_sql_file.py <file.sql> [--from N]
# Co-authored with CoCo
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from o217_agent_io import session  # noqa: E402


def split(sql):
    out, buf, q, i = [], [], False, 0
    lines = [l for l in sql.splitlines() if not l.lstrip().startswith("--") or q]
    s = "\n".join(lines)
    while i < len(s):
        c = s[i]
        if c == "'" and q and i + 1 < len(s) and s[i + 1] == "'":
            buf.append("''"); i += 2; continue
        if c == "'":
            q = not q
        if c == ";" and not q:
            t = "".join(buf).strip()
            if t:
                out.append(t)
            buf = []
        else:
            buf.append(c)
        i += 1
    t = "".join(buf).strip()
    if t:
        out.append(t)
    return out


def main():
    p = sys.argv[1]
    start = int(sys.argv[sys.argv.index("--from") + 1]) if "--from" in sys.argv else 1
    stmts = split(open(p, encoding="utf-8").read())
    s = session()
    for n, st in enumerate(stmts, 1):
        if n < start:
            continue
        head = " ".join(st.split())[:90]
        try:
            r = s.sql(st).collect()
            print("%d OK  %s · %d행" % (n, head, len(r)))
            for x in r[:12]:
                d = x.as_dict()
                keep = {k: v for k, v in d.items() if k in ("name", "is_default") or not st.upper().startswith("SHOW")}
                print("     ", str(keep)[:300])
        except Exception as e:  # noqa: BLE001
            print("%d ERR %s → %s" % (n, head, str(e)[:500]))
            sys.exit(1)


if __name__ == "__main__":
    main()
