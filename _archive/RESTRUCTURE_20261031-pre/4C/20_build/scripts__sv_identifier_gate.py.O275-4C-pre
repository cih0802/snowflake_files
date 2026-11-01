# -*- coding: utf-8 -*-
"""[2026-08-18 O84] Semantic View **식별자 실재 게이트** — 문서·Agent 스펙이 쓴 이름이 라이브에 있는가.

🔴 왜 필요한가(실측 경위 · 착수표 ⑱ C3 = O76-B 처방):
   O76 이 마케팅 Agent 설계문서·스펙에 metric·dimension 이름을 적었는데
   그 이름이 `DESCRIBE SEMANTIC VIEW` 와 대조된 적이 없었다 ⇒ **미검증 식별자 7건(A8)이
   모든 게이트를 조용히 통과**했다. 기존 게이트의 축은 단위(sv_unit_gate)·코드라벨
   (sv_code_label_gate)·COMMENT 드리프트(comment_drift_gate)이고
   **「이 이름이 실재하는가」를 묻는 축은 없었다.**

🔴 왜 사람이 못 잡는가: 9 SV 에 식별자가 수백 개이고, 틀린 이름은 배포 시점에
   에러를 내지 않는다 — Agent 가 런타임에 0행이나 오답을 낸다(무증상 오답 계열).

판정 축 3개
  ① 🔴 **blocking · SV 실재** — Agent 스펙 `tool_resources[*].semantic_view` FQN 이
     라이브에 있는가. 없으면 그 도구는 배포 즉시 죽은 도구다.
  ② 🔴 **blocking · 정규화 참조** — 문서·스펙 본문의 `SV_X.IDENT` 형태.
     SV 가 실재하고 그 SV 에 그 식별자가 있어야 한다.
  ③ 🟠 **advisory · 백틱 식별자** — 백틱으로 감싼 `IDENT` / `FMC.IDENT` 형태 중
     식별자 모양(UPPER_SNAKE)인 것을 전 SV 식별자 합집합과 대조.
     🔴 여기는 **advisory 다** — 문서는 BRONZE·SILVER·GOLD 컬럼명도 백틱으로 쓰므로
     SV 식별자가 아닌 이름이 정상적으로 섞인다. blocking 으로 만들면 오탐이 쏟아진다.
     ⇒ `P16`(침묵 통과보다 오탐이 안전하다)과 `P106`(검사를 끄면 진짜가 조용해진다)의
     절충으로, ③ 은 **보고하되 종료코드를 바꾸지 않는다**.

🔴 이 게이트는 「이름이 실재한다」만 본다 — **의미가 맞는가는 보지 않는다**.
   `CHURN_RATE_12M` 을 개발건수 자리에 써도 ①②③ 전부 통과한다(사람 판단 소관).
"""
import sys, re, os, json, glob, argparse

sys.path.insert(0, '/workspace/scripts')

ROOT = '/workspace'
AGENT_GLOB = os.path.join(ROOT, 'cortex_project/agents/*/agent_spec.yaml')

# ③ 축의 분모. 우리가 저작·유지하는 SV·Agent 정본 표면(P229 규약 = 만들 때 분모에 들어온다).
DOC_GLOBS = [
    '05_SV-Agent_ai/*.md',
    'cortex_project/agents/*/agent_spec.yaml',
]

# 식별자 모양이지만 SV 식별자가 아닌 것이 확실한 토큰 — 오탐 억제용 명시 목록.
# 🔴 근거를 함께 적는다(sv_unit_gate.NOT_RATIO 규약과 같은 취지).
NOT_SV_IDENT = {
    'NULL', 'TRUE', 'FALSE', 'AND', 'OR', 'NOT', 'SUM', 'AVG', 'MIN', 'MAX', 'COUNT',
    'NULLS', 'LAST', 'FIRST', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END', 'SELECT', 'FROM',
    'WHERE', 'GROUP', 'ORDER', 'BY', 'DISTINCT', 'NULLIF', 'COALESCE',   # SQL 예약어
    'DIGITAL', 'VIDEO', 'REBROADCAST',                                    # 코드 **값**(축 이름이 아니다)
    'NEW', 'FALLBACK', 'STOP', 'DEV',                                     # 코드 값
    'PC', 'M',                                                            # 기기 코드 값
    'TOTAL', 'DEPT', 'SPNSR_BSNS', 'NEW_OLD', 'CAMPAIGN',                 # ML 계열유형 코드 값
    'CHANNEL_NEW_SPNSR', 'DVLP_INC',                                      # ML 분석유형 코드 값
    'UCMPGN_AVG_MEMBER', 'CMPGN_TOTAL',                                   # ML LTV유형 코드 값
    'GN_DW', 'BRONZE', 'SILVER', 'GOLD', 'SERVING', 'ML',                 # DB·스키마
}

