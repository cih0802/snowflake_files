#!/usr/bin/env python3
"""O250-B · 3 Agent 스펙에 7축 예측 도구 배선(부분 치환 · 앵커 1회 일치 검증 · 해시 2회 확인)."""
import hashlib
import sys
import time
from pathlib import Path

ROOT = Path("/workspace/cortex_project/agents")

PRED_SPEC = """- tool_spec:
    type: cortex_analyst_text_to_sql
    name: analyst_ml_pred_axis
    description: '🆕 [O250] ML 회원예측(중단·증액) + 미납 실적 × 7축(grain=기준월×회원×7축 조합). 원천=GN_DW.ML → SERVING.ML_MEMBER_RISK_V · ML_SPONSOR_RISK_V · CRM → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN(기준월 말 활동 약정) → SERVING.ML_MEMBER_PRED_AXIS_V. 차원: 기준월 · 회원번호 · 신규기존 · 본부지부(본부/지부/기타 · 원값 8종 = 본부지부 원값) · 후원사업 · 법인(통합/사단/사복) · 공통브랜드 · 캠페인카테고리 · 마케팅캠페인명 · 중단위험 등급 · 후원건 이탈 등급 · 기준월 미납 여부. 지표: 예측 대상 회원수 · 중단 고위험 회원수 · 기대 중단 회원수 · 평균 중단확률 · 기대 증액 회원수 · 평균 증액확률 · 기준월 미납 회원수 · 미납 중 중단 고위험 회원수 · 활동 약정 수. 「증액·중단·미납 예측을 마케팅캠페인명·법인·본부지부·신규기존·후원사업·공통브랜드별(여러 축 조합 포함)」 질문의 정본 도구다. 🔴🔴 예측치이며 실적이 아니다(미납 지표만 실적). 🔴 미납 예측 모델은 없다 — 실적 미납 × 중단 예측으로 답하고 밝힌다. 🔴 회원당 여러 행 — 회원수는 중복제거 · 기대 회원수는 가중합(어느 축으로 나눠도 합 = 전체). 🔴 축 = 활동 약정 기준 — MSTR 개발 귀속 기준 증액(analyst_ml_inc_campaign)과 다르다. 🔴 기준월 미지정 시 최신 하나. 🔴 머신러닝은 테스트 단계다.'
"""

FEE_SPEC = """- tool_spec:
    type: cortex_analyst_text_to_sql
    name: analyst_ml_fee_axis
    description: '🆕 [O250] ML 캠페인카테고리 회비 예측 × 7축 실적 비중 배분 추정(grain=기준월×카테고리×예측월×7축 조합). 원천=GN_DW.ML → SERVING.ML_FEE_FORECAST_V · CRM → GOLD.WIDE_MEMBER_FEE × FACT_MEMBER_SPONSORSHIP_SPAN → SERVING.ML_FEE_FORECAST_AXIS_V. 차원: 기준월 · 예측월 · 캠페인카테고리 · 신규기존 · 본부지부(3분류 · 원값 8종) · 후원사업 · 법인 · 공통브랜드 · 마케팅캠페인명 · 배분 여부. 지표: 배분 추정 회비(원) · 하한 · 상한. 「회비 예측을 마케팅캠페인명·법인·본부지부·신규기존·후원사업·공통브랜드별(여러 축 조합 포함)」 질문의 정본 도구다. 🔴🔴 모델 예측은 캠페인카테고리 단위뿐이다 — 7축 값은 직전 12개월 실적 비중 배분 추정치이며 「본 값은 회비 예측 머신러닝 데이터를 기반으로 실적 비중을 적용한 추정치입니다」를 밝힌다. 🔴 배분 불가(실적 비중 없음) 금액을 따로 밝힌다. 🔴 단위 = 원. 🔴 기준월 여러 개 합산 금지. 🔴 회비 실적과 한 표에 합산하지 않는다.'
"""

PRED_RES = """  analyst_ml_pred_axis:
    semantic_view: GN_DW.SERVING.SV_ML_MEMBER_PRED_AXIS
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
"""
FEE_RES = """  analyst_ml_fee_axis:
    semantic_view: GN_DW.SERVING.SV_ML_FEE_FORECAST_AXIS
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
"""

