# -*- coding: utf-8 -*-
"""[2026-08-11 O59-B] SV 차원 카디널리티 전수 실측 — §6.9-(5) 대상 모집단 확정용.

🔴 왜 필요한가: §6.9-(5)는 *"**저카디널리티** 코드 차원은 comment에 실제 코드값을 열거해야 한다"* 인데
   「저카디널리티」의 임계가 문서에 없다. 임계를 **추측해서 게이트를 만들면** 대상이 틀리고,
   그 게이트는 통과해도 아무것도 보장하지 않는다(P33 계열). ⇒ 분포를 먼저 실측해 임계를 정한다.

출력: (SV, 차원, base 컬럼, distinct 종수, 열거 유무) — 사람이 임계를 결정할 수 있는 형태.
"""
import sys, os, re, collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfconn import conn, q
from sv_code_label_gate import enumerated_values

DB, SC = 'GN_DW', 'SERVING'


def main():
    cn = conn()
    _, tabs = q(f"""select SEMANTIC_VIEW_NAME, NAME, BASE_TABLE_SCHEMA, BASE_TABLE_NAME
                    from {DB}.INFORMATION_SCHEMA.SEMANTIC_TABLES
                    where SEMANTIC_VIEW_SCHEMA='{SC}'""", cn)
    base_of = {(r[0], r[1]): f"{r[2]}.{r[3]}" for r in tabs}
    _, drows = q(f"""select SEMANTIC_VIEW_NAME, TABLE_NAME, NAME, EXPRESSION, COMMENT, DATA_TYPE
                     from {DB}.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS
                     where SEMANTIC_VIEW_SCHEMA='{SC}'""", cn)
    dims = []
    for sv, lt, dim, expr, cmt, dt in drows:
        bt = base_of.get((sv, lt))
        m = re.fullmatch(r'\s*([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*', str(expr or ''))
        if not bt or not m:
            continue
        dims.append((sv, dim, bt, m.group(2).upper(), cmt, dt))

    # base 컬럼 단위로 1회만 측정한다(같은 컬럼을 여러 SV 가 노출하므로).
    need = sorted({(d[2], d[3]) for d in dims})
    card = {}
    by_table = collections.defaultdict(list)
    for bt, bc in need:
        by_table[bt].append(bc)
    for bt, cols in sorted(by_table.items()):
        # 테이블 1회 스캔으로 전 컬럼 distinct 를 구한다(컬럼당 쿼리 = 160회는 과하다).
        sel = ', '.join(f'count(distinct "{c}") as "{c}"' for c in cols)
        try:
            cols_out, rows = q(f'select {sel} from {DB}.{bt}', cn)
        except Exception as e:
            print(f"  ⚪ 측정 불가 {bt}: {str(e)[:70]}")
            continue
        for name, val in zip(cols_out, rows[0]):
            card[(bt, name.upper())] = int(val)
    cn.close()

    rows = []
    for sv, dim, bt, bc, cmt, dt in dims:
        n = card.get((bt, bc))
        vals, declared = enumerated_values(cmt, bc)
        rows.append((n if n is not None else -1, sv, dim, bt.split('.')[-1], bc, dt,
                     len(vals), declared))

    print(f"{'card':>7} {'열거':>4} {'선언':>4}  {'TYPE':<10} SV.DIM  ▸ base 컬럼")
    print('-' * 110)
    for n, sv, dim, tb, bc, dt, nv, dec in sorted(rows):
        mark = '🟢' if nv else '🔴'
        print(f"{n:>7} {nv:>4} {str(dec if dec is not None else '-'):>4}  {str(dt)[:10]:<10} "
              f"{mark} {sv}.{dim} ▸ {tb}.{bc}")

    # 임계 후보별 「열거 없는 축」 규모
    print('\n[임계별 대상 규모] — 열거가 없는 축 개수')
    for thr in (5, 10, 20, 30, 50, 111, 500):
        miss = [r for r in rows if 0 <= r[0] <= thr and r[6] == 0]
        tot = [r for r in rows if 0 <= r[0] <= thr]
        print(f"  distinct <= {thr:>4}: 대상 {len(tot):>3}개 중 열거 없음 {len(miss):>3}개")


if __name__ == '__main__':
    sys.exit(main())
