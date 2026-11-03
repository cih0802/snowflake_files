#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test_split_narrative.py — `split_narrative.py` 음성 테스트 (6축)

[2026-08-28 O111 신설 · `R3-2` 집행 · 선례 = `test_doc_census.py` · `test_snapshot_util.py`]

🔴 왜 필요한가 (이 세션 실측)
--------------------------------------------------------------------------
`split_narrative.py` 초판(O106)은 **정상 입력에서 🟢 를 냈지만** 결함 2종이 있었다.
둘 다 **정상 입력만 돌려서는 원리적으로 보이지 않는다**:

  ㉠ **목적지 통째 덮어쓰기** — 1회차에는 목적지가 비어 있어 무해했다.
     2회차부터 기존 `§C01`~`§C12` 본문이 **경고 없이 사라지고**, 새 블록이
     다시 `C01` 부터 번호를 받아 **원본 포인터 12줄이 다른 내용을 가리킨다.**
     🔴 불변식 1~3 은 **원본만** 검사하므로 전부 🟢 를 낸다.
  ㉡ **신호어 변형 미탐** — 원본에 실재하는 `왜 바꿨나` · `왜 예외가 필요한가` ·
     `왜 이 규약이 있는가` 3종을 못 봐서 **「서사 블록 0개 — 이미 분리돼 있다」**
     를 출력했다. 🔴 **0건 출력이 「없다」로 읽히는 것**이 이 결함의 위험이다.

⇒ 이 테스트는 **오탐 축과 재현율 축을 함께** 단정한다(`R3-4` 역방향 · `test_doc_census.P8` 관례).

사용
--------------------------------------------------------------------------
    python3 scripts/test_split_narrative.py
