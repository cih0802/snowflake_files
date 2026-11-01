# O217 — AGENT_MARKETING spec 개정 생성기
# 입력 = 12_agent개선과제/15_O217_백업_AGENT_MARKETING_spec.yaml (jw08094 DEFAULT 버전)
#        12_agent개선과제/15_O217_백업_AGENT_MEMBER_spec.yaml (회원실 예측 도구 2종 설명 재사용)
# 출력 = 12_agent개선과제/17_O217_AGENT_MARKETING_spec.yaml
# 원칙: 정해진 치환·추가만 한다 · 치환 대상이 없으면 실패(조용한 무변경 금지)
# Co-authored with CoCo
import os
import re
import sys

import yaml

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(BASE, "15_O217_백업_AGENT_MARKETING_spec.yaml")
MEMBER = os.path.join(BASE, "15_O217_백업_AGENT_MEMBER_spec.yaml")
OUT = os.path.join(BASE, "17_O217_AGENT_MARKETING_spec.yaml")
SEARCH_SERVICE = "GN_DW.SERVING.SEARCH_BIZ_DEFINITION"
WH = "GN_DW_ANALYTICS_WH"


def load(p):
    with open(p, encoding="utf-8") as f:
        return yaml.safe_load("".join(l for l in f if not l.startswith("# O217")))


def sub_once(text, pattern, repl, label):
    new, n = re.subn(pattern, repl, text, count=1, flags=re.S)
    if n != 1:
        sys.exit("치환 대상 없음: " + label)
    return new


LTV_RULE = (
    "- 🔴🔴 [O217 정정 · 지표사전 신규 #8 · 피드백_2 나눔마케팅 19] **회원 LTV 는 정의된 지표다** — "
    "산식 = 평균 월 납입회비 × 평균 유지개월수(정의 원문은 search_biz_definition 으로 확인). "
    "「활동기간」(analyst_member_cohort · 회원 1행)과 「납입회비」(analyst_member_fee · 회원×회비월×사업)는 "
    "grain 이 달라 SQL 로 조인하지 않는다 ⇒ **같은 캠페인 축으로 두 도구를 각각 호출한 뒤 결과값을 곱해** "
    "LTV 열을 만들고 「Agent 계산값 · 고정값 아님」을 붙인다. 표에는 회원개발건수·평균 월 납입회비·"
    "평균 유지개월수·회원 LTV 를 함께 둔다. 평균 유지기간은 중단 회원 기준이라 과소일 수 있음을 ③ 상세에 밝힌다. "
    "CAC·LTV/CAC 를 물으면 search_biz_definition 의 산식으로 계산하고, 원천이 이어지지 않는 축(ERP 제작비·광고비의 "
    "캠페인 연결)은 그 부분만 산출 불가 사유를 밝힌다. 「LTV 를 정의하지 않았다」고 답하지 않는다."
)

ORCH_O217 = (
    "🔴🔴 🆕 [O217 정의 조회 · 최우선] 질문의 지표·용어·분류 이름이 낯설거나, 「정의되지 않았다·산출할 수 없다」고 "
    "답하려 할 때는 먼저 **search_biz_definition** 으로 정의·계산식·담당 도구(TOOL_NAME)·SV 필드(SV_FIELD)를 조회한다. "
    "조회 결과에 도구가 있으면 그 도구로 답한다. 🔴 search 결과는 정의 확인용이다 — 수치는 반드시 analyst 도구 결과로만 쓰고 "
    "search 본문의 숫자를 답에 옮기지 않는다. 검색 결과의 물리 컬럼명을 SQL 식별자로 쓰지 않는다.\n\n"
    "🔴🔴 🆕 [O217 사용자 결정 A~D · 2026-10-13] "
    "A. 개발건수: 질문에 「GA」「일별리포트」가 **없으면** MSTR 개발(건)(analyst_mstr_spnsr_dvlp · 후원금액 ÷ 10,000)으로, "
    "**있으면** 일별리포트 GA 개발(건)(analyst_ad 의 GA 개발(건) · 디지털)으로 답한다. 두 값을 한 표에서 합산·비교하지 않는다. "
    "B. 「DR광고」 = 공통브랜드 방송·영상광고 캠페인(analyst_mstr_spnsr_dvlp). 「채널별」 개발 실적은 **마케팅채널** 축"
    "(EBS·SBS Biz 등)으로 나눈다 — 홍보방법은 채널이 아니다. "
    "C. 8개 분류 축 = 마케팅캠페인 · 공통브랜드 · 개발인입경로 · 캠페인유형(국내/해외) · 캠페인유형2(사업/사례) · "
    "캠페인카테고리 · 마케팅채널 · 마케팅UTM. 질문에 이 이름이 나오면 **그 축으로 바로** analyst_mstr_spnsr_dvlp 에 넘긴다 — "
    "비슷한 다른 컬럼을 찾지 않는다. "
    "D. 드릴다운: 개발구분·신규 여부를 지정하지 않은 개발 질문은 첫 답변을 개발 전체(신규·증액·재후원 합계 + 개발구분별)로 "
    "제시하고, 답변 끝에 다음에 볼 만한 축 2~3개를 한 줄로 제안한다(신규만 먼저 보여주지 않는다).\n\n"
    "🔴🔴 🆕 [O217 회원실 회비 예측] 연사업 회비예측·월 회비 예측·추경 회비예측·회비 시나리오(회원실 3·4·5번 유형)는 "
    "회원실 자체 수식 집계로 답한다 — 연간 회비 예측·실측 = **analyst_mbrfee_prdt_actl**(예측/실측 구분 고정) · "
    "월간 후원 분류별 집계(감액/개발/중단/활동/회비 · 법인 축) = **analyst_spnsr_cls_aggr**(집계유형 고정). "
    "직전 3개월 평균 같은 Agent 추세 계산으로 대신하지 않는다. 「추경」은 원천에 구분 축이 없으므로 [O207-C 미정의 지표] 절차를 따른다. "
    "🔴 [O217-B 실측] 「N월 회비 예측」은 **analyst_mbrfee_prdt_actl 의 예측 행(예측실측구분 = 예측 · 2026년 12월까지 월별 조정 회비)**에 "
    "있다 — 월간 분류 집계(analyst_spnsr_cls_aggr)에 그 월이 없다고 「예측값이 없다」로 답하지 않는다. "
    "연간 예측 도구에는 법인 축이 없으므로 법인(사단법인 등)을 물으면 그 사실을 밝히고 전체 기준 예측값을 제시한다.\n\n"
    "🔴 🆕 [O217 예측 우선순위] 개발 예측(익월·연말·향후 N개월)은 머신러닝 예측(analyst_ml_dvlp_forecast · 금액 만원)을 "
    "먼저 제시하고, MSTR 연도말 추세 참고치는 별도 참고 표로만 둔다(건수 예측은 없다고 밝힌다).\n\n"
)

