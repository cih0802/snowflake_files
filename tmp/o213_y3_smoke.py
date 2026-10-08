"""O213 Y3 스모크 — spec 의 새 차원 전건을 SV 경유로 질의(그 SV 의 첫 지표 · 상위 6개 값 · 행 수 · 센티넬 표시)."""
import csv, io, os, sys
import snowflake.connector

token = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(account=os.environ["SNOWFLAKE_ACCOUNT"], host=os.environ.get("SNOWFLAKE_HOST"),
                                  authenticator="oauth", token=token, role="GN_DW_ANALYST", warehouse="GN_DW_ANALYTICS_WH",
                                  database="GN_DW", schema="SERVING")
cur = con.cursor()
SENT = {"-", "(미매핑)", "(해당없음)", "미확인", "기타", "없음", "UNKNOWN", "Unknown"}
SPEC = sys.argv[sys.argv.index("--spec")+1] if "--spec" in sys.argv else "/workspace/tmp/o213_y3_sv_spec.tsv"
OUTP = SPEC.replace("_sv_spec.tsv", "_smoke.tsv")
spec = list(csv.DictReader(io.open(SPEC, encoding="utf-8"), delimiter="\t"))
out = io.open(OUTP, "w", encoding="utf-8")
out.write("sv\tdim\tmetric\tgroups\ttop6\tsentinel\tstatus\n")
bad = 0
metric_of = {}
for r in spec:
    sv, dim = r["sv"], f"{r['alias']}.{r['expose']}"
    if sv not in metric_of:
        ms = cur.execute(f"show semantic metrics in GN_DW.SERVING.{sv}").fetchall()
        metric_of[sv] = f"{ms[0][3].lower()}.{ms[0][4]}"
    m = metric_of[sv]
    try:
        rows = cur.execute(f"select * from semantic_view(GN_DW.SERVING.{sv} dimensions {dim} metrics {m}) "
                           f"order by 2 desc nulls last").fetchall()
        top = " / ".join(f"{a}={b}" for a, b in rows[:6])
        sent = [str(a) for a, _ in rows if a is None or str(a) in SENT]
        st = "OK"
    except Exception as e:
        rows, top, sent, st = [], str(e)[:160], [], "ERR"
        bad += 1
    out.write("\t".join([sv, dim, m, str(len(rows)), top, ",".join(sent), st]) + "\n")
    print(f"{st} {sv} {dim} groups={len(rows)} sent={sent[:3]}")
out.close()
con.close()
print("ERR", bad)
sys.exit(1 if bad else 0)
