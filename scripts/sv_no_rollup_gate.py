# -*- coding: utf-8 -*-
"""[2026-10-23 O259] `sv_no_rollup_gate` — SV 지시문·VQR 이 소계/합계 행을 만들게 하지 않는가.

🔴 왜 필요한가: Agent 표에 소계 행이 붙던 원인은 Analyst 가 아니라 **SV 지시문**이었다
   (O206-C 「GROUP BY ROLLUP 합계 행을 반환한다」 · 05_24/05_25 「ROLLUP 전체 행을 붙인다」).
   O259 가 문구·VQR 을 평면 GROUP BY 로 바꿨다 ⇒ 다시 들어오면 FAIL 한다.
🟢 금지 문장 자체(「ROLLUP·CUBE·GROUPING SETS 금지」·「(ROLLUP 금지)」)는 허용한다.
분모 = `05_SV-Agent_ai/` 의 SV DDL(05_*·22_·25_·34_) · `_archive` 제외.
운영자 점검 SQL(26~29·37)은 Agent 출력이 아니므로 분모 밖이다.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SV_DIR = os.path.join(ROOT, '05_SV-Agent_ai')
PREFIXES = ('05_', '22_', '25_', '34_')
#: SV_DIR 기준 상대경로 — 05 폴더 밖 SV 정본
EXTRA = ('../15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql',)

#: (종류, 패턴) — SQL 구문과 「붙여라」 지시 문구를 함께 본다.
RULES = [
    ('SQL_ROLLUP', re.compile(r'\bROLLUP\s*\(', re.I)),
    ('SQL_CUBE', re.compile(r'\bGROUP\s+BY\s+CUBE\b|\bCUBE\s*\(', re.I)),
    ('SQL_GROUPING_SETS', re.compile(r'\bGROUPING\s+SETS\s*\(', re.I)),
    ('SQL_GROUPING_FN', re.compile(r'\bGROUPING\s*\(\s*[A-Za-z가-힣_]', re.I)),
    ('TEXT_ROLLUP_ROW', re.compile(r'ROLLUP\s*(?:전체|합계\s*행|과\s*함께|행을)')),
]


def targets():
    for f in sorted(os.listdir(SV_DIR)):
        if f.endswith('.sql') and f.startswith(PREFIXES):
            yield f
    # 🆕 [O259] MSTR SV 정본은 05 폴더 밖에 있다(라이브 스캔에서 잔존 1건으로 발견) ⇒ 분모에 명시 편입
    for rel in EXTRA:
        yield rel


def scan_text(name, body):
    hits = []
    for i, line in enumerate(body.split('\n'), 1):
        for kind, rx in RULES:
            if rx.search(line):
                hits.append((kind, name, i))
    return hits


def main():
    hits, n = [], 0
    for f in targets():
        n += 1
        with io.open(os.path.join(SV_DIR, f), encoding='utf-8') as h:
            hits += scan_text(f, h.read())
    for kind, f, i in hits:
        print('🔴 %s %s:%d' % (kind, f, i))
    if n == 0:
        print('🔴 FAIL — 분모 0 파일(경로 확인)')
        return 1
    if hits:
        print('🔴 FAIL — 소계/합계 행 유도 %d건 · 분모 %d 파일' % (len(hits), n))
        return 1
    print('🟢 PASS — 소계/합계 행 유도 0건 · 분모 %d 파일' % n)
    return 0


if __name__ == '__main__':
    sys.exit(main())
