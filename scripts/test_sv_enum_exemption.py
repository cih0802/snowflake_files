#!/usr/bin/env python3
"""음성 테스트 — §6.9-(5) **열린 집합 면제**(`sv_code_label_gate` · O174 결정).

🔎 **왜 이 축이 필요한가** = `O170` 이 `SV_AD.AD_TYPE_NM`·`AD_GROUP_NM` 의 COMMENT 열거를
  **의도적으로 제거**했다(원천 재적재가 분포를 바꿔 열거·종수가 stale 이 된다). 그 결과 게이트가
  **자기 워크스페이스의 확정 처방을 advisory 로 계속 지목**했다(무행동 경고 2건 상주).
🟢 처방 = 면제하되 **조건을 기계가 보게** 한다 — COMMENT 에 `SELECT DISTINCT` 조회 지침이
  실재할 때만 면제하고 **정보 축으로 기록**한다(침묵이 아니다).
🔴 이 테스트는 그 면제가 **넓어지지 않았는지**를 같이 단정한다(면제는 구멍이 되기 쉽다).

축
  축1 열린 집합 + 조회 지침 ⇒ 위반 0 · **정보에 면제 기록**
  축2 열린 집합 + 지침 없음 ⇒ 위반 1 (면제가 넓어지지 않았다 · 역방향 오탐 축)
  축3 🔴 고치기 전 구현(무조건 위반)으로 돌리면 축1 이 실패한다
  축4 유사 문구는 면제되지 않는다(`DISTINCT` 단어만 있는 문장 · 판정 문구 계약)
  축5 열거가 실재하면 애초에 ④ 대상이 아니다(기존 동작 보존)
  축6 blocking 축(존재하지 않는 값 열거)은 면제와 무관하게 잡힌다

종료코드 = 0 전건 통과 · 1 실패.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), 'scripts'))

import sv_code_label_gate as g  # noqa: E402

FAIL = []
BT = 'GOLD.WIDE_AD_COMBINED'
COL = 'AD_TYPE_NM'
ACTUAL = {'BSA', 'CPM', 'DA', 'SA', 'BSA2', 'DA2', 'SA2'}   # 7종(저카디널리티)


def ok(cond, msg):
    if not cond:
        FAIL.append(msg)
        print('     🔴 %s' % msg)


def run(comment):
    """`judge()` 를 직접 호출한다 — 🔴 테스트가 판정식을 베끼지 않는다(`J8`)."""
    dims = [('SV_AD', 'AD', COL, BT, COL, comment)]
    return g.judge(dims,
                   {(BT, COL): set(ACTUAL)},
                   {BT: {COL}},
                   {('SV_AD', BT): {COL}},
                   card={(BT, COL): len(ACTUAL)},
                   dtype={(BT, COL): 'VARCHAR(16777216)'})


def main():
    print('=' * 72)
    print('[음성 테스트] §6.9-(5) 열린 집합 면제 (sv_code_label_gate · O174)')
    print('=' * 72)

    print('── 축1. 열린 집합 + `SELECT DISTINCT` 지침 ⇒ 위반 0 · 정보 기록')
    exempt_cmt = ('디지털 광고유형. AD_SOURCE_TYPE=DIGITAL 전용. '
                  '값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다).')
    _gh, _ct, _lb, _rt, enum1, info1 = run(exempt_cmt)
    ok(len(enum1) == 0, '지침이 있는데 열거누락으로 잡았다 — %r' % (enum1,))
    ok(any('열린 집합 면제' in s for s in info1), '면제를 정보로 기록하지 않았다(침묵이 됐다)')

    print('── 축2. 열린 집합 + 지침 없음 ⇒ 위반 1 (면제가 넓어지지 않았다)')
    _gh, _ct, _lb, _rt, enum2, _info = run('디지털 광고유형. 디지털 전용.')
    ok(len(enum2) == 1, '지침 없는 미열거를 통과시켰다 — %r' % (enum2,))

    print('── 축3. 고치기 전 구현(무조건 위반)으로 돌리면 축1 이 실패한다')
    orig = g.has_probe_instruction
    try:
        g.has_probe_instruction = lambda _c: False       # 종전 구현 재현
        _gh, _ct, _lb, _rt, enum3, info3 = run(exempt_cmt)
        ok(len(enum3) == 1,
           '종전 구현으로도 위반이 0 이다 — 이 축은 아무것도 실증하지 못한다')
        ok(not any('열린 집합 면제' in s for s in info3), '종전 구현이 면제를 기록했다')
        print('     🔎 종전 위반 %d건 ↔ 신 %d건' % (len(enum3), len(enum1)))
    finally:
        g.has_probe_instruction = orig
    _gh, _ct, _lb, _rt, enum3b, _i = run(exempt_cmt)
    ok(len(enum3b) == 0, '복구 후에도 위반이 남았다 — %r (복구 축)' % (enum3b,))

    print('── 축4. 유사 문구는 면제되지 않는다(판정 문구 계약)')
    for near in ('값이 DISTINCT 하다.', '구분(distinct) 값 참고.', '조회해서 보라.'):
        _gh, _ct, _lb, _rt, e, _i = run('디지털 광고유형. ' + near)
        ok(len(e) == 1, '유사 문구 %r 가 면제를 받았다' % near)
    ok(g.has_probe_instruction('… select distinct …'),
       '소문자 `select distinct` 를 못 읽었다(대소문자 비의존이어야 한다)')
    ok(not g.has_probe_instruction(None), 'COMMENT 부재를 면제로 읽었다')

    print('── 축5. 열거가 실재하면 애초에 ④ 대상이 아니다(기존 동작 보존)')
    enum_cmt = "실제값 7종: 'BSA'·'CPM'·'DA'·'SA'·'BSA2'·'DA2'·'SA2'"
    gh5, ct5, _lb, _rt, enum5, _i = run(enum_cmt)
    ok(len(enum5) == 0, '열거가 있는데 열거누락으로 잡았다')
    ok(len(gh5) == 0, '실재하는 값을 유령으로 잡았다 — %r' % (gh5,))
    ok(len(ct5) == 0, '종수가 일치하는데 불일치로 잡았다 — %r' % (ct5,))

    print('── 축6. blocking 축은 면제와 무관하게 잡힌다')
    gh6, _ct, _lb, _rt, _e, _i = run("실제값: 'nf1834a'·'하단DA' "
                                     '· 값 목록은 SELECT DISTINCT 로 조회한다')
    ok(len(gh6) == 1, '존재하지 않는 열거값을 면제가 덮었다 — %r' % (gh6,))
    ok('nf1834a' in gh6[0][2], '유령 값 지목이 틀렸다 — %r' % (gh6,))

    print('=' * 72)
    print('단정 %d건 · 실패 %d건' % (16, len(FAIL)))
    if FAIL:
        print('🔴 FAIL')
        return 1
    print('🟢 PASS — 전건 통과')
    return 0


if __name__ == '__main__':
    sys.exit(main())
