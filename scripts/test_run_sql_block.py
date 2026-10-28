#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""음성 테스트 — `scripts/run_sql_block.py` (O268 신설 · `R3-2`).

축 (각 축이 스스로를 센다 — 🔴 개수를 문서에 적지 마라)
  ① 블록 경계 = 표지 줄 ~ 다음 표지 직전(다음 블록 문장이 섞이지 않는다)
  ② 여러 표지를 주면 **파일 순서**로 모은다(주어진 순서가 아니다)
  ③ 없는 표지 → rc=2(미판정) · 빈 --blocks → rc=2
  ④ 🔴 오염 기반 축 = 원천(BRONZE) 쓰기 문장이 든 블록은 dry-run 에서도 BLOCKED(rc=2)
  ⑤ 역방향 오탐 축 = BRONZE 를 **읽기만** 하는 SELECT 는 막지 않는다
  ⑥ `--apply` 없이는 접속하지 않는다(dry-run 이 sfconn 을 import 하지 않는다)
  ⑦ 날짜 꼴 주석 `-- [2026-10-28 …]` 은 표지가 아니다
종료코드 = 0 전건 통과 · 1 단정 실패.
Co-authored with CoCo
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, 'scripts', 'run_sql_block.py')
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
import run_sql_block as R  # noqa: E402

FIX = """-- 머리 주석
-- [D0] 사전 확인
SELECT 1 AS A;
-- [2026-10-28 O268] 날짜 주석은 표지가 아니다
SELECT 2 AS B;
-- [D1] 구조
ALTER TABLE GN_DW.GOLD.X ADD COLUMN IF NOT EXISTS C NUMBER;
-- [D2] 원천 읽기
SELECT COUNT(*) FROM GN_DW.BRONZE_CRM.T;
-- [D9] 원천 쓰기(오염)
DELETE FROM GN_DW.BRONZE_CRM.T WHERE 1=0;
"""

fails, axes = [], 0


def check(label, ok):
    global axes
    axes += 1
    print(('  🟢 ' if ok else '  🔴 ') + label)
    if not ok:
        fails.append(label)


def run(args):
    p = subprocess.run([sys.executable, TOOL] + args, capture_output=True, text=True, timeout=120)
    return p.returncode, (p.stdout or '') + (p.stderr or '')


blocks = R.split_blocks(FIX)
names = [b for b, _ in blocks]
check('① 표지 = D0·D1·D2·D9(날짜 주석 제외)', names == ['D0', 'D1', 'D2', 'D9'])
d0 = R.statements(dict(blocks)['D0'])
check('① D0 블록 = 문장 2개(SELECT 1 · SELECT 2 · 다음 블록 ALTER 미포함)',
      len(d0) == 2 and not any('ALTER' in s for s in d0))
check('⑦ 날짜 꼴 주석 `-- [2026-…]` 은 표지가 아니다', '2026-10-28' not in ' '.join(names))

with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False, encoding='utf-8', dir='/tmp') as f:
    f.write(FIX)
    path = f.name
try:
    rc, out = run([path, '--blocks', 'D1,D0'])
    i0, i1 = out.find('[D0]'), out.find('[D1]')
    check('② --blocks D1,D0 → 파일 순서(D0 먼저) · dry-run rc=0',
          rc == 0 and 0 <= i0 < i1 and 'DRY-RUN' in out)
    rc, out = run([path, '--blocks', 'DX'])
    check('③ 없는 표지 → rc=2', rc == 2 and '표지 부재' in out)
    rc, out = run([path])
    check('③ 빈 --blocks → rc=2', rc == 2)
    rc, out = run([path, '--blocks', 'D9'])
    check('④ 원천 쓰기 블록 → dry-run 에서도 BLOCKED rc=2', rc == 2 and 'BLOCKED' in out)
    rc, out = run([path, '--blocks', 'D2'])
    check('⑤ 원천 읽기 SELECT 는 막지 않는다(rc=0)', rc == 0 and 'BLOCKED' not in out)
    src = open(TOOL, encoding='utf-8').read()
    check('⑥ sfconn import 는 --apply 분기 뒤에만 있다',
          src.find('import sfconn') > src.find('if not a.apply:') > 0)
finally:
    os.unlink(path)

print(f'{"🔴" if fails else "🟢"} 축 {axes}개 · 실패 {len(fails)}건')
sys.exit(1 if fails else 0)
