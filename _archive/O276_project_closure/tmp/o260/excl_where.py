import io, sys
P = sys.argv[1]
A = "WHERE table_type = 'BASE TABLE'\n  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY', 'BRONZE_GA4', 'BRONZE_GSC')"
B = ("WHERE table_type = 'BASE TABLE'\n"
     "  AND table_name <> 'TM_PM_MBRFEE_ACMSLT_TEST'   -- 🆕 O260 이관 제외(원천 테스트 테이블)\n"
     "  AND (    table_schema IN ('BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY', 'BRONZE_GA4', 'BRONZE_GSC')")
s = io.open(P, encoding="utf-8").read()
n = s.count(A)
print("matches", n)
assert n == int(sys.argv[2])
io.open(P, "w", encoding="utf-8").write(s.replace(A, B))
