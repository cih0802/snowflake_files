"""GN_DW SILVER/GOLD 컬럼 인벤토리 CSV 생성 (라이브 메타데이터 기준).

30_output_share/02_{SILVER,gold} 스키마 컬럼 인벤토리_<날짜>.csv 를 생성한다.
스키마 구조·COMMENT 의 소유자는 DDL 이며, 본 스크립트는 라이브 카탈로그를 그대로 사영한다.
"""
import csv
import os
import re
import sys

import snowflake.connector

WS = os.environ.get("GN_DW_WS", "/workspace")
AS_OF = sys.argv[1] if len(sys.argv) > 1 else "20260811"
OUT_DIR = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
PREV_DIR = os.path.join(WS, "30_output_share", "_archive", "20260806")
PREV_TAG = "20260811"

HEADER = ["테이블명", "GRAIN", "테이블유형", "컬럼명", "타입", "NULLABLE",
          "키", "FK_타깃", "설명", "주의_제약(DDL)"]

AUDIT_PREFIX = "DW_"


def connect():
    tok = open(os.environ["SNOWFLAKE_TOKEN_FILE_PATH"]).read().strip()
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        host=os.environ["SNOWFLAKE_HOST"],
        token=tok,
        authenticator="oauth",
        role=os.environ.get("SNOWFLAKE_ROLE"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE"),
        database="GN_DW",
    )


