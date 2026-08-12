#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O63-K 전파 — `06_DDL.sql` 의 교정 문안을 라이브 컬럼 COMMENT 에 반영한다.

파일이 정본이므로 **파일 → 라이브** 방향만 수행한다(P223: 방향을 잘못 잡으면 결함을 재생산한다).
대상은 `comment_drift_gate.py --surface table` 이 지목한 불일치 컬럼뿐이다 — 손으로 고르지 않는다.
판정은 반영 후 같은 게이트 재실행(불일치 0)으로 낸다.
Co-authored with CoCo
"""
import sys

sys.path.insert(0, '/workspace/scripts')
import comment_drift_gate as g  # noqa: E402
import sfconn  # noqa: E402


def main():
    want = g.parse_ddl()
    cn = sfconn.conn()
    try:
        got = g.live(cn, "'BASE TABLE'")
        todo = [k for k, v in sorted(want.items())
                if k in got and g.sha(v) != g.sha(got[k])]
        if not todo:
            print('🟢 불일치 0 — 반영할 것이 없다')
            return
        print(f'대상 {len(todo)}컬럼: {", ".join(todo)}')
        cur = cn.cursor()
        for key in todo:
            tbl, col = key.split('.', 1)
            lit = want[key].replace("'", "''")
            cur.execute(f"ALTER TABLE GN_DW.GOLD.{tbl} "
                        f"ALTER COLUMN {col} COMMENT '{lit}'")
        print(f'🟢 {len(todo)}컬럼 ALTER 완료 — 판정은 comment_drift_gate 재실행으로 낸다')
    finally:
        cn.close()


if __name__ == '__main__':
    main()
