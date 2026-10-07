#!/usr/bin/env python3
"""Agent 답변 원문(JSON) 판정 — 표 헤더 한글 + 본문 수치가 도구 결과 셀/열합에 근거하는가

🆕 [O207 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `NEEDS_ARGS`. 무인자 실행 = 사용법 출력 + rc=2.
승격 원본 = `tmp/o206_judge.py`(헤더 축) + `tmp/o206_numcheck.py`(수치 근거 축) — 판정 로직 무변경 통합.

사용법
    python3 scripts/agent_answer_judge.py <디렉터리> [<디렉터리> ...] [--axis header|num|all]

입력 = DATA_AGENT_RUN 응답 원문 JSON(`content` 배열) · 디렉터리 안 `*.json` 전부.

축
    header  표 헤더 한글 강제(O206 V1) — table 블록 rowType.name · chart field/title · 본문 마크다운 표 헤더.
            영문 식별자형 헤더(한글 0자 · `^[A-Za-z_][A-Za-z0-9_]*$`)가 1개라도 있으면 FAIL.
    num     본문 수치 근거(O206-C C1) — 본문의 금액(억원·만원·원)·명·건 수치가
            도구 결과 셀 값 또는 한 열의 합계와 반올림 허용오차 안에서 같은가. 없으면 CHECK(근거없음).
            🔴 한계 = 차이·비율·%p 는 보지 않는다 · 100 미만 정수(순위·개수)는 제외.

종료코드 = 0 전건 PASS(NO_TABLE 포함) · 1 FAIL 또는 CHECK 1건 이상 · 2 사용법 오류.
🔴 CHECK 는 「오류 확정」이 아니다 — 원문을 열어 두 행 덧셈(O206-C C3) 같은 정당 파생인지 사람이 본다.

Co-authored with CoCo
"""
import glob
import json
import os
import re
import sys

HANGUL = re.compile(r'[가-힣]')
ENG_ID = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
UNIT = {'억원': 1e8, '억': 1e8, '만원': 1e4, '원': 1, '명': 1, '건': 1}
PAT = re.compile(r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)\s*(억원|억|만원|원|명|건)')


def bad_header(name):
    return name is not None and not HANGUL.search(str(name)) and ENG_ID.match(str(name)) is not None


def judge_header(d):
    heads, bads = [], []
    for c in d['content']:
        if c.get('type') == 'table':
            names = [r['name'] for r in c['table']['result_set']['resultSetMetaData']['rowType']]
            heads.append(names)
            bads += [n for n in names if bad_header(n)]
        elif c.get('type') == 'chart':
            spec = json.loads(c['chart']['chart_spec'])
            s = json.dumps(spec, ensure_ascii=False)
            for f in re.findall(r'"(?:field|title)"\s*:\s*"([^"]+)"', s):
                if f not in ('key', 'value') and bad_header(f):
                    bads.append('chart:' + f)
        elif c.get('type') == 'text':
            lines = c['text'].splitlines()
            for i, line in enumerate(lines[1:], 1):
                if re.match(r'^\s*\|[\s\-:|]+\|\s*$', line):
                    cells = [x.strip().strip('*') for x in lines[i - 1].strip().strip('|').split('|')]
                    heads.append(cells)
                    bads += ['md:' + x for x in cells if bad_header(x)]
    verdict = 'NO_TABLE' if not heads else ('FAIL' if bads else 'PASS')
    return verdict, sorted(set(bads))


def evidence_pool(d):
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


def judge_num(d):
    vals, colsum = evidence_pool(d)
    if not vals:
        return 'NO_TABLE', []
    txt = ' '.join(c['text'] for c in d['content'] if c.get('type') == 'text')
    bad = []
    for m in PAT.finditer(txt):
        n = float(m.group(1).replace(',', ''))
        u = UNIT[m.group(2)]
        v = n * u
        if txt[max(0, m.start() - 1):m.start()] in ('-', '−'):
            v = -v
        if abs(v) < 100 and u == 1:
            continue
        if u == 1e8:
            tol_unit = 0.1e8 if '.' in m.group(1) else 1e8
        else:
            tol_unit = u
        if not (close(v, vals, tol_unit) or close(v, colsum, tol_unit)):
            ctx = txt[max(0, m.start() - 30):m.end() + 5].replace('\n', ' ')
            bad.append(f'{m.group(0)} «{ctx}»')
    return ('PASS' if not bad else 'CHECK'), bad


def main(argv):
    axis = 'all'
    dirs = []
    i = 0
    while i < len(argv):
        if argv[i] == '--axis' and i + 1 < len(argv):
            axis = argv[i + 1]
            i += 2
            continue
        dirs.append(argv[i])
        i += 1
    if not dirs or axis not in ('header', 'num', 'all'):
        print(__doc__)
        return 2
    tot = {'PASS': 0, 'FAIL': 0, 'CHECK': 0, 'NO_TABLE': 0, 'ERROR': 0}
    for d0 in dirs:
        files = sorted(glob.glob(os.path.join(d0, '*.json')))
        if not files:
            print(f'{d0}: *.json 0건 — 경로 확인')
            return 2
        for p in files:
            name = f'{os.path.basename(d0.rstrip("/"))}/{os.path.basename(p)[:-5]}'
            d = json.load(open(p, encoding='utf-8'))
            if 'content' not in d:
                tot['ERROR'] += 1
                print(f'{name:24} ERROR    {str(d)[:120]}')
                continue
            if axis in ('header', 'all'):
                v, bads = judge_header(d)
                tot[v] += 1
                print(f'{name:24} header {v:8} 영문헤더={bads}')
            if axis in ('num', 'all'):
                v, bads = judge_num(d)
                tot[v] += 1
                print(f'{name:24} num    {v:8} 근거없음={len(bads)}')
                for b in bads[:6]:
                    print('        ', b[:150])
    print(tot)
    return 1 if (tot['FAIL'] or tot['CHECK'] or tot['ERROR']) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
