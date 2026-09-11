#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O154-B 자기검토 보조 — 트랜스크립트에서 `python3 -c` 명령 원문을 전건 추출한다.

🔴 왜 필요한가 = `o145_transcript_audit.py` 는 「발견/없음」만 내고 `python3 -c` 의
   **원문을 §4-B 에 싣지 않는다**(rm -rf · 파이프 rc · heredoc 3종만 싣는다).
   ⇒ `O111 ㉢`(판정 문구가 세는 것 ≠ 사람이 읽는 뜻)에 따라 **실물을 열어** 판정한다.
"""
import io
import json
import re
import sys


def load(path):
    items = []
    with io.open(path, encoding='utf-8', errors='replace') as fh:
        raw = fh.read()
    try:
        obj = json.loads(raw)
        return obj if isinstance(obj, list) else [obj]
    except Exception:
        pass
    for line in raw.split('\n'):
        line = line.strip()
        if not line:
            continue
        try:
            items.append(json.loads(line))
        except Exception:
            continue
    return items


def bash_commands(items):
    out = []
    for it in items:
        s = json.dumps(it, ensure_ascii=False)
        for m in re.finditer(r'"command"\s*:\s*"((?:[^"\\]|\\.)*)"', s):
            try:
                cmd = json.loads('"' + m.group(1) + '"')
            except Exception:
                cmd = m.group(1)
            out.append(cmd)
    return out


def main():
    if len(sys.argv) < 2:
        sys.stderr.write('사용법: python3 scripts/_o154b_pyc_probe.py <transcript.json>\n')
        return 2
    items = load(sys.argv[1])
    cmds = bash_commands(items)
    seen, uniq = set(), []
    for c in cmds:
        if c not in seen:
            seen.add(c)
            uniq.append(c)

    hits = [c for c in uniq if 'python3 -c' in c]
    print('전체 bash 명령(중복 제거) = %d건 · `python3 -c` 포함 = %d건' % (len(uniq), len(hits)))
    print('')
    # 🔴 판정 축 = 그 명령이 「파일에 본문을 쓰는가」다. 읽기·진단은 R1-7-9 대상이 아니다.
    WRITE = ('open(', 'write(', '>>', 'edit', 'replace', 'sub(')
    for i, c in enumerate(hits, 1):
        writes = [w for w in WRITE if w in c]
        mark = '🔴 쓰기 의심' if writes else '🟢 읽기·진단'
        print('[%d] %s' % (i, mark))
        if writes:
            print('    적발 토큰 = %s' % ', '.join(writes))
        for line in c.split('\n'):
            print('    | %s' % line)
        print('')
    return 0


if __name__ == '__main__':
    sys.exit(main())
