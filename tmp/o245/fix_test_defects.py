# O245 — Agent 테스트 결함 2종 시정(2026-10-18 · tmp/o245/agent_test/_judge.md)
#   C1 = 「후원사업별 활동회원 중단 고위험」이 analyst_ml_sponsor_risk 로 감(churn_campaign 설명에 후원사업 축 부재 + 54행 규칙)
#   M4·M5 = ROLLUP 합계 행에 COALESCE(…,'(미매칭)') 가 씌워져 합계 행이 (미매칭)으로 표기됨
import io, hashlib, shutil
R = '/workspace/'
TOOL_OLD = "🔴 캠페인카테고리 외의 개별 캠페인명·마케팅캠페인 축은 없다.'"
TOOL_NEW = ("🔴 캠페인카테고리 외의 개별 캠페인명·마케팅캠페인 축은 없다. 🆕 [O245] 후원사업 축 = cs 표(카테고리 × 후원사업 · "
            "SPONSORSHIP_NAME) — 「후원사업별 활동회원·중단 고위험 회원」 질문도 이 도구로 답한다. 회원 특성 축(ma) = 성별·연령대·지역·회원상태·"
            "회원구분·법인구분·등록부서·활동 약정 수·후원금액대·유지기간·납입방식.'")
RULE_OLD = '위험 분포만 묻는 질문(명단·회원 단위 아님)은 기존대로 analyst_ml_sponsor_risk 를 쓴다.'
RULE_NEW = ('위험 분포만 묻는 질문(명단·회원 단위 아님)은 기존대로 analyst_ml_sponsor_risk 를 쓴다. 🆕 [O245] 단 「활동회원」·「중단 고위험(회원 단위 등급)」을 '
            '후원사업별(또는 카테고리 × 후원사업별)로 묻는 질문은 analyst_ml_churn_campaign(cs 표)로 답한다 — sponsor_risk 의 회원수는 「예측 대상 후원건의 회원」이지 활동회원이 아니다.')
AI_OLD = '(미매칭) 행은 따로 밝힌다.'
AI_NEW = ('(미매칭) 행은 따로 밝힌다. 🆕 [O245] ROLLUP 합계 행에는 COALESCE(차원, ''(미매칭)'') 를 씌우지 않는다 — '
          'CASE WHEN GROUPING(차원) = 1 THEN ''전체 합계'' WHEN 차원 IS NULL THEN ''(미매칭)'' ELSE 차원 END 로 구분한다.')
PLAN = [
    ('cortex_project/agents/AGENT_MEMBER/agent_spec.yaml', [(TOOL_OLD, TOOL_NEW, 1), (RULE_OLD, RULE_NEW, 1)]),
    ('cortex_project/agents/AGENT_EXECUTIVE/agent_spec.yaml', [(TOOL_OLD, TOOL_NEW, 1)]),
    ('cortex_project/agents/AGENT_MARKETING/agent_spec.yaml', [(TOOL_OLD, TOOL_NEW, 1)]),
    ('05_SV-Agent_ai/22_ML_SV_DDL.sql', [(AI_OLD, AI_NEW, 2)]),
    ('05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql', [(AI_OLD, AI_NEW, 1)]),
]
for f, reps in PLAN:
    p = R + f
    assert hashlib.sha256(open(p, 'rb').read()).digest() == hashlib.sha256(open(p, 'rb').read()).digest()
    s = io.open(p, encoding='utf-8', newline='').read()
    for a, b, n in reps:
        assert s.count(a) == n, (f, a[:30], s.count(a))
        s = s.replace(a, b)
    shutil.copyfile(p, '/workspace/tmp/o245/%s.before3' % f.replace('/', '__'))
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('OK', f)
