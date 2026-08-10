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

    # ── EXPO-1: 폐기 판정된 정의식이 SV 에 노출되지 않는지 ─────────────────────
    # 🔴🔴 실측 사고(O40~O56): `SV_MEMBER_MONTHLY` 에 미납 **차감식**(`청구 − 납입`)과 DEC-3 **정본**이
    #   공존했고, 폐기된 쪽이 **접미사 없는 짧은 이름**(`UNPAID_RATIO`)을 차지하고 있었다. COMMENT 에
    #   「단독 인용 금지」를 적어 뒀지만 **경고문은 게이트가 아니다**(P105) — Agent 가 자연어 「미납비중」에
    #   짧은 이름을 골라 **−0.36% 를 사실로 답할 경로**였고, 사람도 실제로 그 이름에 속았다(P123).
    #   ⇒ 2026-08-10 O56 EXPO-1 로 제거했고, **재발을 문안이 아니라 이 게이트로 막는다.**
    #   판정 = 등재된 폐기식 패턴이 metric EXPRESSION 에 **1건도 없어야 한다**.
    #   ⚠️ 새 폐기식이 생기면 여기 등재한다(등재하지 않으면 이 게이트는 그것을 잡지 못한다).
    RETIRED_EXPR = [
        # (SV, 패턴 정규식, 왜 폐기인가 · 실측)
        ('SV_MEMBER_MONTHLY',
         re.compile(r'SUM\(\s*fmm\.BILLED_AMT\s*\)\s*-\s*SUM\(\s*fmm\.PAID_FEE\s*\)', re.I),
         '미납 차감식(청구−납입) — 분자에 섞인 기부금이 미납을 상쇄한다. 실측 전 기간 '
         '−3,218,518,220 / −0.360837% vs DEC-3 정본 122,621,758,323 / 13.747454% (O40·O56 EXPO-1 제거)'),
        # 🔴 [2026-08-10 O56-C EXPO-2] 납부율 모집단 불일치식.
        #   ⚠️ 오탐 주의: 이 패턴은 **나눗셈까지** 포함해야 한다. `SUM(fmm.PAID_FEE)` 만 보면
        #     정상 지표 `TOTAL_PAID_ALL`(= 총수납액 · 결함 아님)을 잡는다. 또 `fmm.PAID_FEE_BILLABLE` 은
        #     `PAID_FEE` 뒤에 닫는 괄호가 없어 `PAID_FEE\s*\)` 에 걸리지 않는다(정본 `PAYMENT_RATE_FEE` 보호).
        ('SV_MEMBER_MONTHLY',
         re.compile(r'SUM\(\s*fmm\.PAID_FEE\s*\)\s*/\s*NULLIF\(\s*SUM\(\s*fmm\.BILLED_AMT\s*\)', re.I),
         '납부율 모집단 불일치식 — 분자는 회비+기부금이고 분모는 회비 청구뿐이다. BRONZE 실측: 기부 원천 '
         '`TM_PM_DNTN_DTLS` 에 청구 컬럼(`RQEST_AMT`)이 **아예 없어** 분모에 들어갈 수 없다 ⇒ 비율이 '
         '구조적으로 100% 를 넘는다(전 기간 100.36% vs 회비 기준 정본 86.192258%). 정본 = `PAYMENT_RATE_FEE` '
         '(O40·O56-C EXPO-2 제거)'),
    ]
    retired_hit = []
    cn3 = conn()
    for s in names:
        _, rows3 = q(f'desc semantic view {SCHEMA}.{s}', cn3)
        for kind, name, parent, prop, val in rows3:
            if kind != 'METRIC' or prop != 'EXPRESSION':
                continue
            for sv_name, pat, why in RETIRED_EXPR:
                if sv_name == s and pat.search(val or ''):
                    retired_hit.append((s, name, why, ' '.join((val or '').split())[:80]))
    cn3.close()
    for s, n, why, e in retired_hit:
        print(f"  🔴 폐기식 노출: {s}.{n}  {e}  ▸ {why}")
    print(f"  ⇒ 폐기식 검사: 등재 패턴 {len(RETIRED_EXPR)}종 · 노출 {len(retired_hit)}건")

    # ── COMMENT 수치 금지 게이트 (05_0 COMMENT 작성 규약 (1) · 04 §6.9-(8) · 작업규칙 7) ──
    # 🔴🔴 왜 게이트인가: 이 규약은 **문안으로만 존재해서 이미 두 번 위반됐다.**
    #   ① O51-D 에서 뷰 컬럼 COMMENT 109/355 가 수치를 담아 위반(사용자 판정으로 「규칙 7 엄수」 확정 · P111)
    #   ② 2026-08-10 O56 에서 **내가 SV metric COMMENT·AI_SQL_GENERATION 에 다시 수치를 주입**했다(재발).
    #   ⇒ 경고문은 게이트가 아니다(P105) — 규약을 실행 가능한 검사로 고정한다.
    # 금지 사유(규약 원문): Agent 가 COMMENT 를 **답변 근거로 인용**하므로, 박아둔 수치는 적재량이 바뀌는
    #   순간 Agent 가 **틀린 값을 사실로 말한다**(계정 재현 시 전 수치 불일치 실측 · 04 §6.9-(8)).
    # 판정 대상 = 라이브 SV 의 COMMENT·AI_SQL_GENERATION 문안.
    # ⚠️ 보존해야 하는 것(규약 (3) 등)은 잡지 않는다 — 코드값·지표번호·절 참조·불변식 임계(100%).
    NUM_BAN = re.compile(
        r'\d{1,3}(?:,\d{3})+'          # 천단위 구분 실측치 (행수·금액)
        r'|(?<!10)\d+\.\d+\s*%'        # 소수점 백분율 (커버리지·비율 실측치 · 100% 임계는 제외)
        r'|\d+\.\d+\s*%p'              # 퍼센트포인트 차이
        r'|\b\d+\.\d{4,}\b'            # 고정밀 실측치 (13.747454 등)
        r'|\b\d+(?:\.\d+)?\s*배\b'     # 배수
    )
    cmt_bad = []
    # 🔴 기지 잔존 baseline (2026-08-10 O56-D 실측 · **선행 세션 유래 · 이번 세션 추가분 아님**)
    #   O51-D-D 는 *"SV COMMENT 에 박혀 있던 절대값을 05 DDL 에서 전부 제거"* 를 ✅해소로 기록했으나
    #   라이브 실측 결과 **14건이 살아 있다** — 그 완료 보고가 사실과 다르다(P137 계열: 완료 보고도 검증 대상).
    #   ⚠️ 이 baseline 은 **면제가 아니라 기지 부채 목록**이다. 정리 계획은 이슈원장 §O56-D 에 등재했다.
    #   ⇒ 게이트는 **신규 유입만 실패**시킨다(항상 빨간 게이트는 무시되어 결국 무력화된다).
    #   baseline 에 없는 조합이 나오거나 기지 조합에 **새 토큰이 추가되면** 실패한다.
    CMT_BASELINE = {
        # 키 = (SV, kind, name, property) — 라이브 `DESC SEMANTIC VIEW` 출력 그대로 실측한 값이다.
        ('SV_MEMBER_COHORT', 'CUSTOM_INSTRUCTION', 'None', 'AI_SQL_GENERATION'): {'1,000'},
        ('SV_MEMBER_COHORT', 'METRIC', 'CHURN_RATE_12M', 'COMMENT'): {'100배'},
        ('SV_MEMBER_EVENT', 'CUSTOM_INSTRUCTION', 'None', 'AI_SQL_GENERATION'): {'99.99%', '10,000'},
        ('SV_MEMBER_EVENT', 'METRIC', 'DECREASE_EVENT_AMT', 'COMMENT'): {'10,000'},
        ('SV_MEMBER_EVENT', 'DIMENSION', 'DVLP_DIV_NM', 'COMMENT'): {'1,010,680', '1,038,262'},
        ('SV_MEMBER_EVENT', 'METRIC', 'TOTAL_DEV_CNT', 'COMMENT'): {'56.86%', '2,291,878', '3,594,843'},
        ('SV_MEMBER_FEE', 'None', 'None', 'COMMENT'): {'18.5%', '891,959,790,888', '1,056,821,121,099'},
        ('SV_MEMBER_FEE', 'CUSTOM_INSTRUCTION', 'None', 'AI_SQL_GENERATION'): {'18.5%', '10,000'},
        ('SV_MEMBER_FEE', 'METRIC', 'TOTAL_BILLING_ROWS', 'COMMENT'): {'10,000'},
        ('SV_MEMBER_FEE', 'METRIC', 'UNPAID_RATIO', 'COMMENT'): {'13.747454%'},
        ('SV_MEMBER_MONTHLY', 'None', 'None', 'COMMENT'): {'18.5%', '891,959,790,888', '1,056,821,121,099'},
        ('SV_MEMBER_MONTHLY', 'CUSTOM_INSTRUCTION', 'None', 'AI_SQL_GENERATION'): {'18.5%'},
        ('SV_MEMBER_MONTHLY', 'METRIC', 'TOTAL_PAID_ALL', 'COMMENT'): {'8.32%'},
        ('SV_MEMBER_MONTHLY', 'METRIC', 'UNPAID_RATIO', 'COMMENT'): {'14.29%', '85.65%'},
    }
    cmt_known = 0
    cn4 = conn()
    for s in names:
        _, rows4 = q(f'desc semantic view {SCHEMA}.{s}', cn4)
        for kind, name, parent, prop, val in rows4:
            if prop not in ('COMMENT', 'AI_SQL_GENERATION') or not val:
                continue
            found = set(NUM_BAN.findall(str(val)))
            if not found:
                continue
            key = (s, str(kind), str(name), prop)
            base = CMT_BASELINE.get(key, set())
            new = found - base
            if new:
                cmt_bad.append((s, f'{kind}.{name}', prop, sorted(new)))
            else:
                cmt_known += 1
    cn4.close()
    for s, obj, prop, found in cmt_bad:
        print(f"  🔴 COMMENT 수치 **신규 유입**: {s}.{obj} [{prop}] {', '.join(found)}")
    print(f"  ⇒ COMMENT 수치 금지 검사: SV {len(names)}종 · **신규 유입 {len(cmt_bad)}건** · "
          f"기지 부채 {cmt_known}건(baseline · 정리 계획 = 원장 §O56-D)")

    fail = len(viol) + len(bad_bound) + len(grant_bad) + len(retired_hit) + len(cmt_bad)
    print("\n" + ("🔴 게이트 실패" if fail else
                  "✅ 게이트 통과 — 비율 metric 전량 percent · GRANT 전량 정상 · 폐기식 노출 0 · COMMENT 수치 0"))
    return 1 if fail else 0


if __name__ == '__main__':
    sys.exit(main())
