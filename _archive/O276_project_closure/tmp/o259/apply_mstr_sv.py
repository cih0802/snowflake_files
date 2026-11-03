"""O259 요건 2 — MSTR SV 정본에 같은 개정 적용(기대 건수 불일치 시 쓰기 0)."""
import hashlib, io, sys
P = "/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql"
COL = ("전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다"
       "(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — "
       "답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다")
BAN = "단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만)"
RULES = [
    ("[O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다.",
     "[O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — " + BAN + ". " + COL + ". 비율은 분자·분모 measure 를 열로 함께 낸다.", 1),
    ("GROUP BY ROLLUP(ye.DEPT4_NM) ORDER BY 6 DESC NULLS FIRST", "GROUP BY ye.DEPT4_NM ORDER BY 6 DESC NULLS LAST", 1),
    ("GROUP BY ROLLUP(gl.STRD_MT) ORDER BY 1 NULLS LAST", "GROUP BY gl.STRD_MT ORDER BY 1", 1),
]
raw = open(P, "rb").read()
t = raw.decode("utf-8")
for old, new, want in RULES:
    got = t.count(old)
    print("OK " if got == want else "BAD", got, want, old[:40])
    if got != want:
        sys.exit(1)
    t = t.replace(old, new)
if "--apply" in sys.argv:
    if hashlib.sha256(open(P, "rb").read()).digest() != hashlib.sha256(raw).digest():
        sys.exit("ABORT hash")
    open(P, "wb").write(t.encode("utf-8"))
    assert open(P, "rb").read() == t.encode("utf-8")
    print("WROTE")
