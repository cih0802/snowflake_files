# O206 — Agent 4종: 표 헤더 한글 강제(response) + 큰따옴표 한글 별칭(orchestration) 패치 · 멱등
# 사용: python3 tmp/o206_agent_korean_header.py [--apply]
# Co-authored with CoCo
import hashlib, io, sys
import yaml

AGENTS = ['AGENT_EXECUTIVE', 'AGENT_MARKETING', 'AGENT_MEMBER', 'AGENT_MSTR']
OLD_RESP = '지표·컬럼은 영문 식별자 대신 한글 명칭(SV synonyms/comment 기준, 표 헤더 포함)으로 표기'
NEW_RESP = ('🔴🔴 [O206 표 헤더 한글 강제 · 전 Agent 공통] 답변의 모든 표·차트의 열 이름(헤더)·범례·축 제목은 한글로만 쓴다. '
            '도구 결과 열 이름이 한글이면 그대로 쓰고, 영문 식별자(예: TOTAL_DEV_CNT · MONTH_KEY)가 남아 있으면 '
            '그 SV 의 동의어 첫 항목·COMMENT 의 업무 명칭으로 바꾸고 단위를 괄호로 붙인다(예: 개발(건) · 회비(원) · 집행율(%)). '
            '영문·코드 헤더가 하나라도 남은 표는 내보내지 않는다 — 답변 직전에 헤더를 점검한다. 코드값 열은 「○○코드」처럼 한글 헤더를 붙인다. '
            '이 원칙에 따라 표기')
OLD_ORCH = ('🔴 [O201-B] 열 별칭(AS 뒤 이름)은 영문·숫자·밑줄만 쓴다(예: AS FORECAST_MONTH) — '
            'AS 예측월 처럼 따옴표 없는 한글 별칭은 syntax error 를 낸다. 한글 명칭은 답변 표 헤더에서만 쓴다.')
NEW_ORCH_FMT = ('🔴 [O206 · O201-B 개정] 열 별칭(AS 뒤 이름)은 반드시 큰따옴표 한글 별칭으로 쓴다(예: SUM(x) AS {q}개발(건){q}) — '
                'AS 예측월 처럼 따옴표 없는 한글 별칭은 syntax error 다. 한글명은 SV 동의어 첫 항목·COMMENT 기준이며 단위를 괄호로 붙인다. '
                'analyst 도구에 질의를 넘길 때 「결과 열 이름은 한글(큰따옴표 별칭)」을 요청 끝에 붙인다.')


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


apply = '--apply' in sys.argv
for a in AGENTS:
    p = f'cortex_project/agents/{a}/agent_spec.yaml'
    if sha(p) != sha(p):
        print('UNSTABLE', p); continue
    t = io.open(p, encoding='utf-8').read()
    if '[O206 표 헤더' in t:
        # 2차(O206-B): 차트 fold 변환의 기본 제목 Value/key 도 한글로
        if '[O206-B 차트]' not in t:
            t2 = t.replace('코드값 열은 「○○코드」처럼 한글 헤더를 붙인다. ',
                           '코드값 열은 「○○코드」처럼 한글 헤더를 붙인다. [O206-B 차트] 차트의 축·범례·툴팁 제목도 한글로 지정한다 — '
                           '여러 지표를 한 차트에 겹칠 때 생기는 값·구분 필드(value·key)에는 반드시 title 을 「값」·「구분」 또는 지표 단위명(예: 금액(원))으로 붙인다. ', 1)
            ok = yaml.safe_load(t2) and t2 != t
            print(('APPLY-B ' if apply else 'DRY-B   ') + a, 'ok=' + str(bool(ok)))
            if apply and ok:
                io.open(p, 'w', encoding='utf-8', newline='').write(t2)
        else:
            print('SKIP', a)
        continue
    # orchestration 스칼라의 따옴표 형식 판별 → 큰따옴표 스칼라면 \" 로 이스케이프
    orch_line = next(l for l in t.split('\n') if l.startswith('  orchestration: ') and not l.endswith('auto'))
    q = '\\"' if orch_line.startswith('  orchestration: "') else '"'
    n1, n2 = t.count(OLD_RESP), t.count(OLD_ORCH)
    new = t.replace(OLD_RESP, NEW_RESP).replace(OLD_ORCH, NEW_ORCH_FMT.format(q=q))
    spec = yaml.safe_load(new)
    ok = '[O206 표 헤더' in spec['instructions']['response'] and '[O206 · O201-B 개정]' in spec['instructions']['orchestration']
    ok = ok and '개발(건)"' in spec['instructions']['orchestration']
    print(('APPLY ' if apply else 'DRY   ') + a, f'resp={n1} orch={n2} quote={q!r} yaml_ok={ok}')
    if n1 != 1 or n2 != 1 or not ok:
        print('  🔴 앵커 불일치 또는 파싱 실패 — 쓰지 않는다'); continue
    if apply:
        io.open(p, 'w', encoding='utf-8', newline='').write(new)
