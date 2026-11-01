# O234 — SEARCH_BIZ_DEFINITION 탐침(질의 → 상위 3 DOC_ID) · hit@1/@3
# 입력 = tools/o234_probe_set.csv (ID,EXPECT,QUERY · EXPECT 는 「|」로 복수 정답 허용)
# Co-authored with CoCo
import csv
import json
import os
import sys

from snowflake.snowpark import Session

HERE = os.path.dirname(os.path.abspath(__file__))
SVC = "GN_DW.SERVING.SEARCH_BIZ_DEFINITION"


def session():
    token = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
    return Session.builder.configs({
        "account": os.environ["SNOWFLAKE_ACCOUNT"], "host": os.environ["SNOWFLAKE_HOST"],
        "authenticator": "oauth", "token": token,
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE") or "COMPUTE_WH",
        "role": os.environ.get("SNOWFLAKE_ROLE"),
    }).create()


def main():
    s = session()
    s.sql("USE WAREHOUSE COMPUTE_WH").collect()
    rows = list(csv.DictReader(open(os.path.join(HERE, "o234_probe_set.csv"), encoding="utf-8-sig")))
    h1 = h3 = 0
    for r in rows:
        body = json.dumps({"query": r["QUERY"], "columns": ["DOC_ID", "TITLE"], "limit": 3}, ensure_ascii=False)
        sql = "select SNOWFLAKE.CORTEX.SEARCH_PREVIEW('%s', $$%s$$)" % (SVC, body)
        res = json.loads(s.sql(sql).collect()[0][0])["results"]
        ids = [x["DOC_ID"] for x in res]
        exp = r["EXPECT"].split("|")
        a = ids[:1] and ids[0] in exp
        b = any(i in exp for i in ids)
        h1 += a
        h3 += b
        mark = "@1" if a else ("@3" if b else "MISS")
        print("%s\t%s\t%s\t%s" % (r["ID"], mark, r["QUERY"], " ".join(ids)))
    n = len(rows)
    print("n=%d hit@1=%d (%.0f%%) hit@3=%d (%.0f%%)" % (n, h1, 100.0 * h1 / n, h3, 100.0 * h3 / n))


if __name__ == "__main__":
    sys.exit(main())