def q(cur, sql):
    cur.execute(sql)
    cols = [c[0] for c in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def fmt_type(r):
    t = r["DATA_TYPE"]
    if t in ("TEXT", "VARCHAR", "STRING"):
        return "VARCHAR"
    if t in ("NUMBER", "DECIMAL", "NUMERIC", "FIXED"):
        p, s = r["NUMERIC_PRECISION"], r["NUMERIC_SCALE"]
        if p is None:
            return "NUMBER"
        return f"NUMBER({p},{s if s is not None else 0})"
    if t == "FLOAT":
        return "FLOAT"
    if t == "BOOLEAN":
        return "BOOLEAN"
    if t.startswith("TIMESTAMP_"):
        return t
    return t


# GRAIN: 테이블 COMMENT 에 명시된 grain 선언을 우선 사용한다.
GRAIN_PATTERNS = [
    r"grain\s*=\s*([^.。\n]{1,60}?)(?:\s*[.。]|$)",
    r"1행\s*=\s*([^.·\n)]{1,40})",
    r"PK\s*=\s*([A-Z_0-9×]{3,60})",
    r"\(1([^)]{1,30})\s*grain\)",
    r"\((1[^)]{1,30})\)",
]

TRAILING = " ·—-,·"


def clip(s, n=48):
    """n자를 넘으면 마지막 구분자에서 자른다(단어 중간 절단 방지)."""
    s = s.strip(TRAILING)
    if len(s) <= n:
        return s
    cut = s[:n]
    for sep in ("·", " ", "×", ",", "("):
        i = cut.rfind(sep)
        if i > n // 2:
            return cut[:i].strip(TRAILING)
    return cut.strip(TRAILING)


def derive_grain(tbl_comment, prev_grain):
    if prev_grain:
        return prev_grain
    c = re.sub(r"[🔴🟢⛔⚠️]", "", (tbl_comment or "")).strip()
    if not c:
        return ""
    for pat in GRAIN_PATTERNS:
        m = re.search(pat, c, re.IGNORECASE)
        if m:
            g = m.group(1).strip(TRAILING)
            if g:
                if pat.startswith("1행"):
                    g = g if g.startswith("1") else "1" + g
                return clip(g, 60)
    head = re.split(r"[.。\n]", c)[0]
    return clip(head)


# 원천 구조 변경으로 신설된 테이블의 도메인 라벨 (이전 판본 라벨 체계 승계)
SILVER_TYPE_OVERRIDE = {
    "CRM_BIZ_TARGET": "마스터",
    "CRM_MARKETING_CAMPAIGN": "마스터",
}


def derive_table_type(schema, table, prev_type):
    if prev_type:
        return prev_type
    if schema == "SILVER" and table in SILVER_TYPE_OVERRIDE:
        return SILVER_TYPE_OVERRIDE[table]
    if schema == "GOLD":
        for p, v in (("DIM_", "DIMENSION"), ("FACT_", "FACT"), ("WIDE_", "WIDE")):
            if table.startswith(p):
                return v
        return ""
    # SILVER: 원천 시스템 접두 기반
    if table.startswith("AGENCY_"):
        return "광고"
    if table.startswith("ERP_"):
        return "ERP"
    if table.startswith("GA4_"):
        return "GA4"
    if table.startswith("IDENTITY_"):
        return "신원"
    if table.startswith("CRM_"):
        return "CRM"
    return ""


def derive_key(col, pk_cols, fk_map):
    parts = []
    if col in pk_cols:
        parts.append("PK")
    elif col.endswith("_DK"):
        parts.append("DK")
    elif col.endswith("_BK"):
        parts.append("BK")
    if col in fk_map:
        parts.append("FK")
    return ",".join(parts)


def note(col, prev_note):
    if col.startswith(AUDIT_PREFIX):
        return "공통감사"
    return prev_note or ""


def load_prev(path):
    """이전 판본에서 사람이 정제한 GRAIN·테이블유형·FK_타깃·주의를 승계한다."""
    grain, ttype, fk, notes = {}, {}, {}, {}
    # 02_ 접두사 여부 모두 검사
    if not os.path.exists(path):
        alt_path = path.replace("/02_", "/")
        if os.path.exists(alt_path):
            path = alt_path
        else:
            return grain, ttype, fk, notes
    for r in csv.DictReader(open(path, encoding="utf-8-sig")):
        t, c = r["테이블명"].strip(), r["컬럼명"].strip()
        if r.get("GRAIN", "").strip():
            grain[t] = r["GRAIN"].strip()
        if r.get("테이블유형", "").strip():
            ttype[t] = r["테이블유형"].strip()
        if r.get("FK_타깃", "").strip():
            fk[(t, c)] = r["FK_타깃"].strip()
        if r.get("주의_제약(DDL)", "").strip():
            notes[(t, c)] = r["주의_제약(DDL)"].strip()
    return grain, ttype, fk, notes


def build(cur, schema, prev_file, out_file):
    prev_grain, prev_ttype, prev_fk, prev_notes = load_prev(prev_file)

    cols = q(cur, f"""
        SELECT c.TABLE_NAME, c.ORDINAL_POSITION, c.COLUMN_NAME, c.DATA_TYPE,
               c.NUMERIC_PRECISION, c.NUMERIC_SCALE, c.IS_NULLABLE, c.COMMENT AS COL_COMMENT,
               t.TABLE_TYPE, t.COMMENT AS TBL_COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS c
        JOIN GN_DW.INFORMATION_SCHEMA.TABLES t
          ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
        WHERE c.TABLE_SCHEMA = '{schema}'
        ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION
    """)

    pk = {}
    for r in q(cur, f"SHOW PRIMARY KEYS IN SCHEMA GN_DW.{schema}"):
        pk.setdefault(r["table_name"], set()).add(r["column_name"])

    fk = {}
    for r in q(cur, f"SHOW IMPORTED KEYS IN SCHEMA GN_DW.{schema}"):
        fk[(r["fk_table_name"], r["fk_column_name"])] = \
            f'{r["pk_table_name"]}.{r["pk_column_name"]}'

    rows = []
    for r in cols:
        t, c = r["TABLE_NAME"], r["COLUMN_NAME"]
        fk_target = fk.get((t, c)) or prev_fk.get((t, c), "")
        key = derive_key(c, pk.get(t, set()), {c} if fk_target else set())
        rows.append([
            t,
            derive_grain(r["TBL_COMMENT"], prev_grain.get(t)),
            derive_table_type(schema, t, prev_ttype.get(t)),
            c,
            fmt_type(r),
            "Y" if r["IS_NULLABLE"] == "YES" else "N",
            key,
            fk_target,
            (r["COL_COMMENT"] or "").replace("\r\n", " ").replace("\n", " ").strip(),
            note(c, prev_notes.get((t, c))),
        ])

    with open(out_file, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(HEADER)
        w.writerows(rows)

    tbls = len({r[0] for r in rows})
    print(f"{out_file}: {tbls} tables / {len(rows)} columns")
    return rows


def main():
    conn = connect()
    cur = conn.cursor()
    build(cur, "SILVER",
          f"{PREV_DIR}/SILVER 스키마 컬럼 인벤토리_{PREV_TAG}.csv",
          f"{OUT_DIR}/02_SILVER 스키마 컬럼 인벤토리_{AS_OF}.csv")
    build(cur, "GOLD",
          f"{PREV_DIR}/gold 스키마 컬럼 인벤토리_{PREV_TAG}.csv",
          f"{OUT_DIR}/02_gold 스키마 컬럼 인벤토리_{AS_OF}.csv")
    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
