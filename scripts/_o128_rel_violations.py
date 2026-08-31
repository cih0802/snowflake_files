# O128 착수표 ㉞ 실측 — 물리 FK 18축의 dbt relationships 위반 행 수를 선언 전에 센다.
# Co-authored with CoCo
#
# 판정식 = dbt relationships 와 동일 산식 = 자식 컬럼이 NOT NULL 인 행 중
#   부모 대상 컬럼에 없는 값의 행 수.
# 🔴 관측 축을 같은 표에 싣는다 = 자식 전체 행 수 · NOT NULL 행 수 · 미매칭 DISTINCT 값 수.
#   근거 = 0행 테이블은 「위반 0」이 공허하게 참이다(문서50 `E-6`)
#   ⇒ 「통과」를 「검증됨」으로 읽지 않기 위해 분모를 함께 낸다.

import os
import sys

ROOT = "/workspace"
sys.path.insert(0, os.path.join(ROOT, "scripts"))

AXES = [
    ("DIM_CAMPAIGN",        "MKTG_CAMPAIGN_SK",   "DIM_MARKETING_CAMPAIGN", "MKTG_CAMPAIGN_SK"),
    ("DIM_CAMPAIGN",        "ORG_SK",             "DIM_ORG",                "ORG_SK"),
    ("FACT_AD_PERFORMANCE", "CAMPAIGN_SK",        "DIM_CAMPAIGN",           "CAMPAIGN_SK"),
    ("FACT_AD_PERFORMANCE", "MKTG_CAMPAIGN_SK",   "DIM_MARKETING_CAMPAIGN", "MKTG_CAMPAIGN_SK"),
    ("FACT_AD_PERFORMANCE", "PERF_DATE_SK",       "DIM_DATE",               "DATE_SK"),
    ("FACT_BUDGET",         "CAMPAIGN_SK",        "DIM_CAMPAIGN",           "CAMPAIGN_SK"),
    ("FACT_BUDGET",         "ORG_SK",             "DIM_ORG",                "ORG_SK"),
    ("FACT_BUDGET",         "SPONSORSHIP_SK",     "DIM_SPONSORSHIP",        "SPONSORSHIP_SK"),
    ("FACT_BUDGET_YEARLY",  "CAMPAIGN_SK",        "DIM_CAMPAIGN",           "CAMPAIGN_SK"),
    ("FACT_BUDGET_YEARLY",  "ORG_SK",             "DIM_ORG",                "ORG_SK"),
    ("FACT_BUDGET_YEARLY",  "SPONSORSHIP_SK",     "DIM_SPONSORSHIP",        "SPONSORSHIP_SK"),
    ("FACT_MEMBER_COHORT",  "ACQ_ORG_SK",         "DIM_ORG",                "ORG_SK"),
    ("FACT_MEMBER_COHORT",  "ACQ_SPONSORSHIP_SK", "DIM_SPONSORSHIP",        "SPONSORSHIP_SK"),
    ("FACT_MEMBER_FEE",     "LAST_BILL_DATE_SK",  "DIM_DATE",               "DATE_SK"),
    ("FACT_MEMBER_FEE",     "LAST_PAY_DATE_SK",   "DIM_DATE",               "DATE_SK"),
    ("FACT_TARGET_BIZ",     "CAMPAIGN_SK",        "DIM_CAMPAIGN",           "CAMPAIGN_SK"),
    ("FACT_TARGET_BIZ",     "ORG_SK",             "DIM_ORG",                "ORG_SK"),
    ("FACT_TARGET_BIZ",     "SPONSORSHIP_SK",     "DIM_SPONSORSHIP",        "SPONSORSHIP_SK"),
]

BLOCK = """
SELECT '{child}' AS CHILD_TABLE,
       '{col}' AS CHILD_COL,
       '{parent}.{pcol}' AS PARENT_REF,
       COUNT(*) AS CHILD_ROWS,
       COUNT(c.{col}) AS NOT_NULL_ROWS,
       COUNT_IF(c.{col} IS NOT NULL AND p.{pcol} IS NULL) AS VIOLATION_ROWS,
       COUNT(DISTINCT CASE WHEN c.{col} IS NOT NULL AND p.{pcol} IS NULL
                           THEN c.{col} END) AS VIOLATION_DISTINCT
  FROM GN_DW.GOLD.{child} c
  LEFT JOIN GN_DW.GOLD.{parent} p
    ON p.{pcol} = c.{col}
"""


def main():
    sql = "\nUNION ALL\n".join(
        BLOCK.format(child=a, col=b, parent=c, pcol=d) for a, b, c, d in AXES)
    sql += "\nORDER BY CHILD_TABLE, CHILD_COL"

    import sfconn
    cn = sfconn.conn()
    try:
        cur = cn.cursor()
        cur.execute(sql)
        rows = cur.fetchall()
    finally:
        cn.close()

    hdr = ("자식테이블", "컬럼", "부모참조", "자식행", "NOTNULL", "위반행", "위반distinct")
    print("%-22s %-20s %-40s %12s %12s %10s %8s" % hdr)

    def f(v):
        return format(v, ",") if v is not None else "NULL"

    n_viol = 0
    n_empty = 0
    n_allnull = 0
    for r in rows:
        if r[5]:
            n_viol += 1
        if not r[3]:
            n_empty += 1
        elif not r[4]:
            n_allnull += 1
        print("%-22s %-20s %-40s %12s %12s %10s %8s"
              % (r[0], r[1], r[2], f(r[3]), f(r[4]), f(r[5]), f(r[6])))
    print()
    print("축 수 = %d · 위반 있는 축 = %d · 위반 0 인 축 = %d"
          % (len(rows), n_viol, len(rows) - n_viol))
    print("🔴 공허 통과 후보 — 자식 행 0 인 축 = %d · 자식 행은 있으나 컬럼 전건 NULL 인 축 = %d"
          % (n_empty, n_allnull))
    print("   ⇒ 이 축들의 「위반 0」은 「검증됨」이 아니다(분모가 비었다 · `O111 ㉠`).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