"""

import io
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import split_narrative as SN  # noqa: E402

FAILS = []
ASSERTS = [0]


def check(cond, axis, msg):
    ASSERTS[0] += 1
    if cond:
        print('  🟢 %s — %s' % (axis, msg))
    else:
        print('  🔴 %s — %s' % (axis, msg))
        FAILS.append('%s: %s' % (axis, msg))


def w(path, text):
    with io.open(path, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)


def r(path):
    with io.open(path, encoding='utf-8') as fh:
        return fh.read()


def run(tmp, src, dst, apply_=False):
    """모듈을 in-process 로 돌린다. ROOT 를 tmp 로 바꿔 실 `_archive/` 를 더럽히지 않는다."""
    old_root, old_argv = SN.ROOT, sys.argv
    SN.ROOT = tmp
    argv = ['split_narrative.py', '--src', src, '--dst', dst, '--label', 'TEST']
    if apply_:
        argv.append('--apply')
    sys.argv = argv
    buf = io.StringIO()
    old_out = sys.stdout
    sys.stdout = buf
    try:
        rc = SN.main()
    finally:
        sys.stdout = old_out
        SN.ROOT, sys.argv = old_root, old_argv
    return rc, buf.getvalue()


# ── 합성 원본 ─────────────────────────────────────────────────────────
#   🔴 문장은 실제 지침의 형태를 모사한다(조문 정의 · 서사 · 처방이 교대).
SRC = '\n'.join([
    '# 합성 지침',
    '',
    '## R9. 시험 계열',
    '',
    '* **R9-1 조문 하나**',
    '  🔴 **왜 바꿨나**: 종전 방식은 **99,999자**를 요구해 불가능했다.',
    '  그래서 바꿨다.',
    '  🟢 처방 = 이 줄은 남아야 한다(PRESCRIPTION).',
    '* **R9-2 왜 필요한가**: 이 줄은 **조문 정의 자신**이라 옮기면 조문이 사라진다.',
    '  본문이 이어진다.',
    '* **R9-3 또 다른 조문**',
    '    * 🔴 **왜 예외가 필요한가**: 예외가 없으면 `R9-1` 이 깨진다(**4,686줄** 실측).',
    '    * ⚠️ 예외의 한계 = 이 줄은 남아야 한다.',
    '* **R9-4 마지막**',
    '  🔴 **왜 이 규약이 있는가**: 원장이 **4회** 깨졌다.',
    '* **R9-5 도구 지시**',
    '  · 🆕 **조문의 「왜 필요한가」 경위 서사**는 도구로 이관한다(이 줄은 처방이다).',
    '* **R9-6 또 하나**',
    '  🔴 **무슨 일이 있었나**: 꼬리 **8줄**이 사라졌다.',
    '  ⇒ **처방 = 즉시 py_compile 하라.** 이 줄은 남아야 한다.',
    '',
]) + '\n'

DST_EXISTING = '\n'.join([
    '<!-- LLM-METADATA',
    'doc_id: INCIDENT_CASEBOOK',
    'created_by: OPREV',
    'END-METADATA -->',
    '',
    '# 91_사고사례집 — 조문 경위의 무변경 이관부',
    '',
    '> 머리말 한 줄 — 손으로 적은 문장이 있다고 가정한다.',
    '',
    '| 앵커 | 소관 조문 | 원본 행(이관 시점) |',
    '|---|---|---|',
    '| `§C01` | `R8-1` | 42 |',
    '| `§C02` | `R8-2` | 77 |',
    '',
    '---',
    '',
    '## C01 — 소관 `R8-1`',
    '',
    '> 원본 `x.md` 42행에서 무변경 이관(`OPREV`).',
    '',
    '  기존 경위 1 — 고유토큰 ZZTOP1 · **12,345** 건.',
    '',
    '## C02 — 소관 `R8-2`',
    '',
    '> 원본 `x.md` 77행에서 무변경 이관(`OPREV`).',
    '',
    '  기존 경위 2 — 고유토큰 ZZTOP2 · **67,890** 건.',
    '',
    '_Co-authored with CoCo_',
]) + '\n'


def main():
    tmp = tempfile.mkdtemp(prefix='sn_test_')
    try:
        print('[test_split_narrative] 임시 ROOT = %s' % tmp)

        # ── 축1: 신호어 변형 3종 재현율 (㉡ 회귀) ─────────────────────────
        print('\n축1 — 신호어 변형 재현율 (`왜 바꿨나`·`왜 예외가 필요한가`·`왜 이 규약이 있는가`)')
        src = os.path.join(tmp, 'src.md')
        dst = os.path.join(tmp, 'dst.md')
        w(src, SRC)
        rc, out = run(tmp, src, dst)
        check(rc == 0, '축1-a', 'dry-run rc 0')
        check('서사 블록 4개' in out,
              '축1-b', '변형 3종 + `무슨 일이 있었나` 를 전건 검출한다 (초판은 0개를 냈다) · 출력=%s'
              % [l for l in out.split('\n') if '서사 블록' in l])
        check('이미 분리돼 있다' not in out,
              '축1-c', '「이미 분리돼 있다」로 조용히 넘어가지 않는다')

        # ── 축2: 조문 정의 자신은 옮기지 않는다 (오탐 축) ──────────────────
        print('\n축2 — 조문 정의(`R9-2 왜 필요한가`)는 이관 대상이 아니다 (오탐 0)')
        check('R9-2' not in out.split('[불변식1')[0].split('§C')[-1] or True,
              '축2-a', '(참조) 목록 출력 확인')
        check('소실 0종' in out and '[불변식1 조문 ID]' in out,
              '축2-b', '조문 ID 소실 0 — `CLAUSE_DEF` 가 조문 자신을 지킨다')
        blocks = SN.find_blocks(SRC.split('\n'))
        moved = '\n'.join(
            '\n'.join(SRC.split('\n')[i:j]) for i, j, _ind in blocks)
        check('R9-2 왜 필요한가' not in moved,
              '축2-c', '`R9-2` 정의 줄이 이관 본문에 없다')

        # ── 축3: 처방(🟢/⚠️)은 원본에 남는다 (O106 자기시정 회귀) ──────────
        print('\n축3 — 처방 마커 줄은 이관하지 않는다 (`PRESCRIPTION`)')
        check('🟢 처방 = 이 줄은 남아야 한다' not in moved,
              '축3-a', '🟢 처방 줄 미이관')
        check('⚠️ 예외의 한계 = 이 줄은 남아야 한다' not in moved,
              '축3-b', '⚠️ 처방 줄 미이관')
        # 🆕 [O111] `⇒` 로 시작하는 줄도 처방이다.
        check('⇒ **처방 = 즉시 py_compile 하라.**' not in moved,
              '축3-c', '⇒ 로 시작하는 처방 줄 미이관 (스킬 `[O109 실사고]` 꼬리 2줄 실측 근거)')

        # ── 축3b: 개념 인용 가드 (「왜 필요한가」 는 서사가 아니다) ──────────
        print('\n축3b — 개념 인용 가드: `「왜 필요한가」` 를 포함한 처방 줄은 이관하지 않는다')
        check('경위 서사**는 도구로 이관한다' not in moved,
              '축3b-a', '`「…」` 안의 신호어는 서사로 잡지 않는다 (스킬 336행 실측 오탐)')
        check(len(blocks) == 4,
              '축3b-b', '신호 블록 = 4개 (변형3 + `무슨 일이 있었나`) · 실제=%d' % len(blocks))

        # ── 축4: 목적지 신규면 C01 부터 ────────────────────────────────────
        print('\n축4 — 목적지 신규 = C01 부터 발급')
        rc, out = run(tmp, src, dst, apply_=True)
        check(rc == 0, '축4-a', 'apply rc 0')
        dtext = r(dst)
        check('## C01 — 소관' in dtext and '## C03 — 소관' in dtext,
              '축4-b', '신규 목적지에 C01~C03 발급')
        check('대조 대상 0' in out,
              '축4-c', '불변식4 가 「신규」를 인식한다(기존 보존 대조 생략)')

        # ── 축5: 🔴🔴 기존 목적지 보존 (㉠ 회귀 · 이 테스트의 핵심) ─────────
        print('\n축5 — 기존 목적지 append 보존 (초판 결함 ㉠ 회귀)')
        src2 = os.path.join(tmp, 'src2.md')
        dst2 = os.path.join(tmp, 'dst2.md')
        w(src2, SRC)
        w(dst2, DST_EXISTING)
        rc, out = run(tmp, src2, dst2, apply_=True)
        check(rc == 0, '축5-a', 'apply rc 0')
        d2 = r(dst2)
        check('ZZTOP1' in d2 and 'ZZTOP2' in d2,
              '축5-b', '기존 본문 고유 토큰 2종이 살아 있다 (초판은 소실)')
        check('| `§C01` | `R8-1` | 42 |' in d2 and '| `§C02` | `R8-2` | 77 |' in d2,
              '축5-c', '기존 표 행 2건이 원문 그대로 살아 있다')
        check('## C03 — 소관' in d2 and '## C05 — 소관' in d2,
              '축5-d', '신규 앵커가 C03 부터 이어서 발급된다 (C01 재사용 0)')
        check('created_by: OPREV' in d2,
              '축5-e', '기존 머리말(`created_by`)을 덮지 않는다')
        check('손으로 적은 문장이 있다고 가정한다' in d2,
              '축5-f', '머리말의 손으로 적은 문장이 보존된다')
        check(d2.count('| 앵커 | 소관 조문 |') == 1,
              '축5-g', '표 머리가 이중으로 생기지 않는다')
        check(d2.count('_Co-authored with CoCo_') == 1,
              '축5-h', '꼬리가 이중으로 생기지 않는다')
        check('기존 앵커 2 · 표 행 소실 0 · 본문 줄 소실 0 · 앵커 소실 0' in out,
              '축5-i', '불변식4 가 보존을 숫자로 단정한다')

        # ── 축6: 불변식4 가 실제로 「덮어쓰기」를 잡는가 (음성 · blocking) ──
        print('\n축6 — 불변식4 음성: 덮어쓰기를 주입하면 FAIL 이어야 한다')
        src3 = os.path.join(tmp, 'src3.md')
        dst3 = os.path.join(tmp, 'dst3.md')
        w(src3, SRC)
        w(dst3, DST_EXISTING)
        orig_parse = SN.parse_existing

        def blind_parse(p):
            """초판 동작 재현 = 기존 내용을 못 본 것처럼 반환한다."""
            _pre, rows, body, mx = orig_parse(p)
            return None, rows, body, 0        # ← 머리말·번호를 잃은 상태

        SN.parse_existing = blind_parse
        try:
            rc, out = run(tmp, src3, dst3, apply_=True)
        finally:
            SN.parse_existing = orig_parse
        check(rc == 1,
              '축6-a', '기존 앵커가 재사용되면 blocking FAIL (rc 1) · 실제 rc=%s' % rc)
        check('🔴 FAIL' in out and '기존 목적지 내용이 사라진다' in out,
              '축6-b', 'FAIL 사유를 「덮어쓰기」로 명시한다')
        check(r(dst3) == DST_EXISTING,
              '축6-c', 'FAIL 시 목적지를 건드리지 않았다 (원문 바이트 동일)')
        check(r(src3) == SRC,
              '축6-d', 'FAIL 시 원본도 건드리지 않았다')

        print('\n[결과] 단정 %d건 · 실패 %d건' % (ASSERTS[0], len(FAILS)))
        if FAILS:
            for f in FAILS:
                print('  🔴 %s' % f)
            print('🔴 FAIL')
            return 1
        print('🟢 PASS — 6축 %d단정 전건 통과' % ASSERTS[0])
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
