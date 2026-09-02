"""
Pipeline ERD & Lineage Generator (Bronze > Silver > Gold)
Generates interactive HTML documents in 30_output_share/erd/
Co-authored with CoCo
"""

import os
import re
import sys
import json
import glob
from collections import defaultdict
from datetime import datetime
import yaml

ROOT = "/workspace"
DBT_ROOT = os.path.join(ROOT, "10_dbt_pipeline", "models")
DDL_PATH = os.path.join(ROOT, "03_top-down_gold", "06_DDL.sql")
OUT_DIR = os.path.join(ROOT, "30_output_share", "erd")

# ══════════════════════════════════════════════════════════════════════════════
# 1. Metadata Collection
# ══════════════════════════════════════════════════════════════════════════════

def load_ddl_metadata():
    if not os.path.exists(DDL_PATH):
        return {}
    with open(DDL_PATH, "r", encoding="utf-8") as f:
        ddl_text = f.read()

    table_pattern = re.compile(
        r"CREATE\s+OR\s+REPLACE\s+TABLE\s+(?:GN_DW\.GOLD\.)?([A-Z0-9_]+)\s*\((.*?)\)\s*(?:COMMENT\s*=\s*'([^']*)')?\s*;",
        re.DOTALL | re.IGNORECASE
    )

    ddl_tables = {}
    for match in table_pattern.finditer(ddl_text):
        tname = match.group(1).upper()
        body = match.group(2)
        tbl_comment = match.group(3) or ""
        
        cols = {}
        for line in body.splitlines():
            line = line.strip().rstrip(",")
            if not line or line.startswith(("--", "/*", "PRIMARY KEY", "FOREIGN KEY", "CONSTRAINT")):
                continue
            
            col_match = re.match(
                r"^([A-Z0-9_]+)\s+([A-Z0-9_]+(?:\s*\([^)]*\))?)(.*?)(?:COMMENT\s+'([^']*)')?$",
                line,
                re.IGNORECASE
            )
            if col_match:
                cname = col_match.group(1).upper()
                dtype = col_match.group(2).upper().replace(" ", "")
                comment = col_match.group(4) or ""
                cols[cname] = {
                    "name": cname,
                    "data_type": dtype,
                    "description": comment.strip(),
                    "tests": []
                }
        ddl_tables[tname] = {
            "name": tname,
            "description": tbl_comment.strip(),
            "columns": cols
        }
    return ddl_tables

