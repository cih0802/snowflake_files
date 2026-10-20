# O246-B — Agent 3종 spec 보강: 예측 × 실적 조합 답변 표준 · 회원 브리지 도구 · 개발예측 배분 라우팅
import io, re, shutil, yaml
D = '/workspace/cortex_project/agents/'
RULE = ('🔴🔴 [O246-B 예측 × 실적 조합 답변 표준] '
        '① 예측 모델이 직접 주지 않는 축·지표를 물으면 거절하기 전에 실적 매핑으로 답할 수 있는지 먼저 본다 — '
        '회원 단위 예측의 실적 축·실적 상태 = analyst_ml_member_bridge · '
        '회비·개발 예측의 후원사업·마케팅캠페인명·공통브랜드(·채널) 분해 = 각 예측 도구의 배분 표. '
        '② 값마다 라벨을 붙인다 — 예측치(모델 산출) / 매칭 집계(예측 결과를 실적 특성으로 나눈 값) / '
        '추정치(실적 비중·확률 합 적용). 추정치는 표 제목 또는 각주에 '
        '「본 값은 ○○ 예측 데이터를 기반으로 실적 비중(또는 확률)을 적용한 추정치이며 모델 예측치가 아닙니다」를 쓴다. '
        '③ 미납·활동 예측 모델은 없다 — 활동 유지 기대 회원수·회비 위험액(브리지 추정)과 실적 미납 현황으로 답하고, '
        '그래도 없으면 추세 참고치 규칙을 따른다. '
        '④ 결과에서 (미매칭) 또는 NULL 축 비중이 절반 이상이면 그대로 내지 말고 보완값(직전 실적 월 · 대표 약정 · 종료 약정)으로 '
        '다시 집계해 제시하고, 보완 기준과 보완 전·후 미매칭 비중을 각주로 밝힌다. 절반 미만이면 (미매칭)을 별도 행으로 둔다. '
        '⑤ 보완해도 불가능한 것은 사유를 한 문장으로 밝힌다 — 일시후원 전환 예측의 캠페인카테고리·연령대·지역·회원상태(원천 값 없음) · '
        '예측 지평 개월 수(원천 확인 중). ')
TOOL = ("- tool_spec:\n    type: cortex_analyst_text_to_sql\n    name: analyst_ml_member_bridge\n    description: '"
        'ML 회원 단위 예측(중단·증액·충성) × 실적 축·실적 상태 브리지(grain=기준월×회원). '
        '원천=GN_DW.ML → SERVING.ML_MEMBER_RISK_V + GOLD 실적(약정 기간·회비·MSTR 개발) → SERVING.ML_MEMBER_PRED_BRIDGE_V. '
        '「중단·증액·충성 예측 회원을 마케팅캠페인명·공통브랜드·UTM·유입경로·후원사업별로」 · '
        '「중단 고위험 회원의 미납·회비·개발 실적」 · 「예상 활동회원·기대 중단 회원수·회비 위험액」 질문에 사용. '
        '🔴🔴 값 라벨 = 회원수·실적 금액은 매칭 집계/실적 · 기대 중단 회원수·활동 유지 기대 회원수·회비 위험액·기대 증액 회원수는 '
        '예측 데이터 기반 추정치(모델 직접 산출 아님). 🔴 축은 대표 약정 1건 기준(약정금액 최대 활동 약정 · 없으면 마지막 종료 약정). '
        '🔴 중단은 HAS_CHURN_PRED · 증액은 HAS_INC_PRED · 충성은 HAS_LOYAL_PRED 로 모집단을 고정한다. '
        "⚠️ UTM 은 값 보유가 일부다 — NULL 비중을 밝힌다. 🔴 예측 지평은 원천 확인 중이다.'\n")
RES = ("  analyst_ml_member_bridge:\n    semantic_view: GN_DW.SERVING.SV_ML_MEMBER_PRED_BRIDGE\n"
       "    execution_environment:\n      type: warehouse\n      warehouse: GN_DW_ANALYTICS_WH\n")
DV_OLD = '부서별·후원사업별·신규/기존별 개발 예측 요청에는 원천 삭제로 미제공이라고 밝히고 다른 값을 추정하지 않는다.'
DV_NEW = ('부서별·신규/기존별 개발 예측 요청에는 원천 삭제로 미제공이라고 밝히고 다른 값을 추정하지 않는다. '
          '🆕 [O246-B] 후원사업별·마케팅캠페인명별·공통브랜드별·마케팅채널별 개발 예측은 같은 SV 의 fa 표'
          '(배분 추정 · 전사 예측 × 직전 12개월 개발 실적 비중)로 답하고 표 제목에 [실적 비중 배분 추정치 · 모델 예측 아님] 을 붙인다.')
SQ = {
    'AGENT_MEMBER': ['최신 기준월 중단 고위험 회원을 마케팅캠페인명별로 보고 기대 중단 회원수와 회비 위험액도 알려줘'],
    'AGENT_MARKETING': ['중단 예측 고위험 회원을 공통브랜드별로 나눠줘', '향후 12개월 개발 예측을 마케팅캠페인명별 상위 10개로 보여줘'],
    'AGENT_EXECUTIVE': ['향후 12개월 개발 예측을 후원사업별로 보여줘', '중단 예측 기반 다음 기간 예상 활동회원 수와 회비 위험액은?'],
}
for a in ['AGENT_MEMBER', 'AGENT_MARKETING', 'AGENT_EXECUTIVE']:
    p = D + a + '/agent_spec.yaml'
    s = io.open(p, encoding='utf-8', newline='').read()
    shutil.copyfile(p, '/workspace/tmp/o246/%s_agent_spec.yaml.beforeB' % a)
    m = re.search(r"(  orchestration: ['\"])(🔴🔴 \[O241-T)", s)
    assert m, a
    s = s[:m.end(1)] + RULE + s[m.end(1):]
    assert s.count('tools:\n- tool_spec:') == 1, a
    s = s.replace('tools:\n- tool_spec:', 'tools:\n' + TOOL + '- tool_spec:', 1)
    assert s.count('tool_resources:\n') == 1, a
    s = s.replace('tool_resources:\n', 'tool_resources:\n' + RES, 1)
    add = ''.join('  - question: %s\n' % q for q in SQ[a])
    assert s.count('  sample_questions:\n') == 1, a
    s = s.replace('  sample_questions:\n', '  sample_questions:\n' + add, 1)
    if a != 'AGENT_MEMBER':
        rx = re.compile(r'(?:\s|\\)+'.join(re.escape(w) for w in DV_OLD.split(' ')))
        hits = list(rx.finditer(s))
        assert len(hits) == 1, (a, len(hits))
        s = s[:hits[0].start()] + DV_NEW + s[hits[0].end():]
    y = yaml.safe_load(s)
    names = [t['tool_spec']['name'] for t in y['tools']]
    assert names.count('analyst_ml_member_bridge') == 1 and 'analyst_ml_member_bridge' in y['tool_resources']
    assert y['instructions']['orchestration'].startswith('🔴🔴 [O246-B')
    if a != 'AGENT_MEMBER':
        d = [t for t in y['tools'] if t['tool_spec']['name'] == 'analyst_ml_dvlp_forecast'][0]['tool_spec']['description']
        assert '[O246-B]' in d
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('OK', a, len(y['tools']), len(y['instructions']['sample_questions']))
