# -*- coding: utf-8 -*-
"""[2026-09-15 O164] `sv_comment_object_gate` 음성 테스트.

🔴 왜 음성 테스트인가(`R3-2` · 절차서 §5-1):
   「고친 뒤 통과」는 게이트가 결함을 **본다**는 증거가 아니다.
   **고치기 전 코드에서 반드시 실패하는 축**이 있어야 그 증거가 된다.

🟢 축1 = **오염 기반 재현** — O164 `D1` 실물(`SV_EVENT_PARTICIPATION` view-level comment 가
   `GOLD.FACT_EVENT_PARTICIPATION` 을 가리키고 table 절은 `FACT_EVENT_ATTENDANCE`)을
   픽스처로 넣어 **rc=1** 을 단정한다. 이 축이 없으면 게이트가 그 결함을 본다는 증거가 없다.

🔴 라이브에 붙지 않는다 — 인벤토리·DDL 을 **주입**한다(`inv=`·`ddls=`).
   그래야 계정이 바뀌어도 이 테스트의 판정이 흔들리지 않는다.
"""
import sys, io, contextlib

sys.path.insert(0, '/workspace/scripts')
import sv_comment_object_gate as G

# 라이브 인벤토리 픽스처 — `FACT_EVENT_PARTICIPATION` 은 **일부러 넣지 않는다**.
FQ = {
    'GOLD.FACT_EVENT_ATTENDANCE', 'GOLD.DIM_DATE', 'GOLD.DIM_EVENT', 'GOLD.DIM_MEMBER',
    'GOLD.FACT_MEMBER_EVENT', 'GOLD.WIDE_BIGQUERY_BEHAVIOR', 'GOLD.FACT_MEMBER_MONTHLY',
    'GOLD.FACT_TARGET_MEMBER_DEV',
    'SILVER.CRM_EVENT_PARTICIPATION', 'SILVER.CRM_MEMBER_DEV',
    'SILVER.CRM_MEMBER_DISCONTINUE', 'SILVER.CRM_SEND_MEMBER', 'SILVER.CRM_SEND_REQUEST',
    'SILVER.CRM_PAYMENT_BILLING',
    'SILVER.AGENCY_AD_DIGITAL', 'SILVER.AGENCY_AD_BROADCAST',
    'SERVING.SV_EVENT_PARTICIPATION',
}
BARE = {n.split('.', 1)[1] for n in FQ}
INV = (FQ, BARE)

# O164 D1 실물 축약 재현.
DDL_BAD = {
    'SV_EVENT_PARTICIPATION': (
        "create or replace semantic view SV_EVENT_PARTICIPATION\n"
        " tables ( FEP as GN_DW.GOLD.FACT_EVENT_ATTENDANCE"
        " comment='(base: GOLD.FACT_EVENT_ATTENDANCE)' )\n"
        " comment='Phase-1 행사 참여 SV (base: GOLD.FACT_EVENT_PARTICIPATION, grain: 1행).';"
    ),
}
DDL_GOOD = {
    'SV_EVENT_PARTICIPATION': DDL_BAD['SV_EVENT_PARTICIPATION'].replace(
        'base: GOLD.FACT_EVENT_PARTICIPATION', 'base: GOLD.FACT_EVENT_ATTENDANCE'),
}
# ② 형제 승계 축 — 🔴 O164 자기시정 실물: 형제는 **어간**을 공유한다.
#    `CRM_SEND_MEMBER/REQUEST` = `CRM_SEND_REQUEST`(실재) ⇒ **오탐이면 안 된다.**
DDL_SIB_GOOD = {
    'SV_SERVICE': (
        "comment='[원천: CRM → SILVER.CRM_SEND_MEMBER/REQUEST"
        " → GOLD.FACT_MEMBER_EVENT].';"
    ),
}
DDL_SIB_GOOD2 = {
    'SV_MEMBER_MONTHLY': (
        "comment='[원천: CRM → SILVER.CRM_PAYMENT_BILLING ∪ CRM_MEMBER_DEV/DISCONTINUE"
        " → GOLD.FACT_MEMBER_MONTHLY].';"
    ),
}
# 어간 후보 전건이 부재하면 FAIL 이어야 한다(검사를 끄지 않았다는 단정).
DDL_SIB_BAD = {
    'SV_MEMBER_EVENT': (
        "comment='[원천: CRM → SILVER.CRM_MEMBER_DEV/GHOSTTABLE"
        " → GOLD.FACT_MEMBER_EVENT].';"
    ),
}
# ① 접두 와일드카드 — `SILVER.AGENCY_AD_*` 는 오기가 아니다(라이브 접두 적중 2건).
DDL_WILD_GOOD = {
    'SV_AD': "comment='[원천: AGENCY 3소스 + GA4 → SILVER.AGENCY_AD_* → GOLD.DIM_DATE].';",
}
# 접두 적중 0건이면 FAIL 이어야 한다.
DDL_WILD_BAD = {
    'SV_AD': "comment='[원천: SILVER.NOSUCHPREFIX_* → GOLD.DIM_DATE].';",
}
# ③ 무스키마 축은 이제 **blocking** 이다(O164 실측 정밀도 4/4).
DDL_BARE_BAD = {
    'SV_SERVICE': "comment='[활성 지표: 발송/성공/실패/오픈수, WIDE_GA_BEHAVIOR].';",
}
DDL_BARE_BAD2 = {
    'SV_MEMBER_EVENT': "comment='⚠️ 목표(FACT_TARGET_DEV)에는 후원사업 축이 없다';",
}
DDL_BARE_GOOD = {
    'SV_MEMBER_EVENT': "comment='⚠️ 목표(FACT_TARGET_MEMBER_DEV)에는 후원사업 축이 없다';",
}
# 경계 축(절차서 §5-7) — 비객체 토큰이 객체로 오탐되지 않아야 한다.
DDL_BOUNDARY = {
    'SV_X': (
        "comment='라벨은 PART_STATUS_NAME 축을 쓴다(DEC-35 R1). 코드군 MS304."
        " GOLD.FACT_EVENT_ATTENDANCE 가 base 다.';"
    ),
}

