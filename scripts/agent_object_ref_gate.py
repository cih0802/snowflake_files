# -*- coding: utf-8 -*-
"""[2026-08-30 O121] Agent 스펙 **객체명 실재 게이트** — 스펙 본문이 쓴 DB·스키마·객체명이 라이브에 있는가.

🔴 왜 필요한가(실측 경위 · O120-B 가 손으로 4건을 찾았다):
   `AGENT_MARKETING`·`AGENT_OVERALL` 스펙이 **존재하지 않는 객체를 원천으로 발행**하고 있었다.
   스펙 자신이 *"원천 질문에는 이 description 만 근거로 답한다"* 고 지시하므로,
   배포하면 에이전트가 **없는 스키마를 자신 있게 답한다**(무증상 오답 계열).
   · `GN_DW.BRONZE_GA4`               — 스키마 자체가 부재
   · `GOLD.FACT_AD_COMBINED`          — 부재(실제 base 는 `GOLD.WIDE_AD_COMBINED`)
   · `BRONZE_BIGQUERY.events_YYYYMMDD` — 그 스키마는 테이블 0(외부 Python 이 SILVER 로 직접 적재)

🔴 왜 기존 게이트가 못 잡았는가(분모 공백):
   · `sv_identifier_gate` = `tool_resources` 의 **SV 실재**만 본다.
   · `agent_tool_claim_gate` = **가불가 모순·규칙7 수치**만 본다.
   ⇒ **본문 안의 BRONZE/SILVER/GOLD 객체명을 라이브와 대조하는 축이 어느 게이트에도 없었다.**

🔴🔴 그리고 O120-B 의 시정 자체가 분모 미달이었다 — `tool_spec.description` 만 고쳤고
   `AGENT_OVERALL` 의 **`instructions.system`** 에 같은 오기가 1건 남아 있었다(O121 이 실측 적발).
   ⇒ 🟢 **이 게이트의 분모는 「description」이 아니라 「스펙 파일 전문」이다.**
      추가로 축⑤가 **YAML 문자열 스칼라 표면 전건을 인벤토리로 출력**한다 —
      다음 세션이 「어느 표면을 봤는가」를 눈으로 셀 수 있게 하려는 것이다(분모 가시화).

판정 축 5개 (종료코드 규약 = 0 통과 · 1 위반 · 2 사용법 오류)
  ① 🔴 blocking · **스키마 실재** — `GN_DW.<SCHEMA>` / 수식 없는 `<SCHEMA>` 가 라이브에 있는가.
  ② 🔴 blocking · **객체 실재** — `[GN_DW.]<SCHEMA>.<OBJECT>` 가 라이브 테이블·뷰에 있는가.
     🔴 `SV_*` 는 **이 축에서 제외**한다 — Semantic View 는 `INFORMATION_SCHEMA.TABLES` 에
        나타나지 않으므로(O118 판정식) 여기서 보면 전건 거짓 위반이 된다. SV 는
        `sv_identifier_gate` ① 축 소관이다. ⇒ 같은 것을 두 곳에서 재지 않는다(`R3-9 ㉡`).
  ③ 🟠 advisory · **빈 스키마를 원천으로 발행** — 스키마는 실재하나 객체 0인데 부정 서술 없이 언급.
  ④ 🟠 advisory · **미수식 테이블명** — 스키마 언급에 인접한 UPPER_SNAKE 토큰(수식 없음).
     🔴 advisory 다 — 스펙 본문에는 컬럼명·코드값·지표명이 같은 모양으로 정상 등장한다.
        blocking 으로 만들면 오탐이 쏟아진다(`sv_identifier_gate` ③ 축과 같은 절충).
  ⑤ ⚪ 관측 · **표면 인벤토리** — 판정이 아니다. 분모를 숫자로 보여준다.

🔴 부정 서술 면제(`NEG_RE`): 「~는 실재하지 않는다 / 테이블이 없다 / 비어 있다 / 부재」처럼
   **부재를 알리는 문장**에서의 언급은 위반이 아니다. 실측 = 시정된 문안이 일부러
   `BRONZE_GA4` 를 「실재하지 않는다」로 명시하므로, 면제가 없으면 시정이 FAIL 을 만든다.
   🔴🔴 **이 면제가 검사를 무력화하지 않는다는 것은 음성 테스트가 단정한다**
        (`scripts/test_agent_object_ref_gate.py` 축2 = 부정어 없는 같은 토큰은 여전히 잡힌다).

🔴 이 게이트는 「이름이 실재한다」만 본다 — **그 객체가 정말 그 지표의 원천인가는 보지 않는다.**
"""
import sys
import re
import os
import json
import glob
import argparse

