# O213-Y4 — 7차 Agent 배선: 신규 SV 5종 도구 추가 + 기존 도구 설명에 신규 축 + 라우팅 블록 + 추천 질문
# Co-authored with CoCo
# 방식 = yaml.safe_load → dict 편집 → safe_dump(width=200 · 정본 생성 규약 · 3종 왕복 바이트 동일 실측) → 재파싱 검증.
# 사용: python3 tmp/o213_y4_agent_patch.py [--apply]
import hashlib, io, sys, yaml

B = 'cortex_project/agents/%s/agent_spec.yaml'
WH = {'type': 'warehouse', 'warehouse': 'GN_DW_ANALYTICS_WH'}
TAG = '🆕 [O213 7차]'

# ── 신규 도구 정의 (도구명 → (SV, 설명)) ─────────────────────────────────────
NEW = {
 'analyst_payment_billing_status': ('SV_PAYMENT_BILLING_STATUS',
   f'{TAG} 회비 청구 처리 상태(월 × 후원사업 × 회비구분 × 납입유형 × 청구구분 × 처리상태 × 환급사유). 원천=CRM(eCRM) → GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT·TM_PM_DNTN_DTLS → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_PAYMENT_BILLING_STATUS. '
   '활성 지표: 청구(건)·청구액(원)·납입액(원)·미납액(원). 차원: 회비월(YYYY-MM)·회비구분·납입유형·청구구분(정기청구·OCR신규·개별청구)·처리상태(청구·완료)·환급사유(11종)·후원사업. '
   '「청구구분별·처리상태별·환급사유별 청구 건수·금액」 질문의 정본. 🔴 회원 축이 없다 — 고유 회원수·회원 단위 회비는 analyst_member_fee 로 답한다(한 표 합산 금지). 🔴 청구구분 코드 Y·처리상태 코드 F 는 사전에 라벨이 없다 — 「코드 Y」「코드 F」로 밝히고 의미를 추정하지 않는다.'),
 'analyst_ga_session': ('SV_GA_SESSION',
   f'{TAG} GA4 홈페이지 세션(1일 × 1세션). 원천=GA4(BigQuery export) → SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_SESSION → GOLD.FACT_BIGQUERY_SESSION. '
   '활성 지표: 세션수(회)·방문자수(명)·참여 세션수·페이지뷰(회)·이벤트수(건). 차원: 방문일/연/월 · 회원유형(비로그인·정기회원·중단회원·일시회원·앱회원)·후원자유형(개인·단체·기업)·후원 행동 유형(신규·증액·감액·재후원)·관심 후원사업 유형·로그인 여부·결제수단 · 기기·운영체제·브라우저·기기 언어·휴대폰 제조사·사이트(호스트) · 대륙·하위대륙·국가·광역권 · 기본/주 채널 그룹·유입 플랫폼·구글애즈 캠페인·광고그룹·최초 유입 소스/매체·수집 UTM 매체 · 회원 식별 여부. '
   '「후원자유형·회원유형·국가·기기·브라우저·사이트·유입채널별 방문(세션)·방문자」 질문의 정본. 🔴 세션·방문자수는 비가산(일자별 합산 금지). 🔴 페이지 경로·이벤트 분류 질문은 analyst_ga_behavior(다른 grain · 합산 금지). 🔴 「{{…}}」 형태 값은 GTM 미치환 수집 오류로 밝힌다.'),
 'analyst_search_console': ('SV_SEARCH_CONSOLE',
   f'{TAG} 구글 서치콘솔 검색 성과(일 × 검색어 × 페이지 × 국가 × 기기). 원천=Google Search Console → BRONZE_GSC.SEARCH_CONSOLE_DATA → SILVER.SEARCH_CONSOLE_DATA → GOLD.FACT_SEARCH_CONSOLE. '
   '활성 지표: 클릭수(회)·노출수(회)·클릭률(%)·평균순위(노출 가중). 차원: 검색일/연/월·검색어·노출 페이지·국가(alpha-3 코드 · kor=한국)·기기. '
   '「어떤 검색어로 들어왔나」「구글 검색 노출·클릭·순위」 질문의 정본. 🔴 구글 검색만이다(네이버 등 없음). 🔴 홈페이지 방문(세션)과 다른 원천 — 클릭수를 세션수와 대조·합산하지 않는다.'),
 'analyst_ga_demographic': ('SV_GA_DEMOGRAPHIC',
   f'{TAG} GA4 방문자 인구통계(일 × 기기 × 성별 × 연령대). 원천=GA4 Data API → BRONZE_GA4.GA4_USER_DEMOGRAPHIC → SILVER.GA4_USER_DEMOGRAPHIC → GOLD.FACT_GA4_DEMOGRAPHIC. '
   '활성 지표: 세션수(회). 차원: 방문일/연/월·기기·성별(여성·남성·추정불가)·연령대(18-24~65+·추정불가). '
   '「성별·연령대별 홈페이지 방문」 질문의 정본. 🔴 GA4 가 구글 신호로 추정한 값이다 — CRM 회원 성별·나이가 아니다. 🔴 사용자수는 비가산이라 제공하지 않는다. 🔴 analyst_ga_session 과 세션 정의·모수가 달라 대조·합산하지 않는다.'),
 'analyst_expense_resolution': ('SV_EXPENSE_RESOLUTION',
   f'{TAG} ERP 지출결의 명세(원천 1행 = 1행). 원천=ERP → BRONZE_ERP.EXPENSE_RESOLUTION → SILVER.ERP_EXPENSE_RESOLUTION → GOLD.FACT_EXPENSE_RESOLUTION. '
   '활성 지표: 지출액(원)·결의 건수(건 · 비가산). 차원: 결의일/연/월·회계연도·결의부서(55종)·출처구분·예산단위·목·세목·세세목·재원·지출결의명·결의번호. '
   '「부서별·과목별·재원별 지출(집행) 금액」 질문의 정본 — 예산 원장(analyst_budget)의 부서 축은 비어 있어 부서별 지출은 이 도구로만 답할 수 있다. 🔴🔴 예산 원장(analyst_budget·analyst_budget_yearly)과 원천·범위가 달라 금액을 대조·합산·비율 계산하지 않는다(「예산 대비 지출률」을 두 도구로 섞어 내지 않는다).'),
}