RESULTS = []


def check(name, want_rc, ddls, expect_in_out=None, expect_not_in_out=None):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = G.run(ddls=ddls, inv=INV)
    out = buf.getvalue()
    ok = (rc == want_rc)
    detail = f'rc={rc} (기대 {want_rc})'
    if ok and expect_in_out:
        for t in expect_in_out:
            if t not in out:
                ok, detail = False, f'{detail} · 출력에 `{t}` 부재'
                break
    if ok and expect_not_in_out:
        for t in expect_not_in_out:
            if t in out:
                ok, detail = False, f'{detail} · 출력에 `{t}` 존재(오탐)'
                break
    RESULTS.append((ok, name, detail))
    print(('  🟢 ' if ok else '  🔴 ') + f'{name} — {detail}')


print('=' * 72)
print('[음성 테스트] sv_comment_object_gate')
print('=' * 72)

# 🔴 축1·2 = 「고치기 전 반드시 실패한다」 (O164 D1 실물)
check('축1 오염(O164 D1 실물) → FAIL 이어야 한다', 1, DDL_BAD,
      expect_in_out=['GOLD.FACT_EVENT_PARTICIPATION', 'FAIL'])
check('축2 시정본 → PASS 여야 한다', 0, DDL_GOOD)

# 🔴 축3~5 = ② 형제 승계의 **어간 공유** (O164 자기시정 · 종전 판정식은 전건 오탐이었다)
check('축3 형제 어간 공유(CRM_SEND_MEMBER/REQUEST) → 오탐 0 이어야 한다', 0, DDL_SIB_GOOD,
      expect_not_in_out=['SILVER.REQUEST'])
check('축4 형제 어간 공유(∪ CRM_MEMBER_DEV/DISCONTINUE) → 오탐 0 이어야 한다', 0,
      DDL_SIB_GOOD2, expect_not_in_out=['SILVER.DISCONTINUE'])
check('축5 어간 후보 전건 부재 → FAIL 이어야 한다', 1, DDL_SIB_BAD,
      expect_in_out=['GHOSTTABLE', '어간 후보'])

# 🔴 축6·7 = ① 접두 와일드카드 (검사를 끄지 않았다는 단정)
check('축6 접두 와일드카드 적중 → PASS 여야 한다', 0, DDL_WILD_GOOD,
      expect_in_out=['와일드카드 통과 1건'])
check('축7 접두 적중 0건 → FAIL 이어야 한다', 1, DDL_WILD_BAD,
      expect_in_out=['NOSUCHPREFIX'])

# 🔴 축8~10 = ③ 무스키마 축의 **blocking 승격** (O164 실측 정밀도 4/4)
check('축8 무스키마 개명전 이름(WIDE_GA_BEHAVIOR) → FAIL 이어야 한다', 1, DDL_BARE_BAD,
      expect_in_out=['WIDE_GA_BEHAVIOR'])
check('축9 무스키마 개명전 이름(FACT_TARGET_DEV) → FAIL 이어야 한다', 1, DDL_BARE_BAD2,
      expect_in_out=['FACT_TARGET_DEV'])
check('축10 개명 후 이름 → PASS 여야 한다', 0, DDL_BARE_GOOD)

# 🔴 경계 = 오탐 0(절차서 §4-4 「매치의 이웃을 보라」의 집행)
check('축11 경계 — DEC-35·MS304 를 객체로 오탐하지 않는다', 0, DDL_BOUNDARY,
      expect_not_in_out=['DEC-35', 'MS304'])

# 🔴 분모 축 — 빈 입력에서 조용히 통과하지 않는지(분모가 0 임을 출력에 박는가)
check('축12 빈 입력은 분모 0 을 출력에 박는다', 0, {},
      expect_in_out=['SV 0종'])

print('=' * 72)
failed = sum(1 for ok, _, _ in RESULTS if not ok)
print(f'{"🔴" if failed else "🟢"} 축 {len(RESULTS)}개 · 실패 {failed}건')
sys.exit(1 if failed else 0)