sys.path.insert(0, '/workspace/scripts')

ROOT = '/workspace'
AGENT_GLOB = os.path.join(ROOT, 'cortex_project/agents/*/agent_spec.yaml')
DB = 'GN_DW'

# 스키마 「모양」이다 — 라이브 인벤토리로 만들지 않는다.
# 🔴 이유: `BRONZE_GA4` 처럼 **라이브에 없는** 스키마를 잡는 것이 이 게이트의 목적이므로
#    분모를 라이브에서 뽑으면 그 토큰이 애초에 후보에 들어오지 않는다(0건 침묵 · `▣ZZZ6 ㉠`).
SCHEMA_SHAPE = r'(?:BRONZE_[A-Z0-9]+|SILVER|GOLD|SERVING|ML|OPS|SECURITY)'

# 객체 모양. 소문자 시작 토큰(`analyst_ad` 등 도구명)은 애초에 매칭되지 않는다.
OBJ_SHAPE = r'[A-Za-z][A-Za-z0-9_]{2,}'

# 부재를 알리는 문장 — 토큰 뒤 짧은 창 안에서 찾는다.
# 🔴🔴 [2026-08-30 O121-B 좁힘] 초판은 `없고|없다|부재` 를 **맨 토큰으로** 넣었다 ⇒
#    「`GOLD.FACT_X` 로 답한다. 캠페인 축이 **없다**」처럼 **객체와 무관한 부정어**가 창에 들어오면
#    면제가 성립했다(과대 면제 = 무력화 경로). ⇒ 부정어를 **객체 어휘와 짝지어야만** 인정한다.
#    🟢 시정 후에도 실제 시정 문안 2종은 면제된다(실측):
#      「`BRONZE_BIGQUERY` 는 **테이블이 없**고 `BRONZE_GA4` 라는 스키마는 **실재하지 않**는다」
#      「`BRONZE_BIGQUERY` 는 **비어 있**고 …」
#    🔴 이 좁힘이 면제를 죽이지 않는다는 것과, 맨 부정어가 더는 면제하지 않는다는 것을
#      `test_agent_object_ref_gate.py` 축③·축③-B 가 **양방향으로** 단정한다.
NEG_OBJ = r'(?:테이블|스키마|객체|뷰|샤드)'
NEG_RE = re.compile(
    r'(?:실재하지\s*않|존재하지\s*않|'                     # 객체 부재 단정(명확)
    r'%(o)s\s*(?:이|가|은|는|을|를)?\s*없|'                # 「테이블이 없다」·「스키마는 없다」
    r'없는\s*%(o)s|'                                      # 「없는 스키마」
    r'%(o)s\s*(?:이|가)?\s*부재|'                          # 「테이블 부재」
    r'비어\s*있|비었|'                                     # 「비어 있다」
    r'0\s*%(o)s|%(o)s\s*0(?:개)?)' % {'o': NEG_OBJ})
NEG_WINDOW = 60

# 🔴 SV 는 이 게이트의 축이 아니다(위 docstring ② 참조).
SV_PREFIX = 'SV_'

# 라이브에 없는 것이 정상이며 그 사유가 명시된 토큰 — 행선지를 적는다.
# 🔴 `sv_identifier_gate.RETIRED_IDENTS` 와 같은 규약이다: 등재하지 않은 부재는 계속 blocking.
KNOWN_ABSENT = {
    # (schema, object): 사유
}

