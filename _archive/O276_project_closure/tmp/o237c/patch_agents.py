import io, shutil, yaml
D = "/workspace/cortex_project/agents/"
ANCHOR = "[O237-B] 「캠페인별 활동율"
ADD = ("[O237-C 후원사업별 미납율] 「후원사업별 미납율(공79)」은 analyst_member_sponsor_biz 의 SPONSORSHIP_UNPAID_RATE"
       "(후원사업 미납(건) ÷ 활동(건) ×100 · 기준연월 하나 고정 · 분자·분모 함께 · ROLLUP 전체)로 계산한다 —"
       " 청구 대비 미납비중(analyst_member_fee)으로 대신하지 않는다. 🔴 ")
for a in ("AGENT_MEMBER", "AGENT_MARKETING"):
    p = D + a + "/agent_spec.yaml"
    shutil.copy(p, "/workspace/tmp/o237c/bak/%s_agent_spec.yaml.O237C-before" % a)
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
