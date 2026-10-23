# -*- coding: utf-8 -*-
"""[2026-10-23 O259] `sv_no_rollup_gate` 음성 테스트 — 잡아야 할 것을 잡는가 (`R3-2`).

현 정본 PASS 만으로는 「없다」와 「못 본다」를 가를 수 없다 ⇒ 종전 문구를 주입해 FAIL 을 단정한다.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sv_no_rollup_gate as G

FAIL = []


def check(name, cond):
    print(('🟢 ' if cond else '🔴 ') + name)
    if not cond:
        FAIL.append(name)


def kinds(body):
    return {h[0] for h in G.scan_text('t.sql', body)}


check('축0 현 정본 위반 0', G.main() == 0)
check('축1 VQR GROUP BY ROLLUP( → SQL_ROLLUP',
      'SQL_ROLLUP' in kinds("SQL 'SELECT a FROM t GROUP BY ROLLUP (a)'"))
check('축2 종전 O206-C 문구 → SQL_ROLLUP 또는 TEXT',
      kinds('그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다') & {'TEXT_ROLLUP_ROW'})
check('축3 「ROLLUP 전체 행을 붙인다」 → TEXT_ROLLUP_ROW',
      'TEXT_ROLLUP_ROW' in kinds('함께 보이고 ROLLUP 전체 행을 붙인다.'))
check('축4 GROUPING SETS → SQL_GROUPING_SETS',
      'SQL_GROUPING_SETS' in kinds('GROUP BY GROUPING SETS ((a), ())'))
check('축5 CUBE → SQL_CUBE', 'SQL_CUBE' in kinds('GROUP BY CUBE (a, b)'))
check('축6 GROUPING(차원) → SQL_GROUPING_FN', 'SQL_GROUPING_FN' in kinds('CASE WHEN GROUPING(차원) = 1'))
check('축7 금지 문장은 통과(역방향 오탐 0)',
      kinds('표에 합계·소계 행을 붙이지 않는다(ROLLUP·CUBE·GROUPING SETS 금지 · 평면 GROUP BY 만)') == set()
      and kinds('총계 행은 만들지 않는다(ROLLUP 금지)') == set())

print('FAIL %d' % len(FAIL))
sys.exit(1 if FAIL else 0)