# 미수식 축(④)에서 테이블명이 아닌 것이 확실한 토큰.
NOT_TABLE = {
    'DB', 'SQL', 'CRM', 'ERP', 'UMS', 'GA4', 'LTV', 'ROI', 'CTR', 'CVR', 'NULL',
    'TRUE', 'FALSE', 'SUM', 'AVG', 'MIN', 'MAX', 'COUNT', 'DISTINCT',
    'BRONZE', 'SILVER', 'GOLD', 'SERVING', 'ML', 'GN_DW',
    'DIGITAL', 'VIDEO', 'REBROADCAST', 'DEV', 'STOP', 'NEW', 'FALLBACK',
    'TOTAL', 'DEPT', 'SPNSR_BSNS', 'NEW_OLD', 'CAMPAIGN', 'PC',
}

# 🆕 🔴 [2026-08-30 O121-B] 축④ 가 처음 낸 **6건을 전건 규명**해 사유와 함께 등재한다.
#    O121 은 「라이브 미포함 6건」만 보고하고 **규명하지 않았다** — 이 세션의 주제가
#    「advisory 를 안 보면 진짜가 숨는다」인데 스스로 그것을 남겼다(자기결함).
#    🟢 실측 = **6건 전부 오탐**(컬럼명 4 + 코드값 2 · 진짜 위반 0).
#    🔴 등재는 「잡음 끄기」가 아니라 **잡음을 0 으로 내려 신규 신호가 보이게** 하는 것이다
#       — 등재하지 않은 미수식 토큰은 계속 advisory 로 나온다(무력화 아님은 음성 테스트 축⑬이 단정).
NOT_TABLE_REASON = {
    'SPNSR_BSNS_NO':     '컬럼명 — `FACT_MEMBER_SPONSOR_BIZ` 의 grain 키(후원사업번호)',
    'EXEC_BUDGET_ERP':   '컬럼명 — 집행예산(ERP 마감값) measure',
    'AD_SOURCE_TYPE':    '컬럼명 — 광고 계열 필터 축(DIGITAL/VIDEO/REBROADCAST)',
    'UCMPGN_AVG_MEMBER': '코드값 — ML LTV유형(상위캠페인 회원평균)',
    'CHANNEL_NEW_SPNSR': '코드값 — ML 분석유형(신규 후원 유치 요인)',
    'CMPGN_TOTAL':       '코드값 — ML LTV유형(일반 캠페인 후원총액)',
}


def live_inventory():
    """라이브 스키마 집합 · 스키마별 객체 집합을 수집한다."""
    from sfconn import conn, q
    cn = conn()
    try:
        _, srows = q(
            "select schema_name from %s.INFORMATION_SCHEMA.SCHEMATA "
            "where schema_name <> 'INFORMATION_SCHEMA'" % DB, cn)
        schemas = {r[0] for r in srows}
        _, trows = q(
            "select table_schema, table_name from %s.INFORMATION_SCHEMA.TABLES" % DB, cn)
        objects = {s: set() for s in schemas}
        for sch, nm in trows:
            objects.setdefault(sch, set()).add(nm)
    finally:
        try:
            cn.close()
        except Exception:
            pass
    return {'schemas': sorted(schemas),
            'objects': {k: sorted(v) for k, v in objects.items()}}


def _norm(inv):
    return set(inv['schemas']), {k: set(v) for k, v in inv['objects'].items()}


def negated(line, end):
    """토큰 직후 창 안에 부재 서술이 있는가."""
    return bool(NEG_RE.search(line[end:end + NEG_WINDOW]))


def spec_files():
    return sorted(glob.glob(AGENT_GLOB))


def surface_inventory(path):
    """YAML 문자열 스칼라 표면을 (경로표기, 길이) 로 전건 나열한다 — 관측 축⑤.

    🔴 파싱이 실패해도 게이트가 죽지 않아야 하므로 예외를 삼키고 빈 목록을 낸다
       (판정 축 ①~④ 는 **원문 전문**을 읽으므로 파싱과 무관하다).
    """
    try:
        import yaml
        doc = yaml.safe_load(open(path, encoding='utf-8'))
    except Exception:
        return []
    out = []

    def walk(node, trail):
        if isinstance(node, dict):
            for k, v in node.items():
                walk(v, trail + [str(k)])
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, trail + ['[%d]' % i])
        elif isinstance(node, str):
            out.append(('.'.join(trail), len(node)))

    walk(doc, [])
    return out


