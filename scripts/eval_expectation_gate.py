# -*- coding: utf-8 -*-
"""[2026-08-10 O57] **평가셋 기대값 게이트** — 폐기값이 정답으로 고정되는 것을 상시 차단.

🔴 왜 필요한가(실측 경위): 같은 병이 **세 번** 났다.
   ① O56-C(EXPO-2) — `PAYMENT_RATE` 제거 후 평가셋 M3/M4 가 폐기식 값(93.86%)을 정답으로 유지.
   ② O57 — O24(2026-08-03)가 `DEV_CNT` 를 코드 1·2·4 한정으로 교정했는데 평가셋 7문항이
      **개발원천 행수 3,594,843** 을 「개발 건수」 정답으로 유지(정본 2,291,878 · 56.86% 과대).
   ③ O57 — O56-C 가 「28곳 전량 회수」라 보고했으나 `12_paid_테스트_실행가이드.md` 가 목록에서
      누락돼 93.86% 가 그대로 남아 있었다.
   ⇒ **P159: 두 번 어겼으면 세 번째는 확실하다. 규약을 지키는 유일한 방법은 게이트다.**

무엇을 검사하나 (3층)
  · **[RETIRED]** 폐기 절대값이 **라이브 문서**에 정답으로 남아 있는지. 이력 주석은 면제한다
    (면제 조건 = 같은 줄에 `종전`·`폐기`·`이력`·`O57`·`~~` 중 하나가 있을 때).
    🔴 P145 준수: 검사기가 살아 있음을 **양성 대조**(`--self-check`)로 증명한다.
  · **[INVARIANT]** 값 판정을 절대값이 아니라 **불변식**으로 확인한다(`04_SV_설계.md` §6.9-(8)).
    V6 시간 가산성 · V7 차원 fan-out 무증폭 · V8 개발 건수 정의(O24) 유지.
  · **[DIMNAME]** 평가셋·VQR 문서가 **존재하지 않는 차원/metric** 을 지목하는지
    (O57 실측: `member.GENDER`·`member.MEMBER_STATUS` 는 SV 에 없었다 · P163).

사용법
  python3 scripts/eval_expectation_gate.py             # 전체 검사
  python3 scripts/eval_expectation_gate.py --self-check # 양성 대조(검사기 생존 증명)
  python3 scripts/eval_expectation_gate.py --no-sql     # 문서 검사만(Snowflake 미접속)

🔴 폐기값을 새로 만들었으면 **그 세션에 RETIRED 에 등재**한다. 등재하지 않으면 다음 세션이
   그 값을 정답으로 되살린다(위 ①②③ 이 전부 그 경로였다).
"""
import sys, re, os, glob, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

WS = '/workspace'

# ── 라이브 문서(정답이 실려 나가는 곳) ─────────────────────────────────────────
# _archive/ 는 제외한다(이력 보존 목적).
LIVE_DOCS = [
    '05_SV-Agent_ai/06_검증쿼리_VQR.md',
    '05_SV-Agent_ai/07_평가셋_eval.md',
    '05_SV-Agent_ai/08_AGENT_spec.md',
    '05_SV-Agent_ai/10_SI연결_검증.md',
    '05_SV-Agent_ai/12_paid_테스트_실행가이드.md',
    '05_SV-Agent_ai/00_README.md',
]
# Agent 정본 스펙(가장 위험 — Agent 가 직접 읽는다)
LIVE_SPECS = ['cortex_project/agents/AGENT_MEMBER/agent_spec.yaml',
              'cortex_project/agents/AGENT_OVERALL/agent_spec.yaml']

