#!/usr/bin/env python3
"""S30 운영계 실측 csv → census json + 개발계 대조표(30번 산출물 수치 판정의 운영계 판본)

🔴 분류 = `GEN`. 산출물은 자동 생성물이다 — 손으로 고치면 다음 생성에서 사라진다.

사용법
    python3 scripts/s30_census_to_json.py ZL50263              # 운영계 단독 판정(85번 R90 원칙 · 기본)
    python3 scripts/s30_census_to_json.py ZL50263 --base UM80684  # 참고용 개발계 열 추가

입력
    30_output_share/_ENV/<계정>/S30_manifest.csv · S30_Q01_1.csv · S30_Q02_1.csv · S30_Q03_1.csv …
        (env_capture.py --id S30 --out-root "30_output_share/_ENV" 생성물)
    (--base 지정 시) 30_output_share/_ENV/<base>/census_*.json 중 최신 — 참고 열일 뿐 판정 기준이 아니다
출력
    30_output_share/_ENV/<계정>/census_S30.json  — census_columns.py 와 같은 형식
        ⇒ GN_DW_CENSUS=<이 파일> 로 05·08·09 생성기에 넣을 수 있다.
    30_output_share/12_운영계_실측_<계정>.md — 0행 테이블 · 전건 NULL · 전건 0 판정(운영계 단독)

판정 규칙 = gen_concept_diagram.py 와 동일(행 0 ⇒ 0행 · nonnull 0 ⇒ 전건 NULL · nonzero 0 ⇒ 전건 0 · 감사 컬럼 제외).
종료코드 = 0 성공(실행 시점 부재만 있으면 0) · 1 입력 없음/manifest ERROR 존재 · 2 사용법 오류.
"""
import argparse
import csv
import glob
import io
import json
import os
import sys

WS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = os.path.join(WS, '30_output_share', '_ENV')
AUDIT = {'DW_SOURCE_SYSTEM', 'DW_SOURCE_TABLE', 'DW_LOAD_TS', 'DW_UPDATE_TS', 'DW_BATCH_ID'}
LBL = {'empty': '0행', 'null': '전건 NULL', 'zero': '전건 0', 'ok': '값 있음', None: '부재'}


def read_csv(path):
    """env_capture csv — 첫 줄 `#` 각주 반환 + DictReader 행."""
    with io.open(path, encoding='utf-8') as fp:
        head = fp.readline().strip()
        return head, list(csv.DictReader(fp))


def to_int(v):
    return None if v in (None, '') else int(float(v))


def load_ops(acct):
    d = os.path.join(ENV, acct)
    mpath = os.path.join(d, 'S30_manifest.csv')
    if not os.path.exists(mpath):
        print('🔴 %s 없음 — 운영계에서 env_capture 를 먼저 실행하라' % os.path.relpath(mpath, WS))
        sys.exit(1)
    mhead, man = read_csv(mpath)
    _, q01 = read_csv(os.path.join(d, 'S30_Q01_1.csv'))
    # 🆕 [2026-10-27 운영계 1회차] ① SQL 생성과 ② 실행 사이에 삭제된 객체(날짜 접미 백업 등)는 판정 대상이 아니다.
    #   실측 = ZL50263 Q142 `SILVER.MM_SPNSR_CLS_AGGR_DATA_261019` ⇒ ② 시점 Q01 에 없으면 「실행 시점 부재」로 분리한다.
    q_tbl = {}
    sql_path = os.path.join(WS, '30_output_share', '_근거쿼리', 'S30_census.sql')
    if os.path.exists(sql_path):
        for line in io.open(sql_path, encoding='utf-8'):
            if line.startswith('-- Q') and ' census ' in line:
                q_tbl[line.split()[1]] = line.split(' census ', 1)[1].strip()
    live = {'%s.%s' % (r['TABLE_SCHEMA'], r['TABLE_NAME']) for r in q01}
    bad = [m for m in man if m['STATUS'] != 'OK']
    gone = [dict(m, TABLE=q_tbl[m['QID']]) for m in bad if q_tbl.get(m['QID']) and q_tbl[m['QID']] not in live]
    gone_q = {g['QID'] for g in gone}
    errors = [m for m in bad if m['QID'] not in gone_q]
    _, q02 = read_csv(os.path.join(d, 'S30_Q02_1.csv'))
    types = {(r['TABLE_SCHEMA'], r['TABLE_NAME'], r['COLUMN_NAME']): r['DATA_TYPE'] for r in q02}
    census = {}
    for m in man:
        if m['STATUS'] != 'OK' or m['QID'] in ('Q01', 'Q02'):
            continue
        _, rows = read_csv(os.path.join(d, m['FILE']))
        for r in rows:
            key = '%s.%s' % (r['TABLE_SCHEMA'], r['TABLE_NAME'])
            e = census.setdefault(key, {'rows': to_int(r['ROWS_']), 'cols': {}})
            e['cols'][r['COLUMN_NAME']] = {
                'type': types.get((r['TABLE_SCHEMA'], r['TABLE_NAME'], r['COLUMN_NAME']), ''),
                'nonnull': to_int(r['NONNULL']), 'nonzero': to_int(r['NONZERO']), 'ndv': to_int(r['NDV']),
            }
    return mhead, man, errors, gone, q01, census


def load_base(base):
    paths = sorted(glob.glob(os.path.join(ENV, base, 'census_*.json')))
    if not paths:
        return None, {}
    return os.path.relpath(paths[-1], WS), json.load(io.open(paths[-1], encoding='utf-8'))


