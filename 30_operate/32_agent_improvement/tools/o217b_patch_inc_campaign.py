# O217-B — AGENT_MARKETING spec 증액 예측 × 마케팅캠페인 배선
# 입력 = 12_agent개선과제/17_O217_AGENT_MARKETING_spec.yaml (O217-A 개정안 · 계정 무관)
# 출력 = 12_agent개선과제/19_O217B_AGENT_MARKETING_spec.yaml
# 원칙: 지침 본문에는 한 문단만 더한다(규칙 상세 = 코퍼스 RT-19 · 지침 길이 충돌 완화) ·
#       기존 「캠페인 추천 축 없음」 2곳은 새 도구와 모순이므로 치환한다 · 치환 대상이 없으면 실패
# Co-authored with CoCo
import os
import sys

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from o217_patch_marketing_spec import BASE, WH, load, sub_once  # noqa: E402

SRC = os.path.join(BASE, "17_O217_AGENT_MARKETING_spec.yaml")
OUT = os.path.join(BASE, "19_O217B_AGENT_MARKETING_spec.yaml")
TOOL = "analyst_ml_inc_campaign"

ORCH = (
    "🔴🔴 🆕 [O217-B 증액 예측 · 코퍼스 RT-19] 「N월 증액(개발)이 높을 것으로 예상되는 마케팅캠페인·공통브랜드·"
    "마케팅채널·캠페인카테고리」는 머신러닝 증액 예측이 있다 — **analyst_ml_inc_campaign** 으로 예측 표를 만들고"
    "(기대 증액 회원수 · 평균 증액확률 · 구성비), 실적(1~N월 증액개발 건·구성비)은 analyst_mstr_spnsr_dvlp 로 표를 나눠 둔다. "
    "🔴 직전 3개월 평균(추세 참고치)으로 대신하거나 「머신러닝 예측이 아니다」라고 답하지 않는다. "
    "🔴 ① 핵심 요약에 「머신러닝 증액 예측(회원 단위 확률을 캠페인에 모은 값 · N월 건수 예측 아님)」을 한 번 밝힌다.\n\n"
)
DESC = (
    "🆕 [O217-B] ML 회원 증액 예측 × MSTR 마케팅캠페인 귀속(grain=기준월×회원). 원천=GN_DW.ML.ML_RST_DATA_MBER_INC_12M → "
    "SERVING.ML_MEMBER_RISK_V → SERVING.ML_INC_BY_MKTG_CMPGN_V(귀속 = 그 해 MSTR 최근 개발 1건의 마케팅캠페인). "
    "활성 지표: 예측 대상 회원수(명) · 기대 증액 회원수(명 · 증액확률 합) · 평균 증액확률 · 모델 증액분류 회원수. "
    "차원: 기준월 · 마케팅캠페인 · 공통브랜드 · 마케팅채널 · 캠페인카테고리 · 귀속 여부. "
    "「증액이 높을 것으로 예상되는 캠페인」「다음 달 증액 예측 상위 캠페인」 질문에 사용. "
    "🔴🔴 예측치이며 실적이 아니다 — MSTR 증액 실적과 한 표에 합산하지 않는다. 🔴 「N월 증액 건수」 예측이 아니다(회원 확률의 합). "
    "🔴 기준월 미지정 시 최신 기준월 하나. 🔴 귀속 불가(마케팅캠페인 NULL) 회원수를 함께 밝힌다. 🔴 머신러닝은 테스트 단계다."
)
OLD_ORCH = r"/ \*\*증액 가능성 높은 회원·증액 캠페인 제안 대상\*\* → analyst_ml_member_risk\(증액 확률 순 · 캠페인 추천 축 없음\)\."
NEW_ORCH = ("/ **증액 가능성 높은 회원** → analyst_ml_member_risk(증액 확률 순) · "
            "**증액이 높을 마케팅캠페인** → analyst_ml_inc_campaign(🆕 O217-B).")
OLD_DESC = (r"🔴 \*\*캠페인별 추천은 없다\*\* — 모델에 캠페인 축이 없으므로 「어떤 캠페인에 넣을지」는 데이터에서 조회되지 않는다고 "
            r"밝히고 회원 목록만 제시한다\.")
NEW_DESC = ("🔴 이 도구에는 캠페인 축이 없다 — 「증액이 높을 마케팅캠페인」은 analyst_ml_inc_campaign(🆕 O217-B · "
            "회원 예측을 MSTR 마케팅캠페인에 귀속)으로 답한다.")


def main():
    d = load(SRC)
    if any(t["tool_spec"]["name"] == TOOL for t in d["tools"]):
        sys.exit("이미 배선됨: " + TOOL)
    ins = d["instructions"]
    ins["orchestration"] = sub_once(ins["orchestration"], OLD_ORCH, NEW_ORCH, "orchestration O198 증액")
    ins["orchestration"] = ORCH + ins["orchestration"]
    risk = next(t for t in d["tools"] if t["tool_spec"]["name"] == "analyst_ml_member_risk")
    risk["tool_spec"]["description"] = sub_once(
        risk["tool_spec"]["description"], OLD_DESC, NEW_DESC, "member_risk 캠페인 추천 없음")
    d["tools"].append({"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": TOOL, "description": DESC}})
    d["tool_resources"][TOOL] = {
        "semantic_view": "GN_DW.SERVING.SV_ML_INC_CAMPAIGN",
        "execution_environment": {"type": "warehouse", "warehouse": WH},
    }
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# O217 개정안(B) = 17_O217_AGENT_MARKETING_spec.yaml + tools/o217b_patch_inc_campaign.py\n")
        yaml.safe_dump(d, f, allow_unicode=True, sort_keys=False, width=200)
    print("도구 수 =", len(d["tools"]), "· 출력 =", OUT)


if __name__ == "__main__":
    main()
