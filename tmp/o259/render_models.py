"""O259 — 신규 Silver 2 + 슬림 Gold 2 를 dbt 없이 렌더(ref→CTE)해 라이브 GOLD 와 MINUS 대조용 SQL 생성.

dbt 를 실행하지 않는다(R4-1). 렌더 = ref·config·set·gold_sk·gold_meta 치환뿐.
"""
import io, re

M = "/workspace/10_dbt_pipeline/models"
SRC = {
    "CRM_ORG": "GN_DW.SILVER.CRM_ORG",
    "CRM_MEMBER_DEV": "GN_DW.SILVER.CRM_MEMBER_DEV",
    "CRM_MEMBER_SPONSOR_SPAN": "GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN",
    "ORG_SUCCESSION_MANUAL": "GN_DW.GOLD.ORG_SUCCESSION_MANUAL",
    "CRM_ORG_CLEAN": "T_CLEAN",
    "CRM_ORG_SUCCESSION": "T_SUCC",
}


def gold_sk(m):
    cols = [c.strip().strip("'\"") for c in m.group(1).split(",")]
    return "ABS(HASH(" + " || '‖' || ".join("COALESCE(CAST(%s AS VARCHAR), '∅')" % c for c in cols) + "))"


def render(path):
    s = io.open(path, encoding="utf-8").read()
    s = re.sub(r"\{\{\s*config\(.*?\)\s*\}\}", "", s, flags=re.S)
    s = re.sub(r"\{%-?\s*set .*?%\}", "", s)
    s = s.replace("{{ min_lift }}", "3").replace("{{ min_evd }}", "30")
    s = re.sub(r"\{\{\s*ref\('(\w+)'\)\s*\}\}", lambda m: SRC[m.group(1)], s)
    s = re.sub(r"\{\{\s*gold_sk\(\[(.*?)\]\)\s*\}\}", gold_sk, s)
    s = re.sub(r"\{\{\s*gold_meta\('CRM'\)\s*\}\}",
               "'CRM' AS DW_SOURCE_SYSTEM, NULL::TIMESTAMP_NTZ AS DW_LOAD_TS, NULL::TIMESTAMP_NTZ AS DW_UPDATE_TS, NULL AS DW_BATCH_ID", s)
    s = "\n".join(l for l in s.split("\n") if not l.lstrip().startswith("--"))
    assert "{{" not in s and "{%" not in s, path
    return s.strip()


def as_cte(name, body):
    # 모델 본문이 WITH [RECURSIVE] 로 시작하면 서브쿼리로 감싼다
    return "%s AS (SELECT * FROM (\n%s\n))" % (name, body)


clean = render(M + "/silver/crm/CRM_ORG_CLEAN.sql")
succ = render(M + "/silver/crm/CRM_ORG_SUCCESSION.sql")
dorg = render(M + "/gold/dim/DIM_ORG.sql")
dsucc = render(M + "/gold/dim/DIM_ORG_SUCCESSION.sql")
io.open("/workspace/tmp/o259/render_clean.sql", "w", encoding="utf-8").write(clean)
io.open("/workspace/tmp/o259/render_succ.sql", "w", encoding="utf-8").write(succ)
io.open("/workspace/tmp/o259/render_dim_org.sql", "w", encoding="utf-8").write(dorg)
io.open("/workspace/tmp/o259/render_dim_succ.sql", "w", encoding="utf-8").write(dsucc)
print("rendered 4")
