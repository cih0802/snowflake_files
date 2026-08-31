# O128 임시 조사기 — 물리 FK 에만 있는 관계 18건과 DIM 측 키 컬럼 고립 후보를 나열한다.
# Co-authored with CoCo
#
# 🔴 임시 도구다(착수표 ㉞·㊲ 실측용). 판정을 발행하지 않고 목록만 낸다.

import os
import sys
import importlib.util

ROOT = "/workspace"
sys.path.insert(0, os.path.join(ROOT, "scripts"))


def load_generator():
    spec = importlib.util.spec_from_file_location(
        "gen_gold_erd", os.path.join(ROOT, "scripts", "gen_gold_erd.py"))
    mod = importlib.util.module_from_spec(spec)
    saved = sys.argv
    sys.argv = ["gen_gold_erd"]
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.argv = saved
    return mod


def fetch_key_columns(cn, prefixes):
    """접두별 키 형태 컬럼(_SK / _KEY / _DK)을 라이브에서 가져온다."""
    cur = cn.cursor()
    like = " OR ".join(
        "c.TABLE_NAME LIKE '%s/_%%' ESCAPE '/'" % p for p in prefixes)
    cur.execute("""
        SELECT c.TABLE_NAME, c.COLUMN_NAME
          FROM GN_DW.INFORMATION_SCHEMA.COLUMNS c
          JOIN GN_DW.INFORMATION_SCHEMA.TABLES t
            ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
           AND t.TABLE_NAME   = c.TABLE_NAME
         WHERE c.TABLE_SCHEMA = 'GOLD'
           AND t.TABLE_TYPE   = 'BASE TABLE'
           AND (%s)
           AND (   c.COLUMN_NAME LIKE '%%/_SK'  ESCAPE '/'
                OR c.COLUMN_NAME LIKE '%%/_KEY' ESCAPE '/'
                OR c.COLUMN_NAME LIKE '%%/_DK'  ESCAPE '/')
         ORDER BY c.TABLE_NAME, c.COLUMN_NAME
    """ % like)
    return [(r[0], r[1]) for r in cur.fetchall()]


def main():
    g = load_generator()
    import sfconn
    cn = sfconn.conn()
    try:
        yaml_models = g.parse_dbt_schema(g.SCHEMA_YML)
        yaml_keys = {
            (m, fk["col"], fk["ref_table"], fk["ref_col"])
            for m, mi in yaml_models.items() for fk in mi["fk"]
        }
        live_fk = g.fetch_live_fk(cn)

        print("── 물리 FK 에만 있는 관계 (dbt relationships 미작성) ──")
        n = 0
        for f in sorted(live_fk, key=lambda x: (x["fk_table"], x["fk_col"])):
            key = (f["fk_table"], f["fk_col"], f["pk_table"], f["pk_col"])
            if key in yaml_keys:
                continue
            n += 1
            print("  %2d  %-28s %-26s → %s.%s"
                  % (n, f["fk_table"], f["fk_col"], f["pk_table"], f["pk_col"]))
        print("  합계 = %d" % n)

        print()
        print("── DIM 측 키 형태 컬럼 (㊲ 분모 확대 후보) ──")
        dim_keys = fetch_key_columns(cn, ["DIM"])
        merged, stats = g.merge_fk_sources(g.parse_dbt_schema(g.SCHEMA_YML), live_fk)
        covered = {(m, fk["col"]) for m, mi in merged.items() for fk in mi["fk"]}
        live_pk = g.fetch_live_pk(cn)
        pk_cols = {(t, c) for t, cols in live_pk.items() for c in cols}
        print("  DIM 키 컬럼 수 = %d" % len(dim_keys))
        orph = [k for k in dim_keys if k not in covered and k not in pk_cols]
        print("  그중 고립(FK 도 PK 도 아님) = %d" % len(orph))
        for t, c in orph:
            print("    %-28s %s" % (t, c))
    finally:
        cn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
