# -*- coding: utf-8 -*-
"""[2026-08-07 O51-D] GOLD 뷰 8종 355컬럼 columns[] 를 기계 생성한다.
문안 3소스 = ① 03_top-down_gold/10_ 참고본 이관 ② 기존 _wide_schema.yml 보존 ③ O51-D 신규 작성.
순서는 INFORMATION_SCHEMA.ORDINAL_POSITION 을 정본으로 한다(손 이관 금지)."""
import sys, re, io, collections
sys.path.insert(0, '/workspace/scripts')
sys.path.insert(0, '/workspace/scripts/o51d_view_comments')
from sfconn import q
import desc_member as DM, desc_own as DO, desc_fee as DF, desc_dim as DD, desc_emptyaxis as DE

REF = '/workspace/03_top-down_gold/10_WIDE VIEW 코멘트.sql'
WYML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
TARGETS = ['WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT','WIDE_SERVICE_EVENT',
           'WIDE_EVENT_PARTICIPATION','WIDE_MEMBER_FEE','WIDE_DEV_ACHIEVEMENT',
           'DIM_MEMBER_CURRENT','DIM_MEMBER_ACQUISITION']

# ── ① 물리 컬럼 순서 (정본) ────────────────────────────────────────────────
_, rows = q("""select table_name, column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name in (%s) order by table_name, ordinal_position"""
            % ",".join("'%s'" % t for t in TARGETS))
phys = collections.defaultdict(list)
for t, c in rows: phys[t].append(c)

# ── ② 10_ 참고본 이관 ─────────────────────────────────────────────────────
src = io.open(REF, encoding='utf-8').read()
ref = collections.defaultdict(dict)
for blk in re.split(r'ALTER VIEW GN_DW\.GOLD\.', src)[1:]:
    v = re.match(r'(\w+)', blk).group(1)
    body = blk.split(';')[0]
    for m in re.finditer(r"COLUMN\s+(\w+)\s+COMMENT\s+'((?:[^']|'')*)'", body):
        ref[v][m.group(1)] = m.group(2).replace("''", "'")

# ── ②-B 이관 문안 교정 (O51-D) ────────────────────────────────────────────
# 🔴 `10_` 참고본에서 verbatim 이관하면 **거짓이 물리 COMMENT 로 심긴다**. 실제 적발분만 교정한다.
#   · "(as-was)" = DIM_ORG 를 SCD2 로 알던 시절의 표기. DEC-2 에서 **SCD1 확정**됐으므로 as-was 는 거짓이며
#     실제 의미는 current-value(조직 개편 시 과거 사건에도 현재 조직명이 붙는다). `10_` 헤더 §정정(2026-07-07)이
#     이미 이 사실을 적어 뒀는데도 본문 문안이 그대로 남아 3개월간 전파됐다(P62-B: 자기교정은 전파되지 않는다).
TRANSFER_FIX = [
 ("DIM_ORG.CORP — 법인 (as-was #114)",
  "DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — "
  "조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정)."),
 ("DIM_ORG.DIVISION — 본부/지부 (as-was #115)",
  "DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다."),
 ("DIM_ORG.DEPARTMENT — 부서 (as-was #116)",
  "DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. "
  "🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34)."),
 ("DIM_ORG.TEAM — 팀 (as-was)",
  "DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다."),
]

def apply_transfer_fix(d):
    n = 0
    for k, v in list(d.items()):
        for a, b in TRANSFER_FIX:
            if d[k] == a:
                d[k] = b; n += 1
    return n

# ── ③ 기존 _wide_schema.yml 의 WIDE_MEMBER_FEE 문안 보존(TODO 제외) ────────
wy = io.open(WYML, encoding='utf-8').read()
fee_blk = wy.split('  - name: WIDE_MEMBER_FEE', 1)[1]
kept = {}
for m in re.finditer(r'- name: (\w+)\n\s+description: "((?:[^"\\]|\\.)*)"', fee_blk):
    if 'TODO(O51-D)' not in m.group(2):
        kept[m.group(1)] = m.group(2)

