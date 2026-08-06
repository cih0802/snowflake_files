# SILVER→GOLD 컬럼 보존율 측정 생성기
# Co-authored with CoCo
"""
SILVER DATA 컬럼이 GOLD 로 전파됐는지 기계 측정한다.

측정 4원 대조 (O27 방법론 계승):
  1. INFORMATION_SCHEMA.COLUMNS      — SILVER 물리 컬럼 모집단(DW_* 감사컬럼 제외)
  2. dbt 모델 ref() 계보              — GOLD 모델이 직접 소비하는 SILVER 테이블
  3. dbt 모델 본문 토큰 스캔          — 그 GOLD 모델이 컬럼명을 실제로 참조하는가
  4. SILVER 내부 체인                 — GOLD 미도달이지만 다른 SILVER 모델이 소비하는가

STATUS
  REFERENCED         GOLD 모델이 직접 소비하는 SILVER 테이블 + 그 모델 본문에 컬럼명 존재
  DROPPED            GOLD 가 그 테이블을 소비하지만 컬럼은 SELECT 되지 않음
  SILVER_ONLY_CHAIN  GOLD 직접소비 대상이 아니고 SILVER 내부에서만 소비됨
  NO_CONSUMER        어느 모델도 이 컬럼을 언급하지 않음

판정군(A/B/C/D/E …) 은 사람 판정이므로 이전 판본에서 **키 단위로 승계**한다.
승계 후 STATUS 가 뒤집힌 행은 `판정_재검토필요` 로 표시한다(자동 재판정 금지 — P78 계열).

출력: 30_output_share/08_SILVER→GOLD_보존율.{csv,md}
"""
import csv, os, re, sys, json
from datetime import date

WS = os.environ.get("GN_DW_WS", "/workspace")
OUT_DIR = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
PREV = os.environ.get("GN_DW_PREV", os.path.join(WS, "30_output_share"))
BASENAME = "08_SILVER→GOLD_보존율"
GEN_PATH = "scripts/gen_silver_gold_retention.py"
MEASURED = os.environ.get("GN_DW_MEASURED", date.today().isoformat())

