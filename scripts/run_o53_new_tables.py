#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
O53 2단계 — `06_DDL.sql` 의 **신규 4블록만** 실행한다.
Co-authored with CoCo

⛔ 왜 전용 러너인가
   `06_DDL.sql` 은 전량 `CREATE OR REPLACE TABLE` 이다. 이미 적재된 환경에서 전체를 실행하면
   기존 31테이블의 **데이터가 사라진다**(런북 §11 경고). 그래서 대상 테이블명을 화이트리스트로
   못박고 그 블록만 뽑아 실행한다. 화이트리스트 밖 문장은 **한 건도 실행하지 않는다.**

🔴 뷰 → 테이블 전환의 선행 DROP
   Snowflake 는 같은 이름공간을 쓰므로 뷰가 존재하는 이름으로 `CREATE OR REPLACE TABLE` 을 하면
   실패한다. 전환 대상 3종(DIM_MEMBER_CURRENT·DIM_MEMBER_ACQUISITION·WIDE_DEV_ACHIEVEMENT)은
   `DROP VIEW` 를 먼저 한다. 뷰는 물리 저장이 0 이고 dbt 가 정의를 소유하므로 소실되는 것은 없다.
   ⚠️ WIDE_DEV_ACHIEVEMENT 는 SV_DEV_ACHIEVEMENT 의 base 다 — DROP 시점부터 그 SV 는 깨진다.
      복구는 O53 6단계(`CREATE OR ALTER SEMANTIC VIEW` + GRANT 소비역할 판정). 계획된 순서다.

검증(실행 후 자동)
   · 4테이블 존재 · 컬럼수 = 06_DDL 선언과 일치 · 컬럼 COMMENT 100%
   · PK 선언 존재
   · 소비 역할 SELECT 권한(future grant 적용 여부) — 소유자 세션의 성공은 근거가 아니다(P126)
"""
import io
import re
import sys

sys.path.insert(0, '/workspace/scripts')
import sfconn  # noqa: E402

DDL_PATH = '/workspace/03_top-down_gold/06_DDL.sql'
TARGETS = ['DIM_MONTH', 'DIM_MEMBER_CURRENT', 'DIM_MEMBER_ACQUISITION', 'FACT_DEV_ACHIEVEMENT']
DROP_VIEWS = ['DIM_MEMBER_CURRENT', 'DIM_MEMBER_ACQUISITION', 'WIDE_DEV_ACHIEVEMENT']
EXPECT_COLS = {'DIM_MONTH': 8, 'DIM_MEMBER_CURRENT': 24,
               'DIM_MEMBER_ACQUISITION': 29, 'FACT_DEV_ACHIEVEMENT': 23}
CONSUMER_ROLES = ['GN_DW_ANALYST', 'GN_DW_VIEWER', 'GN_DW_SERVICE']


def extract(sql_text, table):
    """해당 테이블의 CREATE 문 하나만 정확히 잘라낸다(주석 제거 · 세미콜론까지)."""
    head = f'CREATE OR REPLACE TABLE GN_DW.GOLD.{table} ('
    i = sql_text.index(head)
    j = sql_text.index(';', i)
    body = sql_text[i:j + 1]
    lines = [l for l in body.split('\n') if not l.strip().startswith('--')]
    return '\n'.join(lines)


def main():
    apply = '--apply' in sys.argv
    text = io.open(DDL_PATH, encoding='utf-8').read()

    stmts = []
    for t in DROP_VIEWS:
        stmts.append((f'DROP VIEW  GOLD.{t}', f'DROP VIEW IF EXISTS GN_DW.GOLD.{t}'))
    for t in TARGETS:
        s = extract(text, t)
        # 안전장치: 화이트리스트 테이블 외 이름이 섞였는지 확인
        others = [m for m in re.findall(r'CREATE OR REPLACE TABLE GN_DW\.GOLD\.(\w+)', s) if m != t]
        assert not others, f'🔴 블록 경계 오류 — {t} 문장에 {others} 가 섞였다'
        stmts.append((f'CREATE     GOLD.{t}', s))

    print(f'대상 문장 {len(stmts)}건 (DROP VIEW {len(DROP_VIEWS)} + CREATE TABLE {len(TARGETS)})')
    print(f'⛔ 06_DDL.sql 전체 {text.count("CREATE OR REPLACE TABLE GN_DW.GOLD.")}블록 중 '
          f'{len(TARGETS)}블록만 실행한다\n')
    if not apply:
        for label, s in stmts:
            print(f'  [dry-run] {label:<34} {len(s):>6}B')
        print('\n실행하려면 --apply')
        return

    cn = sfconn.conn()
    cur = cn.cursor()
    cur.execute('USE ROLE GN_DW_ADMIN')          # 소유주 = GN_DW_ADMIN (기존 31테이블과 동일)
    cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
    err = 0
    for label, s in stmts:
        try:
            cur.execute(s)
            print(f'  OK  | {label}')
        except Exception as e:
            err += 1
            print(f'  ERR | {label}\n        ↳ {e}')
    if err:
        cn.close()
        sys.exit(f'🔴 {err}건 실패 — 검증 생략')

    # ── 검증 ──────────────────────────────────────────────────────────────────
    print('\n검증(실측):')
    names = "','".join(TARGETS)
    cur.execute(f"""
        select table_name, count(*) cols, count(comment) commented
        from GN_DW.INFORMATION_SCHEMA.COLUMNS
        where table_schema='GOLD' and table_name in ('{names}')
        group by 1 order by 1""")
    rows = cur.fetchall()
    ok = True
    for name, cols, commented in rows:
        exp = EXPECT_COLS[name]
        good = (cols == exp and commented == cols)
        ok &= good
        print(f"  {name:<24} 컬럼 {cols:>2}/{exp} · COMMENT {commented:>2}/{cols} "
              f"{'✅' if good else '🔴'}")
    if len(rows) != len(TARGETS):
        ok = False
        print(f'  🔴 테이블 {len(rows)}/{len(TARGETS)} 만 존재')

    cur.execute("""select table_type, count(distinct table_name)
                   from GN_DW.INFORMATION_SCHEMA.TABLES
                   where table_schema='GOLD' group by 1 order by 1""")
    for tt, n in cur.fetchall():
        print(f"  GOLD {tt:<12} {n}")

    print('\n  소비 역할 SELECT 권한(P126 — future grant 실제 적용 확인):')
    for t in TARGETS:
        cur.execute(f'show grants on table GN_DW.GOLD.{t}')
        g = cur.fetchall()
        cols = [c[0] for c in cur.description]
        gi, pi, ri = cols.index('grantee_name'), cols.index('privilege'), cols.index('granted_to')
        have = {r[gi] for r in g if r[pi] == 'SELECT' and r[ri] == 'ROLE'}
        miss = [r for r in CONSUMER_ROLES if r not in have]
        ok &= not miss
        print(f"    {t:<24} SELECT 보유 {sorted(have)} {'✅' if not miss else '🔴 누락 ' + str(miss)}")

    cn.close()
    print('\n' + ('✅ 2단계 검증 통과' if ok else '🔴 2단계 검증 실패'))
    if not ok:
        sys.exit(1)


if __name__ == '__main__':
    main()
