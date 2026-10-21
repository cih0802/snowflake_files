#!/usr/bin/env python3
"""O250-D · Cortex Analyst 생성 SQL(4문항)과 직접 작성 정답 SQL 을 실행해 결과를 대조한다(읽기 전용)."""
import json
import os
import re
from decimal import Decimal

import snowflake.connector

D = "/workspace/tmp/o250"
GT = {
    "q1": """SELECT CPR_DIV_NM, HQ_BRANCH_NM, COUNT(DISTINCT IFF(IS_UNPAID_STDR, MBER_NO, NULL)) U,
                 COUNT(DISTINCT IFF(IS_UNPAID_STDR AND CHURN_GRADE='고위험', MBER_NO, NULL)) UH
          FROM GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V WHERE STDR_MT='202609' AND CPR_DIV_NM IS NOT NULL
          GROUP BY 1,2 ORDER BY 1,2""",
    "q2": """SELECT NEW_EXISTING, SPONSORSHIP_NAME, ROUND(SUM(CHURN_PROB*MEMBER_WEIGHT),1) E
          FROM GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V WHERE STDR_MT='202609' AND SPONSORSHIP_NAME IS NOT NULL
          GROUP BY 1,2 ORDER BY 3 DESC LIMIT 10""",
    "q3": """SELECT COALESCE(MKTG_CMPGN_NM, IFF(IS_ALLOCATED,'(미지정)','배분 불가')) K, ROUND(SUM(ALLOC_FORECAST_AMT)) A
          FROM GN_DW.SERVING.ML_FEE_FORECAST_AXIS_V WHERE STDR_MT='202609' GROUP BY 1 ORDER BY 2 DESC LIMIT 7""",
    "q4": """SELECT CMMN_BRND_NM, COUNT(DISTINCT MBER_NO) N, ROUND(AVG(INC_PROB)*100,2) P
          FROM GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V
          WHERE STDR_MT=(SELECT MAX(STDR_MT) FROM GN_DW.SERVING.ML_MEMBER_PRED_AXIS_V)
            AND CPR_DIV_NM='사단' AND HQ_BRANCH_NM='지부' AND CMMN_BRND_NM IS NOT NULL
          GROUP BY 1 HAVING COUNT(DISTINCT MBER_NO) >= 100 ORDER BY 3 DESC""",
}
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), account=os.environ.get("SNOWFLAKE_ACCOUNT"),
                                  authenticator="oauth", token=tok, role="GN_DW_ANALYST", warehouse="GN_DW_ANALYTICS_WH")
cur = con.cursor()


def fmt(rows, n=12):
    return [tuple(float(v) if isinstance(v, Decimal) else v for v in r) for r in rows[:n]]


for q in ("q1", "q2", "q3", "q4"):
    raw = open(f"{D}/ca_{q}.json", encoding="utf-8").read()
    j = json.loads(raw[raw.find("{"):])
    m = re.search(r"```sql\n(.*?)```", j["result"], re.S)
    print(f"===== {q} : {j['question']}")
    if not m:
        print("🔴 SQL 없음 ·", j["result"][:300])
        continue
    sql = m.group(1).strip().rstrip(";")
    try:
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        print("CA 열", cols)
        print("CA", fmt(cur.fetchall()))
    except Exception as e:
        print("🔴 CA 실행 오류", str(e)[:300])
    cur.execute(GT[q])
    print("GT", fmt(cur.fetchall()))
