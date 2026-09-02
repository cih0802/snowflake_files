# -*- coding: utf-8 -*-
"""
scripts/apply_silver_comment_drift.py
08_SILVER_테이블DDL_20260714.sql 의 컬럼 COMMENT 를 SILVER Live DB 에 반영합니다.
"""
import sys

sys.path.insert(0, '/workspace/scripts')
import comment_drift_gate as g
import sfconn

def main():
    want = g.parse_ddl(path=g.SILVER_DDL, rx=g.RE_SILVER)
    cn = sfconn.conn()
    try:
        got = g.live(cn, "'BASE TABLE'", schema='SILVER')
        todo = [k for k, v in sorted(want.items())
                if k in got and g.sha(v) != g.sha(got[k])]
        if not todo:
            print('🟢 불일치 0 — 반영할 것이 없다')
            return
        print(f'SILVER 대상 {len(todo)}컬럼: {", ".join(todo[:20])} ...')
        cur = cn.cursor()
        for key in todo:
            tbl, col = key.split('.', 1)
            lit = want[key].replace("'", "''")
            cur.execute(f"ALTER TABLE GN_DW.SILVER.{tbl} "
                        f"ALTER COLUMN {col} COMMENT '{lit}'")
        print(f'🟢 SILVER {len(todo)}컬럼 ALTER 완료')
    finally:
        cn.close()

if __name__ == '__main__':
    main()
