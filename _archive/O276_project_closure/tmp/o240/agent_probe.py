import io, json, os, re, sys, time, snowflake.connector
tok = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
cn = snowflake.connector.connect(host=os.environ.get("SNOWFLAKE_HOST"), token=tok, authenticator="oauth",
                                 account="ua91864", warehouse="COMPUTE_WH", database="GN_DW", schema="SERVING")
c = cn.cursor()
OUT = "/workspace/tmp/o240/probe"
os.makedirs(OUT, exist_ok=True)
QS = [
 ("AGENT_MEMBER", "2026년 9월 기준 캠페인별 누계중단율 전체값을 알려줘"),
 ("AGENT_MEMBER", "2021년 12월 기준 캠페인별 누계중단율 전체값을 알려줘"),
 ("AGENT_MEMBER", "2026년 9월 캠페인별 미납율 전체값"),
 ("AGENT_MEMBER", "2026년 9월 서비스별 서신 참여율"),
 ("AGENT_MARKETING", "2026년 9월 GA 평균세션시간과 이탈율"),
 ("AGENT_MARKETING", "2025년 디지털 광고 CTR과 CVR"),
 ("AGENT_EXECUTIVE", "2025년 예산 집행율"),
 ("AGENT_EXECUTIVE", "2026년 사업목표 연간 목표"),
]
def text_of(raw):
    try:
        d = json.loads(raw)
    except Exception:
        return raw[-600:]
    out = []
    for blk in d.get("content", []) if isinstance(d, dict) else []:
        if blk.get("type") == "text":
            out.append(blk.get("text", ""))
    return ("\n".join(out))[-900:] if out else raw[-600:]
for i, (a, q) in enumerate(QS, 1):
    req = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": q}]}]}, ensure_ascii=False)
    t0 = time.time()
    try:
        c.execute("select SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)", (f"GN_DW.SERVING.{a}", req))
        raw = c.fetchall()[0][0]
    except Exception as e:
        raw = f"__CALL_FAILED__ {e}"
    io.open(f"{OUT}/{i:02d}_{a}.txt", "w", encoding="utf-8").write(str(raw))
    tools = sorted(set(re.findall(r'"name"\s*:\s*"(analyst_[a-z_0-9]+|search_[a-z_]+)"', str(raw))))
    print(f"### {i} {a} ({time.time()-t0:.0f}s) Q: {q}\n tools={tools}\n{text_of(str(raw))}\n", flush=True)
cn.close()
