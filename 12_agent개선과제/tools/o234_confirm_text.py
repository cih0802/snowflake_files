# O234 — LTV 현업 확정(상한 80 + 무기한 · 전체 이력 · 재후원 포함 · 셀 최소 1) 문안 일괄 치환
# 대상 = 06_DDL · dbt yml · 모델 주석 · dbt_project.yml · 각 치환은 기대 건수와 다르면 쓰지 않고 중단한다
# Co-authored with CoCo
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
F = "확정(O234 현업 회신: 상한 80 + 무기한 · 전체 이력 · 재후원 포함 · 셀 최소 1)"

PLAN = {
    "03_top-down_gold/06_DDL.sql": [
        ("-- [O231] LTV 생존분석 입력(잠정 정의)", "-- [O231 · O234 확정] LTV 생존분석 입력", 1),
        ("[잠정 정의 · O231]", "[O231 · O234 확정]", 3),
        ("[잠정 정의 · O233]", "[O233 · O234 확정]", 3),
        ("(LTV 기대 유지개월 · 🟠 잠정 정의)", "(LTV 기대 유지개월 · " + F + ")", 1),
        ("COMMENT '[잠정] 이 행이 상한 N개월의", "COMMENT '[O234 확정 · 상한 80 + 무기한] 이 행이 상한 N개월의", 1),
        ("생존 곡선 팩트(🟠 잠정 정의 · 현업 확인 전).", "생존 곡선 팩트(" + F + ").", 1),
    ],
    "10_dbt_pipeline/models/gold/_gold_ready_schema.yml": [
        ("# 🆕 [O231 · 잠정 정의] LTV", "# 🆕 [O231 · O234 확정] LTV", 1),
        ("# 🆕 [O233 · 잠정 정의] 최종", "# 🆕 [O233 · O234 확정] 최종", 1),
        ('description: "[잠정] ', 'description: "[O234 확정] ', 7),
        ("생존 곡선(🟠 잠정 정의 · 종전", "생존 곡선(O234 확정 · 종전", 1),
        ('description: "[잠정 정의 · 현업 확인 전] 획득', 'description: "[' + F + '] 획득', 1),
        ("행이면 N · 아니면 NULL. 상한 목록 = dbt var ltv_caps\"",
         "행이면 N · 셀 최대 관측월 행이면 9999(무기한 · 관측 최대까지) · 아니면 NULL. 상한 목록 = dbt var ltv_caps(80) · 9999 = ltv_unlimited\"", 1),
    ],
    "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_COHORT.sql": [
        ("[O233 · 잠정 정의 · 현업 회신", "[O233 · O234 확정 · 현업 회신", 1),
        ("[O231 · 잠정 정의] LTV", "[O231 · O234 확정] LTV", 1),
        ("[O233 · 잠정 정의] 최종", "[O233 · O234 확정] 최종", 1),
    ],
    "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_COHORT_SURVIVAL.sql": [
        ("O232 · 🟠 잠정 정의 — 현업 확인 전]", "O232 · O234 " + F + "]", 1),
    ],
    "10_dbt_pipeline/dbt_project.yml": [
        ("[O231 · 잠정 정의] LTV 생존분석", "[O231 · O234 확정] LTV 생존분석", 1),
    ],
}


def main():
    dry = "--apply" not in sys.argv
    bad = 0
    for rel, subs in PLAN.items():
        p = os.path.join(ROOT, rel)
        s = io.open(p, encoding="utf-8").read()
        for a, b, n in subs:
            c = s.count(a)
            print("%-55s %s %d/%d" % (rel[-55:], "OK" if c == n else "MISMATCH", c, n))
            if c != n:
                bad += 1
            s = s.replace(a, b)
        if not dry and not bad:
            io.open(p, "w", encoding="utf-8").write(s)
    if bad:
        sys.exit("불일치 %d — 쓰지 않음" % bad)
    print("dry-run" if dry else "applied")


if __name__ == "__main__":
    main()
