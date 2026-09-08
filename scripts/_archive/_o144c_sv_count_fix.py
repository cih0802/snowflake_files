#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SV DDL 주석의 stale 한 「SV 9종」 기재를 개수 대신 「재는 방법」 표기로 교체한다(O68-B 잔여 · R3-9 ㉦).
# Co-authored with CoCo
"""_o144c_sv_count_fix.py — 「SV 9종」 stale 주석 시정 (O144-C · 후-2 잔여 O68-B)

🔴 **왜 이 스크립트인가**: 대상 문안에 백틱이 들어 있어 셸을 경유시킬 수 없다(`R1-7-9`).
   ⇒ 스크립트 파일로 만들어 실행한다.

🔴 **왜 「17종」으로 안 바꾸는가**: 그러면 다음 SV 신설에서 또 stale 이 된다.
   O126 ⑥ 이 확립한 처방 = **수를 지우고 「재는 방법」으로 대체**(`R3-9 ㉦`).
   ⇒ 「SV 전종(수는 `SHOW SEMANTIC VIEWS` 로 재라)」 형태로 바꾼다.

🟢 **면제 1건** = `05_0_SV_DDL.sql:30` 은 *"이 파일의 「SV 9종」 기재는 전부 stale 이다"* 라는
   **O118 의 교정 주석**이다. 그 문장의 「SV 9종」은 stale 주장이 아니라 **인용**이므로 건드리지 않는다.

사용:
    python3 scripts/_o144c_sv_count_fix.py --apply
    python3 scripts/_o144c_sv_count_fix.py            # dry-run (기본)
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVDIR = os.path.join(ROOT, '05_SV-Agent_ai')

# 🔴 면제 = 그 줄이 「SV 9종」을 **인용**하는 교정 주석인가.
EXEMPT_MARK = 'stale'

REPLACEMENTS = [
    # (찾을 문안, 바꿀 문안)
    ('▶ SV 9종 전체를 아우르는 배포 검증',
     '▶ SV 전종을 아우르는 배포 검증(종수는 `SHOW SEMANTIC VIEWS` 로 재라)'),
    ('실측 판정: SV 9종 전건 owner',
     '실측 판정: SV 전종 owner'),
    ('§전체 배포 검증 — SV 9종을 아우르는 검사',
     '§전체 배포 검증 — SV 전종을 아우르는 검사'),
    ('SV 9종의 base',
     'SV 전종의 base'),
    ('실적 SV 9종)',
     '실적 SV 전종)'),
    ('기존 SV 9종이 정상 동작한다',
     '기존 SV 전종이 정상 동작한다'),
]


def main(apply_it):
    total_lines = 0
    changed_files = 0
    exempt = 0
    残 = []
    for name in sorted(os.listdir(SVDIR)):
        if not name.endswith('.sql'):
            continue
        path = os.path.join(SVDIR, name)
        text = io.open(path, encoding='utf-8').read()
        orig = text
        hits = 0
        for old, new in REPLACEMENTS:
            if old in text:
                hits += text.count(old)
                text = text.replace(old, new)
        if hits:
            total_lines += hits
            changed_files += 1
            print('  %s %s — %d곳' % ('🟢' if apply_it else '·', name, hits))
            if apply_it:
                io.open(path, 'w', encoding='utf-8').write(text)
        # 잔존 확인
        for n, line in enumerate((text if apply_it else orig).split('\n'), 1):
            if re.search(r'SV\s*9\s*종', line):
                if EXEMPT_MARK in line:
                    exempt += 1
                else:
                    残.append('%s:%d' % (name, n))
    print('\n치환 %d곳 · 파일 %d개 · 면제(교정 인용) %d건' % (total_lines, changed_files, exempt))
    if 残:
        print('🟠 잔존 %d건 — 개별 문안이라 일괄 규칙에 안 맞는다:' % len(残))
        for r in 残:
            print('   ', r)
        return 1
    print('🟢 stale 「SV 9종」 잔존 0건 (면제 %d건 제외)' % exempt)
    return 0


if __name__ == '__main__':
    sys.exit(main('--apply' in sys.argv))