# ── 폐기 절대값 등록부 ─────────────────────────────────────────────────────────
# 형식: 폐기값 정규식 → (사유, 정본값 안내, 정본값 정규식)
# 🔴 면제 규칙 2종
#   ① 이력 토큰(HISTORY_TOKENS)이 같은 줄에 있으면 면제 — 「종전 …였다」류 서술.
#   ② **정본값이 같은 줄에 함께 있으면 면제** — 두 값을 나란히 놓은 줄은 「비교·유도」이고
#      정답으로 쓰는 것이 아니다(O57 실측: 이 규칙이 없으면 설명 줄 3건이 전부 오탐이었다).
RETIRED = {
    r'3,594,843':      ('O24 이전 DEV_CNT(전건=1) — 개발원천 행수를 개발 건수로 계상',
                        '2,291,878', r'2,291,878'),
    r'1,585,949':      ('개발원천 distinct 회원수를 「개발한 회원수」로 계상',
                        '1,585,923 (⚠️ FACT_MEMBER_COHORT.ACQ_MEMBERS 는 1,585,949 가 정본이다 — 문맥 확인)',
                        r'1,585,923'),
    r'93\.86|93\.66|93\.98': ('O56-C 폐기식 PAYMENT_RATE 연도값',
                        '86.05 · 85.77 · 85.65', r'86\.05|85\.77|85\.65'),
    r'100\.36':        ('제거된 PAYMENT_RATE(분자 기부금 혼입) 전기간값',
                        '86.19 (PAYMENT_RATE_FEE)', r'86\.19'),
    r'2,002,899|1,362,101|229,573': ('O24 이전 성별 개발건(F/M/U) — 차원 GENDER 자체가 부재',
                        'GENDER_NAME 축 사용', r'GENDER_NAME|1,273,549'),
    r'2,317,052|1,194,376': ('O24 이전 회원상태별 개발건',
                        'MBER_STAT_CD 축 재측정값', r'MBER_STAT_CD|1,229,621'),
    r'319,881':        ('O24 이전 2024 개발건', '176,400', r'176,400'),
    r'503,070,876,000': ('2026년 단독 적재 시점 편성예산을 전체로 계상',
                        '547,614,848,306', r'547,614,848,306'),
    r'199,287,107,812': ('2026년 단독 적재 시점 집행예산을 전체로 계상',
                        '297,045,080,903', r'297,045,080,903|251,015,693,747'),
    r'39\.61':         ('위 두 값에서 파생된 집행율', '54.24', r'54\.24'),
}
# 이력 주석 면제 토큰 — 이 중 하나가 같은 줄에 있으면 「정답으로 쓰는 것이 아님」으로 본다.
HISTORY_TOKENS = ('종전', '폐기', '이력', '무효', '오진', 'stale', 'O57', 'O24', 'O56-C', '~~', '교체', '정정')

# 🔴 COHORT 계열은 1,585,949 가 **정본**이다(1행/회원) — 오탐 방지 화이트리스트(파일:패턴)
WHITELIST_LINE = ('FACT_MEMBER_COHORT', 'ACQ_MEMBERS', 'TOTAL_ACQ_MEMBERS', 'FMC ')


def scan_docs(paths, label):
    viol = []
    for rel in paths:
        p = os.path.join(WS, rel)
        if not os.path.exists(p):
            viol.append((rel, 0, 'FILE_MISSING', '경로가 없다 — 등록부가 stale 이다(P132)', ''))
            continue
        with open(p, encoding='utf-8') as f:
            for i, line in enumerate(f, 1):
                if any(w in line for w in WHITELIST_LINE):
                    continue
                for pat, meta in RETIRED.items():
                    why, canon, canon_pat = meta
                    if re.search(pat, line):
                        if any(t in line for t in HISTORY_TOKENS):
                            continue          # 면제① 이력 주석
                        if canon_pat and re.search(canon_pat, line):
                            continue          # 면제② 정본값 동반 = 비교·유도 줄
                        viol.append((rel, i, pat, why, canon))
    return viol


