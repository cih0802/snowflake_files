# O246 — AGENT_MEMBER spec: 회비 예측 배분 추정(FA) 라우팅 · 특성 폴백 문안 · 질문 예시 2
import io, shutil
p = '/workspace/cortex_project/agents/AGENT_MEMBER/agent_spec.yaml'
R = [
 ("예측 대상 카테고리가 전체 카테고리와 같다고 단정하지 말 것.",
  "예측 대상 카테고리가 전체 카테고리와 같다고 단정하지 말 것. 🆕 [O246] 「후원사업별·마케팅캠페인명별·공통브랜드별 회비 예측」 = 같은 SV 의 FA 표(배분 추정) — ALLOC_AXIS 를 1개로 필터하고 최신 기준월 1개로 한정한다. 🔴 모델 예측치가 아니라 「카테고리 예측 × 직전 12개월 회비 납입 비중」 배분 추정치이므로 표 제목에 [실적 비중 배분 추정치 · 모델 예측 아님] 을 붙이고, (실적 비중 없음) 행(일시 등 회비 실적 없는 카테고리)을 숨기지 않는다. 세 축을 서로 더하지 않는다."),
 ("이후 기간 회비 예측은 analyst_ml_fee_forecast(캠페인카테고리)로",
  "이후 기간 회비 예측은 analyst_ml_fee_forecast(캠페인카테고리 · 🆕 [O246] 후원사업·마케팅캠페인명·공통브랜드 = 배분 추정)로"),
 ("세부캠페인별 다음 달 회비 = analyst_member_fee 직전 3개월 평균",
  "세부캠페인별 다음 달 회비 = analyst_member_fee 직전 3개월 평균 · 🆕 [O246] 단 후원사업·마케팅캠페인명·공통브랜드별 회비 전망은 추세 참고치보다 analyst_ml_fee_forecast 배분 추정을 먼저 쓴다"),
 ("(미매칭) 회원수를 따로 적는다.",
  "(미매칭) 회원수를 따로 적는다. 🆕 [O246] 후원금액대·유지기간·신규기존·납입방식은 기준월 실적 행이 없으면 직전 12개월 내 최근 월 값으로 채운다(ATTR_FALLBACK = TRUE · 고위험군 대부분) — 이 값은 「직전 실적 월 기준」임을 각주로 밝힌다."),
 ("  sample_questions:\n",
  "  sample_questions:\n  - question: 최신 기준월 기준 향후 12개월 회비 예측을 후원사업별로 보여줘\n  - question: 내년 회비 예측을 마케팅캠페인명별·공통브랜드별 상위 10개로 보여줘\n"),
]
s = io.open(p, encoding='utf-8', newline='').read()
for a, b in R:
    assert s.count(a) == 1, a[:30]
    s = s.replace(a, b)
shutil.copyfile(p, '/workspace/tmp/o246/AGENT_MEMBER_agent_spec.yaml.before')
io.open(p, 'w', encoding='utf-8', newline='').write(s)
import yaml; y = yaml.safe_load(s); print('yaml ok', len(y['instructions']['sample_questions']), len(y['tools']))