def load_yaml_metadata():
    yaml_files = glob.glob(f"{DBT_ROOT}/**/*.yml", recursive=True)
    models_meta = {}
    sources_meta = {}

    for yf in sorted(yaml_files):
        with open(yf, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not data:
            continue
        if "models" in data:
            for m in data["models"]:
                mname = m["name"]
                cols = {}
                for c in m.get("columns", []):
                    cname = c["name"]
                    if "||" in cname:
                        continue
                    cols[cname] = {
                        "name": cname,
                        "description": c.get("description", "").strip(),
                        "data_type": c.get("data_type", "VARCHAR"),
                        "tests": c.get("tests", [])
                    }
                models_meta[mname] = {
                    "name": mname,
                    "description": m.get("description", "").strip(),
                    "columns": cols,
                    "yaml_path": os.path.relpath(yf, ROOT)
                }
        if "sources" in data:
            for s in data["sources"]:
                sname = s["name"]
                schema = s.get("schema", sname)
                for t in s.get("tables", []):
                    tname = t["name"]
                    key = (sname, tname)
                    cols = {}
                    for c in t.get("columns", []):
                        cname = c["name"]
                        cols[cname] = {
                            "name": cname,
                            "description": c.get("description", "").strip(),
                            "data_type": c.get("data_type", "VARCHAR"),
                            "tests": c.get("tests", [])
                        }
                    sources_meta[key] = {
                        "source_name": sname,
                        "schema": schema,
                        "table": tname,
                        "description": t.get("description", "").strip(),
                        "columns": cols
                    }
    return models_meta, sources_meta

def load_sql_metadata():
    sql_files = glob.glob(f"{DBT_ROOT}/**/*.sql", recursive=True)
    sql_models = {}

    for sf in sorted(sql_files):
        mname = os.path.basename(sf).replace(".sql", "")
        with open(sf, "r", encoding="utf-8") as f:
            raw_sql = f.read()

        refs = re.findall(r"ref\(\s*['\"]([^'\"]+)['\"]\s*\)", raw_sql)
        sources = re.findall(r"source\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)", raw_sql)

        header_lines = []
        for line in raw_sql.splitlines():
            if line.startswith("--"):
                header_lines.append(line.lstrip("- ").strip())
            elif line.strip().startswith("{{") or line.strip().startswith("with") or line.strip().startswith("select"):
                break

        ctes = re.findall(r"([a-zA-Z0-9_]+)\s+as\s*\(", raw_sql, re.IGNORECASE)

        sql_models[mname] = {
            "name": mname,
            "refs": sorted(list(set(refs))),
            "sources": sorted(list(set(sources))),
            "sql_path": os.path.relpath(sf, ROOT),
            "raw_sql": raw_sql,
            "header_doc": "\n".join(header_lines),
            "ctes": ctes
        }
    return sql_models

# ══════════════════════════════════════════════════════════════════════════════
# 2. Lineage & Dependency Graph Resolution
# ══════════════════════════════════════════════════════════════════════════════

def build_lineage_graph(sql_models):
    upstream = defaultdict(lambda: {"models": set(), "sources": set()})
    downstream = defaultdict(lambda: {"models": set()})

    for mname, mdata in sql_models.items():
        for r in mdata["refs"]:
            upstream[mname]["models"].add(r)
            downstream[r]["models"].add(mname)
        for s in mdata["sources"]:
            upstream[mname]["sources"].add(s)

    return upstream, downstream

def resolve_full_lineage_for_gold(gold_name, sql_models, upstream):
    visited_models = set()
    bronze_sources = set()
    silver_models = set()
    gold_parents = set()

    def dfs(curr):
        if curr in visited_models:
            return
        visited_models.add(curr)

        for s in upstream[curr]["sources"]:
            bronze_sources.add(s)

        for parent in upstream[curr]["models"]:
            if parent.startswith(("DIM_", "FACT_")):
                if parent != gold_name:
                    gold_parents.add(parent)
            else:
                silver_models.add(parent)
            dfs(parent)

    dfs(gold_name)

    # Edge list for mermaid
    edges = []
    for sm in silver_models:
        for s in upstream[sm]["sources"]:
            edges.append(("BRONZE", f"{s[0]}.{s[1]}", "SILVER", sm))
        for parent_sm in upstream[sm]["models"]:
            if not parent_sm.startswith(("DIM_", "FACT_")):
                edges.append(("SILVER", parent_sm, "SILVER", sm))

    for s in upstream[gold_name]["sources"]:
        edges.append(("BRONZE", f"{s[0]}.{s[1]}", "GOLD", gold_name))

    for sm in upstream[gold_name]["models"]:
        if not sm.startswith(("DIM_", "FACT_")):
            edges.append(("SILVER", sm, "GOLD", gold_name))
        else:
            edges.append(("GOLD", sm, "GOLD", gold_name))

    for gp in gold_parents:
        for sm in upstream[gp]["models"]:
            if not sm.startswith(("DIM_", "FACT_")):
                edges.append(("SILVER", sm, "GOLD", gp))

    return {
        "bronze_sources": sorted(list(bronze_sources)),
        "silver_models": sorted(list(silver_models)),
        "gold_parents": sorted(list(gold_parents)),
        "edges": sorted(list(set(edges)))
    }

# ══════════════════════════════════════════════════════════════════════════════
# 3. ERD & FK Relationships for Gold Tables
# ══════════════════════════════════════════════════════════════════════════════

LOGICAL_CONFORM_FKS = [
    ("*", "MONTH_KEY", "DIM_MONTH", "MONTH_KEY", "월 conform 축 (fan-out 방지)"),
    ("*", "START_MONTH_KEY", "DIM_MONTH", "MONTH_KEY", "역할기반 월 축 (개시월)"),
    ("*", "DSCNTC_MONTH_KEY", "DIM_MONTH", "MONTH_KEY", "역할기반 월 축 (중단월)"),
    ("DIM_MEMBER_IDENTITY", "MEMBER_DK", "DIM_MEMBER", "MEMBER_DK", "회원 식별 자연키 참조"),
    ("DIM_MEMBER_CURRENT", "MEMBER_DK", "DIM_MEMBER", "MEMBER_DK", "현재 회원 스냅샷 자연키 참조"),
    ("DIM_MEMBER_ACQUISITION", "MEMBER_DK", "DIM_MEMBER", "MEMBER_DK", "회원 획득 자연키 참조"),
]

def extract_gold_relationships(models_meta):
    relationships = []

    for mname, mdata in models_meta.items():
        if not mname.startswith(("DIM_", "FACT_")):
            continue
        for cname, cdata in mdata.get("columns", {}).items():
            tests = cdata.get("tests", [])
            for t in tests:
                if isinstance(t, dict) and "relationships" in t:
                    rel = t["relationships"]
                    to_model = rel.get("to", "").replace("ref('", "").replace("')", "").replace('ref("', "").replace('")', "")
                    field = rel.get("field", "")
                    relationships.append({
                        "from_table": mname,
                        "from_col": cname,
                        "to_table": to_model,
                        "to_col": field,
                        "source": "dbt YAML",
                        "type": "Physical / Declared FK"
                    })

            for pat_tbl, pat_col, target_tbl, target_col, desc in LOGICAL_CONFORM_FKS:
                if (pat_tbl == "*" or pat_tbl == mname) and cname == pat_col:
                    if target_tbl in models_meta and mname != target_tbl:
                        exists = any(r["from_table"] == mname and r["from_col"] == cname and r["to_table"] == target_tbl for r in relationships)
                        if not exists:
                            relationships.append({
                                "from_table": mname,
                                "from_col": cname,
                                "to_table": target_tbl,
                                "to_col": target_col,
                                "source": "Logical Conform",
                                "type": desc
                            })

    return relationships

# ══════════════════════════════════════════════════════════════════════════════
# 4. Helper & Formatting Functions
# ══════════════════════════════════════════════════════════════════════════════

def get_table_domain(name):
    if any(k in name for k in ["MEMBER", "SPONSOR", "PAYMENT", "RELATION", "SEND", "CRM", "SERVICE", "IDENTITY"]):
        return "CRM / 회원·후원"
    if any(k in name for k in ["BUDGET", "ERP", "TARGET_DEV", "TARGET_BIZ", "DEV_ACHIEVEMENT"]):
        return "ERP / 예산·목표"
    if any(k in name for k in ["AD_", "AGENCY", "CAMPAIGN", "MARKETING"]):
        return "AGENCY / 마케팅·광고"
    if any(k in name for k in ["GA_", "DEVICE", "BIGQUERY"]):
        return "GA4 / 디지털 행동"
    return "COMMON / 공통 기준"

def get_table_type(name):
    if name.startswith("DIM_"):
        return "DIM", "차원 (Dimension)", "badge-dim"
    if name.startswith("FACT_"):
        return "FACT", "팩트 (Fact)", "badge-fact"
    if name.startswith("WIDE_"):
        return "WIDE", "와이드 마트 (Wide Mart)", "badge-wide"
    if name.startswith(("CRM_", "ERP_", "AGENCY_", "BIGQUERY_", "IDENTITY_")):
        return "SILVER", "정제 모델 (Silver)", "badge-silver"
    return "BRONZE", "원천 (Bronze)", "badge-bronze"

def escape_html(text):
    if not text:
        return ""
    return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

def get_clean_korean_title(desc, default_name):
    if not desc:
        return default_name
    first_line = desc.split("\n")[0].strip()
    if ":" in first_line:
        parts = first_line.split(":", 1)
        if len(parts[1].strip()) > 0:
            return parts[1].strip().rstrip(". ")
    return first_line.rstrip(". ")

# ══════════════════════════════════════════════════════════════════════════════
# 5. Common CSS & Theme
# ══════════════════════════════════════════════════════════════════════════════

COMMON_STYLE = """
    :root {
      color-scheme: light dark;
      --bg-primary: light-dark(#f8fafc, #0f172a);
      --bg-surface: light-dark(#ffffff, #1e293b);
      --bg-subtle: light-dark(#f1f5f9, #334155);
      --text-main: light-dark(#0f172a, #f8fafc);
      --text-muted: light-dark(#64748b, #94a3b8);
      --border-color: light-dark(#e2e8f0, #334155);
      --accent-blue: light-dark(#2563eb, #3b82f6);
      --accent-amber: light-dark(#d97706, #f59e0b);
      --accent-purple: light-dark(#7c3aed, #a855f7);
      --accent-emerald: light-dark(#059669, #10b981);
      --accent-rose: light-dark(#e11d48, #f43f5e);
    }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      margin: 0; padding: 0;
      background-color: var(--bg-primary);
      color: var(--text-main);
      line-height: 1.5;
    }
    .layout-container {
      display: flex;
      min-height: 100vh;
    }
    .sidebar {
      width: 280px;
      flex-shrink: 0;
      background-color: var(--bg-surface);
      border-right: 1px solid var(--border-color);
      display: flex;
      flex-direction: column;
      position: sticky;
      top: 0;
      height: 100vh;
      overflow-y: auto;
    }
    .sidebar-header {
      padding: 16px;
      border-bottom: 1px solid var(--border-color);
    }
    .sidebar-title {
      font-size: 1.1rem;
      font-weight: 700;
      margin: 0 0 4px 0;
      color: var(--accent-blue);
    }
    .sidebar-subtitle {
      font-size: 0.8rem;
      color: var(--text-muted);
      margin: 0;
    }
    .sidebar-search {
      padding: 12px 16px;
      border-bottom: 1px solid var(--border-color);
    }
    .sidebar-search input {
      width: 100%;
      padding: 8px 12px;
      border-radius: 6px;
      border: 1px solid var(--border-color);
      background: var(--bg-subtle);
      color: var(--text-main);
      font-size: 0.85rem;
    }
    .sidebar-nav {
      padding: 12px 0;
      flex: 1;
    }
    .nav-group-title {
      font-size: 0.75rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-muted);
      padding: 8px 16px 4px 16px;
    }
    .nav-item {
      display: flex;
      align-items: center;
      padding: 6px 16px;
      color: var(--text-main);
      text-decoration: none;
      font-size: 0.85rem;
      gap: 8px;
    }
    .nav-item:hover {
      background-color: var(--bg-subtle);
      color: var(--accent-blue);
    }
    .nav-item.active {
      background-color: var(--bg-subtle);
      color: var(--accent-blue);
      font-weight: 600;
      border-left: 3px solid var(--accent-blue);
    }
    .main-content {
      flex: 1;
      padding: 24px 36px;\n      max-width: 1200px;
      overflow-x: hidden;
    }
    .header-card {
      background-color: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 24px;
      margin-bottom: 24px;
    }
    .header-top {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 12px;
    }
    .title-area h1 {
      margin: 0 0 6px 0;
      font-size: 1.75rem;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .korean-title {
      font-size: 1.1rem;
      color: var(--text-muted);
      font-weight: 500;
    }
    .meta-badges {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-top: 8px;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 4px;
      font-size: 0.75rem;
      font-weight: 600;
      text-transform: uppercase;
    }
    .badge-dim { background: rgba(37, 99, 235, 0.15); color: var(--accent-blue); }
    .badge-fact { background: rgba(217, 119, 6, 0.15); color: var(--accent-amber); }
    .badge-wide { background: rgba(124, 58, 237, 0.15); color: var(--accent-purple); }
    .badge-silver { background: rgba(5, 150, 105, 0.15); color: var(--accent-emerald); }
    .badge-bronze { background: rgba(225, 29, 72, 0.15); color: var(--accent-rose); }
    .badge-domain { background: var(--bg-subtle); color: var(--text-muted); border: 1px solid var(--border-color); }
    .section-card {
      background-color: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 24px;
      margin-bottom: 24px;
    }
    .section-title {
      font-size: 1.25rem;
      font-weight: 700;
      margin: 0 0 16px 0;
      display: flex;
      align-items: center;
      gap: 8px;
      border-bottom: 1px solid var(--border-color);
      padding-bottom: 8px;
    }
    .lineage-diag-wrap {
      background: var(--bg-subtle);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 16px;
      overflow-x: auto;
      margin-bottom: 16px;
      display: flex;
      justify-content: center;
    }
    .table-wrap {
      overflow-x: auto;
      margin: 16px 0;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.85rem;
    }
    th, td {
      border: 1px solid var(--border-color);
      padding: 8px 12px;
      text-align: left;
    }
    th {
      background-color: var(--bg-subtle);
      font-weight: 600;
    }
    .flow-steps {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
      margin-top: 16px;
    }
    .flow-step-box {
      background: var(--bg-subtle);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 14px;
    }
    .flow-step-title {
      font-size: 0.9rem;
      font-weight: 700;
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .flow-step-list {
      list-style: none;
      padding: 0;
      margin: 0;
      font-size: 0.8rem;
    }
    .flow-step-list li {
      padding: 4px 0;
      border-bottom: 1px dashed var(--border-color);
    }
    .flow-step-list li:last-child {
      border-bottom: none;
    }
    .sql-code-box {
      background: var(--bg-subtle);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 16px;
      overflow-x: auto;
      font-size: 0.8rem;
    }
    details summary {
      cursor: pointer;
      font-weight: 600;
      padding: 8px 0;
    }
    a { color: var(--accent-blue); text-decoration: none; }
    a:hover { text-decoration: underline; }

    /* Index styles */
    .hero-stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .stat-card {
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 16px 20px;
      text-align: center;
    }
    .stat-num {
      font-size: 2rem;
      font-weight: 800;
      margin: 4px 0;
    }
    .stat-label {
      font-size: 0.8rem;
      color: var(--text-muted);
      text-transform: uppercase;
      font-weight: 600;
    }
    .stat-bronze .stat-num { color: var(--accent-rose); }
    .stat-silver .stat-num { color: var(--accent-emerald); }
    .stat-gold .stat-num { color: var(--accent-blue); }
    .stat-wide .stat-num { color: var(--accent-purple); }

    .filter-bar {
      display: flex;
      gap: 12px;
      margin-bottom: 20px;
      flex-wrap: wrap;
      align-items: center;
    }
    .filter-btn {
      padding: 6px 14px;
      border-radius: 20px;
      border: 1px solid var(--border-color);
      background: var(--bg-surface);
      color: var(--text-main);
      font-size: 0.85rem;
      cursor: pointer;
    }
    .filter-btn.active {
      background: var(--accent-blue);
      color: #ffffff;
      border-color: var(--accent-blue);
      font-weight: 600;
    }
    .table-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 16px;
      margin-top: 16px;
    }
    .table-grid-card {
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 10px;
      padding: 18px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      transition: transform 0.15s ease, border-color 0.15s ease;
    }
    .table-grid-card:hover {
      border-color: var(--accent-blue);
      transform: translateY(-2px);
    }
    .card-header {
      display: flex;
      justify-content: space-between;
      margin-bottom: 8px;
    }
    .card-title {
      margin: 0 0 4px 0;
      font-size: 1.1rem;
    }
    .card-desc {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin-bottom: 12px;
      height: 2.6em;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }
    .card-meta {
      font-size: 0.75rem;
      background: var(--bg-subtle);
      border-radius: 6px;
      padding: 8px;
      margin-bottom: 12px;
      line-height: 1.6;
    }
    .card-btn {
      display: block;
      text-align: center;
      padding: 8px;
      background: var(--bg-subtle);
      border: 1px solid var(--border-color);
      border-radius: 6px;
      font-size: 0.85rem;
      font-weight: 600;
      color: var(--accent-blue);
    }
    .card-btn:hover {
      background: var(--accent-blue);
      color: #ffffff;
      text-decoration: none;
    }
"""

# ══════════════════════════════════════════════════════════════════════════════
# 6. HTML Page Generators
# ══════════════════════════════════════════════════════════════════════════════

def generate_table_html(mname, models_meta, sources_meta, sql_models, upstream, all_gold_names, all_relationships, ts):
    mdata = models_meta.get(mname, {"description": "", "columns": {}})
    sdata = sql_models.get(mname, {"raw_sql": "", "header_doc": "", "sources": [], "refs": []})
    
    table_type, type_label, badge_class = get_table_type(mname)
    domain = get_table_domain(mname)
    korean_title = get_clean_korean_title(mdata["description"], mname)
    
    # 1. Resolve lineage
    lineage = resolve_full_lineage_for_gold(mname, sql_models, upstream)
    
    # 2. Build Mermaid Lineage
    mermaid_lines = [
        "flowchart LR",
        "  classDef bronze fill:#ffe4e6,stroke:#e11d48,stroke-width:1px,color:#9f1239;",
        "  classDef silver fill:#d1fae5,stroke:#059669,stroke-width:1px,color:#065f46;",
        "  classDef gold fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e40af;",
        "  classDef target fill:#fef3c7,stroke:#d97706,stroke-width:3px,color:#92400e;"
    ]
    
    # Subgraph Bronze
    if lineage["bronze_sources"]:
        mermaid_lines.append("  subgraph BRONZE [1. BRONZE 원천]")
        for s in lineage["bronze_sources"]:
            src_key = (s[0], s[1])
            src_info = sources_meta.get(src_key, {})
            s_desc = src_info.get("description", "").split("\n")[0].strip()[:20]
            node_id = f"B_{s[0]}_{s[1]}".replace("-", "_")
            node_label = f"{s[1]}<br/>{s_desc}" if s_desc else s[1]
            mermaid_lines.append(f"    {node_id}[\"{node_label}\"]:::bronze")
        mermaid_lines.append("  end")

    # Subgraph Silver
    if lineage["silver_models"]:
        mermaid_lines.append("  subgraph SILVER [2. SILVER 정제/가공]")
        for sm in lineage["silver_models"]:
            sm_info = models_meta.get(sm, {})
            sm_desc = sm_info.get("description", "").split("\n")[0].strip()[:20]
            node_id = f"S_{sm}".replace("-", "_")
            node_label = f"{sm}<br/>{sm_desc}" if sm_desc else sm
            mermaid_lines.append(f"    {node_id}[\"{node_label}\"]:::silver")
        mermaid_lines.append("  end")

    # Subgraph Gold
    mermaid_lines.append("  subgraph GOLD [3. GOLD 마트]")
    target_id = f"G_{mname}".replace("-", "_")
    target_desc = korean_title[:25]
    mermaid_lines.append(f"    {target_id}[\"★ {mname}<br/>{target_desc}\"]:::target")
    for gp in lineage["gold_parents"]:
        gp_info = models_meta.get(gp, {})
        gp_desc = gp_info.get("description", "").split("\n")[0].strip()[:20]
        node_id = f"G_{gp}".replace("-", "_")
        node_label = f"{gp}<br/>{gp_desc}" if gp_desc else gp
        mermaid_lines.append(f"    {node_id}[\"{node_label}\"]:::gold")
    mermaid_lines.append("  end")

    # Edges
    for src_type, src_node, tgt_type, tgt_node in lineage["edges"]:
        if src_type == "BRONZE":
            parts = src_node.split(".")
            s_id = f"B_{parts[0]}_{parts[1]}".replace("-", "_")
        elif src_type == "SILVER":
            s_id = f"S_{src_node}".replace("-", "_")
        else:
            s_id = f"G_{src_node}".replace("-", "_")

        if tgt_type == "SILVER":
            t_id = f"S_{tgt_node}".replace("-", "_")
        else:
            t_id = f"G_{tgt_node}".replace("-", "_")

        mermaid_lines.append(f"  {s_id} --> {t_id}")

    mermaid_lineage_code = "\n".join(mermaid_lines)

    # 3. Build Mermaid ERD (Related Gold Tables)
    related_rels = [r for r in all_relationships if r["from_table"] == mname or r["to_table"] == mname]
    erd_lines = ["erDiagram"]
    
    erd_entities = {mname}
    for r in related_rels:
        erd_entities.add(r["from_table"])
        erd_entities.add(r["to_table"])

    for ent in sorted(erd_entities):
        ent_meta = models_meta.get(ent, {})
        erd_lines.append(f"  {ent} {{")
        for cname, cinfo in ent_meta.get("columns", {}).items():
            tests = cinfo.get("tests", [])
            is_pk = "unique" in tests and "not_null" in tests
            is_fk = any(isinstance(t, dict) and "relationships" in t for t in tests)
            is_conform = any(pat_col == cname for _, pat_col, _, _, _ in LOGICAL_CONFORM_FKS)
            if is_pk:
                erd_lines.append(f"    string {cname} PK")
            elif is_fk or is_conform:
                erd_lines.append(f"    string {cname} FK")
            elif cname.endswith(("_SK", "_KEY", "_DK", "_ID", "_NO")):
                erd_lines.append(f"    string {cname}")
        erd_lines.append("  }")

    seen_rel_keys = set()
    for r in related_rels:
        rel_key = (r["to_table"], r["from_table"], r["from_col"])
        if rel_key in seen_rel_keys:
            continue
        seen_rel_keys.add(rel_key)
        op = "||..o{" if "Logical" in r.get("source", "") else "||--o{"
        erd_lines.append(f'  {r["to_table"]} {op} {r["from_table"]} : "{r["from_col"]}"')

    if not related_rels:
        erd_lines.append(f"  {mname} {{")
        erd_lines.append("    string ID PK")
        erd_lines.append("  }")

    mermaid_erd_code = "\n".join(erd_lines)

    # 4. Build Sidebar Items (with per-item line breaks)
    sidebar_items_dim = []
    sidebar_items_fact = []

    for gn in sorted(all_gold_names):
        active_cls = " active" if gn == mname else ""
        item_html = f'<a href="{gn}.html" class="nav-item{active_cls}"><span>{gn}</span></a>'
        if gn.startswith("DIM_"):
            sidebar_items_dim.append(item_html)
        elif gn.startswith("FACT_"):
            sidebar_items_fact.append(item_html)

    sidebar_dim_str = "\n".join(sidebar_items_dim)
    sidebar_fact_str = "\n".join(sidebar_items_fact)

    # 5. Columns Table
    columns_html = []
    for cname, cinfo in mdata.get("columns", {}).items():
        cdesc = cinfo.get("description", "")
        dtype = cinfo.get("data_type", "VARCHAR")
        tests = cinfo.get("tests", [])
        is_pk = "unique" in tests and "not_null" in tests
        is_fk = any(isinstance(t, dict) and "relationships" in t for t in tests)
        is_conform = any(pat_col == cname for _, pat_col, _, _, _ in LOGICAL_CONFORM_FKS)
        
        key_badge = ""
        if is_pk:
            key_badge = '<span class="badge badge-dim">PK</span>'
        elif is_fk:
            key_badge = '<span class="badge badge-fact">FK</span>'
        elif is_conform:
            key_badge = '<span class="badge badge-wide">CONFORM</span>'
        elif cname.endswith(("_DK", "_BK")):
            key_badge = '<span class="badge badge-silver">DK</span>'

        columns_html.append(f"""        <tr>
          <td><code>{escape_html(cname)}</code></td>
          <td><code>{escape_html(dtype)}</code></td>
          <td>{key_badge}</td>
          <td>{escape_html(cdesc)}</td>
        </tr>""")

    columns_str = "\n".join(columns_html)

    # 6. Upstream Details
    bronze_cards = []
    for s in lineage["bronze_sources"]:
        src_key = (s[0], s[1])
        src_info = sources_meta.get(src_key, {})
        s_desc = src_info.get("description", "원천 테이블")
        bronze_cards.append(f"<li><b>{s[0]}.{s[1]}</b>: {escape_html(s_desc)}</li>")

    silver_cards = []
    for sm in lineage["silver_models"]:
        sm_info = models_meta.get(sm, {})
        sm_desc = sm_info.get("description", "정제 모델")
        silver_cards.append(f"<li><b>{sm}</b>: {escape_html(sm_desc)}</li>")

    bronze_cards_str = "\n".join(bronze_cards) if bronze_cards else "<li>직접 참조 원천 없음 (생성 쿼리)</li>"
    silver_cards_str = "\n".join(silver_cards) if silver_cards else "<li>직접 참조 모델 없음</li>"

    rel_rows = []
    for r in related_rels:
        rel_rows.append(f"""        <tr>
          <td><code>{escape_html(r['from_table'])}</code></td>
          <td><code>{escape_html(r['from_col'])}</code></td>
          <td>➔</td>
          <td><a href="{r['to_table']}.html"><code>{escape_html(r['to_table'])}</code></a></td>
          <td><code>{escape_html(r['to_col'])}</code></td>
          <td><span class="badge badge-domain">{escape_html(r['source'])}</span></td>
          <td>{escape_html(r['type'])}</td>
        </tr>""")

    rel_rows_str = "\n".join(rel_rows)

    # Assemble HTML
    html_content = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="snowflake-source" content="cortex-agent-authored" />
  <title>{mname} - Pipeline ERD & Lineage</title>
  <script type="application/json" id="snowflake-report-metadata">
  {{
    "generated": "{ts}",
    "intent": "Bronze > Silver > Gold Pipeline Lineage and ERD for {mname}",
    "table": "{mname}",
    "domain": "{domain}",
    "type": "{table_type}"
  }}
  </script>
  <style>
{COMMON_STYLE}
  </style>
</head>
<body>
  <div class="layout-container">
    <!-- Sidebar -->
    <aside class="sidebar">
      <div class="sidebar-header">
        <div class="sidebar-title">GN DW ERD & Lineage</div>
        <div class="sidebar-subtitle">Bronze ➔ Silver ➔ Gold 파이프라인</div>
      </div>
      <div class="sidebar-search">
        <input type="text" id="nav-filter" placeholder="테이블 검색..." />
      </div>
      <nav class="sidebar-nav">
        <a href="index.html" class="nav-item"><b>🏠 전체 파이프라인 허브</b></a>
        <div class="nav-group-title">DIMENSION ({len(sidebar_items_dim)})</div>
{sidebar_dim_str}
        <div class="nav-group-title">FACT ({len(sidebar_items_fact)})</div>
{sidebar_fact_str}
      </nav>
    </aside>

    <!-- Main Content -->
    <main class="main-content">
      <!-- Header Card -->
      <div class="header-card">
        <div class="header-top">
          <div class="title-area">
            <h1>
              <span>{mname}</span>
              <span class="badge {badge_class}">{type_label}</span>
            </h1>
            <div class="korean-title">{escape_html(korean_title)}</div>
          </div>
          <div>
            <a href="index.html" style="font-size: 0.85rem;">◀ 전체 목록으로</a>
          </div>
        </div>
        <div class="meta-badges">
          <span class="badge badge-domain">도메인: {domain}</span>
          <span class="badge badge-domain">BRONZE 원천: {len(lineage['bronze_sources'])}개</span>
          <span class="badge badge-domain">SILVER 모델: {len(lineage['silver_models'])}개</span>
          <span class="badge badge-domain">컬럼 수: {len(mdata.get('columns', {}))}개</span>
        </div>
        {f"<p style='margin: 12px 0 0 0; font-size: 0.9rem; color: var(--text-muted);'>{escape_html(mdata.get('description', ''))}</p>" if mdata.get('description') else ""}
      </div>

      <!-- 1. Pipeline Lineage Diagram -->
      <div class="section-card">
        <h2 class="section-title">📊 1. Bronze ➔ Silver ➔ Gold 3단계 파이프라인 계보 (Lineage)</h2>
        <p style="font-size: 0.85rem; color: var(--text-muted); margin-top: 0;">
          원천 데이터(Bronze)에서 중간 정제/변환(Silver)을 거쳐 최종 마트({mname})로 데이터가 유입되는 전체 경로입니다.
        </p>
        <div class="lineage-diag-wrap">
          <pre class="mermaid">
{mermaid_lineage_code}
          </pre>
        </div>

        <div class="flow-steps">
          <div class="flow-step-box">
            <div class="flow-step-title">
              <span class="badge badge-bronze">BRONZE</span> 원천 테이블 ({len(lineage['bronze_sources'])}개)
            </div>
            <ul class="flow-step-list">
{bronze_cards_str}
            </ul>
          </div>
          <div class="flow-step-box">
            <div class="flow-step-title">
              <span class="badge badge-silver">SILVER</span> 중간 모델 ({len(lineage['silver_models'])}개)
            </div>
            <ul class="flow-step-list">
{silver_cards_str}
            </ul>
          </div>
        </div>
      </div>

      <!-- 2. Gold ERD & Relationships -->
      <div class="section-card">
        <h2 class="section-title">🔗 2. GOLD 레벨 ERD 및 관계 (Relationships)</h2>
        <p style="font-size: 0.85rem; color: var(--text-muted); margin-top: 0;">
          {mname} 테이블과 조인/참조 관계를 맺고 있는 GOLD 계층의 연관 테이블 및 외래키(FK/Conform) 명세입니다.
        </p>
        <div class="lineage-diag-wrap">
          <pre class="mermaid">
{mermaid_erd_code}
          </pre>
        </div>

        {f'''
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>출발 테이블</th>
                <th>출발 컬럼</th>
                <th></th>
                <th>대상 테이블</th>
                <th>대상 컬럼</th>
                <th>관계 출처</th>
                <th>관계 유형</th>
              </tr>
            </thead>
            <tbody>
{rel_rows_str}
            </tbody>
          </table>
        </div>
        ''' if rel_rows else "<p style='font-size:0.85rem; color:var(--text-muted);'>연결된 외부 참조 관계가 없는 독립 테이블입니다.</p>"}
      </div>

      <!-- 3. Column Catalog -->
      <div class="section-card">
        <h2 class="section-title">📋 3. 컬럼 명세서 (Column Specifications)</h2>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>컬럼명</th>
                <th>데이터 타입</th>
                <th>속성</th>
                <th>한글 설명 (Description / Comment)</th>
              </tr>
            </thead>
            <tbody>
{columns_str}
            </tbody>
          </table>
        </div>
      </div>

      <!-- 4. dbt SQL Source -->
      <div class="section-card">
        <h2 class="section-title">💻 4. dbt SQL 변환 로직 (Source Code)</h2>
        <details>
          <summary>dbt SQL 소스 코드 보기 ({sdata.get('sql_path', '')})</summary>
          <div class="sql-code-box">
            <pre><code>{escape_html(sdata.get('raw_sql', ''))}</code></pre>
          </div>
        </details>
      </div>
    </main>
  </div>

  <script src="/libs/mermaid@10.9.6/mermaid.min.js"></script>
  <script>
    mermaid.initialize({{ startOnLoad: true, securityLevel: 'strict' }});
    
    // Search filter for sidebar
    const searchInput = document.getElementById('nav-filter');
    if (searchInput) {{
      searchInput.addEventListener('input', function() {{
        const q = this.value.toLowerCase();
        document.querySelectorAll('.nav-item').forEach(el => {{
          const text = el.textContent.toLowerCase();
          if (text.includes(q)) {{
            el.style.display = 'flex';
          }} else {{
            el.style.display = 'none';
          }}
        }});\n      }});\n    }}
  </script>
</body>
</html>
"""
    return html_content

# ══════════════════════════════════════════════════════════════════════════════
# 7. Index Hub Generator
# ══════════════════════════════════════════════════════════════════════════════

def generate_index_html(models_meta, sources_meta, sql_models, upstream, all_gold_names, ts):
    num_bronze = len(sources_meta)
    num_silver = len([m for m in sql_models if not m.startswith(("DIM_", "FACT_", "WIDE_"))])
    num_dim = len([m for m in all_gold_names if m.startswith("DIM_")])
    num_fact = len([m for m in all_gold_names if m.startswith("FACT_")])
    num_gold = len(all_gold_names)

    table_cards = []
    matrix_rows = []

    for gn in sorted(all_gold_names):
        mdata = models_meta.get(gn, {"description": "", "columns": {}})
        table_type, type_label, badge_class = get_table_type(gn)
        domain = get_table_domain(gn)
        korean_title = get_clean_korean_title(mdata["description"], gn)
        lineage = resolve_full_lineage_for_gold(gn, sql_models, upstream)
        
        bronze_list_str = ", ".join([f"{s[1]}" for s in lineage["bronze_sources"][:4]])
        if len(lineage["bronze_sources"]) > 4:
            bronze_list_str += f" 외 {len(lineage['bronze_sources']) - 4}개"
        if not bronze_list_str:
            bronze_list_str = "(독립 생성)"

        silver_list_str = ", ".join(lineage["silver_models"][:4])
        if len(lineage["silver_models"]) > 4:
            silver_list_str += f" 외 {len(lineage['silver_models']) - 4}개"
        if not silver_list_str:
            silver_list_str = "(직접 변환)"

        table_cards.append(f"""        <div class="table-grid-card" data-domain="{domain}" data-type="{table_type}">
          <div class="card-header">
            <span class="badge {badge_class}">{table_type}</span>
            <span class="badge badge-domain">{domain.split('/')[0].strip()}</span>
          </div>
          <h3 class="card-title"><a href="{gn}.html">{gn}</a></h3>
          <div class="card-desc">{escape_html(korean_title)}</div>
          <div class="card-meta">
            <div><b>Bronze:</b> {len(lineage['bronze_sources'])}개 ({escape_html(bronze_list_str)})</div>
            <div><b>Silver:</b> {len(lineage['silver_models'])}개 ({escape_html(silver_list_str)})</div>
            <div><b>컬럼:</b> {len(mdata.get('columns', {}))}개</div>
          </div>
          <a href="{gn}.html" class="card-btn">상세 계보 & ERD 보기 ➔</a>
        </div>""")

        matrix_rows.append(f"""        <tr data-domain="{domain}" data-type="{table_type}">
          <td><span class="badge {badge_class}">{table_type}</span></td>
          <td><a href="{gn}.html"><b>{gn}</b></a></td>
          <td>{escape_html(korean_title)}</td>
          <td><span class="badge badge-domain">{domain}</span></td>
          <td><code>{escape_html(bronze_list_str)}</code></td>
          <td><code>{escape_html(silver_list_str)}</code></td>
          <td><a href="{gn}.html" class="badge badge-dim">상세보기</a></td>
        </tr>""")

    cards_str = "\n".join(table_cards)
    matrix_str = "\n".join(matrix_rows)

    index_html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="snowflake-source" content="cortex-agent-authored" />
  <title>Good Neighbors DW - Pipeline ERD & Lineage Hub</title>
  <script type="application/json" id="snowflake-report-metadata">
  {{
    "generated": "{ts}",
    "intent": "Bronze > Silver > Gold Full Data Pipeline ERD & Lineage Hub",
    "stats": {{
      "bronze_sources": {num_bronze},
      "silver_models": {num_silver},
      "gold_tables": {num_gold},
      "dim_count": {num_dim},
      "fact_count": {num_fact}
    }}
  }}
  </script>
  <style>
{COMMON_STYLE}
  </style>
</head>
<body>
  <div style="max-width: 1400px; margin: 0 auto; padding: 24px;">
    <!-- Hero Header -->
    <div class="header-card">
      <div class="header-top">
        <div>
          <h1 style="margin: 0 0 8px 0;">🌐 Good Neighbors Data Warehouse - 파이프라인 ERD & Lineage</h1>
          <div style="font-size: 1.05rem; color: var(--text-muted);">
            BRONZE (원천 데이터) ➔ SILVER (정제/표준화 모델) ➔ GOLD (차원/팩트) 엔드투엔드 계보 및 ERD 카탈로그
          </div>
        </div>
      </div>
    </div>

    <!-- Stats -->
    <div class="hero-stats">
      <div class="stat-card stat-bronze">
        <div class="stat-label">BRONZE 원천 소스</div>
        <div class="stat-num">{num_bronze}</div>
        <div style="font-size:0.75rem; color:var(--text-muted);">CRM, ERP, AGENCY, GA4</div>
      </div>
      <div class="stat-card stat-silver">
        <div class="stat-label">SILVER 정제 모델</div>
        <div class="stat-num">{num_silver}</div>
        <div style="font-size:0.75rem; color:var(--text-muted);">표준화 및 비즈니스 정제</div>
      </div>
      <div class="stat-card stat-gold">
        <div class="stat-label">GOLD 마트 테이블</div>
        <div class="stat-num">{num_gold}</div>
        <div style="font-size:0.75rem; color:var(--text-muted);">DIM {num_dim} + FACT {num_fact}</div>
      </div>
    </div>

    <!-- Filter Bar -->
    <div class="section-card">
      <div class="filter-bar">
        <span style="font-size: 0.85rem; font-weight: 700; margin-right: 8px;">필터:</span>
        <button class="filter-btn active" data-filter="all">전체 ({num_gold})</button>
        <button class="filter-btn" data-filter="DIM">DIM 차원 ({num_dim})</button>
        <button class="filter-btn" data-filter="FACT">FACT 팩트 ({num_fact})</button>
        <button class="filter-btn" data-filter="CRM">회원·후원 (CRM)</button>
        <button class="filter-btn" data-filter="ERP">예산·목표 (ERP)</button>
        <button class="filter-btn" data-filter="AGENCY">마케팅·광고 (AGENCY)</button>
        <button class="filter-btn" data-filter="GA4">디지털 행동 (GA4)</button>
        <input type="text" id="grid-search" placeholder="테이블 검색..." style="margin-left:auto; padding: 6px 12px; border-radius: 6px; border: 1px solid var(--border-color); background: var(--bg-subtle); color: var(--text-main);" />
      </div>

      <!-- Grid Cards -->
      <div class="table-grid" id="card-grid">
{cards_str}
      </div>
    </div>

    <!-- Matrix Table -->
    <div class="section-card">
      <h2 class="section-title">📑 전체 파이프라인 매트릭스 (Bronze ➔ Silver ➔ Gold 매핑 표)</h2>
      <div class="table-wrap">
        <table id="matrix-table">
          <thead>
            <tr>
              <th>유형</th>
              <th>GOLD 테이블명</th>
              <th>한글 설명</th>
              <th>도메인</th>
              <th>BRONZE 원천 소스</th>
              <th>SILVER 정제 모델</th>
              <th>상세</th>
            </tr>
          </thead>
          <tbody>
{matrix_str}
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <script>
    // Filter buttons
    const filterBtns = document.querySelectorAll('.filter-btn');
    const cards = document.querySelectorAll('.table-grid-card');
    const tableRows = document.querySelectorAll('#matrix-table tbody tr');
    const searchInput = document.getElementById('grid-search');

    function applyFilters() {{
      const activeBtn = document.querySelector('.filter-btn.active');
      const filter = activeBtn ? activeBtn.getAttribute('data-filter') : 'all';
      const query = searchInput ? searchInput.value.toLowerCase() : '';

      cards.forEach(c => {{
        const cType = c.getAttribute('data-type');
        const cDomain = c.getAttribute('data-domain');
        const text = c.textContent.toLowerCase();
        
        let matchFilter = (filter === 'all') || (cType === filter) || (cDomain.includes(filter));
        let matchQuery = !query || text.includes(query);

        if (matchFilter && matchQuery) {{
          c.style.display = 'flex';
        }} else {{
          c.style.display = 'none';
        }}
      }});

      tableRows.forEach(r => {{
        const rType = r.getAttribute('data-type');
        const rDomain = r.getAttribute('data-domain');
        const text = r.textContent.toLowerCase();

        let matchFilter = (filter === 'all') || (rType === filter) || (rDomain.includes(filter));
        let matchQuery = !query || text.includes(query);

        if (matchFilter && matchQuery) {{
          r.style.display = '';
        }} else {{
          r.style.display = 'none';
        }}
      }});
    }}

    filterBtns.forEach(btn => {{
      btn.addEventListener('click', function() {{
        filterBtns.forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        applyFilters();
      }});
    }});

    if (searchInput) {{
      searchInput.addEventListener('input', applyFilters);
    }}
  </script>
</body>
</html>
"""
    return index_html

# ══════════════════════════════════════════════════════════════════════════════
# 8. Main Execution
# ══════════════════════════════════════════════════════════════════════════════

def main():
    print("[1/5] YAML 및 SQL, DDL 메타데이터 로드 중...")
    models_meta, sources_meta = load_yaml_metadata()
    ddl_tables = load_ddl_metadata()
    sql_models = load_sql_metadata()

    # Merge DDL metadata into models_meta for tables where YAML is sparse
    for tname, ddl_info in ddl_tables.items():
        if tname not in models_meta:
            models_meta[tname] = {
                "name": tname,
                "description": ddl_info["description"],
                "columns": ddl_info["columns"],
                "yaml_path": "03_top-down_gold/06_DDL.sql"
            }
        else:
            if not models_meta[tname]["description"] and ddl_info["description"]:
                models_meta[tname]["description"] = ddl_info["description"]
            for cname, cinfo in ddl_info["columns"].items():
                if cname not in models_meta[tname]["columns"]:
                    models_meta[tname]["columns"][cname] = cinfo
                else:
                    if not models_meta[tname]["columns"][cname]["description"] and cinfo["description"]:
                        models_meta[tname]["columns"][cname]["description"] = cinfo["description"]
                    if models_meta[tname]["columns"][cname].get("data_type") in [None, "VARCHAR"]:
                        models_meta[tname]["columns"][cname]["data_type"] = cinfo["data_type"]

    print(f"      · 메타데이터 병합 완료: 총 {len(models_meta)}개 모델")

    print("[2/5] 리니지 및 의존성 그래프 구축 중...")
    upstream, downstream = build_lineage_graph(sql_models)
    all_gold_names = sorted([m for m in sql_models if m.startswith(("DIM_", "FACT_"))])
    print(f"      · GOLD 대상 테이블: {len(all_gold_names)}개 (DIM & FACT)")

    print("[3/5] 외래키 및 ERD 관계 추출 중...")
    all_relationships = extract_gold_relationships(models_meta)
    print(f"      · GOLD 관계선: {len(all_relationships)}개")

    print(f"[4/5] 출력 폴더 준비: {OUT_DIR}")
    os.makedirs(OUT_DIR, exist_ok=True)

    ts = datetime.now().strftime("%Y-%m-%d %H:%M")

    print("[5/5] HTML 문서 생성 중...")
    index_html = generate_index_html(models_meta, sources_meta, sql_models, upstream, all_gold_names, ts)
    index_path = os.path.join(OUT_DIR, "index.html")
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(index_html)
    print(f"      · 🟢 index.html 생성 완료 ({os.path.relpath(index_path, ROOT)})")

    for gn in all_gold_names:
        table_html = generate_table_html(gn, models_meta, sources_meta, sql_models, upstream, all_gold_names, all_relationships, ts)
        tbl_path = os.path.join(OUT_DIR, f"{gn}.html")
        with open(tbl_path, "w", encoding="utf-8") as f:
            f.write(table_html)

    print(f"      · 🟢 {len(all_gold_names)}개 개별 테이블 HTML 문서 생성 완료!")
    print(f"\n🎉 전체 파이프라인 ERD & Lineage 생성 완료: {OUT_DIR}")

if __name__ == "__main__":
    main()
