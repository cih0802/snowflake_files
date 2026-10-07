# O206-C — 답변 본문 수치 근거 검사: 본문의 금액(억원·원)·건/명 수치가 도구 결과 표(셀 값 또는 열 합계)에서 나오는가
# 사용: python3 tmp/o206_numcheck.py <디렉터리...>
# 판정: 본문 수치 v 가 ① 어떤 표 셀 ② 어떤 표 한 열의 합계 와 반올림 허용오차 안에서 같으면 근거 있음.
#       없으면 「근거 없음」 — Agent 가 답변 작성 중 직접 계산(합계·차이·비율)했을 가능성이 크다.
# 🔴 한계 = 차이·비율·%p 는 셀에 없을 수 있다(정당한 SQL 산출이 아니어도 표기상 파생) ⇒ 금액(억원·원)과 명·건 만 본다.
# Co-authored with CoCo
import glob, json, os, re, sys

UNIT = {'억원': 1e8, '억': 1e8, '만원': 1e4, '원': 1, '명': 1, '건': 1}
PAT = re.compile(r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)\s*(억원|억|만원|원|명|건)')


def cells(d):
    """화면 표(table 블록) + 모든 도구 결과(tool_result 의 data 행)를 근거 풀로 모은다."""
    vals, cols = [], []

    def add_rows(rows, ncol):
        for j in range(ncol):
            col = []
            for r in rows:
                try:
                    col.append(float(r[j]))
                except Exception:
                    pass
            vals.extend(col)
            if col:
                cols.append(sum(col))

    def walk(x):
        if isinstance(x, dict):
            if isinstance(x.get('data'), list) and x['data'] and isinstance(x['data'][0], list):
                add_rows(x['data'], max(len(r) for r in x['data']))
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)

    for c in d['content']:
        if c.get('type') in ('table', 'tool_result'):
            walk(c)
    return vals, cols


def close(v, pool, unit):
    tol = max(abs(v) * 0.0006, 0.5 * (unit if unit > 1 else 1))
    return any(abs(v - p) <= tol for p in pool)


tot_bad = 0
for d0 in sys.argv[1:]:
    for p in sorted(glob.glob(f'{d0}/*.json')):
        d = json.load(open(p, encoding='utf-8'))
        if 'content' not in d:
            continue
        vals, colsum = cells(d)
        if not vals:
            continue
        txt = ' '.join(c['text'] for c in d['content'] if c.get('type') == 'text')
        bad = []
        for m in PAT.finditer(txt):
            n = float(m.group(1).replace(',', '')); u = UNIT[m.group(2)]; v = n * u
            if txt[max(0, m.start() - 1):m.start()] in ('-', '−'):   # 음수 표기
                v = -v
            if abs(v) < 100 and u == 1:      # 작은 수(순위·개수 등)는 제외
                continue
            # 억 표기 반올림 허용: 소수 1자리 → 0.05억 · 정수 → 0.5억 · 그 외 단위 1
            if u == 1e8:
                tol_unit = 0.1e8 if '.' in m.group(1) else 1e8
            else:
                tol_unit = u
            if not (close(v, vals, tol_unit) or close(v, colsum, tol_unit)):
                ctx = txt[max(0, m.start() - 30):m.end() + 5].replace('\n', ' ')
                bad.append(f'{m.group(0)} «{ctx}»')
        tag = 'PASS' if not bad else 'CHECK'
        tot_bad += len(bad)
        print(f'{d0.split("/")[-1]}/{os.path.basename(p)[:-5]:4} {tag:5} 근거없음={len(bad)}')
        for b in bad[:6]:
            print('       ', b[:150])
print('TOTAL 근거없음 =', tot_bad)
