# GN_DW 아키텍처 지도 HTML 을 라이브 INFORMATION_SCHEMA + dbt 모델 리니지로 전량 재생성한다.
# Co-authored with CoCo
#
# 왜: 30_output_share/20260826_아키텍처 지도 요약본.html 초판은 노드 목록의 상당 부분이 창작이었다
#     ("총 54개 채우기 위한 명세" · GA4_RAW_EVENTS_01 · TM_BZ_* · AGENCY_MEDIA_COST 등).
#     R2-3(원본 실측) · R2-4(스캔 결과가 완료 기준)에 따라 라이브 스캔 결과만 근거로 삼는다.
#
# 입력 = ① GN_DW.INFORMATION_SCHEMA (객체·컬럼·COMMENT) ② SHOW PRIMARY/IMPORTED KEYS
#        ③ 10_dbt_pipeline/models/**/*.sql 의 source()/ref() ④ SERVING 뷰 정의 문자열
# 출력 = 30_output_share/20260826_아키텍처 지도 요약본.html (인라인 데이터 · 외부 fetch 없음)

import json
import os
import re
import sys
from collections import defaultdict

import snowflake.connector

ROOT = "/workspace"
MODELS = os.path.join(ROOT, "10_dbt_pipeline", "models")
OUT = os.path.join(ROOT, "30_output_share", "20260826_아키텍처 지도 요약본.html")

BRONZE_SCHEMAS = ("BRONZE_CRM", "BRONZE_ERP", "BRONZE_AGENCY")
ALL_SCHEMAS = BRONZE_SCHEMAS + ("SILVER", "GOLD", "SERVING")


