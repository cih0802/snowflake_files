"""O261 · SV COMMENT 「실제값 N종」 → 「주요 값(…)」 치환 + 라이브 신규값 목록 추가.
사용: python3 enum_rewrite.py [--apply]   (기본 = dry-run · 결과 = tmp/o261/enum_rewrite_report.csv)
- 대상 = tmp/o261/targets.txt · 라이브 매핑 = tmp/o261/enum_check.csv(DESCRIBE 결과)
- 값 목록 형식 = SQL 문자열 안의 ''값'' (두 홑따옴표). 목록이 없는 COMMENT 는 문구만 바꾼다.
- 신규값 추가 조건 = 라이브 DISTINCT ≤ MAX_LIVE · 기존 목록 1개 이상 · 마지막 ''값'' 뒤에 ·''신규'' 삽입.
"""
import sys, re, csv
sys.path.insert(0, '/workspace/scripts')
import sfconn

APPLY = '--apply' in sys.argv
MAX_LIVE = 60
PHRASE = '주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인)'
N_PAT = re.compile(r'(이 차원의 )?실제값\s*[0-9]+\s*종(\s*예)?')
SV_PAT = re.compile(r'SEMANTIC\s+VIEW\s+(?:IF\s+NOT\s+EXISTS\s+)?GN_DW\.(\w+)\.(\w+)', re.I)
DIM_PAT = re.compile(r"(\w+)\.(\w+)\s+AS\s+\w+\.\w+((?:(?!\bAS\b).)*?)COMMENT\s*=\s*'((?:[^']|'')*)'", re.S | re.I)
VAL_PAT = re.compile(r"''((?:[^']|'''')*?)''")
MIN_COVER = 0.5   # 따옴표 목록이 라이브 값의 이 비율 이상일 때만 신규값을 추가(다른 형식 나열 · 범위 표기 제외)
# 잘린 값 교정(라이브 실측 · DIM_AD_CREATIVE.CM_POSITION = E-1st·E-4th · 'st'·'th' 0행)
FIXES = {('SV_AD', 'AD', 'CM_POSITION'): [("''st''", "''E-1st''"), ("''th''", "''E-4th''")]}

mapping = {}
with open('/workspace/tmp/o261/enum_check.csv', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        mapping[(r['sv'].upper(), r['logical_table'].upper(), r['dimension'].upper())] = (r['base_table'], r['expr'])

cn = sfconn.conn()
cur = cn.cursor()
cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
cache = {}

def live_values(base, expr):
    col = expr.split('.')[-1].upper()
    k = (base, col)
    if k not in cache:
        cur.execute(f'SELECT COUNT(DISTINCT "{col}") FROM {base}')
        n = cur.fetchone()[0]
        vals = None
        if n <= MAX_LIVE:
            cur.execute(f'SELECT DISTINCT "{col}"::VARCHAR FROM {base} WHERE "{col}" IS NOT NULL ORDER BY 1')
            vals = [r[0] for r in cur.fetchall()]
        cache[k] = vals
    return cache[k]

report = []
targets = [l.strip() for l in open('/workspace/tmp/o261/targets.txt', encoding='utf-8') if l.strip()]
for path in targets:
    full = '/workspace/' + path
    text = open(full, encoding='utf-8').read()
    svpos = [(m.start(), m.group(2).upper()) for m in SV_PAT.finditer(text)]
    out, last, changed = [], 0, 0
    for m in DIM_PAT.finditer(text):
        cm = m.group(4)
        if not N_PAT.search(cm):
            continue
        sv = next((n for p, n in reversed(svpos) if p < m.start()), None)
        key = (sv, m.group(1).upper(), m.group(2).upper())
        new = N_PAT.sub(PHRASE, cm, count=1)
        for a, b in FIXES.get(key, []):
            new = new.replace(a, b)
        added = []
        listed = [v.replace("''''", "'") for v in VAL_PAT.findall(new)]
        if key in mapping and listed:
            vals = live_values(*mapping[key])
            if vals and sum(1 for v in vals if v in listed) / len(vals) >= MIN_COVER:
                added = [v for v in vals if v not in listed and "'" not in v]
                if added:
                    # 첫 목록 덩어리(·로 이어진 ''값'' 연속)의 끝에 붙인다 — 뒤 경고문의 ''값'' 뒤에 붙지 않게(O261 실측 오삽입 1건 교정)
                    run = re.search(r"''(?:[^']|'''')*?''(?:·''(?:[^']|'''')*?'')*", new)
                    ins = ''.join("·''" + v + "''" for v in added)
                    new = new[:run.end()] + ins + new[run.end():]
        s, e = m.start(4), m.end(4)
        out.append(text[last:s]); out.append(new); last = e
        changed += 1
        report.append([path, sv, key[1], key[2], 'MAPPED' if key in mapping else 'UNMAPPED',
                       len(listed), '|'.join(added)])
    out.append(text[last:])
    newtext = ''.join(out)
    if APPLY and changed and newtext != text:
        open(full, 'w', encoding='utf-8').write(newtext)
    remain = len(N_PAT.findall(newtext))
    print(f'{path}: 치환 {changed} · 잔존 「실제값 N종」 {remain}')
cn.close()

with open('/workspace/tmp/o261/enum_rewrite_report.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['file', 'sv', 'table', 'dimension', 'map', 'listed_n', 'added'])
    w.writerows(report)
print('TOTAL', len(report), '· 신규값 추가 차원', sum(1 for r in report if r[-1]), '· APPLY' if APPLY else '· DRY-RUN')
for r in report:
    if r[-1]:
        print('ADD', r[1], r[3], r[-1])