INVARIANTS = [
    ('V6 시간 가산성(연도 분해 재합 = 총량)', """
        SELECT g.a, t.b FROM
          (SELECT SUM(TOTAL_DEV_CNT) a FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY
             DIMENSIONS month.CAL_YEAR METRICS TOTAL_DEV_CNT)) g,
          (SELECT TOTAL_DEV_CNT b FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY
             METRICS TOTAL_DEV_CNT)) t"""),
    ('V7 차원 fan-out 무증폭(성별 분해 합 = 총량)', """
        SELECT d.a, t.b FROM
          (SELECT SUM(TOTAL_DEV_CNT) a FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY
             DIMENSIONS member.GENDER_NAME METRICS TOTAL_DEV_CNT)) d,
          (SELECT TOTAL_DEV_CNT b FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY
             METRICS TOTAL_DEV_CNT)) t"""),
    ('V8 개발 건수 정의 유지(O24: 코드 1·2·4 한정)', """
        SELECT SUM(DEV_CNT), SUM(IFF(DVLP_DIV_CD IN ('1','2','4'),1,0))
        FROM GN_DW.GOLD.FACT_MEMBER_EVENT"""),
    ('V9 SV=FACT 개발/중단(EVENT)', """
        SELECT (SELECT TOTAL_DEV_CNT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT
                  METRICS TOTAL_DEV_CNT)),
               (SELECT SUM(DEV_CNT) FROM GN_DW.GOLD.FACT_MEMBER_EVENT)"""),
    ('V10 SV=FACT 편성예산(BUDGET)', """
        SELECT (SELECT TOTAL_PLAN_BUDGET FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET
                  METRICS TOTAL_PLAN_BUDGET)),
               (SELECT SUM(PLAN_BUDGET_MONTH) FROM GN_DW.GOLD.FACT_BUDGET)"""),
]

# 평가셋·VQR 문서가 지목하는 SV 차원 — 실존 여부를 대조한다(P163)
DIMREF = re.compile(r'\b(member|month|date|service|event|item|fme|fmm|fbd|fep|fse)\.([A-Z][A-Z0-9_]{2,})')


def check_sql(cn, q):
    ok, fail = [], []
    for name, sql in INVARIANTS:
        _, rows = q(sql, cn)
        a, b = rows[0][0], rows[0][1]
        if a is None or b is None:
            fail.append((name, a, b, 'NULL 반환 — 대상 부재(vacuous) 의심 · P106'))
        elif float(a) == float(b):
            ok.append((name, a))
        else:
            fail.append((name, a, b, '불변식 위반'))
    return ok, fail


