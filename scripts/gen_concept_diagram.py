# GN_DW 개념도(HTML) 생성기 — 계층 인벤토리 · 계보 · 적재 상태 브라우저
# Co-authored with CoCo
"""
`30_output_share/03_GN_DW_개념도.html` 를 **실측 파생**으로 생성한다.

⚠️ 설계 전환 (2026-08-06)
  구 판본은 객체 목록·한글 설명·행수를 HTML 안에 손으로 적어 두었다. 그래서 신설 객체
  (`FACT_MEMBER_COHORT`·`FACT_AD_*` 3종·`DIM_SEND_TYPE`·`WIDE_AD_*` 3종·`FACT_DEV_ACHIEVEMENT`)가
  누락되고 이미 없는 객체(`ERP_BIZ_TARGET`)가 남아 있었다.
  → 이 판본은 카탈로그·census·dbt 계보를 읽어 만든다. 객체 목록을 손으로 적지 않는다.

입력
  /tmp/schema.json   (dump_schema.py — INFORMATION_SCHEMA 스냅샷)
  /tmp/census.json   (census.py — 컬럼 COUNT/COUNT_IF 실측)
  DB TABLES.COMMENT  (설명 1순위 — 배포 객체에 실제로 붙어 있는 문장)
  99_provided_definition/테이블정의 20260629.csv (BRONZE_CRM 테이블 설명)
  10_dbt_pipeline/models (ref()/source() 계보)

출력: 30_output_share/03_GN_DW_개념도.html (단일 파일 · 외부 요청 0 · 데이터 전량 인라인)
"""
import csv, json, os, re, sys, html, collections
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/tmp")
from sfconn import conn, q