# 🔴🔴 [O84 첫 실사용에서 드러난 설계 공백] 이 게이트는 「그 이름을 쓴다」와
#     「그 이름을 **제거했다**」를 구별하지 못한다.
#     실측 = `SV_MEMBER_EVENT.AVG_RETENTION_MONTHS` 가 3표면에서 ② blocking 으로 잡혔는데
#     세 문장 전부 *"전건 NULL → 제거·재배포 완료"* 라는 **역사적 서술**이었다(오탐).
#     ⇒ 이것은 `index_row_gate`(의도적 삭제 ↔ 사고를 구별 못 함 · O82-C ④)와
#        `split_doc --verify` 게이트3(은퇴를 유실로 오탐 · O83-C)과 **같은 계열**이다.
# 🔴 처방을 「검사 끄기」로 하지 않았다(`P106` — 끄면 진짜 오기가 조용해진다).
#    대신 **행선지를 명시한 화이트리스트**로 둔다: 「라이브에 없는 것이 정상이며 그 사유가 무엇인가」.
#    등재하지 않은 부재 식별자는 계속 blocking 이다(`sv_unit_gate.NOT_RATIO` 와 같은 규약).
RETIRED_IDENTS = {
    ('SV_MEMBER_EVENT', 'AVG_RETENTION_MONTHS'):
        '2026-07-22 제거·재배포 완료(전건 NULL — 가입↔중단 페어링 불가). '
        '참조 3표면은 제거 사실을 기록한 역사적 서술이며 사용 주장이 아니다.',
}

# 🔴 ① 축에서 「배포되지 않았을 뿐 오기는 아닌」 SV 를 별 버킷으로 보고한다.
#    blocking 은 유지한다 — 이 스펙을 그대로 배포하면 죽은 도구가 생기기 때문이다.
#    실측 근거 = ML 예측 16테이블은 `GN_DW.ML` 에 적재돼 있으나 SERVING 뷰 7·SV 7 이 0종이다
#    (O74 가 구 계정에서 배포했고 계정 이관 후 재배포되지 않았다 · O75 가 부재를 먼저 기록).
UNDEPLOYED_PREFIX = 'SV_ML_'

IDENT_RE = r'[A-Z][A-Z0-9_]{2,}'


def live_inventory():
    """라이브 SV 별 식별자 집합을 DESCRIBE 로 수집한다."""
    from sfconn import conn, q
    inv, cn = {}, conn()
    try:
        _, rows = q("SHOW SEMANTIC VIEWS IN SCHEMA GN_DW.SERVING", cn)
        # SHOW 출력의 name 위치는 판본에 따라 다를 수 있어 이름으로 찾지 않고 값 모양으로 고른다.
        names = []
        for r in rows:
            for v in r:
                if isinstance(v, str) and v.startswith('SV_'):
                    names.append(v)
                    break
        for nm in sorted(set(names)):
            idents = set()
            _, drows = q(f"DESCRIBE SEMANTIC VIEW GN_DW.SERVING.{nm}", cn)
            for r in drows:
                kind, obj = r[0], r[1]
                if kind in ('DIMENSION', 'METRIC', 'FACT', 'TABLE', 'RELATIONSHIP') and obj:
                    idents.add(obj)
            inv[nm] = idents
    finally:
        try:
            cn.close()
        except Exception:
            pass
    return inv


def spec_semantic_views():
    """Agent 스펙이 참조하는 SV FQN 을 (스펙경로, 도구명, FQN) 으로 뽑는다.

    🔴 yaml 파서를 쓰지 않고 정규식으로 읽는다 — 스펙 YAML 에 이스케이프 결함이 있어도
       (O76-C A19 가 실제로 그랬다) 이 게이트가 죽지 않아야 한다.
    """
    out = []
    for p in sorted(glob.glob(AGENT_GLOB)):
        txt = open(p, encoding='utf-8').read()
        blk = txt.split('tool_resources:', 1)
        if len(blk) < 2:
            continue
        tool = None
        for ln in blk[1].splitlines():
            m = re.match(r'^  ([A-Za-z_][A-Za-z0-9_]*):\s*$', ln)
            if m:
                tool = m.group(1)
            m = re.search(r'semantic_view:\s*([A-Za-z0-9_.]+)', ln)
            if m:
                out.append((p, tool, m.group(1)))
    return out


