#!/usr/bin/env python3
# O207-B W5 후속 — 연도말/연말 개발 예측 라우팅 보강(3 Agent orchestration 선두) · 앵커 1회 강제
# Co-authored with CoCo
import io, sys
import yaml

BASE = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
MARK = '[O207-B 연도말 개발 예측 라우팅]'
RULE = ("🔴🔴 " + MARK + " 「연도말·연말·올해 말 개발 예측/전망/예측치」 질문은 **단위가 건수이거나 지정되지 않았을 때, "
        "또는 부서별·후원사업별·신규 개발을 물을 때 analyst_mstr_spnsr_dvlp 의 연도말 개발 추세 참고치(건)로 먼저 답한다** "
        "(부서별·전사 = 연도말 추세 테이블 · 후원사업별 = 후원사업별 연도말 추세 테이블 · 신규 = 개발구분 신규 · 목표 대비 % 는 부서·전사만). "
        "「후원사업별·부서별·신규 예측은 제공할 수 없다」고 답하지 않는다 — 그 말은 ML 개발금액 예측에만 해당한다. "
        "ML 개발금액 예측(만원 · 전사/캠페인 · analyst_ml_dvlp_forecast)은 사용자가 금액 예측을 물을 때 쓰고, "
        "건수 질문에는 별도 참고 표로만 덧붙이며 두 값을 섞거나 환산하지 않는다. ")


def once(s, old, new, label):
    n = s.count(old)
    if n != 1:
        sys.exit(f'🔴 {label}: 앵커 {n}회 (기대 1)')
    return s.replace(old, new, 1)


for a in ['AGENT_MEMBER', 'AGENT_MARKETING', 'AGENT_EXECUTIVE']:
    p = BASE % a
    s = io.open(p, encoding='utf-8').read()
    if MARK in s:
        print(a, 'skip'); continue
    q = "'" if "  orchestration: '" in s else '"'
    s = once(s, "  orchestration: " + q, "  orchestration: " + q + RULE, a)
    d = yaml.safe_load(s)
    assert MARK in d['instructions']['orchestration']
    print(a, 'max_line=%d' % max(len(l) for l in s.splitlines()))
    io.open(p, 'w', encoding='utf-8').write(s)
