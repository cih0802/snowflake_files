#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O63-F — `_wide_schema.yml` 의 **라벨축 NULL 사유 공백**을 메운다(`R2-7-2`).

대상 = `MEMBER_REGION`·`MEMBER_AGE_BAND`. 두 컬럼은 상류 코드 컬럼(MEMBER_AREA_CD·MEMBER_AGE_CD)에는
상세 문안이 있는데 **라벨축만 한 줄**이었다 — 소비자가 GROUP BY 하는 축은 라벨이므로 사유가 라벨에 있어야 한다.

근거(2026-08-12 O63 실측 · 규모는 원장 §O63-F):
  · `ONCE` = 개발약정 **행 자체가 없어** NULL — 개념은 있으므로 `(해당없음)` 이 아니다(지침 R2-7-2 의 예시 그대로다)
  · `FDRM` = ①코드 부재 ②`REGION` 만 센티넬 `'0'`(사전 라벨 없음) — 두 갈래 · 미매핑 0
⚠️ 규칙7: 문안에 실측 수치를 넣지 않는다.
Co-authored with CoCo
"""
import io
import sys

YML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'

PATCH = {
    '        description: "DIM_MEMBER.REGION — 지역 (#131)"':
        '        description: "DIM_MEMBER.REGION — 지역명(정본 공#131) · **CM018** 약칭 라벨. '
        '코드 = MEMBER_AREA_CD. 🔴빈 값이 세 갈래다 — ①일시회원(MEMBER_TYPE=\'ONCE\')은 개발약정 '
        '**행 자체가 없어** NULL 이다(지역 개념은 존재하므로 \'(해당없음)\' 이 아니다) '
        '②정기회원(FDRM) 중 개발약정이 없는 행도 NULL ③센티넬 코드 \'0\' 은 사전에 라벨이 없어 NULL. '
        '🟢미매핑(코드는 있는데 사전에 없음)은 없다. \'미상\' 으로 창작하지 않는다(R2-7-1). '
        '🔴**현재 거주지가 아니다** — 개발약정 시점 스냅샷이며 BRONZE 에 현주소 축이 없다(O34). '
        '⚠️지역 분포는 MEMBER_TYPE=\'FDRM\' 으로 스코프할 것 — ONCE 를 분모에 넣으면 '
        '채움률이 조용히 낮아진다(P128)."',
    '        description: "DIM_MEMBER.AGE_BAND — 연령대"':
        '        description: "DIM_MEMBER.AGE_BAND — 연령대명 · **CM014** 라벨. 코드 = MEMBER_AGE_CD. '
        '🔴빈 값은 두 갈래이며 **둘 다 개발약정 원천 행이 없는 경우**다 — 일시회원(\'ONCE\')은 전건, '
        '정기회원(FDRM)은 일부. 연령 개념은 존재하므로 \'(해당없음)\' 이 아니라 NULL 이고 미매핑도 없다. '
        '\'미상\' 으로 창작하지 않는다(R2-7-1). 🔴**연속형 나이가 아니다** — 평균·재구간화 금지'
        '(원천이 이미 구간화해 제공한다 · DEC-28). 🔴**현재 나이가 아니다** — 개발약정 시점 스냅샷이고 '
        'BRONZE 에 생년월일 축이 없어 시점정확 연령은 산출 불가다(O34). '
        '⚠️연령 분포는 MEMBER_TYPE=\'FDRM\' 으로 스코프할 것(P128)."',
}
EXPECT = 4  # 회원속성을 붙이는 WIDE 뷰 4종


def main():
    src = io.open(YML, encoding='utf-8').read()
    for old, new in PATCH.items():
        n = src.count(old)
        if n != EXPECT:
            print(f'🔴 기대 {EXPECT}건 · 실측 {n}건 — 대상이 달라졌다. 중단하고 손으로 확인할 것.')
            sys.exit(1)
        src = src.replace(old, new)
    for old in PATCH:
        if old in src:
            print('🔴 교체 후에도 원문 잔존 — 중단')
            sys.exit(1)
    io.open(YML, 'w', encoding='utf-8').write(src)
    print(f'🟢 라벨축 NULL 사유 보강 — {len(PATCH)}축 × {EXPECT}뷰 = {len(PATCH) * EXPECT}건')


if __name__ == '__main__':
    main()
