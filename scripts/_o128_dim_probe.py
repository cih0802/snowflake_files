# O128 착수표 ㊲ 실측 — DIM 측 고립 후보 10건의 성격을 분류 전에 실측한다.
# Co-authored with CoCo
#
# 🔴 분류(CONFORM / DEGEN / SELFREF)를 적기 전에 실측한다 — 사유를 잘못 적으면
#   conform 축이 ERD 에서 영구히 사라진다(gold_erd_coverage_gate 의 자기경고).
# 판정 축 두 개를 함께 낸다:
#   ㉠ 제안한 부모로 100% 해소되는가(그렇다면 실재하는 참조다)
#   ㉡ 그 컬럼이 자기 테이블의 grain 키인가(그렇다면 FK 가 아니라 자연키다)

import os
import sys

ROOT = "/workspace"
sys.path.insert(0, os.path.join(ROOT, "scripts"))

# (자식, 컬럼, 제안 부모, 부모 컬럼) — 🔴 제안이지 판정이 아니다.
CANDIDATES = [
    ("DIM_DATE",               "MONTH_KEY",          "DIM_MONTH",       "MONTH_KEY"),
    ("DIM_MEMBER",             "MEMBER_DK",          "DIM_MEMBER",      "MEMBER_DK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_CAMPAIGN_SK",    "DIM_CAMPAIGN",    "CAMPAIGN_SK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_DATE_SK",        "DIM_DATE",        "DATE_SK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_ORG_SK",         "DIM_ORG",         "ORG_SK"),
    ("DIM_MEMBER_ACQUISITION", "ACQ_SPONSORSHIP_SK", "DIM_SPONSORSHIP", "SPONSORSHIP_SK"),
    ("DIM_MEMBER_ACQUISITION", "FIRST_STOP_DATE_SK", "DIM_DATE",        "DATE_SK"),
    ("DIM_MEMBER_CURRENT",     "MEMBER_SK",          "DIM_MEMBER",      "MEMBER_SK"),
    ("DIM_MEMBER_IDENTITY",    "MEMBER_DK",          "DIM_MEMBER",      "MEMBER_DK"),
    ("DIM_ORG",                "ORG_DK",             "DIM_ORG",         "ORG_DK"),
]

BLOCK = """
SELECT '{child}.{col}' AS AXIS,
       COUNT(*) AS CHILD_ROWS,
       COUNT({col}) AS NOT_NULL_ROWS,
       COUNT(DISTINCT {col}) AS DISTINCT_VALS,
       (SELECT COUNT(*) FROM GN_DW.GOLD.{child} c2
         WHERE c2.{col} IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM GN_DW.GOLD.{parent} p
                            WHERE p.{pcol} = c2.{col})) AS UNRESOLVED_ROWS
  FROM GN_DW.GOLD.{child}
"""


def main():
    sql = "\nUNION ALL\n".join(
        BLOCK.format(child=a, col=b, parent=c, pcol=d) for a, b, c, d in CANDIDATES)

    import sfconn
    cn = sfconn.conn()
    try:
        cur = cn.cursor()
        cur.execute(sql)
        rows = {r[0]: r for r in cur.fetchall()}
    finally:
        cn.close()

    def f(v):
        return format(v, ",") if v is not None else "NULL"

    print("%-44s %12s %12s %12s %12s %s"
          % ("축", "자식행", "NOTNULL", "distinct", "미해소행", "grain키?"))
    for a, b, c, d in CANDIDATES:
        key = "%s.%s" % (a, b)
        r = rows[key]
        # ㉡ grain 키 판정 = distinct == 자식 행 수(자기 테이블에서 유일하다)
        grain = "🟢 유일(자연키 후보)" if r[2] and r[2] == r[3] else "— 비유일(참조 후보)"
        print("%-44s %12s %12s %12s %12s %s"
              % ("%s → %s.%s" % (key, c, d), f(r[1]), f(r[2]), f(r[3]),
                 f(r[4]), grain))
    return 0


if __name__ == "__main__":
    sys.exit(main())
