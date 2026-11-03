"""O261 · sv_code_label_gate 🟠 열거 누락(§6.9-(5)) 보강 — COMMENT 끝에 「주요 값(…): ''a''·''b''」 추가.
사용: python3 enum_fill.py [--apply]   (기본 dry-run · 보고 = tmp/o261/enum_fill_report.csv)
- 대상 = tmp/o261/sv_code_label.out 의 열거 누락 줄(SV.DIM) · 값 = 라이브 DISTINCT(NULL·'' 제외 · ≤ 20)
- 편집 = 05_SV-Agent_ai/*.sql · 15_MSTR…/05_MSTR_SV_DDL.sql 중 그 SV 를 정의하는 **모든** 파일의 같은 차원(후행 덮어쓰기 파일 일관)
- 제외 = 값에 따옴표·줄바꿈 · 값 길이 > 60 · EXCLUDE(개인정보·자유텍스트 판단) → 보고서 SKIP 사유
"""
import sys, re, csv, glob
sys.path.insert(0, '/workspace/scripts')
import sfconn

APPLY = '--apply' in sys.argv
PHRASE = ' 주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): '
LINE = re.compile(r"열거 누락\(§6\.9-\(5\)\): (\w+)\.(\w+) ▸ (\w+) distinct (\d+)종")
SV_PAT = re.compile(r'SEMANTIC\s+VIEW\s+(?:IF\s+NOT\s+EXISTS\s+)?GN_DW\.(\w+)\.(\w+)', re.I)
# 🔴 COMMENT 없는 항목이 있으면 lazy 매치가 다음 항목의 COMMENT 까지 삼킨다 ⇒ 다음 항목 경계(`,\n  x.y AS`)에서 멈춘다(dry-run 1차 미발견 37건 원인)
DIM_PAT = re.compile(r"(\w+)\.(\w+)\s+AS\s+((?:(?!\bCOMMENT\b)(?!,\s*\w+\.\w+\s+AS\b)[^;])*?)COMMENT\s*=\s*'((?:[^']|'')*)'", re.S | re.I)
EXCLUDE = {('SV_MEMBER_SERVICE_COHORT', 'CHRG_DEPT_NAMES')}   # 부서명 조합 텍스트(범주 아님) · dry-run 검토 결과

targets = {}
for l in open('/workspace/tmp/o261/sv_code_label.out', encoding='utf-8'):
    m = LINE.search(l)
    if m:
        targets[(m.group(1).upper(), m.group(2).upper())] = m.group(3).upper()

FROM_REPORT = '--from-report' in sys.argv   # 직전 보고서의 라이브 값 재사용(재조회 생략)
values, report = {}, []
if FROM_REPORT:
    for r in csv.DictReader(open('/workspace/tmp/o261/enum_fill_report.csv', encoding='utf-8')):
        if r['kind'] == 'FILL' or r['why'] == '소스 미발견':
            values[(r['sv'], r['dimension'])] = r['values'].split('|')
        else:
            report.append([r['sv'], r['dimension'], r['kind'], r['why'], r['values']])
for k in EXCLUDE:
    if values.pop(k, None) is not None:
        report.append([k[0], k[1], 'SKIP', 'EXCLUDE', ''])
cn = None if FROM_REPORT else sfconn.conn()
schema_of = {}
cur = cn.cursor() if cn else None
if cn:
    cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
for sch in (('SERVING', 'MSTR') if cn else ()):
    cur.execute(f'SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.{sch}')
    ni = [c[0] for c in cur.description].index('name')
    for r in cur.fetchall():
        schema_of[r[ni].upper()] = sch

for sv in (sorted({s for s, _ in targets}) if cn else []):
    cur.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.{schema_of[sv]}.{sv}')
    cols = [c[0].lower() for c in cur.description]
    base, dims = {}, {}
    for d in (dict(zip(cols, r)) for r in cur.fetchall()):
        if d['object_kind'] == 'TABLE':
            base.setdefault(d['object_name'], {})[d['property']] = d['property_value']
        elif d['object_kind'] == 'DIMENSION':
            dims.setdefault(d['object_name'].upper(), (d['parent_entity'], {}))[1][d['property']] = d['property_value']
    for (s2, dim), bc in targets.items():
        if s2 != sv:
            continue
        if dim not in dims:
            report.append([sv, dim, 'SKIP', 'DESCRIBE 미발견', '']); continue
        tbl, p = dims[dim]
        b = base.get(tbl, {})
        fq = '.'.join(x for x in (b.get('BASE_TABLE_DATABASE_NAME'), b.get('BASE_TABLE_SCHEMA_NAME'), b.get('BASE_TABLE_NAME')) if x)
        expr = (p.get('EXPRESSION') or '').strip()
        try:
            cur.execute(f'SELECT DISTINCT ({expr.split(".", 1)[1] if re.match(r"^\w+\.\w+$", expr) else expr})::VARCHAR v FROM {fq} t WHERE v IS NOT NULL AND v <> \'\' ORDER BY 1 LIMIT 21')
            vals = [r[0] for r in cur.fetchall()]
        except Exception as e:
            report.append([sv, dim, 'SKIP', f'조회 실패 {str(e)[:60]}', '']); continue
        why = ('EXCLUDE' if (sv, dim) in EXCLUDE else 'DISTINCT>20' if len(vals) > 20 else '값 없음' if not vals
               else '따옴표·줄바꿈' if any(("'" in v or '\n' in v) for v in vals) else '값 길이>60' if any(len(v) > 60 for v in vals) else '')
        if why:
            report.append([sv, dim, 'SKIP', why, '|'.join(vals[:5])]); continue
        values[(sv, dim)] = vals
if cn:
    cn.close()

files = sorted(glob.glob('/workspace/05_SV-Agent_ai/*.sql')) + ['/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql']
edited = {}
hit = set()
for full in files:
    text = open(full, encoding='utf-8').read()
    svpos = [(m.start(), m.group(2).upper()) for m in SV_PAT.finditer(text)]
    if not svpos:
        continue
    out, last, n = [], 0, 0
    for m in DIM_PAT.finditer(text):
        sv = next((nm for pp, nm in reversed(svpos) if pp < m.start()), None)
        key = (sv, m.group(2).upper())
        if key not in values or "''" in m.group(4) or '주요 값(' in m.group(4):
            continue
        cm = m.group(4).rstrip()
        add = PHRASE + '·'.join("''" + v + "''" for v in values[key])
        out.append(text[last:m.start(4)]); out.append(cm + add); last = m.end(4)
        n += 1; hit.add(key)
    if n:
        out.append(text[last:])
        edited[full] = n
        if APPLY:
            open(full, 'w', encoding='utf-8').write(''.join(out))
for k, v in values.items():
    report.append([k[0], k[1], 'FILL' if k in hit else 'SKIP', '' if k in hit else '소스 미발견', '|'.join(v)])
with open('/workspace/tmp/o261/enum_fill_report.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f); w.writerow(['sv', 'dimension', 'kind', 'why', 'values']); w.writerows(report)
for f_, n in edited.items():
    print(f_.replace('/workspace/', ''), n)
print('대상', len(targets), '· FILL', len(hit), '· SKIP', sum(r[2] == 'SKIP' for r in report), '· APPLY' if APPLY else '· DRY-RUN')
