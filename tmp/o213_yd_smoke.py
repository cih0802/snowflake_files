"""O213 Y3-D — SV_PAYMENT_BILLING_STATUS GRANT(GN_DW_ADMIN) + 스모크(GN_DW_ANALYST · 정본 05_19 말미 3값 · VQR 202608)."""
import os
import snowflake.connector

tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()


def con(role, wh):
    return snowflake.connector.connect(account=os.environ["SNOWFLAKE_ACCOUNT"], host=os.environ.get("SNOWFLAKE_HOST"),
                                       authenticator="oauth", token=tok, role=role, warehouse=wh, database="GN_DW", schema="SERVING")


a = con("GN_DW_ADMIN", "GN_DW_DEV_WH").cursor()
for r in ("GN_DW_ANALYST", "GN_DW_VIEWER", "GN_DW_SERVICE"):
    a.execute(f"GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS TO ROLE {r}")
print("GRANT 3 OK")

c = con("GN_DW_ANALYST", "GN_DW_ANALYTICS_WH").cursor()
sv, fact, fmf = c.execute("""
SELECT (SELECT BILLED_AMT_SUM FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS METRICS pbs.BILLED_AMT_SUM)),
       (SELECT SUM(BILLED_AMT) FROM GN_DW.GOLD.FACT_PAYMENT_BILLING_STATUS),
       (SELECT SUM(BILLED_AMT) FROM GN_DW.GOLD.FACT_MEMBER_FEE)""").fetchone()
print("smoke sv/fact/fmf =", sv, fact, fmf, "MATCH" if sv == fact == fmf else "🔴 MISMATCH")
print("VQR 202608 청구구분:")
for row in c.execute("""SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS
        DIMENSIONS pbs.RQEST_DIV_NAME, pbs.RQEST_DIV_CD METRICS pbs.BILLING_ROW_CNT, pbs.BILLED_AMT_SUM
        WHERE pbs.MONTH_KEY = 202608) ORDER BY 3 DESC""").fetchall():
    print("  ", row)
print("환급사유 상위 3:")
for row in c.execute("""SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS
        DIMENSIONS pbs.RETUN_RSN_NAME METRICS pbs.BILLING_ROW_CNT WHERE pbs.RETUN_RSN_NAME IS NOT NULL) ORDER BY 2 DESC LIMIT 3""").fetchall():
    print("  ", row)
print("dims =", len(c.execute("show semantic dimensions in GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS").fetchall()),
      "metrics =", len(c.execute("show semantic metrics in GN_DW.SERVING.SV_PAYMENT_BILLING_STATUS").fetchall()))
