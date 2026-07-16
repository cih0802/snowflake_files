# GN_DW SILVER/GOLD 컬럼 인벤토리를 현재 구현(GN_DW.SILVER/GOLD DDL)에서 재생성
# Co-authored with CoCo
import os, csv, re
import snowflake.connector

TOKEN = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
con = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    host=os.environ["SNOWFLAKE_HOST"],
    token=TOKEN,
    authenticator="oauth",
    warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
    database="GN_DW",
    role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
)
cur = con.cursor()

AUDIT = {"DW_SOURCE_SYSTEM", "DW_SOURCE_TABLE", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"}

# ---- 1) 컬럼 메타데이터 ----
def cols(schema):
    cur.execute("""
      SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME,
        CASE WHEN DATA_TYPE='TEXT' THEN
               CASE WHEN CHARACTER_MAXIMUM_LENGTH=16777216 THEN 'VARCHAR'
                    ELSE 'VARCHAR('||CHARACTER_MAXIMUM_LENGTH||')' END
             WHEN DATA_TYPE='NUMBER' THEN 'NUMBER('||NUMERIC_PRECISION||','||NUMERIC_SCALE||')'
             ELSE DATA_TYPE END AS FULL_TYPE,
        IS_NULLABLE, COALESCE(COMMENT,'')
      FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA=%s
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    """, (schema,))
    return cur.fetchall()

# ---- 2) PK 세트 ----
def pks(schema):
    cur.execute(f"SHOW PRIMARY KEYS IN SCHEMA GN_DW.{schema}")
    s = set()
    for r in cur.fetchall():
        # columns: created_on,db,schema,table,column,key_seq,...
        s.add((r[3], r[4]))
    return s

# ---- 3) FK 맵 (GOLD, enforced) : (fk_table, fk_col) -> "PK_TABLE(PK_COL)" ----
def fks():
    cur.execute("SHOW IMPORTED KEYS IN DATABASE GN_DW")
    m = {}
    for r in cur.fetchall():
        pk_tab, pk_col = r[3], r[4]
        fk_tab, fk_col = r[7], r[8]
        m[(fk_tab, fk_col)] = f"{pk_tab}({pk_col})"
    return m

SILVER = cols("SILVER"); GOLD = cols("GOLD")
PK_S = pks("SILVER"); PK_G = pks("GOLD")
FK_G = fks()

# ---- 4) 기존 CSV에서 GRAIN/유형/키/FK 주석 캐리오버 ----
def load_old(path):
    grain, typ, key, fk = {}, {}, {}, {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            t = row["테이블명"]; c = row["컬럼명"]
            grain[t] = row["GRAIN"]; typ[t] = row["테이블유형"]
            key[(t, c)] = row["키"]; fk[(t, c)] = row["FK_타깃"]
    return grain, typ, key, fk

OG_S, OT_S, OK_S, OFK_S = load_old("/workspace/SILVER 스키마 컬럼 인벤토리_20260630.csv")
OG_G, OT_G, OK_G, OFK_G = load_old("/workspace/gold 스키마 컬럼 인벤토리_20260629.csv")

# 신규 테이블 GRAIN/유형 정의
NEW_SILVER = {
    "AGENCY_AD_CREATIVE":  ("광고소재 1건(대체키)",            "대행사-광고소재"),
    "AGENCY_AD_PERFORMANCE": ("소스×일자×매체×소재 실적",       "대행사-광고실적"),
    "ERP_BIZ_TARGET":      ("연/월×조직×사업 목표 1건",         "ERP-사업목표"),
    "ERP_BUDGET":          ("예산과목×월 1건",                  "ERP-예산"),
    "ERP_BUDGET_ITEM":     ("예산과목(세세목) 1건",             "ERP-예산과목"),
    "IDENTITY_MEMBER_XREF":("GA세션(user_pseudo_id)×CRM회원 매칭","브리지-신원"),
}
# WIDE GRAIN: 대응 FACT grain 재사용
WIDE_GRAIN = {
    "WIDE_MEMBER_MONTHLY": "MONTH_KEY × MEMBER_DK",
    "WIDE_MEMBER_EVENT":   "DATE_SK × MEMBER_DK × EVENT_TYPE",
    "WIDE_SERVICE_EVENT":  "DATE_SK × MEMBER_DK × SERVICE × CAMPAIGN",
    "WIDE_GA_BEHAVIOR":    "DATE_SK × IDENTITY × GA_EVENT × GA_SOURCE × DEVICE × CAMPAIGN × PAGE",
    "WIDE_AD_PERFORMANCE": "PERF_DATE × CAMPAIGN × AD_CREATIVE × DEVICE",
    "WIDE_EVENT_PARTICIPATION": "DATE_SK × MEMBER_DK × EVENT",
    "WIDE_BUDGET":         "MONTH_KEY × ORG × BUDGET_ITEM [×CAMPAIGN]",
    "WIDE_TARGET_DEV":     "MONTH_KEY × ORG × DEV_TYPE",
    "WIDE_TARGET_BIZ":     "MONTH_KEY × ORG × SPONSORSHIP [×CAMPAIGN]",
}

def split_comment(col, comment):
    """DDL 코멘트를 설명 / 주의_제약(DDL)로 분리 (현재 구현 기준, 해소된 이슈 없음)."""
    desc, caveat = comment, ""
    # 공통감사 컬럼
    if col in AUDIT:
        return comment, "공통감사"
    # ⚠️ 이후는 미해소 주의사항으로 이동
    if "⚠️" in desc:
        i = desc.find("⚠️")
        caveat = desc[i:].strip()
        desc = desc[:i].strip(" —(,")
    # 비가산
    if "비가산" in comment and "비가산" not in caveat:
        caveat = ("비가산; " + caveat).strip("; ") if caveat else "비가산"
    # 파생
    if desc.startswith("파생") or "(파생)" in comment or " 파생" in comment:
        tag = "파생"
        caveat = (caveat + "; " + tag).strip("; ") if caveat else tag
    # (PK) 표기는 키 열에서 처리 → 설명에서 제거
    desc = re.sub(r"\s*\(PK[^)]*\)", "", desc).strip(" ,")
    # WIDE 라벨조인 표시 (DIM_ 접두 코멘트)
    if col not in AUDIT and comment.startswith("DIM_"):
        caveat = (caveat + "; 라벨조인(DIM 파생)").strip("; ") if caveat else "라벨조인(DIM 파생)"
    return desc, caveat

def key_val(schema, tab, col, nullable, is_fact, is_wide, pkset, oldkey):
    parts = []
    if (tab, col) in pkset:
        parts.append("PK")
    is_fk = False
    if schema == "GOLD" and (tab, col) in FK_G:
        is_fk = True
    parts_join = ",".join(parts)
    # GRAIN (fact/wide 의 NOT NULL 비감사 키)
    grain = (is_fact or is_wide) and nullable == "NO" and col not in AUDIT and "PK" not in parts
    ann = []
    if "PK" in parts:
        ann.append("PK")
    if grain:
        ann.append("GRAIN")
    if is_fk:
        ann.append("FK")
    if ann:
        return ",".join(dict.fromkeys(ann))
    # 캐리오버 (degen/snapshot/A/N/DK/FK 주석 등)
    ov = oldkey.get((tab, col), "")
    # SILVER 비강제 FK: 코멘트 '→' 기반
    return ov

def fk_target(schema, tab, col, comment, oldfk):
    if schema == "GOLD" and (tab, col) in FK_G:
        return FK_G[(tab, col)]
    # SILVER 비강제 FK: 코멘트의 (→TABLE) 추출
    m = re.search(r"→\s*([A-Z_][A-Z0-9_]*)", comment)
    if m and schema == "SILVER":
        tgt = m.group(1)
        return f"{tgt}※비강제"
    # 캐리오버
    return oldfk.get((tab, col), "")

def build(rows, schema, oldgrain, oldtyp, oldkey, oldfk):
    out = []
    for tab, pos, col, ftype, nullable, comment in rows:
        is_fact = tab.startswith("FACT_")
        is_wide = tab.startswith("WIDE_")
        pkset = PK_S if schema == "SILVER" else PK_G
        # GRAIN/유형
        if schema == "SILVER":
            grain = oldgrain.get(tab) or (NEW_SILVER.get(tab, ("", ""))[0])
            typ = oldtyp.get(tab) or (NEW_SILVER.get(tab, ("", ""))[1])
        else:
            if is_wide:
                grain = WIDE_GRAIN.get(tab, ""); typ = "WIDE"
            else:
                grain = oldgrain.get(tab, ""); typ = oldtyp.get(tab, "")
        desc, caveat = split_comment(col, comment)
        keyv = key_val(schema, tab, col, nullable, is_fact, is_wide, pkset, oldkey)
        fkt = fk_target(schema, tab, col, comment, oldfk)
        nn = "N" if nullable == "NO" else "Y"
        out.append([tab, grain, typ, col, ftype, nn, keyv, fkt, desc, caveat])
    return out

hdr = ["테이블명","GRAIN","테이블유형","컬럼명","타입","NULLABLE","키","FK_타깃","설명","주의_제약(DDL)"]

sv = build(SILVER, "SILVER", OG_S, OT_S, OK_S, OFK_S)
gd = build(GOLD, "GOLD", OG_G, OT_G, OK_G, OFK_G)

with open("/workspace/SILVER 스키마 컬럼 인벤토리_20260716.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f); w.writerow(hdr); w.writerows(sv)
with open("/workspace/gold 스키마 컬럼 인벤토리_20260716.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f); w.writerow(hdr); w.writerows(gd)

print(f"SILVER rows={len(sv)} tables={len(set(r[0] for r in sv))}")
print(f"GOLD   rows={len(gd)} tables={len(set(r[0] for r in gd))}")
con.close()
