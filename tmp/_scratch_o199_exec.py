import io
p = '/workspace/cortex_project/agents/AGENT_EXECUTIVE/agent_spec.yaml'
s = io.open(p, encoding='utf-8').read()
R = [
 ("**[2026-08-14 O74] 머신러닝 예측 도구 4종 라우팅**", "**[2026-08-14 O74 · O199 3종] 머신러닝 예측 도구 3종 라우팅**"),
 ("  - question: 상위캠페인(채널)별 회원평균 LTV 예측 상위 10곳은? (예측)\n  - question: 캠페인별 후원총액 LTV 스코어 상위 10곳은? (예측)\n",
  "  - question: 마케팅채널별 회원평균 후원금액 예측 상위 10곳은? (예측)\n  - question: 캠페인별 월간 후원금액 예측 상위 10곳은? (예측)\n"),
 ("· 예측 도구\\\n    \\ 4종 = ", "· 예측 도구\\\n    \\ 3종 = "),
 ("`analyst_ml_ltv_forecast`(LTV 월별 예측 · 원) · `analyst_ml_ltv_score`(LTV\\\n    \\ 스코어 · 원) · `analyst_ml_feature_importance`",
  "`analyst_ml_ltv_forecast`(LTV 월별 예측 · 원 · 마케팅채널 회원평균 / 캠페인 월간 후원금액) · \U0001F534 LTV 스코어는 원천 폐기(O198)로 미제공 · `analyst_ml_feature_importance`"),
 ("\\ 계열이다** — 경로는", "\\ 계열이다(O199 = 3종)** — 경로는"),
 ("  analyst_ml_ltv_score:\n    execution_environment:\n      type: warehouse\n      warehouse: GN_DW_ANALYTICS_WH\n    semantic_view: GN_DW.SERVING.SV_ML_LTV_SCORE\n", ""),
]
for a, b in R:
    n = s.count(a)
    print(n, a[:40].replace('\n', '|'))
    assert n == 1, a
    s = s.replace(a, b)
# LTV forecast tool description + drop ltv_score tool
a0 = s.index("- tool_spec:\n    description: 'ML LTV 월별 예측 2종")
a1 = s.index("- tool_spec:\n    description: 'ML 요인분석")
new_ltv = """- tool_spec:
    description: 'ML LTV 월별 예측 2종(grain=기준월×LTV유형×계열×예측월). 원천=GN_DW.ML → SERVING.ML_LTV_FORECAST_V. 🔴🔴 예측치이며 실적이 아니다. 🔴 머신러닝은
      테스트 단계다. 🔴 단위는 원이다(개발금액 예측의 만원과 다르다). 활성 지표: 예측 평균·합계·신뢰구간·예측 개월수·계열수. 차원: 기준월·**LTV유형**·계열코드·계열명·예측월.
      "마케팅채널별 회원평균 후원금액 예측"·"채널별 LTV 예측"·"캠페인별 월간 후원금액 예측" 류 질문에 사용. 🔴🔴 **LTV유형을 반드시 하나로 고정한다** —
      ''MKTG_CHANNEL_AVG_MEMBER''는 **마케팅채널의 회원 1인당 평균 후원금액** 예측이고 ''CMPGN_TOTAL''은 **캠페인의 월간 후원금액 총액** 예측이다.
      의미·자리수·계열 축(마케팅채널 ↔ 캠페인)이 달라 두 유형을 한 표에 섞거나 순위를 함께 매기면 반드시 틀린다. 🔴 「채널별」 질문은 MKTG_CHANNEL_AVG_MEMBER,
      「캠페인별」 질문은 CMPGN_TOTAL 로 답한다(원천은 두 테이블 모두 계열 컬럼을 채널로 이름 붙였으나 CMPGN_TOTAL 쪽 값은 캠페인코드다 · 원천 확인 중).
      🔴 **회원평균 유형에서는 합산하지 않는다**(1인당 평균의 합은 의미가 없다) — 평균 지표를 쓴다. 🔴 LTV 스코어·과거 누적 LTV·상위캠페인 LTV 는 원천 폐기(O198)로
      제공하지 않는다 — 수치를 만들지 말고 이 도구의 월별 예측을 대안으로 안내한다.'
    name: analyst_ml_ltv_forecast
    type: cortex_analyst_text_to_sql
"""
s = s[:a0] + new_ltv + s[a1:]
a = "**피처 목록은 사람이 지정한 후보다**(피처유형 전건 ''user_provided'')"
assert s.count(a) == 1
s = s.replace(a, "**피처 목록은 사람이 지정한 후보다**(피처유형 ''user_provided'' · 신규 후원 유치 요인은 원천에서 유형 컬럼이 제거돼 비어 있다 · O199)")
assert 'ltv_score' not in s and 'LTV_SCORE' not in s and 'UCMPGN' not in s
io.open(p, 'w', encoding='utf-8').write(s)
print('ok', s.count('tool_spec'))
