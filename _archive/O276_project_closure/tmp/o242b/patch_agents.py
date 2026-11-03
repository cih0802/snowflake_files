# O242-B — Agent 3종 지시 정정(③ · ㉥) + MEMBER Q01 라우팅 · Co-authored with CoCo
import io, sys, shutil, os
OLD3 = ('system_execute_sql 로 SV 테이블에 직접 SQL 을 쓰지 않는다(직접 SQL 은 한글 별칭·반올림 규칙을 거치지 않아 '
        '영문 열·긴 소수가 나온다 · O241 S4 실측).')
NEW3 = ('analyst 도구가 의미 문맥을 돌려준 뒤 system_execute_sql 로 그 SQL 을 실행하는 것은 정상 경로다 — 그때 쓰는 SQL 도 '
        '그 SV 의 규칙(최종 SELECT 한글 큰따옴표 별칭 · 소수 ROUND(식,2)::NUMBER(38,2))을 지킨다'
        '(🆕 O242-B 정정 · 질문이 검증 쿼리와 같으면 그 SQL 을 그대로 실행한다).')
OLD5 = '㉤ 표·차트의 열 이름·범례는 전부 한글이다(영문 컬럼명·스네이크케이스가 남으면 업무 명칭+단위로 바꾼다).'
NEW5 = OLD5 + ' ㉥ 본문에 한글·영문·숫자·문장부호 밖의 문자(다른 언어 글자)가 섞이지 않았다(🆕 O242-B 실측 = 진행 문장 앞 「का」).'
ANC = '🔴🔴 🆕 [O224 중단 예측 × 캠페인 매칭 · 교차 결합 제한 해제]'
ADD = ('    🔴 🆕 [O242-B 캠페인별 중단 예측 + 회원 특성] 「캠페인(카테고리)별 중단 확률 예측 · 높은/낮은 캠페인 비교 · 캠페인별 회원 특성」을 '
       '함께 묻는 질문은 analyst_ml_churn_campaign 1회로 답한다(ma 축 = 성별·연령대·회원구분·후원금액대·유지기간대 · 기준월 말 시점) — '
       'analyst_ml_sponsor_risk 를 같은 질문에 거듭 부르지 않는다. 실적 중단률이 함께 필요할 때만 analyst_member_cohort 를 1회 더한다.\n')
ap = '--apply' in sys.argv
for a in ('AGENT_EXECUTIVE', 'AGENT_MARKETING', 'AGENT_MEMBER'):
    p = f'cortex_project/agents/{a}/agent_spec.yaml'
    t = io.open(p, encoding='utf-8').read()
    assert t.count(OLD3) == 1 and t.count(OLD5) == 1, (a, t.count(OLD3), t.count(OLD5))
    n = t.replace(OLD3, NEW3).replace(OLD5, NEW5)
    n5 = n.count('아래 5가지를 점검')
    n = n.replace('아래 5가지를 점검', '아래 6가지를 점검')
    if a == 'AGENT_MEMBER':
        i = n.find(ANC); assert i > 0
        ls = n.rfind('\n', 0, i) + 1
        n = n[:ls] + ADD + n[ls:]
    print(a, '5→6가지', n5, 'len', len(t), '->', len(n))
    if ap:
        os.makedirs('tmp/o242b/bak/agents', exist_ok=True)
        shutil.copy(p, f'tmp/o242b/bak/agents/{a}.agent_spec.yaml')
        io.open(p, 'w', encoding='utf-8', newline='').write(n)
