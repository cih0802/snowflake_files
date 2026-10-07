# O206-C — Agent 4종 response: 수치 근거 규칙(차단형 자가점검) · 멱등 · YAML 파싱 검증
# 사용: python3 tmp/o206c_agent_number_rule.py [--apply]
# Co-authored with CoCo
import hashlib, io, sys
import yaml

AGENTS = ['AGENT_EXECUTIVE', 'AGENT_MARKETING', 'AGENT_MEMBER', 'AGENT_MSTR']
MARK = '[O206-C 수치 근거'
RULE = ('🔴🔴 [O206-C 수치 근거 · 답변 직전 자가점검] 본문에 쓰는 모든 금액·건수·명수·합계·분모는 '
        '도구 결과의 한 셀에 그대로 있는 값이어야 한다. '
        '월별 값을 더해 연간 합계를 만들거나, 그룹별 고유 회원수를 더해 전체 분모를 만들거나, 두 값을 빼서 차이를 만들지 않는다'
        '(실측 사고 유형: 월별 값을 직접 더한 연간 합계가 실제와 수십억 원 어긋남 · 등급별 고유 회원수를 더한 분모가 실제 중복제거 값보다 큼). '
        '필요한 합계·분모·차이가 결과에 없으면 그 값을 내는 SQL 을 한 번 더 실행한다. '
        '단위 환산(원 → 억원·백만원) 시 자릿수를 다시 확인한다(백만 단위를 억 단위로 쓰지 않는다). '
        '답변을 내기 직전, 본문 수치를 하나씩 결과 셀과 대조하고 맞지 않으면 고친다.')
# 삽입 위치 = response 첫 줄 끝(「…조회 기간·필터를 명시.」 다음) — 4종 공통 문장
ANCH = '여러 행은 표로 제시하고 조회 기간·필터를 명시.'


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


apply = '--apply' in sys.argv
for a in AGENTS:
    p = f'cortex_project/agents/{a}/agent_spec.yaml'
    if sha(p) != sha(p):
        print('UNSTABLE', a); continue
    t = io.open(p, encoding='utf-8').read()
    if MARK in t:
        print('SKIP', a); continue
    n = t.count(ANCH)
    new = t.replace(ANCH, ANCH + '\n\n    ' + RULE, 1)
    try:
        spec = yaml.safe_load(new); ok = MARK in spec['instructions']['response']
    except Exception as e:
        ok = False; print('  yaml', e)
    print(('APPLY ' if apply else 'DRY   ') + a, 'anchor=%d' % n, 'yaml_ok=%s' % ok)
    if apply and n >= 1 and ok:
        io.open(p, 'w', encoding='utf-8', newline='').write(new)
