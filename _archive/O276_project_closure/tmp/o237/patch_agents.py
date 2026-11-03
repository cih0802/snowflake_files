# O237 — 정본 agent_spec.yaml 3종: search_biz_definition 열 4개(COVERAGE·ANSWER_GUIDE·TOOL_NAME·SV_FIELD) + [O237] 규칙 1문장 삽입
# 방식 = O236 patch_agents.py 와 같다(백업 → 고유 앵커 assert → 파싱 → 의미 diff → 쓰기 후 재독)
# Co-authored with CoCo
import json
import os
import shutil
import sys

import yaml

BASE = "/workspace/cortex_project/agents"
BAK = "/workspace/tmp/o237/bak"
ANCHOR_RULE = "누계중단(건)·누계개발(건)·연도초활동회원(건)·누계중단율(%)을 함께 보인다."
RULE = (" 🔴 [O237 산식 대응] 지표사전 산식 질문은 search_biz_definition 결과의 **COVERAGE·TOOL_NAME·SV_FIELD·ANSWER_GUIDE** 를 읽고"
        " ANSWER_GUIDE 의 절차대로 그 도구로 계산한다 — C1_METRIC = 그 metric 하나 · C2_COMBINE = 같은 도구 안에서 필터·기간·ROLLUP 조합 ·"
        " C3_CROSS = 두 도구를 각각 호출해 표를 분리한 뒤 나눈다 · C4_DIMENSION = 값 목록이므로 그 차원으로 분해한다 ·"
        " C5_PARTIAL = 답하되 ANSWER_GUIDE 의 제약 문구를 답변에 그대로 밝힌다 · G2_NEED_CONFIRM = 답하되 「산식 원문 확인 필요」를 한 줄 밝힌다 ·"
        " G1_NEED_MODEL = 근사 계산하지 말고 「현재 산출 불가 — 모델 추가 예정」으로 답한 뒤 가장 가까운 산출 가능 지표를 별도로 제시한다.")
COL_BLOCK = (
    "      COVERAGE:\n"
    "        description: '산식 대응 상태: C1_METRIC·C2_COMBINE·C3_CROSS·C4_DIMENSION·C5_PARTIAL = 답변 가능 · G1_NEED_MODEL = 현재 산출 불가 · G2_NEED_CONFIRM = 산식 원문 확인 필요'\n"
    "        type: string\n"
    "        searchable: false\n"
    "        filterable: true\n"
    "      TOOL_NAME:\n"
    "        description: 산식을 계산할 analyst 도구명(여러 개면 · 또는 | 로 구분 · C3_CROSS 는 각각 호출)\n"
    "        type: string\n"
    "        searchable: false\n"
    "        filterable: false\n"
    "      SV_FIELD:\n"
    "        description: 그 도구에서 쓸 SV 논리 필드(SV명.논리테이블.필드 · 여러 개면 · 구분)\n"
    "        type: string\n"
    "        searchable: false\n"
    "        filterable: false\n"
    "      ANSWER_GUIDE:\n"
    "        description: LLM 답변 절차(어느 metric·필터·기간·조합으로 답하는가와 답변에 밝힐 제약)\n"
    "        type: string\n"
    "        searchable: false\n"
    "        filterable: false\n")
NEW_COLS = ("COVERAGE", "TOOL_NAME", "SV_FIELD", "ANSWER_GUIDE")


def insert_cols(src, a):
    key = "      HAS_FORMULA:\n"
    assert src.count(key) == 1, (a, src.count(key))
    i = src.index(key)
    end = i
    for _ in range(5):
        end = src.index("\n", end) + 1
    blk = src[i:end]
    assert blk.rstrip("\n").endswith("filterable: true"), (a, blk)
    return src[:end] + COL_BLOCK + src[end:]


def search_cols(d):
    return d["tool_resources"]["search_biz_definition"]["columns_and_descriptions"]


def main():
    os.makedirs(BAK, exist_ok=True)
    for a in ("MEMBER", "MARKETING", "EXECUTIVE"):
        p = os.path.join(BASE, "AGENT_%s" % a, "agent_spec.yaml")
        src = open(p, encoding="utf-8").read()
        bak = os.path.join(BAK, "AGENT_%s.agent_spec.yaml.O237-before" % a)
        if not os.path.exists(bak):
            shutil.copyfile(p, bak)
        if open(bak, encoding="utf-8").read() != src:
            sys.exit("백업 ≠ 현재 — 중단: " + a)
        if "[O237 산식 대응]" in src:
            sys.exit("이미 배선됨: " + a)
        assert src.count(ANCHOR_RULE) == 1, (a, src.count(ANCHOR_RULE))
        new = src.replace(ANCHOR_RULE, ANCHOR_RULE + RULE)
        new = insert_cols(new, a)
        o, n = yaml.safe_load(src), yaml.safe_load(new)
        oc, nc = search_cols(o), search_cols(n)
        assert not (set(NEW_COLS) & set(oc)), a
        assert {k: v for k, v in nc.items() if k not in NEW_COLS} == oc and set(nc) - set(oc) == set(NEW_COLS), a
        assert nc["COVERAGE"]["filterable"] is True, a
        oo = o["instructions"]["orchestration"]
        assert n["instructions"]["orchestration"] == oo.replace(ANCHOR_RULE, ANCHOR_RULE + RULE), a
        assert {k: v for k, v in n["instructions"].items() if k != "orchestration"} == \
               {k: v for k, v in o["instructions"].items() if k != "orchestration"}, a
        assert n["tools"] == o["tools"], a
        ot = {k: v for k, v in o["tool_resources"].items() if k != "search_biz_definition"}
        nt = {k: v for k, v in n["tool_resources"].items() if k != "search_biz_definition"}
        assert ot == nt, a
        os_, ns_ = dict(o["tool_resources"]["search_biz_definition"]), dict(n["tool_resources"]["search_biz_definition"])
        os_.pop("columns_and_descriptions"), ns_.pop("columns_and_descriptions")
        assert os_ == ns_, a
        assert {k: v for k, v in n.items() if k not in ("tool_resources", "instructions")} == \
               {k: v for k, v in o.items() if k not in ("tool_resources", "instructions")}, a
        open(p, "w", encoding="utf-8").write(new)
        assert open(p, encoding="utf-8").read() == new, "쓰기 후 재독 불일치: " + a
        size = len(json.dumps(n, ensure_ascii=False, separators=(",", ":")))
        print(a, "OK · 검색 열", len(oc), "→", len(nc), "· 규칙 +1 · spec", size, "자")


if __name__ == "__main__":
    main()
