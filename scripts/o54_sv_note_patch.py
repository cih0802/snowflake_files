# -*- coding: utf-8 -*-
"""[2026-08-10 O54] `CREATE OR ALTER` 전환에 따른 파일 내 서술 교정. 멱등.

🔴 왜 필요한가: 본문 DDL 을 `CREATE OR ALTER` 로 바꿨는데 같은 파일의 주석이
   *"CREATE OR REPLACE 가 GRANT 를 파괴하므로 GRANT 를 반드시 함께 실행한다"* 로 남으면
   다음 세션이 파괴를 전제로 판단한다(P62-B — 자기교정은 전파되지 않는다).
🔴 대상은 **재배선·전환한 6파일뿐**이다. `05_3`(COHORT)·`05_9`(FEE)는 여전히
   `CREATE OR REPLACE` 이므로 그 경고는 사실이며 건드리지 않는다.
"""
import io
import sys

D = '/workspace/05_SV-Agent_ai/'
FILES = ['05_1_SV_DDL_MEMBER_MONTHLY.sql', '05_2_SV_DDL_MEMBER_EVENT.sql',
         '05_4_SV_DDL_SERVICE.sql', '05_5_SV_DDL_EVENT_PARTICIPATION.sql',
         '05_6_SV_DDL_BUDGET.sql', '05_7_SV_DDL_AD.sql']

PAIRS = [
    ('--   `CREATE OR REPLACE` 가 GRANT 를 파괴하지만 GRANT 절이 같은 파일에 있어 자기완결적이다.\n',
     '--   🔴 [2026-08-10 O54] 본문 DDL 은 **`CREATE OR ALTER SEMANTIC VIEW`** 다 — GRANT 가 보존된다\n'
     '--      (§129 실측 · created_on 불변). 아래 GRANT 절은 멱등 재확인용이며 ⛔ `CREATE OR REPLACE`\n'
     '--      로 되돌리면 GRANT 가 파괴된다(P125 실사고).\n'),
    ('      🔴 `CREATE OR REPLACE` 는 기존 GRANT 를 전부 삭제한다(OWNERSHIP 만 잔존) →\n'
     '         이 파일을 재실행할 때 **아래 GRANT 를 반드시 함께 실행**한다.\n',
     '      🟢 [2026-08-10 O54] 본문이 `CREATE OR ALTER` 이므로 **기존 GRANT 는 보존**된다 →\n'
     '         아래 GRANT 는 멱등 재확인이다. 🔴 판정은 소유자 세션이 아니라 **소비 역할 세션**으로\n'
     '         한다(P126) — 검사기 = `scripts/sv_unit_gate.py`.\n'),
]

# 05_7 전용 — base 표기 교정
AD_ONLY = [
    ('-- GN_DW 3단계: Semantic View DDL 정본 — SV_AD (광고 실적) + helper 뷰 FACT_AD_COMBINED',
     '-- GN_DW 3단계: Semantic View DDL 정본 — SV_AD (광고 실적) · base = GOLD.WIDE_AD_COMBINED(dbt 소유)'),
    ('--   대상 SV = **SV_AD (+ helper 뷰 `FACT_AD_COMBINED` 동봉 — 이 SV 의 단일 base 이므로 독립 실행을 위해 같은 파일에 둔다)**.',
     '--   대상 SV = **SV_AD**. base = `GOLD.WIDE_AD_COMBINED`(dbt 모델 소유) ⇒ 🔴 이 파일은 **`dbt build` 이후에만**\n'
     '--   배포 가능하다(DEC-34 §0.8-D ③ 계열 · O54 재배선). 종전 helper `SERVING.FACT_AD_COMBINED` 동봉은 폐지됐다.'),
    ('   6. SV_AD (overall Agent) — base FACT_AD_COMBINED(helper, FAP+FAD+FAB 1:1 pre-join)',
     '   6. SV_AD (overall Agent) — base GOLD.WIDE_AD_COMBINED(dbt 뷰, FAP+FAD+FAB 1:1 pre-join)'),
    ("COMMENT = 'Phase-1 광고 실적 SV(base FACT_AD_COMBINED helper).",
     "COMMENT = 'Phase-1 광고 실적 SV(base GOLD.WIDE_AD_COMBINED — dbt 소유 GOLD 뷰).")
]


def main():
    for f in FILES:
        p = D + f
        t = io.open(p, encoding='utf-8').read()
        o = t
        n = 0
        for a, b in PAIRS:
            if a in t:
                t = t.replace(a, b)
                n += 1
        if f == '05_7_SV_DDL_AD.sql':
            for a, b in AD_ONLY:
                if a in t:
                    t = t.replace(a, b)
                    n += 1
        if t != o:
            io.open(p, 'w', encoding='utf-8').write(t)
        print(f'  {f}: 치환 {n}건')

    # 잔존 검사 — 전환 6파일에 파괴 전제 서술이 남아 있으면 실패
    bad = []
    for f in FILES:
        for i, ln in enumerate(io.open(D + f, encoding='utf-8').read().split('\n'), 1):
            if '기존 GRANT 를 전부 삭제' in ln or 'GRANT 를 파괴하지만' in ln:
                bad.append(f'{f}:{i}: {ln.strip()[:80]}')
    for b in bad:
        print('  🔴 잔존:', b)
    print('✅ 통과' if not bad else '🔴 실패')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