def check_dimnames(cn, q):
    _, rows = q("""SELECT SEMANTIC_VIEW_NAME||'|'||TABLE_NAME||'.'||NAME
                   FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS
                   WHERE SEMANTIC_VIEW_SCHEMA='SERVING'
                   UNION ALL
                   SELECT SEMANTIC_VIEW_NAME||'|'||TABLE_NAME||'.'||NAME
                   FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_METRICS
                   WHERE SEMANTIC_VIEW_SCHEMA='SERVING'""", cn)
    known = {r[0].split('|')[1].upper() for r in rows}
    bad = []
    for rel in LIVE_DOCS:
        p = os.path.join(WS, rel)
        if not os.path.exists(p):
            continue
        with open(p, encoding='utf-8') as f:
            for i, line in enumerate(f, 1):
                if any(t in line for t in ('존재하지 않', '없다', '아니다', '부재')):
                    continue          # 「없는 차원이다」라고 경고하는 줄은 면제
                for m in DIMREF.finditer(line):
                    ref = f"{m.group(1).upper()}.{m.group(2).upper()}"
                    if ref not in known:
                        bad.append((rel, i, ref))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--self-check', action='store_true', help='양성 대조 — 검사기 생존 증명(P145)')
    ap.add_argument('--no-sql', action='store_true', help='문서 검사만')
    a = ap.parse_args()

    rc = 0
    print('=' * 78)
    print('[평가셋 기대값 게이트] O57 신설 — 폐기값이 정답으로 고정되는 것을 차단')
    print('=' * 78)

    # ── 1층 RETIRED ────────────────────────────────────────────────────────────
    docs = LIVE_DOCS + LIVE_SPECS
    viol = scan_docs(docs, 'LIVE')
    print(f"\n[RETIRED] 라이브 문서 {len(docs)}종 · 폐기값 등록부 {len(RETIRED)}개 패턴")
    if viol:
        rc = 1
        for rel, ln, pat, why, canon in viol:
            print(f"  ❌ {rel}:{ln}  /{pat}/  {why}  ⇒ 정본 {canon}")
    else:
        print("  ✅ 위반 0 — 폐기값이 정답으로 쓰인 곳 없음(이력 주석은 면제)")

    # ── 양성 대조 ──────────────────────────────────────────────────────────────
    if a.self_check:
        import tempfile
        print("\n[SELF-CHECK] 양성 대조 — 일부러 폐기값을 심어 검출되는지 본다(P145)")
        with tempfile.TemporaryDirectory() as d:
            rel = 'selfcheck.md'
            with open(os.path.join(d, rel), 'w', encoding='utf-8') as f:
                f.write("| M9 | 전체 개발건수 | 3,594,843 |\n")          # 양성① 검출돼야 한다
                f.write("| M3 | 납부율 | 93.86% |\n")                    # 양성② 검출돼야 한다
                f.write("| B1 | 편성예산 | 503,070,876,000 |\n")         # 양성③ 검출돼야 한다
                f.write("- 종전 3,594,843 은 폐기값이다\n")               # 음성① 이력 토큰 면제
                f.write("- FACT_MEMBER_COHORT.ACQ_MEMBERS 1,585,949\n")  # 음성② 화이트리스트
                f.write("- 3,594,843 에서 2,291,878 로 바뀌었다\n")        # 음성③ 정본 동반(면제②)
                f.write("- 편성 503,070,876,000 은 547,614,848,306 의 2026 몫\n")  # 음성④ 정본 동반
            g = WS
            globals()['WS'] = d
            pos = scan_docs([rel], 'SELF')
            globals()['WS'] = g
        got = len(pos)
        print(f"  양성 3 기대 · 검출 {got} · 음성 4종(이력·화이트리스트·정본동반 2) 오탐 {max(0, got - 3)}")
        if got == 3:
            print("  ✅ 검사기 생존 확인 — 양성 3/3 검출 · 음성 4/4 면제(오탐 0)")
        else:
            print("  ❌ 검사기 결함 — 「0건」을 결론으로 쓸 수 없다")
            rc = 1

    if a.no_sql:
        print(f"\n[--no-sql] 불변식·차원명 검사 건너뜀. 종료코드 {rc}")
        return rc

    # ── 2·3층 ──────────────────────────────────────────────────────────────────
    from sfconn import conn, q
    cn = conn()
    try:
        ok, fail = check_sql(cn, q)
        print(f"\n[INVARIANT] 불변식 {len(INVARIANTS)}종 (절대값 판정 금지 · §6.9-(8))")
        for n, v in ok:
            print(f"  ✅ {n}  = {v}")
        for n, x, y, why in fail:
            rc = 1
            print(f"  ❌ {n}  {x} != {y}  — {why}")

        bad = check_dimnames(cn, q)
        print(f"\n[DIMNAME] 문서가 지목한 SV 차원·metric 실존 대조 (P163)")
        if bad:
            rc = 1
            for rel, ln, ref in bad:
                print(f"  ❌ {rel}:{ln}  {ref} — SV 에 존재하지 않는다")
        else:
            print("  ✅ 미존재 차원 지목 0건")
    finally:
        cn.close()

    print(f"\n{'=' * 78}\n판정: {'PASS' if rc == 0 else 'FAIL'}  (종료코드 {rc})")
    return rc


if __name__ == '__main__':
    sys.exit(main())
