# O218 — 마케팅 Agent 「① 핵심 요약」 2회 출력 결함 시정(정본 spec 패치 · 재실행 안전)
# 원인(output/o217b/after_QM4.txt · after_F01.txt) = ① 을 쓴 뒤 차트 생성 단계를 거치고 **답변을 처음부터 다시 쓴다**
#   (F01 = ①②①② · QM4 = ①▼①▼). response 의 「같은 내용을 두 번 출력하지 않는다」는 O207-C 문단 중간에 묻혀 있었다.
# 처방 = response 맨 앞에 「도구·차트 → 본문 1회」 순서 규칙 · orchestration 에 같은 순서를 1문장.
# 사용: python3 o218_patch_single_answer.py [spec.yaml]  (기본 = cortex_project 정본)
# Co-authored with CoCo
import io
import sys

import yaml

P = sys.argv[1] if len(sys.argv) > 1 else "/workspace/cortex_project/agents/AGENT_MARKETING/agent_spec.yaml"
TAG = "[O218 1회 출력]"
RESP = ("🔴🔴 " + TAG + " 답변 본문은 한 번만 쓴다. 차트 생성을 포함한 모든 도구 호출을 끝낸 뒤 「① 핵심 요약」을 쓰기 시작하고, "
        "차트가 만들어진 뒤 ①·▼ 상세를 다시 쓰지 않는다 — 「① 핵심 요약」 제목은 답변에 정확히 1회다. "
        "도구 호출 전 안내 문장은 1문장만 쓴다. ")
ORCH = ("🔴 " + TAG + " 데이터 조회·차트 생성을 모두 마친 다음 최종 답변을 한 번에 작성한다(본문 작성 중 도구를 다시 부르지 않는다).\n")


def main():
    t = open(P, encoding="utf-8").read()
    s = yaml.safe_load(t)
    ins = s["instructions"]
    if TAG in ins["response"]:
        print("이미 적용됨 — 변경 없음")
        return 0
    ins["response"] = RESP + ins["response"]
    ins["orchestration"] = ORCH + ins["orchestration"]
    o = io.StringIO()
    yaml.safe_dump(s, o, allow_unicode=True, sort_keys=False, width=200)
    open(P, "w", encoding="utf-8").write(o.getvalue())
    back = yaml.safe_load(open(P, encoding="utf-8").read())["instructions"]
    ok = back["response"].count(TAG) == 1 and back["orchestration"].count(TAG) == 1
    print("적용", "OK" if ok else "🔴 되읽기 실패", "· response", len(back["response"]), "· orchestration", len(back["orchestration"]))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
