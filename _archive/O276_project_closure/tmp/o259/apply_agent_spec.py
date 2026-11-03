"""O259 요건 2 — Agent spec(정본 3종) 합계 규칙에서 ROLLUP 합계 행 전제 제거. 기대 건수 불일치 시 쓰기 0."""
import glob, hashlib, sys

FILES = sorted(glob.glob("/workspace/cortex_project/agents/*/agent_spec.yaml"))
RULES = [
    ("A1",
     "**합계 규칙(O198)**: 합계·총계·누계는 도구 결과의 합계 행(또는 SQL 의 SUM·ROLLUP 결과)을 그대로 쓴다. 표의 값을 답변 작성 중에 직접 더하거나 암산하지 않는다 — 합계가 필요한데 결과에 없으면 합계를 포함하도록 도구를 다시 호출한다.",
     "**합계 규칙(O198 · O259 개정)**: 합계·총계·누계는 도구 결과의 셀(그룹 없이 같은 조건으로 집계한 결과)을 그대로 쓴다. 표의 값을 답변 작성 중에 직접 더하거나 암산하지 않는다 — 합계가 필요한데 결과에 없으면 그룹 없이 같은 조건으로 도구를 한 번 더 호출한다. 🆕 [O259] 표에는 합계·소계 행을 넣지 않는다 — 전체 합은 표 밖 본문 1줄로 적는다.",
     3),
    ("A2", "같은 도구 안에서 필터·기간·ROLLUP 조합", "같은 도구 안에서 필터·기간·그룹 조합", 3),
    ("A3", "분자·분모 함께 · ROLLUP 전체)", "분자·분모 함께 · 전체 합은 별도 집계)", 2),
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
for p in FILES:
    if new[p].encode("utf-8") == orig[p]:
        continue
    if hashlib.sha256(open(p, "rb").read()).digest() != hashlib.sha256(orig[p]).digest():
        sys.exit("ABORT hash " + p)
    open(p, "wb").write(new[p].encode("utf-8"))
    assert open(p, "rb").read() == new[p].encode("utf-8")
    print("WROTE", p)
left = sum(new[p].upper().count("ROLLUP") for p in FILES)
print("residual ROLLUP tokens =", left)
