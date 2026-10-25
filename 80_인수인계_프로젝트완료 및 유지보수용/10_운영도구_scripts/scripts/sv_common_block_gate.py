#!/usr/bin/env python3
"""SV AI_SQL_GENERATION 이 정본 공통 블록(00_SV_공통지시문.md)으로 시작하는가 · 소스+라이브 · O262 R-SV1

🆕 [O262 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `JUDGE` — 종료코드가 판정이다(0 통과 · 1 위반 · 2 실행 오류 = 미판정). 음성 테스트 = `scripts/test_sv_common_block_gate.py`.

축
  SRC_MISSING  소스 SV 지시문이 정본 블록으로 시작하지 않는다(누락·변형·순서 — 고유 절이 앞에 옴)
  SRC_NONE     분모 파일에 지시문(AI_SQL_GENERATION)이 하나도 없다
  LIVE_MISSING 라이브 SV(SERVING) 지시문이 정본 블록으로 시작하지 않는다(미배포·드리프트)
  CANON        정본 문서에서 블록을 못 읽었다(rc=2)
정본 = `05_SV-Agent_ai/00_SV_공통지시문.md` 의 CANON-BEGIN ~ CANON-END(SQL 소스 표기 · 라이브는 '' → ').
분모(소스) = SV 폴더의 05_*·22_~25_·34_~36_ SV DDL. 라이브 = `SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING` 전건.
"""
import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
#: 워크스페이스 → 80 패키지 순(sv_no_rollup_gate 와 같은 규칙)
SV_CANDIDATES = (os.path.join(ROOT, '05_SV-Agent_ai'),
                 os.path.join(os.path.dirname(ROOT), '01_실행순서_배포SQL', '05_SV-Agent_ai'))
SV_DIR = next((d for d in SV_CANDIDATES if os.path.isdir(d)), SV_CANDIDATES[0])
CANON_DOC = '00_SV_공통지시문.md'
PREFIX = re.compile(r'^(05_\d{2}_|2[2-5]_|3[4-6]_).*\.sql$')
#: SV 폴더 밖 SV 정본(sv_no_rollup_gate.EXTRA 와 같은 파일 · SV_DIR 기준 상대) — 없으면 건너뛴다(80 패키지)
EXTRA = ('../15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql',)
LIT = re.compile(r"AI_SQL_GENERATION\s+'", re.I)


def read_canon(sv_dir):
    t = io.open(os.path.join(sv_dir, CANON_DOC), encoding='utf-8').read()
    m = re.search(r'<!-- CANON-BEGIN -->\n(.*?)\n<!-- CANON-END -->', t, re.S)
    if not m or not m.group(1).strip():
        raise ValueError('정본 블록 없음: %s' % CANON_DOC)
    return m.group(1).rstrip()


def literals(t):
    """AI_SQL_GENERATION '…' 본문 목록 — '' 이스케이프를 건너뛴다."""
    out = []
    for m in LIT.finditer(t):
        i = m.end()
        while True:
            j = t.find("'", i)
            if j < 0:
                return out
            if t[j + 1:j + 2] == "'":
                i = j + 2
                continue
            out.append((m.end(), t[m.end():j]))
            break
    return out


def check_source(sv_dir, canon):
    rows, n = [], 0
    names = [f for f in sorted(os.listdir(sv_dir)) if PREFIX.match(f)]
    names += [x for x in EXTRA if os.path.exists(os.path.join(sv_dir, x))]
    for f in names:
        t = io.open(os.path.join(sv_dir, f), encoding='utf-8').read()
        lits = literals(t)
        if not lits:
            continue
        for pos, body in lits:
            n += 1
            if not body.startswith(canon):
                rows.append(('SRC_MISSING', f, t.count('\n', 0, pos) + 1, body[:60]))
    return n, rows


def check_live(cur, canon_live):
    cur.execute('USE WAREHOUSE ' + os.environ.get('GN_DW_WAREHOUSE', 'GN_DW_DEV_WH'))
    cur.execute('SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING')
    ni = [c[0] for c in cur.description].index('name')
    names = [r[ni] for r in cur.fetchall()]
    rows = []
    for sv in names:
        cur.execute('DESCRIBE SEMANTIC VIEW GN_DW.SERVING.%s' % sv)
        cols = [c[0].lower() for c in cur.description]
        txt = None
        for d in (dict(zip(cols, r)) for r in cur.fetchall()):
            if d.get('object_kind') == 'CUSTOM_INSTRUCTION' and d.get('property') == 'AI_SQL_GENERATION':
                txt = d.get('property_value') or ''
        if txt is None or not txt.startswith(canon_live):
            rows.append(('LIVE_MISSING', sv, 0, (txt or '(지시문 없음)')[:60]))
    return len(names), rows


def main(argv=None):
    ap = argparse.ArgumentParser(description='SV 공통 지시문 블록 R-SV1 검사(rc 0 통과 · 1 위반 · 2 미판정)')
    ap.add_argument('--sv-dir', default=SV_DIR, help='SV DDL 폴더(기본 = 자동 탐지 %s)' % SV_DIR)
    ap.add_argument('--source-only', action='store_true', help='라이브 접속 없이 소스만 검사')
    a = ap.parse_args(argv)
    try:
        canon = read_canon(a.sv_dir)
    except Exception as e:
        print('🔴 CANON 실행 오류(미판정): %s' % e)
        return 2
    n_src, rows = check_source(a.sv_dir, canon)
    if n_src == 0:
        print('🔴 SRC_NONE — 분모 지시문 0(경로 확인)')
        return 1
    n_live = '-'
    if not a.source_only:
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import sfconn
            cn = sfconn.conn()
            try:
                n_live, live_rows = check_live(cn.cursor(), canon.replace("''", "'"))
            finally:
                cn.close()
        except Exception as e:  # 접속 실패를 「위반 0」으로 읽지 않게 rc=2
            print('🔴 라이브 실행 오류(미판정): %s' % e)
            return 2
        rows += live_rows
    for k, f, line, head in rows:
        print('  🔴 %s %s%s %r' % (k, f, ':%d' % line if line else '', head))
    print('소스 지시문 %d · 라이브 SV %s · 위반 %d' % (n_src, n_live, len(rows)))
    print('✅ 게이트 통과' if not rows else '❌ 게이트 실패')
    return 1 if rows else 0


if __name__ == '__main__':
    sys.exit(main())
