# -*- coding: utf-8 -*-
"""[2026-09-15 O164] SV COMMENT **객체 실재 게이트** — 라이브 메타데이터가 라이브 실체를 가리키는가.

🔴 왜 필요한가(실측 경위):
   O155 `D3` = `SV_MEMBER_EVENT` 의 COMMENT 가 라이브에 없는 `GOLD.FACT_MEMBER_EVENT` 를
   가리켰다. O155 는 그 **1건을 손으로 고쳤고 이 축을 보는 게이트를 만들지 않았다.**
   ⇒ O164 가 같은 판정식을 다시 돌리자 **`SV_EVENT_PARTICIPATION` 에서 재발**했다:
     view-level comment = `base: GOLD.FACT_EVENT_PARTICIPATION` (**라이브 부재**)
     table 절·table-level comment = `GOLD.FACT_EVENT_ATTENDANCE` (**옳음**)

🔴 왜 기존 게이트가 못 잡는가 — `comment_drift_gate` 의 판정식은
   **SHA256(파일) == SHA256(라이브)** 다 ⇒ **둘이 똑같이 틀리면 🟢** 다.
   그것은 **정합 게이트**이고 이 게이트는 **정확성 게이트**다(절차서 §4-3).
   정확성은 **제3의 기준**(= 라이브 객체 인벤토리)으로 봐야 한다.

🔴 왜 사람이 못 잡는가 — SV COMMENT 는 SV 당 수천 자이고, 틀린 객체명은
   배포 시 에러를 내지 않는다. **Cortex Analyst·Agent 가 그 문장을 읽고 사용자에게 틀리게 답한다**
   (무증상 오답 계열). ⚠️ SV·Agent 의 COMMENT 는 **AI 컨텍스트**다.

판정 축 3개
  ① 🔴 **blocking · 스키마 정규화 참조** — COMMENT 안의 `[GN_DW.]SCHEMA.OBJECT` 가
     라이브에 실재하는가. SCHEMA 는 `KNOWN_SCHEMAS` 로 **경계를 둔다**(절차서 §5-7)
     ⇒ `DEC-35 R1` 같은 비객체 토큰이 잡히지 않는다.
     🟢 **접두 와일드카드**(`SILVER.AGENCY_AD_*`)는 오기가 아니다 — 그 접두로 시작하는
     라이브 객체가 **1개 이상** 있으면 통과시킨다(0개면 FAIL — 검사를 끄지 않는다).
  ② 🔴 **blocking · 형제 승계 참조** — `SILVER.CRM_SEND_MEMBER/REQUEST` 처럼
     앞 객체를 줄여 쓴 나열형. 🔴🔴 **이 축에서 내가 먼저 틀렸다**(O164 자기시정) —
     형제는 **스키마를 물려받는 것이 아니라 이름 어간을 물려받는다.**
     실측 = `CRM_SEND_MEMBER/REQUEST` 의 뒤 토큰은 `SILVER.REQUEST` 가 아니라
     **`SILVER.CRM_SEND_REQUEST`** 이고, `CRM_MEMBER_DEV/DISCONTINUE` 는
     **`SILVER.CRM_MEMBER_DISCONTINUE`** 다 ⇒ 스키마만 이어붙이면 **전건 오탐**이다.
     🟢 판정식 = 앞 객체명의 **누적 어간 전건**(`CRM_`·`CRM_SEND_`…)을 붙여 본 뒤
     하나라도 실재하면 통과. 전부 부재면 FAIL.
  ③ 🔴 **blocking · 무스키마 객체형 토큰** — `FACT_`·`DIM_`·`WIDE_`·`SV_` 접두의
     이름이 라이브 객체 합집합에 있는가.
     🔴🔴 **이 축을 advisory 로 두려 했으나 실측이 반대였다**(O164) — 라이브 17 SV 전건에서
     이 축이 낸 **4건이 전부 진짜 결함**이었다(오탐 0 · 정밀도 4/4):
     `FACT_EVENT_PARTICIPATION` · `FACT_TARGET_DEV`(개명 전 이름) ·
     `WIDE_GA_BEHAVIOR`(개명 전 이름) · `SV_BUDGET_YEARLY`(실재하지 않는 SV 로 유도).
     반대로 **blocking 으로 뒀던 ①② 가 낸 3건은 전부 내 판정식의 오탐**이었다.
     ⇒ 🟢 `P16`(침묵 통과보다 오탐이 안전하다)의 근거가 이 축에 **실측으로** 있다.
     ⚠️ 역사적 서술로 은퇴 이름을 적어야 하면 `RETIRED_REFS` 에 **사유와 함께** 등재한다.


🔴 이 게이트는 「그 이름이 라이브에 있는가」만 본다 — **의미가 맞는가는 보지 않는다.**
   `base: GOLD.DIM_DATE` 라고 적어도 ①②③ 전부 통과한다(사람 판단 소관).

🟢 기준선이 없다 — 이 게이트는 **증가 차단이 아니라 해소**를 요구한다.
   부재 참조는 정당한 잔여가 아니므로 화이트리스트도 두지 않는다.
   ⚠️ 단, 「라이브에 없는 것이 정상」인 사유가 생기면 `RETIRED_REFS` 에 **사유와 함께** 등재한다.
"""
import sys, re, os, argparse

