# GOLD 스키마 테이블별 ERD 문서를 dbt schema YAML + INFORMATION_SCHEMA 로 자동 생성한다.
# Co-authored with CoCo
#
# 비용 구조:
#   - 1차 소스 = dbt _gold_ready_schema.yml 파싱 (비용 $0, 파일 I/O만)
#   - 2차 소스 = INFORMATION_SCHEMA 컬럼 메타 + SHOW IMPORTED KEYS (XS 웨어하우스 ~2초)
#   - --yaml-only 플래그로 컴퓨트 비용 없이 실행 가능 (단 아래 🔴 경고 참조)
#
# 🔴 [실측 2026-08-31] **두 소스 중 어느 하나도 FK 전량을 담지 못한다** → 반드시 합집합을 써야 한다.
#    - dbt YAML 단독  = 45관계. 물리 FK 18개 누락(FACT_BUDGET·FACT_BUDGET_YEARLY·FACT_TARGET_BIZ 의
#      ORG_SK·SPONSORSHIP_SK·CAMPAIGN_SK / FACT_AD_PERFORMANCE 3 / DIM_CAMPAIGN 2 / 역할기반 날짜키 등)
#      — relationships 테스트를 안 붙인 컬럼은 YAML 에 흔적이 없다.
#    - 물리 FK 단독  = 56관계. YAML 관계 7개 누락 — `MEMBER_DK → DIM_MEMBER` 7건은
#      DIM_MEMBER 가 SCD2 라 MEMBER_DK 가 비유일 ⇒ Snowflake 규칙상 FK **선언 불가**
#      (06_DDL.sql [관계 제약] 섹션 [보류] 사유와 일치). 그러나 실제 조인경로이므로 ERD 에 있어야 한다.
#    ⇒ 본 스크립트는 두 소스를 병합하고 각 관계에 출처(yaml / live / both)를 표기한다.
#    ⚠️ --yaml-only 로 만든 산출물은 FK 가 불완전하다 — 별도 경로로만 쓴다(OUT_HTML 을 덮지 않는다).
#
# 🔴🔴 [O126 검토로 발견 · 초판의 최악 결함] **합집합도 전량이 아니다 — 3차 소스가 필요하다.**
#    초판은 병합 63관계를 「전량」으로 발행했으나, 실측하니 **DIM_MONTH 로 가는 conform 축 7건이
#    두 소스 어디에도 없어** ERD 에서 DIM_MONTH 가 **관계선 0개의 고립 섬**으로 그려졌다.
#    ⚠️ 이것이 이 스키마에서 가능한 최악의 오도다 — DIM_MONTH 는 **fan-out 차단 차원**이고,
#    초판 ERD 는 월 팩트를 DIM_DATE(일 grain)에만 연결해 두어 **설계가 막으려던 금액 과대 집계를
#    오히려 유도**했다(DIM_MONTH.MONTH_KEY COMMENT 의 🔴🔴 경고가 정확히 그 사고다).
#    ⇒ 3차 소스 = `scripts/gold_erd_coverage_gate.py` 의 `LOGICAL_FK` (사람이 판정해 등재한 논리 관계).
#    🔴 그 게이트가 **미분류 고립 0** 을 강제하므로, 새 키 컬럼이 생기면 FAIL 로 사람 판정을 부른다.
#    🟢 판정식 = 「관계 수가 늘었는가」가 아니라 **「고립 키 컬럼이 분류되었는가」**다.
#
# 재사용: dbt 파이프라인에서 GOLD 테이블·컬럼·FK 변경 후 이 스크립트 재실행만 하면
#         ERD 문서가 자동 갱신된다. CI/CD 또는 dbt post-hook 에 통합 가능.
#         🔴 **재실행 전에 커버리지 게이트를 먼저 통과시켜라** — 안 그러면 새 축이 조용히 빠진다.
#
# 출력 = 30_output_share/GOLD_ERD_테이블별.html          (전량판)
#        30_output_share/GOLD_ERD_테이블별_YAML전용.html  (--yaml-only · 불완전 · 배포 금지)

import os
import re
import sys
import json
from collections import defaultdict
from datetime import datetime

import yaml

# ── 경로 ──
ROOT = "/workspace"
SCHEMA_YML = os.path.join(ROOT, "10_dbt_pipeline", "models", "gold", "_gold_ready_schema.yml")
WIDE_YML = os.path.join(ROOT, "10_dbt_pipeline", "models", "gold", "wide", "_wide_schema.yml")
OUT_HTML = os.path.join(ROOT, "30_output_share", "GOLD_ERD_테이블별.html")
# 🔴 [O126] --yaml-only 는 **별도 경로**에 쓴다. 종전 판본은 같은 경로에 써서
#    불완전 산출물이 전량판을 조용히 덮었다(이 워크스페이스가 4번 당한 「조용한 소실」 유형).
OUT_HTML_YAML = os.path.join(ROOT, "30_output_share", "GOLD_ERD_테이블별_YAML전용.html")

YAML_ONLY = "--yaml-only" in sys.argv

# 🔴 [O126] 스냅샷 라벨 — **산식을 재구현하지 않는다**(`test_snapshot_util` 축9).
#   `resolve_label()` 이 인자 → `SESSION_LABEL` → `UNLABELED` 를 정하고 `_sanitize` 도 한다.
#   사용법 = `--label O1NN` 또는 `export SESSION_LABEL=O1NN`.
def _label_from_argv():
    if "--label" in sys.argv:
        i = sys.argv.index("--label")
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


LABEL = _label_from_argv()


