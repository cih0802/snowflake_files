# -*- coding: utf-8 -*-
"""[2026-08-10 O52-A] Semantic View **비율 metric 단위 게이트** — percent 규약 상시 감시.

🔴 왜 필요한가(실측 경위): `SV_MEMBER_FEE.PAYMENT_RATE_FEE`·`UNPAID_RATIO` 와
   `SV_MEMBER_COHORT.CHURN_RATE_12M` 이 **분수(0~1)** 였고 동명·동의미 지표인
   `SV_MEMBER_MONTHLY` 쪽은 **percent** 였다 ⇒ 같은 이름의 값이 **100배** 어긋났다.
   Agent instruction 이 「비율=% 2자리」이고 orchestration 이 그 도구로 명시 라우팅하므로
   **에러 없이 "0.86%"(정답 86.19%) 라고 답하는 활성 경로**였다(AD-4/P19 무증상 오답).

🔴 사람 눈으로는 못 잡는다 — metric 이 9 SV 에 60여 개이고 새 SV 가 늘어난다.
   ⇒ 규약을 **게이트로 고정**한다(P120: 「무엇이 빠졌나」는 정본 기준으로 배포 전에 본다).

판정 규칙
  · 비율 metric = 식에 `/` 가 있고 **비율 의미**인 것. `×100` 이 없으면 위반.
  · 🔴 **P122**: 「나눗셈이 있다」는 「비율이다」가 아니다 — 단가·평균·배수도 나눗셈이다.
    의미 판정을 코드가 대신할 수 없으므로 **예외를 명시적 화이트리스트로 관리**한다.
    새 단가·평균 metric 을 만들면 아래 NOT_RATIO 에 등재할 것(등재하지 않으면 게이트가 잡는다 =
    의도된 동작이다. 침묵 통과보다 오탐이 안전하다 · P16).
  · 🔴 **P124**: 판정 상수 `<= 1.0` 이 남아 있으면 그 자체가 단위 분기의 흔적이다 —
    DDL 파일의 상한 판정도 함께 훑는다.
"""
import sys, re, io, os, glob

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn, q

SCHEMA = 'GN_DW.SERVING'

# 비율이 아닌 metric(나눗셈이지만 단가·평균·기간 등) — 의미 기반 예외. 근거를 함께 적는다.
NOT_RATIO = {
    'DEV_UNIT_PRICE':        '개발단가(원/건) — 금액÷건수이므로 percent 가 아니다',
    'REBRDC_DEV_UNIT_PRICE': '재방송 개발단가(원/건)',
}

RATIO_HINT = re.compile(r'RATE|RATIO|_PCT|율$|률$')


def main():
    cn = conn()
    _, svs = q(f"show semantic views in schema {SCHEMA}", cn)
    names = [r[1] for r in svs]
    viol, exempt, checked = [], [], 0
    for s in names:
        _, rows = q(f'desc semantic view {SCHEMA}.{s}', cn)
        for kind, name, parent, prop, val in rows:
            if kind != 'METRIC' or prop != 'EXPRESSION':
                continue
            if '/' not in val:
                continue
            checked += 1
            if name in NOT_RATIO:
                exempt.append(f"{s}.{name} ({NOT_RATIO[name]})")
                continue
            if not re.search(r'\*\s*100', val):
                # 이름에 비율 힌트가 없으면 「미등재 예외 후보」로 구분해 보고한다.
                hint = '비율 명명' if RATIO_HINT.search(name) else '⚠️명명상 비율 아님 — 예외 등재 검토'
                viol.append((s, name, hint, ' '.join(val.split())[:90]))
    cn.close()

    print(f"[SV 단위 게이트] SV {len(names)}종 · 나눗셈 metric {checked}개 검사")
    for e in exempt:
        print(f"  ⚪ 예외: {e}")
    for s, n, h, e in viol:
        print(f"  🔴 위반: {s}.{n}  [{h}]  {e}")
    print(f"  ⇒ 위반 {len(viol)}건 · 예외 {len(exempt)}건")

    # ── P124: DDL 파일의 상한 판정 상수 훑기 ──────────────────────────────────
    # 🔴 P114 재적용: 「판정」이라는 낱말이 들어간 **설명 문장**을 잡으면 오탐이다(최초 판이 이 파일의
    #   O52-A 경위 주석을 위반으로 잡았다). ⇒ 실제 판정 지시문 형식(`--  판정: … <= 1.0`)만 본다.
    bad_bound = []
    JUDGE = re.compile(r'(?m)^\s*--\s*판정\s*:\s*[^\n]*<=\s*1\.0')
    for f in sorted(glob.glob('/workspace/05_SV-Agent_ai/05_*_SV_DDL*.sql')):
        t = io.open(f, encoding='utf-8').read()
        for m in JUDGE.finditer(t):
            bad_bound.append(f"{os.path.basename(f)}: {m.group(0).strip()[:90]}")
    for b in bad_bound:
        print(f"  🔴 상한 판정이 1.0 (P124 — 단위 분기 흔적): {b}")

    # ── P125/P126: SV GRANT 잔존 검사 ─────────────────────────────────────────
    # 🔴🔴 실측 사고(2026-08-10 O52-B): `CREATE OR REPLACE SEMANTIC VIEW` 로 SV 2종을 재배포하고
    #   **GRANT 를 재실행하지 않아** 소비 역할이 그 SV 를 못 읽는 상태가 됐다. 문서가 3곳에서 경고하고
    #   있었고(`10_진단_원인분석.md` §129 는 **`CREATE OR ALTER` 가 GRANT 를 보존**한다는 처방까지 적어 뒀다)
    #   나는 스모크·단위·불변식만 보고 *"회귀 검증 전항 통과"* 로 보고했다.
    #   🔴 `ACCOUNTADMIN` 세션에서는 전부 성공한다 ⇒ **소유자 세션의 성공은 소비 가능성의 증거가 아니다**(P126).
    #   ⇒ 권한을 게이트 항목으로 고정한다. 판정 = 비소유 GRANT 6건(REFERENCES·SELECT × 3역할).
    ROLES = {'GN_DW_ANALYST', 'GN_DW_VIEWER', 'GN_DW_SERVICE'}
    PRIVS = {'REFERENCES', 'SELECT'}
    cn2 = conn()
    grant_bad = []
    for s in names:
        c, r = q(f"show grants on semantic view {SCHEMA}.{s}", cn2)
        ci = {x.lower(): i for i, x in enumerate(c)}
        got = {(str(row[ci['privilege']]).upper(), str(row[ci['grantee_name']]).upper())
               for row in r if str(row[ci['privilege']]).upper() != 'OWNERSHIP'}
        want = {(p, ro) for p in PRIVS for ro in ROLES}
        miss = want - got
        if miss:
            grant_bad.append((s, sorted(f"{p}→{ro}" for p, ro in miss)))
    cn2.close()
    for s, miss in grant_bad:
        print(f"  🔴 GRANT 누락: {s}  ({len(miss)}건) {'; '.join(miss)}")
    print(f"  ⇒ GRANT 검사: SV {len(names)}종 · 누락 객체 {len(grant_bad)}건")

    fail = len(viol) + len(bad_bound) + len(grant_bad)
    print("\n" + ("🔴 게이트 실패" if fail else "✅ 게이트 통과 — 비율 metric 전량 percent · GRANT 전량 정상"))
    return 1 if fail else 0


if __name__ == '__main__':
    sys.exit(main())
