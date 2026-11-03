# O249 — 3 Agent 공통 예측 가드레일 교체 · MKT 광고비 배분 라우팅 · 신규 SV 2종 도구 배선 (사용자 승인 2026-10-20)
import io, sys, copy, yaml, hashlib

ROOT = '/workspace/cortex_project/agents/'
GUARD_OLD = '두 값을 섞거나 환산하지 않는다.'
GUARD_NEW = ('두 값을 한 표에 합산하지 않는다(🆕 [O249] ML 개발금액 예측(만원)과 개발(건)은 같은 숫자 단위다 — 건수로 읽을 때는 그렇게 밝힌다). '
             '🆕🔴🔴 [O249 공통 예측 가드레일] 예측 질문은 ① ML 예측 도구 → ② 비중 배분(analyst_ml_dvlp_forecast 의 배분 표 · '
             '후원사업·마케팅캠페인명·공통브랜드·마케팅채널·개발구분(신규·증액·재후원) 축 · 「실적 비중 배분 추정치 · 모델 예측 아님」) → '
             '③ 부서 자체 수식(회원실·기획실 예측) → ④ 추세 참고치(직전 3개월 실적 평균) 순으로 찾고 「없다·못한다」로 끝내지 않는다. '
             '신규 개발(건)·신규 예측은 ② 의 개발구분 = 신규 로 답한다(회원 신규/기존 구분과 다른 축임을 밝힌다).')
EDITS = {
    'AGENT_EXECUTIVE': [(GUARD_OLD, GUARD_NEW, 1)],
    'AGENT_MEMBER': [
        (GUARD_OLD, GUARD_NEW, 1),
        ('③ 🆕 [O203 · 사용자 결정 2026-10-06] **부서 자체 예측을 먼저 찾는다**',
         '③ 🆕 [O249] 개발금액·개발(건)의 후원사업·마케팅캠페인명·공통브랜드·마케팅채널·개발구분별 예측은 먼저 analyst_ml_dvlp_forecast 의 배분 표(비중 배분 추정)로 답한다. '
         '그 밖의 지표는 🆕 [O203 · 사용자 결정 2026-10-06] **부서 자체 예측을 먼저 찾는다**', 1),
    ],
    'AGENT_MARKETING': [
        (GUARD_OLD, GUARD_NEW, 1),
        ('(금액 만원 예측 · 건수 예측은 조회되지 않는다고 밝힌다)',
         '(금액 만원 예측 · 🆕 [O249] 신규·증액·재후원 건수 예측은 배분 표 개발구분 축의 배분 추정치로 답한다 — 만원 = 개발(건) 같은 숫자)', 1),
        ('**CRM 개발실적 기준**(광고비 ÷ CRM 개발건)은 정의된 지표가 아니다.',
         '**CRM 개발실적 기준**(광고비 ÷ CRM 개발건)은 🆕 [O249] **analyst_ad_inflow_alloc** 의 개발단가(COST_PER_DEV · 광고비를 같은 월·마케팅캠페인의 '
         '개발인입경로로 배분한 추정치)로 답한다 — 광고비와 CRM 개발건을 직접 나누지 않는다.', 1),
        ('형태의 개발단가는 cross-fact 라 불가하며 이 도구의 개발단가는',
         '형태의 개발단가는 이 도구로는 불가하며(cross-fact) 🆕 [O249] analyst_ad_inflow_alloc(인입경로 배분 추정)이 답한다. 이 도구의 개발단가는', 1),
    ],
}
NEW_TOOLS = {
    'AGENT_MARKETING': ('analyst_ad_inflow_alloc', 'GN_DW.SERVING.SV_AD_INFLOW_ALLOC',
        '🆕 [O249] 광고비 → 개발인입경로 배분 팩트(GOLD.FACT_AD_INFLOW_ALLOC · grain = 월 × 마케팅캠페인 × 인입경로 × 행종류). '
        '「개발인입경로별 개발단가」·「인입경로별 광고비」·「광고비 ÷ CRM 개발건」 질문의 정본 도구다. 개발단가 = COST_PER_DEV(ALLOC 행 배분 광고비 ÷ 개발(건)). '
        '🔴 배분 추정치이며 실측 광고비가 아니다 — analyst_ad 광고비와 한 표에 합산하지 않는다. 🔴 미배분(UNALLOC) 광고비를 사유와 함께 따로 밝힌다. '
        '🔴 방송광고(VIDEO) 허용 인입경로는 현업 확인 전 가정이다.'),
    'AGENT_MEMBER': ('analyst_member_event_cohort', 'GN_DW.SERVING.SV_MEMBER_EVENT_COHORT',
        '🆕 [O249] 개발사건 × 경과월 코호트(GOLD.FACT_MEMBER_EVENT_COHORT · grain = 회원 × 사건월 × 개발구분 × 경과월 0~12). '
        '「신규 후 N개월 증액·유지·중단 비율」·「증액 상위 회원 원문」·「개발 당일 알림톡 수신·문자 오픈」 질문에 쓴다. '
        '🔴 개발구분 1개와 경과월 1개를 반드시 고정한다(경과월 합산 = 회원 중복). 🔴 비율 분모는 관측 가능 회원만. '
        '🔴 발송 수신과 후속 사건의 차이는 인과가 아니다. 🔴 개발건수 실적 정본은 analyst_member_event 다.'),
}


def main(apply):
    for a in ['AGENT_EXECUTIVE', 'AGENT_MARKETING', 'AGENT_MEMBER']:
        p = ROOT + a + '/agent_spec.yaml'
        raw = io.open(p, encoding='utf-8').read()
        assert hashlib.sha256(raw.encode()).digest() == hashlib.sha256(io.open(p, encoding='utf-8').read().encode()).digest()
        d = yaml.safe_load(raw)
        before = copy.deepcopy(d)
        ins = d['instructions']
        for old, new, n in EDITS[a]:
            hit = [k for k in ins if isinstance(ins[k], str) and old in ins[k]]
            hit_tools = [t for t in d['tools'] if old in t['tool_spec'].get('description', '')]
            cnt = sum(ins[k].count(old) for k in hit) + sum(t['tool_spec']['description'].count(old) for t in hit_tools)
            assert cnt == n, (a, old[:30], cnt)
            for k in hit:
                ins[k] = ins[k].replace(old, new)
            for t in hit_tools:
                t['tool_spec']['description'] = t['tool_spec']['description'].replace(old, new)
        if a in NEW_TOOLS:
            name, sv, desc = NEW_TOOLS[a]
            assert name not in d['tool_resources']
            tmpl = next(t for t in d['tools'] if t['tool_spec']['name'] == 'analyst_member_cohort')
            nt = copy.deepcopy(tmpl)
            nt['tool_spec']['name'] = name
            nt['tool_spec']['description'] = desc
            d['tools'].append(nt)
            d['tool_resources'][name] = {'semantic_view': sv, 'execution_environment': copy.deepcopy(d['tool_resources']['analyst_member_cohort']['execution_environment'])}
        out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=800)
        assert yaml.safe_load(out) == d
        changed = [k for k in d if d[k] != before.get(k)]
        print(a, 'changed top keys =', changed, 'tools', len(before['tools']), '->', len(d['tools']), 'len', len(raw), '->', len(out))
        if apply:
            io.open(p, 'w', encoding='utf-8').write(out)
            assert yaml.safe_load(io.open(p, encoding='utf-8').read()) == d


main('--apply' in sys.argv)
