# -*- coding: utf-8 -*-
"""[2026-08-10 O51-F] 광고 계열 8뷰 columns[] 를 기계 생성한다.

대상·문안 출처
  · `WIDE_AD_BROADCAST`(35) · `WIDE_AD_DIGITAL`(33) → **신규 이관**: `03_top-down_gold/10_` §7-A·§7-B
  · `WIDE_AD_PERFORMANCE`·`WIDE_GA_BEHAVIOR`·`WIDE_BUDGET`·`WIDE_TARGET_DEV`·
    `WIDE_AD_BROADCAST_CASE`·`WIDE_TARGET_BIZ` → **기존 yml 보존 + 경고 오버레이만**

순서 정본 = `INFORMATION_SCHEMA.ORDINAL_POSITION` (손 이관 금지).
🔴 `CREATE VIEW` 컬럼목록은 SELECT 전 컬럼과 개수·순서가 정확히 일치해야 한다 — 결손 1건이면 build 실패.
"""
import sys, re, io, collections, os
sys.path.insert(0, '/workspace/scripts')
sys.path.insert(0, '/workspace/scripts/o51d_view_comments')
from sfconn import q
import yaml
import desc_ad as DA

REF  = '/workspace/03_top-down_gold/10_WIDE VIEW 코멘트.sql'
WYML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
NEW      = ['WIDE_AD_BROADCAST', 'WIDE_AD_DIGITAL']
OVERLAY  = ['WIDE_AD_PERFORMANCE', 'WIDE_GA_BEHAVIOR', 'WIDE_BUDGET',
            'WIDE_TARGET_DEV', 'WIDE_AD_BROADCAST_CASE', 'WIDE_TARGET_BIZ']
TARGETS  = NEW + OVERLAY

# ── ① 물리 컬럼 순서(정본) ────────────────────────────────────────────────────
_, rows = q("""select table_name, column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS
where table_schema='GOLD' and table_name in (%s) order by table_name, ordinal_position"""
            % ",".join("'%s'" % t for t in TARGETS))
phys = collections.defaultdict(list)
for t, c in rows:
    phys[t].append(c)

# ── ② `10_` 참고본 이관 (신규 2뷰) ────────────────────────────────────────────
src = io.open(REF, encoding='utf-8').read()
ref = collections.defaultdict(dict)
for blk in re.split(r'ALTER VIEW GN_DW\.GOLD\.', src)[1:]:
    v = re.match(r'(\w+)', blk).group(1)
    body = blk.split(';')[0]
    for m in re.finditer(r"COLUMN\s+(\w+)\s+COMMENT\s+'((?:[^']|'')*)'", body):
        ref[v][m.group(1)] = m.group(2).replace("''", "'")

# ── ③ 기존 yml 보존 (오버레이 6뷰) ───────────────────────────────────────────
doc = yaml.safe_load(io.open(WYML, encoding='utf-8'))
existing = {}
for m in doc['models']:
    if m['name'] in OVERLAY:
        existing[m['name']] = {c['name']: (c.get('description') or '')
                               for c in (m.get('columns') or [])}

# ── ④ 조립 + 오버레이 ────────────────────────────────────────────────────────
DESC = collections.defaultdict(dict)
for v in NEW:
    DESC[v].update(ref[v])
for v in OVERLAY:
    DESC[v].update(existing.get(v, {}))

tot_fix = tot_add = 0
for v in TARGETS:
    f, a = DA.apply_ad(v, DESC[v])
    tot_fix += f
    tot_add += a
    print(f"{v:<26} 이관교정 {f:>2} · 경고부착 {a:>2}")
print(f"\n이관 문안 교정 {tot_fix}건 · 빈축·희소축 경고 부착 {tot_add}건")

# ── ⑤ 게이트: 결손·유령·TODO·규칙7 ───────────────────────────────────────────
NUM = [re.compile(r'[0-9]{1,3}(,[0-9]{3})+'),          # 천단위 행수
       re.compile(r'[0-9]+(\.[0-9]+)?%'),              # 백분율
       re.compile(r'[0-9]+(\.[0-9]+)?배')]             # 배수
WHITE = re.compile(r'#[0-9]+|(CM|MM|MS|PM|CONF|DEC|O|P|E|G|Q|AD|SVL)-?[0-9]+|[0-9]+0대')

fail = 0
for t in TARGETS:
    p, d = phys[t], DESC[t]
    miss  = [c for c in p if c not in d or not str(d[c]).strip()]
    ghost = [c for c in d if c not in p]
    todo  = [c for c in p if c in d and 'TODO' in d[c]]
    viol  = []
    for c in p:
        if c not in d:
            continue
        s = WHITE.sub('', d[c])
        if any(rx.search(s) for rx in NUM):
            viol.append(c)
    print(f"{t:<26} 물리={len(p):>3} 문안={len([c for c in p if c in d]):>3} "
          f"결손={len(miss)} TODO={len(todo)} 규칙7위반={len(viol)} 유령(폐기)={len(ghost)}")
    if miss:  print("   🔴 결손:", ", ".join(miss));            fail += 1
    if todo:  print("   🔴 TODO 잔존:", ", ".join(todo));        fail += 1
    if viol:  print("   🔴 규칙7 위반:", ", ".join(viol));       fail += 1
    if ghost: print("   ⚪ 폐기:", ", ".join(sorted(ghost)))

tot = sum(len(phys[t]) for t in TARGETS)
print(f"\n합계 물리 {tot}컬럼 · 실패 객체 {fail}")
if fail:
    sys.exit("🔴 게이트 실패 — yml 생성 중단")


def emit(t, indent='    '):
    out = [f"{indent}columns:"]
    for c in phys[t]:
        d = str(DESC[t][c]).replace('\\', '\\\\').replace('"', '\\"')
        out.append(f"{indent}  - name: {c}")
        out.append(f'{indent}    description: "{d}"')
    return "\n".join(out) + "\n"


os.makedirs('/tmp/o51f_out', exist_ok=True)
for t in TARGETS:
    io.open(f'/tmp/o51f_out/{t}.cols.yml', 'w', encoding='utf-8').write(emit(t))
print("✅ 생성:", ", ".join(TARGETS))
