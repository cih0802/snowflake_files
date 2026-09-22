#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SILVER 컬럼 COMMENT 전파 — `08_SILVER_테이블DDL_20260714.sql` 을 라이브에 반영한다.

파일이 정본이므로 **파일 → 라이브** 방향만 수행한다(`P223`).
대상은 `comment_drift_gate` 가 지목한 불일치 컬럼뿐이다 — 손으로 고르지 않는다.

🔴🔴 [O178] **`apply_table_comment_drift.py` 의 쌍둥이다 — 같은 시정을 동시에 적용했다.**
  종전 결함 = `argparse` 가 없어 **인자를 무엇으로 주든 즉시 라이브 `ALTER`** 를 냈다.
  🔴 O176 이 GOLD 쪽(`㉧`)만 적발했고 이 SILVER 쪽은 **아무도 보지 않았다** —
     「같은 것을 다르게 재는 지점」이 쌍으로 있으면 한쪽만 고치는 결함이 반복된다(`R1-6-17`).
  🟢 처방 = ㉠ `--apply` 없이는 무변경 ㉡ `--help` 는 문서만 ㉢ dry-run 이 SQL 전문을 보여준다.
  ⚠️ SILVER 는 대상 컬럼이 많을 수 있다 ⇒ dry-run 은 전문을 **전건** 출력한다(승인 검토용).

사용법
    python3 scripts/apply_silver_comment_drift.py            # dry-run (기본 · 라이브 무변경)
    python3 scripts/apply_silver_comment_drift.py --apply    # 🔴 실제 ALTER (R4-4-3 승인 대상)
    python3 scripts/apply_silver_comment_drift.py --help     # 이 문서만 출력(집행하지 않는다)

종료코드 = 0 성공/무변경 · 1 실패 · 2 사용법 오류.
Co-authored with CoCo
"""
import argparse
import sys

sys.path.insert(0, '/workspace/scripts')
import comment_drift_gate as g  # noqa: E402
import sfconn  # noqa: E402


def build_todo(cn):
    want = g.parse_ddl(path=g.SILVER_DDL, rx=g.RE_SILVER)
    got = g.live(cn, "'BASE TABLE'", schema='SILVER')
    todo = [k for k, v in sorted(want.items())
            if k in got and g.sha(v) != g.sha(got[k])]
    return want, todo


def stmt_for(tbl, col, text):
    lit = text.replace("'", "''")
    return ("ALTER TABLE GN_DW.SILVER.%s ALTER COLUMN %s COMMENT '%s'"
            % (tbl, col, lit))


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('--apply', action='store_true',
                    help='실제 ALTER 를 집행한다(기본은 dry-run)')
    ap.add_argument('-h', '--help', action='store_true')
    try:
        a = ap.parse_args()
    except SystemExit:
        print(__doc__)
        return 2
    if a.help:
        print(__doc__)
        return 0

    cn = sfconn.conn()
    try:
        want, todo = build_todo(cn)
        if not todo:
            print('🟢 불일치 0 — 반영할 것이 없다')
            return 0

        print('SILVER 대상 %d컬럼' % len(todo))
        if not a.apply:
            print('')
            print('🟡 DRY-RUN — 라이브를 바꾸지 않았다. 아래가 `--apply` 시 실행될 전문이다.')
            for key in todo:
                tbl, col = key.split('.', 1)
                print('  ' + stmt_for(tbl, col, want[key]))
            print('')
            print('🔴 집행하려면 `--apply` 를 주어라(`R4-4-3` 별도 승인 대상).')
            return 0

        cur = cn.cursor()
        for key in todo:
            tbl, col = key.split('.', 1)
            cur.execute(stmt_for(tbl, col, want[key]))
        print('🟢 SILVER %d컬럼 ALTER 완료 — 판정은 comment_drift_gate 재실행으로 낸다'
              % len(todo))
        return 0
    finally:
        cn.close()


if __name__ == '__main__':
    sys.exit(main())
