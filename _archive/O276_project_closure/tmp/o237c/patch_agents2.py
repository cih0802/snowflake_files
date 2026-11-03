import io, shutil, yaml
D = "/workspace/cortex_project/agents/"
ANCHOR = "[O237-B] 「캠페인별 활동율"
ADD = ("[O237-C 최종캠페인] 「최종캠페인(공31)별 회원수·실적」은 analyst_member_monthly 의 LAST_CAMPAIGN_NAME"
       "(회원 최종캠페인 · 잠정 = 가장 최근 시작 후원약정의 대표캠페인)으로 분해한다 — 대표캠페인(sponsor_biz)·최초캠페인·그 달 후원 캠페인으로 대신하지 않는다"
       " · 기준월 하나 고정 · 답변에 「잠정(최근 시작 후원약정 기준)」을 밝힌다. 🔴 ")
for a in ("AGENT_MEMBER", "AGENT_EXECUTIVE"):
    p = D + a + "/agent_spec.yaml"
    shutil.copy(p, "/workspace/tmp/o237c/bak/%s_agent_spec.yaml.O237C-before2" % a)
    src = io.open(p, encoding="utf-8").read()
    assert src.count(ANCHOR) == 1, (a, src.count(ANCHOR))
    before = yaml.safe_load(src)
    out = src.replace(ANCHOR, ADD + ANCHOR, 1)
    after = yaml.safe_load(out)
    o1, o2 = before["instructions"]["orchestration"], after["instructions"]["orchestration"]
    assert o2.replace(ADD, "", 1) == o1, a
    io.open(p, "w", encoding="utf-8", newline="").write(out)
    assert io.open(p, encoding="utf-8").read() == out
    print(a, "OK", len(src), "->", len(out))
