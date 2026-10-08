"""O213 Y3 — 정본 SV DDL 10종 배포(파일에서 그 SV 의 CREATE 문 1개를 잘라 GN_DW_ADMIN 으로 실행)."""
import io, os, re, sys
import snowflake.connector

FILES = {
    "SV_MEMBER_EVENT": "05_2_SV_DDL_MEMBER_EVENT.sql", "SV_MEMBER_COHORT": "05_3_SV_DDL_MEMBER_COHORT.sql",
    "SV_MEMBER_SPONSOR_BIZ": "05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql", "SV_MEMBER_MONTHLY": "05_1_SV_DDL_MEMBER_MONTHLY.sql",
    "SV_SERVICE": "05_4_SV_DDL_SERVICE.sql", "SV_EVENT_PARTICIPATION": "05_5_SV_DDL_EVENT_PARTICIPATION.sql",
    "SV_RELATION_ACTIVITY": "05_12_SV_DDL_RELATION_ACTIVITY.sql", "SV_MEMBER_STATUS_ASOF": "05_17_SV_DDL_MEMBER_STATUS_ASOF.sql",
    "SV_GA_BEHAVIOR": "05_15_SV_DDL_GA_BEHAVIOR.sql", "SV_AD": "05_7_SV_DDL_AD.sql",
    "SV_GA_SESSION": "05_20_SV_DDL_GA_SESSION.sql", "SV_SEARCH_CONSOLE": "05_21_SV_DDL_SEARCH_CONSOLE.sql",
    "SV_GA_DEMOGRAPHIC": "05_22_SV_DDL_GA_DEMOGRAPHIC.sql", "SV_EXPENSE_RESOLUTION": "05_23_SV_DDL_EXPENSE_RESOLUTION.sql",
    "SV_BUDGET": "05_6_SV_DDL_BUDGET.sql", "SV_BUDGET_YEARLY": "05_16_SV_DDL_BUDGET_YEARLY.sql"}
D = "/workspace/05_SV-Agent_ai/"
only = sys.argv[1:] or list(FILES)


def cut(t, sv):
    m = re.search(r"CREATE OR (?:REPLACE|ALTER) SEMANTIC VIEW GN_DW\.SERVING\." + sv + r"\b", t)
    q, j = False, m.start()
    while j < len(t):
        c = t[j]
        if c == "'":
            q = not q
        elif c == ";" and not q:
            return t[m.start():j]
        j += 1
    return t[m.start():]


token = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(account=os.environ["SNOWFLAKE_ACCOUNT"], host=os.environ.get("SNOWFLAKE_HOST"),
                                  authenticator="oauth", token=token, role="GN_DW_ADMIN", warehouse="GN_DW_DEV_WH",
                                  database="GN_DW", schema="SERVING")
cur = con.cursor()
bad = 0
for sv in only:
    stmt = cut(io.open(D + FILES[sv], encoding="utf-8").read(), sv)
    try:
        cur.execute(stmt)
        n = len(cur.execute(f"show semantic dimensions in GN_DW.SERVING.{sv}").fetchall())
        print(f"🟢 {sv}: OK · dimensions={n}")
    except Exception as e:
        bad += 1
        print(f"🔴 {sv}: {str(e)[:300]}")
con.close()
print("FAIL", bad)
sys.exit(1 if bad else 0)
