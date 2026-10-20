#!/usr/bin/env python3
"""N03 통합 데이터 사전 생성 — D01·D08·D09·D06 csv 를 지표 1행으로 잇고 xlsx·html 산출

🆕 [UNLABELED 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `GEN`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
🔴 산출물은 자동 생성물이다 — 손으로 고치면 다음 생성에서 사라진다.

사용법
    python3 scripts/n03_catalog_build.py <계정>        # 예: IW20760
    선행 = python3 scripts/b_struct_build.py <계정>     (D01·D06·D08·D09 csv 생성)

입력(85_실제 인수인계 문서/20_정식산출물/ · `#` 로 시작하는 각주 줄은 건너뛴다)
    · D01_지표매핑.csv     지표 → 도구 · SV 필드 · 대응 상태
    · D09_Agent도구.csv    도구 → 대상 SV
    · D08_SV메트릭.csv     SV 메트릭 식
    · D06_테이블계보.csv   SV base · 뷰 의존 · dbt ref · dbt source 간선
출력(같은 폴더 · 첫 줄/첫 행에 계정·생성 시각)
    · N03_통합데이터사전.csv · N03_통합데이터사전.xlsx(시트 = 통합사전 · 요약) · N03_통합데이터사전.html(검색 필터)

추적 규칙
    · SV 필드가 있으면 그 논리테이블의 base 객체에서 시작한다(추적범위 = 필드).
    · SV 필드가 없고 도구의 대상 SV 만 있으면 그 SV 의 base 전부에서 시작한다(추적범위 = SV 전체 · 넓다).
    · 둘 다 없으면 계보를 비운다(추적범위 = 없음 · D01 「산식 미등록」 지표).
    · 상향 추적 = DOWNSTREAM 이 현재 객체인 간선의 UPSTREAM 을 재귀로 모은다(방문 집합으로 순환 차단).

종료코드 = 0 성공 · 1 입력 부재 · 2 사용법 오류.
"""
import collections
import csv
import datetime
import html
import io
import os
import sys

BASE = '85_실제 인수인계 문서'
OUT = os.path.join(BASE, '20_정식산출물')
STEM = 'N03_통합데이터사전'
COLS = ['DOC_ID', '묶음', '지표', '정의', '산식', '대응상태', '적용Agent', '도구', '대상SV', 'SV필드', '필드종류',
        'SV식', 'SV_base', 'GOLD', 'SILVER', 'BRONZE', '기타상류', '추적범위', '지표원천']
LINEAGE_EDGES = ('view dependency', 'dbt ref', 'dbt source')


def read_csv(path):
    with open(path, encoding='utf-8-sig') as f:
        rows = [r for r in csv.reader(f) if r and not r[0].startswith('#')]
    head = rows[0]
    return [dict(zip(head, r)) for r in rows[1:]]


def sv_base_map(d06):
    """(SV, 논리테이블) → base 객체 집합. DOWNSTREAM 형식 = 'SERVING.<SV> (<TBL>)'."""
    m = collections.defaultdict(set)
    for e in d06:
        if e['EDGE_TYPE'] != 'SV base':
            continue
        down = e['DOWNSTREAM']
        obj, _, tbl = down.partition(' (')
        sv = obj.split('.', 1)[1] if '.' in obj else obj
        m[(sv.upper(), tbl.rstrip(')').upper())].add(e['UPSTREAM'])
    return m


def upstream_index(d06):
    up = collections.defaultdict(set)
    for e in d06:
        if e['EDGE_TYPE'] in LINEAGE_EDGES:
            up[e['DOWNSTREAM']].add(e['UPSTREAM'])
    return up


def walk_up(up, starts):
    """starts 에서 상류 전부(시작점 포함). 순환이 있어도 방문 집합으로 끝난다."""
    seen, stack = set(), list(starts)
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        stack.extend(up.get(n, ()))
    return seen


def split_layers(objs):
    out = {'GOLD': [], 'SILVER': [], 'BRONZE': [], '기타상류': []}
    for o in sorted(objs):
        sch = o.split('.', 1)[0]
        key = 'GOLD' if sch == 'GOLD' else 'SILVER' if sch == 'SILVER' else 'BRONZE' if sch.startswith('BRONZE') else '기타상류'
        out[key].append(o)
    return {k: ' | '.join(v) for k, v in out.items()}


def build(d01, d08m, d09, d06):
    tool_sv = {}
    for t in d09:
        if t['TOOL_TYPE'] == 'cortex_analyst_text_to_sql':
            tool_sv[t['TOOL_NAME']] = t['TARGET'].upper()
    metric_expr = {(m['SV_NAME'].upper(), m['TABLE'].upper(), m['METRIC'].upper()): m['EXPRESSION'] for m in d08m}
    bases = sv_base_map(d06)
    up = upstream_index(d06)
    rows = []
    for r in d01:
        tool = r.get('TOOL_NAME', '')
        field = r.get('SV_FIELD', '')
        sv, tbl, fld = (field.upper().split('.', 2) + ['', '', ''])[:3] if field else ('', '', '')
        target = sv or tool_sv.get(tool, '')
        if field:
            starts = bases.get((sv, tbl), set())
            scope = '필드' if starts else '필드(base 미해결)'   # 논리테이블명 불일치를 조용히 넘기지 않는다
        elif target:
            starts = set().union(*[v for (s, _), v in bases.items() if s == target] or [set()])
            scope = 'SV 전체'
        else:
            starts, scope = set(), '없음'
        expr = metric_expr.get((sv, tbl, fld), '')
        kind = '' if not field else ('메트릭' if expr else '차원·사실')
        lay = split_layers(walk_up(up, starts))   # 시작점(SV base)도 레이어 열에 포함한다
        rows.append({
            'DOC_ID': r['DOC_ID'], '묶음': r.get('SOURCE_GROUP', ''), '지표': r.get('METRIC', ''),
            '정의': r.get('DEFINITION', ''), '산식': r.get('FORMULA', ''), '대응상태': r.get('COVERAGE', ''),
            '적용Agent': r.get('AGENT_SCOPE', ''), '도구': tool, '대상SV': target, 'SV필드': field, '필드종류': kind,
            'SV식': expr, 'SV_base': ' | '.join(sorted(starts)), 'GOLD': lay['GOLD'], 'SILVER': lay['SILVER'],
            'BRONZE': lay['BRONZE'], '기타상류': lay['기타상류'], '추적범위': scope, '지표원천': r.get('SOURCE_FILE', ''),
        })
    return rows