def connect():
    """🆕 [2026-08-30 O123-C] `sfconn` 경유로 시정 — 종전 판본은 계정·사용자·역할·웨어하우스를
    **하드코딩**했다(`account="zl50263.ap-northeast-2.aws"` · `user="CHOIH"` ·
    `role="GN_DW_ADMIN"` · `warehouse="GN_DW_DEV_WH"`).
    🔴 이 워크스페이스는 **계정이 계속 바뀐다**(O120 `YQ47212` → O123 `KA98941` · `P169` 축)
      ⇒ 하드코딩은 시간이 지나면 반드시 깨진다. 실제로 이 세션에서 **403 Forbidden** 으로 실패했고
      그것이 이 제네레이터만 산출물을 만들지 못한 유일한 원인이었다.
    🟢 판정식 = **접속 정보는 도구마다 적지 말고 단일 경유점(`scripts/sfconn.py`)에서 받는다**
      (그 헬퍼는 `SNOWFLAKE_ACCOUNT`·`SNOWFLAKE_HOST` 환경변수와 세션 OAuth 토큰을 쓴다).
    🔴 계정명을 이 파일에 다시 적지 마라 — 산출물 HTML 의 계정 표기는
      아래 `select current_account()` **조회 결과**로 채운다(맥락이지 근거가 아니다 · `R3-9 ㉤`)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sfconn
    return sfconn.conn()


def fmt_type(dt, clen, nprec, nscale, dtprec):
    if dt in ("TEXT", "VARCHAR", "CHAR", "STRING"):
        return "VARCHAR(%s)" % clen if clen is not None else "VARCHAR"
    if dt in ("NUMBER", "DECIMAL", "NUMERIC"):
        if nprec is None:
            return "NUMBER"
        return "NUMBER(%d,%d)" % (nprec, nscale or 0)
    if dt in ("TIMESTAMP_NTZ", "TIMESTAMP_LTZ", "TIMESTAMP_TZ"):
        return "%s(%s)" % (dt, dtprec if dtprec is not None else 9)
    return dt


def domain_of(schema, name, silver_folder=None):
    if schema == "BRONZE_CRM":
        return "CRM"
    if schema == "BRONZE_ERP":
        return "ERP"
    if schema == "BRONZE_AGENCY":
        return "AGENCY"
    if silver_folder:
        return {"crm": "CRM", "agency": "AGENCY", "erp": "ERP",
                "ga4": "GA4", "bridge": "GA4"}.get(silver_folder, "CRM")
    n = name.upper()
    if n.startswith("ML_"):
        return "ML"
    if "GA4" in n or "GA_" in n or "BIGQUERY" in n or "IDENTITY" in n or n.endswith("DEVICE"):
        return "GA4"
    if "AD_" in n or "AGENCY" in n or "MARKETING" in n or "CREATIVE" in n:
        return "AGENCY"
    if "BUDGET" in n or n.startswith("ERP_"):
        return "ERP"
    return "CRM"


def layer_of(schema, ttype):
    if schema.startswith("BRONZE_"):
        return "BRONZE"
    if schema == "SILVER":
        return "SILVER"
    if schema == "GOLD":
        return "WIDE" if ttype == "VIEW" else "GOLD"
    if schema == "SERVING":
        return "SERVING"
    return None


# ---------------------------------------------------------------- dbt 리니지
RE_SOURCE = re.compile(r"source\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)")
RE_REF = re.compile(r"ref\(\s*['\"]([^'\"]+)['\"]\s*\)")

# _sources.yml 의 source 이름 → 실제 스키마
SOURCE_SCHEMA = {
    "bronze_crm": "BRONZE_CRM",
    "bronze_erp": "BRONZE_ERP",
    "bronze_agency": "BRONZE_AGENCY",
    "bronze_bigquery": "BRONZE_BIGQUERY",
    "silver_external": "SILVER",
}


def scan_dbt_models():
    """returns (model_name -> {'folder':..,'layer_dir':..}, links[(from_key,to_key)])"""
    models = {}
    raw_edges = []
    for dirpath, _dirs, files in os.walk(MODELS):
        for fn in files:
            if not fn.endswith(".sql"):
                continue
            model = fn[:-4]
            rel = os.path.relpath(dirpath, MODELS).split(os.sep)
            layer_dir = rel[0] if rel else ""
            folder = rel[1] if len(rel) > 1 else ""
            models[model.upper()] = {"folder": folder, "layer_dir": layer_dir}
            with open(os.path.join(dirpath, fn), encoding="utf-8") as f:
                sql = f.read()
            # 주석 제거 — 폐기된 참조가 리니지로 잡히는 것을 막는다
            sql = re.sub(r"--[^\n]*", "", sql)
            sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
            for src, tbl in set(RE_SOURCE.findall(sql)):
                sch = SOURCE_SCHEMA.get(src)
                if sch:
                    raw_edges.append(("%s.%s" % (sch, tbl.upper()), model.upper()))
            for r in set(RE_REF.findall(sql)):
                raw_edges.append((r.upper(), model.upper()))
    return models, raw_edges


def main():
    conn = connect()
    cur = conn.cursor()

    cur.execute("SELECT CURRENT_ACCOUNT()")
    account = cur.fetchone()[0]

    cur.execute(
        """
        SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, ROW_COUNT, COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA IN (%s)
        ORDER BY TABLE_SCHEMA, TABLE_NAME
        """ % ",".join("'%s'" % s for s in ALL_SCHEMAS)
    )
    tables = cur.fetchall()

    cur.execute(
        """
        SELECT TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE,
               CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE,
               DATETIME_PRECISION, IS_NULLABLE, COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA IN (%s)
        ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
        """ % ",".join("'%s'" % s for s in ALL_SCHEMAS)
    )
    cols = cur.fetchall()

    pk = set()
    cur.execute("SHOW PRIMARY KEYS IN DATABASE GN_DW")
    for row in cur.fetchall():
        d = dict(zip([c[0].lower() for c in cur.description], row))
        pk.add((d["schema_name"], d["table_name"], d["column_name"]))

    fk = set()
    try:
        cur.execute("SHOW IMPORTED KEYS IN DATABASE GN_DW")
        for row in cur.fetchall():
            d = dict(zip([c[0].lower() for c in cur.description], row))
            fk.add((d["fk_schema_name"], d["fk_table_name"], d["fk_column_name"]))
    except Exception as exc:  # noqa: BLE001
        print("  [warn] SHOW IMPORTED KEYS 실패: %s" % exc)

    cur.execute(
        """
        SELECT TABLE_SCHEMA, TABLE_NAME, VIEW_DEFINITION
        FROM GN_DW.INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = 'SERVING'
        """
    )
    serving_defs = cur.fetchall()

    # Semantic View 는 INFORMATION_SCHEMA.TABLES 에 나오지 않는다 → SHOW/DESCRIBE 로 잰다.
    svs = []
    cur.execute("SHOW SEMANTIC VIEWS IN DATABASE GN_DW")
    sv_rows = cur.fetchall()
    sv_cols = [c[0].lower() for c in cur.description]
    for row in sv_rows:
        d = dict(zip(sv_cols, row))
        svs.append({
            "schema": d["schema_name"],
            "name": d["name"],
            "comment": (d.get("comment") or "").strip(),
        })

    # 각 SV 의 base table 과 노출 차원·메트릭
    sv_detail = {}
    for sv in svs:
        fq = "GN_DW.%s.%s" % (sv["schema"], sv["name"])
        tbl_props = defaultdict(dict)     # 논리테이블명 → {DB,SCHEMA,NAME}
        mem_props = {}                    # (kind, name) → {EXPRESSION, DATA_TYPE, COMMENT}
        order = []
        try:
            cur.execute("DESCRIBE SEMANTIC VIEW %s" % fq)
            rows = cur.fetchall()
            dcols = [c[0].lower() for c in cur.description]
            for row in rows:
                d = dict(zip(dcols, row))
                kind = (d.get("object_kind") or "").upper()
                oname = d.get("object_name") or ""
                prop = (d.get("property") or "").upper()
                pval = d.get("property_value")
                pval = "" if pval is None else str(pval).replace('"', "")
                if kind == "TABLE":
                    if prop in ("BASE_TABLE_DATABASE_NAME", "BASE_TABLE_SCHEMA_NAME",
                                "BASE_TABLE_NAME"):
                        tbl_props[oname][prop] = pval
                elif kind in ("DIMENSION", "METRIC", "FACT"):
                    key = (kind, oname)
                    if key not in mem_props:
                        mem_props[key] = {}
                        order.append(key)
                    if prop in ("EXPRESSION", "DATA_TYPE", "COMMENT"):
                        mem_props[key][prop] = pval
        except Exception as exc:  # noqa: BLE001
            print("  [warn] DESCRIBE SEMANTIC VIEW %s 실패: %s" % (fq, exc))
        bases = []
        for _lt, p in tbl_props.items():
            if p.get("BASE_TABLE_NAME"):
                bases.append("%s.%s" % (p.get("BASE_TABLE_SCHEMA_NAME", ""),
                                        p["BASE_TABLE_NAME"]))
        members = [{"k": k, "n": n,
                    "t": mem_props[(k, n)].get("DATA_TYPE", ""),
                    "e": mem_props[(k, n)].get("EXPRESSION", ""),
                    "d": mem_props[(k, n)].get("COMMENT", "")}
                   for (k, n) in order]
        sv_detail[sv["name"]] = {"bases": sorted(set(bases)), "members": members}

    agent_cnt = 0
    try:
        cur.execute("SHOW AGENTS IN DATABASE GN_DW")
        agent_cnt = len(cur.fetchall())
    except Exception as exc:  # noqa: BLE001
        print("  [warn] SHOW AGENTS 실패: %s" % exc)

    cur.close()
    conn.close()

    # ---------------------------------------------------------------- 노드
    dbt_models, raw_edges = scan_dbt_models()

    nodes = []
    key_of_name = {}          # 단순명(대문자) → 노드 key (SILVER/GOLD/SERVING 유일명 가정)
    node_by_key = {}
    for sch, name, ttype, rowcnt, tcomment in tables:
        layer = layer_of(sch, ttype)
        if layer is None:
            continue
        info = dbt_models.get(name.upper())
        folder = info["folder"] if (info and sch == "SILVER") else None
        key = "%s.%s" % (sch, name)
        node = {
            "id": key,
            "label": name,
            "schema": sch,
            "layer": layer,
            "domain": domain_of(sch, name, folder),
            "rows": int(rowcnt) if rowcnt is not None else None,
            "type": "VIEW" if ttype == "VIEW" else "TABLE",
            "dbt": bool(info),
            "comment": (tcomment or "").strip(),
        }
        nodes.append(node)
        node_by_key[key] = node
        key_of_name.setdefault(name.upper(), key)

    # BRONZE 는 원천 선언·dbt 참조가 있는 것만 남긴다(적재만 되고 미사용인 테이블은 지도 밖).
    referenced_bronze = {f for f, _t in raw_edges if f.startswith("BRONZE_")}

    # ---------------------------------------------------------------- 링크
    links = []
    seen = set()
    for src, dst in raw_edges:
        fkey = src if "." in src else key_of_name.get(src)
        tkey = key_of_name.get(dst)
        if not fkey or not tkey:
            continue
        if fkey not in node_by_key or tkey not in node_by_key:
            continue
        if (fkey, tkey) in seen or fkey == tkey:
            continue
        seen.add((fkey, tkey))
        links.append({"from": fkey, "to": tkey})

    # SERVING 뷰 → 참조 객체 (뷰 정의 문자열에서 추출)
    for sch, name, vdef in serving_defs:
        tkey = "%s.%s" % (sch, name)
        if tkey not in node_by_key or not vdef:
            continue
        body = re.sub(r"--[^\n]*", "", vdef)
        for m in re.finditer(r"\b(GOLD|SILVER|SERVING)\.([A-Z0-9_]+)", body.upper()):
            fkey = "%s.%s" % (m.group(1), m.group(2))
            if fkey in node_by_key and fkey != tkey and (fkey, tkey) not in seen:
                seen.add((fkey, tkey))
                links.append({"from": fkey, "to": tkey})

    # 노드 정리 — 미참조 BRONZE 제거
    nodes = [n for n in nodes
             if n["layer"] != "BRONZE" or n["id"] in referenced_bronze]
    live_keys = {n["id"] for n in nodes}
    links = [l for l in links if l["from"] in live_keys and l["to"] in live_keys]

    # ---------------------------------------------------------------- SEMANTIC 계층
    # SV 는 INFORMATION_SCHEMA.TABLES 에 없으므로 별도 노드로 편입한다.
    sv_columns = {}
    for sv in svs:
        key = "SV::%s.%s" % (sv["schema"], sv["name"])
        det = sv_detail.get(sv["name"], {"bases": [], "members": []})
        nodes.append({
            "id": key,
            "label": sv["name"],
            "schema": sv["schema"],
            "layer": "SEMANTIC",
            "domain": domain_of(sv["schema"], sv["name"]),
            "rows": None,
            "type": "SEMANTIC VIEW",
            "dbt": False,
            "comment": sv["comment"],
        })
        live_keys.add(key)
        for b in det["bases"]:
            if b in live_keys and (b, key) not in seen:
                seen.add((b, key))
                links.append({"from": b, "to": key})
        sv_columns[key] = [
            {"n": m["n"], "t": m["t"] or "",
             "k": {"METRIC": "METRIC", "FACT": "FACT"}.get(m["k"], "DIM"),
             "z": "",
             "d": (("%s · 식 = %s" % (m["d"], m["e"])) if m["d"] else ("식 = %s" % m["e"]))}
            for m in det["members"]
        ]

    # ---------------------------------------------------------------- 컬럼
    columns = defaultdict(list)
    for (sch, tbl, ordi, cname, dt, clen, nprec, nscale, dtprec, nullable, ccomment) in cols:
        key = "%s.%s" % (sch, tbl)
        if key not in live_keys:
            continue
        columns[key].append({
            "n": cname,
            "t": fmt_type(dt, clen, nprec, nscale, dtprec),
            "k": "PK" if (sch, tbl, cname) in pk
                 else ("FK" if (sch, tbl, cname) in fk else ""),
            "z": "" if nullable == "YES" else "NN",
            "d": (ccomment or "").strip(),
        })

    # ---------------------------------------------------------------- 집계
    columns.update(sv_columns)
    by_layer = defaultdict(int)
    for n in nodes:
        by_layer[n["layer"]] += 1
    print("계정 = %s" % account)
    for lk in ("BRONZE", "SILVER", "GOLD", "WIDE", "SERVING", "SEMANTIC"):
        print("  %-9s 노드 %3d" % (lk, by_layer[lk]))
    print("  링크 %d · 컬럼/멤버 %d (노드 %d 중 명세보유 %d) · Agent %d"
          % (len(links), sum(len(v) for v in columns.values()),
             len(nodes), len(columns), agent_cnt))

    write_html(OUT, account, nodes, links, columns, by_layer, agent_cnt)
    print("작성 = %s (%d bytes)" % (OUT, os.path.getsize(OUT)))


# ---------------------------------------------------------------- HTML 생성
CHUNK = 600      # 긴 문자열 분할 단위 (R1-5-1 한 줄 2000자 상한 대응)


def chunk_long(obj):
    """긴 문자열을 청크 배열로 바꾼다. JS 쪽 tx() 가 join 해 복원한다.

    왜: SV·컬럼 COMMENT 가 최대 2,000자를 넘어 한 줄로 쓰면 `read` 가 절단한다(지침 R1-5-2).
        값을 자르지 않고 **줄만 나눈다** — 정보 손실 0.
    """
    if isinstance(obj, str):
        if len(obj) > CHUNK:
            return [obj[i:i + CHUNK] for i in range(0, len(obj), CHUNK)]
        return obj
    if isinstance(obj, dict):
        return {k: chunk_long(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [chunk_long(v) for v in obj]
    return obj


def jline(obj, indent="  "):
    """한 줄이 1000자를 넘지 않도록 필요 시 청크 분할 + 다행 출력한다."""
    compact = json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    if len(compact) + len(indent) <= 1000:
        return indent + compact
    pretty = json.dumps(chunk_long(obj), ensure_ascii=False, indent=2)
    return "\n".join(indent + ln for ln in pretty.splitlines())


HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GN_DW 아키텍처 통합 지도 (라이브 실측 · 계정 {account})</title>
<style>
:root {{
  --bg-color:#f4f6f9; --layer-bg:#ffffff; --text-main:#2c3e50; --text-sub:#7f8c8d;
  --border-color:#e0e6ed; --chip-bg:#eef2f5; --chip-border:#dcdde1;
  --hover-bg:#3498db; --hover-border:#2980b9; --active-bg:#e74c3c; --active-border:#c0392b;
  --upstream-color:#2ecc71; --downstream-color:#f39c12; --panel-bg:#ffffff; --header-bg:#1a252f;
}}
body {{ margin:0; font-family:'Segoe UI','Malgun Gothic',sans-serif; background:var(--bg-color);
  color:var(--text-main); overflow-x:hidden; }}
.header {{ padding:18px 26px; background:var(--header-bg); color:white; }}
.header h1 {{ margin:0; font-size:21px; font-weight:600; }}
.header p {{ margin:6px 0 0 0; font-size:12.5px; color:#bdc3c7; line-height:1.6; }}
.map-container {{ display:grid; grid-template-columns:repeat(6,1fr); gap:14px; padding:18px;
  position:relative; align-items:start; }}
#line-svg {{ position:absolute; top:0; left:0; width:100%; height:100%; pointer-events:none; z-index:10; }}
path.lineage {{ fill:none; stroke-width:2; opacity:0.12; transition:opacity .25s ease; stroke:#7f8c8d; }}
path.upstream-line {{ stroke:var(--upstream-color); opacity:.95; stroke-dasharray:4;
  animation:dash 20s linear infinite; }}
path.downstream-line {{ stroke:var(--downstream-color); opacity:.95; stroke-dasharray:4;
  animation:dash-rev 20s linear infinite; }}
@keyframes dash {{ to {{ stroke-dashoffset:-1000; }} }}
@keyframes dash-rev {{ to {{ stroke-dashoffset:1000; }} }}
.layer {{ background:var(--layer-bg); border-radius:10px; box-shadow:0 4px 12px rgba(0,0,0,.05);
  padding:13px; position:relative; z-index:2; display:flex; flex-direction:column;
  border-top:4px solid var(--text-sub); }}
.layer.l-BRONZE {{ border-top-color:#95a5a6; }}
.layer.l-SILVER {{ border-top-color:#3498db; }}
.layer.l-GOLD {{ border-top-color:#f1c40f; }}
.layer.l-WIDE {{ border-top-color:#9b59b6; }}
.layer.l-SERVING {{ border-top-color:#16a085; }}
.layer.l-SEMANTIC {{ border-top-color:#e67e22; }}
.layer-title {{ font-size:15px; font-weight:bold; text-align:center; margin-bottom:4px; }}
.layer-sub {{ font-size:10.5px; color:var(--text-sub); text-align:center; margin-bottom:12px;
  padding-bottom:8px; border-bottom:1px solid var(--border-color); line-height:1.5; }}
.domain-group {{ margin-bottom:16px; }}
.domain-title {{ font-size:11px; font-weight:700; color:var(--text-sub); margin-bottom:7px;
  text-transform:uppercase; letter-spacing:1px; display:flex; align-items:center; gap:6px; }}
.domain-title::before, .domain-title::after {{ content:''; flex:1; height:1px; background:var(--border-color); }}
.chip-container {{ display:flex; flex-wrap:wrap; gap:5px; }}
.chip {{ background:var(--chip-bg); border:1px solid var(--chip-border); border-radius:5px;
  padding:4px 7px; font-size:10.5px; font-weight:600; cursor:pointer; transition:all .2s;
  box-shadow:0 1px 2px rgba(0,0,0,.04); word-break:break-all; position:relative; z-index:5; }}
.chip:hover {{ background:var(--hover-bg); color:white; border-color:var(--hover-border); }}
.chip.active {{ background:var(--active-bg) !important; color:white !important;
  border-color:var(--active-border) !important; }}
.chip.upstream {{ background:var(--upstream-color) !important; color:white !important; }}
.chip.downstream {{ background:var(--downstream-color) !important; color:white !important; }}
.chip.is-view {{ border-left:3px solid #9b59b6; }}
.chip.is-view::after {{ content:' (V)'; font-size:8px; color:#9b59b6; }}
.chip.is-sv {{ border-left:3px solid #e67e22; }}
.chip.is-sv::after {{ content:' (SV)'; font-size:8px; color:#e67e22; }}
.chip.is-empty {{ border-style:dashed; color:#b2bec3; }}
.chip.is-empty::before {{ content:'∅ '; font-size:9px; }}
.panel {{ position:fixed; right:-620px; top:0; width:590px; height:100%; background:var(--panel-bg);
  box-shadow:-5px 0 25px rgba(0,0,0,.15); transition:right .3s cubic-bezier(.4,0,.2,1);
  z-index:100; display:flex; flex-direction:column; }}
.panel.open {{ right:0; }}
.panel-header {{ background:var(--header-bg); color:white; padding:16px 20px; display:flex;
  justify-content:space-between; align-items:center; }}
.panel-title {{ font-size:15px; font-weight:bold; }}
.panel-subtitle {{ font-size:11px; color:#bdc3c7; margin-top:4px; line-height:1.5; }}
.close-btn {{ background:rgba(255,255,255,.1); border:none; color:white; font-size:15px; width:30px;
  height:30px; border-radius:50%; cursor:pointer; flex:none; }}
.panel-note {{ padding:10px 14px; font-size:11px; color:#7f8c8d; background:#f8f9fa;
  border-bottom:1px solid var(--border-color); line-height:1.6; }}
.panel-content {{ padding:0; overflow-y:auto; flex:1; }}
table {{ width:100%; border-collapse:collapse; font-size:11.5px; }}
th {{ background:#f8f9fa; font-weight:600; color:#34495e; position:sticky; top:0;
  border-bottom:2px solid #e0e6ed; padding:9px 11px; text-align:left; }}
td {{ border-bottom:1px solid #e0e6ed; padding:8px 11px; vertical-align:top; color:#2c3e50; }}
.badge {{ padding:2px 5px; border-radius:3px; font-size:9px; font-weight:bold; color:white;
  display:inline-block; margin-right:3px; }}
.badge.pk {{ background:#e74c3c; }} .badge.fk {{ background:#f39c12; }}
.badge.attr {{ background:#95a5a6; }} .badge.nn {{ background:#34495e; }}
.badge.metric {{ background:#16a085; }} .badge.dim {{ background:#8e44ad; }}
.badge.fact {{ background:#2980b9; }}
.type-col {{ color:#2980b9; font-family:monospace; font-weight:bold; }}
.no-comment {{ color:#b2bec3; }}
.legend {{ display:flex; gap:14px; padding:9px 26px; background:white;
  border-bottom:1px solid var(--border-color); font-size:11.5px; align-items:center; flex-wrap:wrap; }}
.legend-item {{ display:flex; align-items:center; gap:5px; }}
.legend-box {{ width:12px; height:12px; border-radius:2px; }}
</style>
</head>
<body>
<div class="header">
  <h1>GN_DW 아키텍처 통합 지도 — BRONZE {n_bronze} · SILVER {n_silver} · GOLD {n_gold} · WIDE {n_wide} · SERVING {n_serving} · SV {n_semantic}</h1>
  <p>
    근거 = <b>라이브 실측</b>(<code>GN_DW.INFORMATION_SCHEMA</code> 객체·컬럼·COMMENT ·
    <code>SHOW PRIMARY/IMPORTED KEYS</code> · <code>SHOW/DESCRIBE SEMANTIC VIEW</code>) ·
    리니지 = <code>10_dbt_pipeline/models/**/*.sql</code> 의 <code>source()</code>/<code>ref()</code> +
    SERVING 뷰 정의 + SV base table · 계정 <b>{account}</b> · 측정 {measured}<br>
    노드 <b>{n_total}</b> · 리니지 간선 <b>{n_links}</b> · 컬럼·SV멤버 <b>{n_cols}</b> · Agent <b>{n_agents}</b>.
    칩을 클릭하면 컬럼(또는 SV 차원·메트릭) 명세, 마우스를 올리면 상·하위 리니지가 표시된다. ∅ = 0행 테이블.<br>
    <b>지도 범위 밖</b>(의도적 제외) = <code>BRONZE_BIGQUERY</code> 일별 샤드 943 ·
    <code>BRONZE_GA4</code>/<code>BRONZE_GSC</code> 각 2 · <code>ML</code> 스키마 49+4 ·
    <code>OPS</code>/<code>SECURITY</code> · dbt <code>source</code> 미선언 BRONZE 테이블.
  </p>
</div>
<div class="legend">
  <div class="legend-item"><div class="legend-box" style="background:var(--active-bg);"></div>선택 노드</div>
  <div class="legend-item"><div class="legend-box" style="background:var(--upstream-color);"></div>상위 리니지</div>
  <div class="legend-item"><div class="legend-box" style="background:var(--downstream-color);"></div>하위 리니지</div>
  <div class="legend-item"><div class="legend-box" style="border-left:3px solid #9b59b6;background:var(--chip-bg);"></div>뷰 (V)</div>
  <div class="legend-item"><div class="legend-box" style="border-left:3px solid #e67e22;background:var(--chip-bg);"></div>Semantic View (SV)</div>
  <div class="legend-item"><div class="legend-box" style="border:1px dashed #b2bec3;"></div>0행 테이블 (∅)</div>
</div>
<svg id="line-svg"></svg>
<div class="map-container" id="map-container"></div>
<div class="panel" id="side-panel">
  <div class="panel-header">
    <div>
      <div class="panel-title" id="panel-title"></div>
      <div class="panel-subtitle" id="panel-subtitle"></div>
    </div>
    <button class="close-btn" onclick="closePanel()">&#10005;</button>
  </div>
  <div class="panel-note" id="panel-note"></div>
  <div class="panel-content">
    <table>
      <thead><tr><th width="34%">컬럼 / SV 멤버</th><th width="22%">타입</th><th width="44%">COMMENT (라이브)</th></tr></thead>
      <tbody id="panel-content-body"></tbody>
    </table>
  </div>
</div>
<script>
const LAYERS = [
  {{ id:"BRONZE",  title:"BRONZE",  sub:"원천 적재 (dbt source 선언분)" }},
  {{ id:"SILVER",  title:"SILVER",  sub:"정제·표준화 (dbt)" }},
  {{ id:"GOLD",    title:"GOLD",    sub:"차원·팩트 테이블 (dbt)" }},
  {{ id:"WIDE",    title:"WIDE",    sub:"GOLD 스키마 뷰 (dbt)" }},
  {{ id:"SERVING", title:"SERVING", sub:"서빙 뷰 (DDL)" }},
  {{ id:"SEMANTIC", title:"SEMANTIC", sub:"Semantic View (Cortex Analyst / Agent 입력)" }}
];
const DOMAINS = ["CRM", "AGENCY", "GA4", "ERP", "ML"];
"""

