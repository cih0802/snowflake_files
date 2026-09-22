#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""O63-K 전파 — `06_DDL.sql` 의 교정 문안을 라이브 컬럼 COMMENT 에 반영한다.

파일이 정본이므로 **파일 → 라이브** 방향만 수행한다(P223: 방향을 잘못 잡으면 결함을 재생산한다).
대상은 `comment_drift_gate.py --surface table` 이 지목한 불일치 컬럼뿐이다 — 손으로 고르지 않는다.
판정은 반영 후 같은 게이트 재실행(불일치 0)으로 낸다.

🔴🔴 [O178 · `O176-A-3 ㉧` 시정] **dry-run 을 기본값으로 만들었다.**
  종전 결함 = `argparse` 가 없어서 **인자를 무엇으로 주든 즉시 라이브 `ALTER` 를 집행**했다.
  `--help` 로 사용법을 보려 해도 집행됐다(O176 이 인수인계 환경함정에 적었으나 구현은 그대로였다).
  🔴 이 도구는 `gate_census` 분류가 **`MUTATES`** 다 — 「승인 대상」으로 등재해 두고
     정작 **집행을 멈출 수단이 없는** 상태였다. 등재와 구현이 어긋난 것이다.
  🟢 처방 = ㉠ `--apply` 없이는 **아무것도 바꾸지 않는다** ㉡ `--help`/`-h` 는 문서만 출력한다
     ㉢ dry-run 이 **실행할 SQL 전문을 그대로 보여준다**(사전 검토 가능).

사용법
    python3 scripts/apply_table_comment_drift.py            # dry-run (기본 · 라이브 무변경)
    python3 scripts/apply_table_comment_drift.py --apply    # 🔴 실제 ALTER (R4-4-3 승인 대상)
    python3 scripts/apply_table_comment_drift.py --help     # 이 문서만 출력(집행하지 않는다)

종료코드 = 0 성공/무변경 · 1 실패 · 2 사용법 오류.
Co-authored with CoCo
"""
import argparse
import sys

sys.path.insert(0, '/workspace/scripts')
import comment_drift_gate as g  # noqa: E402
import sfconn  # noqa: E402


def build_todo(cn):
    """반영 대상 = 파일(정본)과 라이브가 다른 컬럼. 🔴 손으로 고르지 않는다."""
    want = g.parse_ddl()
    got = g.live(cn, "'BASE TABLE'")
    todo = [k for k, v in sorted(want.items())
            if k in got and g.sha(v) != g.sha(got[k])]
    return want, todo


def stmt_for(tbl, col, text):
    lit = text.replace("'", "''")
    return ("ALTER TABLE GN_DW.GOLD.%s ALTER COLUMN %s COMMENT '%s'"
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

        print('대상 %d컬럼: %s' % (len(todo), ', '.join(todo)))
        if not a.apply:
            # 🟢 dry-run 은 **실행할 SQL 전문**을 낸다 — 승인자가 눈으로 검토할 수 있어야 한다.
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
        print('🟢 %d컬럼 ALTER 완료 — 판정은 comment_drift_gate 재실행으로 낸다' % len(todo))
        return 0
    finally:
        cn.close()


if __name__ == '__main__':
    sys.exit(main())
