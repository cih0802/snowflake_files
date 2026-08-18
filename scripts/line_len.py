#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""[2026-08-14 O82] 한 줄 길이 검사 — `R1-5-4` 의 blocking 게이트.

🔴 왜 awk 를 쓰지 않는가:
    종전 `R1-5-4` 는 `awk 'length($0)>2000'` 을 규정했는데 BusyBox awk 의
    `length()` 는 **바이트**를 센다. 한글은 UTF-8 에서 1자 = 3바이트이므로
    **문자 기준 1,907자인 줄이 3,091 로 잡혀 오탐**한다(O82 실측 · 인덱스 8줄).
    `read` 툴의 절단 기준은 **문자**이므로 판정도 문자로 해야 한다.

사용:
    python3 scripts/line_len.py <경로> [<경로> ...]
    python3 scripts/line_len.py --limit 1000 <경로>      # 권고 임계도 함께 볼 때

출력이 비어야 통과다(종료코드 0). 초과 줄이 있으면 종료코드 1.
"""
import argparse
import os
import sys

HARD = 2000          # 절대 상한 — `read` 가 이 지점에서 줄을 자른다
SOFT = 1000          # 권고 목표(안전 마진)


def scan(path, hard, soft):
    """(초과, 권고초과) 목록을 돌려준다. 문자 기준이다."""
    over, warn = [], []
    with open(path, 'rb') as fh:
        raw = fh.read()
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError as e:
        return None, None, '🔴 UTF-8 손상 — %s 바이트 지점에서 절단(부분 write 의심 · C5)' % e.start
    for n, line in enumerate(text.split('\n'), 1):
        if len(line) > hard:
            over.append((n, len(line)))
        elif len(line) > soft:
            warn.append((n, len(line)))
    return over, warn, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='+')
    ap.add_argument('--limit', type=int, default=HARD)
    ap.add_argument('--soft', type=int, default=SOFT)
    ap.add_argument('--quiet-soft', action='store_true',
                    help='권고 임계 초과는 출력하지 않는다')
    a = ap.parse_args()

    total_over = 0
    broken = []
    for p in a.paths:
        if not os.path.isfile(p):
            print('🔴 경로 부재: %s' % p)
            total_over += 1
            continue
        over, warn, err = scan(p, a.limit, a.soft)
        if err:
            print('%s: %s' % (p, err))
            broken.append(p)
            continue
        for n, c in over:
            print('%s:%d: %d자 (상한 %d 초과)' % (p, n, c, a.limit))
        total_over += len(over)
        if warn and not a.quiet_soft:
            for n, c in warn:
                print('  ⚠️ %s:%d: %d자 (권고 %d 초과 · 상한 이내)' % (p, n, c, a.soft))

    if broken:
        print('\n🔴 FAIL — UTF-8 손상 %d건' % len(broken))
        return 1
    if total_over:
        print('\n🔴 FAIL — 상한 초과 %d줄' % total_over)
        return 1
    print('🟢 PASS — %d파일 · 상한(%d자) 초과 0줄' % (len(a.paths), a.limit))
    return 0


if __name__ == '__main__':
    sys.exit(main())
