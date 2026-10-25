#!/usr/bin/env python3
"""SV COMMENT 열거 목록에 없는 라이브 신규값 0 · '실제값 N종' 종수 잔존 0 · O261

🔴 분류 = `JUDGE` — 종료코드가 판정이다(0 통과 · 1 위반 · 2 실행 오류). 음성 테스트 = `scripts/test_sv_enum_newvalue_gate.py`.

축
  STALE_COUNT  COMMENT 에 「실제값 N종」 종수 표기 잔존(O261 에서 폐지 — 값이 늘면 즉시 거짓이 된다)
  NEW          COMMENT 의 ''값'' 목록이 라이브 DISTINCT 의 MIN_COVER 이상을 덮는 차원(=열거 목록 차원)에서
               목록에 없는 라이브 값 — 목록이 낡아 Agent 가 실재 값을 누락한 답을 낸다
대조 제외(오탐 방지) = 라이브 DISTINCT > MAX_LIVE · 목록이 라이브를 MIN_COVER 미만으로 덮음(예시 나열·범위·단위 문구)
                     · 식이 단일 컬럼 참조가 아님.
처방 = NEW 값을 해당 SV 소스 COMMENT 목록에 추가 후 재배포(`tmp/o261/enum_rewrite.py` 참고). 결과 CSV = --out.
"""
import sys
import os
import re
import csv
import argparse

MAX_LIVE, MIN_COVER = 60, 0.5
# 🆕 [O261] 「실제값 N종」만 보던 1판은 변형(「원값 55종」·「실측 값 6종」·「값 3종:」) 18건을 놓쳤다 ⇒ `값 N종` 전반
N_PAT = re.compile(r'값\s*[0-9]+\s*종')
VAL_PAT = re.compile(r"''((?:[^']|'''')*?)''|'((?:[^'])*?)'")
COL_PAT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)$')


def stale_count(comment):
    return bool(N_PAT.search(comment or ''))


def listed_values(comment):
    return [a or b for a, b in VAL_PAT.findall(comment or '')]


def new_values(comment, live_vals):
    """열거 목록 차원이면 목록 밖 라이브 값 리스트, 대조 대상이 아니면 None."""
    listed = listed_values(comment)
    vals = [v for v in live_vals if v is not None]
    if not listed or not vals or len(vals) > MAX_LIVE:
        return None
    if sum(v in listed for v in vals) / len(vals) < MIN_COVER:
        return None
    return sorted(v for v in vals if v not in listed)


def scan(cur):
    cur.execute('USE WAREHOUSE ' + os.environ.get('GN_DW_WAREHOUSE', 'GN_DW_DEV_WH'))  # [O262] 덮어쓰기(기본값 불변)
    svs = []
    for sch in ('SERVING', 'MSTR'):
        cur.execute(f'SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.{sch}')
        ni = [c[0] for c in cur.description].index('name')
        svs += [(sch, r[ni]) for r in cur.fetchall()]
    rows, checked = [], 0
    for sch, sv in svs:
        cur.execute(f'DESCRIBE SEMANTIC VIEW GN_DW.{sch}.{sv}')
        cols = [c[0].lower() for c in cur.description]
        base, dims = {}, {}
        for d in (dict(zip(cols, r)) for r in cur.fetchall()):
            if d['object_kind'] == 'TABLE':
                base.setdefault(d['object_name'], {})[d['property']] = d['property_value']
            elif d['object_kind'] == 'DIMENSION':
                dims.setdefault((d['parent_entity'], d['object_name']), {})[d['property']] = d['property_value']
        for (tbl, dname), p in dims.items():
            cm = p.get('COMMENT') or ''
            if stale_count(cm):
                rows.append([sv, dname, 'STALE_COUNT', ''])
            m = COL_PAT.match((p.get('EXPRESSION') or '').strip())
            b = base.get(tbl, {})
            fq = '.'.join(x for x in (b.get('BASE_TABLE_DATABASE_NAME'), b.get('BASE_TABLE_SCHEMA_NAME'), b.get('BASE_TABLE_NAME')) if x)
            if not (listed_values(cm) and m and fq.count('.') == 2):
                continue
            col = m.group(1).upper()
            cur.execute(f'SELECT COUNT(DISTINCT "{col}") FROM {fq}')
            if cur.fetchone()[0] > MAX_LIVE:
                continue
            cur.execute(f'SELECT DISTINCT "{col}"::VARCHAR FROM {fq} WHERE "{col}" IS NOT NULL')
            new = new_values(cm, [r[0] for r in cur.fetchall()])
            if new is None:
                continue
            checked += 1
            if new:
                rows.append([sv, dname, 'NEW', '|'.join(new)])
    return len(svs), checked, rows


def main():
    ap = argparse.ArgumentParser()
    # [O262] 기본값 = 워크스페이스면 종전 경로 · 그 밖(80 패키지·로컬)은 실행 폴더
    _ws = '/workspace/tmp'
    ap.add_argument('--out', default=os.path.join(_ws if os.path.isdir(_ws) else os.getcwd(), 'sv_enum_newvalue.csv'))
    a = ap.parse_args()
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # [O262] 자기 폴더 기준
        import sfconn
        cn = sfconn.conn()
        try:
            nsv, checked, rows = scan(cn.cursor())
        finally:
            cn.close()
    except Exception as e:  # 실행 실패를 「위반 0」으로 읽지 않게 rc=2
        print(f'🔴 실행 오류(미판정): {e}')
        return 2
    with open(a.out, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['sv', 'dimension', 'kind', 'values'])
        w.writerows(rows)
    for r in rows:
        print(f'  🔴 {r[2]}: {r[0]}.{r[1]} {r[3]}')
    nst = sum(r[2] == 'STALE_COUNT' for r in rows)
    nnew = sum(r[2] == 'NEW' for r in rows)
    print(f'SV {nsv} · 목록 대조 차원 {checked} · STALE_COUNT {nst} · NEW {nnew} · 결과 {a.out}')
    if checked == 0:
        print('🔴 대조 차원 0 = 미판정(탐지 경로 고장 의심)')
        return 2
    print('✅ 게이트 통과' if not rows else '❌ 게이트 실패')
    return 1 if rows else 0


if __name__ == '__main__':
    sys.exit(main())