RULE_BOTH = ("🔴🔴 [O250 7축 예측] 「증액·중단·미납 예측」을 신규기존·본부지부(부서구분)·후원사업·법인(사단법인)·공통브랜드·캠페인카테고리·"
             "마케팅캠페인명 중 하나 이상(조합 포함)으로 나눠 묻는 질문은 analyst_ml_pred_axis 1회로 답한다 · 「회비 예측」을 같은 축으로 묻는 질문은 "
             "analyst_ml_fee_axis 1회로 답한다(배분 추정치 라벨). 🔴 「캠페인카테고리까지만 볼 수 있다」·「마케팅캠페인명 축이 없다」고 답하지 않는다. "
             "축이 캠페인카테고리·후원사업뿐이면 기존 도구(analyst_ml_churn_campaign)도 쓸 수 있으나 마케팅캠페인명·법인·본부지부·신규기존이 들어가면 "
             "반드시 7축 도구를 쓴다. 증액이 높을 마케팅캠페인을 「MSTR 개발 귀속 기준」으로 물으면 analyst_ml_inc_campaign 이다(두 기준을 한 표에 합산하지 않는다).")
RULE_PRED = ("🔴🔴 [O250 7축 예측] 「증액·중단·미납 예측」을 신규기존·본부지부(부서구분)·후원사업·법인(사단법인)·공통브랜드·캠페인카테고리·"
             "마케팅캠페인명 중 하나 이상(조합 포함)으로 나눠 묻는 질문은 analyst_ml_pred_axis 1회로 답한다. 🔴 「캠페인카테고리까지만 볼 수 있다」·"
             "「마케팅캠페인명 축이 없다」고 답하지 않는다. 회비 예측의 7축 분해는 회원 분석·마케팅 분석 Agent 를 안내한다.")

OLD_CHURN = "🔴 캠페인카테고리 외의 개별 캠페인명·마케팅캠페인 축은 없다."
NEW_CHURN = "🔴 이 도구에는 마케팅캠페인명·법인·본부지부·신규기존 축이 없다 — 그 축은 analyst_ml_pred_axis(🆕 O250)로 답한다."

PLAN = {
    "AGENT_MEMBER": (PRED_SPEC + FEE_SPEC, PRED_RES + FEE_RES, RULE_BOTH),
    "AGENT_MARKETING": (PRED_SPEC + FEE_SPEC, PRED_RES + FEE_RES, RULE_BOTH),
    "AGENT_EXECUTIVE": (PRED_SPEC, PRED_RES, RULE_PRED),
}


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def once(text, anchor, label):
    n = text.count(anchor)
    if n != 1:
        sys.exit(f"🔴 {label}: 앵커 {n}회 일치(1회여야 한다) — 중단")


ok = True
for agent, (specs, res, rule) in PLAN.items():
    p = ROOT / agent / "agent_spec.yaml"
    h1 = sha(p)
    time.sleep(1)
    if sha(p) != h1:
        sys.exit(f"🔴 {agent}: 해시 불안정 — 중단(R1-7-2)")
    t = p.read_text(encoding="utf-8")
    if "analyst_ml_pred_axis" in t:
        print(f"⚪ {agent}: 이미 배선됨 — skip")
        continue
    once(t, "\ntool_resources:\n", agent + " tool_resources")
    t = t.replace("\ntool_resources:\n", "\n" + specs + "tool_resources:\n", 1)
    if not t.endswith("\n"):
        t += "\n"
    t += res
    # orchestration 규칙 = 문자열 선두에 삽입(따옴표 형식별)
    sq = "\n  orchestration: '"
    dq = '\n  orchestration: "'
    if t.count(sq) == 1:
        t = t.replace(sq, sq + rule + " ", 1)
    elif t.count(dq) == 1:
        t = t.replace(dq, dq + rule + "\\n\\n", 1)
    else:
        sys.exit(f"🔴 {agent}: orchestration 앵커 없음 — 중단")
    if OLD_CHURN in t:
        once(t, OLD_CHURN, agent + " churn 문구")
        t = t.replace(OLD_CHURN, NEW_CHURN, 1)
    p.write_text(t, encoding="utf-8")
    back = p.read_text(encoding="utf-8")
    good = back == t and back.count("name: analyst_ml_pred_axis") == 1
    ok &= good
    print(("🟢" if good else "🔴"), agent, "bytes", len(back.encode("utf-8")))
sys.exit(0 if ok else 1)