TAIL = """
const container = document.getElementById("map-container");
const svg = document.getElementById("line-svg");
const nodeById = {};
nodesData.forEach(n => nodeById[n.id] = n);

// 긴 COMMENT 는 한 줄 2000자 상한(작업지침 R1-5-1) 때문에 청크 배열로 저장돼 있다 → 복원한다.
function tx(v) { return Array.isArray(v) ? v.join("") : (v == null ? "" : String(v)); }

LAYERS.forEach(layer => {
  const nodesInLayer = nodesData.filter(n => n.layer === layer.id);
  const layerEl = document.createElement("div");
  layerEl.className = "layer l-" + layer.id;
  const t = document.createElement("div");
  t.className = "layer-title";
  t.innerText = layer.title + " (" + nodesInLayer.length + ")";
  const s = document.createElement("div");
  s.className = "layer-sub";
  s.innerText = layer.sub;
  layerEl.appendChild(t); layerEl.appendChild(s);

  DOMAINS.forEach(domain => {
    const domainNodes = nodesInLayer.filter(n => n.domain === domain);
    if (domainNodes.length === 0) return;
    const groupEl = document.createElement("div");
    groupEl.className = "domain-group";
    const dt = document.createElement("div");
    dt.className = "domain-title";
    dt.innerText = domain + " " + domainNodes.length;
    groupEl.appendChild(dt);
    const chipsEl = document.createElement("div");
    chipsEl.className = "chip-container";
    domainNodes.forEach(node => {
      const chip = document.createElement("div");
      let cls = "chip";
      if (node.type === "VIEW") cls += " is-view";
      if (node.type === "SEMANTIC VIEW") cls += " is-sv";
      if (node.rows === 0) cls += " is-empty";
      chip.className = cls;
      chip.id = "node-" + cssId(node.id);
      chip.innerText = node.label;
      chip.title = node.schema + "." + node.label +
        (node.rows === null ? "" : " · " + node.rows.toLocaleString() + "행");
      chip.onclick = () => selectNode(node.id);
      chip.onmouseenter = () => highlightLineage(node.id);
      chip.onmouseleave = () => resetLineage();
      chipsEl.appendChild(chip);
    });
    groupEl.appendChild(chipsEl);
    layerEl.appendChild(groupEl);
  });
  container.appendChild(layerEl);
});

function cssId(id) { return id.replace(/[^A-Za-z0-9_]/g, "_"); }

let svgPaths = [];
function drawLines() {
  svg.innerHTML = "";
  svgPaths = [];
  const svgRect = svg.getBoundingClientRect();
  linksData.forEach(link => {
    const elFrom = document.getElementById("node-" + cssId(link.from));
    const elTo = document.getElementById("node-" + cssId(link.to));
    if (!elFrom || !elTo) return;
    const a = elFrom.getBoundingClientRect(), b = elTo.getBoundingClientRect();
    const x1 = a.right - svgRect.left, y1 = a.top + a.height / 2 - svgRect.top;
    const x2 = b.left - svgRect.left,  y2 = b.top + b.height / 2 - svgRect.top;
    const dx = Math.max(Math.abs(x2 - x1) / 2, 25);
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", "M " + x1 + " " + y1 + " C " + (x1 + dx) + " " + y1 + ", " +
      (x2 - dx) + " " + y2 + ", " + x2 + " " + y2);
    path.setAttribute("class", "lineage");
    path.dataset.from = link.from;
    path.dataset.to = link.to;
    svg.appendChild(path);
    svgPaths.push(path);
  });
}

function highlightLineage(nodeId) {
  const up = new Set(), down = new Set();
  (function walkUp(id) {
    linksData.filter(l => l.to === id).forEach(l => {
      if (!up.has(l.from)) { up.add(l.from); walkUp(l.from); }
    });
  })(nodeId);
  (function walkDown(id) {
    linksData.filter(l => l.from === id).forEach(l => {
      if (!down.has(l.to)) { down.add(l.to); walkDown(l.to); }
    });
  })(nodeId);

  document.querySelectorAll(".chip").forEach(chip => {
    const id = chip.dataset.nid;
    if (id === nodeId) chip.classList.add("active");
    else if (up.has(id)) chip.classList.add("upstream");
    else if (down.has(id)) chip.classList.add("downstream");
    else chip.style.opacity = "0.22";
  });

  svgPaths.forEach(path => {
    const f = path.dataset.from, t = path.dataset.to;
    const inUp = (t === nodeId && up.has(f)) || (up.has(t) && up.has(f));
    const inDown = (f === nodeId && down.has(t)) || (down.has(f) && down.has(t));
    if (inUp) { path.classList.add("upstream-line"); path.style.opacity = "1"; }
    else if (inDown) { path.classList.add("downstream-line"); path.style.opacity = "1"; }
    else { path.style.opacity = "0.03"; }
  });
}

function resetLineage() {
  document.querySelectorAll(".chip").forEach(chip => {
    chip.classList.remove("active", "upstream", "downstream");
    chip.style.opacity = "1";
  });
  svgPaths.forEach(path => {
    path.classList.remove("upstream-line", "downstream-line");
    path.style.opacity = "0.12";
  });
}

function esc(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function selectNode(nodeId) {
  const node = nodeById[nodeId];
  if (!node) return;
  document.getElementById("panel-title").innerText = node.label;
  const ups = linksData.filter(l => l.to === nodeId).map(l => nodeById[l.from].label);
  const downs = linksData.filter(l => l.from === nodeId).map(l => nodeById[l.to].label);
  document.getElementById("panel-subtitle").innerText =
    node.schema + " · " + node.layer + " / " + node.domain + " · " + node.type +
    (node.rows === null ? "" : " · " + node.rows.toLocaleString() + "행");

  const note = [];
  if (tx(node.comment)) note.push("<b>객체 COMMENT</b> — " + esc(tx(node.comment)));
  note.push("<b>상위</b> " + (ups.length ? esc(ups.join(", ")) : "없음") +
            " &nbsp;/&nbsp; <b>하위</b> " + (downs.length ? esc(downs.join(", ")) : "없음"));
  document.getElementById("panel-note").innerHTML = note.join("<br>");

  const tbody = document.getElementById("panel-content-body");
  tbody.innerHTML = "";
  const cols = columnsData[nodeId] || [];
  if (cols.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" class="no-comment">컬럼 메타데이터 없음</td></tr>';
  }
  cols.forEach(col => {
    const tr = document.createElement("tr");
    let badges = "";
    if (col.k === "PK") badges += '<span class="badge pk">PK</span>';
    else if (col.k === "FK") badges += '<span class="badge fk">FK</span>';
    else if (col.k === "METRIC") badges += '<span class="badge metric">METRIC</span>';
    else if (col.k === "FACT") badges += '<span class="badge fact">FACT</span>';
    else if (col.k === "DIM") badges += '<span class="badge dim">DIM</span>';
    else badges += '<span class="badge attr">ATTR</span>';
    if (col.z === "NN") badges += '<span class="badge nn">NN</span>';
    const desc = tx(col.d) ? esc(tx(col.d)) : '<span class="no-comment">(COMMENT 없음)</span>';
    tr.innerHTML = "<td>" + badges + " " + esc(tx(col.n)) + "</td>" +
      '<td class="type-col">' + esc(tx(col.t)) + "</td><td>" + desc + "</td>";
    tbody.appendChild(tr);
  });
  document.getElementById("side-panel").classList.add("open");
}

function closePanel() {
  document.getElementById("side-panel").classList.remove("open");
}

document.querySelectorAll(".chip").forEach(chip => {
  const n = nodesData.find(x => "node-" + cssId(x.id) === chip.id);
  if (n) chip.dataset.nid = n.id;
});

window.addEventListener("load", drawLines);
window.addEventListener("resize", drawLines);
</script>
</body>
</html>
"""


