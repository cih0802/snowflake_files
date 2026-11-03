#!/usr/bin/env python3
"""O214 — SV_MEMBER_FEE 규칙7 라이브 위반 2건(「202,601」 예시) 시정 · 같은 문자열의 [O212-B] 태그 제거.
처방 정본 = 99_NEXT_SESSION-O0213-J.md ▣ O213-J-2 (숫자 없는 서술 「6자리 정수 YYYYMM」).
Co-authored with CoCo
"""
import io
import sys

F = '/workspace/05_SV-Agent_ai/05_9_SV_DDL_MEMBER_FEE.sql'
REPL = [
    ('🆕 [O212-B] 숫자형이라 출력하면 202,601 처럼 천단위 쉼표가 붙는다',
     '6자리 정수 YYYYMM 이라 출력하면 천단위 쉼표가 붙는다'),
    ('🆕 [O212-B] 월별 결과를 낼 때', '월별 결과를 낼 때'),
    ('MONTH_KEY 숫자를 그대로 출력하면 202,601 처럼 보인다',
     'MONTH_KEY(6자리 정수 YYYYMM)를 그대로 출력하면 천단위 쉼표가 붙어 보인다'),
]
src = io.open(F, encoding='utf-8').read()
out = src
for a, b in REPL:
    n = out.count(a)
    print(n, a[:30])
    if n != 1:
        sys.exit('앵커 불일치 — 중단')
    out = out.replace(a, b)
if '--apply' in sys.argv:
    io.open(F, 'w', encoding='utf-8', newline='').write(out)
    print('APPLY')
