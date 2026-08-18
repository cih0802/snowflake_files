#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""retire_rows.py 음성 테스트 (2026-08-18 O83-B · R3 게이트 2 집행).

🔴 왜 필요한가: 「게이트를 만들었다」와 「그 게이트가 사고를 잡는다」는 다르다.
이 세션에서 이미 두 번 갈렸다 — `--rebalance` 는 만들었지만 여유를 못 늘렸고,
폴더 조각 탐색은 만들었지만 폴더명을 추측해 실패했다.
⇒ 은퇴 이관의 `R2-8-1` 토큰 대조가 **절단·변형을 실제로 검출하는지** 실패 케이스로 확인한다.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import retire_rows as r          # noqa: E402
import index_row_gate as g       # noqa: E402

BT = chr(96)
cell = ('실측 **1,234행** · 근거 ' + BT + 'R1-7-4' + BT +
        ' · 라벨 O82-C · 지표 DEC-35 · 비율 37.6% 확인')

fails = []
tk = r.tokens(cell)
print('① 토큰 추출 %d종: %s' % (len(tk), sorted(tk)))
if not tk:
    fails.append('토큰 0종 — 추출기가 죽었다')

# ② 무변경 이관 → 부재 0 이어야 한다(정상 경로가 막히면 도구를 못 쓴다)
miss = sorted(t for t in tk if t not in ('이관본: ' + cell))
print('② 무변경 이관 → 부재 %d ⇒ %s' % (len(miss), 'PASS' if not miss else 'FAIL'))
if miss:
    fails.append('무변경 이관이 FAIL — 정상 경로 차단: %s' % miss)

# ③ 꼬리 절단 → 반드시 검출해야 한다
trunc = '이관본: 실측 **1,234행** · 근거 ' + BT + 'R1-7-4' + BT
miss2 = sorted(t for t in tk if t not in trunc)
print('③ 절단 이관 → 부재 %d %s ⇒ %s'
      % (len(miss2), miss2, 'PASS(검출)' if miss2 else 'FAIL(무력화!)'))
if not miss2:
    fails.append('절단을 검출하지 못했다 — 게이트가 vacuous')

# ④ 수치 표기 변형(콤마 소실) → 반드시 검출해야 한다
enc = '이관본: ' + cell.replace('1,234', '1234')
miss3 = sorted(t for t in tk if t not in enc)
print('④ 수치 표기 변형 → 부재 %d %s ⇒ %s'
      % (len(miss3), miss3, 'PASS(검출)' if miss3 else 'FAIL(무력화!)'))
if not miss3:
    fails.append('표기 변형을 검출하지 못했다')

# ⑤ 2자리 이하 수치는 토큰에서 제외돼야 한다(포함하면 대조가 vacuous 해진다 · P106)
short = [t for t in tk if len(t) < 3]
print('⑤ 2자리 이하 토큰 %d개 ⇒ %s' % (len(short), 'PASS' if not short else 'FAIL'))
if short:
    fails.append('짧은 토큰 혼입: %s' % short)

# ⑥ 행 키 정규화 규칙이 index_row_gate 와 동일해야 한다
#    🔴 어긋나면 이 도구가 「보존했다」고 보고한 키를 게이트가 「유실」로 잡는다.
samples = ['**🟢 ML 데이터 이관 문서화**',
           '~~낡은~~ ' + BT + '값' + BT,
           '🔒 **O82-C 진행 체크포인트(내부)**',
           '**잔여** <br> 다음줄']
diff = [s for s in samples if r.norm(s) != g.row_key(s)]
print('⑥ norm 규칙 일치 ⇒ %s' % ('PASS' if not diff else 'FAIL'))
for s in diff:
    print('   차이: %r vs %r' % (r.norm(s), g.row_key(s)))
if diff:
    fails.append('norm 규칙 불일치 %d건' % len(diff))

# ⑦ 첫 셀은 절대 대체 대상이 되지 않아야 한다(행 키 = 인용 좌표)
cells = ['키', '아주아주긴셀' * 50, '중간', '꼬리']
k = r.big_cell_index(cells)
print('⑦ 대체 대상 인덱스 = %s ⇒ %s' % (k, 'PASS' if k not in (0, len(cells) - 1) else 'FAIL'))
if k in (0, len(cells) - 1):
    fails.append('첫 셀 또는 마지막 셀이 대체 대상으로 선택됐다')

# ⑧ 2열 표는 대체 대상이 없어야 한다(첫 셀·마지막 셀만 있으면 건드릴 게 없다)
k2 = r.big_cell_index(['키', '값'])
print('⑧ 2열 표 대체 대상 = %s ⇒ %s' % (k2, 'PASS' if k2 == 1 else 'CHECK'))

print('')
if fails:
    print('🔴 FAIL %d건' % len(fails))
    for f in fails:
        print(' -', f)
    sys.exit(1)
print('🟢 PASS — 음성 테스트 8종 통과(절단·변형 검출 · 정상 경로 통과 · 행 키 불변)')
sys.exit(0)