def status(entry, col):
    if entry is None:
        return None
    if entry['rows'] == 0:
        return 'empty'
    i = entry['cols'].get(col)
    if i is None:
        return None
    if not (i['nonnull'] or 0):
        return 'null'
    if not (i['nonzero'] or 0):
        return 'zero'
    return 'ok'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('account')
    ap.add_argument('--base', default=None, help='참고용 비교 계정(기본 없음)')
    if len(sys.argv) == 1:
        print(__doc__)
        return 2
    a = ap.parse_args()

    mhead, man, errors, gone, q01, ops = load_ops(a.account)
    base_path, base = load_base(a.base) if a.base else (None, {})
    hb = bool(a.base)
    out_json = os.path.join(ENV, a.account, 'census_S30.json')
    json.dump(ops, io.open(out_json, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

    as_of = mhead.split('as_of:')[1].split('·')[0].strip() if 'as_of:' in mhead else '?'
    keys = sorted(set(ops) | set(base))
    zero_tbl, col_rows, diff_rows = [], [], []
    for k in keys:
        o, b = ops.get(k), base.get(k)
        if (o and o['rows'] == 0) or (b and b['rows'] == 0):
            zero_tbl.append((k, o and o['rows'], b and b['rows']))
        if o and o['rows'] and b is not None and b['rows'] != o['rows']:
            diff_rows.append((k, o['rows'], b['rows']))
        cols = sorted(set((o or {}).get('cols', {})) | set((b or {}).get('cols', {})))
        for c in cols:
            if c in AUDIT:
                continue
            so, sb = status(o, c), status(b, c)
            if so in ('null', 'zero') or sb in ('null', 'zero'):
                col_rows.append((k, c, so, sb))

    bronze = [r for r in q01 if r['TABLE_SCHEMA'].startswith('BRONZE') and r['ROW_COUNT'] in ('0', '')
              and r['TABLE_TYPE'] == 'BASE TABLE']

    def cnt(v):
        return '—' if v is None else '{:,}'.format(v)

    L = ['<!-- 생성기 = scripts/s30_census_to_json.py · 손으로 고치지 않는다 -->',
         '# 30번 산출물 운영계 실측 — %s' % a.account, '',
         '> 측정 = **%s** · 근거 = `_ENV/%s/S30_*.csv`(`_근거쿼리/S30_census.sql`)' % (as_of, a.account),
         '> 판정 규칙 = `03_GN_DW_개념도.html` 과 동일(감사 컬럼 제외). 03·04·05·08·09 본문 수치는 개발계 실측이다 — '
         '운영계 수치 인용은 이 문서를 근거로 한다. 판정은 운영계 결과 안에서 닫힌다(85번 R90 원칙)'
         + (' · 개발계 열은 참고(`%s`)' % base_path if hb else '') + '.', '',
         '## 1. 실행 결과', '',
         '- census 문장 %d · OK %d · ERROR %d · 실행 시점 부재 %d' % (
             len(man), len(man) - len(errors) - len(gone), len(errors), len(gone))]
    for m in errors:
        L.append('  - 🔴 `%s` %s — %s' % (m['QID'], m['FILE'], m['NOTE'][:200]))
    for g in gone:
        L.append('  - 🟠 `%s` `%s` — ① SQL 생성 후 ② 실행 전에 사라진 객체(② 시점 Q01 에 없음) · 판정 대상 아님' % (g['QID'], g['TABLE']))
    L += ['', '## 2. 0행 테이블 (GOLD·SILVER·SERVING census)', '',
          '| 테이블 | 운영계 행수 |' + (' 개발계(참고) |' if hb else ''), '| :--- | ---: |' + (' ---: |' if hb else '')]
    L += ['| `%s` | %s |' % (k, cnt(o)) + (' %s |' % cnt(b) if hb else '') for k, o, b in zero_tbl] or ['| (없음) | |']
    L += ['', '## 3. BRONZE 0행 테이블 (`INFORMATION_SCHEMA.TABLES.ROW_COUNT`)', '',
          '| 테이블 | 최종 변경 |', '| :--- | :--- |']
    L += ['| `%s.%s` | %s |' % (r['TABLE_SCHEMA'], r['TABLE_NAME'], r['LAST_ALTERED'][:19]) for r in bronze] or ['| (없음) | |']
    L += ['', '## 4. 전건 NULL · 전건 0 컬럼 (0행 테이블 제외)', '',
          '| 테이블 | 컬럼 | 운영계 |' + (' 개발계(참고) |' if hb else ''), '| :--- | :--- | :--- |' + (' :--- |' if hb else '')]
    L += ['| `%s` | `%s` | %s |' % (k, c, LBL[so]) + (' %s |' % LBL[sb] if hb else '')
          for k, c, so, sb in col_rows if so in ('null', 'zero')] or ['| (없음) | | |']
    if hb:
        L += ['', '## 5. 참고 — 행수가 개발계와 다른 테이블', '', '| 테이블 | 운영계 | 개발계 |', '| :--- | ---: | ---: |']
        L += ['| `%s` | %s | %s |' % (k, cnt(o), cnt(b)) for k, o, b in diff_rows] or ['| (없음) | | |']

    out_md = os.path.join(WS, '30_output_share', '12_운영계_실측_%s.md' % a.account)
    io.open(out_md, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
    print('🟢 %s · %s' % (os.path.relpath(out_json, WS), os.path.relpath(out_md, WS)))
    print('   0행 %d · 전건NULL/0 컬럼 %d · ERROR %d' % (
        len(zero_tbl), sum(1 for r in col_rows if r[2] in ('null', 'zero')), len(errors))
        + (' · 참고 계정 대비 판정 불일치 %d · 행수 차이 %d' % (
            sum(1 for r in col_rows if r[2] != r[3]), len(diff_rows)) if hb else ''))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
