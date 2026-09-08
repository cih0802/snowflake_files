#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 원장 §1 대시보드 행의 문자 길이를 재어 1,900자 관례 여유를 판정한다.
# Co-authored with CoCo
import io
import sys

P = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-001.md'


def main():
    lines = io.open(P, encoding='utf-8').read().split('\n')
    for n in (150, 151):
        if n - 1 < len(lines):
            t = lines[n - 1]
            print('행 %d · 문자 %d · 여유(1900 기준) %d' % (n, len(t), 1900 - len(t)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
