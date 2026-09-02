#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
table_ddl_column_gate.py — DDL 선언 ↔ dbt 모델 SELECT 컬럼 대조 게이트 (GOLD + SILVER 전수).
Co-authored with CoCo

검사 대상:
  - GOLD 37개 테이블 (models/gold/ ↔ 03_top-down_gold/06_DDL.sql)
  - SILVER 42개 테이블 (models/silver/ ↔ 04_silver_design/08_SILVER_테이블DDL_20260714.sql)
"""
import io
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, '/workspace/scripts')
import sfconn  # noqa: E402

GOLD_DDL = '/workspace/03_top-down_gold/06_DDL.sql'
SILVER_DDL = '/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql'

AUDIT_SQL = ("'{src}' AS DW_SOURCE_SYSTEM,\n"
             "CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_LOAD_TS,\n"
             "CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_UPDATE_TS,\n"
             "'gate' AS DW_BATCH_ID")


def gold_ddl_columns(table):
    s = io.open(GOLD_DDL, encoding='utf-8').read()
    pat = rf'CREATE\s+OR\s+REPLACE\s+TABLE\s+GN_DW\.GOLD\.{table}\s*\('
    m = re.search(pat, s)
    if not m:
        return None
    i = m.start()
    j = s.index('\n) COMMENT =', i)
    out = []
    for line in s[i:j].split('\n')[1:]:
        t = line.strip()
        if not t or t.startswith('--') or t.startswith('PRIMARY KEY') or t.startswith(')'):
            continue
        m_col = re.match(r'([A-Z0-9_]+)\s+', t)
        if m_col:
            out.append(m_col.group(1))
    return out


def silver_ddl_columns(table):
    s = io.open(SILVER_DDL, encoding='utf-8').read()
    pat = rf'CREATE\s+(?:OR\s+REPLACE\s+|TABLE\s+IF\s+NOT\s+EXISTS\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?GN_DW\.SILVER\.{table}\s*\('
    m = re.search(pat, s)
    if not m:
        return None
    i = m.start()
    j = s.find('\n) COMMENT =', i)
    if j == -1:
        j = s.find('\n)\nCOMMENT =', i)
    out = []
    for line in s[i:j].split('\n')[1:]:
        t = line.strip()
        if not t or t.startswith('--') or t.startswith('PRIMARY KEY') or t.startswith(')'):
            continue
        m_col = re.match(r'([A-Z0-9_]+)\s+', t)
        if m_col:
            out.append(m_col.group(1))
    return out


_KNOWN_TABLES = None


def load_known_tables(cn):
    global _KNOWN_TABLES
    if _KNOWN_TABLES is None:
        cur = cn.cursor()
        cur.execute("select table_schema, table_name from GN_DW.INFORMATION_SCHEMA.TABLES where table_schema in ('GOLD', 'SILVER')")
        _KNOWN_TABLES = {(r[0], r[1]) for r in cur.fetchall()}


def resolve_ref(cn, name):
    load_known_tables(cn)
    if ('GOLD', name) in _KNOWN_TABLES:
        return f'GN_DW.GOLD.{name}'
    if ('SILVER', name) in _KNOWN_TABLES:
        return f'GN_DW.SILVER.{name}'
    sys.exit(f'🔴 ref 해석 실패: {name} (GOLD·SILVER 어디에도 없다)')


def resolve_source(source_name, table_name):
    if source_name.lower() == 'silver_external':
        return f'GN_DW.SILVER.{table_name}'
    return f'GN_DW.{source_name.upper()}.{table_name}'


def render_model(cn, path, layer='GOLD'):
    s = io.open(path, encoding='utf-8').read()
    s = re.sub(r'\{#.*?#\}', '', s, flags=re.DOTALL)
    # Strip all config blocks
    s = re.sub(r'\{\{\s*config\s*\(.*?\)\s*\}\}', '', s, flags=re.DOTALL)
    # Strip jinja control blocks
    s = re.sub(r'\{%\s*if\s+is_incremental\(\)[^%]*%\}.*?\{%\s*endif\s*%\}', '', s, flags=re.DOTALL)
    s = re.sub(r'\{%-?\s*for\s+[^%]+%-?\}.*?\{%-?\s*endfor\s*%-?\}', "(EVENT_DATE between '20240101' and '20240102')", s, flags=re.DOTALL)
    s = re.sub(r'\{\{\s*\(modules\.datetime.*?\)\.days\s*\+\s*1\s*\}\}', '1000', s)
    s = re.sub(r"\{\{\s*var\(['\"]cal_start['\"]\)\s*\}\}", "2020-01-01", s)
    s = re.sub(r"\{\{\s*var\(['\"]cal_end['\"]\)\s*\}\}", "2030-12-31", s)
    s = re.sub(r"\{\{\s*gold_meta\('([A-Z0-9_]+)'\)\s*\}\}", lambda m: AUDIT_SQL.format(src=m.group(1)), s)
    s = re.sub(r"\{\{\s*ref\('([A-Z0-9_]+)'\)\s*\}\}", lambda m: resolve_ref(cn, m.group(1)), s)
    s = re.sub(r"\{\{\s*source\('([^']+)',\s*'([^']+)'\)\s*\}\}", lambda m: resolve_source(m.group(1), m.group(2)), s)
    s = re.sub(r"\{\{\s*clean_str\('([^']+)'\)\s*\}\}", lambda m: f"NULLIF(TRIM({m.group(1)}), '')", s)
    s = re.sub(r"\{\{\s*ga4_range_predicate\([^)]*\)\s*\}\}", '1=1', s)
    s = re.sub(r"\{\{\s*invocation_id\s*\}\}", 'gate_batch', s)

    def _arg(x):
        return x.strip().strip('\'"')

    s = re.sub(r'\{\{\s*month_key\(\s*\"([^\"]+)\"\s*\)\s*\}\}', lambda m: f"TRY_TO_NUMBER(TO_CHAR({m.group(1)}, 'YYYYMM'))", s)
    s = re.sub(r'\{\{\s*month_key\(\s*\'([^\']+)\'\s*\)\s*\}\}', lambda m: f"TRY_TO_NUMBER(TO_CHAR({m.group(1)}, 'YYYYMM'))", s)
    s = re.sub(r'\{\{\s*month_key\(\s*([A-Za-z0-9_\.]+)\s*\)\s*\}\}', lambda m: f"TRY_TO_NUMBER(TO_CHAR({m.group(1)}, 'YYYYMM'))", s)
    s = re.sub(r'\{\{\s*date_sk\(\s*\"([^\"]+)\"\s*\)\s*\}\}', lambda m: f"TRY_TO_NUMBER(TO_CHAR({m.group(1)}, 'YYYYMMDD'))", s)
    s = re.sub(r'\{\{\s*date_sk\(\s*\'([^\']+)\'\s*\)\s*\}\}', lambda m: f"TRY_TO_NUMBER(TO_CHAR({m.group(1)}, 'YYYYMMDD'))", s)
    s = re.sub(r'\{\{\s*date_sk\(\s*([A-Za-z0-9_\.]+)\s*\)\s*\}\}', lambda m: f"TRY_TO_NUMBER(TO_CHAR({m.group(1)}, 'YYYYMMDD'))", s)
    s = re.sub(r'\{\{\s*month_key_clamp\(\s*\"([^\"]+)\"\s*\)\s*\}\}', lambda m: f"({m.group(1)})", s)
    s = re.sub(r'\{\{\s*month_key_clamp\(\s*\'([^\']+)\'\s*\)\s*\}\}', lambda m: f"({m.group(1)})", s)
    s = re.sub(r'\{\{\s*month_key_offset\(\s*[\'\"]?([^\'\"]+)[\'\"]?\s*,\s*(-?\d+)\s*\)\s*\}\}', lambda m: f"({m.group(1)} + {m.group(2)})", s)

    def _gold_sk(m):
        raw = m.group(1)
        cols = []
        for item in re.split(r',(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)(?=(?:[^\']*\'[^\']*\')*[^\']*$)', raw):
            item = item.strip()
            if (item.startswith('\"\'') and item.endswith('\'\"')) or (item.startswith('\"') and item.endswith('\"')):
                cols.append(item.strip('\"'))
            elif item.startswith('\'') and item.endswith('\''):
                cols.append(item)
            else:
                cols.append(f"COALESCE(CAST({item} AS VARCHAR), '∅')")
        expr = " || '‖' || ".join(cols)
        return f"ABS(HASH({expr}))"

    s = re.sub(r"\{\{\s*gold_sk\(\[([^\]]*)\]\)\s*\}\}", _gold_sk, s)
    leftover = re.findall(r'\{\{[^}]*\}\}|\{%.*?%\}', s)
    if leftover:
        sys.exit(f'🔴 렌더되지 않은 jinja 가 남았다 in {path}: {leftover[:3]}')
    return s.strip().rstrip(';')


def model_columns(cn, path, layer='GOLD'):
    sql = render_model(cn, path, layer)
    cur = cn.cursor()
    cur.execute(f'select * from (\n{sql}\n) limit 0')
    return [d[0] for d in cur.description]


def self_check(cn):
    """게이트 탐지력 실증(P106)"""
    print('게이트 자기검사 (P106 — 탐지력 실증)\n')
    table = 'DIM_MONTH'
    p = '/workspace/10_dbt_pipeline/models/gold/dim/DIM_MONTH.sql'
    base_d = gold_ddl_columns(table)
    base_m = model_columns(cn, p, 'GOLD')
    swapped = base_d[:]
    swapped[1], swapped[2] = swapped[2], swapped[1]
    cases = [
        ('정상(대조군)',   base_d,                    []),
        ('DDL 에만 1건',   base_d + ['GHOST_COL'],     ['누락']),
        ('모델에만 1건',   [c for c in base_d if c != 'QUARTER'], ['초과']),
        ('순서만 어긋남',  swapped,                    ['순서']),
    ]
    ok = 0
    for label, d, expect in cases:
        missing = [c for c in d if c not in base_m]
        extra = [c for c in base_m if c not in d]
        got = ([] + (['누락'] if missing else []) + (['초과'] if extra else [])
               + (['순서'] if d != base_m and not missing and not extra else []))
        hit = sorted(set(got)) == sorted(set(expect))
        ok += hit
        print(f"  {label:<16} 기대={expect or '없음'} 실제={got or '없음'} {'✅' if hit else '🔴'}")
    print(f"\n자기검사 {ok}/{len(cases)} 일치")
    if ok != len(cases):
        sys.exit('🔴 게이트가 기대대로 탐지하지 못한다')

    print('\nseverity 매핑 자기검사 (강등이 무력화가 아님을 단정)')
    sev_cases = [
        ('누락 → blocking', base_d + ['GHOST_COL'], True),
        ('초과 → blocking', [c for c in base_d if c != 'QUARTER'], True),
        ('순서만 → advisory(blocking 아님)', swapped, False),
        ('정상 → blocking 아님', base_d, False),
    ]
    sok = 0
    for label, d, want_block in sev_cases:
        missing = [c for c in d if c not in base_m]
        extra = [c for c in base_m if c not in d]
        got_block = bool(missing or extra)
        hit = (got_block == want_block)
        sok += hit
        print(f"  {label:<34} blocking 기대={want_block} 실제={got_block} {'✅' if hit else '🔴'}")
    print(f"\nseverity 자기검사 {sok}/{len(sev_cases)} 일치")
    if sok != len(sev_cases):
        sys.exit('🔴 severity 매핑이 어긋난다 — 강등이 진짜 위험까지 껐을 수 있다')


def main():
    cn = sfconn.conn()
    cn.cursor().execute('USE WAREHOUSE GN_DW_DEV_WH')
    load_known_tables(cn)

    if '--self-check' in sys.argv:
        self_check(cn)
        cn.close()
        return

    fails = 0
    drift = 0

    gold_tables = re.findall(r'CREATE OR REPLACE TABLE GN_DW\.GOLD\.([A-Z0-9_]+)', io.open(GOLD_DDL, encoding='utf-8').read())
    gold_model_files = {p.stem: p for p in Path('/workspace/10_dbt_pipeline/models/gold').glob('**/*.sql')}

    silver_models = sorted(list(Path('/workspace/10_dbt_pipeline/models/silver').glob('**/*.sql')))

    print('DDL 선언 ↔ dbt 모델 출력 컬럼 대조 (적재 전 판정 · P120 · GOLD 37 + SILVER 42 전수)')
    print('  🔴 blocking = **집합** 불일치(누락·초과) · 🟠 advisory = **순서** 드리프트(문서 축)\n')

    print(f'=== [GOLD 계층: {len(gold_tables)} 테이블] ===')
    for tbl in gold_tables:
        if tbl not in gold_model_files:
            print(f'  {tbl:<28} 🔴 Model file not found')
            fails += 1
            continue
        p = gold_model_files[tbl]
        d = gold_ddl_columns(tbl)
        m = model_columns(cn, p, 'GOLD')
        missing = [c for c in d if c not in m]
        extra = [c for c in m if c not in d]
        order_ok = (d == m)
        blocking = bool(missing or extra)
        fails += blocking
        drift += (not order_ok)
        mism = [] if order_ok else [f'{k+1}:{a}≠{b}' for k, (a, b) in enumerate(zip(d, m)) if a != b][:5]
        status = '🔴' if blocking else ('🟠' if not order_ok else '✅')
        print(f"  {tbl:<28} DDL {len(d):>2} · 모델 {len(m):>2} · 누락 {len(missing)} · 초과 {len(extra)} · 순서 {'일치' if order_ok else '불일치'} {status}")
        if missing:
            print(f"     🔴 DDL 에만(모델이 채우지 않는다): {', '.join(missing)}")
        if extra:
            print(f"     🔴 모델에만(물리가 정본보다 앞서 나간다): {', '.join(extra)}")
        if mism:
            print(f"     🟠 순서 드리프트(앞 5건): {', '.join(mism)}")

    print(f'\n=== [SILVER 계층: {len(silver_models)} 테이블] ===')
    for p in silver_models:
        tbl = p.stem
        d = silver_ddl_columns(tbl)
        if d is None:
            print(f'  {tbl:<28} 🔴 DDL block not found')
            fails += 1
            continue
        m = model_columns(cn, p, 'SILVER')
        missing = [c for c in d if c not in m]
        extra = [c for c in m if c not in d]
        order_ok = (d == m)
        blocking = bool(missing or extra)
        fails += blocking
        drift += (not order_ok)
        mism = [] if order_ok else [f'{k+1}:{a}≠{b}' for k, (a, b) in enumerate(zip(d, m)) if a != b][:5]
        status = '🔴' if blocking else ('🟠' if not order_ok else '✅')
        print(f"  {tbl:<28} DDL {len(d):>2} · 모델 {len(m):>2} · 누락 {len(missing)} · 초과 {len(extra)} · 순서 {'일치' if order_ok else '불일치'} {status}")
        if missing:
            print(f"     🔴 DDL 에만(모델이 채우지 않는다): {', '.join(missing)}")
        if extra:
            print(f"     🔴 모델에만(물리가 정본보다 앞서 나간다): {', '.join(extra)}")
        if mism:
            print(f"     🟠 순서 드리프트(앞 5건): {', '.join(mism)}")

    tot_targets = len(gold_tables) + len(silver_models)
    print()
    print(f'집합 불일치(blocking) {fails}건 · 순서 드리프트(advisory) {drift}건 / 대상 {tot_targets}개 (GOLD {len(gold_tables)} + SILVER {len(silver_models)})')
    cn.close()

    if fails:
        sys.exit(f'🔴 {fails}/{tot_targets} 객체 **집합** 불일치 — 모델이 컬럼을 채우지 않거나 '
                 f'물리가 정본을 앞서 나갔다. 적재 전에 정본을 맞출 것.')
    if drift:
        print(f'🟠 순서 드리프트 {drift}건 — **문서 축이며 적재 위험이 아니다**(종료코드 무영향).')
        print('   🔴 다만 「파일이 정본」 주장은 약해진다 ⇒ DDL 파일 선언 순서를 모델에 맞출 것.')
    print(f'✅ 집합 일치 {tot_targets}/{tot_targets} — 적재 안전')


if __name__ == '__main__':
    main()
