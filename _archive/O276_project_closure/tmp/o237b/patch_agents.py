# O237-B — 정본 agent_spec.yaml 3종: analyst_campaign_monthly 도구·리소스 + [O237-B] 규칙 1문장
# 방식 = O236 patch_agents.py 와 같다(백업 → 고유 앵커 assert → 파싱 의미 diff → 쓰기 후 재독)
# Co-authored with CoCo
import json
import os
import shutil
import sys

import yaml

BASE = "/workspace/cortex_project/agents"
BAK = "/workspace/tmp/o237b/bak"
ANCHOR_RULE = "가장 가까운 산출 가능 지표를 별도로 제시한다."
RULE_COMMON = (" 🔴 [O237-B] 「캠페인별 활동율·중단율·이탈율·납입율·누계납입율·미납율(연도별·납입방식별 포함)」은 근사하지 않고"
               " **analyst_campaign_monthly** 로 계산한다 — 기준연월 하나 고정 · 「연도별」은 연도마다 마지막 마감 기준월 ·"
               " 납입방식 = 그 달 청구 결제수단(잠정)임을 밝힌다.")
RULE_SVC = {
    "MEMBER": " 「서비스 참여회원(서신·선물금·증액)의 N개월 유지율·납입율·중단율·가입캠페인 구성비」는 analyst_service_cohort 의"
              " 참여 플래그로 거른 RETAINED_*·PAID_AFTER_3M·EVER_STOPPED 비율로 답한다(N = 3·6·12 · 납입 창 3개월 잠정).",
    "MARKETING": " 「서비스 참여회원 유지율·납입율」은 이 Agent 에 서비스 코호트 도구가 없다 — 회원 Agent(AGENT_MEMBER) 소관이라고 안내한다.",
    "EXECUTIVE": " 「서비스 참여회원 유지율·납입율」은 이 Agent 에 서비스 코호트 도구가 없다 — 회원 Agent(AGENT_MEMBER) 소관이라고 안내한다.",
}
DESC = ("🆕 [O237-B] 캠페인별 월 지표 계산 전용(SV_CAMPAIGN_MONTHLY · grain=기준연월×캠페인×납입방식)."
        " 원천=CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN(활동·중단·연도초) · FACT_MEMBER_EVENT(개발) · FACT_MEMBER_FEE(회비) → GOLD.FACT_CAMPAIGN_MONTHLY."
        " 지표: 캠페인별 활동율(%) · 중단율(%) · 연도별 중단율(전월말 기준) · 이탈(건)·이탈율(%) · 납입율(%) · 누계 납입율(%) · 미납율(%) 와 분자·분모(활동·중단·개발·누계개발·연도초활동·납입회비·미납회비)."
        " 차원: 기준연월 · 기준연도 · 캠페인명 · 캠페인카테고리 · 캠페인유형 · 캠페인유형2 · 개발인입경로 · 공통브랜드 · 마케팅캠페인 · 마케팅채널 · UTM · 상위캠페인 · 납입방식(잠정)."
        " 🔴 기준연월 하나를 고정한다(여러 기준월 합산 금지). 🔴 캠페인 = 후원건 캠페인 — 「그 달 후원 캠페인」(analyst_member_monthly)과 다른 축이다.")
TOOL_BLOCK = ("- tool_spec:\n"
              "    type: cortex_analyst_text_to_sql\n"
              "    name: analyst_campaign_monthly\n"
              "    description: " + json.dumps(DESC, ensure_ascii=False) + "\n")
RES_BLOCK = ("  analyst_campaign_monthly:\n"
             "    semantic_view: GN_DW.SERVING.SV_CAMPAIGN_MONTHLY\n"
             "    execution_environment:\n"
             "      type: warehouse\n"
             "      warehouse: GN_DW_ANALYTICS_WH\n")


def main():
    os.makedirs(BAK, exist_ok=True)
    for a in ("MEMBER", "MARKETING", "EXECUTIVE"):
        p = os.path.join(BASE, "AGENT_%s" % a, "agent_spec.yaml")
        src = open(p, encoding="utf-8").read()
        bak = os.path.join(BAK, "AGENT_%s.agent_spec.yaml.O237B-before" % a)
        if not os.path.exists(bak):
            shutil.copyfile(p, bak)
        if open(bak, encoding="utf-8").read() != src:
            sys.exit("백업 ≠ 현재 — 중단: " + a)
        if "analyst_campaign_monthly" in src:
            sys.exit("이미 배선됨: " + a)
        rule = RULE_COMMON + RULE_SVC[a]
        assert src.count(ANCHOR_RULE) == 1, (a, src.count(ANCHOR_RULE))
        assert src.count("\ntool_resources:\n") == 1, a
        assert src.endswith("\n"), a
        new = src.replace(ANCHOR_RULE, ANCHOR_RULE + rule)
        new = new.replace("\ntool_resources:\n", "\n" + TOOL_BLOCK + "tool_resources:\n")
        new = new + RES_BLOCK
        o, n = yaml.safe_load(src), yaml.safe_load(new)
        assert n["tools"][:-1] == o["tools"] and n["tools"][-1]["tool_spec"]["name"] == "analyst_campaign_monthly", a
        assert n["tool_resources"]["analyst_campaign_monthly"]["semantic_view"] == "GN_DW.SERVING.SV_CAMPAIGN_MONTHLY", a
        assert {k: v for k, v in n["tool_resources"].items() if k != "analyst_campaign_monthly"} == o["tool_resources"], a
        assert n["instructions"]["orchestration"] == o["instructions"]["orchestration"].replace(ANCHOR_RULE, ANCHOR_RULE + rule), a
        assert {k: v for k, v in n["instructions"].items() if k != "orchestration"} == \
               {k: v for k, v in o["instructions"].items() if k != "orchestration"}, a
        assert {k: v for k, v in n.items() if k not in ("tools", "tool_resources", "instructions")} == \
               {k: v for k, v in o.items() if k not in ("tools", "tool_resources", "instructions")}, a
        open(p, "w", encoding="utf-8").write(new)
        assert open(p, encoding="utf-8").read() == new, "쓰기 후 재독 불일치: " + a
        size = len(json.dumps(n, ensure_ascii=False, separators=(",", ":")))
        print(a, "OK · 도구", len(o["tools"]), "→", len(n["tools"]), "· spec", size, "자")


if __name__ == "__main__":
    main()
