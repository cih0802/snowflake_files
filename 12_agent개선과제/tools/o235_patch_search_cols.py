# O235 — search_biz_definition 도구에 columns_and_descriptions 배선(multi-index 서비스 대응)
# 증상 = Agent 검색 호출 오류 「Column DOC_ID doesn't have a text index or a vector index」
#        「Text only search is not supported. Please specify at least one vector column.」
# 원인(추정 · 운영계 재현 필요) = O233-B 에서 서비스가 multi-index(TEXT TITLE·KEYWORDS·SEARCH_TEXT /
#   VECTOR SEARCH_TEXT)로 바뀌었는데 도구 설정은 종전 단일 색인 형식(id_column 만)이다
#   ⇒ 검색 대상 컬럼을 columns_and_descriptions 로 명시한다(벡터 색인 컬럼 SEARCH_TEXT 포함)
# 사용 = python3 o217_agent_io.py export AGENT_MARKETING live.yaml
#        python3 o235_patch_search_cols.py live.yaml out.yaml
#        python3 o217_agent_io.py diff live.yaml out.yaml   → tool_resources 만 불일치여야 한다
#        AGENT_COMMIT_COMMENT=O235 python3 o217_agent_io.py apply AGENT_MARKETING out.yaml   (🔴 승인 대상)
# Co-authored with CoCo
import sys

import yaml

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from o217_agent_io import load  # noqa: E402

COLS = {
    "TITLE": {"description": "지표명·용어·부서명·라우팅 항목명(예: 캠페인별 누계중단율(%))",
              "type": "string", "searchable": True, "filterable": False},
    "KEYWORDS": {"description": "제목·동의어 표기 변형(누계↔누적 · 율↔률↔비중 · 띄어쓰기 제거)",
                 "type": "string", "searchable": True, "filterable": False},
    "SEARCH_TEXT": {"description": "검색 본문 = 동의어·정의·계산식·도구·SV 필드·한계 합본(Markdown)",
                    "type": "string", "searchable": True, "filterable": False},
    "FORMULA": {"description": "계산식 원문(빈 값 = 원천에 산식 미등록)",
                "type": "string", "searchable": False, "filterable": False},
    "DOC_TYPE": {"description": "문서 유형: 라우팅 · 지표 · 용어 · 조직",
                 "type": "string", "searchable": False, "filterable": True},
    "HAS_FORMULA": {"description": "산식 등록 여부: Y = 계산식 있음 · N = 원천 공란. 계산식·산식·어떻게 계산 질문은 Y 로 필터",
                    "type": "string", "searchable": False, "filterable": True},
}

# ㉢ 산식 질문 응답 규칙(orchestration 머리에 1문단 · 기존 라우팅은 바꾸지 않는다)
ORCH = (
    "🔴🔴 🆕 [O235 산식 질문] 「계산식·산식·어떻게 계산·어떻게 들어갔나」 질문은 search_biz_definition 을 "
    "HAS_FORMULA = Y 로 필터해 조회하고 **계산식이 등록된 항목만** 답한다. 계산식이 「미등록」인 항목을 나열하거나 "
    "「산식이 없다」로 답을 시작하지 않는다. 질문한 이름 그대로의 항목에 산식이 없으면 같은 계열(이름·동의어가 겹치는) "
    "산식 등록 항목을 「가장 가까운 등록 산식」으로 제시하고, 같은 지표라는 근거가 없으면 「동일 지표 여부는 원천 근거 없음」을 "
    "한 줄로 덧붙인다. 등록 산식이 하나도 없을 때만 「지표사전에 계산식이 등록되지 않았다」고 답한다.\n\n"
)


def main(src, out):
    d = load(src)
    tr = d.get("tool_resources", {}).get("search_biz_definition")
    if tr is None:
        sys.exit("search_biz_definition 도구 부재: " + src)
    tr["columns_and_descriptions"] = COLS
    orch = d["instructions"].get("orchestration", "")
    if "[O235 산식 질문]" not in orch:
        d["instructions"]["orchestration"] = ORCH + orch
    with open(out, "w", encoding="utf-8") as f:
        f.write("# O235 개정안 = %s + tools/o235_patch_search_cols.py\n" % src)
        yaml.safe_dump(d, f, allow_unicode=True, sort_keys=False, width=200)
    print("patched →", out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("사용법: o235_patch_search_cols.py <live.yaml> <out.yaml>")
    main(sys.argv[1], sys.argv[2])
