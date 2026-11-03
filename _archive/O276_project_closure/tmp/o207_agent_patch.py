#!/usr/bin/env python3
# O207 W3·W4 — AGENT_MEMBER·MARKETING·EXECUTIVE 에 MSTR 개발 도구 배선 + 라우팅·교차 규칙 · 앵커 1회 일치 강제
# 사용: python3 tmp/o207_agent_patch.py [--dry]
# Co-authored with CoCo
import io, sys
import yaml

DRY = '--dry' in sys.argv
BASE = '/workspace/cortex_project/agents/%s/agent_spec.yaml'
MARK = '[O207 MSTR 개발 정본]'

RULE = ("🔴🔴 " + MARK + " 개발 실적(개발(건)·개발(명)·후원금액)을 부서(구분_팀·본부/지부·팀/지부·부서)·캠페인·상위캠페인·후원사업·"
        "신규기존·후원기간대·후원금액대·결제수단·회원구분·시도·중단/감액 사유·직전캠페인 축으로 묻는 질문과, "
        "부서별 개발 목표·달성률·연도말 개발 예측(전망) 질문은 **analyst_mstr_spnsr_dvlp**(MSTR 기준 · 현업 검증 로직)를 먼저 쓴다. "
        "답변에 「MSTR 기준」을 밝히고 「MSTR 개발(건) = 후원금액 ÷ 10,000」을 처음 한 번 각주로 단다. "
        "연도말 개발 예측은 「추세 참고치(모델 예측 아님 · 마감월 실적 + 남은 월 × 직전 3개월 평균)」로 밝힌다. "
        "🔴 [O207 교차 규칙] MSTR 에 없는 축(캠페인카테고리·개발인입경로·국내해외·UTM·회비·발송·행사·코호트·GA·ML 예측)이나 "
        "개발 × 그 축 교차 질문은 기존 GN_DW 도구로 답하고 표 제목에 「GN_DW 기준」을 단다. "
        "🔴🔴 MSTR 기준과 GN_DW 기준 수치를 한 표에서 합산·차감·비율 계산하지 않는다 — 두 기준이 함께 필요하면 표를 나누고 기준을 각각 밝힌다. "
        "ML 개발금액 예측(만원 · 전사/캠페인)과 MSTR 연도말 추세 참고치(건 · 부서)는 다른 지표이므로 섞지 않는다. ")

TOOL = """- tool_spec:
    type: cortex_analyst_text_to_sql
    name: analyst_mstr_spnsr_dvlp
    description: '🆕 [O207] MSTR 정기회원 후원개발(개발 실적의 정본 · 현업 검증 로직). 원천=CRM(eCRM) → GN_DW.BRONZE_CRM → GN_DW.MSTR(MSTR 이관 프로시저) → SERVING.MSTR_SPNSR_DVLP_V·MSTR_DVLP_GOAL_V·MSTR_DVLP_YE_TREND_V.
      활성 지표: 개발(건)(= 후원금액 ÷ 10,000 · 소수 4자리) · 개발(명)(비가산) · 후원금액(원) · 월 목표(건)·실적·목표 달성률(%) · 연 목표·마감월 누적 실적·연도말 개발 추세 참고치(건 · 모델 예측 아님)·연 목표 대비 추세(%).
      차원: 기준년월·개발구분·법인·구분_팀·본부/지부·팀/지부·부서·브랜드·상위캠페인·캠페인·홍보방법·후원사업·후원사업2·성별·연령대·신규기존구분·후원기간대·후원금액대·결제수단·회원구분·시도·후원약칭·중단/감액 사유·직전캠페인.
      🔴 MSTR 기준이다 — GN_DW 도구 수치와 한 표에 합산하지 않는다. 🔴 실질 목표는 신규만 있다. 🔴 개발구분 미지정 시 신규·증액·재후원으로 한정한다.'
"""
RES = """  analyst_mstr_spnsr_dvlp:
    semantic_view: GN_DW.SERVING.SV_MSTR_SPNSR_DVLP
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
"""
AUX = ("🆕 [O207] 개발 실적·목표·연도말 전망의 정본은 analyst_mstr_spnsr_dvlp(MSTR 기준)다 — 이 도구의 개발 지표는 "
       "MSTR 에 없는 축(캠페인카테고리·개발인입경로 등)과 교차 분석용 보조이며 답변에 「GN_DW 기준」을 단다. ")
AUX_TOOLS = ['analyst_member_event', 'analyst_dev_achievement', 'analyst_dvlp_goal_acmslt']


def once(s, old, new, label):
    n = s.count(old)
    if n != 1:
        sys.exit(f'🔴 {label}: 앵커 {n}회 (기대 1)')
    return s.replace(old, new, 1)


for a in ['AGENT_MEMBER', 'AGENT_MARKETING', 'AGENT_EXECUTIVE']:
    p = BASE % a
    s = io.open(p, encoding='utf-8').read()
    if MARK in s:
        print(a, '이미 적용 — skip')
        continue
    q = "'" if "  orchestration: '" in s else '"'
    s = once(s, "  orchestration: " + q, "  orchestration: " + q + RULE, a + ' orchestration')
    s = once(s, '\ntools:\n', '\ntools:\n' + TOOL, a + ' tools')
    s = once(s, '\ntool_resources:\n', '\ntool_resources:\n' + RES, a + ' tool_resources')
    for t in AUX_TOOLS:
        for dq in ("'", '"'):
            anchor = f"    name: {t}\n    description: {dq}"
            if anchor in s:
                s = once(s, anchor, anchor + AUX, f'{a} {t}')
    d = yaml.safe_load(s)
    names = [x['tool_spec']['name'] for x in d['tools']]
    assert names.count('analyst_mstr_spnsr_dvlp') == 1 and 'analyst_mstr_spnsr_dvlp' in d['tool_resources'] and MARK in d['instructions']['orchestration']
    print(a, 'tools=%d' % len(names), 'aux=%d' % sum(AUX in (x['tool_spec'].get('description') or '') for x in d['tools']),
          'max_line=%d' % max(len(l) for l in s.splitlines()))
    if not DRY:
        io.open(p, 'w', encoding='utf-8').write(s)
print('DRY' if DRY else 'WRITTEN')
