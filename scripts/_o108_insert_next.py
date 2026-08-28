#!/usr/bin/env python3
"""O108: 99_NEXT 조각 -001 의 `# 99.` 제목 직후에 §0-NNN 절을 삽입한다.

🔴 R1-7-9 준수 — 본문에 백틱이 많으므로 셸(`python3 -c`·heredoc)을 경유하지 않는다.
🔴 R1-7-1 준수 — 전체 재작성이 아니라 **앵커 위치에 삽입**만 한다(줄 인덱스 지정).
🔴 R1-7-2 준수 — 삽입 전 2회 읽어 SHA256 안정성을 확인한다.
"""
import hashlib
import io
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(ROOT)
TGT = os.path.join(ROOT, '99_NEXT_SESSION_조각', '99_NEXT_SESSION-001.md')
SRC = os.path.join(ROOT, '_o108_next.md')
ANCHOR = '# 99. 다음 세션 착수 프롬프트'
SENTINEL = '## 0-NNN.'


def read(p):
    with io.open(p, encoding='utf-8') as fh:
        return fh.read()


def sha(s):
    return hashlib.sha256(s.encode('utf-8')).hexdigest()[:16]


def main():
    a = read(TGT)
    b = read(TGT)
    if sha(a) != sha(b) or len(a) != len(b):
        print('🔴 해시 불안정 — 중단(R1-7-2)')
        return 1
    print('🟢 해시 안정 %s · %d B' % (sha(a), len(a.encode('utf-8'))))

    if SENTINEL in a:
        print('🔴 이미 삽입돼 있다 — 멱등 차단')
        return 1

    body = read(SRC).rstrip('\n')
    lines = a.split('\n')
    try:
        i = lines.index(ANCHOR)
    except ValueError:
        print('🔴 앵커 부재 — 중단')
        return 1

    out = lines[:i + 1] + [''] + body.split('\n') + lines[i + 1:]
    new = '\n'.join(out)

    snap = os.path.join(ROOT, '_archive', '99_NEXT_SESSION-001.md.O108-preinsert')
    with io.open(snap, 'w', encoding='utf-8') as fh:
        fh.write(a)
    with io.open(TGT, 'w', encoding='utf-8') as fh:
        fh.write(new)

    chk = read(TGT)
    ok = (SENTINEL in chk) and ('0-MMM' in chk) and (ANCHOR in chk)
    print('🟢 삽입 %d줄 → %d줄 · 스냅샷 %s' % (len(lines), len(out), os.path.basename(snap)))
    print('   센티넬 %s · 0-MMM 보존 %s · 앵커 보존 %s'
          % (SENTINEL in chk, '0-MMM' in chk, ANCHOR in chk))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