def scan_refs(inv):
    """②③ 축의 참조를 문서·스펙에서 수집한다."""
    qualified, backticked = [], []
    sv_names = set(inv)
    for g in DOC_GLOBS:
        for p in sorted(glob.glob(os.path.join(ROOT, g))):
            for i, ln in enumerate(open(p, encoding='utf-8'), 1):
                for m in re.finditer(r'\b(SV_[A-Z0-9_]+)\.(' + IDENT_RE + r')\b', ln):
                    qualified.append((p, i, m.group(1), m.group(2)))
                for m in re.finditer(r'`([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)?)`', ln):
                    tok = m.group(1)
                    tail = tok.split('.')[-1]
                    if tok.startswith('SV_') and '.' in tok:
                        continue                      # ② 가 이미 본다
                    if not re.fullmatch(IDENT_RE, tail):
                        continue
                    if tail in NOT_SV_IDENT or tail in sv_names:
                        continue
                    backticked.append((p, i, tok, tail))
    return qualified, backticked


def run(advisory_verbose=False, inv=None):
    inv = inv if inv is not None else live_inventory()
    all_idents = set().union(*inv.values()) if inv else set()
    fail, undeployed, retired = [], [], []

    # ① SV 실재
    print('=' * 72)
    print('① SV 실재 (blocking) — Agent 스펙 tool_resources')
    print('=' * 72)
    a1 = 0
    for p, tool, fqn in spec_semantic_views():
        a1 += 1
        nm = fqn.split('.')[-1]
        if nm not in inv:
            where = f'{os.path.basename(os.path.dirname(p))}/{tool} → {fqn}'
            if nm.startswith(UNDEPLOYED_PREFIX):
                undeployed.append(where)
            else:
                fail.append(f'① {where} **라이브 부재**')
    print(f'  검사 {a1}건 · 라이브 SV {len(inv)}종')
    if undeployed:
        print(f'  🔴 미배포 드리프트 {len(undeployed)}건 (오기가 아니라 재배포 미이행)')
        for u in undeployed:
            print('    · ' + u)
        fail.append(f'① 미배포 SV 참조 {len(undeployed)}건 — 이 스펙을 배포하면 죽은 도구가 생긴다')

    # ② 정규화 참조
    qualified, backticked = scan_refs(inv)
    print('=' * 72)
    print('② 정규화 참조 SV_X.IDENT (blocking)')
    print('=' * 72)
    for p, ln, sv, ident in qualified:
        key = (sv, ident)
        if key in RETIRED_IDENTS:
            retired.append(f'{os.path.relpath(p, ROOT)}:{ln} {sv}.{ident}')
            continue
        if sv not in inv:
            if sv.startswith(UNDEPLOYED_PREFIX):
                undeployed.append(f'{os.path.relpath(p, ROOT)}:{ln} {sv}.{ident} (미배포 SV)')
                continue
            fail.append(f'② {os.path.relpath(p, ROOT)}:{ln} {sv}.{ident} → SV 부재')
        elif ident not in inv[sv]:
            fail.append(f'② {os.path.relpath(p, ROOT)}:{ln} {sv}.{ident} → 그 SV 에 식별자 부재')
    print(f'  검사 {len(qualified)}건 · 은퇴 등재 참조 {len(retired)}건(면제)')
    for r in retired:
        print('    · ' + r)

    # ③ 백틱 식별자 (advisory)
    print('=' * 72)
    print('③ 백틱 식별자 (advisory · 종료코드 무영향)')
    print('=' * 72)
    miss = [(p, ln, tok) for p, ln, tok, tail in backticked if tail not in all_idents]
    print(f'  검사 {len(backticked)}건 · SV 식별자 합집합 미포함 {len(miss)}건')
    if advisory_verbose:
        for p, ln, tok in miss[:80]:
            print(f'    · {os.path.relpath(p, ROOT)}:{ln} `{tok}`')
        if len(miss) > 80:
            print(f'    … 외 {len(miss) - 80}건')

    print('=' * 72)
    if fail:
        print(f'🔴 FAIL — blocking 위반 {len(fail)}건')
        for f in fail:
            print('  ' + f)
        return 1
    print('🟢 PASS — blocking 위반 0건')
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--verbose-advisory', action='store_true')
    a = ap.parse_args()
    sys.exit(run(advisory_verbose=a.verbose_advisory))