# 에이전트별 신규 도구
ADD = {
 'AGENT_MEMBER':    ['analyst_payment_billing_status'],
 'AGENT_EXECUTIVE': ['analyst_expense_resolution', 'analyst_payment_billing_status'],
 'AGENT_MARKETING': ['analyst_ga_session', 'analyst_search_console', 'analyst_ga_demographic', 'analyst_expense_resolution'],
}

# 기존 도구 설명 말미 보강(SV → 문장) — SV 기준으로 매핑해 같은 SV 를 쓰는 모든 Agent 에 동일 적용
C6 = '결연구분·특별관리·최초후원사업·휴대폰/이메일 상태·TM/TS 거절'   # 회원 속성 6축(spec 실측 공통분)
EXT = {
 'SV_MEMBER_MONTHLY':     f' {TAG} 차원 추가(회원 현재 마스터 값): {C6}·특별관리2·생일 양력/음력·일시회원 관계 · 가입경로·가입 공통브랜드.',
 'SV_MEMBER_EVENT':       f' {TAG} 차원 추가(회원 현재 마스터 값): {C6} · 마케팅채널·가입경로·가입 공통브랜드.',
 'SV_MEMBER_COHORT':      f' {TAG} 차원 추가: 마케팅채널·후원사업 4그룹.',
 'SV_MEMBER_SPONSOR_BIZ': f' {TAG} 차원 추가: 마케팅채널·후원 가입경로·후원사업 4그룹.',
 'SV_MEMBER_STATUS_ASOF': f' {TAG} 차원 추가: 가입경로.',
 'SV_SERVICE':            f' {TAG} 차원 추가: 발송 카테고리(대·중·소)·메시지 구분·발송 시간 구분·우편물 처리상태·재발송/대량발송 여부·발송 법인구분·문자 분할 방식 · 문자 발송 시점 후원사업·중단사유·결연아동 사업국·사업장 · 회원(현재 마스터 값) {C6}·기타연락처 상태·이메일/우편물 수신동의 항목별(수신거부·정기·결연·감사·웹진·개발) · 가입경로·공통/최초/최종 브랜드. 🔴 발송 카테고리는 문자(SND) 요청에만 값이 있다.',
 'SV_EVENT_PARTICIPATION': f' {TAG} 차원 추가: 참여신청 사용여부(캠페인행사) · 회원(현재 마스터 값) {C6} · 가입경로.',
 'SV_RELATION_ACTIVITY':  f' {TAG} 차원 추가: 결연 중단 여부·결연 중단(종료)사유(라벨 코드군 현업 확인 중 — 답에 밝힌다)·선물금 정산은행 · 회원(현재 마스터 값) {C6} · 가입경로.',
 'SV_AD':                 f' {TAG} 차원 추가: 매체(YOUTUBE·META·EBS 등 3원천 공통)·소재명·비용유형·예산출처(사단·사복·통합)·소재유형(디지털·영상)·캠페인유형(국내/해외 사례·사업)·UTM 캠페인 · 영상 전용 사업/사례 구분·CM 구분·국내/해외 · 방송구분·채널사유형·CTV구분·요일구분. 🔴 원천 전용 축은 다른 원천 행에서 NULL(결측 아님) — 혼합 집계 전에 출처유형으로 스코프한다.',
 'SV_BUDGET':             f' {TAG} 차원 추가: 예산 과목 장·관·항·재원(ERP 원장). 🔴 부서별 지출은 analyst_expense_resolution(다른 원천 · 합산 금지).',
 'SV_BUDGET_YEARLY':      f' {TAG} 차원 추가: 예산 과목 장·관·항·재원(ERP 원장).',
 'SV_GA_BEHAVIOR':        f' {TAG} 차원 추가: UTM 콘텐츠·UTM 검색어. 🔴 회원유형·후원자유형·국가·브라우저·사이트별 방문(세션) 질문은 analyst_ga_session 으로 답한다.',
}

