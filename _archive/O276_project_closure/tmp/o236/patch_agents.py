# O236 — 정본 agent_spec.yaml 3종에 analyst_campaign_cum_stop 도구·리소스·규칙 1문장 삽입(전체 재작성 없음)
# 방식 = 원문 문자열에 고유 앵커 기준 삽입 → 파싱 → 의미 diff(tools +1 · tool_resources +1 · orchestration 문장 +1)
# Co-authored with CoCo
import json
import os
import shutil
import sys

import yaml

BASE = "/workspace/cortex_project/agents"
BAK = "/workspace/tmp/o236"
ANCHOR_RULE = "「지표사전에 계산식이 등록되지 않았다」고 답한다."
RULE = (" 🔴 [O236] 「캠페인별 누계중단율·누계중단비중을 N월 기준으로 계산」은 근사하지 않고 **analyst_campaign_cum_stop** 으로"
        " 바로 계산한다 — 기준연월 하나 고정(2026년 9월 기준 = 202609 · 1월~9월 누계) · 캠페인 = 후원건 캠페인 ·"
        " 누계중단(건)·누계개발(건)·연도초활동회원(건)·누계중단율(%)을 함께 보인다.")
DESC = ("🆕 [O236] 캠페인별 누계중단율(신규 #17) 계산 전용(SV_CAMPAIGN_CUM_STOP · grain=기준연월×캠페인 · 누계 = 같은 해 1월~기준월)."
        " 원천=CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN(중단·연도초) · FACT_MEMBER_EVENT(개발) → GOLD.FACT_CAMPAIGN_CUM_STOP."
        " 지표: 누계중단(건) · 누계개발(건) · 연도초활동회원(건) · 캠페인별 누계중단율(%) = 누계중단 ÷ (누계개발 + 연도초활동) ×100."
        " 차원: 기준연월 · 캠페인명 · 캠페인카테고리 · 캠페인유형(국내/해외) · 캠페인유형2 · 개발인입경로 · 공통브랜드 · 마케팅캠페인 · 마케팅채널 · UTM · 상위캠페인."
        " 🔴 기준연월 하나를 고정한다(여러 기준월 합산 금지). 🔴 캠페인 = 후원건 캠페인 — 「그 달 후원 캠페인」(analyst_member_monthly)과 다른 축이다.")
TOOL_BLOCK = ("- tool_spec:\n"
              "    type: cortex_analyst_text_to_sql\n"
              "    name: analyst_campaign_cum_stop\n"
              "    description: " + json.dumps(DESC, ensure_ascii=False) + "\n")
RES_BLOCK = ("  analyst_campaign_cum_stop:\n"
             "    semantic_view: GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP\n"
             "    execution_environment:\n"
             "      type: warehouse\n"
             "      warehouse: GN_DW_ANALYTICS_WH\n")


def main():
    os.makedirs(BAK, exist_ok=True)
    for a in ("MEMBER", "MARKETING", "EXECUTIVE"):
        p = os.path.join(BASE, "AGENT_%s" % a, "agent_spec.yaml")
        src = open(p, encoding="utf-8").read()
        bak = os.path.join(BAK, "AGENT_%s.agent_spec.yaml.O236-before" % a)
        if not os.path.exists(bak):
            shutil.copyfile(p, bak)
        if open(bak, encoding="utf-8").read() != src:
            sys.exit("백업 ≠ 현재 — 중단: " + a)
        if "analyst_campaign_cum_stop" in src:
            sys.exit("이미 배선됨: " + a)
        assert src.count(ANCHOR_RULE) == 1, (a, src.count(ANCHOR_RULE))
        assert src.count("\ntool_resources:\n") == 1, a
        assert src.endswith("\n"), a
        new = src.replace(ANCHOR_RULE, ANCHOR_RULE + RULE)
        new = new.replace("\ntool_resources:\n", "\n" + TOOL_BLOCK + "tool_resources:\n")
        new = new + RES_BLOCK
        o, n = yaml.safe_load(src), yaml.safe_load(new)
        assert n["tools"][:-1] == o["tools"] and n["tools"][-1]["tool_spec"]["name"] == "analyst_campaign_cum_stop", a
        assert n["tool_resources"]["analyst_campaign_cum_stop"]["semantic_view"] == "GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP", a
        assert {k: v for k, v in n["tool_resources"].items() if k != "analyst_campaign_cum_stop"} == o["tool_resources"], a
        oo = o["instructions"]["orchestration"]
        assert n["instructions"]["orchestration"] == oo.replace(ANCHOR_RULE, ANCHOR_RULE + RULE), a
        assert {k: v for k, v in n["instructions"].items() if k != "orchestration"} == {k: v for k, v in o["instructions"].items() if k != "orchestration"}, a
        assert {k: v for k, v in n.items() if k not in ("tools", "tool_resources", "instructions")} == {k: v for k, v in o.items() if k not in ("tools", "tool_resources", "instructions")}, a
        open(p, "w", encoding="utf-8").write(new)
        back = open(p, encoding="utf-8").read()
        assert back == new, "쓰기 후 재독 불일치: " + a
        size = len(json.dumps(n, ensure_ascii=False, separators=(",", ":")))
        print(a, "OK · 도구", len(o["tools"]), "→", len(n["tools"]), "· spec", size, "자")


if __name__ == "__main__":
    main()
