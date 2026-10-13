# O217-B — Agent spec 내보내기 · 대조 · 적용(운영계 재현용 · 계정 무관)
# export <AGENT> <out.yaml>        = 라이브 기본 버전 spec 을 yaml 로 저장
# diff   <a.yaml> <b.yaml>         = 두 spec 의 정규화 비교(키별 일치/불일치)
# apply  <AGENT> <spec.yaml>       = MODIFY LIVE VERSION SET SPECIFICATION → COMMIT(새 VERSION$N)
#                                    🔴 승인 대상(라이브 변경) · 적용 전 export 백업을 남긴다
# Co-authored with CoCo
import json
import os
import sys

import yaml

FQ = "GN_DW.SERVING."


def session():
    from snowflake.snowpark import Session
    token = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
    return Session.builder.configs({
        "account": os.environ["SNOWFLAKE_ACCOUNT"], "host": os.environ["SNOWFLAKE_HOST"],
        "authenticator": "oauth", "token": token,
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE"), "role": os.environ.get("SNOWFLAKE_ROLE"),
    }).create()


def load(p):
    with open(p, encoding="utf-8") as f:
        return yaml.safe_load("".join(l for l in f if not l.startswith("# O217")))


def live_spec(s, agent):
    rows = s.sql("SHOW VERSIONS IN AGENT " + FQ + agent).collect()
    d = [r for r in rows if str(r["is_default"]).lower() == "true"]
    if len(d) != 1:
        sys.exit("기본 버전 판정 실패: %s" % [r["name"] for r in rows])
    return d[0]["name"], json.loads(d[0]["agent_spec"])


def export(agent, out):
    s = session()
    ver, spec = live_spec(s, agent)
    with open(out, "w", encoding="utf-8") as f:
        f.write("# O217 export = %s%s %s (%s)\n" % (FQ, agent, ver, s.sql("SELECT CURRENT_ACCOUNT()").collect()[0][0]))
        yaml.safe_dump(spec, f, allow_unicode=True, sort_keys=False, width=200)
    print(agent, ver, "도구 수 =", len(spec.get("tools", [])), "→", out)


def diff(a, b):
    x, y = load(a), load(b)
    bad = 0
    for k in sorted(set(x) | set(y)):
        if k == "instructions":
            for j in sorted(set(x.get(k, {})) | set(y.get(k, {}))):
                same = x.get(k, {}).get(j) == y.get(k, {}).get(j)
                bad += not same
                print("instructions.%s" % j, "일치" if same else "🔴 불일치")
            continue
        same = json.dumps(x.get(k), sort_keys=True) == json.dumps(y.get(k), sort_keys=True)
        bad += not same
        print(k, "일치" if same else "🔴 불일치")
    print("불일치 키 =", bad)
    return bad


def apply(agent, path):
    spec = load(path)
    body = json.dumps(spec, ensure_ascii=False, separators=(",", ":"))
    # 문서 상한 = 100,000 · O217 실측 = MEMBER 102,577 B(UTF-8) 가 jw08094 에서 배포됐다 ⇒ 문자 수로 사전 점검
    if len(body) > 100000:
        sys.exit("spec 100,000 자 초과: %d" % len(body))
    if "$$" in body:
        sys.exit("spec 에 $$ 포함 — dollar-quote 불가")
    s = session()
    before, _ = live_spec(s, agent)
    try:  # live 버전이 없으면 만든다(이미 있으면 오류 → 그대로 진행)
        s.sql("ALTER AGENT %s%s ADD LIVE VERSION FROM LAST" % (FQ, agent)).collect()
    except Exception as e:  # noqa: BLE001
        print("ADD LIVE VERSION 생략:", str(e)[:120])
    s.sql("ALTER AGENT %s%s MODIFY LIVE VERSION SET SPECIFICATION = $$%s$$" % (FQ, agent, body)).collect()
    cm = os.environ.get("AGENT_COMMIT_COMMENT", "O217-B").replace("'", "")
    s.sql("ALTER AGENT %s%s COMMIT COMMENT = '%s'" % (FQ, agent, cm)).collect()
    after, live = live_spec(s, agent)
    print(agent, before, "→", after, "· 도구 수 =", len(live.get("tools", [])))


if __name__ == "__main__":
    c = sys.argv[1]
    if c == "export":
        export(sys.argv[2], sys.argv[3])
    elif c == "diff":
        sys.exit(1 if diff(sys.argv[2], sys.argv[3]) else 0)
    elif c == "apply":
        apply(sys.argv[2], sys.argv[3])
    else:
        sys.exit("사용법: export|diff|apply")
