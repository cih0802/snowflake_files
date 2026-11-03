#!/usr/bin/env python3
"""재사용 키트 자리표시자 치환기.

사용:
  python3 apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345            # dry-run (변경 건수만)
  python3 apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345 --apply    # 적용
  python3 apply_names.py --check                                          # 남은 자리표시자 집계

자리표시자 = `{{DB}}`(데이터베이스 · 역할·창고 접두 포함, 예: `{{DB}}_ADMIN`) · `{{ACCOUNT}}`(계정 로케이터).
🔴 값을 넣으면 되돌릴 수 없다 — 적용 전에 키트를 복사해 두거나 git 에 올려 둔다.
"""
import argparse
import io
import os
import re
import sys

KIT = os.path.dirname(os.path.abspath(__file__))
SELF = os.path.basename(__file__)
TEXT = ('.md', '.py', '.sql', '.sh', '.yml', '.yaml', '.txt', '.csv', '.toml', '.json')
SKIP = {SELF, '00_INVENTORY.md', '01_PLACEHOLDERS.md'}
PH = re.compile(r'\{\{([A-Z_]+)\}\}')


def files():
    for dp, _, fs in os.walk(KIT):
        for f in fs:
            if dp == KIT and f == '00_README.md':
                continue  # 키트 안내문 — 자리표시자를 「설명」한다
            if f.endswith(TEXT) and f not in SKIP:
                yield os.path.join(dp, f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--set', action='append', default=[], metavar='KEY=VALUE')
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    if a.check:
        cnt = {}
        for p in files():
            for k in PH.findall(io.open(p, encoding='utf-8', errors='replace').read()):
                cnt[k] = cnt.get(k, 0) + 1
        for k, v in sorted(cnt.items()):
            print('{{%s}}\t%d' % (k, v))
        return 0
    if not a.set:
        ap.error('--set KEY=VALUE 가 필요하다')
    vals = dict(s.split('=', 1) for s in a.set)
    bad = [k for k in vals if not re.fullmatch(r'[A-Z_]+', k)]
    if bad:
        ap.error('KEY 는 대문자·밑줄만: %s' % bad)
    nfile = nrep = 0
    for p in files():
        src = io.open(p, encoding='utf-8', errors='strict').read()
        n = 0

        def sub(m):
            nonlocal n
            if m.group(1) in vals:
                n += 1
                return vals[m.group(1)]
            return m.group(0)
        out = PH.sub(sub, src)
        if n:
            nfile += 1
            nrep += n
            if a.apply:
                io.open(p, 'w', encoding='utf-8', newline='').write(out)
    print('%s files %d · replacements %d' % ('APPLIED' if a.apply else 'DRY-RUN', nfile, nrep))
    return 0


if __name__ == '__main__':
    sys.exit(main())
