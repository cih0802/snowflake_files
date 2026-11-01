#!/usr/bin/env python3
"""06_DDL.sql COMMENT 길이·중복 실측 (조사 도구 · 재생성판).

경위 = 2026-08-20 세션에서 git pull 이 선행 사본을 제거했다.
      선행 측정치(195,103 B 기준)는 stale 이므로 이 도구로 재측정한다.

🔴 이 도구는 **후보만** 낸다. 자동 삭제는 금지다(P58) — 컬럼별 판단이 필요하다.
🔴 R2-8-1 = 삭제 전 그 문장이 목적지(테이블 COMMENT)에 실재하는지 대조한다.
길이는 문자 기준이다(R1-5-4 · awk 바이트 오탐 회피).

사용법
  python3 scripts/comment_len_probe.py            # 길이 분포 + 상위
  python3 scripts/comment_len_probe.py --dup      # 문면 동일 절 중복
"""
import io
import re
import sys
from collections import defaultdict

PATH = '/workspace/03_top-down_gold/06_DDL.sql'

RE_COL = re.compile(
    r"^\s{2,}(?P<col>[A-Z_0-9]+)\s+.*?\bCOMMENT\s+'(?P<body>.*)'\s*,?\s*$")
RE_TBL = re.compile(r"^\s*\)\s*COMMENT\s*=\s*'(?P<body>.*)'")
# 🔴 FQN 의 **마지막** 세그먼트를 잡아야 한다.
#   선행판은 비탐욕 접두 때문에 첫 세그먼트(`GN_DW`)를 잡아 35테이블이 1개로 뭉쳤다.
RE_CREATE = re.compile(
    r"CREATE\s+(?:OR\s+REPLACE\s+)?(?:TRANSIENT\s+)?TABLE\s+"
    r"(?:IF\s+NOT\s+EXISTS\s+)?(?P<fq>[A-Za-z0-9_.\"]+)",
    re.IGNORECASE)

SPLIT = re.compile(
    r'\s·\s'
    r'|(?<=[.다])\s+(?=[🔴🟢⚠️✅🔷])'
    r'|(?<=\.)\s{1,2}(?=[A-Z가-힣🔴🟢⚠])')


def clauses(body):
    """COMMENT 본문을 절 목록으로 자른다. 18자 미만 조각은 버린다."""
    out = []
    for c in SPLIT.split(body):
        c = (c or '').strip().strip('·').strip()
        if len(c) >= 18:
            out.append(c)
    return out


def norm(s):
    """대조용 정규화 — 강조 마커·따옴표·공백 제거(문면 차이를 흡수)."""
    s = re.sub(r'[*`\'"]', '', s)
    return re.sub(r'\s+', '', s)


def parse():
    lines = io.open(PATH, encoding='utf-8').read().splitlines()
    cur = None
    tables = {}
    order = []
    for i, line in enumerate(lines, start=1):
        m = RE_CREATE.search(line)
        if m:
            cur = m.group('fq').split('.')[-1].strip('"')
            if cur not in tables:
                tables[cur] = {'cols': [], 'tbl': None, 'tbl_line': None}
                order.append(cur)
            continue
        if cur is None:
            continue
        m = RE_TBL.match(line)
        if m:
            tables[cur]['tbl'] = m.group('body')
            tables[cur]['tbl_line'] = i
            cur = None
            continue
        m = RE_COL.match(line)
        if m:
            tables[cur]['cols'].append((m.group('col'), m.group('body'), i))
    return tables, order


def report_len(tables, order):
    cols = []
    tbls = []
    for t in order:
        d = tables[t]
        for c, b, ln in d['cols']:
            cols.append((t, c, len(b), ln))
        if d['tbl'] is not None:
            tbls.append((t, len(d['tbl']), d['tbl_line']))

    lens = sorted(x[2] for x in cols)
    n = len(lens)
    if not n:
        print('컬럼 COMMENT 0건 — 정규식 점검 필요')
        return 1

    def pct(p):
        return lens[min(n - 1, int(n * p))]

    print('== 컬럼 COMMENT 길이 분포 (문자) ==')
    print('  건수      :', n)
    print('  중위/p75  :', pct(0.50), '/', pct(0.75))
    print('  p90/p95   :', pct(0.90), '/', pct(0.95))
    print('  최대/합계 :', lens[-1], '/', sum(lens))
    for thr in (100, 200, 300, 400, 600):
        c = sum(1 for x in lens if x > thr)
        print(f'  > {thr:>4}자 : {c:>4}건 ({c / n * 100:.1f}%)')

    print()
    print('== 테이블 COMMENT 길이 분포 (문자) ==')
    tl = sorted(x[1] for x in tbls)
    if tl:
        print('  건수/중위/최대/합계 :',
              len(tl), '/', tl[len(tl) // 2], '/', tl[-1], '/', sum(tl))

    print()
    print('== 컬럼 COMMENT 길이 상위 15 ==')
    for t, c, ln, no in sorted(cols, key=lambda x: -x[2])[:15]:
        print(f'  {ln:>5}자  L{no:>5}  {t}.{c}')

    print()
    print('== 테이블별 컬럼 COMMENT 총량 상위 12 ==')
    agg = defaultdict(lambda: [0, 0])
    for t, c, ln, no in cols:
        agg[t][0] += 1
        agg[t][1] += ln
    for t, (cnt, tot) in sorted(agg.items(), key=lambda x: -x[1][1])[:12]:
        print(f'  {tot:>7}자  컬럼 {cnt:>3}개  평균 {tot // max(cnt, 1):>4}자  {t}')
    return 0


def report_dup(tables, order):
    seen = defaultdict(list)
    for t in order:
        for col, body, ln in tables[t]['cols']:
            for c in clauses(body):
                seen[norm(c)].append((t, col, c, ln))

    dup = [v for v in seen.values() if len(v) >= 2]
    dup.sort(key=lambda v: -(len(v) - 1) * len(v[0][2]))
    total = sum((len(v) - 1) * len(v[0][2]) for v in dup)
    allc = sum(len(b) for t in order for _, b, _ in tables[t]['cols'])

    print(f'== 문면 동일 절 중복 : {len(dup)}종 ==')
    for v in dup[:20]:
        waste = (len(v) - 1) * len(v[0][2])
        tabs = sorted({x[0] for x in v})
        same = len(tabs) == 1
        in_tbl = ''
        if same:
            tb = norm(tables[tabs[0]]['tbl'] or '')
            in_tbl = ' 🟢테이블실재' if norm(v[0][2]) in tb else ' 🔴테이블부재'
        print(f'  {len(v)}회 {len(v[0][2]):>4}자 (제거가능 {waste:>4}자)'
              f'{" [동일테이블]" + in_tbl if same else " [테이블간]"}')
        print(f'       {v[0][2][:100]}')
        print(f'       @ {"/".join(tabs)}')
    print()
    print(f'제거가능 합계 : {total}자 / 컬럼COMMENT 총 {allc}자 '
          f'= {total / max(allc, 1) * 100:.1f}%')
    return 0


def main():
    tables, order = parse()
    if '--dup' in sys.argv:
        return report_dup(tables, order)
    return report_len(tables, order)


if __name__ == '__main__':
    sys.exit(main())