def write_html(path, account, nodes, links, columns, by_layer, agent_cnt):
    import datetime
    parts = [HEAD.format(
        account=account,
        measured=datetime.date.today().isoformat(),
        n_bronze=by_layer["BRONZE"], n_silver=by_layer["SILVER"],
        n_gold=by_layer["GOLD"], n_wide=by_layer["WIDE"], n_serving=by_layer["SERVING"],
        n_semantic=by_layer["SEMANTIC"], n_agents=agent_cnt,
        n_total=len(nodes), n_links=len(links),
        n_cols=sum(len(v) for v in columns.values()),
    )]

    parts.append("const nodesData = [")
    for i, n in enumerate(nodes):
        parts.append(jline(n) + ("," if i < len(nodes) - 1 else ""))
    parts.append("];")

    parts.append("const linksData = [")
    for i, l in enumerate(links):
        parts.append(jline(l) + ("," if i < len(links) - 1 else ""))
    parts.append("];")

    parts.append("const columnsData = {")
    keys = sorted(columns)
    for ki, k in enumerate(keys):
        parts.append("  %s: [" % json.dumps(k, ensure_ascii=False))
        rows = columns[k]
        for i, c in enumerate(rows):
            parts.append(jline(c, "    ") + ("," if i < len(rows) - 1 else ""))
        parts.append("  ]%s" % ("," if ki < len(keys) - 1 else ""))
    parts.append("};")

    parts.append(TAIL)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))


if __name__ == "__main__":
    sys.exit(main())