WS = os.environ.get("GN_DW_WS", "/workspace")
OUT_DIR = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
OUT = os.path.join(OUT_DIR, "03_GN_DW_개념도.html")
GEN_PATH = "scripts/gen_concept_diagram.py"
MEASURED = os.environ.get("GN_DW_MEASURED", date.today().isoformat())
MODELS = os.path.join(WS, "10_dbt_pipeline", "models")
TBLDEF = os.path.join(WS, "99_provided_definition", "테이블정의 20260629.csv")
AUDIT = {"DW_SOURCE_SYSTEM", "DW_SOURCE_TABLE", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"}

LAYERS = [
    ("BRONZE", ["BRONZE_CRM", "BRONZE_AGENCY", "BRONZE_ERP", "BRONZE_GA4"], "원천 적재 — 무손실"),
    ("SILVER", ["SILVER"], "정제·표준화 — 코드 보존·ID 통합"),
    ("GOLD", ["GOLD"], "표준 지표 — 팩트/차원 + WIDE 소비뷰"),
    ("SERVING", ["SERVING"], "소비 — Semantic View / Agent 전용"),
]


def load_models():
    out = {}
    for root, _, files in os.walk(MODELS):
        for fn in files:
            if not fn.endswith(".sql"):
                continue
            raw = open(os.path.join(root, fn), encoding="utf-8").read()
            rel = os.path.relpath(os.path.join(root, fn), MODELS)
            out[fn[:-4]] = {
                "layer": rel.split(os.sep)[0], "path": rel,
                "refs": sorted(set(re.findall(r"ref\(\s*['\"]([A-Za-z0-9_]+)['\"]\s*\)", raw))),
                "sources": sorted(set(re.findall(r"source\(\s*['\"][^'\"]+['\"]\s*,\s*['\"]([A-Za-z0-9_]+)['\"]\s*\)", raw))),
            }
    return out


def main():
    schema = json.load(open("/tmp/schema.json", encoding="utf-8"))
    census = json.load(open("/tmp/census.json", encoding="utf-8"))
    models = load_models()

    cn = conn()
    _, trows = q("""select table_schema, table_name, table_type, row_count, comment
                    from GN_DW.INFORMATION_SCHEMA.TABLES
                    where table_schema in ('BRONZE_CRM','BRONZE_AGENCY','BRONZE_ERP','BRONZE_GA4',
                                           'SILVER','GOLD','SERVING')""", cn)
    _, crows = q("""select table_schema, table_name, column_name, data_type, comment
                    from GN_DW.INFORMATION_SCHEMA.COLUMNS
                    where table_schema in ('BRONZE_CRM','BRONZE_AGENCY','BRONZE_ERP','BRONZE_GA4',
                                           'SILVER','GOLD','SERVING')
                    order by table_schema, table_name, ordinal_position""", cn)
    try:
        _, svrows = q("show semantic views in schema GN_DW.SERVING", cn)
        svs = [(r[1], (r[4] or "")) for r in svrows]
    except Exception:
        svs = []
    cn.close()

    bronze_desc = {}
    if os.path.exists(TBLDEF):
        for r in csv.DictReader(open(TBLDEF, encoding="utf-8-sig")):
            t = (r.get("테이블명") or "").strip()
            d = (r.get("테이블설명") or "").strip()
            if t and d:
                bronze_desc[t] = d

    cols = collections.defaultdict(list)
    for s, t, c, dt, cm in crows:
        cols[(s, t)].append({"c": c, "t": dt, "m": cm or ""})

    # ── 객체 조립 ──
    objs = []
    for s, t, ty, rc, cm in trows:
        key = (s, t)
        cl = cols.get(key, [])
        data_cols = [c for c in cl if c["c"] not in AUDIT]
        cen = census.get(f"{s}.{t}")
        nfill = nzero = nnull = 0
        colinfo = []
        for c in data_cols:
            st = ""
            if cen:
                i = cen["cols"].get(c["c"])
                if i:
                    nn, nz = int(i["nonnull"] or 0), int(i["nonzero"] or 0)
                    if cen["rows"] == 0:
                        st = "empty"
                    elif nn == 0:
                        st = "null"; nnull += 1
                    elif nz == 0:
                        st = "zero"; nzero += 1
                    else:
                        st = "ok"; nfill += 1
            colinfo.append({"c": c["c"], "t": c["t"], "m": c["m"], "s": st})
        desc = (cm or "").strip() or bronze_desc.get(t, "")
        m = models.get(t)
        objs.append({
            "schema": s, "name": t, "type": "VIEW" if ty == "VIEW" else "TABLE",
            "layer": next(L for L, ss, _ in LAYERS if s in ss),
            "rows": rc if rc is not None else (cen or {}).get("rows"),
            "ncols": len(data_cols), "desc": desc,
            "fill": nfill, "zero": nzero, "null": nnull,
            "model": (m or {}).get("path", ""),
            "upstream": ((m or {}).get("refs") or []) + ((m or {}).get("sources") or []),
            "cols": colinfo,
        })
    for name, cm in svs:
        objs.append({"schema": "SERVING", "name": name, "type": "SEMANTIC VIEW", "layer": "SERVING",
                     "rows": None, "ncols": 0, "desc": (cm or "").strip(),
                     "fill": 0, "zero": 0, "null": 0, "model": "05_SV-Agent_ai/05_*_SV_DDL_*.sql",
                     "upstream": [], "cols": []})

    # 하류(downstream) 역인덱스
    down = collections.defaultdict(set)
    for o in objs:
        for u in o["upstream"]:
            down[u].add(o["name"])
    for o in objs:
        o["downstream"] = sorted(down.get(o["name"], []))

    # ── 요약 통계 ──
    stat = collections.Counter()
    for o in objs:
        stat[o["layer"]] += 1
    gold_empty0 = sum(len([c for c in o["cols"] if c["s"] == "empty"]) for o in objs
                      if o["schema"] == "GOLD" and o["type"] == "TABLE")
    gold_data = sum(o["fill"] + o["zero"] + o["null"] for o in objs
                    if o["schema"] == "GOLD" and o["type"] == "TABLE") + gold_empty0
    gold_fill = sum(o["fill"] for o in objs if o["schema"] == "GOLD" and o["type"] == "TABLE")
    gold_zero = sum(o["zero"] for o in objs if o["schema"] == "GOLD" and o["type"] == "TABLE")
    gold_null = sum(o["null"] for o in objs if o["schema"] == "GOLD" and o["type"] == "TABLE")
    gold_empty = sum(len([c for c in o["cols"] if c["s"] == "empty"]) for o in objs
                     if o["schema"] == "GOLD" and o["type"] == "TABLE")
    bronze_rows = sum((o["rows"] or 0) for o in objs if o["layer"] == "BRONZE")

    meta = {
        "generated": MEASURED,
        "intent": "GN_DW 전 계층 객체 인벤토리 · 계보 · 컬럼 적재 상태 브라우저",
        "generator": GEN_PATH,
        "dataSources": [
            {"type": "query", "warehouse": "COMPUTE_WH",
             "sql": "SELECT table_schema, table_name, table_type, row_count, comment FROM GN_DW.INFORMATION_SCHEMA.TABLES"},
            {"type": "query", "warehouse": "COMPUTE_WH",
             "sql": "SELECT table_schema, table_name, column_name, data_type, comment FROM GN_DW.INFORMATION_SCHEMA.COLUMNS"},
            {"type": "query", "warehouse": "COMPUTE_WH",
             "sql": "SELECT COUNT(<col>), COUNT_IF(<col> <> 0) FROM GN_DW.<schema>.<table>  -- 전 컬럼 census"},
            {"type": "file", "path": "10_dbt_pipeline/models/**/*.sql",
             "notes": "ref()/source() 파싱으로 계보(상류·하류) 산출"},
        ],
        "sections": [
            {"id": "summary", "title": "계층 요약",
             "producerNotes": "객체 수·행수·컬럼 적재 상태는 전부 카탈로그/census 파생. 하드코딩 없음."},
            {"id": "flow", "title": "계층 흐름",
             "producerNotes": "고정 다이어그램. 계층 정의가 바뀔 때만 생성기 수정."},
            {"id": "inventory", "title": "객체 인벤토리",
             "producerNotes": "OBJECTS 배열이 정본. 클릭 시 컬럼·계보 패널 표시."},
        ],
    }

    js = json.dumps(objs, ensure_ascii=False, separators=(",", ":"))
    metajs = json.dumps(meta, ensure_ascii=False, indent=2)

    H = f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="snowflake-source" content="cortex-agent-authored" />
<title>GN_DW 개념도 — 계층 인벤토리 · 계보 · 적재 상태 ({MEASURED} 실측)</title>
<script type="application/json" id="snowflake-report-metadata">
{metajs}
</script>
<style>
:root {{
  color-scheme: light dark;
  --bg: light-dark(#f8fafc, #0f172a);
  --card: light-dark(#ffffff, #1e293b);
  --border: light-dark(#cbd5e1, #334155);
  --text: light-dark(#0f172a, #f1f5f9);
  --sub: light-dark(#64748b, #94a3b8);
  --chip: light-dark(#f1f5f9, #0b1120);
  --bronze: #b45309; --silver: #64748b; --gold: #ca8a04; --serving: #7c3aed;
  --ok: #059669; --zero: #dc2626; --null: #d97706; --empty: #6b7280;
}}
* {{ box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Malgun Gothic", system-ui, sans-serif;
  margin: 0; padding: 20px; background: var(--bg); color: var(--text); line-height: 1.55; }}
header {{ border-bottom: 2px solid var(--border); padding-bottom: 14px; margin-bottom: 18px; }}
h1 {{ margin: 0 0 6px; font-size: 1.4rem; font-weight: 800; }}
h2 {{ font-size: 1.05rem; margin: 26px 0 10px; padding-bottom: 6px; border-bottom: 1px solid var(--border); }}
.note {{ font-size: 0.84rem; color: var(--sub); }}
.warn {{ background: light-dark(#fef3c7, #422006); border-left: 4px solid var(--null);
  padding: 10px 14px; border-radius: 4px; font-size: 0.85rem; margin: 12px 0; }}
.cards {{ display: flex; flex-wrap: wrap; gap: 10px; margin: 12px 0; }}
.card {{ background: var(--card); border: 1px solid var(--border); border-radius: 8px;
  padding: 10px 14px; min-width: 132px; }}
.card .k {{ font-size: 0.72rem; color: var(--sub); font-weight: 600; }}
.card .v {{ font-size: 1.22rem; font-weight: 800; }}
.card .s {{ font-size: 0.72rem; color: var(--sub); }}
pre.flow {{ background: var(--card); border: 1px solid var(--border); border-radius: 8px;
  padding: 14px; overflow-x: auto; font-size: 0.78rem; line-height: 1.5; }}
.toolbar {{ display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin: 10px 0 14px; }}
input[type=search] {{ padding: 7px 11px; border: 1px solid var(--border); border-radius: 6px;
  background: var(--card); color: var(--text); min-width: 240px; font-size: 0.86rem; }}
button {{ padding: 6px 12px; border: 1px solid var(--border); border-radius: 6px;
  background: var(--card); color: var(--text); cursor: pointer; font-size: 0.8rem; font-weight: 600; }}
button.on {{ background: light-dark(#dbeafe, #1e3a8a); border-color: #3b82f6; }}
table {{ border-collapse: collapse; width: 100%; font-size: 0.82rem; }}
th, td {{ border: 1px solid var(--border); padding: 5px 8px; text-align: left; vertical-align: top; }}
th {{ background: light-dark(#f1f5f9, #1e293b); font-weight: 700; position: sticky; top: 0; }}
td.num {{ text-align: right; font-variant-numeric: tabular-nums; }}
tr.row {{ cursor: pointer; }}
tr.row:hover td {{ background: light-dark(#f8fafc, #172033); }}
.tag {{ display: inline-block; padding: 1px 7px; border-radius: 10px; font-size: 0.7rem;
  font-weight: 700; color: #fff; }}
.tag.BRONZE {{ background: var(--bronze); }} .tag.SILVER {{ background: var(--silver); }}
.tag.GOLD {{ background: var(--gold); }} .tag.SERVING {{ background: var(--serving); }}
.bar {{ display: flex; height: 9px; border-radius: 5px; overflow: hidden; min-width: 74px;
  border: 1px solid var(--border); }}
.bar i {{ display: block; height: 100%; }}
.bar i.ok {{ background: var(--ok); }} .bar i.zero {{ background: var(--zero); }}
.bar i.null {{ background: var(--null); }} .bar i.empty {{ background: var(--empty); }}
.panel {{ background: var(--card); border: 1px solid var(--border); border-radius: 8px;
  padding: 14px; margin: 14px 0; }}
.panel h3 {{ margin: 0 0 6px; font-size: 1rem; }}
.chips {{ display: flex; flex-wrap: wrap; gap: 5px; margin: 5px 0 10px; }}
.chip {{ background: var(--chip); border: 1px solid var(--border); border-radius: 5px;
  padding: 2px 7px; font-size: 0.74rem; font-family: ui-monospace, monospace; }}
.desc {{ font-size: 0.82rem; color: var(--sub); white-space: pre-wrap; margin: 6px 0 10px; }}
.st {{ font-weight: 700; font-size: 0.72rem; }}
.st.ok {{ color: var(--ok); }} .st.zero {{ color: var(--zero); }}
.st.null {{ color: var(--null); }} .st.empty {{ color: var(--empty); }}
.legend {{ font-size: 0.76rem; color: var(--sub); display: flex; flex-wrap: wrap; gap: 14px; margin: 8px 0; }}
.legend span b {{ font-weight: 700; }}
.hidden {{ display: none; }}
.mono {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }}
</style>
</head>
<body>

<header>
  <h1>GN_DW 개념도 — 계층 인벤토리 · 계보 · 적재 상태</h1>
  <div class="note">
    <b>측정일 {MEASURED}</b> · 생성기 <span class="mono">{GEN_PATH}</span> — 자동 생성물이므로 직접 편집하지 마세요.<br>
    객체 목록·행수·컬럼 적재 상태는 전부 <b>Snowflake 카탈로그와 컬럼 census 실측</b>에서 나왔습니다.
    설명은 <b>배포된 객체 COMMENT 원문</b>입니다(문서가 아니라 DB 에 실제로 붙어 있는 문장).
  </div>
</header>

<div class="warn">
  🔴 <b>「컬럼이 있다」와 「값이 있다」는 다릅니다.</b> GOLD 기본 테이블의 DATA 컬럼 <b>{gold_data}</b>개 중
  <b>{gold_zero}</b>개가 <b>전건 0</b>, <b>{gold_null}</b>개가 <b>전건 NULL</b>, <b>{gold_empty}</b>개가
  <b>0행 테이블</b> 소속입니다. 조회하면 에러 없이 <span class="mono">0</span> 이 반환되므로
  <b>그 <span class="mono">0</span> 을 실적으로 읽으면 조용히 틀립니다.</b>
  아래 인벤토리의 <b>적재</b> 막대와 객체 클릭 시 나오는 컬럼 목록에서 확인하세요.
</div>

<h2 id="summary">1. 계층 요약</h2>
<div class="cards">
  <div class="card"><div class="k">BRONZE</div><div class="v">{stat['BRONZE']}</div><div class="s">{bronze_rows:,} 행</div></div>
  <div class="card"><div class="k">SILVER</div><div class="v">{stat['SILVER']}</div><div class="s">정제 테이블</div></div>
  <div class="card"><div class="k">GOLD</div><div class="v">{stat['GOLD']}</div><div class="s">테이블 + 뷰</div></div>
  <div class="card"><div class="k">SERVING</div><div class="v">{stat['SERVING']}</div><div class="s">뷰 + Semantic View</div></div>
  <div class="card"><div class="k">GOLD DATA 컬럼</div><div class="v">{gold_data}</div><div class="s">감사컬럼 제외</div></div>
  <div class="card"><div class="k">값 주입됨</div><div class="v" style="color:var(--ok)">{gold_fill}</div><div class="s">{gold_fill/gold_data*100:.1f}%</div></div>
  <div class="card"><div class="k">미주입</div><div class="v" style="color:var(--zero)">{gold_zero + gold_null + gold_empty}</div><div class="s">{(gold_zero+gold_null+gold_empty)/gold_data*100:.1f}%</div></div>
</div>

<h2 id="flow">2. 계층 흐름</h2>
<pre class="flow">  ┌─ BRONZE ────────────────┐   ┌─ SILVER ──────────────┐   ┌─ GOLD ─────────────────────┐   ┌─ SERVING ──────────┐
  │ CRM      (eCRM)         │   │ 코드 보존 · ID 통합    │   │ DIM (차원) · FACT (팩트)   │   │ Semantic View      │
  │ AGENCY   (대행사 리포트)│──▶│ 정기∪일시 회원 통합    │──▶│         +                  │──▶│ Cortex Agent       │
  │ ERP      (예산원장)     │   │ SCD2 상태이력 재구성   │   │ WIDE (BI 직결 평탄화 뷰)   │   │ 자연어 질의        │
  │ GA4      (BigQuery)     │   │ 센티넬 0 라우팅        │   │ 표준 지표 사전 계산        │   │                    │
  └─────────────────────────┘   └───────────────────────┘   └────────────────────────────┘   └────────────────────┘
        무손실 적재                   정제 · 표준화                 표준 지표 · 소비 계약            자연어 소비

  ⚠️ 원천 시스템이 다르면 한 표에서 교차 집계하지 않습니다 — 예산(ERP) ↔ 광고비(AGENCY) 는 별개 원천입니다.
  ⚠️ 미매칭 차원키는 Unknown 멤버(SK=0, 라벨 '(미매핑)')로 라우팅됩니다. 이 버킷이 큰 축은 집계가 부분집합입니다.</pre>

<h2 id="inventory">3. 객체 인벤토리 <span class="note">(행을 클릭하면 컬럼·계보가 열립니다)</span></h2>
<div class="legend">
  <span><b>적재 막대</b></span>
  <span><i class="st ok">■</i> 값 있음</span>
  <span><i class="st zero">■</i> 전건 0</span>
  <span><i class="st null">■</i> 전건 NULL</span>
  <span><i class="st empty">■</i> 0행 테이블</span>
</div>
<div class="toolbar">
  <input type="search" id="q" placeholder="객체명·설명 검색 (예: MEMBER, 목표, 광고)" />
  <button data-f="ALL" class="on">전체</button>
  <button data-f="BRONZE">BRONZE</button>
  <button data-f="SILVER">SILVER</button>
  <button data-f="GOLD">GOLD</button>
  <button data-f="SERVING">SERVING</button>
  <button data-f="GAP">⚠️ 미주입 보유</button>
  <span class="note" id="cnt"></span>
</div>
<div id="detail"></div>
<table>
  <thead><tr>
    <th>계층</th><th>스키마</th><th>객체</th><th>종류</th>
    <th style="text-align:right">행수</th><th style="text-align:right">컬럼</th>
    <th>적재</th><th>설명 (배포 COMMENT)</th>
  </tr></thead>
  <tbody id="tb"></tbody>
</table>

<h2>4. 함께 볼 문서</h2>
<table>
  <thead><tr><th>알고 싶은 것</th><th>문서</th></tr></thead>
  <tbody>
    <tr><td>지표 정의 · 지금 쓸 수 있는 범위 · 오독 방지</td><td class="mono">01_DW_현업활용가이드.md</td></tr>
    <tr><td>무엇이 왜 안 되나(원천 결손 · 해소 주체)</td><td class="mono">02_원천결손_Gap분석.md</td></tr>
    <tr><td>이 컬럼 값이 어디서 왔나(계보)</td><td class="mono">04_컬럼계보매핑.md</td></tr>
    <tr><td>지표번호 → GOLD 배속</td><td class="mono">05_지표GOLD매핑.md</td></tr>
    <tr><td>BRONZE 원천이 다 보여지고 있나</td><td class="mono">06_BRONZE노출감사.md</td></tr>
    <tr><td>코드값이 한글 라벨로 나오나</td><td class="mono">07_코드체계_관문측정.md</td></tr>
    <tr><td>SILVER → GOLD 로 무엇이 탈락했나</td><td class="mono">08_SILVER→GOLD_보존율.md</td></tr>
  </tbody>
</table>

<script id="objdata" type="application/json">{js}</script>
<script>
const OBJECTS = JSON.parse(document.getElementById('objdata').textContent);
const tb = document.getElementById('tb');
const detail = document.getElementById('detail');
const cnt = document.getElementById('cnt');
let filter = 'ALL', term = '';

function esc(s) {{
  return String(s == null ? '' : s).replace(/[&<>"]/g, c => ({{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}})[c]);
}}
function bar(o) {{
  const emp = o.cols.filter(c => c.s === 'empty').length;
  const tot = o.fill + o.zero + o.null + emp;
  if (!tot) return '<span class="note">—</span>';
  const p = n => (n / tot * 100).toFixed(2) + '%';
  return '<div class="bar" title="값있음 ' + o.fill + ' / 전건0 ' + o.zero
    + ' / 전건NULL ' + o.null + ' / 0행 ' + emp + '">'
    + '<i class="ok" style="width:' + p(o.fill) + '"></i>'
    + '<i class="zero" style="width:' + p(o.zero) + '"></i>'
    + '<i class="null" style="width:' + p(o.null) + '"></i>'
    + '<i class="empty" style="width:' + p(emp) + '"></i></div>';
}}
function match(o) {{
  const emp = o.cols.filter(c => c.s === 'empty').length;
  if (filter === 'GAP') {{ if (!(o.zero + o.null + emp)) return false; }}
  else if (filter !== 'ALL' && o.layer !== filter) return false;
  if (!term) return true;
  const t = term.toLowerCase();
  return o.name.toLowerCase().includes(t) || (o.desc || '').toLowerCase().includes(t)
      || o.cols.some(c => c.c.toLowerCase().includes(t));
}}
function render() {{
  const rows = OBJECTS.filter(match);
  cnt.textContent = rows.length + ' / ' + OBJECTS.length + ' 객체';
  tb.innerHTML = rows.map((o, i) => {{
    const gi = OBJECTS.indexOf(o);
    return '<tr class="row" data-i="' + gi + '">'
      + '<td><span class="tag ' + o.layer + '">' + o.layer + '</span></td>'
      + '<td class="mono">' + esc(o.schema) + '</td>'
      + '<td class="mono"><b>' + esc(o.name) + '</b></td>'
      + '<td>' + esc(o.type) + '</td>'
      + '<td class="num">' + (o.rows == null ? '—' : Number(o.rows).toLocaleString()) + '</td>'
      + '<td class="num">' + (o.ncols || '—') + '</td>'
      + '<td>' + bar(o) + '</td>'
      + '<td>' + esc((o.desc || '').slice(0, 160)) + ((o.desc || '').length > 160 ? '…' : '') + '</td>'
      + '</tr>';
  }}).join('');
}}
function show(i) {{
  const o = OBJECTS[i];
  const emp = o.cols.filter(c => c.s === 'empty').length;
  const bad = o.cols.filter(c => c.s === 'zero' || c.s === 'null' || c.s === 'empty');
  const LBL = {{ ok: '값 있음', zero: '전건 0', null: '전건 NULL', empty: '0행 테이블', '': '—' }};
  let h = '<div class="panel"><h3><span class="tag ' + o.layer + '">' + o.layer + '</span> '
    + '<span class="mono">' + esc(o.schema) + '.' + esc(o.name) + '</span> '
    + '<span class="note">' + esc(o.type) + ' · '
    + (o.rows == null ? '행수 —' : Number(o.rows).toLocaleString() + ' 행') + ' · '
    + o.ncols + ' 컬럼</span></h3>';
  if (o.desc) h += '<div class="desc">' + esc(o.desc) + '</div>';
  if (o.model) h += '<div class="note">정의: <span class="mono">' + esc(o.model) + '</span></div>';
  if (o.upstream.length) h += '<div class="note" style="margin-top:8px">상류(입력)</div><div class="chips">'
    + o.upstream.map(u => '<span class="chip">' + esc(u) + '</span>').join('') + '</div>';
  if (o.downstream.length) h += '<div class="note">하류(이 객체를 쓰는 곳)</div><div class="chips">'
    + o.downstream.map(u => '<span class="chip">' + esc(u) + '</span>').join('') + '</div>';
  if (bad.length) h += '<div class="warn">⚠️ <b>미주입 컬럼 ' + bad.length + '개</b> — 조회하면 '
    + '<span class="mono">0</span>/<span class="mono">NULL</span> 이 반환됩니다. 실적으로 읽지 마세요.</div>';
  if (o.cols.length) {{
    h += '<table><thead><tr><th>컬럼</th><th>타입</th><th>적재</th><th>COMMENT</th></tr></thead><tbody>'
      + o.cols.map(c => '<tr><td class="mono">' + esc(c.c) + '</td><td class="note">' + esc(c.t)
        + '</td><td><span class="st ' + (c.s || '') + '">' + LBL[c.s || ''] + '</span></td><td class="note">'
        + esc((c.m || '').slice(0, 400)) + ((c.m || '').length > 400 ? '…' : '') + '</td></tr>').join('')
      + '</tbody></table>';
  }} else {{
    h += '<div class="note">이 객체의 컬럼 메타는 카탈로그에서 열거되지 않습니다(Semantic View 는 '
      + '<span class="mono">DESCRIBE SEMANTIC VIEW</span> 로 확인).</div>';
  }}
  h += '</div>';
  detail.innerHTML = h;
  detail.scrollIntoView({{ behavior: 'smooth', block: 'nearest' }});
}}
tb.addEventListener('click', e => {{
  const tr = e.target.closest('tr.row');
  if (tr) show(Number(tr.dataset.i));
}});
document.getElementById('q').addEventListener('input', e => {{ term = e.target.value.trim(); render(); }});
document.querySelectorAll('button[data-f]').forEach(b => {{
  b.addEventListener('click', () => {{
    document.querySelectorAll('button[data-f]').forEach(x => x.classList.remove('on'));
    b.classList.add('on');
    filter = b.dataset.f;
    render();
  }});
}});
render();
</script>

<p class="note">Co-authored with CoCo</p>
</body>
</html>
"""
    os.makedirs(OUT_DIR, exist_ok=True)
    tmp = "/tmp/03_GN_DW_개념도.html"
    open(tmp, "w", encoding="utf-8").write(H)
    import shutil
    shutil.copyfile(tmp, OUT)
    print("HTML:", OUT, f"({len(H)/1024:.0f} KB)")
    print("객체", len(objs), dict(stat), "| GOLD DATA 컬럼", gold_data,
          "값있음", gold_fill, "0", gold_zero, "NULL", gold_null, "0행", gold_empty)


if __name__ == "__main__":
    main()