# ══════════════════════════════════════════════════════════════════════════════
# 1. dbt schema YAML 파싱 — FK 관계 + PK(unique+not_null) 추출
# ══════════════════════════════════════════════════════════════════════════════
def parse_dbt_schema(yml_path):
    """YAML 에서 모델별 PK 컬럼, FK 관계를 추출한다.

    PK 판정 = unique + not_null 동시 부착. 🔴 이는 **dbt 테스트 규약의 추론**이며
    물리 PRIMARY KEY 선언과 다를 수 있다 — 물리 PK 는 fetch_live_pk() 로 별도 확인한다.
    """
    with open(yml_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    models = {}
    for m in data.get("models", []):
        name = m["name"]
        pk_cols = []
        fk_rels = []
        col_names = []
        for c in m.get("columns", []):
            cname = c["name"]
            # 복합 grain 가드(|| 포함)는 컬럼이 아니라 표현식 → 스킵
            if "||" in cname:
                continue
            col_names.append(cname)
            tests = c.get("tests", [])
            has_unique = False
            has_not_null = False
            for t in tests:
                if t == "unique":
                    has_unique = True
                elif t == "not_null":
                    has_not_null = True
                elif isinstance(t, dict):
                    if "unique" in t:
                        has_unique = True
                    if "not_null" in t:
                        has_not_null = True
                    if "relationships" in t:
                        rel = t["relationships"]
                        ref_match = re.search(r"ref\(['\"](\w+)['\"]\)", rel.get("to", ""))
                        if ref_match:
                            fk_rels.append({
                                "col": cname,
                                "ref_table": ref_match.group(1),
                                "ref_col": rel.get("field", cname),
                                "src": "yaml",
                            })
            if has_unique and has_not_null:
                pk_cols.append(cname)
        models[name] = {"pk": pk_cols, "fk": fk_rels, "columns": col_names,
                        "description": m.get("description", "")}
    return models


# ══════════════════════════════════════════════════════════════════════════════
# 2. INFORMATION_SCHEMA / SHOW 로 라이브 메타 조회
# ══════════════════════════════════════════════════════════════════════════════
def fetch_column_meta(cn):
    """GOLD 스키마 전 테이블의 컬럼명·타입·COMMENT 를 가져온다."""
    cur = cn.cursor()
    cur.execute("""
        SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE,
               NUMERIC_PRECISION, NUMERIC_SCALE, CHARACTER_MAXIMUM_LENGTH,
               COMMENT, ORDINAL_POSITION, IS_NULLABLE
          FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = 'GOLD'
         ORDER BY TABLE_NAME, ORDINAL_POSITION
    """)
    cols = [c[0] for c in cur.description]
    meta = defaultdict(list)
    for r in cur.fetchall():
        d = dict(zip(cols, r))
        dtype = d["DATA_TYPE"]
        if dtype in ("NUMBER", "DECIMAL", "NUMERIC") and d["NUMERIC_PRECISION"]:
            dtype = f"NUMBER({d['NUMERIC_PRECISION']},{d['NUMERIC_SCALE'] or 0})"
        elif dtype in ("TEXT", "VARCHAR") and d["CHARACTER_MAXIMUM_LENGTH"]:
            clen = d["CHARACTER_MAXIMUM_LENGTH"]
            dtype = f"VARCHAR({clen})" if clen < 16777216 else "VARCHAR"
        meta[d["TABLE_NAME"]].append({
            "name": d["COLUMN_NAME"],
            "type": dtype,
            "comment": (d["COMMENT"] or "")[:120],
            "nullable": d["IS_NULLABLE"] == "YES",
            "ordinal": d["ORDINAL_POSITION"],
        })
    return dict(meta)


def fetch_live_fk(cn):
    """SHOW IMPORTED KEYS 로 물리 FK(정보성 NOT ENFORCED 포함)를 가져온다."""
    cur = cn.cursor()
    cur.execute("SHOW IMPORTED KEYS IN SCHEMA GN_DW.GOLD")
    desc = [c[0] for c in cur.description]
    out = []
    for r in cur.fetchall():
        d = dict(zip(desc, r))
        out.append({
            "fk_table": d.get("fk_table_name", ""),
            "fk_col": d.get("fk_column_name", ""),
            "pk_table": d.get("pk_table_name", ""),
            "pk_col": d.get("pk_column_name", ""),
        })
    return out


def fetch_live_pk(cn):
    """SHOW PRIMARY KEYS 로 물리 PK 를 가져온다(YAML 추론 PK 와 대조용)."""
    cur = cn.cursor()
    cur.execute("SHOW PRIMARY KEYS IN SCHEMA GN_DW.GOLD")
    desc = [c[0] for c in cur.description]
    pk = defaultdict(list)
    for r in cur.fetchall():
        d = dict(zip(desc, r))
        pk[d.get("table_name", "")].append(d.get("column_name", ""))
    return dict(pk)


def fetch_table_rows(cn):
    """테이블·뷰별 행 수. 🔴 VIEW 는 ROW_COUNT 가 NULL 이다(스캔 없이 알 수 없다)."""
    cur = cn.cursor()
    cur.execute("""
        SELECT TABLE_NAME, ROW_COUNT, TABLE_TYPE
          FROM GN_DW.INFORMATION_SCHEMA.TABLES
         WHERE TABLE_SCHEMA = 'GOLD'
    """)
    return {r[0]: {"rows": r[1], "type": r[2]} for r in cur.fetchall()}


# ══════════════════════════════════════════════════════════════════════════════
# 3. FK 합집합 병합 — 두 소스 어느 하나도 전량이 아니다(파일 헤더 🔴 참조)
# ══════════════════════════════════════════════════════════════════════════════
def merge_fk_sources(models, live_fk):
    """물리 FK 를 models 의 fk 목록에 병합하고 각 관계에 출처를 표기한다.

    반환 = (models, stats) — stats 는 소스별 관계 수 판정 근거.
    """
    yaml_keys = set()
    for mname, minfo in models.items():
        for fk in minfo["fk"]:
            yaml_keys.add((mname, fk["col"], fk["ref_table"], fk["ref_col"]))

    live_keys = set()
    for f in live_fk:
        live_keys.add((f["fk_table"], f["fk_col"], f["pk_table"], f["pk_col"]))

    # ① YAML 에도 물리에도 있는 관계 → src = both
    for mname, minfo in models.items():
        for fk in minfo["fk"]:
            if (mname, fk["col"], fk["ref_table"], fk["ref_col"]) in live_keys:
                fk["src"] = "both"

    # ② 물리에만 있는 관계 → 새로 추가(src = live)
    added = 0
    for f in live_fk:
        key = (f["fk_table"], f["fk_col"], f["pk_table"], f["pk_col"])
        if key in yaml_keys:
            continue
        tgt = f["fk_table"]
        if tgt not in models:
            # YAML 에 모델 블록조차 없는 테이블(테스트 미작성) → 껍데기 생성
            models[tgt] = {"pk": [], "fk": [], "columns": [], "description": ""}
        models[tgt]["fk"].append({
            "col": f["fk_col"],
            "ref_table": f["pk_table"],
            "ref_col": f["pk_col"],
            "src": "live",
        })
        added += 1

    stats = {
        "yaml_total": len(yaml_keys),
        "live_total": len(live_keys),
        "yaml_only": len(yaml_keys - live_keys),
        "live_only": len(live_keys - yaml_keys),
        "both": len(yaml_keys & live_keys),
        "merged_total": len(yaml_keys | live_keys),
        "added_from_live": added,
    }
    return models, stats


def merge_pk_sources(models, live_pk):
    """물리 PK 를 우선 채택하고, 없으면 YAML 추론 PK 를 남긴다."""
    for tname, cols in live_pk.items():
        if tname not in models:
            models[tname] = {"pk": [], "fk": [], "columns": [], "description": ""}
        models[tname]["pk_live"] = cols
    for tname, info in models.items():
        info.setdefault("pk_live", [])
    return models


# ══════════════════════════════════════════════════════════════════════════════
# 3-B. 논리 관계 병합 (3차 소스) — 🔴 [O126] 합집합도 전량이 아니다
# ══════════════════════════════════════════════════════════════════════════════
def merge_logical_fk(models, fact_key_cols, live_pk):
    """두 소스 어디에도 없는 「고립 키 컬럼」에 논리 관계를 부여한다.

    규칙 정본 = `scripts/gold_erd_coverage_gate.py` 의 `LOGICAL_FK` / `KNOWN_ORPHANS`.
    🔴 규칙을 이 파일에 복사하지 마라 — 두 곳에 적으면 한 곳이 낡는다(`R3-9 ㉡`).
      게이트를 import 해서 읽는다. import 실패는 **조용히 넘기지 않고 예외로 중단**한다
      (규칙 없이 생성하면 초판과 같은 고립 섬 ERD 가 다시 나온다).

    반환 = (models, stats) — stats 는 논리 관계 추가 수와 미분류 고립 수.
    """
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    import gold_erd_coverage_gate as gate

    covered = {(m, fk["col"]) for m, mi in models.items() for fk in mi["fk"]}
    pk_cols = {(t, c) for t, cols in live_pk.items() for c in cols}

    added, unclassified, degen = 0, [], 0
    for tname, col in fact_key_cols:
        if (tname, col) in covered or (tname, col) in pk_cols:
            continue
        cls = gate.classify(tname, col)
        if cls is None:
            unclassified.append((tname, col))
            continue
        if cls[0] != "CONFORM":
            degen += 1          # DEGEN·SELFREF 는 관계선이 없는 것이 설계다
            continue
        target = gate.logical_target(tname, col)
        if target is None:
            unclassified.append((tname, col))
            continue
        if tname not in models:
            models[tname] = {"pk": [], "fk": [], "columns": [], "description": ""}
        models[tname]["fk"].append({
            "col": col,
            "ref_table": target[0],
            "ref_col": target[1],
            "src": "logical",
        })
        added += 1

    return models, {"logical_added": added, "degen": degen,
                    "unclassified": unclassified}


# ══════════════════════════════════════════════════════════════════════════════
# 4. Mermaid ERD 생성
# ══════════════════════════════════════════════════════════════════════════════
def sanitize(name):
    return name.replace(" ", "_").replace("-", "_")


def rel_op(src):
    """관계선 연산자. 논리 관계(FK 선언 없음)는 **점선**으로 구분한다.

    Mermaid: `||--o{` = 식별 관계(실선) · `||..o{` = 비식별 관계(점선).
    🔴 점선이 「약한 관계」라는 뜻이 아니다 — **FK 로 선언되어 있지 않다**는 뜻이다.
      조인 경로로서는 실선과 동등하게 유효하다(월 팩트는 반드시 이 축을 써야 한다).
    """
    return "||..o{" if src == "logical" else "||--o{"


def eff_pk(info):
    """유효 PK = 물리 PK 우선, 없으면 YAML 추론 PK.

    🔴🔴 **[2026-08-31 O128 · 착수표 ㉟ · 사용자 결정] 표기에 이 함수를 쓰지 마라.**
      결함 = 이 함수는 두 성격을 **한 목록으로 뭉갠다** ⇒ 물리 PK 가 없는 FACT 11개에서
      dbt 추론 PK(unique + not_null)가 `PK` 로 그려져 독자가 **「grain 이 확정됐다」**로 읽는다.
      실측 = 물리 PK 는 DIM 20/20 · FACT **6/17** 이고, 이는 `06_DDL.sql` 실행규칙 8
      「FACT PK/UNIQUE 는 grain 미확정으로 보류」와 **정합하므로 결함이 아니다** —
      결함은 **ERD 표기가 그 보류를 감춘 것**이다.
      🟢 사용자 결정 = **별 배지로 분리 표기**(①안) ⇒ 표기에는 `phys_pk()` / `infer_pk()` 를 쓴다.
      🟠 이 함수는 「PK 든 추론이든 하나라도 있는가」를 묻는 곳에만 남긴다(성격을 묻지 않는 판정).
    """
    return info.get("pk_live") or info.get("pk") or []


def phys_pk(info):
    """물리 PK 만 — `SHOW PRIMARY KEYS` 로 라이브에서 확인된 것."""
    return info.get("pk_live") or []


def infer_pk(info):
    """dbt 추론 PK 중 **물리 PK 로 확인되지 않은 것만**.

    🔴 판정식 = YAML 의 unique + not_null 조합이지 **선언된 PK 가 아니다**.
      ⇒ 표기는 `UK`(unique key)로 하고 배지·범례로 「grain 확정 아님」을 명시한다.
      🟢 `UK` 를 쓰는 이유 = Mermaid 가 지원하는 제약 중 **의미가 정확히 맞는 것**이다
        (dbt 가 실제로 보증하는 것은 유일성이고 grain 확정이 아니다).
      🔴 물리 PK 가 이미 있으면 여기서 제외한다 — 같은 컬럼을 PK 와 UK 로 두 번 그리지 않는다.
    """
    live = set(info.get("pk_live") or [])
    return [c for c in (info.get("pk") or []) if c not in live]


def _pk_lines(tname, info, col_meta):
    """Mermaid 속성 줄 = 물리 PK 는 `PK` · 추론 PK 는 `UK` + 주석. `(줄목록, 표기컬럼집합)`."""
    out, shown = [], set()
    for pk in phys_pk(info):
        out.append(f"        {_mm_type(_get_type(tname, pk, col_meta))} {pk} PK")
        shown.add(pk)
    for uk in infer_pk(info):
        if uk in shown:
            continue
        out.append(f"        {_mm_type(_get_type(tname, uk, col_meta))} {uk} UK "
                   f'"dbt 추론 · grain 미확정"')
        shown.add(uk)
    return out, shown


def _get_type(table, col, col_meta):
    if col_meta and table in col_meta:
        for c in col_meta[table]:
            if c["name"] == col:
                return c["type"]
    return "NUMBER"


def _mm_type(t):
    """Mermaid erDiagram 은 타입에 괄호·쉼표를 허용하지 않는다 → 정규화."""
    return re.sub(r"[(),]", "_", t).rstrip("_")


def build_full_erd(models, col_meta=None):
    """전체 GOLD 스타스키마 ERD — 키 컬럼만."""
    lines = ["erDiagram"]
    dims = sorted([m for m in models if m.startswith("DIM_")])
    facts = sorted([m for m in models if m.startswith("FACT_")])

    for tname in dims + facts:
        info = models[tname]
        lines.append(f"    {sanitize(tname)} {{")
        pk_lines, shown = _pk_lines(tname, info, col_meta)
        lines.extend(pk_lines)
        for fk in info["fk"]:
            if fk["col"] in shown:
                continue
            lines.append(f"        {_mm_type(_get_type(tname, fk['col'], col_meta))} {fk['col']} FK")
            shown.add(fk["col"])
        lines.append("    }")

    seen = set()
    for tname in dims + facts:
        for fk in models[tname]["fk"]:
            ref = sanitize(fk["ref_table"])
            key = (ref, sanitize(tname), fk["col"])
            if key in seen:
                continue
            seen.add(key)
            op = rel_op(fk.get("src"))
            lines.append(f'    {ref} {op} {sanitize(tname)} : "{fk["col"]}"')
    return "\n".join(lines)


def build_table_erd(tname, models, col_meta=None, with_all_cols=True):
    """단일 테이블 중심 ERD — 해당 테이블 + 직접 연결된 DIM/FACT."""
    info = models.get(tname, {"pk": [], "fk": [], "columns": []})
    related = {fk["ref_table"] for fk in info.get("fk", [])}
    if tname.startswith("DIM_"):
        for mname, minfo in models.items():
            if any(fk["ref_table"] == tname for fk in minfo.get("fk", [])):
                related.add(mname)

    all_tables = {tname} | related
    lines = ["erDiagram"]

    for t in sorted(all_tables):
        ti = models.get(t, {"pk": [], "fk": [], "columns": []})
        lines.append(f"    {sanitize(t)} {{")
        pk_lines, shown = _pk_lines(t, ti, col_meta)
        lines.extend(pk_lines)
        for fk in ti["fk"]:
            if fk["col"] not in shown:
                lines.append(f"        {_mm_type(_get_type(t, fk['col'], col_meta))} {fk['col']} FK")
                shown.add(fk["col"])
        # 중심 테이블만 비즈니스 컬럼 전량 표시(주변 테이블은 키만 → 그림 폭발 방지)
        if with_all_cols and t == tname and col_meta and t in col_meta:
            for c in col_meta[t]:
                if c["name"] not in shown and not c["name"].startswith("DW_"):
                    lines.append(f"        {_mm_type(c['type'])} {c['name']}")
                    shown.add(c["name"])
        lines.append("    }")

    seen = set()
    for t in sorted(all_tables):
        ti = models.get(t, {"fk": []})
        for fk in ti["fk"]:
            if fk["ref_table"] not in all_tables:
                continue
            key = (sanitize(fk["ref_table"]), sanitize(t), fk["col"])
            if key in seen:
                continue
            seen.add(key)
            op = rel_op(fk.get("src"))
            lines.append(f'    {sanitize(fk["ref_table"])} {op} {sanitize(t)} : "{fk["col"]}"')
    return "\n".join(lines)


# ══════════════════════════════════════════════════════════════════════════════
# 5. HTML 문서 생성
# ══════════════════════════════════════════════════════════════════════════════
SRC_BADGE = {
    "both": '<span class="b both" title="dbt relationships 테스트 + 물리 FK 양쪽에 존재">both</span>',
    "yaml": '<span class="b yaml" title="dbt relationships 테스트에만 존재 — 물리 FK 선언 불가/누락">yaml</span>',
    "live": '<span class="b live" title="물리 FK 에만 존재 — dbt relationships 테스트 미작성">live</span>',
    "logical": '<span class="b logical" title="🔴 두 소스 어디에도 없는 논리 관계 — 사람이 판정해 등재했다(gold_erd_coverage_gate.LOGICAL_FK). conform 축이라 FK 선언이 불가하다">logical</span>',
}


#: 🆕 [2026-08-31 O128 · ㉟ · 사용자 결정 ①] PK 성격 배지 — **물리 선언과 dbt 추론을 가른다.**
#:   🔴 종전에는 배지가 없어 두 성격이 같은 `PK` 문안으로 나갔다 ⇒ 「grain 확정」 오독의 원인.
PK_BADGE = {
    "phys": '<span class="b both" title="물리 PRIMARY KEY 로 선언되어 있다 — grain 이 DDL 로 확정됐다">물리</span>',
    "infer": '<span class="b logical" title="🔴 dbt unique + not_null 조합에서 추론한 유일키다. '
             'PRIMARY KEY 로 선언된 것이 아니고 grain 확정을 뜻하지 않는다 — '
             '06_DDL.sql 실행규칙 8 이 FACT PK/UNIQUE 선언을 grain 미확정으로 보류했다">추론 PK*</span>',
    "none": '<span class="b live" title="물리 PK 도 dbt 추론 PK 도 없다 — grain 이 어느 층에서도 선언되지 않았다">미선언</span>',
}


def esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def build_column_table_html(tname, col_meta, pk_cols, fk_rels):
    if not col_meta or tname not in col_meta:
        return '<p><i>컬럼 메타 없음 — --yaml-only 모드로 생성됨</i></p>'
    pk_set = set(pk_cols)
    fk_map = {}
    for fk in fk_rels:
        fk_map.setdefault(fk["col"], []).append(
            f'{fk["ref_table"]}.{fk["ref_col"]} {SRC_BADGE.get(fk.get("src", "yaml"), "")}')
    rows = []
    for c in col_meta[tname]:
        if c["name"] in pk_set:
            role = "🔑 PK"
        elif c["name"] in fk_map:
            role = "🔗 " + "<br>".join(fk_map[c["name"]])
        else:
            role = ""
        rows.append(
            f"<tr><td>{c['ordinal']}</td><td><b>{esc(c['name'])}</b></td>"
            f"<td><code>{esc(c['type'])}</code></td><td>{role}</td>"
            f"<td>{'' if c['nullable'] else '●'}</td><td>{esc(c['comment'])}</td></tr>")
    return ('<table class="col-tbl"><thead><tr><th>#</th><th>컬럼</th><th>타입</th>'
            '<th>역할</th><th>NOT NULL</th><th>설명(COMMENT)</th></tr></thead>'
            f'<tbody>{"".join(rows)}</tbody></table>')


def generate_html(models, col_meta, tbl_info, stats, timestamp, account, lstats=None):
    dims = sorted([m for m in models if m.startswith("DIM_")])
    facts = sorted([m for m in models if m.startswith("FACT_")])

    def rc_label(t):
        d = tbl_info.get(t)
        if not d:
            return "N/A"
        if d["type"] == "VIEW":
            return "VIEW"
        return f"{d['rows']:,}" if d["rows"] is not None else "?"

    toc = ['<li><a href="#overview">📊 전체 스타스키마</a></li>',
           '<li><a href="#fkaudit">🔍 FK 소스 대조</a></li>',
           f'<li class="section">DIM ({len(dims)})</li>']
    toc += [f'<li><a href="#{d}">{d}</a></li>' for d in dims]
    toc.append(f'<li class="section">FACT ({len(facts)})</li>')
    toc += [f'<li><a href="#{f}">{f}</a></li>' for f in facts]

    # FK 대조 섹션
    audit_rows = []
    for t in dims + facts:
        for fk in sorted(models[t]["fk"], key=lambda x: x["col"]):
            audit_rows.append(
                f'<tr><td>{t}</td><td><b>{fk["col"]}</b></td>'
                f'<td>{fk["ref_table"]}.{fk["ref_col"]}</td>'
                f'<td>{SRC_BADGE.get(fk.get("src", "yaml"), "")}</td></tr>')

    sections = []
    for tname in dims + facts:
        info = models[tname]
        desc = re.sub(r"\s+", " ", info.get("description", "")).strip()
        pk = eff_pk(info)
        # 🆕🆕 [2026-08-31 O128 · ㉟ · 사용자 결정 ①] 물리 PK 와 dbt 추론 PK 를 **분리 표기**한다.
        #   🔴 종전 문안은 `PK <컬럼>` 한 줄이어서 물리 PK 부재(FACT 11개)가 보이지 않았다 ⇒
        #     독자가 「grain 이 확정됐다」로 읽었다. 이제 두 줄로 갈라 배지를 붙인다.
        #   🟢 `pk` 변수는 아래 컬럼 상세 표의 PK 강조에만 계속 쓴다(성격을 묻지 않는 용도).
        _phys, _infer = phys_pk(info), infer_pk(info)
        if _phys:
            pk_html = f'PK <code>{", ".join(_phys)}</code> ' + PK_BADGE["phys"]
        else:
            pk_html = 'PK <code>물리 선언 없음</code> ' + PK_BADGE["none"]
        if _infer:
            pk_html += (f' &nbsp;|&nbsp; PK* <code>{", ".join(_infer)}</code> '
                        + PK_BADGE["infer"])
        pk_note = ""
        if _phys and _infer:
            pk_note = (f' <span class="warn">⚠️ 물리 PK 와 dbt 추론 PK 가 다르다 — '
                       f'어느 쪽이 grain 인지 확정하라</span>')

        fk_html = ""
        if info["fk"]:
            items = "".join(
                f'<li><code>{fk["col"]}</code> → <code>{fk["ref_table"]}.{fk["ref_col"]}</code> '
                f'{SRC_BADGE.get(fk.get("src", "yaml"), "")}</li>'
                for fk in sorted(info["fk"], key=lambda x: x["col"]))
            fk_html = f'<div class="box"><b>참조하는 DIM ({len(info["fk"])}):</b><ul>{items}</ul></div>'

        ref_by = ""
        if tname.startswith("DIM_"):
            refs = sorted({f'{m}.{fk["col"]}'
                           for m, mi in models.items()
                           for fk in mi.get("fk", []) if fk["ref_table"] == tname})
            if refs:
                ref_by = ('<div class="box refby"><b>이 DIM 을 참조하는 팩트 '
                          f'({len(refs)}):</b><ul>'
                          + "".join(f"<li><code>{r}</code></li>" for r in refs) + "</ul></div>")

        sections.append(f"""
<section id="{tname}">
  <h2>{"🟦" if tname.startswith("DIM_") else "🟧"} {tname}</h2>
  <div class="meta">행 수 <b>{rc_label(tname)}</b> &nbsp;|&nbsp;
    {pk_html}{pk_note}</div>
  {"<p class='desc'>" + esc(desc) + "</p>" if desc else ""}
  {fk_html}{ref_by}
  <div class="mermaid">{build_table_erd(tname, models, col_meta)}</div>
  <details><summary>컬럼 상세 ({len(col_meta.get(tname, [])) if col_meta else "?"})</summary>
    {build_column_table_html(tname, col_meta, pk, info["fk"])}</details>
</section>""")

    yaml_only_warn = ""
    if stats is None:
        yaml_only_warn = (
            '<div class="alert">'
            '🔴🔴 <b>--yaml-only 모드로 생성됨 — 이 판본은 관계가 불완전하다. '
            '배포·인수인계에 쓰지 마라.</b><br>'
            '빠진 것 ① 물리 FK 에만 있는 관계(실측 18건) ② <b>논리 관계 전량</b> '
            '— 특히 <b>월 conform 축(→ DIM_MONTH)이 통째로 없다</b>.<br>'
            '⚠️ <b>그래서 이 판본은 DIM_MONTH 를 관계선 0개의 고립 섬으로 그린다</b> ⇒ '
            '독자가 월 팩트를 DIM_DATE(일 grain)에 조인해 <b>금액을 월당 일수만큼 과대</b>하게 '
            '집계할 수 있다(<code>DIM_MONTH.MONTH_KEY</code> COMMENT 의 🔴🔴 경고).<br>'
            '③ 컬럼 타입·COMMENT·행 수도 없다.<br>'
            '🟢 <b>전량판 = <code>python3 scripts/gen_gold_erd.py</code></b> (플래그 없이).'
            '</div>')

    stats_html = ""
    if stats:
        logical_row = ""
        if stats.get("logical_added"):
            logical_row = f"""
<tr class="hl3"><th>논리 관계 (3차 소스)</th><td>{stats['logical_added']}</td>
    <td>🔴🔴 <b>두 소스 어디에도 없다</b> — conform 축이라 FK 선언 불가 + dbt 테스트 미작성.
        사람이 판정해 등재했다(<code>gold_erd_coverage_gate.LOGICAL_FK</code>).
        🔴 <b>합집합만 믿으면 이 축이 통째로 사라진다</b></td></tr>"""
        stats_html = f"""
<table class="stat">
<tr><th>dbt YAML relationships</th><td>{stats['yaml_total']}</td>
    <td>relationships 테스트로 선언된 관계</td></tr>
<tr><th>물리 FK (SHOW IMPORTED KEYS)</th><td>{stats['live_total']}</td>
    <td>DDL 로 선언된 정보성 FK (NOT ENFORCED NORELY)</td></tr>
<tr><th>양쪽 일치</th><td>{stats['both']}</td><td>—</td></tr>
<tr class="hl"><th>YAML 에만 존재</th><td>{stats['yaml_only']}</td>
    <td>🔴 물리 FK 선언 불가(DIM_MEMBER SCD2 비유일 참조) — 물리 FK 만 보면 <b>누락</b></td></tr>
<tr class="hl"><th>물리에만 존재</th><td>{stats['live_only']}</td>
    <td>🔴 dbt relationships 테스트 미작성 — YAML 만 보면 <b>누락</b></td></tr>
<tr><th>합집합 (선언된 FK)</th><td>{stats['merged_total']}</td>
    <td>두 소스의 union</td></tr>
{logical_row}
<tr class="tot"><th>총 관계 (본 문서 기준)</th>
    <td><b>{stats.get('total_with_logical', stats['merged_total'])}</b></td>
    <td>ERD 가 표기하는 관계 수 = 선언 FK + 논리 관계</td></tr>
</table>"""

    fanout_warn = ""
    if lstats and lstats.get("logical_added"):
        fanout_warn = f"""
<div class="alert">
🔴🔴 <b>이 ERD 초판(2026-08-31 O126 이전)은 DIM_MONTH 를 관계선 0개의 고립 섬으로 그렸다.</b><br>
원인 = 월 conform 축 {lstats['logical_added']}건이 <b>dbt relationships 에도, 물리 FK 에도 없다</b>
(Snowflake 는 비유일 참조에 FK 를 못 걸고 yml 에도 테스트가 없었다) ⇒ 두 소스 합집합으로도 잡히지 않았다.<br>
⚠️ <b>왜 최악인가</b> — DIM_MONTH 는 <b>fan-out 차단 차원</b>이다. 초판 ERD 는 월 팩트를
DIM_DATE(일 grain)에만 연결해 두어 <b>설계가 막으려던 금액 과대 집계를 오히려 유도</b>했다
(월당 일수만큼 행이 증폭된다 · <code>DIM_MONTH.MONTH_KEY</code> COMMENT 의 🔴🔴 경고).<br>
🟢 <b>현재 판본은 논리 관계를 <span class="b logical">logical</span> 배지 + 점선</b>으로 표기한다.
🔴 <b>점선은 「약한 관계」가 아니라 「FK 로 선언되어 있지 않다」는 뜻</b>이며,
조인 경로로서는 실선과 동등하게 유효하다 — <b>월 팩트는 반드시 DIM_MONTH 를 쓴다.</b>
</div>"""

    return f"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8">
<title>GN_DW.GOLD ERD — 테이블별 문서</title>
<style>
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ font-family: -apple-system, 'Segoe UI', 'Malgun Gothic', sans-serif;
        background: #f4f6f8; color: #222; line-height: 1.55; }}
nav {{ position: fixed; top: 0; left: 0; width: 250px; height: 100vh; overflow-y: auto;
       background: #263238; color: #cfd8dc; padding: 14px 6px; font-size: 12.5px; }}
nav h3 {{ font-size: 14px; margin: 4px 8px 10px; color: #fff; }}
nav ul {{ list-style: none; }}
nav li.section {{ margin: 12px 8px 4px; font-size: 10.5px; font-weight: 700;
                  color: #78909c; letter-spacing: .06em; }}
nav a {{ color: #b0bec5; text-decoration: none; display: block; padding: 3px 9px; border-radius: 3px; }}
nav a:hover {{ background: #37474f; color: #fff; }}
main {{ margin-left: 258px; padding: 26px 30px 60px; max-width: 1180px; }}
h1 {{ font-size: 25px; }}
.sub {{ color: #607d8b; font-size: 13px; margin: 6px 0 20px; }}
section {{ background: #fff; border-radius: 8px; padding: 20px 22px; margin-bottom: 18px;
           box-shadow: 0 1px 3px rgba(0,0,0,.09); }}
h2 {{ font-size: 19px; margin-bottom: 9px; }}
.meta {{ font-size: 13px; color: #546e7a; margin-bottom: 8px; }}
.desc {{ font-size: 13px; background: #fafafa; border-left: 3px solid #b0bec5;
         padding: 8px 11px; margin: 8px 0; color: #37474f; }}
.box {{ font-size: 13px; margin: 8px 0; padding: 9px 12px; background: #f1f8e9;
        border-radius: 5px; }}
.box.refby {{ background: #e3f2fd; }}
.box ul {{ margin: 4px 0 0 18px; }}
details {{ margin-top: 12px; }}
summary {{ cursor: pointer; font-weight: 600; color: #1565c0; font-size: 13px; }}
table {{ border-collapse: collapse; width: 100%; font-size: 12px; margin-top: 8px; }}
th {{ background: #37474f; color: #fff; padding: 6px 9px; text-align: left; font-weight: 600; }}
td {{ padding: 5px 9px; border-bottom: 1px solid #eceff1; vertical-align: top; }}
tr:hover td {{ background: #f5fafd; }}
code {{ background: #eceff1; padding: 1px 5px; border-radius: 3px;
        font-family: ui-monospace, Menlo, monospace; font-size: 11.5px; }}
.mermaid {{ margin: 14px 0; overflow-x: auto; background: #fcfcfc;
            border: 1px solid #eceff1; border-radius: 6px; padding: 10px; }}
.b {{ display: inline-block; font-size: 10px; padding: 1px 6px; border-radius: 9px;
      font-weight: 700; vertical-align: middle; }}
.b.both {{ background: #c8e6c9; color: #1b5e20; }}
.b.yaml {{ background: #ffe0b2; color: #e65100; }}
.b.live {{ background: #bbdefb; color: #0d47a1; }}
.b.logical {{ background: #f8bbd0; color: #880e4f; }}
.alert {{ background: #ffebee; border-left: 4px solid #c62828; padding: 12px 14px;
          border-radius: 5px; font-size: 13px; margin-bottom: 18px; }}
.regen {{ background: #e8f5e9; border-left: 4px solid #2e7d32; padding: 12px 14px;
          border-radius: 5px; font-size: 13px; margin-bottom: 18px; }}
.warn {{ color: #e65100; font-size: 12px; }}
table.stat th {{ width: 230px; }}
table.stat tr.hl td {{ background: #fff8e1; }}
table.stat tr.hl3 td {{ background: #fce4ec; }}
table.stat tr.hl3 th {{ background: #880e4f; }}
table.stat tr.tot th {{ background: #1b5e20; }}
#mmfail {{ display: none; background: #fff3e0; border-left: 4px solid #ef6c00;
           padding: 10px 13px; border-radius: 5px; font-size: 13px; margin-bottom: 16px; }}
</style></head>
<body>
<nav><h3>GOLD ERD</h3><ul>{"".join(toc)}</ul></nav>
<main>
<h1>GN_DW.GOLD 스키마 ERD</h1>
<div class="sub">생성 {timestamp} · 계정 {account} · DIM {len(dims)} · FACT {len(facts)}
  {"· 총 관계 " + str(stats.get("total_with_logical", stats["merged_total"])) if stats else ""}</div>

{yaml_only_warn}{fanout_warn}
<div id="mmfail">
⚠️ <b>Mermaid 렌더러를 불러오지 못했다</b>(오프라인 또는 CDN 차단). 다이어그램은 아래에
<b>텍스트 소스</b>로 그대로 남아 있어 관계를 읽을 수 있다 —
<code>DIM_X ||--o{{ FACT_Y : "COL"</code> 은 실선(선언 FK),
<code>||..o{{</code> 은 점선(논리 관계)이다.
</div>
<div class="regen">
<b>재생성</b> — dbt 파이프라인에서 GOLD 테이블·컬럼·FK 를 바꾼 뒤 아래 <b>순서대로</b> 실행한다.<br>
① <code>python3 scripts/gold_erd_coverage_gate.py</code>
   &nbsp;🔴 <b>먼저 통과시켜라</b> — 미분류 고립이 있으면 그 축이 ERD 에서 빠진다<br>
② <code>python3 scripts/gen_gold_erd.py --label O1NN</code> &nbsp;(권장 · INFORMATION_SCHEMA 조회 ~2초)<br>
&nbsp;&nbsp;&nbsp;🟢 <b>기존 판본은 덮이지 않는다</b> — <b>내용이 실제로 바뀐 경우에만</b>
&nbsp;&nbsp;&nbsp;<code>_archive/_rolling/</code> 로 <code>파일명_YYYYMMDD.html</code> 로 보관한다
&nbsp;&nbsp;&nbsp;(같은 날 두 번째부터 <code>_2</code>·<code>_3</code> · <b>확장자 보존</b>).<br>
&nbsp;&nbsp;&nbsp;🔴 <b>생성 시각만 다르면 보관하지 않는다</b> — 그렇지 않으면 돌릴 때마다 쌓인다
&nbsp;&nbsp;&nbsp;(HTML 이 자기 시각을 본문에 박아 「바이트 동일」 멱등이 듣지 않는다).
&nbsp;&nbsp;&nbsp;⇒ <b>쌓이는 판본 수 = 실제로 바뀐 횟수</b>이지 실행 횟수가 아니다.<br>
&nbsp;&nbsp;&nbsp;🔴 날짜는 <b>이 문서가 선언한 생성일</b>이다(mtime 이 아니다 · 폴백 시 출력에 표시된다).<br>
&nbsp;&nbsp;&nbsp;⚠️ <code>_archive/</code> 최상위의 <b>날짜 폴더</b>(<code>20260830/</code>)는 <b>다른 관례</b>다 —
&nbsp;&nbsp;&nbsp;배포 시점 산출물 <b>세트</b>를 사람이 통째로 이관한 것이고, 위 롤링과 층이 다르다.<br>
③ <code>python3 scripts/test_gold_erd.py</code> &nbsp;(음성 테스트 · 회귀 확인)<br>
⚪ <code>python3 scripts/gen_gold_erd.py --yaml-only</code>
   &nbsp;(컴퓨트 $0 · 🔴 FK 불완전 · 별도 경로에 쓴다)
</div>

<section id="overview">
<h2>📊 전체 스타스키마 ERD</h2>
<p class="desc">FACT → DIM 관계. 키 컬럼(PK·FK)만 표기하고 비즈니스 컬럼은 생략했다.
  <b>실선 = 선언된 FK</b> · <b>점선 = 논리 관계</b>(FK 선언 불가 · 조인 경로로는 동등하게 유효).
  각 테이블 상세는 좌측 목차에서 개별 섹션으로 볼 수 있다.</p>
<div class="alert">
🔑 <b>PK 표기 범례 — 🔴 두 표기는 같은 뜻이 아니다</b>
&nbsp;[2026-08-31 O128 · 착수표 ㉟ 사용자 결정]<br>
&nbsp;&nbsp;&nbsp;<code>PK</code> {PK_BADGE["phys"]} = <b>물리 <code>PRIMARY KEY</code> 로 선언</b>돼 있다
&nbsp;⇒ grain 이 DDL 로 확정됐다.<br>
&nbsp;&nbsp;&nbsp;<code>PK*</code> / 다이어그램의 <code>UK</code> {PK_BADGE["infer"]} =
<b>dbt <code>unique</code> + <code>not_null</code> 에서 추론</b>한 유일키다.<br>
&nbsp;&nbsp;&nbsp;🔴 <b>추론 PK 는 grain 확정을 뜻하지 않는다.</b>
<code>06_DDL.sql</code> 실행규칙 8 이 <b>FACT 의 PK/UNIQUE 선언을 grain 미확정으로 보류</b>했고,
물리 PK 는 <b>DIM 20/20 · FACT 6/17</b> 이다(실측) — <b>정합이며 결함이 아니다</b>.<br>
&nbsp;&nbsp;&nbsp;🔴 종전 판본은 물리 PK 가 없으면 <b>추론 PK 를 그대로 <code>PK</code> 로 표기</b>해
독자가 「grain 이 확정됐다」로 읽을 수 있었다 ⇒ <b>이 판본에서 두 성격을 분리했다.</b>
</div>
<div class="mermaid">{build_full_erd(models, col_meta)}</div>
</section>

<section id="fkaudit">
<h2>🔍 FK 소스 대조</h2>
<p class="desc">🔴 <b>세 소스는 서로를 포함하지 않는다</b> — 이 ERD 는 <b>3중 합집합</b>을 쓴다.
  한쪽만 근거로 ERD 를 그리면 관계가 조용히 빠진다.
  🔴 <b>「관계 수가 늘었는가」가 판정식이 아니다</b> — 판정식은
  <b>「고립 키 컬럼이 전부 분류되었는가」</b>이고, 그것을
  <code>gold_erd_coverage_gate.py</code> 가 blocking 으로 강제한다.</p>
{stats_html}
<details><summary>전체 관계 목록 ({sum(len(models[t]["fk"]) for t in dims + facts)})</summary>
<table><thead><tr><th>팩트/차원</th><th>키 컬럼</th><th>참조 대상</th><th>출처</th></tr></thead>
<tbody>{"".join(audit_rows)}</tbody></table></details>
</section>

{"".join(sections)}
</main>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>
if (typeof mermaid === 'undefined') {{
  document.getElementById('mmfail').style.display = 'block';
  document.querySelectorAll('.mermaid').forEach(function (d) {{
    d.style.whiteSpace = 'pre'; d.style.fontFamily = 'ui-monospace, Menlo, monospace';
    d.style.fontSize = '11px';
  }});
}} else {{
  mermaid.initialize({{ startOnLoad: true, theme: 'neutral',
    er: {{ useMaxWidth: true, layoutDirection: 'TB' }} }});
}}
</script>
</body></html>"""


# ══════════════════════════════════════════════════════════════════════════════
# 5-B. 산출물 회전 — 내용이 **실제로 바뀐 경우에만** `_archive/_rolling/` 에 보관한다
# ══════════════════════════════════════════════════════════════════════════════
#   🆕 [2026-08-31 O126 · 사용자 요청] 종전 판본은 기존 HTML 을 **말없이 덮었다**
#      ⇒ 과거 판본을 되돌릴 수 없었다(이 워크스페이스가 4번 당한 「조용한 소실」 축).
#   🔴 **`scripts/snapshot_util.py` 만 경유한다**(`R1-7-10`) — 여기서 경로를 조립하면
#      그 조문의 우회이고, 「덮지 않는다」 불변식(바이트 동일 재사용 · 접미 · 소진 시 예외)을
#      잃는다. 이름 규칙 2종(`snapshot_name` · `dated_snapshot_name`)도 그 모듈에 있다.
#   🟢 **복사 후 덮어쓰기**를 쓴다(이동이 아니다) — HTML 문자열을 **다 만든 뒤에** 회전하므로
#      생성이 실패하면 애초에 여기 오지 않고 기존 파일이 그대로 남는다.
#
#   🔴🔴 **[O126 개정 ② · 사용자 승인] `snapshot_util` 의 「바이트 동일이면 재사용」 멱등은
#      이 산출물에 원리적으로 듣지 않았다.** HTML 이 자기 생성 시각을 본문에 박기 때문에
#      **내용이 같아도 바이트가 항상 다르다** ⇒ 돌릴 때마다 새 판본이 쌓였다.
#      실측 = 검증용 3판본의 차이가 **생성 시각 한 줄뿐**이었다(diff 다른 줄 2 = 그 줄의 -/+).
#      🟢 처방 = **타임스탬프를 제외한 내용**으로 비교해 **실제 변경이 없으면 회전하지 않는다.**
#      🔴 그래도 **새 HTML 은 항상 쓴다** — 생성 시각이 갱신되어야
#        「생성 시각이 방금인가」라는 성공 판정(산출물 상단 자기표기)이 유효하다.
#        ⇒ 판정식 = **「돌린 횟수」가 아니라 「실제로 바뀐 횟수」만큼 쌓인다.**
#
#   🔴 **[O126 개정 ① · 사용자 승인] 롤링 백업은 `_archive/_rolling/` 으로 격리한다.**
#      이유 = `_archive/` 최상위에는 **날짜 폴더**(`20260830/`)에 산출물 세트를 통째로
#      담는 별개 관례가 있다(수동 이관 · 목적 = 특정일 배포본 전체 보존 · ③ 현행 유지).
#      두 방식은 **다른 질문에 답한다** — 날짜 폴더 = 릴리스 태그(영구) ·
#      롤링 = undo 버퍼(임시) ⇒ **같은 층에 섞으면 「어느 것이 이력의 정본이냐」가 모호**해진다
#      (`R3-9 ㉡` 「같은 것을 다르게 재는 지점」). 층을 나누면 중복이 아니다.
ARCHIVE_DIR = os.path.join(ROOT, "30_output_share", "_archive", "_rolling")

#: 비교에서 제외할 휘발성 패턴 — 생성 시각만 지운다.
#: 🔴 계정·DIM/FACT 수는 **지우지 않는다** — 그것이 바뀌면 **실질 변경**이다
#:   (넓게 지우면 진짜 변경을 놓친다 · `P130` 「넓은 판정식」의 반대 실수).
VOLATILE_RE = re.compile(r"생성\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}")


def normalize_for_compare(html):
    """생성 시각을 자리표시자로 바꾼 문자열 — 「실질 변경」 판정의 분모."""
    return VOLATILE_RE.sub("생성 <TS>", html)


def artifact_date(path):
    """산출물의 「생성일」을 `(YYYYMMDD, 판정축)` 으로 돌려준다.

    🔴 판정 순서 = ① HTML 이 **스스로 선언한** 생성 시각(`생성 YYYY-MM-DD HH:MM`)
                   ② 없으면 파일 mtime.
      ⇒ ① 을 먼저 쓰는 이유 = 그것이 **그 문서가 주장하는 값**이고 회전 이름은 그 주장을
        보존해야 한다. mtime 은 복사·마운트 동기화로 바뀔 수 있어 문서 내용과 어긋난다
        (이 워크스페이스는 스테이지 마운트라 mtime 이 재작성 시각으로 갱신된다).

    🔴🔴 **[O126 자기시정] 초판은 앞 4,096자만 읽어 ① 을 놓치고 조용히 ② 로 폴백했다.**
      실측 = 선언 문구는 문자 오프셋 **5,644**(CSS 블록 뒤)에 있다 ⇒ 창 밖이었다.
      ⚠️ **두 축이 같은 날짜를 냈기 때문에 결과가 정상처럼 보였다** — 「0건」이 「없다」가
        아니라 **「내 판정식이 못 본다」**였던 것이다(`O111 ㉠`).
      🟢 처방 = ㉠ 창을 헤더 전체가 들어가도록 넓힌다 ㉡ **폴백을 침묵시키지 않고
        판정 축을 반환해 호출자가 출력**한다 ㉢ 음성 테스트로 두 축을 각각 단정한다.
      🔴 창 크기를 늘리는 것만으로는 부족하다 — 레이아웃이 바뀌면 또 밀린다 ⇒
        **판정 축을 노출하는 것이 본질적 처방**이다(수치가 우연히 맞는 것에 의존하지 않는다).
    """
    #: 헤더 탐색 창(문자). 🔴 선언 문구 실측 위치 5,644 의 약 6배 여유.
    #:   그래도 못 찾으면 mtime 으로 가지만 **그 사실이 출력된다**.
    HEAD_CHARS = 32768
    try:
        head = open(path, encoding="utf-8", errors="replace").read(HEAD_CHARS)
    except OSError:
        head = ""
    m = re.search(r"생성\s+(\d{4})-(\d{2})-(\d{2})", head)
    if m:
        return "".join(m.groups()), "선언"
    ts = datetime.fromtimestamp(os.path.getmtime(path))
    return ts.strftime("%Y%m%d"), "mtime(🟠 선언 문구를 찾지 못했다)"


def rotate_previous(out_path, new_html=None, label=None, archive=None):
    """기존 산출물이 **실질적으로 달라졌을 때만** `_archive/_rolling/` 에 보관한다.

    반환 =
      · `None`                                     — 기존 파일이 없다(첫 생성)
      · `("unchanged", None, date, axis)`          — 실질 변경 0 ⇒ 회전 생략
      · `(스냅샷경로, 상태, date, axis)`            — 보관했다(상태 = created/reused/suffixed)

    🔴 `new_html` 을 주지 않으면 **무조건 회전**한다(종전 동작) — 비교할 대상이 없으므로
      「변경 없음」을 단정할 수 없고, 그럴 때는 **보관하는 쪽이 안전**하다.
    🔴 실패를 삼키지 않는다 — 보관에 실패하면 **예외를 올려 새 파일을 쓰지 못하게** 한다
      (보관 없이 덮으면 그것이 바로 고치려던 결함이다).

    🆕 🔴🔴 **[O126 자기시정] `archive` 주입 지점이 없어 음성 테스트가 실 `_archive/` 를
      더럽혔다.** 실측 = 축12-e·축12-f 가 임시 디렉터리를 만들어 놓고도 보관본을
      `30_output_share/_archive/_rolling/OUT_20260830.html` 로 썼다(모듈 상수를 썼으므로).
      ⚠️ 테스트는 **전건 통과했다** — 오염은 판정에 나타나지 않았다.
      🟢 `snapshot_util` docstring 이 이미 경고한 함정이다(「`archive=` 를 넘겨라 — 안 넘기면
        테스트가 패치한 경로를 벗어나 실 `_archive/` 를 더럽힌다」) ⇒ **그 경고를 이 함수가
        받지 못하고 있었던 것**이 결함이다. 이제 인자로 받고 테스트가 그것을 넘긴다.
    """
    if not os.path.exists(out_path):
        return None
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    from snapshot_util import snapshot, dated_snapshot_name

    date_str, src = artifact_date(out_path)

    if new_html is not None:
        try:
            old = open(out_path, encoding="utf-8", errors="replace").read()
        except OSError:
            old = None                      # 🔴 읽기 실패는 「같다」로 읽지 않는다 → 회전한다
        if old is not None and normalize_for_compare(old) == normalize_for_compare(new_html):
            return "unchanged", None, date_str, src

    snap, status = snapshot(
        out_path, "prerun", label=label,
        archive=archive if archive is not None else ARCHIVE_DIR,
        name=dated_snapshot_name(out_path, date_str), keep_ext=True)
    return snap, status, date_str, src


# ══════════════════════════════════════════════════════════════════════════════
# 6. 메인
# ══════════════════════════════════════════════════════════════════════════════
def main():
    print("[1/6] dbt schema YAML 파싱 (비용 $0)...")
    models = parse_dbt_schema(SCHEMA_YML)
    if os.path.exists(WIDE_YML):
        models.update(parse_dbt_schema(WIDE_YML))
    yaml_fk = sum(len(v["fk"]) for v in models.values())
    print(f"      → 모델 {len(models)} · YAML FK {yaml_fk}")

    col_meta, tbl_info, stats, account = None, {}, None, "(미조회)"
    lstats = None

    if not YAML_ONLY:
        sys.path.insert(0, os.path.join(ROOT, "scripts"))
        import sfconn
        import gold_erd_coverage_gate as gate
        cn = sfconn.conn()
        try:
            print("[2/6] INFORMATION_SCHEMA 컬럼 메타...")
            col_meta = fetch_column_meta(cn)
            print(f"      → 컬럼 {sum(len(v) for v in col_meta.values())}")

            print("[3/6] 물리 PK/FK + 행 수...")
            live_fk = fetch_live_fk(cn)
            live_pk = fetch_live_pk(cn)
            tbl_info = fetch_table_rows(cn)
            fact_keys = gate.fetch_key_columns(cn)
            cur = cn.cursor()
            cur.execute("SELECT CURRENT_ACCOUNT()")
            account = cur.fetchone()[0]
            print(f"      → 물리 FK {len(live_fk)} · 물리 PK {len(live_pk)}테이블 "
                  f"· 객체 {len(tbl_info)} · 키 컬럼 {len(fact_keys)} "
                  f"(분모 = {'·'.join(gate.KEY_TABLE_PREFIXES)})")

            print("[4/6] FK 합집합 병합...")
            models, stats = merge_fk_sources(models, live_fk)
            models = merge_pk_sources(models, live_pk)
            print(f"      → YAML만 {stats['yaml_only']} · 물리만 {stats['live_only']} "
                  f"· 양쪽 {stats['both']} ⇒ 병합 {stats['merged_total']}")

            print("[5/6] 논리 관계 병합 (3차 소스)...")
            models, lstats = merge_logical_fk(models, fact_keys, live_pk)
            stats["logical_added"] = lstats["logical_added"]
            stats["total_with_logical"] = stats["merged_total"] + lstats["logical_added"]
            print(f"      → 논리 관계 +{lstats['logical_added']} "
                  f"· degen(관계 없음이 설계) {lstats['degen']} "
                  f"· 🔴 미분류 {len(lstats['unclassified'])}")
            if lstats["unclassified"]:
                print("      🔴🔴 미분류 고립이 있다 — ERD 에 그 축이 빠진다. 중단한다.")
                for t, c in lstats["unclassified"]:
                    print(f"         · {t}.{c}")
                print("      ⇒ scripts/gold_erd_coverage_gate.py 의 KNOWN_ORPHANS 에 "
                      "분류·사유를 등재한 뒤 재실행하라.")
                return 1
        finally:
            cn.close()
    else:
        print("[2/6] --yaml-only: INFORMATION_SCHEMA 스킵")
        print("[3/6]~[5/6] 스킵 · 🔴 FK 불완전 + 논리 관계 병합 불가")
        for info in models.values():
            info.setdefault("pk_live", [])

    out_path = OUT_HTML_YAML if YAML_ONLY else OUT_HTML
    print("[6/6] HTML 생성...")
    ts = datetime.now().strftime("%Y-%m-%d %H:%M")
    html = generate_html(models, col_meta, tbl_info, stats, ts, account, lstats)

    # 🔴 [O126] 기존 산출물을 **먼저 보관**한 뒤에 쓴다. 보관 실패는 예외로 올라가
    #    새 파일 쓰기에 도달하지 않는다 ⇒ 「보관 없이 덮는」 경로가 원리적으로 없다.
    #    🟢 개정 ② = 생성 시각을 제외한 내용이 같으면 **회전을 생략**한다(새 HTML 은 그래도 쓴다).
    rot = rotate_previous(out_path, new_html=html, label=LABEL)
    if rot is None:
        print("      · 기존 산출물 없음 — 보관 생략(첫 생성)")
    elif rot[0] == "unchanged":
        _, _, date_str, date_src = rot
        print("      · 🟢 실질 변경 0 — 회전 생략 "
              "(생성 시각 외 내용이 기존 판본과 동일하다)")
        print(f"        기존 판본 생성일 {date_str} · 판정 축 = {date_src}")
        print("        ⇒ 🔴 새 HTML 은 그래도 쓴다 — 생성 시각이 갱신되어야 "
              "「방금 돌았다」를 증명할 수 있다.")
    else:
        snap, status, date_str, date_src = rot
        note = {"created": "보관", "reused": "기존 보관본 재사용(바이트 동일)",
                "suffixed": "🟠 같은 날 다른 판본 존재 → 접미 신설"}[status]
        print(f"      · 실질 변경 있음 ⇒ 기존 판본 {note} → "
              f"{os.path.relpath(snap, ROOT)}")
        print(f"        (생성일 {date_str} · 판정 축 = {date_src})")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)

    dims = [m for m in models if m.startswith("DIM_")]
    facts = [m for m in models if m.startswith("FACT_")]
    print(f"\n✅ {out_path}")
    if stats:
        print(f"   DIM {len(dims)} · FACT {len(facts)} · "
              f"관계 {stats['total_with_logical']} "
              f"(선언 FK {stats['merged_total']} + 논리 {stats['logical_added']})")
    else:
        print(f"   DIM {len(dims)} · FACT {len(facts)} · FK {yaml_fk} (🔴 불완전)")
    if tbl_info:
        tot = sum(v["rows"] or 0 for v in tbl_info.values() if v["type"] == "BASE TABLE")
        print(f"   BASE TABLE 총 행 수 {tot:,}")
    if YAML_ONLY:
        print("   🔴 이 산출물은 FK 가 불완전하다 — 배포·인수인계에 쓰지 마라.")
        print(f"   🟢 전량판 = 플래그 없이 재실행 → {OUT_HTML}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
