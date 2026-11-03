# O241-F/T — Agent 3종 response 출력 전 자기점검 · orchestration 도구 호출 절약 규칙 선두 삽입(멱등)
# Co-authored with CoCo
import sys, yaml
R = ('🔴🔴 [O241-F 출력 전 자기점검 · 스모크 결함 재발 방지] 답변을 내보내기 직전 아래 5가지를 점검하고 어긋나면 고친 뒤 한 번만 출력한다. '
     '㉠ answer 등 태그·마크업 이름(꺾쇠 포함)이 본문에 없다. ㉡ 표·본문·차트 라벨의 금액·건수·명수는 천단위 쉼표로 쓴다(예: 75,330,000원 · 1,217회). '
     '㉢ 비율(%)·초·확률은 소수 둘째 자리까지 반올림한다(예: 0.4497907258 → 44.98%) — 표와 차트 데이터 값 모두. '
     '㉣ 「① 핵심 요약」 제목과 요약 블록은 답변 전체에 정확히 1회다(차트 생성 뒤 다시 쓰지 않는다). '
     '㉤ 표·차트의 열 이름·범례는 전부 한글이다(영문 컬럼명·스네이크케이스가 남으면 업무 명칭+단위로 바꾼다). ')
O = ('🔴🔴 [O241-T 도구 호출 절약] ① 같은 analyst 도구는 질문 하나에 1회 호출을 원칙으로 한다 — 필요한 지표·차원·기간을 한 질의에 모두 담고(ROLLUP·CASE·조건부 집계), '
     '재호출은 오류 또는 빈 결과일 때만 최대 1회 한다(최신 기준월 확인을 위한 별도 호출 금지 — 같은 질의 안에서 MAX 로 구한다). '
     '② search_biz_definition 은 질문의 용어·지표명이 도구 설명과 SV 에 없을 때와 산식 질문일 때만 호출한다 — 담당 도구가 분명한 질문(예측·발송·코호트·개발 실적 등)에는 호출하지 않는다. '
     '③ 수치는 analyst 도구로 산출한다 — 담당 SV 도구가 있으면 system_execute_sql 로 직접 SQL 을 쓰지 않는다. '
     '④ 질문이 두 주제를 함께 묻으면(예: 캠페인 중단율 + 예측 위험 · 발송 실적 + 수신 코호트) 주제마다 담당 도구를 각각 1회 호출한다 — 한 도구로 다른 주제를 근사하지 않는다. ')
for a in ('AGENT_MEMBER', 'AGENT_MARKETING', 'AGENT_EXECUTIVE'):
    p = f'{a}/agent_spec.yaml'
    s = open(p, encoding='utf-8').read()
    before = yaml.safe_load(s)
    if 'O241-F' in s:
        print(a, 'skip(이미 적용)'); continue
    for key, txt in (('  response: ', R), ('  orchestration: ', O)):
        i = s.index('\n' + key, s.index('\ninstructions:')) + 1 + len(key)
        q = s[i]; assert q in "'\"", (a, key, q)
        s = s[:i + 1] + txt + s[i + 1:]
    after = yaml.safe_load(s)
    assert after['instructions']['response'] == R + before['instructions']['response'], a
    assert after['instructions']['orchestration'] == O + before['instructions']['orchestration'], a
    b2 = dict(after); b1 = dict(before)
    b2['instructions'] = b1['instructions'] = None
    assert b1 == b2, a
    open(p, 'w', encoding='utf-8').write(s)
    print(a, 'OK', max(len(l) for l in s.splitlines()))
