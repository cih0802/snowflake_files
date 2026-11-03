"""O259 요건 2 — SV 지시문·VQR 에서 ROLLUP 소계/합계 행 제거.

기대 건수가 하나라도 어긋나면 아무 파일도 쓰지 않는다(전부 아니면 전무).
쓰기 직전 파일을 다시 읽어 SHA256 이 첫 독해와 같을 때만 쓴다(R1-7-2).
"""
import hashlib, io, os, sys

ROOT = "/workspace/05_SV-Agent_ai"
TARGETS = sorted(
    f for f in os.listdir(ROOT)
    if f.endswith(".sql") and (f.startswith("05_") or f[:3] in ("22_", "25_", "34_"))
)

BAN = "단 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만)"
SEP = "전체 합이 필요하면 같은 조건의 별도 집계 쿼리(그룹 없음)로 내고 답변 표 밖 본문 1줄로 적는다"

RULES = [
    ("R1",
     "[O206-C 합계 규칙] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행(또는 같은 조건의 별도 집계 쿼리)을 반환한다.",
     "[O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계·연간 합계·분모(전체 대상 수)는 반드시 SQL 이 낸다 — " + BAN + ". " + SEP + ". 비율은 분자·분모 measure 를 열로 함께 낸다.",
     31),
    ("R2",
     "[O206-C 합계 규칙] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다",
     "[O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — " + BAN + ". " + SEP,
     5),
    ("R2b",
     "(고유 세션·방문자수 합계는 ROLLUP 이 다시 세므로 그룹 합과 다를 수 있다 — 그 차이를 밝힌다)",
     "(고유 세션·방문자수 전체는 별도 집계가 다시 세므로 그룹 합과 다를 수 있다 — 그 차이를 밝힌다)",
     1),
    ("R3",
     "합계·분모는 SQL 이 낸다 — GROUP BY ROLLUP 합계 행을 함께 반환하고, 합계 행에는 COALESCE(차원, ''(미매칭)'') 를 씌우지 않는다(CASE WHEN GROUPING(차원) = 1 THEN ''전체 합계'' WHEN 차원 IS NULL THEN ''(미매칭)'' ELSE 차원 END).",
     "합계·분모는 SQL 이 낸다 — " + BAN + " · O259). " + SEP + ". 차원 NULL 은 COALESCE(차원, ''(미매칭)'') 로 표시한다.",
     1),
    ("R4",
     "🆕 [O245] ROLLUP 합계 행에는 COALESCE(차원, (미매칭)) 를 씌우지 않는다 — CASE WHEN GROUPING(차원) = 1 THEN 전체 합계 WHEN 차원 IS NULL THEN (미매칭) ELSE 차원 END 로 구분한다.",
     "🆕 [O245 · O259 개정] 합계 행을 만들지 않으므로 차원 NULL 은 COALESCE(차원, (미매칭)) 로 표시한다.",
     6),
    ("R5", "GROUP BY ROLLUP((연,월)) 반환", "연·월 평면 GROUP BY 로 반환(합계 행 없음)", 7),
    ("R6", "ROLLUP 과 함께", "그룹 행으로 함께", 3),
    ("R7", "ROLLUP 전체 행을 붙인다", "전체 합 행은 붙이지 않는다(필요하면 별도 집계 · 표 밖 본문 1줄)", 2),
    ("R8", "ROLLUP 전체 행을 낸다", "전체 합 행은 붙이지 않는다(필요하면 별도 집계 · 표 밖 본문 1줄)", 2),
    ("R9", "(전체 ROLLUP 행·합계는 제외 없이 그대로)", "(별도 집계한 전체 합계는 제외 없이 그대로)", 1),
    ("R10", "ROLLUP 전체를 함께 낸다", "전체 합은 별도 집계로 낸다(표에 행으로 붙이지 않는다)", 1),
    ("R11",
     "[O206-C 합계 규칙] 답변에 쓸 합계·분모는 반드시 SQL 이 낸다 — 중복제거",
     "[O206-C 합계 규칙 · O259 개정] 답변에 쓸 합계·분모는 반드시 SQL 이 낸다 — 표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지). 중복제거",
     1),
    # VQR SQL
    ("V07", "GROUP BY ROLLUP(COALESCE(ad.AD_CTGR_NM, ''(귀속 없음)''))", "GROUP BY COALESCE(ad.AD_CTGR_NM, ''(귀속 없음)'')", 1),
    ("V08a", "SELECT COALESCE(CUR_DEPARTMENT, ''전체'') AS \"현재 부서\"", "SELECT COALESCE(CUR_DEPARTMENT, ''(미매핑)'') AS \"현재 부서\"", 2),
    ("V08b", "GROUP BY ROLLUP (org_succ.CUR_DEPARTMENT)) ORDER BY CUR_DEPARTMENT IS NULL DESC, ", "GROUP BY org_succ.CUR_DEPARTMENT) ORDER BY ", 2),
    ("V10a", "COALESCE(CUR_ORG_PATH, ''전체'')", "COALESCE(CUR_ORG_PATH, ''(미매핑)'')", 1),
    ("V10b", "GROUP BY ROLLUP (org_succ.CUR_ORG_PATH)) ORDER BY CUR_ORG_PATH IS NULL DESC, ", "GROUP BY org_succ.CUR_ORG_PATH) ORDER BY ", 1),
    ("V19", "GROUP BY ROLLUP(pbs.RQEST_DIV_NAME, pbs.RQEST_DIV_CD) ORDER BY 3 DESC NULLS FIRST", "GROUP BY pbs.RQEST_DIV_NAME, pbs.RQEST_DIV_CD ORDER BY 3 DESC NULLS LAST", 1),
    ("V20", "GROUP BY ROLLUP(gs.UP_DONOR_TYPE)", "GROUP BY gs.UP_DONOR_TYPE", 1),
    ("V22", "GROUP BY ROLLUP(demo.USER_GENDER)", "GROUP BY demo.USER_GENDER", 1),
    ("V24", "GROUP BY ROLLUP (campaign.CAMPAIGN_NAME) ORDER BY CUM_STOP DESC NULLS FIRST) ORDER BY CUM_STOP DESC NULLS FIRST", "GROUP BY campaign.CAMPAIGN_NAME) ORDER BY CUM_STOP DESC NULLS LAST", 1),
    ("V25", "GROUP BY ROLLUP (campaign.CAMPAIGN_NAME) ORDER BY ACTIVE_CNT_SUM DESC NULLS FIRST) ORDER BY ACTIVE_CNT_SUM DESC NULLS FIRST", "GROUP BY campaign.CAMPAIGN_NAME) ORDER BY ACTIVE_CNT_SUM DESC NULLS LAST", 1),
    ("V26a", "GROUP BY ROLLUP(usc.CLICK_MONTH_KEY)", "GROUP BY usc.CLICK_MONTH_KEY", 1),
    ("V26b", "GROUP BY ROLLUP(date.YEAR)", "GROUP BY date.YEAR", 1),
]


