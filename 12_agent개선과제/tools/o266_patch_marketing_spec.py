# O266 — AGENT_MARKETING spec 개정 생성기(현업 피드백 1~4)
# 입력 = tmp/o266/live_AGENT_MARKETING.yaml (개발계 ZS83821 VERSION$3 export · 정본 cortex_project 와 불일치 키 0 실측)
# 출력 = cortex_project/agents/AGENT_MARKETING/agent_spec.yaml (정본 갱신 · 적용 = o217_agent_io.py apply)
# 원칙: 정해진 치환·추가만 한다 · 치환 대상이 없으면 실패(조용한 무변경 금지) · 재실행해도 중복 추가하지 않는다
# Co-authored with CoCo
import os
import sys

import yaml

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(BASE, "tmp", "o266", "live_AGENT_MARKETING.yaml")
OUT = os.path.join(BASE, "cortex_project", "agents", "AGENT_MARKETING", "agent_spec.yaml")
WH = "GN_DW_ANALYTICS_WH"
TOOL = "analyst_mktg_campaign_cost"
TAG = "[O266]"

NEW_TOOL_DESC = (
    "🆕 [O266] 마케팅캠페인별 광고비·디지털 최종정산금액·제작비·개발(건) 한 표 전용(SV_MKTG_CAMPAIGN_COST · "
    "grain=마케팅캠페인×연월). 원천=대행사 광고(FACT_AD_PERFORMANCE) · 지출결의(FACT_EXPENSE_RESOLUTION · 세부캠페인코드 기재분) · "
    "MSTR 개발(F_MM_SPNSR_DVLP_SUM) → GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST. 지표: 광고비(출처유형 3분해) · 디지털 최종정산금액 · "
    "제작비 · 개발(건)(MSTR) · 신규 개발(건) · 개발단가(광고비 ÷ MSTR 개발건) · 제작비 포함 개발단가. 차원: 연월 · 연도 · 마케팅캠페인명 · "
    "캠페인카테고리(대표값) · UTM. 🔴 「마케팅캠페인별 광고비/개발건수/제작비」·「캠페인 투입 대비 개발」은 이 도구 1회로 답한다(다른 도구 결과를 손으로 붙이지 않는다). "
    "🔴 마케팅채널·인입경로별 비용은 없다. 🔴 제작비 = 코드 기재분만 · 개발(건) = MSTR 기준."
)
AD_DESC_ADD = (
    " 🆕 [O266] 디지털 최종정산금액(광고비+마크업+부가세 · DIGITAL 전용) 지표 AD_SETTLE_AMT — 「광고비」 질문에는 광고비와 나란히 보인다."
)
ORCH_ANCHOR = "  · ⑤ 캠페인별 LTV → 활동기간은 analyst_member_cohort, 납입회비는 analyst_member_fee."
ORCH_ADD = (
    "  · 🆕 [O266] ⑥ 마케팅캠페인별 광고비·개발(건)·제작비(한 표 · 투입 대비 개발) → analyst_mktg_campaign_cost **단일 호출**. "
    "「광고와 개발은 축이 달라 연결할 수 없다」고 답하지 않는다 — 마케팅캠페인 축으로 이미 결합돼 있다(미매핑 행은 그대로 보인다).\n"
    "  · 🆕 [O266] 광고비 질문(analyst_ad)은 광고비와 디지털 최종정산금액(AD_SETTLE_AMT)을 같은 표에 나란히 낸다 — 정산액은 디지털 전용이다.\n"
    "  · 🆕 [O266] 캠페인별 활동율·개발 등에서 마케팅캠페인명·마케팅채널을 물으면 analyst_campaign_monthly 의 마케팅캠페인·마케팅채널 차원을 그대로 쓴다 "
    "(기준연월 하나 고정). 검증 오류가 나면 같은 도구로 한 번 더 시도하고 「조회되지 않는다」고 답하지 않는다.\n"
)
LTV_RULE = (
    "  · 🆕 [O266] **LTV(실적) 질문은 반드시 도구를 호출한다**(정의 검색만으로 답하지 않는다) — analyst_member_cohort 의 "
    "EXP_TENURE_MONTHS_CAP(유지개월(상한))·EXP_TENURE_MONTHS_UNLIMITED(유지개월(무기한))를 축값별 같은 행으로 조회하고 "
    "analyst_member_fee 의 월평균 납입회비를 조회한 뒤 표 하나로 낸다. 무기한 = 관측 최대월과 상한 중 긴 창(항상 상한 이상). "
    "표 열 = 구분 · 유지개월(상한 80) · 유지개월(무기한) · 월평균 납입회비(원) · LTV(상한 80, 원) · LTV(무기한, 원) "
    "(LTV = 월평균 납입회비 × 유지개월). 상한 값이 80 이 아니면 열 이름의 숫자를 실제 상한으로 바꾼다.\n"
)
RESP_ADD = (
    "\n🆕 [O266] 표 형식 고정: ① 광고비 표에는 「광고비(원)」 옆에 「디지털 최종정산금액(원)」 열을 둔다(디지털 외 출처는 빈칸 · 0 금지). "
    "② LTV 표 열 순서 = 구분 · 유지개월(상한 80) · 유지개월(무기한) · 월평균 납입회비(원) · LTV(상한 80, 원) · LTV(무기한, 원). "
    "③ 마케팅캠페인별 비용·개발 표 열 순서 = 마케팅캠페인명 · 광고비(원) · 디지털 최종정산금액(원) · 제작비(원) · 개발(건) · 개발단가(원) — "
    "표 밖에 「제작비 = 세부캠페인코드 기재분만」「개발(건) = MSTR 기준」을 1줄씩 밝힌다."
)


