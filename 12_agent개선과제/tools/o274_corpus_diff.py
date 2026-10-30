# O274 — 지표사전 새 CSV ↔ 라이브 표 대조(읽기 전용 · 계획서 O273 §4 A4 · 운영계 B1 에도 쓴다)
# 판정(blocking) = DOC_ID 집합 · AGENT_SCOPE · TOOL_NAME · FORMULA 차이가 「추가 행」뿐이어야 한다
# 참고(비차단) = 그 밖의 열 차이 건수
# 사용: python3 12_agent개선과제/tools/o274_corpus_diff.py [--expect-added RT-31,RT-32,...]
# Co-authored with CoCo
import argparse
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(os.path.dirname(HERE), "output", "O217_biz_definition_corpus.csv")
TABLE = "GN_DW.SERVING.BIZ_DEFINITION_CORPUS"
KEY_COLS = ["AGENT_SCOPE", "TOOL_NAME", "FORMULA"]


def norm(v):
    return "" if v is None else str(v).strip()


def live_rows():
    from snowflake.snowpark import Session
    token = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
    s = Session.builder.configs({
        "account": os.environ["SNOWFLAKE_ACCOUNT"], "host": os.environ["SNOWFLAKE_HOST"],
        "authenticator": "oauth", "token": token,
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE"), "role": os.environ.get("SNOWFLAKE_ROLE"),
    }).create()
    acct = s.sql("SELECT CURRENT_ACCOUNT()").collect()[0][0]
    df = s.sql("SELECT * FROM " + TABLE).to_pandas()
    return acct, {norm(r["DOC_ID"]): {k: norm(v) for k, v in r.items()} for r in df.to_dict("records")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--expect-added", default="RT-31,RT-32,RT-33,RT-34,RT-35,RT-36,RT-37")
    a = ap.parse_args()
    expect = set(x.strip() for x in a.expect_added.split(",") if x.strip())
    with open(CSV, encoding="utf-8", newline="") as fh:
        new = {norm(r["DOC_ID"]): {k: norm(v) for k, v in r.items()} for r in csv.DictReader(fh)}
    acct, old = live_rows()
    added, removed = set(new) - set(old), set(old) - set(new)
    key_diff, info_diff = [], {}
    for d in sorted(set(new) & set(old)):
        for c in new[d]:
            if c not in old[d] or new[d][c] == old[d][c]:
                continue
            if c in KEY_COLS:
                key_diff.append((d, c, old[d][c][:60], new[d][c][:60]))
            else:
                info_diff[c] = info_diff.get(c, 0) + 1
                if c != "SEARCH_TEXT":
                    print("  참고 %s.%s\n    표 = %s\n    CSV = %s" % (d, c, old[d][c][:300], new[d][c][:300]))
    print("계정 =", acct, "· CSV 행 =", len(new), "· 표 행 =", len(old))
    print("추가 =", sorted(added))
    print("삭제 =", sorted(removed))
    print("핵심열 차이(%s) = %d건" % ("·".join(KEY_COLS), len(key_diff)))
    for x in key_diff[:30]:
        print("  ", x)
    print("참고열 차이(비차단) =", info_diff)
    ok = added == expect and not removed and not key_diff
    print("🟢 PASS — 차이 = 추가 %d행뿐" % len(added) if ok else "🔴 FAIL — 멈춤(계획서 R3)")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
