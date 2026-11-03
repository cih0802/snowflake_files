"""O259 요건 2 — 2차 교정: 「별도 집계 쿼리」→「같은 SELECT 의 전체 합 열」(O241-T 1회 호출 원칙과 정합).

기대 건수 불일치 시 쓰기 0 · 쓰기 직전 해시 재대조.
"""
import glob, hashlib, io, os, sys

SV = "/workspace/05_SV-Agent_ai"
FILES = sorted(
    os.path.join(SV, f) for f in os.listdir(SV)
    if f.endswith(".sql") and (f.startswith("05_") or f[:3] in ("22_", "25_", "34_"))
) + sorted(glob.glob("/workspace/cortex_project/agents/*/agent_spec.yaml"))

COL = ("전체 합이 필요하면 행이 아니라 같은 SELECT 의 열로 붙인다"
       "(SUM(SUM(x)) OVER () · COUNT DISTINCT·HAVING 이 있으면 그룹 없는 CTE 를 CROSS JOIN) — "
       "답변에서는 그 열을 표에 싣지 않고 표 밖 본문 1줄로 적는다")
RULES = [
    ("S1", "전체 합이 필요하면 같은 조건의 별도 집계 쿼리(그룹 없음)로 내고 답변 표 밖 본문 1줄로 적는다", COL, 37),
    ("S2", "(필요하면 별도 집계 · 표 밖 본문 1줄)", "(필요하면 전체 합 열 · 표 밖 본문 1줄)", 4),
    ("S3", "(별도 집계한 전체 합계는 제외 없이 그대로)", "(전체 합은 HAVING 전 값이어야 하므로 그룹 없는 CTE 로 낸다 · 제외 없이 그대로)", 1),
    ("S4", "전체 합은 별도 집계로 낸다(표에 행으로 붙이지 않는다)", "전체 합은 열로 낸다(표에 행으로 붙이지 않는다)", 1),
    ("S5", "(고유 세션·방문자수 전체는 별도 집계가 다시 세므로", "(고유 세션·방문자수 전체는 그룹 없는 CTE 가 다시 세므로", 1),
    ("A1",
     "합계·총계·누계는 도구 결과의 셀(그룹 없이 같은 조건으로 집계한 결과)을 그대로 쓴다. 표의 값을 답변 작성 중에 직접 더하거나 암산하지 않는다 — 합계가 필요한데 결과에 없으면 그룹 없이 같은 조건으로 도구를 한 번 더 호출한다.",
     "합계·총계·누계는 도구 결과의 셀(전체 합 열)을 그대로 쓴다. 표의 값을 답변 작성 중에 직접 더하거나 암산하지 않는다 — 합계가 필요하면 처음 질의부터 전체 합을 열로 함께 요청한다(O241-T 1회 호출).",
     3),
    ("A2", "· 전체 합은 별도 집계)", "· 전체 합은 열)", 2),
    ("A3", "(ROLLUP·CASE·조건부 집계)", "(CASE·조건부 집계·전체 합 열)", 3),
]
orig = {p: open(p, "rb").read() for p in FILES}
new = {p: orig[p].decode("utf-8") for p in FILES}
bad = False
for rid, old, rep, want in RULES:
    got = sum(new[p].count(old) for p in FILES)
    for p in FILES:
        new[p] = new[p].replace(old, rep)
    print(("OK " if got == want else "BAD"), rid, got, want)
    bad |= got != want
if bad or "--apply" not in sys.argv:
    sys.exit(1 if bad else 0)
n = 0
for p in FILES:
    if new[p].encode("utf-8") == orig[p]:
        continue
    if hashlib.sha256(open(p, "rb").read()).digest() != hashlib.sha256(orig[p]).digest():
        sys.exit("ABORT hash " + p)
    open(p, "wb").write(new[p].encode("utf-8"))
    assert open(p, "rb").read() == new[p].encode("utf-8")
    n += 1
print("changed files =", n)
