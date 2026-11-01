# O217 — AGENT_MEMBER · AGENT_EXECUTIVE 에 search_biz_definition 도구만 배선
# 입력 = 12_agent개선과제/15_O217_백업_AGENT_<X>_spec.yaml · 출력 = 17_O217_AGENT_<X>_spec.yaml
# 기존 라우팅은 바꾸지 않는다 — 도구 1개 + orchestration 머리 1문단만 추가한다
# Co-authored with CoCo
import os
import sys

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from o217_patch_marketing_spec import BASE, SEARCH_SERVICE, load  # noqa: E402

ORCH = (
    "🔴🔴 🆕 [O217 정의 조회] 질문의 지표·용어·분류 이름이 낯설거나 「정의되지 않았다·산출할 수 없다」고 답하려 할 때는 "
    "먼저 **search_biz_definition** 으로 정의·계산식·담당 도구(TOOL_NAME)·SV 필드(SV_FIELD)를 조회하고, 결과의 도구가 "
    "이 Agent 에 있으면 그 도구로 답한다. 🔴 search 결과는 정의 확인용이다 — 수치는 analyst 도구 결과로만 쓴다. "
    "🔴 [O217 사용자 결정 A] 개발건수는 「GA·일별리포트」 명시가 없으면 MSTR 개발(건)으로 답한다. "
    "🔴 [O217] 답변 끝에 정기 리포트·자동 발송·자동화 설정을 권유하지 않는다.\n\n"
)
DESC = (
    "🆕 [O217] 굿네이버스 비즈니스 정의 검색 — 현업 지표사전(공통·신규·추가)·지표 용어·조직(부서명·부서코드)·"
    "라우팅 결정(어느 도구·어느 SV 필드로 답하는지)·확정 산식. 원천=90_provided_definition 문서 → "
    "GN_DW.SERVING.BIZ_DEFINITION_CORPUS. 「~의 정의·계산식」「이 지표는 어느 데이터로 보나」 질문과 낯선 지표 이름을 "
    "만났을 때 사용. 🔴 정의만 담는다 — 수치는 analyst 도구로만 낸다."
)


def main():
    for a in ("MEMBER", "EXECUTIVE"):
        d = load(os.path.join(BASE, "15_O217_백업_AGENT_%s_spec.yaml" % a))
        if any(t["tool_spec"]["name"] == "search_biz_definition" for t in d["tools"]):
            sys.exit("이미 배선됨: " + a)
        d["tools"].insert(0, {"tool_spec": {
            "type": "cortex_search", "name": "search_biz_definition", "description": DESC}})
        d["tool_resources"]["search_biz_definition"] = {
            "search_service": SEARCH_SERVICE, "id_column": "DOC_ID",
            "title_column": "TITLE", "max_results": 5}
        d["instructions"]["orchestration"] = ORCH + d["instructions"]["orchestration"]
        out = os.path.join(BASE, "17_O217_AGENT_%s_spec.yaml" % a)
        with open(out, "w", encoding="utf-8") as f:
            f.write("# O217 개정안 = 15_O217_백업_AGENT_%s_spec.yaml + tools/o217_patch_search_tool.py\n" % a)
            yaml.safe_dump(d, f, allow_unicode=True, sort_keys=False, width=200)
        print(a, "도구 수 =", len(d["tools"]))


if __name__ == "__main__":
    main()