sys.path.insert(0, '/workspace/scripts')

# 🔴 경계를 둔다(절차서 §5-7) — 이 접두로 시작하는 토큰만 「객체 참조」로 읽는다.
#    이것을 넓히면 `DEC-35 R1`·`MS304 코드군` 같은 문장이 객체로 오탐된다.
KNOWN_SCHEMAS = (
    'BRONZE_CRM', 'BRONZE_ERP', 'BRONZE_AGENCY', 'BRONZE_GA4', 'BRONZE_GSC',
    'SILVER', 'GOLD', 'SERVING', 'ML', 'OPS',
)

# ③ 축이 객체형으로 읽는 접두. 🔴 근거 = 이 워크스페이스의 GOLD·SERVING 명명 규약.
OBJ_PREFIXES = ('FACT_', 'DIM_', 'WIDE_', 'SV_', 'ML_RST_DATA_')

# 「라이브에 없는 것이 정상이며 그 사유가 무엇인가」를 명시하는 화이트리스트.
# 🔴 사유 없는 등재를 두지 마라 — 그러면 게이트가 조용해진다(`P106`).
RETIRED_REFS = {}

FQ_RE = re.compile(
    r'\b(?:GN_DW\.)?(' + '|'.join(KNOWN_SCHEMAS) + r')\.([A-Z][A-Z0-9_]{2,})\b'
)
# ② 축: 앞 참조 뒤에 붙는 형제 나열. 구분자 = `/` `∪` (공백 허용)
#    🔴 `re.match` 로 **앞 참조의 끝 위치에서만** 본다(전역 검색이면 무관한 나열이 섞인다).
SIB_PAT = r'\s*(?:/|∪)\s*([A-Z][A-Z0-9_]{2,})\b'
BARE_RE = re.compile(r'\b(' + '|'.join(p + r'[A-Z0-9_]{2,}' for p in OBJ_PREFIXES) + r')\b')


def live_inventory(cn=None):
    """라이브 객체 인벤토리 = {'SCHEMA.OBJECT'} ∪ {'OBJECT'} · SV 이름 포함."""
    from sfconn import conn, q
    own = cn is None
    cn = cn or conn()
    try:
        fq, bare = set(), set()
        _, rows = q(
            "SELECT TABLE_SCHEMA, TABLE_NAME FROM GN_DW.INFORMATION_SCHEMA.TABLES", cn)
        for sch, nm in rows:
            fq.add(f'{sch}.{nm}')
            bare.add(nm)
        _, rows = q("SHOW SEMANTIC VIEWS IN DATABASE GN_DW", cn)
        for r in rows:
            for v in r:
                if isinstance(v, str) and v.startswith('SV_'):
                    fq.add(f'SERVING.{v}')
                    bare.add(v)
                    break
        return fq, bare
    finally:
        if own:
            try:
                cn.close()
            except Exception:
                pass


def live_sv_ddls(cn=None):
    """{SV명: DDL 문자열}."""
    from sfconn import conn, q
    own = cn is None
    cn = cn or conn()
    try:
        names = []
        _, rows = q("SHOW SEMANTIC VIEWS IN DATABASE GN_DW", cn)
        for r in rows:
            for v in r:
                if isinstance(v, str) and v.startswith('SV_'):
                    names.append(v)
                    break
        out = {}
        for nm in sorted(set(names)):
            _, d = q(
                f"SELECT GET_DDL('SEMANTIC_VIEW','GN_DW.SERVING.{nm}')", cn)
            out[nm] = d[0][0] or ''
        return out
    finally:
        if own:
            try:
                cn.close()
            except Exception:
                pass


