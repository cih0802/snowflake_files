#!/usr/bin/env python3
"""85번 인수인계 [ENV] 값 캡처 — 읽기 전용 SQL(-- Qnn 마커) 결과를 _ENV/<계정>/<ID>_<Qnn>.csv 로 기록

🆕 [UNLABELED 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `GEN`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
🔴 산출물은 자동 생성물이다 — 손으로 고치면 다음 생성에서 사라진다.

사용법
    python3 scripts/env_capture.py --id A0 "85_실제 인수인계 문서/10_실무자_인수인계/A0_환경실사_baseline.sql"

규약([ENV] 분리 · 85번 작업계획서 §1-10)
    · SQL 파일은 `-- Qnn <제목>` 줄로 블록을 나눈다. 블록 안 문장은 `;` 줄끝으로 나눈다.
    · 문장은 SELECT/WITH/SHOW/DESC/DESCRIBE 만 허용한다 — 하나라도 어기면 **실행 전에** rc=1.
    · 출력 = `85_실제 인수인계 문서/_ENV/<CURRENT_ACCOUNT>/<ID>_<Qnn>_<k>.csv` + `<ID>_manifest.csv`.
    · csv 첫 줄은 `#` 각주(doc_id · as_of · account · query) — 작업계획서 §1-7.
    · 셀 개행은 ` ⏎ ` 로 바꾸고, 한 줄 1900자 이내가 되도록 긴 셀을 절단한다(R1-5 · 절단 수는 manifest).

종료코드 = 0 성공 · 1 문장 거부/실행 오류(오류 문장은 manifest 에 ERROR) · 2 사용법 오류.
"""
import argparse
import csv
import datetime
import io
import os
import re
import sys

ALLOWED = ('SELECT', 'WITH', 'SHOW', 'DESC', 'DESCRIBE')
OUT_ROOT = os.path.join('85_실제 인수인계 문서', '_ENV')
ROW_LIMIT = 1900
CELL_CAPS = (400, 150, 60)
Q_RE = re.compile(r'^--\s*(Q\d+)\b(.*)$')


def parse_blocks(text):
    """`-- Qnn` 마커 기준 [(qid, title, [stmt, ...])]."""
    blocks, cur, buf = [], None, []
    for line in text.splitlines():
        m = Q_RE.match(line.strip())
        if m:
            cur = [m.group(1), m.group(2).strip(), []]
            blocks.append(cur)
            buf = []
            continue
        if cur is None or line.strip().startswith('--'):
            continue
        buf.append(line)
        if line.rstrip().endswith(';'):
            stmt = '\n'.join(buf).strip().rstrip(';').strip()
            if stmt:
                cur[2].append(stmt)
            buf = []
    return blocks


def first_kw(stmt):
    return stmt.split(None, 1)[0].upper() if stmt.split() else ''


def fit_row(cells):
    """셀 개행 치환 + 한 줄 ROW_LIMIT 이내가 되도록 긴 셀 절단. (cells, 절단 셀 수)."""
    cells = ['' if c is None else str(c).replace('\r', '').replace('\n', ' ⏎ ') for c in cells]
    cut = 0
    for cap in CELL_CAPS:
        if sum(len(c) + 3 for c in cells) <= ROW_LIMIT:
            break
        for i, c in enumerate(cells):
            if len(c) > cap:
                cells[i] = c[:cap] + '…[절단 %d자]' % (len(c) - cap)
                cut += 1
    return cells, cut


def connect():
    import snowflake.connector
    tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
    return snowflake.connector.connect(
        account=os.environ['SNOWFLAKE_ACCOUNT'],
        host=os.environ.get('SNOWFLAKE_HOST'),
        authenticator='oauth',
        token=tok,
        role=os.environ.get('SNOWFLAKE_ROLE'),
        warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE'),
    )


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('sql_path')
    ap.add_argument('--id', required=True, help='산출물 ID (예: A0)')
    if len(sys.argv) == 1:
        print(__doc__)
        return 2
    a = ap.parse_args()

    blocks = parse_blocks(io.open(a.sql_path, encoding='utf-8').read())
    bad = [(q, s) for q, _, ss in blocks for s in ss if first_kw(s) not in ALLOWED]
    if not blocks or bad:
        for q, s in bad:
            print('🔴 거부(읽기 전용 아님) %s: %s' % (q, s[:80]))
        if not blocks:
            print('🔴 Qnn 블록 0건')
        return 1

    con = connect()
    cur = con.cursor()
    cur.execute('SELECT CURRENT_ACCOUNT(), CURRENT_TIMESTAMP()::STRING')
    acct, now = cur.fetchone()
    out_dir = os.path.join(OUT_ROOT, acct)
    os.makedirs(out_dir, exist_ok=True)

    manifest, rc = [], 0
    for qid, title, stmts in blocks:
        for k, stmt in enumerate(stmts, 1):
            name = '%s_%s_%d.csv' % (a.id, qid, k)
            try:
                cur.execute(stmt)
                cols = [d[0] for d in cur.description] if cur.description else []
                rows = cur.fetchall() if cols else []
            except Exception as e:  # 오류 문장은 기록하고 계속한다
                rc = 1
                manifest.append([qid, k, name, 'ERROR', 0, 0, str(e).splitlines()[0][:300]])
                continue
            cut_total = 0
            sio = io.StringIO()
            w = csv.writer(sio, lineterminator='\n')
            sio.write('# doc_id: %s · as_of: %s · account: %s · query: %s-%d %s\n' % (a.id, now, acct, qid, k, title))
            hdr, _ = fit_row(cols)
            w.writerow(hdr)
            for r in rows:
                cells, cut = fit_row(r)
                cut_total += cut
                w.writerow(cells)
            io.open(os.path.join(out_dir, name), 'w', encoding='utf-8').write(sio.getvalue())
            manifest.append([qid, k, name, 'OK', len(rows), cut_total, first_kw(stmt) + ' ' + title])

    sio = io.StringIO()
    w = csv.writer(sio, lineterminator='\n')
    sio.write('# doc_id: %s · as_of: %s · account: %s · manifest\n' % (a.id, now, acct))
    w.writerow(['QID', 'K', 'FILE', 'STATUS', 'ROWS', 'CUT_CELLS', 'NOTE'])
    w.writerows(manifest)
    io.open(os.path.join(out_dir, '%s_manifest.csv' % a.id), 'w', encoding='utf-8').write(sio.getvalue())
    con.close()

    ok = sum(1 for m in manifest if m[3] == 'OK')
    print('%s %s · account=%s · 문장 %d · OK %d · ERROR %d → %s'
          % ('🟢' if rc == 0 else '🔴', a.id, acct, len(manifest), ok, len(manifest) - ok, out_dir))
    return rc


if __name__ == '__main__':
    sys.exit(main())