def sha(b):
    return hashlib.sha256(b).hexdigest()


orig = {}
for f in TARGETS:
    p = os.path.join(ROOT, f)
    with open(p, "rb") as h:
        orig[f] = h.read()

new = {f: orig[f].decode("utf-8") for f in TARGETS}
report = []
bad = False
for rid, old, rep, want in RULES:
    got = 0
    files = []
    for f in TARGETS:
        n = new[f].count(old)
        if n:
            got += n
            files.append("%s×%d" % (f[:5], n))
            new[f] = new[f].replace(old, rep)
    ok = got == want
    bad |= not ok
    report.append("%s %s got=%d want=%d %s" % ("OK " if ok else "BAD", rid, got, want, " ".join(files)))

print("\n".join(report))
if bad or "--apply" not in sys.argv:
    print("DRY-RUN" if not bad else "ABORT — 기대 건수 불일치 · 쓰기 0")
    sys.exit(1 if bad else 0)

changed = 0
for f in TARGETS:
    if new[f] == orig[f].decode("utf-8"):
        continue
    p = os.path.join(ROOT, f)
    with open(p, "rb") as h:
        now = h.read()
    if sha(now) != sha(orig[f]):
        print("ABORT — 해시 변동", f)
        sys.exit(2)
    with open(p, "wb") as h:
        h.write(new[f].encode("utf-8"))
    with open(p, "rb") as h:
        back = h.read()
    assert back == new[f].encode("utf-8"), f
    changed += 1
    print("WROTE", f, sha(orig[f])[:12], "->", sha(back)[:12])
print("changed files =", changed)