def scan_ddl(sv, ddl):
    """한 SV DDL 에서 ①②③ 축의 참조를 뽑는다.

    반환 = (qualified, siblings, bare)
      · qualified = [(sv, schema, obj, is_wildcard, pos)]
      · siblings  = [(sv, schema, 앞_객체명, 형제_꼬리, pos)]
      · bare      = [(sv, token, pos)]

    🔴 판정식은 **매치의 이웃을 본다**(절차서 §4-4) — 와일드카드 `*` 와
       형제 나열의 **어간 공유**가 그 이웃이다. 둘을 안 보면 전건 오탐이 난다(O164 자기시정).
    """
    qualified, siblings, bare = [], [], []
    for m in FQ_RE.finditer(ddl):
        sch, obj = m.group(1), m.group(2)
        pos = m.end()
        wild = ddl[pos:pos + 1] == '*'
        if wild:
            pos += 1
        qualified.append((sv, sch, obj, wild, m.start()))
        # ② 형제 승계 — `/X` 또는 `∪ X` 가 이어지면 앞 객체의 **어간**을 물려받는다.
        #    🔴 어간의 출처는 **직전 형제**다(최초 객체가 아니다) — 그래서 체인을 들고 간다.
        #    실측 = `SILVER.CRM_PAYMENT_BILLING ∪ CRM_MEMBER_DEV/DISCONTINUE` 에서
        #    `DISCONTINUE` 의 어간은 `CRM_MEMBER_DEV` 이고 `CRM_PAYMENT_BILLING` 이 아니다.
        chain = [obj]
        while True:
            sm = re.match(SIB_PAT, ddl[pos:])
            if not sm:
                break
            tail = sm.group(1)
            siblings.append((sv, sch, list(chain), tail, pos))
            chain.append(tail)
            pos += sm.end()
    for m in BARE_RE.finditer(ddl):
        bare.append((sv, m.group(1), m.start()))
    return qualified, siblings, bare


def stem_candidates(prev_obj, tail):
    """앞 객체명의 누적 어간을 붙인 형제 후보 전건 (긴 어간부터).

    예: prev=`CRM_SEND_MEMBER` · tail=`REQUEST`
        ⇒ ['CRM_SEND_REQUEST', 'CRM_REQUEST', 'REQUEST']
    """
    parts = prev_obj.split('_')
    out = []
    for k in range(len(parts) - 1, 0, -1):
        out.append('_'.join(parts[:k]) + '_' + tail)
    out.append(tail)
    return out


def run(ddls=None, inv=None, verbose=False):
    fq, bare_inv = inv if inv is not None else live_inventory()
    ddls = ddls if ddls is not None else live_sv_ddls()

    fail, retired = [], []
    n1 = n2 = n3 = 0
    wild_ok = 0

    print('=' * 72)
    print(f'[SV COMMENT 객체 실재 게이트] SV {len(ddls)}종 · 라이브 객체 FQ {len(fq)}개')
    print('=' * 72)

    for sv in sorted(ddls):
        qualified, siblings, bare = scan_ddl(sv, ddls[sv])

        # ① 스키마 정규화 참조
        for who, sch, obj, wild, pos in qualified:
            n1 += 1
            ref = f'{sch}.{obj}'
            if ref in RETIRED_REFS:
                retired.append(f'{who} {ref}')
                continue
            if wild:
                # 🟢 접두 와일드카드 — 그 접두로 시작하는 라이브 객체가 1개 이상이면 통과.
                hits = [x for x in fq if x.startswith(f'{sch}.{obj}')]
                if hits:
                    wild_ok += 1
                    continue
                fail.append(f'① {who} → `{ref}*` **접두에 해당하는 라이브 객체 0개**')
                continue
            if ref not in fq:
                fail.append(f'① {who} → `{ref}` **라이브 부재**')

        # ② 형제 승계 참조 (어간 공유 · 체인은 직전 형제부터 거슬러 본다)
        for who, sch, chain, tail, pos in siblings:
            n2 += 1
            cands = []
            for prev in reversed(chain):
                for c in stem_candidates(prev, tail):
                    if c not in cands:
                        cands.append(c)
            if any(f'{sch}.{c}' in RETIRED_REFS for c in cands):
                retired.append(f'{who} {sch}.{tail}')
                continue
            if not any(f'{sch}.{c}' in fq for c in cands):
                fail.append(
                    f'② {who} → `{sch}.{chain[-1]}/{tail}` **어간 후보 전건 라이브 부재** '
                    f'(후보: {", ".join(cands)})')

        # ③ 무스키마 객체형 토큰
        for who, tok, pos in bare:
            n3 += 1
            if tok in RETIRED_REFS:
                retired.append(f'{who} {tok}')
                continue
            if tok not in bare_inv:
                fail.append(f'③ {who} → `{tok}` **라이브 부재**(무스키마 객체형 토큰)')

    print(f'  ① 스키마 정규화 참조 {n1}건 · 접두 와일드카드 통과 {wild_ok}건 '
          f'· 은퇴 등재 면제 {len(retired)}건')
    print(f'  ② 형제 승계 참조 {n2}건 (어간 공유 판정)')
    print(f'  ③ 무스키마 객체형 토큰 {n3}건')

    print('=' * 72)
    if fail:
        uniq = sorted(set(fail))
        print(f'🔴 FAIL — blocking 위반 {len(uniq)}건 (중복 제거 전 {len(fail)}건)')
        for f in uniq:
            print('  ' + f)
        print('🔴 이 게이트에는 기준선이 없다 — 부재 참조는 **해소**해야 한다(증가 차단이 아니다).')
        return 1
    print('🟢 PASS — blocking 위반 0건 (①②③ 축)')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--verbose', action='store_true')
    a = ap.parse_args()
    sys.exit(run(verbose=a.verbose))

