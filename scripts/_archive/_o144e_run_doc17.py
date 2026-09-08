#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 문서17 의 ```sql 블록을 전량 추출해 문장 단위로 실제 실행하고 성공·실패·0행을 절 좌표와 함께 보고한다.
# Co-authored with CoCo
import re
import sys

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

DOC = '/workspace/30_output_share/17_9월3일기준 현업요청 확정.md'


def split_statements(block):
    """SQL 블록을 문장으로 쪼갠다 — 문자열 리터럴과 -- 주석 안의 세미콜론은 건너뛴다."""
    out, buf = [], []
    i, n = 0, len(block)
    in_s = False          # 단일 인용부호 안
    in_line_comment = False
    while i < n:
        ch = block[i]
        if in_line_comment:
            buf.append(ch)
            if ch == '\n':
                in_line_comment = False
            i += 1
            continue
        if in_s:
            buf.append(ch)
            if ch == "'":
                # 연속 '' 은 이스케이프
                if i + 1 < n and block[i + 1] == "'":
                    buf.append(block[i + 1])
                    i += 2
                    continue
                in_s = False
            i += 1
            continue
        if ch == '-' and i + 1 < n and block[i + 1] == '-':
            in_line_comment = True
            buf.append(ch)
            i += 1
            continue
        if ch == "'":
            in_s = True
            buf.append(ch)
            i += 1
            continue
        if ch == ';':
            out.append(''.join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    tail = ''.join(buf).strip()
    if tail:
        out.append(tail)
    return [s for s in (x.strip() for x in out) if s and not _only_comments(s)]


def _only_comments(s):
    """주석과 공백만 남은 조각은 문장이 아니다."""
    for line in s.split('\n'):
        t = line.strip()
        if t and not t.startswith('--'):
            return False
    return True


def extract():
    """(절 제목, 라벨, SQL문) 목록을 문서에서 뽑는다."""
    text = open(DOC, encoding='utf-8').read()
    lines = text.split('\n')
    items, heading, i = [], '(문서 서두)', 0
    while i < len(lines):
        line = lines[i]
        if line.startswith('###'):
            heading = line.lstrip('#').strip()
        if line.strip().startswith('```sql'):
            start = i + 1
            j = start
            while j < len(lines) and not lines[j].strip().startswith('```'):
                j += 1
            block = '\n'.join(lines[start:j])
            for stmt in split_statements(block):
                m = re.search(r'--\s*\[([^\]]+)\]', stmt)
                label = m.group(1) if m else '(라벨 없음)'
                items.append((heading, label, start + 1, stmt))
            i = j
        i += 1
    return items


def main():
    items = extract()
    print("문서17 에서 추출한 실행 대상 문장 = %d개\n" % len(items))
    c = conn()
    cur = c.cursor()
    cur.execute("USE WAREHOUSE GN_DW_DEV_WH")
    cur.execute("USE ROLE GN_DW_ADMIN")

    ok = fail = zero = 0
    for heading, label, ln, stmt in items:
        print("=" * 78)
        print("절 : %s" % heading)
        print("쿼리: [%s]  (문서 %d행 근처)" % (label, ln))
        try:
            rows = cur.execute(stmt).fetchall()
        except Exception as exc:
            fail += 1
            print("  🔴 실패 — %s: %s" % (type(exc).__name__, str(exc).split('\n')[0]))
            continue
        cols = [d[0] for d in cur.description]
        if not rows:
            zero += 1
            print("  🟠 0행 — 컬럼 %s" % (", ".join(cols)))
            continue
        ok += 1
        print("  🟢 %d행 · 컬럼 %s" % (len(rows), ", ".join(cols)))
        for r in rows[:8]:
            cells = ["" if v is None else str(v) for v in r]
            print("     " + " | ".join(x[:60] for x in cells))
        if len(rows) > 8:
            print("     ... (총 %d행)" % len(rows))

    print("=" * 78)
    print("집계 — 🟢 결과있음 %d · 🟠 0행 %d · 🔴 실패 %d (총 %d)"
          % (ok, zero, fail, len(items)))
    print("rc_ok")


if __name__ == '__main__':
    main()