def summary(rows):
    c = collections.Counter(r['추적범위'] for r in rows)
    reach = lambda k: sum(1 for r in rows if r[k])
    return [('지표', len(rows)), ('추적범위=필드', c['필드']), ('추적범위=필드(base 미해결)', c['필드(base 미해결)']),
            ('추적범위=SV 전체', c['SV 전체']), ('추적범위=없음', c['없음']),
            ('GOLD 도달', reach('GOLD')),
            ('SILVER 도달', reach('SILVER')), ('BRONZE 도달', reach('BRONZE'))]


def render_html(rows, note):
    head = ''.join(f'<th>{html.escape(c)}</th>' for c in COLS)
    body = '\n'.join('<tr>' + ''.join(f'<td>{html.escape(r[c])}</td>' for c in COLS) + '</tr>' for r in rows)
    return f"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8"><title>{STEM}</title>
<style>body{{font-family:sans-serif;font-size:12px}}table{{border-collapse:collapse}}td,th{{border:1px solid #ccc;padding:3px;vertical-align:top;max-width:360px}}th{{background:#eee;position:sticky;top:0}}</style>
</head><body>
<h1>N03 통합 데이터 사전</h1>
<p>{html.escape(note)}</p>
<p><input id="q" size="60" placeholder="지표·SV·테이블 이름으로 검색" oninput="f()"> <span id="n"></span></p>
<table id="t"><thead><tr>{head}</tr></thead><tbody>
{body}
</tbody></table>
<script>
function f(){{var q=document.getElementById('q').value.toLowerCase(),k=0;
document.querySelectorAll('#t tbody tr').forEach(function(r){{var s=r.textContent.toLowerCase().indexOf(q)>=0;r.style.display=s?'':'none';if(s)k++;}});
document.getElementById('n').textContent=k+' 행';}}
f();
</script>
</body></html>
"""


def clip_list(v, limit=400):
    """csv 한 줄 2000자 상한(R1-5) 대응 — ` | ` 목록을 limit 자에서 끊고 남은 개수를 붙인다. 전체는 xlsx·html 에 있다."""
    if len(v) <= limit:
        return v
    items, out = v.split(' | '), []
    for it in items:
        if len(' | '.join(out + [it])) > limit:
            break
        out.append(it)
    return ' | '.join(out) + f' | … 외 {len(items) - len(out)}개(전체 = xlsx·html)'


def write_bytes(path, data):
    # 스테이지 마운트는 seek 을 지원하지 않는다 → 메모리에서 완성해 한 번에 쓴다.
    with open(path, 'wb') as f:
        f.write(data)


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    acct = argv[1]
    need = ['D01_지표매핑.csv', 'D09_Agent도구.csv', 'D08_SV메트릭.csv', 'D06_테이블계보.csv']
    miss = [n for n in need if not os.path.exists(os.path.join(OUT, n))]
    if miss:
        print('🔴 입력 부재:', ', '.join(miss), '→ b_struct_build.py 선행')
        return 1
    d01, d09, d08m, d06 = (read_csv(os.path.join(OUT, n)) for n in need)
    rows = build(d01, d08m, d09, d06)
    ts = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).strftime('%Y-%m-%d %H:%M KST')
    note = f'# 생성 = scripts/n03_catalog_build.py {acct} · {ts} · 입력 = D01·D09·D08·D06 csv · 손으로 고치지 말 것'

    s = io.StringIO()
    s.write(note + '\n')
    w = csv.DictWriter(s, fieldnames=COLS, lineterminator='\n')
    w.writeheader()
    w.writerows({**r, **{k: clip_list(r[k]) for k in ('SV_base', 'GOLD', 'SILVER', 'BRONZE', '기타상류')}} for r in rows)
    write_bytes(os.path.join(OUT, STEM + '.csv'), s.getvalue().encode('utf-8'))

    import openpyxl
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = '통합사전'
    ws.append([note])
    ws.append(COLS)
    for r in rows:
        ws.append([r[c] for c in COLS])
    ws.freeze_panes = 'A3'
    sm = wb.create_sheet('요약')
    sm.append([note])
    for k, v in summary(rows):
        sm.append([k, v])
    b = io.BytesIO()
    wb.save(b)
    write_bytes(os.path.join(OUT, STEM + '.xlsx'), b.getvalue())

    write_bytes(os.path.join(OUT, STEM + '.html'), render_html(rows, note).encode('utf-8'))
    for k, v in summary(rows):
        print(f'{k} = {v}')
    print(f'🟢 {STEM} csv·xlsx·html → {OUT}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
