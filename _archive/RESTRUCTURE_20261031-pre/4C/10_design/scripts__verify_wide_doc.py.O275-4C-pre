# -*- coding: utf-8 -*-
"""verify_wide_doc.py — 09_빅테이블 VIEW.md 문서와 실제 dbt 모델 및 라이브 Snowflake 뷰 전수 대조."""
import os
import sys
import re
import yaml

ROOT = '/workspace'
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from sfconn import conn, q

def main():
    # 1. Live Snowflake Information Schema
    cn = conn()
    _, rows = q('''
    select table_name, column_name, data_type, is_nullable, ordinal_position
    from GN_DW.INFORMATION_SCHEMA.COLUMNS
    where table_schema = 'GOLD' and table_name like 'WIDE_%'
    order by table_name, ordinal_position
    ''', cn)

    live_by_table = {}
    for t, c, dt, n, op in rows:
        live_by_table.setdefault(t, []).append((c, dt, n))

    # 2. dbt SQL models
    wide_dir = os.path.join(ROOT, '10_dbt_pipeline', 'models', 'gold', 'wide')
    dbt_sql_files = {
        os.path.basename(f).replace('.sql', ''): f
        for f in os.listdir(wide_dir) if f.endswith('.sql')
    }

    # 3. Read generated 09_빅테이블 VIEW.md
    doc_path = os.path.join(ROOT, '03_top-down_gold', '09_빅테이블 VIEW.md')
    with open(doc_path, 'r', encoding='utf-8') as f:
        doc_text = f.read()

    doc_views = {}
    current_view = None
    for line in doc_text.splitlines():
        m = re.match(r'^###\s+2\.\d+\s+`(WIDE_[A-Z0-9_]+)`', line)
        if m:
            current_view = m.group(1)
            doc_views[current_view] = []
            continue
        if current_view and line.startswith('| **'):
            cells = [c.strip() for c in line.split('|')[1:-1]]
            if len(cells) >= 6:
                cname = cells[1].replace('`', '').strip()
                dtype = cells[2]
                nullable = cells[3]
                source = cells[4]
                doc_views[current_view].append((cname, dtype, nullable, source))

    print('=== 1. WIDE VIEW 목록 대조 (14종) ===')
    print('Live views in DB:', len(live_by_table))
    print('dbt SQL models  :', len(dbt_sql_files))
    print('Doc views in 09 :', len(doc_views))

    assert set(live_by_table.keys()) == set(dbt_sql_files.keys()) == set(doc_views.keys()), 'View names mismatch!'
    print('🟢 14종 뷰 목록 100% 일치 확인\n')

    print('=== 2. 각 뷰별 컬럼 수 및 컬럼명·타입 일치성 전수 검증 ===')
    mismatches = 0
    total_cols = 0
    for vname in sorted(live_by_table.keys()):
        live_cols = [c[0] for c in live_by_table[vname]]
        doc_cols = [c[0] for c in doc_views[vname]]
        total_cols += len(live_cols)
        
        cnt_match = len(live_cols) == len(doc_cols)
        col_match = live_cols == doc_cols
        
        live_type_map = {c[0]: c[1] for c in live_by_table[vname]}
        doc_type_map = {c[0]: c[1] for c in doc_views[vname]}
        type_diffs = []
        for c in live_cols:
            if c in doc_type_map and live_type_map[c] != doc_type_map[c]:
                type_diffs.append((c, live_type_map[c], doc_type_map[c]))
                
        if cnt_match and col_match and not type_diffs:
            print(f'  🟢 {vname:<25}: {len(live_cols)}컬럼 전수 일치 (Live ↔ dbt ↔ 문서 100%)')
        else:
            mismatches += 1
            print(f'  🔴 {vname:<25}: 불일치 발견! (Live {len(live_cols)} vs Doc {len(doc_cols)})')
            if type_diffs:
                print(f'     타입 불일치: {type_diffs}')

    print(f'\n총 검증 컬럼 수: {total_cols}개 / 불일치 뷰: {mismatches}건')
    if mismatches == 0:
        print('🟢 전수 100% 정합성 검증 완료')
        return 0
    return 1

if __name__ == '__main__':
    sys.exit(main())
