# -*- coding: utf-8 -*-
"""100% 전건 NULL 컬럼 검출 스크립트.
GN_DW.GOLD 및 GN_DW.SILVER 스키마의 모든 BASE TABLE 및 VIEW를 전수 조사하여
비NULL 건수가 0 (100% NULL)인 컬럼을 검출한다.
"""
import io, os, sys, json
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn, q

def main():
    cn = conn()
    print("Snowflake 연결 완료. 스키마 컬럼 메타데이터 조회 중...")
    
    # 1. 대상 테이블/뷰 및 컬럼 목록 조회
    sql_cols = """
    SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, COMMENT
    FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA IN ('GOLD', 'SILVER')
    ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
    """
    _, cols_rows = q(sql_cols, cn)
    
    tables_map = {}
    for schema, tbl, col, dtype, comment in cols_rows:
        key = (schema, tbl)
        if key not in tables_map:
            tables_map[key] = []
        tables_map[key].append((col, dtype, comment))
    
    print(f"대상 테이블/뷰 총 {len(tables_map)}개, 총 컬럼 수 {len(cols_rows)}개.")
    
    results = []
    
    # 2. 각 테이블별로 1개 쿼리로 COUNT(*) 및 각 컬럼 COUNT("COL") 집계
    for (schema, tbl), cols in tables_map.items():
        col_names = [c[0] for c in cols]
        # Build SELECT COUNT(*) as TOTAL_ROWS, COUNT("c1") as c1, COUNT("c2") as c2 ...
        select_exprs = ['COUNT(*) AS __TOTAL_ROWS__']
        for cname in col_names:
            select_exprs.append(f'COUNT("{cname}") AS "{cname}"')
        
        sql_scan = f'SELECT {", ".join(select_exprs)} FROM GN_DW.{schema}."{tbl}"'
        try:
            _, scan_rows = q(sql_scan, cn)
            if not scan_rows:
                continue
            row = scan_rows[0]
            tot_rows = row[0]
            if tot_rows == 0:
                # 테이블 자체가 0행인 경우는 스킵 (전건 결손이 아닌 미적재)
                continue
            
            for idx, (cname, dtype, comment) in enumerate(cols):
                non_null_cnt = row[idx + 1]
                if non_null_cnt == 0:
                    results.append({
                        'schema': schema,
                        'table': tbl,
                        'column': cname,
                        'data_type': dtype,
                        'total_rows': tot_rows,
                        'non_null_count': non_null_cnt,
                        'comment': comment or ''
                    })
                    print(f"  [100% NULL] {schema}.{tbl}.{cname} ({tot_rows:,}행 중 0건) | COMMENT: {comment or '(없음)'}")
        except Exception as e:
            print(f"  [오류] {schema}.{tbl} 조회 실패: {e}")
            continue
            
    cn.close()
    
    out_file = '/workspace/12_agent개선과제/23_100pct_NULL_컬럼_검출목록.json'
    with io.open(out_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    
    print(f"\n검출 완료: 총 {len(results)}건의 100% NULL 컬럼 검출됨 -> {out_file}")

if __name__ == '__main__':
    main()