RESPONSE_O217 = (
    "🔴 🆕 [O217 표기·마무리] ① 표·그래프의 기준년월·월 같은 날짜 값은 「2026년 9월」 형식으로 쓴다"
    "(2026-09·202609 표기를 쓰지 않는다 · 기간 범위는 「2026년 1월 - 2026년 9월」). "
    "② 답변 끝에 정기 리포트·자동 발송·예약 실행·자동화 설정을 권유하거나 「설정해 드릴까요?」라고 묻지 않는다. "
    "③ 드릴다운 제안은 「다음으로 볼 수 있는 기준: …」 한 줄로만 쓴다.\n\n"
)


def main():
    d = load(SRC)
    m = load(MEMBER)
    ins = d["instructions"]

    ins["system"] = sub_once(
        ins["system"],
        r"- 🔴🔴 \*\*캠페인별 LTV 는 한 표로 답할 수 없다\.\*\*.*?\(정본에 그 산식이 없다\)\.",
        LTV_RULE, "system LTV 금지 문단")
    ins["system"] = sub_once(
        ins["system"],
        r"· \*\*GA 전환수\(건\)\*\* = 어의 미확정이다\. \(명\)과 \(건\)을 같은 지표로 답하지 않는다\.",
        "· **GA 전환수(건)** = 🆕 [O217 사용자 결정 A] 「GA·일별리포트 개발건수」로 물으면 analyst_ad 의 "
        "GA 개발(건)(디지털 · 소수 포함)으로 답한다. (명)과 (건)을 같은 지표로 답하지 않는다.",
        "system GA 전환수")
    ins["orchestration"] = sub_once(
        ins["orchestration"],
        r"🔴 두 도구를 조인하지 말고 \*\*캠페인 축에서 표를 병기\*\*한다\.",
        "🔴 두 도구를 SQL 로 조인하지 말고 각각 호출한 뒤 **캠페인 축에서 결과값을 곱해** 회원 LTV 열을 만든다"
        "(🆕 O217 · system LTV 규칙).",
        "orchestration ⑤ LTV")
    ins["orchestration"] = ORCH_O217 + ins["orchestration"]
    ins["response"] = RESPONSE_O217 + ins["response"]

    names = [t["tool_spec"]["name"] for t in d["tools"]]
    add = [t for t in m["tools"]
           if t["tool_spec"]["name"] in ("analyst_mbrfee_prdt_actl", "analyst_spnsr_cls_aggr")
           and t["tool_spec"]["name"] not in names]
    if len(add) != 2:
        sys.exit("회원실 예측 도구 2종을 회원 spec 에서 찾지 못함")
    d["tools"].extend(add)
    for t in add:
        n = t["tool_spec"]["name"]
        d["tool_resources"][n] = m["tool_resources"][n]
    if "search_biz_definition" not in names:
        d["tools"].insert(0, {"tool_spec": {
            "type": "cortex_search",
            "name": "search_biz_definition",
            "description": (
                "🆕 [O217] 굿네이버스 비즈니스 정의 검색 — 현업 지표사전(공통·신규·추가)·지표 용어·조직(부서명·부서코드)·"
                "라우팅 결정(어느 도구·어느 SV 필드로 답하는지)·LTV/CAC 같은 확정 산식. "
                "원천=90_provided_definition 문서 → GN_DW.SERVING.BIZ_DEFINITION_CORPUS. "
                "「~가 뭐야」「~의 정의·계산식」「이 지표는 어느 데이터로 보나」 질문과, 낯선 지표·분류 이름을 만났을 때 사용. "
                "🔴 정의만 담는다 — 수치는 analyst 도구로만 낸다."),
        }})
        d["tool_resources"]["search_biz_definition"] = {
            "search_service": SEARCH_SERVICE,
            "id_column": "DOC_ID",
            "title_column": "TITLE",
            "max_results": 5,
        }

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# O217 개정안 = 15_O217_백업_AGENT_MARKETING_spec.yaml + tools/o217_patch_marketing_spec.py\n")
        yaml.safe_dump(d, f, allow_unicode=True, sort_keys=False, width=200)
    print("도구 수 =", len(d["tools"]), "· 출력 =", OUT)


if __name__ == "__main__":
    main()