ROUTE = {
 'AGENT_MEMBER': f'\n\n🔴🔴 {TAG} 신규 축·도구 라우팅. ① 「청구구분별·처리상태별·환급사유별 청구 건수·청구액」 → **analyst_payment_billing_status** (회원수·회원 단위 회비는 analyst_member_fee · 한 표 합산 금지). ② 회원 속성(결연구분·특별관리·최초후원사업·연락처 상태·TM/TS 거절·수신동의 항목별·가입경로·마케팅채널)으로 분해하는 질문은 그 축을 가진 기존 도구로 답한다 — 월 실적 = analyst_member_monthly · 개발/중단 = analyst_member_event · 발송 = analyst_service · 결연활동 = analyst_relation_activity. 이 축들은 **현재 마스터 값**이다(과거월도 현재값) — 표 각주에 한 번 밝힌다. ③ 「결연 중단 사유」「중단된 결연의 서신·선물금」 → analyst_relation_activity(중단사유 라벨은 현업 확인 중이라고 밝힌다). ④ 「발송 카테고리·메시지 구분·우편 처리상태」 → analyst_service. ⑤ 홈페이지 방문(GA)·구글 검색어·부서별 지출은 이 Agent 에 도구가 없다 — 마케팅 분석 어시스턴트(GA·검색) 또는 경영 어시스턴트(지출결의)로 안내한다.',
 'AGENT_EXECUTIVE': f'\n\n🔴🔴 {TAG} 신규 축·도구 라우팅. ① 「부서별·과목별·재원별 지출(집행) 금액·결의 건수」 → **analyst_expense_resolution** — 예산 원장(analyst_budget)의 부서 축은 비어 있으므로 「부서별 지출」을 analyst_budget 으로 답하지 않는다. 🔴 예산(analyst_budget·analyst_budget_yearly)과 지출결의는 원천·범위가 달라 「예산 대비 지출률」을 두 도구로 계산하지 않는다 — 두 값을 표를 나눠 각각 밝힌다. ② 「청구구분·처리상태·환급사유별 청구」 → **analyst_payment_billing_status**. ③ 광고를 매체·소재·예산출처·캠페인유형·CM 구분으로 분해 → analyst_ad. ④ 예산을 장·관·항·재원으로 분해 → analyst_budget / analyst_budget_yearly. ⑤ 홈페이지 방문·검색어는 마케팅 분석 어시스턴트로 안내한다.',
 'AGENT_MARKETING': f'\n\n🔴🔴 {TAG} 신규 축·도구 라우팅. ① 「회원유형·후원자유형·관심 후원사업·국가·기기·브라우저·사이트·유입채널(채널 그룹·광고 플랫폼)별 홈페이지 방문(세션)·방문자·페이지뷰」 → **analyst_ga_session** / 페이지 경로·이벤트 분류·UTM 원값 단위 → analyst_ga_behavior (두 도구 합산 금지). ② 「어떤 검색어로 들어왔나·구글 검색 노출·클릭·클릭률·순위」 → **analyst_search_console** (구글만 · 방문 세션과 대조 금지). ③ 「성별·연령대별 방문」 → **analyst_ga_demographic** (GA4 추정값 · CRM 회원 성별/나이 아님). ④ 「부서별·과목별 지출」 → **analyst_expense_resolution** (예산 도구와 합산 금지). ⑤ 광고를 매체·소재·예산출처·캠페인유형·UTM·CM 구분으로 분해 → analyst_ad. ⑥ GA·검색·광고·CRM 은 서로 다른 원천이다 — 「광고 클릭 → 방문 → 후원」을 한 표에서 이어 계산하지 않고 각 도구 값을 따로 제시한다.',
}

