# -*- coding: utf-8 -*-
"""[2026-08-10 O54] SV DDL 가드레일 헤더의 R1 base 표기를 GOLD 정본으로 교정한다. 멱등.

🔴 왜 스크립트인가: 같은 2줄이 8개 파일에 복제돼 있어 손 편집은 반드시 누락된다(P105).
🔴 최초 판이 유니코드 escape 를 잘못 써(팩=U+D329 를 U+D31D 로) **전건 조용히 스킵**했다.
   교훈: 치환기는 「몇 건 바꿨나」를 출력하고 0 건이면 실패로 볼 것(P106 계열).
"""
import io
import sys

D = '/workspace/05_SV-Agent_ai/'

NOTE = '--                🔴 [2026-08-10 O54] SERVING helper 3종 → GOLD 재배선 완료(DEC-34 §0.8-D · helper DROP 은 7단계).\n'

PAIRS = [
    # (구, 신) — 백틱 판본(05_1~05_7)
    ('--   R1 fan-out : 월팩트→`SERVING.DIM_MONTH` · 회원속성→`SERVING.DIM_MEMBER_CURRENT` ·\n'
     '--                광고팩트→`SERVING.FACT_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.\n',
     '--   R1 fan-out : 월팩트→`GOLD.DIM_MONTH` · 회원속성→`GOLD.DIM_MEMBER_CURRENT` ·\n'
     '--                광고팩트→`GOLD.WIDE_AD_COMBINED`. raw `DIM_DATE`/`DIM_MEMBER` 직접조인 금지.\n' + NOTE),
    # 무백틱 판본(05_0)
    ('--   R1 fan-out : 월팩트→SERVING.DIM_MONTH · 회원속성→SERVING.DIM_MEMBER_CURRENT ·\n'
     '--                광고팩트→SERVING.FACT_AD_COMBINED(AD_PERF_DK 1:1 pre-join).\n',
     '--   R1 fan-out : 월팩트→GOLD.DIM_MONTH · 회원속성→GOLD.DIM_MEMBER_CURRENT ·\n'
     '--                광고팩트→GOLD.WIDE_AD_COMBINED(AD_PERF_DK 1:1 pre-join).\n' + NOTE),
]

FILES = ['05_0_SV_DDL.sql', '05_1_SV_DDL_MEMBER_MONTHLY.sql', '05_2_SV_DDL_MEMBER_EVENT.sql',
         '05_3_SV_DDL_MEMBER_COHORT.sql', '05_4_SV_DDL_SERVICE.sql',
         '05_5_SV_DDL_EVENT_PARTICIPATION.sql', '05_6_SV_DDL_BUDGET.sql',
         '05_7_SV_DDL_AD.sql', '05_8_SV_DDL_DEV_ACHIEVEMENT.sql',
         '05_9_SV_DDL_MEMBER_FEE.sql']


def main():
    hit = 0
    for f in FILES:
        p = D + f
        t = io.open(p, encoding='utf-8').read()
        o = t
        for a, b in PAIRS:
            t = t.replace(a, b)
        if t != o:
            io.open(p, 'w', encoding='utf-8').write(t)
            hit += 1
            print('  EDIT', f)
        elif NOTE in t:
            print('  이미반영', f)
        else:
            print('  해당없음', f)
    print(f'⇒ 교정 {hit}건')
    # 잔존 검사 — 헤더에 구 표기가 남아 있으면 실패
    bad = []
    for f in FILES:
        for i, ln in enumerate(io.open(D + f, encoding='utf-8').read().split('\n'), 1):
            if ln.lstrip().startswith('--') and 'R1 fan-out' in ln and 'SERVING.' in ln:
                bad.append(f'{f}:{i}')
    for b in bad:
        print('  🔴 구 표기 잔존:', b)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
