# O209 X6 — 재편 후 재측정 · 문항 = 06_O208_문항코퍼스.csv · 판정 = o208_baseline judge 와 같은 규칙
# 쌍 = (문항, 수정안 단위 Agent) + (문항, 현업 예상 Agent) · 원문 = tmp/o209_x6/<문항ID>__<AGENT>.json
# 사용: python3 tmp/o209_x6.py [--agent AGENT_EXECUTIVE] [--only Q01] [--judge]
# Co-authored with CoCo
import csv, json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/workspace/scripts')
sys.path.insert(0, '/workspace/tmp')
from sfconn import conn
import o208_baseline as B
OUT = '/workspace/tmp/o209_x6'; os.makedirs(OUT, exist_ok=True)
# 재시도 폴더 — 스테이지 마운트가 mv 직후 같은 경로 재생성을 거부한다(ENOENT · O209 실측)
ALT = '/workspace/tmp/o209_x6_retry'; os.makedirs(ALT, exist_ok=True)
UNIT = {'경영·기획': 'AGENT_EXECUTIVE', '회원': 'AGENT_MEMBER', '마케팅': 'AGENT_MARKETING'}
ROWS = list(csv.DictReader(open(B.SRC, encoding='utf-8')))


def pairs():
    out = []
    for r in ROWS:
        for a in (UNIT[r['질문단위_수정안']], r['현업 예상 Agent']):
            if (r['문항ID'], a) not in [(x[0], x[1]) for x in out]:
                out.append((r['문항ID'], a, r['질문']))
    return out


def run(c):
    B.OUT = ALT if '--retry' in sys.argv else OUT
    return B.run(c)


def judge():
    # [O211] Q20 거짓 음성 보강 — 「알려 주세요」·「확인해 주세요」·「정해 주시면」(띄어쓰기 변이 포함)
    ask = re.compile(r'(계산할까요|진행할까요|드릴까요|원하시면|알려\s?주시면|확인해야|알려\s?주세요|확인해\s?주세요|정해\s?주시면)')
    eng = re.compile(r"\b(I'll|I will|Let me|Found it|There's|Now I)\b")
    by = {r['문항ID']: r for r in ROWS}
    w = csv.writer(open(f'{OUT}/_judge.csv', 'w', encoding='utf-8', newline=''))
    w.writerow(['문항ID', 'Agent', '정답Agent여부', '사용도구', '정답도구사용', '무도구정답', '라우팅판정',
                'MSTR기준', 'GN_DW기준', '계산전확인', '영문사고문'])
    for k, agent, _q in pairs():
        p = f'{ALT}/{k}__{agent}.json'
        if not os.path.exists(p):
            p = f'{OUT}/{k}__{agent}.json'
        if not os.path.exists(p):
            w.writerow([k, agent, '', 'MISSING']); continue
        d = json.load(open(p, encoding='utf-8'))
        t = ' '.join(c.get('text', '') for c in d.get('content', []) if c.get('type') == 'text')
        r = by[k]; ts = B.tools(d)
        exp = [x.strip() for x in r['정답 도구'].split(';')]
        hit = any(x in ts for x in exp)
        asked = bool(ask.search(t))
        notool = (not ts) and (('IT부서' in t) or (r['계산 전 확인'] == 'Y' and asked) or ('조회되지 않' in t) or ('산출할 수 없' in t))
        w.writerow([k, agent, agent == UNIT[r['질문단위_수정안']], ' '.join(ts), hit, notool,
                    hit or notool, 'MSTR 기준' in t, 'GN_DW 기준' in t, asked, bool(eng.search(t))])


if __name__ == '__main__':
    P = pairs()
    if '--agent' in sys.argv:
        ag = sys.argv[sys.argv.index('--agent') + 1]; P = [p for p in P if p[1] == ag]
    if '--only' in sys.argv:
        keep = set(sys.argv[sys.argv.index('--only') + 1].split(',')); P = [p for p in P if p[0] in keep]
    if '--judge' not in sys.argv:
        print('pairs', len(P), flush=True)
        with ThreadPoolExecutor(4) as ex:
            for r in ex.map(run, P):
                print(r, flush=True)
    judge()