def load(p):
    with open(p, encoding="utf-8") as f:
        return yaml.safe_load("".join(l for l in f if not l.startswith("# O2")))


def main():
    d = load(SRC)
    names = [t["tool_spec"]["name"] for t in d["tools"]]
    if TOOL in names:
        sys.exit("이미 적용됨: " + TOOL)
    # ① 도구 추가(analyst_campaign_monthly 뒤)
    i = names.index("analyst_campaign_monthly")
    d["tools"].insert(i + 1, {"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": TOOL, "description": NEW_TOOL_DESC}})
    d["tool_resources"][TOOL] = {
        "semantic_view": "GN_DW.SERVING.SV_MKTG_CAMPAIGN_COST",
        "execution_environment": {"type": "warehouse", "warehouse": WH},
    }
    # ② analyst_ad 설명 보강
    ad = [t for t in d["tools"] if t["tool_spec"]["name"] == "analyst_ad"]
    if len(ad) != 1:
        sys.exit("analyst_ad 판정 실패")
    ad[0]["tool_spec"]["description"] = ad[0]["tool_spec"]["description"].rstrip() + AD_DESC_ADD
    # ③ orchestration — ⑤ LTV 줄 앞에 LTV 규칙, 그 다음 블록에 ⑥ 라우팅
    o = d["instructions"]["orchestration"]
    if o.count(ORCH_ANCHOR) != 1:
        sys.exit("치환 대상 없음: orchestration ⑤ LTV 앵커")
    j = o.index(ORCH_ANCHOR)
    k = o.index("\n", o.index("\n", j) + 1) + 1   # ⑤ 줄 + 다음 줄(🔴 두 도구를 SQL 로 조인하지 말고 …) 뒤
    d["instructions"]["orchestration"] = o[:k] + LTV_RULE + ORCH_ADD + o[k:]
    # ④ response — 표 형식 고정
    d["instructions"]["response"] = d["instructions"]["response"].rstrip() + RESP_ADD
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# O266 개정안 = tmp/o266/live_AGENT_MARKETING.yaml + 12_agent개선과제/tools/o266_patch_marketing_spec.py\n")
        yaml.safe_dump(d, f, allow_unicode=True, sort_keys=False, width=200)
    print("ok 도구 수 =", len(d["tools"]), "→", OUT)


if __name__ == "__main__":
    main()
