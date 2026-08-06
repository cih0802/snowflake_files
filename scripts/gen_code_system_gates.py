# BRONZE 코드체계 → SILVER → GOLD 반영 관문(G1~G7) 측정 생성기
# Co-authored with CoCo
"""
정본 컬럼정의서에 코드그룹이 지정된 BRONZE 컬럼을 모집단으로 삼아
코드체계가 SILVER·GOLD 까지 살아오는지 관문별로 실측한다.

관문
  G1 코드사전(SILVER.CRM_CODE)에 코드그룹이 존재하는가
  G2 BRONZE 실값이 그 사전 안에 있는가 (활성/폐지/사전부재 3분할)
  G3 SILVER 가 코드를 보존하는가 (물리 컬럼 존재)
  G4 GOLD 에 도달했는가 (dbt 계보 기반 — 이름기반 탐지는 오탐이라 쓰지 않는다)
  G5 GOLD 도메인 == BRONZE 도메인인가 (확정연결 건만)
  G6 라벨(*_NM/_NAME) 이 동반되는가
  G7 단위·정의 정합 — 자동 판정 불가(설계 결정 사안)

원칙: P13(커버리지≠정확도) · P14(부재판정은 실측필수) · P27(도메인 부분적재는 자동검증을 통과한다)
출력: 30_output_share/07_코드체계_관문측정.md
"""
import csv, os, re, sys, json, collections
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/tmp")
from sfconn import conn, q

WS = os.environ.get("GN_DW_WS", "/workspace")
OUT_DIR = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
BASENAME = "07_코드체계_관문측정"
GEN_PATH = "scripts/gen_code_system_gates.py"
MEASURED = os.environ.get("GN_DW_MEASURED", date.today().isoformat())
DEF_CSV = os.path.join(WS, "99_provided_definition", "컬럼정의서 20260714.csv")
MODELS = os.path.join(WS, "10_dbt_pipeline", "models")
STD_RE = re.compile(r"^(CM|MM|MS|PM|RM)\d{3}$")

# ── 개명 전파 등록부 (P13 대응) ──
# 이름 토큰 매칭은 개명 적재를 미탐한다 → 개명은 명시 등록해야 「미보존」 오판을 막는다.
# 근거: O25(변환형태 노출 3건) · O26(동명이의 해소 개명 2건). 각 항목은 SILVER 물리 실측으로 확인했다.
RENAME_MAP = {
    ("TD_MS_MSG_AT_SNDNG_DTLS", "TRNSMS_STAT_CD"): ("SNDNG_RST_CD", "O25 — 발송결과로 변환 형태 노출(중복 신설 안 함)"),
    ("TM_MM_FDRM_MBER_INFO", "EMAIL_RECPTN_CD"): ("EMAIL_RECPTN", "O25 — 수신동의 변환 형태 노출"),
    ("TM_MM_FDRM_MBER_INFO", "PSTMTR_RECPTN_CD"): ("PSTMTR_RECPTN", "O25 — 수신동의 변환 형태 노출"),
    ("TM_PM_MBRFEE_ACMSLT", "PRCS_STAT_CD"): ("MBRFEE_PRCS_STAT_CD", "O26 — 동명이의 해소 개명(회비)"),
    ("TM_MS_PSTMTR_SNDNG", "PRCS_STAT_CD"): ("PSTMTR_PRCS_STAT_CD", "O26 — 동명이의 해소 개명(발송)"),
}


def strip_sql_comments(s):
    s = re.sub(r"/\*.*?\*/", " ", s, flags=re.S)
    s = re.sub(r"--[^\n]*", " ", s)
    return s


def load_models():
    out = {}
    for root, _, files in os.walk(MODELS):
        for fn in files:
            if not fn.endswith(".sql"):
                continue
            p = os.path.join(root, fn)
            rel = os.path.relpath(p, MODELS)
            raw = open(p, encoding="utf-8").read()
            out[fn[:-4]] = {"layer": rel.split(os.sep)[0], "sql": strip_sql_comments(raw),
                            "refs": set(re.findall(r"ref\(\s*['\"]([A-Za-z0-9_]+)['\"]\s*\)", raw))}
    return out