SAMPLE = {
 'AGENT_MEMBER':    ['2026년 8월 회비 청구구분별 청구 건수와 청구액을 보여줘', '결연 중단 사유별 서신·선물금 활동 건수를 보여줘', '결연구분별 2025년 신규 개발 건수는?'],
 'AGENT_EXECUTIVE': ['2026년 부서별 지출결의 금액 상위 10개 부서는?', '2026년 매체별 광고비와 클릭수를 보여줘', '예산 장·관별 2026년 편성액을 보여줘'],
 'AGENT_MARKETING': ['2026년 9월 후원자유형별 홈페이지 방문 세션수를 보여줘', '2026년 9월 구글 검색어 클릭수 상위 20개와 클릭률은?', '성별·연령대별 홈페이지 방문 비중은?', '유입 채널 그룹별 방문자수와 참여 세션수는?'],
}


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


ok = True
for a, adds in ADD.items():
    p = B % a
    h0 = h(p); assert h0 == h(p)
    t = io.open(p, encoding='utf-8').read()
    d = yaml.safe_load(t)
    assert yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200) == t, a + ' 왕복 불일치'
    names = [x['tool_spec']['name'] for x in d['tools']]
    tr = d['tool_resources']
    # 기존 도구 설명 보강(멱등: 태그 있으면 skip)
    ext_n = 0
    for x in d['tools']:
        n = x['tool_spec']['name']; sv = tr[n]['semantic_view'].split('.')[-1]
        if sv in EXT and TAG not in x['tool_spec']['description']:
            x['tool_spec']['description'] += EXT[sv]; ext_n += 1
    # 신규 도구
    for n in adds:
        if n in names:
            continue
        sv, desc = NEW[n]
        d['tools'].append({'tool_spec': {'type': 'cortex_analyst_text_to_sql', 'name': n, 'description': desc}})
        tr[n] = {'semantic_view': 'GN_DW.SERVING.' + sv, 'execution_environment': dict(WH)}
    ins = d['instructions']
    if TAG not in ins['orchestration']:
        ins['orchestration'] = ins['orchestration'].rstrip('\n') + ROUTE[a] + '\n'
    qs = ins.setdefault('sample_questions', [])
    have = {q['question'] for q in qs}
    for q in SAMPLE[a]:
        if q not in have:
            qs.append({'question': q})
    out = yaml.safe_dump(d, allow_unicode=True, sort_keys=False, width=200)
    d2 = yaml.safe_load(out)
    tools2 = [x['tool_spec']['name'] for x in d2['tools']]
    assert len(tools2) == len(set(tools2)) and set(tools2) == set(d2['tool_resources']), a + ' 도구/리소스 불일치'
    assert all(n in tools2 for n in adds)
    print(f'{a}: tools {len(names)}→{len(tools2)} · 설명보강 {ext_n} · 질문 {len(have)}→{len(d2["instructions"]["sample_questions"])} · bytes {len(t.encode())}→{len(out.encode())}')
    if '--apply' in sys.argv:
        assert h(p) == h0, a + ' 편집 중 변경됨'
        io.open(p, 'w', encoding='utf-8', newline='').write(out)
        print('  WROTE', h(p)[:12])
print('mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')
