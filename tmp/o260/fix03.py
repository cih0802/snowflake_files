import io, sys
P = sys.argv[1]
R = [
 ("--   ③-2 BRONZE_GA4 (2 테이블) · ③-3 BRONZE_GSC (3 테이블)",
  "--   ③-2 BRONZE_GA4 (2 테이블) · ③-3 BRONZE_GSC (2 테이블 · 🆕 O260 SEARCH_CONSOLE_DATA2 삭제)"),
 ("--   ⇒ 합계 81 테이블",
  "--   ⇒ 합계 80 테이블 (🆕 2026-10-23 O260 · 81 → 80)\n"
  "--   ⛔ BRONZE_CRM.TM_PM_MBRFEE_ACMSLT_TEST(원천 테스트 테이블)는 A 가 02번 2절에서 REVOKE 한다 ⇒ B 에 보이면 A 에 회수 요청."),
 ("AS crm_visible,      -- 기대 53",
  "AS crm_visible,      -- 기대 53 (54 = A 의 _TEST REVOKE 누락)"),
 ("--   기대: BRONZE_AGENCY 4 · BRONZE_CRM 53 · BRONZE_ERP 3 · BRONZE_GA4 2 · BRONZE_GSC 3\n--         · ML 12 · SILVER 4 = 81 테이블",
  "--   기대: BRONZE_AGENCY 4 · BRONZE_CRM 53 · BRONZE_ERP 3 · BRONZE_GA4 2 · BRONZE_GSC 2\n--         · ML 12 · SILVER 4 = 80 테이블 (2026-10-23)"),
 ("--    대상: BRONZE_CRM(53) · BRONZE_AGENCY(4) · BRONZE_ERP(3) · BRONZE_GA4(2) · BRONZE_GSC(3)\n--          · SILVER(4) · ML(12) = 81",
  "--    대상: BRONZE_CRM(53) · BRONZE_AGENCY(4) · BRONZE_ERP(3) · BRONZE_GA4(2) · BRONZE_GSC(2)\n--          · SILVER(4) · ML(12) = 80 (2026-10-23)"),
 ("'UNLOAD 완료: 81개 테이블' 이 나와야 정상.",
  "'UNLOAD 완료: 80개 테이블' 이 나와야 정상(2026-10-23)."),
 ("-- 기대 반환값: 'UNLOAD 완료: 81개 테이블'",
  "-- 기대 반환값: 'UNLOAD 완료: 80개 테이블' (2026-10-23)"),
]
s = io.open(P, encoding="utf-8").read()
for a, b in R:
    n = s.count(a)
    assert n == 1, (n, a[:40])
    s = s.replace(a, b)
io.open(P, "w", encoding="utf-8").write(s)
print("ok", len(R))