def scan(path):
    """원문 전문에서 ①②③④ 후보 토큰을 뽑는다. 분모는 파일 전문이다."""
    three = re.compile(r'\b%s\.(%s)\.(%s)\b' % (DB, SCHEMA_SHAPE, OBJ_SHAPE))
    db_sch = re.compile(r'\b%s\.(%s)\b(?!\.)' % (DB, SCHEMA_SHAPE))
    sch_obj = re.compile(r'(?<![A-Za-z0-9_.])(%s)\.(%s)\b' % (SCHEMA_SHAPE, OBJ_SHAPE))
    bare_sch = re.compile(r'(?<![A-Za-z0-9_.])(%s)(?![A-Za-z0-9_.])' % SCHEMA_SHAPE)
    unqual = re.compile(r'(?<![A-Za-z0-9_.])([A-Z][A-Z0-9]*(?:_[A-Z0-9]+){2,})(?![A-Za-z0-9_.])')

    sch_hits, obj_hits, bare_hits, unq_hits = [], [], [], []
    for i, line in enumerate(open(path, encoding='utf-8'), 1):
        seen_obj = set()
        for m in three.finditer(line):
            sch_hits.append((i, m.group(1), negated(line, m.end())))
            obj_hits.append((i, m.group(1), m.group(2), negated(line, m.end())))
            seen_obj.add(m.span())
        for m in db_sch.finditer(line):
            sch_hits.append((i, m.group(1), negated(line, m.end())))
        for m in sch_obj.finditer(line):
            if any(a <= m.start() and m.end() <= b for a, b in seen_obj):
                continue
            sch_hits.append((i, m.group(1), negated(line, m.end())))
            obj_hits.append((i, m.group(1), m.group(2), negated(line, m.end())))
        for m in bare_sch.finditer(line):
            bare_hits.append((i, m.group(1), negated(line, m.end())))
        if bare_sch.search(line) or db_sch.search(line):
            for m in unqual.finditer(line):
                tok = m.group(1)
                if tok in NOT_TABLE or re.fullmatch(SCHEMA_SHAPE, tok):
                    continue
                unq_hits.append((i, tok))
    return sch_hits, obj_hits, bare_hits, unq_hits