def main():
    cn = conn()

    # ── 0. 정본 모집단 ──
    defrows = list(csv.DictReader(open(DEF_CSV, encoding="utf-8-sig")))
    tot_cols = len(defrows)
    cy = sum(1 for r in defrows if (r.get("코드여부") or "").strip() == "Y")
    cnn = sum(1 for r in defrows if (r.get("코드여부") or "").strip() == "N")
    cblank = sum(1 for r in defrows if not (r.get("코드여부") or "").strip())
    with_gid = [r for r in defrows if (r.get("코드그룹ID") or "").strip()]
    std = [r for r in with_gid if STD_RE.match((r["코드그룹ID"] or "").strip())]

    # BRONZE 물리 실존 확인
    _, brows = q("""select table_schema, table_name, column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS
                    where table_schema like 'BRONZE%'""", cn)
    bronze = collections.defaultdict(set)
    tab_schema = {}
    for s, t, c in brows:
        bronze[t].add(c)
        tab_schema[t] = s

    pop = []            # 모집단: (테이블, 컬럼, 코드그룹)
    seen = set()
    missing_phys = []
    for r in std:
        t = (r["테이블명"] or "").strip()
        c = (r["컬럼명"] or "").strip()
        g = (r["코드그룹ID"] or "").strip()
        if c not in bronze.get(t, ()):
            missing_phys.append((t, c, g))
            continue
        if (t, c) in seen:
            continue
        seen.add((t, c))
        pop.append({"table": t, "col": c, "grp": g, "desc": (r.get("컬럼설명(한글)") or "").strip()})

    groups = sorted({p["grp"] for p in pop})

    # ── G1: 코드사전 ──
    _, crows = q("""select CD_ID, DTL_CD_ID, DTL_CD_NM, USE_YN from GN_DW.SILVER.CRM_CODE""", cn)
    dic = collections.defaultdict(dict)
    for gid, cd, nm, use in crows:
        dic[gid][str(cd)] = (nm, use)
    g1_present = [g for g in groups if g in dic]
    g1_missing = [g for g in groups if g not in dic]
    dict_total = sum(len(v) for g, v in dic.items() if g in groups)
    dict_active = sum(1 for g in groups for cd, (nm, u) in dic.get(g, {}).items() if u == 'Y')

    # ── G2: BRONZE 실값 ↔ 사전 ──
    g2 = []
    for p in pop:
        t, c, g = p["table"], p["col"], p["grp"]
        sch = tab_schema.get(t, 'BRONZE_CRM')
        try:
            _, vals = q(f'select distinct "{c}"::string as v from GN_DW.{sch}."{t}" where "{c}" is not null limit 5000', cn)
        except Exception as e:
            p.update(g2="측정불가", g2_detail=str(e)[:80])
            g2.append(p)
            continue
        vs = {v[0] for v in vals if v[0] is not None and v[0] != ''}
        d = dic.get(g, {})
        act = {v for v in vs if d.get(v, (None, None))[1] == 'Y'}
        dep = {v for v in vs if d.get(v, (None, None))[1] not in ('Y', None)}
        nod = {v for v in vs if v not in d}
        if not vs:
            st = "값없음"
        elif nod:
            st = "사전부재값 有"
        elif dep:
            st = "폐지코드 사용"
        else:
            st = "활성만"
        p.update(g2=st, n_vals=len(vs), n_active=len(act), n_dep=len(dep), n_nodict=len(nod),
                 nodict_sample=", ".join(sorted(nod)[:6]), dep_sample=", ".join(sorted(dep)[:6]),
                 bronze_schema=sch)
        g2.append(p)

    # ── G3/G4: SILVER·GOLD 도달 ──
    _, srows = q("""select table_name, column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS
                    where table_schema='SILVER'""", cn)
    silver = collections.defaultdict(set)
    for t, c in srows:
        silver[t].add(c)
    silver_all = {c for v in silver.values() for c in v}
    _, grows = q("""select table_name, column_name from GN_DW.INFORMATION_SCHEMA.COLUMNS
                    where table_schema='GOLD'""", cn)
    goldcols = collections.defaultdict(set)
    for t, c in grows:
        goldcols[t].add(c)
    gold_all = {c for v in goldcols.values() for c in v}

    models = load_models()
    silver_sourced = set()
    src_yml = os.path.join(MODELS, "silver", "_sources.yml")
    if os.path.exists(src_yml):
        silver_sourced = set(re.findall(r"-\s*name:\s*([A-Za-z0-9_]+)", open(src_yml, encoding="utf-8").read()))
    for p in g2:
        c0 = p["col"]
        rn = RENAME_MAP.get((p["table"], c0))
        c = rn[0] if rn else c0
        p["silver_col"] = c
        p["rename"] = f"{c0} → {c} ({rn[1]})" if rn else ""
        if c in silver_all:
            p["g3"] = "보존(개명)" if rn else "보존"
        elif p["table"] not in silver_sourced:
            p["g3"] = "미보존(SILVER 모델 부재)"
        else:
            p["g3"] = "미보존(SELECT 탈락)"
        p["silver_tables"] = ";".join(sorted(t for t, v in silver.items() if c in v))
        # G4: dbt GOLD 모델 본문에 컬럼명이 등장하는가 (계보 기반)
        hits = sorted(n for n, m in models.items()
                      if m["layer"] == "gold" and re.search(r"\b" + re.escape(c) + r"\b", m["sql"]))
        p["g4"] = "도달" if hits else ("미도달" if p["g3"].startswith("보존") else "선행미보존")
        p["gold_models"] = ";".join(hits)
        p["gold_tables"] = ";".join(sorted(t for t, v in goldcols.items() if c in v))
        # G6: 라벨 동반
        lab = [x for x in (c + "_NM", c.replace("_CD", "") + "_NM", c + "_NAME") if x in silver_all or x in gold_all]
        p["g6"] = ";".join(lab) if lab else ""

    cn.close()

    # ── 리포트 ──
    n = len(g2)
    c_g2 = collections.Counter(p["g2"] for p in g2)
    c_g3 = collections.Counter(p["g3"] for p in g2)
    c_g4 = collections.Counter(p["g4"] for p in g2)
    n_g6 = sum(1 for p in g2 if p["g6"])

    L = []
    A = L.append
    A("<!-- LLM-METADATA")
    A("doc_id: CODE_SYSTEM_GATE_MEASUREMENT")
    A("doc_role: BRONZE 코드체계 → SILVER → GOLD 반영 관문(G1~G7) 측정 정본")
    A("project: GN_DW (굿네이버스)")
    A(f"measured: {MEASURED}")
    A("scope: 정본 컬럼정의서에 표준 코드그룹이 지정되고 BRONZE 에 물리 실존하는 컬럼 전수")
    A("method: 정본 CSV(csv.DictReader) 모집단 + BRONZE distinct 실값 + SILVER.CRM_CODE 사전 + INFORMATION_SCHEMA + dbt 모델 계보 파싱")
    A(f"generator: {GEN_PATH}")
    A("generated: auto (do-not-edit)")
    A("principle: P13(커버리지≠정확도) · P14(부재판정은 실측필수) · P27(도메인 부분적재는 자동검증을 통과한다)")
    A("END-METADATA -->")
    A("")
    A("# 코드체계 관문 측정 (G1~G7)")
    A("")
    A(f"> ⚙️ **자동 생성물** — 생성기 `{GEN_PATH}`. 직접 편집 금지 · 재실행으로 갱신.")
    A(f"> **측정일 {MEASURED}** — 전 수치는 이 문서 생성 시점에 DB·정본 CSV·dbt 모델을 직접 읽어 산출했다.")
    A("> 추론으로 채운 항목은 없다. 자동 판정이 불가한 관문은 **미측정**으로 표기한다.")
    A("")
    A("## 0. 관문 현황 요약")
    A("")
    A("| 관문 | 판정 내용 | 실측 결과 |")
    A("|---|---|---|")
    A(f"| **G1** | 코드사전(`SILVER.CRM_CODE`)에 코드그룹이 존재하는가 | **{len(g1_present)}/{len(groups)} 완비** · 사전 결손 {len(g1_missing)} · 등록 코드 {dict_total}(활성 {dict_active}) |")
    A(f"| **G2** | BRONZE 실값이 사전 안에 있는가 | 활성만 **{c_g2['활성만']}** · 폐지코드 사용 **{c_g2['폐지코드 사용']}** · 사전부재값 **{c_g2['사전부재값 有']}** · 값없음 {c_g2['값없음']} · 측정불가 {c_g2['측정불가']} |")
    n_keep = c_g3['보존'] + c_g3['보존(개명)']
    A(f"| **G3** | SILVER 가 코드를 보존하는가 | 보존 **{n_keep}/{n} ({n_keep/n*100:.1f}%)** = 동명 {c_g3['보존']} + 개명 {c_g3['보존(개명)']} · 미보존 {c_g3['미보존(SILVER 모델 부재)']+c_g3['미보존(SELECT 탈락)']}(모델부재 {c_g3['미보존(SILVER 모델 부재)']} · SELECT 탈락 {c_g3['미보존(SELECT 탈락)']}) |")
    A(f"| **G4** | GOLD 에 도달했는가 | 도달 **{c_g4['도달']}** · 미도달 {c_g4['미도달']} · 선행미보존 {c_g4['선행미보존']} (⚠️ 계보 기반 — 개명 전파는 미탐, P13) |")
    A(f"| **G5** | GOLD 도메인 == BRONZE 도메인인가 | §4 확정연결 건만 판정 |")
    A(f"| **G6** | 라벨(`*_NM`/`*_NAME`)이 동반되는가 | 동반 **{n_g6}/{n}** |")
    A(f"| **G7** | 단위·정의 정합(`(건)`=금액÷10,000 등) | 🔴 **미측정** — 설계결정·현업확인 사안(자동 판정 불가) |")
    A("")
    A("## 1. 모집단 재현 (정식 CSV 파서)")
    A("")
    A(f"정본 `99_provided_definition/컬럼정의서 20260714.csv` 를 `csv.DictReader`(utf-8-sig)로 파싱했다.")
    A("`awk -F','` 는 인용부호 내 콤마 때문에 쓰지 않았다.")
    A("")
    A("| 구분 | 건수 |")
    A("|---|---:|")
    A(f"| 정본 총 컬럼 | **{tot_cols}** |")
    A(f"| `코드여부='Y'` | {cy} |")
    A(f"| `코드여부='N'` | {cnn} |")
    A(f"| ⚠️ `코드여부` 공백(정본 미판정) | {cblank} ({cblank/tot_cols*100:.1f}%) |")
    A(f"| `코드그룹ID` 보유 | {len(with_gid)} |")
    A(f"| └ 표준 코드그룹 `^(CM\\|MM\\|MS\\|PM\\|RM)\\d{{3}}$` | {len(std)} |")
    A(f"| └ └ BRONZE 물리 실존 + 중복 제거 = **확정 모집단** | **{n}** |")
    A(f"| └ └ 정본에 있으나 BRONZE 물리 부재 | {len(missing_phys)} |")
    A("")
    if missing_phys:
        A("**정본 지정 ↔ BRONZE 물리 불일치** (정본이 코드그룹을 지정했으나 그 컬럼이 물리에 없다)")
        A("")
        A("| BRONZE 테이블 | 컬럼 | 코드그룹 |")
        A("|---|---|---|")
        for t, c, g in sorted(missing_phys):
            A(f"| `{t}` | `{c}` | `{g}` |")
        A("")
    A("## 2. G1 — 코드사전 완비 여부")
    A("")
    A(f"모집단이 참조하는 코드그룹 **{len(groups)}종**을 `SILVER.CRM_CODE.CD_ID` 와 대조했다.")
    A("")
    if g1_missing:
        A(f"🔴 **사전 결손 {len(g1_missing)}종**: " + ", ".join(f"`{g}`" for g in g1_missing))
    else:
        A(f"✅ **결손 0** — {len(groups)}종 전량 사전에 존재한다.")
    A("")
    A("| 코드그룹 | 사전 등록 코드 | 활성(`USE_YN='Y'`) | 폐지 | 이 그룹을 쓰는 BRONZE 컬럼 |")
    A("|---|---:|---:|---:|---|")
    for g in groups:
        d = dic.get(g, {})
        act = sum(1 for _, (nm, u) in d.items() if u == 'Y')
        cols = [f"`{p['table']}.{p['col']}`" for p in g2 if p["grp"] == g]
        A(f"| `{g}` | {len(d)} | {act} | {len(d)-act} | {', '.join(cols)} |")
    A("")
    A("## 3. G2 — BRONZE 실값 ↔ 사전 대조 (컬럼 전수)")
    A("")
    A("> `distinct` 실값을 사전과 직접 대조했다. **사전부재값**은 Analyst 가 라벨을 붙일 수 없는 구간이고,")
    A("> **폐지코드 사용**은 `USE_YN='Y'` 필터를 거는 순간 라벨이 조용히 사라지는 구간이다.")
    A("")
    A("| BRONZE 테이블 | 컬럼 | 코드그룹 | 판정 | 실값 | 활성 | 폐지 | 사전부재 | 사전부재 값(샘플) |")
    A("|---|---|---|---|---:|---:|---:|---:|---|")
    for p in sorted(g2, key=lambda x: (x["g2"] != "사전부재값 有", x["table"], x["col"])):
        A(f"| `{p['table']}` | `{p['col']}` | `{p['grp']}` | {p['g2']} | {p.get('n_vals','—')} | "
          f"{p.get('n_active','—')} | {p.get('n_dep','—')} | {p.get('n_nodict','—')} | {p.get('nodict_sample','')} |")
    A("")
    A("## 4. G3·G4 — SILVER 보존 / GOLD 도달")
    A("")
    A("> **G4 는 계보(dbt 모델 본문) 기반**이다. 이름기반·값기반 탐지는 오탐이 확인돼 쓰지 않는다(P13·P16).")
    A("> `미도달` 은 부재 확정이 아니다 — 개명 전파(`STOP_REASON` 류)는 이 방식으로 잡히지 않는다.")
    A("")
    A("| BRONZE 컬럼 | 코드그룹 | G3 SILVER | 개명 전파 | SILVER 테이블 | G4 GOLD | GOLD 테이블 | G6 라벨 |")
    A("|---|---|---|---|---|---|---|---|")
    for p in sorted(g2, key=lambda x: (x["g4"] == "도달", x["table"], x["col"])):
        A(f"| `{p['table']}.{p['col']}` | `{p['grp']}` | {p['g3']} | {p['rename'] or '—'} | {p['silver_tables'] or '—'} | "
          f"{p['g4']} | {p['gold_tables'] or '—'} | {p['g6'] or '—'} |")
    A("")
    A("### 4-1. 미보존 전량 — 원인 분리")
    A("")
    A("> 「미보존」을 한 칸에 묶으면 조치 방식이 섞인다. **SILVER 모델 부재**는 도메인 스코프 밖(설계 판단)이고,")
    A("> **SELECT 탈락**은 배선만 하면 해소되는 결함이다.")
    A("")
    A("| BRONZE 컬럼 | 코드그룹 | 원인 | 비고 |")
    A("|---|---|---|---|")
    for p in sorted(g2, key=lambda x: (x["g3"], x["table"], x["col"])):
        if p["g3"].startswith("보존"):
            continue
        note = "BRONZE 테이블이 `_sources.yml` 에 등록되지 않았다 = SILVER 모델 자체가 없다" \
            if "모델 부재" in p["g3"] else "SILVER 모델은 있으나 이 컬럼을 SELECT 하지 않는다 — **배선 대상**"
        A(f"| `{p['table']}.{p['col']}` | `{p['grp']}` | {p['g3']} | {note} |")
    A("")
    A("## 5. G5 — GOLD 도메인 == BRONZE 도메인")
    A("")
    A("GOLD 에 도달하고 SILVER 에 보존된 컬럼에 한해, BRONZE 실값 집합이 사전 안에 완전히 들어가는지로 판정한다.")
    A("사전부재값이 있으면 GOLD 라벨에 공백이 생기므로 **불합격**이다.")
    A("")
    A("| BRONZE 컬럼 | 코드그룹 | 실값 | 사전부재 | 판정 |")
    A("|---|---|---:|---:|---|")
    for p in sorted(g2, key=lambda x: (x["table"], x["col"])):
        if p["g4"] != "도달":
            continue
        ok = "✅ 통과" if p.get("n_nodict", 0) == 0 else f"🔴 불합격(사전부재 {p['n_nodict']})"
        A(f"| `{p['table']}.{p['col']}` | `{p['grp']}` | {p.get('n_vals','—')} | {p.get('n_nodict','—')} | {ok} |")
    A("")
    A("## 6. G7 — 단위·정의 정합 (미측정)")
    A("")
    A("`(건)` 계열이 건수인지 금액÷10,000 인지, `*_MEMBERS` 가 「명」인지 플래그인지 같은 판정은")
    A("**코드체계 대조로 결정되지 않는다** — 정본 지표 정의·현업 확인 사안이다.")
    A("이 문서는 그 판정을 하지 않으며, 소관은 이슈원장(CONF-2 · O39 계열)이다.")
    A("")
    A("---")
    A("_Co-authored with CoCo_")

    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, BASENAME + ".md")
    open(path, "w", encoding="utf-8").write("\n".join(L) + "\n")
    print("MD:", path)
    print("모집단", n, "| G1", f"{len(g1_present)}/{len(groups)}", "| G2", dict(c_g2), "| G3", dict(c_g3), "| G4", dict(c_g4), "| G6", n_g6)


if __name__ == "__main__":
    main()
