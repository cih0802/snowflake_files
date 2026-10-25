import io, sys
P = sys.argv[1]
R = [
 ("대상 81 테이블 CSV(GZIP) 언로드", "대상 80 테이블 CSV(GZIP) 언로드"),
 ("`BRONZE_GSC`(3) = **65 테이블** |",
  "`BRONZE_GSC`(2) = **64 테이블** (2026-10-23 · CRM `_TEST` 제외) |"),
 ("| 이관 총계 | **81 테이블** (브론즈 65 + SILVER 4 + ML 12) |",
  "| 이관 총계 | **80 테이블** (브론즈 64 + SILVER 4 + ML 12 · 2026-10-23) |"),
 ("**81 테이블**(CRM 53 + AGENCY 4 + ERP 3 + GA4 2 + GSC 3 + SILVER 4 + ML 12).",
  "**80 테이블**(CRM 53 + AGENCY 4 + ERP 3 + GA4 2 + GSC 2 + SILVER 4 + ML 12 · 2026-10-23)."),
 ("(**81** = 브론즈 65 + SILVER 4 + ML 12)", "(**80** = 브론즈 64 + SILVER 4 + ML 12)"),
 ("| 참고: 전체 이관 총계 | **81** | — | 브론즈 65 + 위 16 |",
  "| 참고: 전체 이관 총계 | **80** | — | 브론즈 64 + 위 16 |"),
 ("(테이블 81개 생성 = 브론즈 65 + SILVER 4 + ML 12)", "(테이블 80개 생성 = 브론즈 64 + SILVER 4 + ML 12)"),
 ("행수·무결성·거부행 대조 (81 테이블)", "행수·무결성·거부행 대조 (80 테이블)"),
]
s = io.open(P, encoding="utf-8").read()
for a, b in R:
    n = s.count(a)
    assert n == 1, (n, a[:40])
    s = s.replace(a, b)
io.open(P, "w", encoding="utf-8").write(s)
print("ok", len(R))
