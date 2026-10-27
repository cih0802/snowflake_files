#!/usr/bin/env python3
"""30번 산출물 운영계 실측용 근거 SQL 생성 — `30_output_share/_근거쿼리/S30_census.sql`

🔴 분류 = `GEN`. 산출물은 자동 생성물이다 — 손으로 고치지 말고 이 스크립트를 다시 돌린다.

목적
    30번 산출물(03 개념도 · 04/05/08/09)의 0행·전건 NULL·전건 0 판정은 `scripts/census_columns.py`
    (`/tmp/census.json`) 실측에서 나온다. 그 스크립트는 접속 계정에서만 돈다 ⇒ 운영계(ZL50263) 수치는
    85번과 같은 방식(`-- Qnn` 읽기 전용 SQL → `env_capture.py` → `_ENV/<계정>/` csv)으로 가져온다.

사용법(개발계에서 생성 → 운영계에서 실행)
    python3 scripts/gen_s30_census_sql.py            # 개발계 카탈로그 기준으로 SQL 생성
    # 운영계 워크스페이스에서:
    python3 scripts/env_capture.py --id S30 --out-root "30_output_share/_ENV" "30_output_share/_근거쿼리/S30_census.sql"
    python3 scripts/s30_census_to_json.py ZL50263    # csv → census json + 개발계 대조표

블록 구성
    Q01 = 전 계층 테이블 목록·행수(INFORMATION_SCHEMA · 실행 계정 기준이라 운영계에만 있는 테이블도 잡힌다)
    Q02 = census 대상 컬럼 목록·타입(운영계 타입으로 판정하려고 받는다)
    Q03~ = 테이블별 컬럼 census 1문장 — 결과를 FLATTEN 으로 세로(컬럼 1행)로 펴서 csv 한 줄 1900자 규약을 지킨다.
           운영계에 없는 테이블/컬럼은 그 문장만 ERROR 로 manifest 에 남고 나머지는 계속 돈다.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn, q  # noqa: E402

WS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(WS, '30_output_share', '_근거쿼리', 'S30_census.sql')
CENSUS_SCHEMAS = ('GOLD', 'SILVER', 'SERVING')  # census_columns.py 와 동일 범위
ALL_SCHEMAS = ('BRONZE_CRM', 'BRONZE_AGENCY', 'BRONZE_ERP', 'BRONZE_BIGQUERY', 'BRONZE_GA4', 'BRONZE_GSC',
               'SILVER', 'GOLD', 'SERVING')
# census_columns.py 의 NZ 판정과 같은 규칙
NUMT = {'NUMBER', 'FLOAT', 'DECIMAL', 'INT', 'INTEGER', 'BIGINT', 'DOUBLE', 'REAL'}
TEXTT = {'TEXT', 'VARCHAR', 'STRING', 'CHAR'}


def nz_expr(qc, dt):
    if dt in NUMT:
        return 'COUNT_IF(%s <> 0)' % qc
    if dt == 'BOOLEAN':
        return 'COUNT_IF(%s)' % qc
    if dt in TEXTT:
        return "COUNT_IF(%s IS NOT NULL AND %s <> '')" % (qc, qc)
    return 'COUNT(%s)' % qc


def sql_lit(s):
    return "'" + s.replace("'", "''") + "'"


def table_stmt(s, t, cols):
    agg = ['COUNT(*) AS R']
    obj = []
    for i, (c, dt) in enumerate(cols, 1):
        qc = '"%s"' % c.replace('"', '""')
        agg.append('COUNT(%s) AS NN%d, %s AS NZ%d, APPROX_COUNT_DISTINCT(%s) AS DC%d' % (qc, i, nz_expr(qc, dt), i, qc, i))
        obj.append('%s, ARRAY_CONSTRUCT(NN%d, NZ%d, DC%d)' % (sql_lit(c), i, i, i))
    return ('WITH a AS (SELECT %s FROM GN_DW.%s."%s")\n'
            "SELECT %s AS TABLE_SCHEMA, %s AS TABLE_NAME, a.R AS ROWS_, f.key AS COLUMN_NAME,\n"
            '       f.value[0]::NUMBER AS NONNULL, f.value[1]::NUMBER AS NONZERO, f.value[2]::NUMBER AS NDV\n'
            'FROM a, LATERAL FLATTEN(INPUT => OBJECT_CONSTRUCT_KEEP_NULL(%s)) f ORDER BY f.index;'
            % (', '.join(agg), s, t, sql_lit(s), sql_lit(t), ', '.join(obj)))


def main():
    cn = conn()
    _, trows = q("""select table_schema, table_name from GN_DW.INFORMATION_SCHEMA.TABLES
                    where table_type = 'BASE TABLE' and table_schema in (%s)
                    order by 1, 2""" % ','.join(sql_lit(s) for s in CENSUS_SCHEMAS), cn)
    _, crows = q("""select table_schema, table_name, column_name, data_type
                    from GN_DW.INFORMATION_SCHEMA.COLUMNS where table_schema in (%s)
                    order by table_schema, table_name, ordinal_position""" % ','.join(sql_lit(s) for s in CENSUS_SCHEMAS), cn)
    _, acct = q('select current_account(), current_date()::string', cn)
    cn.close()

    cols = {}
    for s, t, c, dt in crows:
        cols.setdefault((s, t), []).append((c, dt))

    sch_in = ','.join(sql_lit(s) for s in ALL_SCHEMAS)
    cen_in = ','.join(sql_lit(s) for s in CENSUS_SCHEMAS)
    lines = [
        '-- doc_id: S30 · 30번 산출물 운영계 실측 근거(읽기 전용) · 생성기 = scripts/gen_s30_census_sql.py',
        '-- 생성 기준 = %s 카탈로그 %s · census 대상 %d 테이블 · 손으로 고치지 않는다' % (acct[0][0], acct[0][1], len(trows)),
        '-- 실행 = python3 scripts/env_capture.py --id S30 --out-root "30_output_share/_ENV" "30_output_share/_근거쿼리/S30_census.sql"',
        '-- Q01 전 계층 테이블 목록·행수',
        "SELECT table_schema, table_name, table_type, row_count, last_altered FROM GN_DW.INFORMATION_SCHEMA.TABLES "
        "WHERE table_schema IN (%s) ORDER BY 1, 2;" % sch_in,
        '-- Q02 census 대상 컬럼 목록·타입',
        "SELECT table_schema, table_name, column_name, data_type, ordinal_position FROM GN_DW.INFORMATION_SCHEMA.COLUMNS "
        "WHERE table_schema IN (%s) ORDER BY 1, 2, 5;" % cen_in,
    ]
    n = 3
    for s, t in trows:
        cl = cols.get((s, t))
        if not cl:
            continue
        lines.append('-- Q%02d census %s.%s' % (n, s, t))
        lines.append(table_stmt(s, t, cl))
        n += 1

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print('🟢 %s · Q01~Q%02d (census %d 테이블)' % (os.path.relpath(OUT, WS), n - 1, n - 3))
    return 0


if __name__ == '__main__':
    sys.exit(main())