MODELS = os.path.join(WS, "10_dbt_pipeline", "models")
AUDIT = {"DW_SOURCE_SYSTEM", "DW_SOURCE_TABLE", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"}


def strip_sql_comments(s):
    s = re.sub(r"/\*.*?\*/", " ", s, flags=re.S)
    s = re.sub(r"--[^\n]*", " ", s)
    return s


def load_models():
    """{모델명: {'layer':..,'path':..,'sql':..,'refs':set()}}"""
    out = {}
    for root, _, files in os.walk(MODELS):
        for fn in files:
            if not fn.endswith(".sql"):
                continue
            p = os.path.join(root, fn)
            name = fn[:-4]
            rel = os.path.relpath(p, MODELS)
            layer = rel.split(os.sep)[0]
            raw = open(p, encoding="utf-8").read()
            body = strip_sql_comments(raw)
            refs = set(re.findall(r"ref\(\s*['\"]([A-Za-z0-9_]+)['\"]\s*\)", raw))
            out[name] = {"layer": layer, "path": rel, "sql": body, "raw": raw, "refs": refs}
    return out


def main():
    census = json.load(open(os.environ.get("GN_DW_CENSUS", "/tmp/census.json"), encoding="utf-8"))
    silver = {}
    for k, v in census.items():
        if not k.startswith("SILVER."):
            continue
        t = k.split(".", 1)[1]
        silver[t] = [(c, i) for c, i in v["cols"].items() if c not in AUDIT]

    models = load_models()
    gold = {n: m for n, m in models.items() if m["layer"] == "gold"}
    silver_models = {n: m for n, m in models.items() if m["layer"] == "silver"}

    # GOLD 가 직접 소비하는 SILVER 테이블 → 소비 모델 목록
    gold_consumers = {}
    for n, m in gold.items():
        for r in m["refs"]:
            if r in silver:
                gold_consumers.setdefault(r, []).append(n)
    # SILVER 내부 소비
    silver_consumers = {}
    for n, m in silver_models.items():
        for r in m["refs"]:
            if r in silver and r != n:
                silver_consumers.setdefault(r, []).append(n)

    # 이전 판본 판정군 승계
    prev = {}
    ppath = os.path.join(PREV, BASENAME + ".csv")
    if os.path.exists(ppath):
        for r in csv.DictReader(open(ppath, encoding="utf-8-sig")):
            prev[(r["SILVER_TABLE"], r["COLUMN"])] = (r.get("판정군", ""), r.get("STATUS", ""))

    rows = []
    for t in sorted(silver):
        gcs = sorted(gold_consumers.get(t, []))
        scs = sorted(silver_consumers.get(t, []))
        for col, info in silver[t]:
            tok = re.compile(r"\b" + re.escape(col) + r"\b")
            hit_g = [n for n in gcs if tok.search(gold[n]["sql"])]
            hit_s = [n for n in scs if tok.search(silver_models[n]["sql"])]
            if gcs:
                status = "REFERENCED" if hit_g else "DROPPED"
            elif scs:
                # 테이블 자체가 SILVER 내부 체인에서만 소비된다(원 판정 스코프 = 테이블).
                status = "SILVER_ONLY_CHAIN"
            else:
                status = "NO_CONSUMER"
            pg, ps = prev.get((t, col), ("", ""))
            flag = ""
            if ps and ps != status:
                flag = f"판정_재검토필요(구={ps})"
            nn = int(info["nonnull"] or 0)
            nz = int(info["nonzero"] or 0)
            rows.append({
                "SILVER_TABLE": t, "COLUMN": col, "STATUS": status, "판정군": pg,
                "소비GOLD모델": ";".join(hit_g or gcs) if gcs else "",
                "SILVER내부소비": ";".join(hit_s or scs),
                "SILVER내부_컬럼참조": "Y" if hit_s else ("N" if scs else ""),
                "채움(non-null)": nn, "비영(non-zero)": nz, "고유값(근사)": info["ndv"],
                f"변동({MEASURED})": flag,
            })

    os.makedirs(OUT_DIR, exist_ok=True)
    fields = list(rows[0].keys())
    cpath = os.path.join(OUT_DIR, BASENAME + ".csv")
    with open(cpath, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    import collections
    st = collections.Counter(r["STATUS"] for r in rows)
    denom = st["REFERENCED"] + st["DROPPED"]
    chg = [r for r in rows if r[f"변동({MEASURED})"]]

    L = []
    A = L.append
    A("<!-- LLM-METADATA")
    A("doc_id: SILVER_GOLD_RETENTION")
    A("doc_role: SILVER→GOLD 컬럼 보존율 측정 (기계 측정 + 사람 판정군 승계)")
    A("project: GN_DW (굿네이버스)")
    A(f"measured: {MEASURED}")
    A(f"generator: {GEN_PATH}")
    A("generated: auto (do-not-edit)")
    A("principle: P27(도메인 부분적재는 자동검증을 통과한다) · P36(짝짓기를 이름 유사성으로 하지 않는다) · P78(의미는 이름이 아니라 grain 으로 판정)")
    A("END-METADATA -->")
    A("")
    A("# SILVER → GOLD 컬럼 보존율")
    A("")
    A(f"> ⚙️ **자동 생성물** — 생성기 `{GEN_PATH}`. 직접 편집 금지.")
    A(f"> **측정일** {MEASURED} · 모집단 = SILVER 물리 DATA 컬럼(감사 `DW_*` 5종 제외)")
    A("> **한계(P13)**: 컬럼명 토큰 스캔이므로 **개명 전파는 미탐**이다 — `DROPPED` 는 부재 확정이 아니다.")
    A("> `판정군` 은 사람 판정이며 이전 판본에서 키 단위 승계했다. 기계 STATUS 가 뒤집힌 행은 마지막 열에 표시된다.")
    A("")
    A("## 1. 요약")
    A("")
    A("| 구분 | 건수 |")
    A("|---|---:|")
    A(f"| SILVER DATA 컬럼 총계 | **{len(rows)}** |")
    A(f"| GOLD 직접소비 테이블의 컬럼(=보존율 분모) | **{denom}** |")
    A(f"| └ REFERENCED (보존) | **{st['REFERENCED']}** |")
    A(f"| └ DROPPED (탈락) | **{st['DROPPED']}** |")
    A(f"| SILVER_ONLY_CHAIN (SILVER 내부만 소비) | {st['SILVER_ONLY_CHAIN']} |")
    A(f"| NO_CONSUMER (소비처 0) | {st['NO_CONSUMER']} |")
    A("")
    A(f"**보존율 = {st['REFERENCED']}/{denom} = {st['REFERENCED']/denom*100:.1f}%**")
    A("")
    if chg:
        A(f"## 2. ⚠️ 이전 판본 대비 STATUS 변동 {len(chg)}건 — 판정군 재검토 필요")
        A("")
        A("| SILVER 테이블 | 컬럼 | 현재 STATUS | 승계된 판정군 | 변동 |")
        A("|---|---|---|---|---|")
        for r in chg:
            A(f"| `{r['SILVER_TABLE']}` | `{r['COLUMN']}` | {r['STATUS']} | {r['판정군'] or '—'} | {r[f'변동({MEASURED})']} |")
        A("")
    else:
        A("## 2. 이전 판본 대비 STATUS 변동")
        A("")
        A("변동 0건 — 기계 측정 결과가 이전 판본과 일치한다.")
        A("")
    A("## 3. 테이블별 보존율")
    A("")
    A("| SILVER 테이블 | DATA 컬럼 | REFERENCED | DROPPED | 내부체인 | 소비처0 | 보존율 | 소비 GOLD 모델 |")
    A("|---|---:|---:|---:|---:|---:|---:|---|")
    bytab = collections.defaultdict(collections.Counter)
    tabmodels = {}
    for r in rows:
        bytab[r["SILVER_TABLE"]][r["STATUS"]] += 1
        if r["소비GOLD모델"]:
            tabmodels.setdefault(r["SILVER_TABLE"], set()).update(r["소비GOLD모델"].split(";"))
    for t in sorted(bytab):
        c = bytab[t]
        d = c["REFERENCED"] + c["DROPPED"]
        rate = f"{c['REFERENCED']/d*100:.0f}%" if d else "—"
        gm = ", ".join(f"`{x}`" for x in sorted(tabmodels.get(t, []))) or "—"
        A(f"| `{t}` | {sum(c.values())} | {c['REFERENCED']} | {c['DROPPED']} | {c['SILVER_ONLY_CHAIN']} | {c['NO_CONSUMER']} | {rate} | {gm} |")
    A("")
    A("## 4. 탈락(DROPPED) 전량 — 판정군별")
    A("")
    drops = [r for r in rows if r["STATUS"] == "DROPPED"]
    grp = collections.defaultdict(list)
    for r in drops:
        grp[r["판정군"] or "(미판정 — 신규 또는 승계 실패)"].append(r)
    for g in sorted(grp, key=lambda x: (-len(grp[x]), x)):
        A(f"### {g} — {len(grp[g])}건")
        A("")
        A("| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |")
        A("|---|---|---:|---:|---:|")
        for r in sorted(grp[g], key=lambda x: (x["SILVER_TABLE"], x["COLUMN"])):
            A(f"| `{r['SILVER_TABLE']}` | `{r['COLUMN']}` | {r['채움(non-null)']:,} | {r['비영(non-zero)']:,} | {r['고유값(근사)']} |")
        A("")
    A("## 5. 소비처 0 (NO_CONSUMER) 전량")
    A("")
    nc = [r for r in rows if r["STATUS"] == "NO_CONSUMER"]
    if nc:
        A("| SILVER 테이블 | 컬럼 | 채움 | 비영 | 고유값 |")
        A("|---|---|---:|---:|---:|")
        for r in sorted(nc, key=lambda x: (x["SILVER_TABLE"], x["COLUMN"])):
            A(f"| `{r['SILVER_TABLE']}` | `{r['COLUMN']}` | {r['채움(non-null)']:,} | {r['비영(non-zero)']:,} | {r['고유값(근사)']} |")
    else:
        A("없음.")
    A("")
    A("---")
    A("_Co-authored with CoCo_")

    mpath = os.path.join(OUT_DIR, BASENAME + ".md")
    open(mpath, "w", encoding="utf-8").write("\n".join(L) + "\n")
    print("CSV:", cpath)
    print("MD :", mpath)
    print(f"보존율 {st['REFERENCED']}/{denom} = {st['REFERENCED']/denom*100:.1f}% · 변동 {len(chg)}건")
    print(dict(st))


if __name__ == "__main__":
    main()