# ── ④ 문안 조립 ───────────────────────────────────────────────────────────
DESC = collections.defaultdict(dict)
_fixed = 0
for v in ('WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT','WIDE_SERVICE_EVENT',
          'WIDE_EVENT_PARTICIPATION','WIDE_DEV_ACHIEVEMENT'):
    DESC[v].update(ref[v])                       # 이관
    _fixed += apply_transfer_fix(DESC[v])        # 이관 문안 교정
print(f"이관 문안 교정 (as-was → SCD1): {_fixed}건")
DESC['WIDE_MEMBER_FEE'].update(kept)             # 기존 보존
DESC['WIDE_MEMBER_FEE'].update(DF.FEE)           # 신규 22
DESC['WIDE_MEMBER_FEE'].update(DF.FEE_FIX)       # O45-B 해소 정정 2
for v in ('WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT','WIDE_SERVICE_EVENT','WIDE_EVENT_PARTICIPATION'):
    DESC[v].update(DM.MEMBER_COMMON)
for v in ('WIDE_MEMBER_MONTHLY','WIDE_MEMBER_EVENT'):
    DESC[v].update(DM.MEMBER_TRANSITION)
DESC['WIDE_MEMBER_MONTHLY'].update(DO.MONTHLY_OWN)
DESC['WIDE_MEMBER_EVENT'].update(DO.EVENT_OWN)
DESC['WIDE_SERVICE_EVENT'].update(DO.SERVICE_OWN)
DESC['WIDE_EVENT_PARTICIPATION'].update(DO.PART_OWN)
DESC['DIM_MEMBER_CURRENT'].update(DD.MEMBER_CURRENT)
DESC['DIM_MEMBER_ACQUISITION'].update(DD.MEMBER_ACQ)

# ── ④-B 빈 축 경고 오버레이 (O51-D-C) ─────────────────────────────────────
# 🔴 전건 NULL / 전건 센티넬 컬럼에 **실측 근거 경고를 덧붙인다**(기존 문안은 보존).
#   빈 축을 침묵하면 O51-D 의 목적(오답 방지) 자체가 무력해진다 — 전건 센티넬은 GROUP BY 가 성공한 것처럼 보인다.
_ea = 0
for v in DESC:
    _ea += DE.apply_empty_axis(v, DESC[v])
print(f"빈 축 경고 부착: {_ea}건")

# ── ⑤ 검증: 결손·유령·TODO·이스케이프 ────────────────────────────────────
fail = 0
for t in TARGETS:
    p, d = phys[t], DESC[t]
    miss = [c for c in p if c not in d or not d[c].strip()]
    ghost = [c for c in d if c not in p]
    todo = [c for c in p if c in d and 'TODO' in d[c]]
    print(f"{t:<26} 물리={len(p):>3} 문안={len([c for c in p if c in d]):>3} "
          f"결손={len(miss)} TODO={len(todo)} 유령(폐기)={len(ghost)}")
    if miss: print("   🔴 결손:", ", ".join(miss)); fail += 1
    if todo: print("   🔴 TODO 잔존:", ", ".join(todo)); fail += 1
    if ghost: print("   ⚪ 폐기:", ", ".join(sorted(ghost)))
tot = sum(len(phys[t]) for t in TARGETS)
print(f"\n합계 물리 {tot}컬럼 · 결손/TODO 있는 객체 {fail}")
if fail: sys.exit("🔴 게이트 실패 — yml 생성 중단")

def emit(t, indent='    '):
    out = [f"{indent}columns:"]
    for c in phys[t]:
        d = DESC[t][c].replace('\\', '\\\\').replace('"', '\\"')
        out.append(f"{indent}  - name: {c}")
        out.append(f'{indent}    description: "{d}"')
    return "\n".join(out) + "\n"

import json, os
os.makedirs('/tmp/o51d_out', exist_ok=True)
for t in TARGETS:
    io.open(f'/tmp/o51d_out/{t}.cols.yml','w',encoding='utf-8').write(emit(t))
print("✅ 생성:", ", ".join(TARGETS))