def run(inv=None, verbose_advisory=False):
    inv = inv if inv is not None else live_inventory()
    schemas, objects = _norm(inv)
    all_objs = set()
    for v in objects.values():
        all_objs |= v
    fail = []
    files = spec_files()

    a1 = a2 = 0
    a1_neg = a2_neg = a2_sv = 0
    a3, a4 = [], []
    a4_known = []
    surfaces = []

    for p in files:
        rel = os.path.relpath(p, ROOT)
        sch_hits, obj_hits, bare_hits, unq_hits = scan(p)
        surfaces.append((rel, surface_inventory(p)))

        for ln, sch, neg in sch_hits:
            a1 += 1
            if neg:
                a1_neg += 1
                continue
            if sch not in schemas:
                fail.append('① %s:%d `%s.%s` → **스키마 라이브 부재**' % (rel, ln, DB, sch))

        for ln, sch, obj, neg in obj_hits:
            if obj.startswith(SV_PREFIX):
                a2_sv += 1
                continue
            a2 += 1
            if neg:
                a2_neg += 1
                continue
            if (sch, obj) in KNOWN_ABSENT:
                continue
            if sch not in schemas:
                continue                      # ① 이 이미 잡았다 — 중복 계상 금지
            if obj not in objects.get(sch, set()):
                extra = ''
                if obj in all_objs:
                    where = sorted(s for s in objects if obj in objects[s])
                    extra = ' (같은 이름이 %s 에 있다 — 스키마가 틀렸다)' % '·'.join(where)
                fail.append('② %s:%d `%s.%s` → **객체 라이브 부재**%s' % (rel, ln, sch, obj, extra))

        for ln, sch, neg in bare_hits:
            if neg or sch not in schemas:
                continue
            if not objects.get(sch):
                a3.append('%s:%d `%s` (객체 0)' % (rel, ln, sch))
        for ln, tok in unq_hits:
            if tok in all_objs:
                continue
            if tok in NOT_TABLE_REASON:
                a4_known.append('%s:%d `%s` — %s' % (rel, ln, tok, NOT_TABLE_REASON[tok]))
                continue
            a4.append('%s:%d `%s`' % (rel, ln, tok))

    print('=' * 72)
    print('Agent 스펙 객체명 실재 게이트 — 분모 = 스펙 파일 %d개 **전문**' % len(files))
    print('=' * 72)
    print('  라이브 = 스키마 %d종 · 객체 %d개' % (len(schemas), len(all_objs)))

    print('-' * 72)
    print('① 스키마 실재 (blocking) — 검사 %d건 · 부정서술 면제 %d건' % (a1, a1_neg))
    print('② 객체 실재 (blocking) — 검사 %d건 · 부정서술 면제 %d건 · SV 제외 %d건'
          % (a2, a2_neg, a2_sv))
    print('   🔴 SV 제외는 오탐 회피다 — SV 는 INFORMATION_SCHEMA.TABLES 에 없고')
    print('      `sv_identifier_gate` ① 축이 SHOW SEMANTIC VIEWS 로 판정한다.')

    print('-' * 72)
    print('③ 빈 스키마를 원천으로 발행 (advisory · 종료코드 무영향) — %d건' % len(a3))
    for x in a3:
        print('    · ' + x)
    print('-' * 72)
    print('④ 미수식 테이블명 (advisory · 종료코드 무영향) — 미규명 %d건 · 규명 등재 %d건'
          % (len(a4), len(a4_known)))
    print('   🔴 **미규명이 0 이어야 한다** — 「6건」처럼 수만 보고하고 규명하지 않으면')
    print('      그 안에 진짜 위반이 숨는다(O121 이 실제로 그렇게 남겼다).')
    for x in a4_known:
        print('    🟢 ' + x)
    if a4:
        for x in a4:
            print('    🟠 ' + x)
        print('   ⇒ 🔴 위 미규명 토큰을 조사해 `NOT_TABLE_REASON` 에 **사유와 함께** 등재하거나,')
        print('      진짜 객체명이면 실제 라이브 이름으로 고쳐라.')

    print('-' * 72)
    print('⑤ 표면 인벤토리 (관측 · 판정 아님) — 🔴 이 게이트의 분모는 전문이지만,')
    print('   여기 나열된 표면 전건이 판정 대상에 들어왔음을 눈으로 셀 수 있게 둔다.')
    for rel, sfs in surfaces:
        if not sfs:
            print('  %s — YAML 파싱 실패(판정은 전문 스캔이라 영향 없음)' % rel)
            continue
        print('  %s — 문자열 표면 %d개 · 총 %d자' % (rel, len(sfs), sum(n for _, n in sfs)))
        for pathname, n in sfs:
            if n >= 200:
                print('      · %s (%d자)' % (pathname, n))

    print('=' * 72)
    if fail:
        print('🔴 FAIL — blocking 위반 %d건' % len(fail))
        for f in fail:
            print('  ' + f)
        return 1
    print('🟢 PASS — blocking 위반 0건')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser(
        description='Agent 스펙 본문의 DB·스키마·객체명이 라이브에 실재하는가를 판정한다.')
    ap.add_argument('--verbose-advisory', action='store_true')
    ap.add_argument('--offline', metavar='JSON',
                    help='라이브 대신 인벤토리 JSON 을 쓴다(음성 테스트·계정 미구성 시).')
    ap.add_argument('--dump-inventory', metavar='JSON',
                    help='라이브 인벤토리를 JSON 으로 저장한다.')
    try:
        a = ap.parse_args()
    except SystemExit:
        sys.exit(2)
    if a.dump_inventory:
        json.dump(live_inventory(), open(a.dump_inventory, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=1)
        print('🟢 인벤토리 저장: %s' % a.dump_inventory)
        sys.exit(0)
    _inv = json.load(open(a.offline, encoding='utf-8')) if a.offline else None
    sys.exit(run(inv=_inv, verbose_advisory=a.verbose_advisory))
