#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 트랜스크립트 위험신호 3건(rm -rf · 파이프 뒤 rc · python3 -c)의 실제 명령을 분리해 사람이 판정하게 한다.
# Co-authored with CoCo
import json
import re
import sys
from pathlib import Path


def walk(node, out):
    if isinstance(node, dict):
        out.append(node)
        for v in node.values():
            walk(v, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, out)


def load(path):
    raw = Path(path).read_text(encoding='utf-8', errors='replace')
    docs = []
    try:
        docs.append(json.loads(raw))
    except json.JSONDecodeError:
        for line in raw.splitlines():
            line = line.strip()
            if line:
                try:
                    docs.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    nodes = []
    for d in docs:
        walk(d, nodes)
    return nodes


PATTERNS = [
    ('A. rm 계열', re.compile(r'\brm\s+-rf|\brm\s+-r\b|\brm\s+')),
    ('B. 파이프 뒤 rc 판독', re.compile(r'\|\s*(?:tail|head|grep)[^\n]*\n?[^\n]*\$\?')),
    ('C. python3 -c', re.compile(r'python3\s+-c')),
]


def main():
    if len(sys.argv) < 2:
        print('사용법: python3 scripts/_o144f_risk_probe.py <transcript.json>')
        return 2
    nodes = load(sys.argv[1])
    cmds = []
    for nd in nodes:
        inp = nd.get('input') or nd.get('parameters') or nd.get('arguments')
        if isinstance(inp, str):
            try:
                inp = json.loads(inp)
            except json.JSONDecodeError:
                inp = None
        if isinstance(inp, dict) and isinstance(inp.get('command'), str):
            cmds.append(inp['command'])
    seen, uniq = set(), []
    for c in cmds:
        if c not in seen:
            seen.add(c)
            uniq.append(c)
    print('bash 명령 고유 %d건' % len(uniq))
    for label, rx in PATTERNS:
        hits = [c for c in uniq if rx.search(c)]
        print('\n=== %s — %d건 ===' % (label, len(hits)))
        for n, h in enumerate(hits, 1):
            one = ' '.join(h.split())
            print('  [%d] %s' % (n, one))
    return 0


if __name__ == '__main__':
    sys.exit(main())
