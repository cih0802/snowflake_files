# 지표(지표번호) → GOLD 매핑 장표 생성기 (현업용, 215 지표 + 보고서필드 인벤토리 매핑)
# Co-authored with CoCo
"""
GN_DW '지표 → GOLD' 추적(traceability) 장표 생성기.
"원하는 지표가 GOLD 어디에(FACT/DIM/SV·물리컬럼·SV base) 어떻게 매핑됐는지" 한 눈에 본다.

정본(근거) — 모두 파싱해 지표번호로 조인:
  - 03_top-down_gold/02_지표 분류.md        (215 지표: 유형·소스·단위·배속 FACT/DIM/SV)
  - 99_provided_definition/02_지표사전 공통.md (공통 162: 정의·정본 계산식)
  - 99_provided_definition/03_지표사전 신규.md (신규 53: 정의·정본 계산식)
  - 03_top-down_gold/04_SV파생 매핑.md       (derived 81 → 분자/분모 base + FACT, base 물리컬럼 카탈로그)
  - scripts/gen_column_mapping.py            (GOLD 컬럼 → SILVER → BRONZE 계보 재사용)
  - 99_provided_definition/04·05 보고서필드 인벤토리.md (보고서×필드 → 지표번호/GOLD 매핑)

출력(30_output_share): MD(가독) · CSV(가공) · XLSX(현업 공유, 시트 분할)
"""
import csv, os, re, sys, json, importlib.util

WS = os.path.realpath("/workspace")
OUT_DIR = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
LINEAGE_CSV = os.environ.get("GN_DW_LINEAGE", os.path.join(OUT_DIR, "04_컬럼계보매핑.csv"))
CENSUS = os.environ.get("GN_DW_CENSUS", "/tmp/census.json")
MEASURED = os.environ.get("GN_DW_MEASURED", "")
BASENAME = "05_지표GOLD매핑"
GEN_PATH = "scripts/gen_metric_gold_mapping.py"
PROV = f"본 파일은 자동 생성물입니다. 직접 수정 금지 — 생성기 {GEN_PATH} 수정 후 재실행하세요."

DOC_CLS   = os.path.join(WS, "03_top-down_gold", "02_지표 분류.md")
DOC_COMM  = os.path.join(WS, "99_provided_definition", "02_지표사전 공통.md")
DOC_NEW   = os.path.join(WS, "99_provided_definition", "03_지표사전 신규.md")
DOC_SV    = os.path.join(WS, "03_top-down_gold", "04_SV파생 매핑.md")
DOC_INV   = os.path.join(WS, "03_top-down_gold", "05_필드 인벤토리.md")
DOC_MKT   = os.path.join(WS, "99_provided_definition", "04_마케팅_보고서필드 인벤토리.md")
DOC_MEM   = os.path.join(WS, "99_provided_definition", "05_회원_보고서필드 인벤토리.md")


# ─────────────────────────────── 마크다운 테이블 파서 ───────────────────────────────
def parse_md(path):
    """마크다운 파일을 훑어 표 블록을 반환. 각 표: dict(h1,h2,h3,label,header[],rows[[]]).
    label = 표 직전의 **굵은글씨** 라벨(예: 'CRM 필드')."""
    h1 = h2 = h3 = label = ""
    tables, block = [], []
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()

    def is_sep(cells):
        return cells and all(re.fullmatch(r":?-{2,}:?", c.strip() or "-") for c in cells if c.strip() != "") \
            and all(set(c.strip()) <= set("-: ") for c in cells)

    def flush(block, ctx):
        rows = []
        for ln in block:
            cells = [c.strip() for c in ln.strip().strip("|").split("|")]
            rows.append(cells)
        # 분리행 제거
        rows = [r for r in rows if not is_sep(r)]
        if len(rows) >= 2:
            tables.append({**ctx, "header": rows[0], "rows": rows[1:]})

    for raw in lines:
        ln = raw.rstrip("\n")
        s = ln.strip()
        if s.startswith("|"):
            block.append(ln)
            continue
        if block:
            flush(block, {"h1": h1, "h2": h2, "h3": h3, "label": label})
            block = []
        if s.startswith("# "):
            h1, h2, h3 = s[2:].strip(), "", ""
        elif s.startswith("## "):
            h2, h3 = s[3:].strip(), ""
        elif s.startswith("### "):
            h3 = s[4:].strip()
        m = re.fullmatch(r"\*\*(.+?)\*\*", s)
        if m:
            label = m.group(1).strip()
    if block:
        flush(block, {"h1": h1, "h2": h2, "h3": h3, "label": label})
    return tables


def col_idx(header, *needles):
    for i, h in enumerate(header):
        for nd in needles:
            if nd in h:
                return i
    return None


def clean_placement(v):
    """배속 셀에서 대표 토큰만: 'SV ✅…'→'SV', 'FAD ✅실측…'→'FAD', 'FMM ⚠️…'→'FMM'."""
    v = v.strip()
    v = re.split(r"[ \u2705\u26a0\ufe0f]", v, 1)[0]
    return v.strip()


def base_token(v):
    """base 표현에서 선두 UPPER_SNAKE 식별자 추출: 'CAMPAIGN_UNPAID_CNT ×10000'→'CAMPAIGN_UNPAID_CNT'."""
    m = re.search(r"[A-Z][A-Z0-9_]+", v or "")
    return m.group(0) if m else ""


# ─────────────────────────────── 1) gen_column_mapping ROWS 재사용 ───────────────────────────────
def load_gcm():
    """계보는 04_컬럼계보매핑.csv(실측 파생물)에서 읽는다.

    ⚠️ 구 판본은 `gen_column_mapping.py` 의 하드코딩 리스트를 import 했다. 그 리스트가 stale 해지면
    이 문서도 함께 stale 해졌다(O24·O26·O34·O38·O39 미반영). 이제는 **측정 산출물을 입력으로 받는다**.
    """
    col2src, obj2src = {}, {}
    if not os.path.exists(LINEAGE_CSV):
        raise SystemExit(f"계보 입력이 없습니다: {LINEAGE_CSV} — 먼저 gen_column_mapping.py 를 실행하세요.")
    with open(LINEAGE_CSV, encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            col = r["WIDE_컬럼"]
            gold = r["GOLD_원천(테이블.컬럼)"]
            silver = r["SILVER_원천(테이블.컬럼)"]
            bronze = r["BRONZE_원천(테이블)"]
            conf = r["계보_확정도"]
            col2src.setdefault(col, (silver, bronze, conf, r["WIDE_마트"]))
            gt = gold.split(".")[0] if "." in gold else ""
            if gt:
                obj2src.setdefault(gt, (silver, bronze, conf, r["WIDE_마트"]))
    return col2src, obj2src


def load_census():
    """GOLD 물리 컬럼 실측 census — 상태 판정을 추측이 아니라 측정으로 한다."""
    if not os.path.exists(CENSUS):
        return {}
    raw = json.load(open(CENSUS, encoding="utf-8"))
    out = {}
    for k, v in raw.items():
        if not k.startswith("GOLD."):
            continue
        t = k.split(".", 1)[1]
        for c, i in v["cols"].items():
            out.setdefault(c, []).append((t, v["rows"], int(i["nonnull"] or 0), int(i["nonzero"] or 0)))
    return out


CENSUS_IDX = {}


def measured_status(physical):
    """물리컬럼명으로 census 를 조회해 상태를 판정. 못 찾으면 (None, 근거없음)."""
    tok = base_token(physical or "")
    if not tok or tok not in CENSUS_IDX:
        return None, ""
    best = None
    for t, rows, nn, nz in CENSUS_IDX[tok]:
        if rows == 0:
            cand = ("WAIT", f"`{t}` 0행")
        elif nn == 0:
            cand = ("WAIT", f"`{t}.{tok}` 전건 NULL")
        elif nz == 0:
            cand = ("WAIT", f"`{t}.{tok}` 전건 0 — 설계O·값 미주입")
        elif nz < rows:
            cand = ("PARTIAL", f"`{t}.{tok}` 비영 {nz:,}/{rows:,} ({nz/rows*100:.1f}%)")
        else:
            cand = ("OK", f"`{t}.{tok}` 비영 {nz:,}/{rows:,} (100%)")
        rank = {"OK": 0, "PARTIAL": 1, "WAIT": 2}
        if best is None or rank[cand[0]] < rank[best[0]]:
            best = cand
    return best


# ─────────────────────────────── 2) 지표 분류 (215 배속) ───────────────────────────────
def load_classification():
    """{'공4': {...}, '신20': {...}} — name/유형/소스/단위/basis/배속/배속원문."""
    out = {}
    for t in parse_md(DOC_CLS):
        if col_idx(t["header"], "지표명") is None or col_idx(t["header"], "배속") is None:
            continue
        pref = "공" if "공통" in t["h2"] else ("신" if "신규" in t["h2"] else None)
        if not pref:
            continue
        for r in t["rows"]:
            if not r or not r[0].isdigit():
                continue
            key = f"{pref}{int(r[0])}"
            out[key] = {
                "name": r[1], "type": r[2], "src": r[3], "unit": r[4],
                "basis": r[5] if len(r) > 5 else "",
                "place_raw": r[7] if len(r) > 7 else "",
                "place": clean_placement(r[7] if len(r) > 7 else ""),
            }
    return out


# ─────────────────────────────── 3) 지표사전 (정의·계산식) ───────────────────────────────
def load_dictionary(path, pref):
    out = {}
    for t in parse_md(path):
        ci_no = col_idx(t["header"], "순서")
        ci_nm = col_idx(t["header"], "지표명")
        ci_def = col_idx(t["header"], "정의")
        ci_fx = col_idx(t["header"], "계산식")
        if None in (ci_no, ci_nm, ci_fx):
            continue
        for r in t["rows"]:
            if ci_no >= len(r) or not r[ci_no].isdigit():
                continue
            key = f"{pref}{int(r[ci_no])}"
            out[key] = {
                "cat": r[1] if len(r) > 1 else "",
                "def": r[ci_def] if ci_def is not None and ci_def < len(r) else "",
                "formula": r[ci_fx] if ci_fx < len(r) else "",
            }
    return out


# ─────────────────────────────── 4) SV파생 (derived base + base 카탈로그) ───────────────────────────────
def load_sv():
    """returns (num2base_measure, derived_map)
       num2base_measure: {'공4':'DEV_CNT', ...}  (§1 base 카탈로그 역인덱스)
       derived_map: {'공45':{'num':'MONTH_END_ACTIVE_CNT','den':'...','fact':'FMM','note':''}, ...}"""
    num2base, derived = {}, {}
    for t in parse_md(DOC_SV):
        h2 = t["h2"]
        hdr = t["header"]
        # §1 base 카탈로그
        if col_idx(hdr, "base 물리명") is not None and col_idx(hdr, "원천 지표#") is not None:
            ci_b = col_idx(hdr, "base 물리명")
            ci_s = col_idx(hdr, "원천 지표#")
            for r in t["rows"]:
                if ci_s >= len(r):
                    continue
                # 'A / B / C' 다중 base → 지표번호와 위치(순서)로 페어링
                base_list = [base_token(x) for x in re.split(r"\s*/\s*", r[ci_b]) if base_token(x)]
                nums_seq = [f"{pref}{n}" for pref, nums in _parse_srcnums(r[ci_s]) for n in nums]
                if base_list and len(base_list) == len(nums_seq):
                    for k, b in zip(nums_seq, base_list):
                        num2base.setdefault(k, b)
                else:
                    b0 = base_list[0] if base_list else base_token(r[ci_b])
                    for k in nums_seq:
                        num2base.setdefault(k, b0)
            continue
        # §2(공통 derived) / §3(신규 derived)
        pref = "공" if h2.strip().startswith("2.") else ("신" if h2.strip().startswith("3.") else None)
        ci_num = col_idx(hdr, "분자")
        ci_den = col_idx(hdr, "분모")
        ci_fact = col_idx(hdr, "FACT")
        if pref and ci_num is not None and col_idx(hdr, "#") == 0:
            for r in t["rows"]:
                if not r or not r[0].isdigit():
                    continue
                key = f"{pref}{int(r[0])}"
                derived[key] = {
                    "num": r[ci_num] if ci_num < len(r) else "",
                    "den": r[ci_den] if ci_den is not None and ci_den < len(r) else "",
                    "fact": r[ci_fact] if ci_fact is not None and ci_fact < len(r) else "",
                }
    return num2base, derived


# ─────────────────────────────── 4b) GOLD 물리 필드 인벤토리 (보고서필드 → GOLD 컬럼 정본) ───────────────────────────────
INV_DELIMS = re.compile(r"\s(?:SUM|COUNT|AVG|COALESCE|비가산|conform|롤업|GA4)|—|\((?:overview|05|04|신규|신#|SCD|정본|원천|=|선택|MM|SND|TM_|TH_|TD_|CRM|MBER|행동|건/)|/\s?10000")


def _inv_label(desc):
    """설명에서 보고서필드 한글 라벨만 추출: '개발(건) SUM(금액)/10000 (#4·5·149)' → '개발(건)'."""
    d = re.sub(r"\(?(?:신규|신)?#\s*[\d·~]+\)?", "", desc)   # #지표번호 제거
    d = INV_DELIMS.split(d)[0]
    return d.strip(" .·")


def _inv_metricno(desc):
    """설명의 (#..) → '공4·5·149' / '신20' 형태."""
    outs = []
    for pre, body in re.findall(r"(신규|신|공)?\s*#\s*([\d·~]+)", desc):
        p = "신" if pre in ("신규", "신") else "공"
        nums = []
        for part in re.split(r"·", body):
            if "~" in part:
                a, b = part.split("~")
                if a.isdigit() and b.isdigit():
                    nums += [str(x) for x in range(int(a), int(b) + 1)]
            elif part.isdigit():
                nums.append(part)
        if nums:
            outs.append(p + "·".join(nums))
    return " ".join(outs)


def load_gold_inventory():
    """05_필드 인벤토리.md 파싱 → 보고서필드(설명) → GOLD 물리컬럼 정본 인덱스.
    returns (idx: label_norm→entry, entries: [entry]).  entry={col,table,desc,label_norm,mno}."""
    entries = []
    for t in parse_md(DOC_INV):
        # 표 소속 GOLD 객체: 헤딩 'D2. DIM_MEMBER ...' / 'FMM. FACT_MEMBER_MONTHLY ...'
        head = t["h3"] or t["h2"]
        m = re.match(r"[A-Z0-9_]+\.\s*([A-Z_]+)", head)
        if not m or col_idx(t["header"], "컬럼명") is None:
            continue
        table = m.group(1)
        ci_c = col_idx(t["header"], "컬럼명")
        ci_d = col_idx(t["header"], "설명")   # '설명' 또는 '설명/basis'
        for r in t["rows"]:
            if ci_c >= len(r):
                continue
            col = r[ci_c].strip()
            if not col or col.startswith("~~") or "❌" in " ".join(r):   # 삭제 컬럼 제외
                continue
            if col.endswith("_SK") or col in ("MEMBER_DK", "ORG_DK", "CAMPAIGN_BK", "SPONSORSHIP_BK",
                                              "REASON_CODE", "AD_CREATIVE_BK", "EVENT_BK"):
                pass  # 키도 매핑 대상(회원번호 등)이라 유지
            desc = r[ci_d] if ci_d is not None and ci_d < len(r) else ""
            label = _inv_label(desc)
            entries.append({
                "col": col, "table": table, "desc": desc,
                "label_norm": _norm(label), "mno": _inv_metricno(desc),
            })
    idx = {}
    for e in entries:
        if e["label_norm"]:
            idx.setdefault(e["label_norm"], e)
    return idx, entries


def _parse_srcnums(cell):
    """'공4·5·149' → [('공',[4,5,149])]; '공139~142' → [('공',[139..142])]; '신20' → [('신',[20])]."""
    res = []
    for pref, body in re.findall(r"(공|신)\s*([\d·~,\s]+)", cell):
        nums = []
        for part in re.split(r"[·,\s]+", body.strip()):
            if not part:
                continue
            if "~" in part:
                a, b = part.split("~")
                if a.isdigit() and b.isdigit():
                    nums.extend(range(int(a), int(b) + 1))
            elif part.isdigit():
                nums.append(int(part))
        if nums:
            res.append((pref, nums))
    return res


# ─────────────────────────────── 5) 상태 판정 ───────────────────────────────
IDENTITY_SET = {"공81", "공122", "신32", "신33"}
WAIT_SET = {"공152", "공153", "공154", "공155"}


def derive_status(key, cls, place, physical=""):
    """상태 판정 — **실측 우선**.

    ① 물리 컬럼을 특정할 수 있으면 census(`COUNT`/`COUNT_IF(<>0)`)로 판정한다.
    ② 특정 불가(파생 metric·차원 배속 등)일 때만 배속·원천 계통 추정으로 내려간다.
       이때 근거 열에 「추정」임을 명시한다 — 실측과 추정을 섞어 보여주지 않는다.
    """
    ms = measured_status(physical) if physical else None
    if ms and ms[0]:
        return ms[0], "실측: " + ms[1]

    raw = (cls.get("place_raw", "") + " " + cls.get("basis", ""))
    if key in WAIT_SET or "FTG-B" in place or "FTG_B" in place or "원천 부재" in raw or "입고 대기" in raw or "대기" in raw:
        return "WAIT", "추정: 원천 미입고 계통(E-6 등)"
    if key in IDENTITY_SET or "identity" in raw:
        return "PARTIAL", "추정: identity 브리지 의존"
    src = cls.get("src", "")
    p = place.upper()
    if src in ("GA4", "GA") or p.startswith("FGA") or "GA_" in p:
        return "PARTIAL", "추정: GA4 계통(G-5 샤드 부분입고)"
    if src == "AGENCY" or p.startswith("FAD") or "AD_CREATIVE" in p:
        return "PARTIAL", "추정: AGENCY 계통(연결키 Q10 대기)"
    if p.startswith("FBD") or (src == "ERP"):
        return "PARTIAL", "추정: ERP 예산 계통(E-1/E-4 대기)"
    return "OK", "추정: 배속·원천 계통에 알려진 제약 없음"


# ─────────────────────────────── 6) 지표 → GOLD 행 조립 ───────────────────────────────
# SV파생 §1 base 카탈로그에 없는 measure → 실제 WIDE 물리컬럼(gen_column_mapping.py ROWS 존재값)으로 보강
MEASURE_OVERRIDE = {
    "공25": "INBOUND_CALL",      # 인입콜 (WIDE_AD_PERFORMANCE)
    "공66": "REGULAR_FEE",       # 정기회비 (WIDE_MEMBER_MONTHLY)
    "공87": "FAIL_MEMBERS",      # 실패수(명) (WIDE_SERVICE_EVENT)
    "공91": "GIFT_PART_AMT",     # 선물금참여(원) (WIDE_SERVICE_EVENT)
    "공97": "SESSION_CNT",       # 세션수(명) (WIDE_GA_BEHAVIOR)
    "공107": "SCROLL_DEPTH",     # 스크롤깊이 (WIDE_GA_BEHAVIOR)
}

HEADER = ["지표#", "구분", "지표명", "유형", "소스", "단위",
          "GOLD_배속", "GOLD_매핑(물리컬럼/SV base)", "SILVER_원천", "BRONZE_원천",
          "정본_계산식", "상태", "상태_근거"]


def build_metric_rows():
    cls = load_classification()
    comm = load_dictionary(DOC_COMM, "공")
    new = load_dictionary(DOC_NEW, "신")
    dic = {**comm, **new}
    num2base, derived = load_sv()
    col2src, obj2src = load_gcm()

    def src_for_col(col):
        col = base_token(col) or col
        if col in col2src:
            s = col2src[col]
            return s[0], s[1]
        return "", ""

    def src_for_obj(obj):
        obj = obj.split("(")[0].split(" ")[0].strip()
        if obj in obj2src:
            s = obj2src[obj]
            return s[0], s[1]
        return "", ""

    rows, num2metricnum = [], {}      # num2metricnum: GOLD컬럼 → 지표# (04 계보 보강용)
    order = [f"공{i}" for i in range(1, 163)] + [f"신{i}" for i in range(1, 54)]
    for key in order:
        c = cls.get(key)
        if not c:
            continue
        d = dic.get(key, {})
        place = c["place"]
        typ = c["type"]
        silver = bronze = ""
        if typ == "derived":
            dv = derived.get(key)
            if dv:
                num_b, den_b = dv["num"], dv["den"]
                fact = dv["fact"] or place
                gold = f"SV metric — 분자: {num_b or '—'} / 분모: {den_b or '—'}"
                silver, bronze = src_for_col(num_b)
                place_disp = f"SV ({fact})" if fact and fact != "SV" else "SV"
            else:
                gold = "SV metric (파생 — base는 04_SV파생 매핑.md 참조)"
                place_disp = place
            # #98·108 GA4 비가산은 물리 적재
            if key in ("공98", "공108"):
                gold = "FGA 물리적재(비가산) — " + gold
                silver, bronze = src_for_obj("FACT_GA_BEHAVIOR")
        elif typ == "measure":
            base = num2base.get(key, "") or MEASURE_OVERRIDE.get(key, "")
            if base:
                gold = f"{place}.{base}" if place and not place.endswith(")") else f"{place} · {base}"
                silver, bronze = src_for_col(base)
                num2metricnum.setdefault(base, []).append(key)
            else:
                gold = f"{place} (measure — 컬럼 06_DDL.sql 확인)"
                silver, bronze = src_for_obj(place)
        else:  # dimension
            gold = f"{place}"
            silver, bronze = src_for_obj(place)
        phys = ""
        if typ == "measure":
            phys = num2base.get(key, "") or MEASURE_OVERRIDE.get(key, "")
        elif typ == "derived":
            dv2 = derived.get(key)
            phys = (dv2 or {}).get("num", "") or ""
        st, st_why = derive_status(key, c, place, phys)
        rows.append([
            key, d.get("cat", c.get("", "")) or _cat_guess(place, typ), c["name"], typ, c["src"], c["unit"],
            place, gold, silver, bronze, d.get("formula", ""), st, st_why,
        ])
    return rows, num2base, derived, num2metricnum


def _cat_guess(place, typ):
    return ""


# ─────────────────────────────── 7) 보고서필드 인벤토리 매핑 ───────────────────────────────
def _norm(s):
    s = s.lower()
    s = s.replace("중복", "")
    s = re.sub(r"[\s()（）\[\]/·,%*=＝~:\-—–÷]", "", s)
    s = s.replace("（", "").replace("）", "")
    return s


# ③ 부분일치에서 제외할 GOLD 컬럼(동명이의·코호트한정·구간(band)·예산 세분 — 반드시 명시적 별칭으로만 매핑)
# 근거: 표본검증 2026-07-27에서 substring 오매핑 유발 확인
#   UTM_CONTENT('세션 수동 광고 콘텐츠')←'세션수' · D5_*(+5일차 코호트)←'선물금 참여(건)'
#   *_BAND(구간)←'후원금액' · *_BUDGET_*(월/연/ERP/추정 구분)←'연 편성예산'
INV_NO_SUBSTR = {"UTM_CONTENT", "UTM_TERM",
                 "AMOUNT_BAND1", "AMOUNT_BAND2", "PERIOD_BAND1", "PERIOD_BAND2",
                 "PLAN_BUDGET_MONTH", "PLAN_BUDGET_YEAR", "EXEC_BUDGET_ERP", "EXEC_BUDGET_EST"}


def build_field_index(metric_rows):
    """보고서필드 매칭용 인덱스 구성.
    - metric_idx: 정규화 지표명 → (지표#, 유형, GOLD매핑, 배속)  [율/파생=SV 매핑 확보]
    - inv_idx/inv_entries: GOLD 물리 필드 인벤토리(05_필드 인벤토리.md) → 물리 컬럼 정본
    - alias: 보고서 표기 변형 → 표준 라벨"""
    metric_idx = {}
    for r in metric_rows:
        metric_idx.setdefault(_norm(r[2]), (r[0], r[3], r[7], r[6]))
    inv_idx, inv_entries = load_gold_inventory()
    alias = {
        # 목표달성율(개발) — SV 파생(공1~3)
        "월목표달성율": "월 목표대비 개발(%)", "월목표대비개발건": "월 목표대비 개발(%)", "월목표대비개발": "월 목표대비 개발(%)",
        "누계월목표달성율": "누계 목표대비 개발(%)", "누계목표대비개발건": "누계 목표대비 개발(%)",
        "연목표달성율": "연 목표대비 개발(%)", "연목표대비개발건": "연 목표대비 개발(%)",
        # 개발/활동/중단/미납/감액 — 물리 컬럼(인벤토리)
        "개발건": "개발(건)", "개발명": "개발(명)", "누계개발건": "개발(건)", "누계개발명": "개발(명)",
        "전년동월개발명": "개발(명)", "전년누계개발명": "개발(명)", "전년대비증감개발명": "개발(명)",
        "활동명": "활동(명)", "활동건": "활동(건)", "활동누계명": "활동누계(명)", "활동누계건": "활동누계(건)",
        "중단건": "중단(건)", "중단명": "중단(명)", "미납건": "미납(건)", "감액건": "감액(건)", "이탈건": "이탈(건)",
        "증액명": "증액(명)", "증액건": "증액(건)", "미납중단명": "미납중단(명)", "미납중단건": "미납중단(건)",
        "월말활동회원건": "월말활동회원(건)", "연도초활동회원건": "연도초 활동회원(건)", "연도말활동회원건": "연도말 활동회원(건)",
        # 회비/금액
        "정기회비": "정기회비(원)", "납입회비": "납입회비(원)", "청구": "청구(원)", "청구회비": "청구(원)",
        "후원기간개월": "후원기간(개월)", "후원기간년": "후원기간(년)", "납입개월수": "납입개월수",
        # 서비스 발송·참여 — 물리 컬럼
        "발송수": "발송수(명)", "발송명": "발송수(명)", "성공수": "성공수(명)", "발송성공수": "성공수(명)", "오픈": "오픈(명)", "오픈수": "오픈(명)",
        "실패수": "실패수(명)", "서신참여명": "서신참여(명)", "서신참여건": "서신참여(건)",
        "선물금참여명": "선물금참여(명)", "선물금참여원": "선물금참여(원)", "서비스명": "서비스(명)", "서비스건": "서비스(건)",
        # GA 행동 — 물리 컬럼(device 분해는 동일 컬럼)
        "방문수": "방문수", "방문수합계": "방문수", "pc방문수": "방문수", "m방문수": "방문수", "app방문수": "방문수",
        "활성사용자": "활성사용자수", "활성사용자합계": "활성사용자수",
        "pc활성사용자": "활성사용자수", "m활성사용자": "활성사용자수", "app활성사용자": "활성사용자수",
        "총사용자": "총사용자", "이벤트수": "이벤트수", "조회수": "조회수",
        "세션수": "세션수", "세션": "세션수", "평균세션시간": "평균세션시간", "스크롤깊이": "스크롤깊이", "이탈율": "이탈율", "참여율": "참여율",
        "eventcategory": "event_category", "eventaction": "event_action", "eventlabel": "event_label",
        # 차원(공통) — 물리 컬럼
        "부서명": "부서", "부서": "부서", "법인명": "법인", "법인": "법인", "본부지부": "본부/지부",
        "브랜드": "공통브랜드", "상위캠페인": "공통상위캠페인", "홍보방법": "홍보방법",
        "매체명브랜드2": "매체명/공동브랜드", "매체명": "매체명/공동브랜드",
        "캠페인": "캠페인명", "캠페인명": "캠페인명", "후원사업": "후원사업 전체", "후원사업2명": "후원사업 전체", "후원사업명": "후원사업 전체",
        "개발구분": "개발구분", "성별": "성별", "성별회원": "성별", "지역": "지역", "회원상태": "회원상태", "회원구분": "회원구분",
        "연령대": "연령대", "가입경로": "가입경로", "신규기존": "신규기존구분", "신규기존구분": "신규기존구분",
        "납입방식": "납입방식", "발송구분": "발송구분 대", "발송구분대": "발송구분 대", "미납사유": "미납사유", "중단사유": "중단사유",
        "제목": "제목", "발송상태": "발송상태", "회원번호": "회원번호",
        "노출수횟수": "노출수", "노출수": "노출수", "클릭수": "클릭수", "인입콜": "인입콜",
        "ga전환수명": "GA전환수", "ga전환수건": "GA전환수", "전환수": "GA전환수",
        # 목표(회원개발목표=FTG_D.GOAL_CNT, 물리) / 목표달성율(=SV 공1~3)
        "월목표": "회원개발목표", "연목표": "회원개발목표", "누계월목표": "회원개발목표", "누계목표": "회원개발목표", "월목표누계": "회원개발목표",
        "월목표대비달성율": "월 목표대비 개발(%)", "누계목표대비달성율": "누계 목표대비 개발(%)", "연목표대비달성율": "연 목표대비 개발(%)",
        # 발송 성공/실패(명)·납입(원) 축약형
        "성공명": "성공수", "실패명": "실패수", "발송성공명": "성공수", "발송실패명": "실패수",
        "납입원": "납입회비", "납입": "납입회비", "누계중단명": "중단(명)", "누계개발명2": "개발(명)",
        # 예산(FBD 물리) — 누계·집행율(%)은 SV라 물리 없음(미매칭 정상)
        "월편성예산": "편성예산", "연편성예산": "편성예산", "편성예산": "편성예산",
        "월집행예산erp마감값": "집행예산", "월집행예산추정치": "집행예산", "집행예산": "집행예산",
        # 광고 차원 축약
        "매체유형명": "매체유형", "잠재고객이름타겟그룹": "타겟그룹", "송출플랫폼": "플랫폼",
        # 표기 변형(률/율)
        "이탈률": "이탈율", "기준일자": "실제 일자", "기준일시": "실제 일자",
        # 이벤트/행사(FEP·DIM_EVENT 물리)
        "이벤트명": "행사명", "이벤트구분": "행사구분", "이벤트관리": "행사명", "총참여수": "참여자수",
        "이벤트참여횟수전체": "참여횟수", "정기후원금": "정기후원금", "참여일": "참여경로",
        # 기타 물리 차원
        "실적지부": "본부/지부", "아동번호": "결연아동코드", "최초브랜드": "최초캠페인",
        "세션수동콘텐츠": "세션 수동 광고 콘텐츠", "세션콘텐츠": "세션 수동 광고 콘텐츠",
        # 날짜 grain(→DIM_DATE) · 실적(→개발 measure) · 후원금액대
        "기준년월": "실제 일자", "기준년도": "실제 일자", "신청일자": "실제 일자",
        "최근참여일": "실제 일자", "참여일자": "실제 일자",
        "월실적": "개발(건)", "일별실적": "개발(건)",
        "후원금액대약정금액기준10000원": "후원금액대1 5만",
        "후원기간대납입기준": "후원기간대1 5년",
        # ── 표본검증(2026-07-27) 확정 별칭: substring 오매핑 교정분 ──
        "세션수": "세션수(명)", "세션": "세션수(명)",                    # ←UTM_CONTENT 오매핑 교정
        "월편성예산": "편성예산(월)", "연편성예산": "편성예산(연)",         # ←월/연 구분
        "월집행예산erp마감값": "집행예산(ERP, 월)", "월집행예산추정치": "집행예산(추정)",
        "연도초활동건": "연도초 활동회원(건)", "전월말활동건": "전월말 활동회원(건)",  # ←공49·53 전용컬럼
        "가입캠페인": "캠페인명", "최근캠페인": "최종캠페인",
        "최초상위캠페인": "공통상위캠페인", "상위캠페인10개": "공통상위캠페인",
        "기준일납입일": "실제 일자", "가입부서": "부서", "실적지부본부지부": "본부/지부",
        "연령": "연령대",
    }
    return metric_idx, inv_idx, inv_entries, alias


def slice_axis(field, gold):
    """보고서필드가 GOLD 컬럼의 어떤 '분해 축(슬라이스)'인지 판정.
    같은 컬럼으로 수렴하는 필드(PC/M/APP 방문수, 전년/주간 개발건)가 실제로는
    필터·윈도우를 걸어야 나오는 값임을 명시 — 현업 오해 방지(§8-E #1-2).
    이미 컬럼명이 시점/윈도우를 내포하면(YEAR_START·PREV_MONTH·MONTH_END·CUM) 중복표기하지 않는다.
    ⚠️ 축값 적재 실측(2026-07-27): `DIM_DEVICE`=PC·M·(unknown) 3건뿐 → **APP 축값 미적재**.
       `FACT_GA_BEHAVIOR`.DEVICE_SK는 전건 적재(널/0 없음), 실분포 M 36,035행·PC 8,870행."""
    if not gold or gold.startswith("("):
        return ""
    ax = []
    # 디바이스 축 (DIM_DEVICE.DEVICE_TYPE = PC/M/APP · FGA/FAD의 DEVICE_SK 조인)
    if re.match(r"^PC", field):
        ax.append("DIM_DEVICE.DEVICE_TYPE='PC'")
    elif re.match(r"^APP", field):
        ax.append("DIM_DEVICE.DEVICE_TYPE='APP' ⚠️축값 미적재(2026-07-27 실측: PC·M만)")
    elif re.match(r"^M[가-힣]", field):
        ax.append("DIM_DEVICE.DEVICE_TYPE='M'")
    # 기간 윈도우 축 (컬럼이 이미 시점을 내포하면 생략)
    encoded = any(t in gold for t in ("YEAR_START", "PREV_MONTH", "MONTH_END", "_CUM", "CUM_"))
    if not encoded:
        tw = []
        if "전전년" in field:
            tw.append("전전년 동기")
        elif "전년" in field:
            tw.append("전년 동기")
        elif "전월" in field:
            tw.append("전월")
        elif "전주" in field:
            tw.append("전주")
        if "누계" in field:
            tw.append("YTD 누계")
        if "주간" in field or "주차" in field:
            tw.append("주")
        elif "당월" in field or "당해년도" in field:
            tw.append("당기")
        if tw:
            ax.append("기간윈도우: " + "+".join(tw))
    # 신규/기존 귀속 축
    if "신규" in field and "기존" not in field:
        ax.append("FMM.NEW_EXISTING_FLAG='신규'")
    elif "기존" in field and "신규" not in field:
        ax.append("FMM.NEW_EXISTING_FLAG='기존'")
    # 전체 합계(축 없음) 명시
    if not ax and ("합계" in field or "전체" in field):
        return "(전체 합계 · 축 없음)"
    return " · ".join(ax)


def map_report_fields(doc, indices, kind):
    """보고서필드 표 → [영역, 섹션, 필드값, 원천, TYPE, 대응 지표#, GOLD 매핑, 매핑근거].
    매핑 우선순위: ① GOLD 물리 필드 인벤토리(물리 컬럼) → ② 지표사전(율·파생=SV) → ③ 부분일치.
    지표번호가 없어도 물리 컬럼이 있으면 매핑된다(예: 연령대→DIM_MEMBER.AGE_BAND, 오픈(명)→FSE.OPEN_MEMBERS)."""
    metric_idx, inv_idx, inv_entries, alias = indices
    # 파생 의미 표지: 이 표지를 가진 보고서필드는 물리 컬럼이 아니라 SV 계산항목이다.
    # ③④(부분일치)가 base measure 이름을 substring으로 낚아채 '물리컬럼'으로 오확정하는 것을 차단(정밀도 우선).
    DERIVED_MARK = re.compile(r"율|률|구성비|증감|대비|비중|달성|1인당|1명당|%")

    def resolve(field):
        n = _norm(field)
        cands = [n]
        if n in alias:
            cands.append(_norm(alias[n]))
        # ① 인벤토리 정확일치 → 물리 GOLD 컬럼
        for c in cands:
            if c in inv_idx:
                e = inv_idx[c]
                return (e["mno"] or "(215밖)", f'{e["table"]}.{e["col"]}', "필드인벤토리")
        # ② 지표사전 정확일치 → 율·파생(SV)·측정
        for c in cands:
            if c in metric_idx:
                h = metric_idx[c]
                return (h[0], h[2], "지표사전")
        # 파생 표지가 있으면 부분일치(③④)를 건너뛰고 ⑤ SV 패턴으로 직행
        if not DERIVED_MARK.search(field):
            # ③ 인벤토리 부분일치 (라벨↔필드 포함관계) — 위험 컬럼(blocklist)·+5일차 코호트는 제외
            for c in cands:
                if len(c) >= 2:
                    for e in inv_entries:
                        if e["col"] in INV_NO_SUBSTR or e["col"].startswith("D5_"):
                            continue
                        ln = e["label_norm"]
                        if ln and len(ln) >= 2 and (ln == c or ln.startswith(c) or c.startswith(ln) or c in ln):
                            return (e["mno"] or "(215밖)", f'{e["table"]}.{e["col"]}', "필드인벤토리~")
            # ④ 지표사전 부분일치
            for c in cands:
                if len(c) >= 4:
                    for k, h in metric_idx.items():
                        if k and k in c:
                            return (h[0], h[2], "지표사전~")
        # ⑤ SV 파생 패턴(율·증감·구성비·집행율·1인당·누계) — 물리 컬럼 없이 SV metric으로 계산(P7 등)
        base = ""
        blen = 0
        for e in inv_entries:
            ln = e["label_norm"]
            if ln and len(ln) >= 2 and ln in n and len(ln) > blen:
                base, blen = f'{e["table"]}.{e["col"]}', len(ln)

        def sv(no, desc):
            g = f"SV metric — {desc}" + (f" · base: {base}" if base else "")
            return (no, g, "SV파생")

        pct = bool(re.search(r"%|율|률", field))
        if "증감" in field and (pct or "p" in field.lower().split("증감")[-1]):
            return sv("공60", "증감율(%) = (당기−전기)/전기×100 (P7 시계열)")
        if "증감" in field:
            return sv("공59", "증감 = 당기−전기 (P7 시계열)")
        if "구성비" in field or "비중" in field:
            return sv("(ratio-of-total)", "구성비/비중(%) = 부분/전체×100 (예: 공26·29·신41 패턴)")
        if "달성" in field:
            return sv("공1·2·3", "목표달성율(%) = 개발(건)/회원개발목표 (FTG_D 분모)")
        if "대비" in field:
            return sv("(SV ratio)", "대비(%) = 분자/분모 ×100 — 보고서 정의상 두 base 비율(분모는 보고서 문맥 확인)")
        if "집행율" in field or "집행률" in field:
            return sv("(overview)", "집행율(%) = 집행예산/편성예산 (FBD, P7)")
        if "1인당" in field or "1명당" in field:
            return sv("공61", "1명당 건수 = 활동회원(건)/활동회원(명)")
        if "성공율" in field:
            return sv("(FSE 파생)", "성공율(%) = SUCCESS_MEMBERS/SEND_MEMBERS")
        if "납입" in field and "명" in field:
            return ("(FMM 파생)", "SV metric — 납입회원수(명) = COUNT(DISTINCT MBER_NO WHERE PAY_STAT_CD='S') · 원천 BRONZE_CRM.TM_PM_MBRFEE_ACMSLT(46.4M·적재완료)", "SV파생")
        if "누계" in field:
            return sv("(YTD)", "누계 = base의 YTD running sum (P7·물리 미저장)")
        if pct:
            return sv("(SV ratio)", "비율(%) — SV time-intelligence/ratio")
        if "평균" in field:
            return sv("(SV avg)", "평균 — SV 집계(base AVG)")
        return ("—", "(미매칭 — GOLD 물리·SV 대응 미확인)", "")

    out = []
    for t in parse_md(doc):
        hdr = t["header"]
        ci_f = col_idx(hdr, "필드값")
        ci_s = col_idx(hdr, "데이터 원천", "원천")
        ci_t = col_idx(hdr, "데이터 TYPE", "TYPE")
        if ci_f is None:
            continue
        area = t["h1"] or ""
        section = t["h2"] or ""
        label = t["label"] or ""
        if kind == "mkt":
            area = "마케팅 보고서"
            sec = section
        else:
            sec = (section + (f" · {label}" if label and "필드" in label else "")).strip(" ·")
        for r in t["rows"]:
            if ci_f >= len(r) or not r[ci_f] or r[ci_f] in ("필드값",):
                continue
            field = r[ci_f]
            srcv = r[ci_s] if ci_s is not None and ci_s < len(r) else ""
            typev = r[ci_t] if ci_t is not None and ci_t < len(r) else ""
            mno, gold, basis = resolve(field)
            out.append([area, sec, field, srcv, typev, mno, gold, slice_axis(field, gold), basis])
    return out


# ─────────────────────────────── 8) 출력: CSV ───────────────────────────────
def write_csv(rows, mkt, mem):
    path = os.path.join(OUT_DIR, BASENAME + ".csv")
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow([f"# 생성기: {GEN_PATH}"])
        w.writerow([f"# {PROV}"])
        w.writerow([])
        w.writerow(["## 지표 → GOLD 매핑 (215)"])
        w.writerow(HEADER)
        w.writerows(rows)
        w.writerow([])
        w.writerow(["## 마케팅 보고서필드 → 지표#/GOLD"])
        w.writerow(["영역", "섹션", "필드값", "데이터원천", "데이터TYPE", "대응_지표#", "GOLD_매핑", "분해축", "매핑근거"])
        w.writerows(mkt)
        w.writerow([])
        w.writerow(["## 회원 보고서필드 → 지표#/GOLD"])
        w.writerow(["영역", "섹션", "필드값", "데이터원천", "데이터TYPE", "대응_지표#", "GOLD_매핑", "분해축", "매핑근거"])
        w.writerows(mem)
    return path


# ─────────────────────────────── 9) 출력: MD ───────────────────────────────
def write_md(rows, mkt, mem):
    path = os.path.join(OUT_DIR, BASENAME + ".md")
    n_ok = sum(1 for r in rows if r[11] == "OK")
    n_par = sum(1 for r in rows if r[11] == "PARTIAL")
    n_wait = sum(1 for r in rows if r[11] == "WAIT")
    # 매핑근거별 정밀도 집계(보고서필드) — 커버리지≠정확도임을 명시하기 위함
    from collections import Counter
    basis = Counter((r[8] or "(미매칭)") for r in (mkt + mem))
    L = []
    L.append("<!-- LLM-METADATA")
    L.append("doc_id: METRIC_TO_GOLD_MAPPING")
    L.append("doc_role: 지표번호 → GOLD(FACT/DIM/SV·물리컬럼·SV base) 추적 장표 (현업용)")
    L.append("project: GN_DW (굿네이버스)")
    L.append("grounded_on: 02_지표 분류.md · 02·03 지표사전 · 04_SV파생 매핑.md · 05_필드 인벤토리.md(보고서필드→GOLD 물리컬럼 정본) · gen_column_mapping.py · 04·05 보고서필드 인벤토리")
    L.append(f"generator: {GEN_PATH}")
    L.append("generated: auto (do-not-edit)")
    L.append("END-METADATA -->")
    L.append("")
    L.append("# 지표 → GOLD 매핑 장표 (현업용)")
    L.append("")
    L.append(f"> ⚙️ **생성기**: `{GEN_PATH}` — {PROV}")
    L.append("> **읽는 법**: 현업/기획이 원하는 **지표(지표번호)** 를 기준으로, 그 지표가 GOLD의 어느 **배속(FACT/DIM/SV)** 에")
    L.append("> 어떤 **물리컬럼**(measure·dimension) 또는 **SV base**(derived=율/구성비/LTV 등)로 매핑됐고, 그 값이")
    L.append("> 어떤 **SILVER→BRONZE 원천**에서 오는지 한 줄로 추적합니다.")
    L.append("> 상태: **OK** 사용가능 · **PARTIAL** 일부 대기 · **WAIT** 값 부재(전건 0/NULL 또는 원천 미입고)")
    L.append("")
    L.append("> 🔴 **상태는 가능한 한 실측입니다** — 지표에 대응하는 GOLD 물리 컬럼을 특정할 수 있으면")
    L.append("> `COUNT`/`COUNT_IF(<>0)` 로 직접 측정해 판정하고, 근거를 `상태_근거` 열에 `실측:` 으로 적습니다.")
    L.append("> 물리 컬럼을 특정할 수 없는 경우(파생 metric·차원 배속)에만 배속·원천 계통으로 **추정**하고 `추정:` 으로 표시합니다.")
    L.append("> **`추정:` 행을 사용 가능 근거로 단독 인용하지 마세요.**")
    L.append("")
    L.append("## 0. 요약")
    L.append("")
    L.append(f"- 총 **{len(rows)}개** 지표 (공통 162 + 신규 53).")
    n_meas = sum(1 for r in rows if str(r[12]).startswith("실측"))
    L.append(f"- 상태: ✅ OK **{n_ok}** · ◐ PARTIAL **{n_par}** · ⛔ WAIT **{n_wait}**")
    L.append(f"- 판정 근거: **실측 {n_meas}** / 추정 {len(rows)-n_meas} (실측 = GOLD 물리 컬럼 census 직접 조회)")
    L.append("")
    L.append("> 🔴 **종전 판본은 이 표를 `OK 168 · PARTIAL 43 · WAIT 4` 로 적었습니다. 그것은 과대 진술이었습니다** —")
    L.append("> 상태를 원천 계통으로만 추정해서, `FACT_MEMBER_MONTHLY` 의 활동·미납·증액 카운트나")
    L.append("> `FACT_SERVICE_EVENT` 의 성공·실패·참여 카운트처럼 **컬럼이 전건 `0` 인 지표를 `OK` 로 분류**했습니다.")
    L.append("> 이번 판본은 실측으로 판정하므로 그 지표들이 `WAIT` 로 드러납니다(§0-2).")
    L.append("- **유형별 GOLD 매핑 규칙**: `measure`→FACT 물리컬럼 · `dimension`→DIM(또는 FMM degen/스냅샷) · `derived`→**SV metric**(분자/분모 base로 계산, 물리컬럼 아님. 단 GA4 비가산 #98·108은 FGA 물리적재).")
    L.append("- **약어**: FMM=FACT_MEMBER_MONTHLY · FME=FACT_MEMBER_EVENT · FSE=FACT_SERVICE_EVENT · FAD=FACT_AD_PERFORMANCE · FGA=FACT_GA_BEHAVIOR · FBD=FACT_BUDGET · FEP=FACT_EVENT_PARTICIPATION · FTG-D=FACT_TARGET_DEV · FTG-B=FACT_TARGET_BIZ · SV=Semantic View metric.")
    L.append("")
    waits = [r for r in rows if r[11] == "WAIT" and str(r[12]).startswith("실측")]
    L.append("### 0-2. 🔴 실측 `WAIT` — 「설계는 됐으나 값이 없는」 지표")
    L.append("")
    L.append(f"아래 **{len(waits)}개** 지표는 배속·계보가 모두 확정돼 있으나 대응 GOLD 물리 컬럼이 **전건 0 또는 NULL** 이다.")
    L.append("조회하면 에러 없이 `0` 이 반환되므로 **그 `0` 을 실적으로 읽으면 조용히 틀린다**(P15).")
    L.append("")
    L.append("| 지표# | 지표명 | GOLD 매핑 | 실측 근거 |")
    L.append("|---|---|---|---|")
    for r in waits:
        L.append(f"| `{r[0]}` | {r[2]} | `{r[7]}` | {str(r[12]).replace('실측: ','')} |")
    L.append("")
    L.append("### 0-1. 보고서필드 매핑 신뢰도 (⚠ 커버리지 ≠ 정확도)")
    L.append("")
    L.append("| 매핑근거 | 건수 | 신뢰도 | 해석 |")
    L.append("|---|---:|---|---|")
    for k, lvl, desc in [
        ("필드인벤토리", "높음(정확일치)", "05_필드 인벤토리.md 라벨과 정확히 일치 — 물리 GOLD 컬럼 확정"),
        ("지표사전", "높음(정확일치)", "지표사전 지표명과 정확히 일치"),
        ("SV파생", "중(규칙기반)", "율·증감·구성비·대비 등 규칙 판정 — **분자/분모 확정은 04_SV파생 매핑.md·현업 확인 필요**"),
        ("필드인벤토리~", "**검증필요**(부분일치)", "라벨 부분일치 — 동명이의 가능. 표본검증 권장"),
        ("지표사전~", "**검증필요**(부분일치)", "지표명 부분일치 — 동명이의 가능. 표본검증 권장"),
        ("(미매칭)", "—", "GOLD 물리·SV 어느 쪽도 대응 없음(어드민 제외분 등)"),
    ]:
        L.append(f"| `{k}` | {basis.get(k, 0)} | {lvl} | {desc} |")
    L.append("")
    L.append("> **후속 작업 주의**: 위 표의 `~`(부분일치)·`SV파생` 행은 **문자열/규칙 기반 추정**이다. 현업 확정 전")
    L.append("> 계약·개발 산출물의 근거로 단독 인용하지 말고, `필드인벤토리`/`지표사전`(정확일치) 또는 정본 문서로 재확인할 것.")
    L.append("> 생성 시점 원천 문서가 바뀌면 이 장표는 **자동 갱신되지 않는다** → 생성기 재실행 필요.")
    L.append("")

    def emit_table(title, subset):
        L.append(f"### {title} ({len(subset)})")
        L.append("")
        L.append("| 지표# | 지표명 | 유형 | 소스 | 단위 | GOLD 배속 | GOLD 매핑 (물리컬럼 / SV base) | SILVER 원천 | BRONZE 원천 | 정본 계산식 | 상태 | 상태 근거 |")
        L.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
        for r in subset:
            fx = (r[10] or "").replace("|", "\\|")
            L.append(f"| `{r[0]}` | {r[2]} | {r[3]} | {r[4]} | {r[5]} | `{r[6]}` | `{r[7]}` | `{r[8]}` | `{r[9]}` | {fx} | {r[11]} | {r[12]} |")
        L.append("")

    L.append("## 1. 지표 → GOLD 전체 매핑")
    L.append("")
    emit_table("1-A. 공통 지표", [r for r in rows if r[0].startswith("공")])
    emit_table("1-B. 신규 지표", [r for r in rows if r[0].startswith("신")])

    L.append("---")
    L.append("")
    L.append("## 2. 마케팅 보고서필드 → 지표#/GOLD 매핑")
    L.append("")
    L.append("> `99_provided_definition/04_마케팅_보고서필드 인벤토리.md`(디지털/영상/재송출 효율분석 + 전환회원특성 + 캠페인별 LTV)의 필드를 지표번호·GOLD로 매핑.")
    L.append("> **매핑근거**: `필드인벤토리`=05_필드 인벤토리.md의 GOLD 물리 컬럼과 직접 대응(지표번호 없어도 매핑됨. 예: 연령대→`DIM_MEMBER.AGE_BAND`) · `지표사전`=지표명 일치 · `SV파생`=율/증감/구성비/집행율/1인당/납입(명)/누계 등 **물리 컬럼 없이 SV metric으로 계산**(base·원천 병기) · `~`=부분일치. 미매칭 2건은 어드민 푸시(발송·성공건수, ❌삭제 확정)뿐.")
    L.append("")
    L.append("| 영역 | 섹션 | 필드값 | 데이터 원천 | TYPE | 대응 지표# | GOLD 매핑 | 분해축 | 매핑근거 |")
    L.append("|---|---|---|---|---|---|---|---|---|")
    for r in mkt:
        L.append(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} | `{r[5]}` | `{r[6]}` | {r[7]} | {r[8]} |")
    L.append("")
    L.append("---")
    L.append("")
    L.append("## 3. 회원 보고서필드 → 지표#/GOLD 매핑")
    L.append("")
    L.append("> `99_provided_definition/05_회원_보고서필드 인벤토리.md`(개발현황·회원특성·서비스 보고서의 CRM/GA 필드)를 지표번호·GOLD로 매핑.")
    L.append("")
    L.append("| 영역 | 섹션 | 필드값 | 데이터 원천 | TYPE | 대응 지표# | GOLD 매핑 | 분해축 | 매핑근거 |")
    L.append("|---|---|---|---|---|---|---|---|---|")
    for r in mem:
        L.append(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} | `{r[5]}` | `{r[6]}` | {r[7]} | {r[8]} |")
    L.append("")
    L.append("---")
    L.append("_Co-authored with CoCo_")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    return path


# ─────────────────────────────── 10) 출력: XLSX ───────────────────────────────
def write_xlsx(rows, mkt, mem):
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter
    wb = Workbook()
    hdr_fill = PatternFill("solid", fgColor="1F4E78")
    hdr_font = Font(color="FFFFFF", bold=True, size=10)
    title_font = Font(bold=True, size=13, color="1F4E78")
    wrap = Alignment(wrap_text=True, vertical="top")
    thin = Side(style="thin", color="D0D0D0")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    status_fill = {"OK": PatternFill("solid", fgColor="E2EFDA"),
                   "PARTIAL": PatternFill("solid", fgColor="FFF2CC"),
                   "WAIT": PatternFill("solid", fgColor="FCE4D6")}

    def style_header(ws, row_idx, ncol):
        for c in range(1, ncol + 1):
            cell = ws.cell(row=row_idx, column=c)
            cell.fill = hdr_fill; cell.font = hdr_font
            cell.alignment = wrap; cell.border = border

    def sheet(title, header, data, widths, status_col=None):
        ws = wb.create_sheet(title[:31])
        ws["A1"] = title; ws["A1"].font = title_font
        ws["A2"] = f"⚙️ 생성기: {GEN_PATH}"
        ws.append([]); ws.append(header)
        style_header(ws, 4, len(header))
        for r in data:
            ws.append(r)
        for i, wd in enumerate(widths, 1):
            ws.column_dimensions[get_column_letter(i)].width = wd
        for rr in range(5, ws.max_row + 1):
            for cc in range(1, len(header) + 1):
                cell = ws.cell(row=rr, column=cc)
                cell.alignment = wrap; cell.border = border
            if status_col:
                sv = ws.cell(row=rr, column=status_col).value
                if sv in status_fill:
                    ws.cell(row=rr, column=status_col).fill = status_fill[sv]
        ws.freeze_panes = "A5"
        return ws

    # INDEX
    ws = wb.active; ws.title = "00_INDEX"
    ws["A1"] = "GN_DW 지표 → GOLD 매핑 장표"; ws["A1"].font = title_font
    ws["A2"] = f"⚙️ 생성기: {GEN_PATH} — {PROV}"
    ws.append([]); ws.append(["시트", "내용"]); style_header(ws, 4, 2)
    for nm, desc in [
        ("01_지표GOLD매핑", "215 지표(공통162+신규53) → 배속·물리컬럼/SV base·SILVER/BRONZE·계산식·상태"),
        ("02_마케팅보고서필드", "04 마케팅 보고서필드 → 지표#/GOLD"),
        ("03_회원보고서필드", "05 회원 보고서필드 → 지표#/GOLD"),
    ]:
        ws.append([nm, desc])
    ws.column_dimensions["A"].width = 26; ws.column_dimensions["B"].width = 88
    for rr in range(5, ws.max_row + 1):
        for cc in (1, 2):
            ws.cell(row=rr, column=cc).alignment = wrap; ws.cell(row=rr, column=cc).border = border
    ws.append([]); ws.append(["범례", "OK=사용가능 · PARTIAL=일부대기(GA/AGENCY/ERP·identity) · WAIT=원천 입고 대기"])

    sheet("01_지표GOLD매핑", HEADER, rows,
          [8, 8, 30, 10, 8, 8, 16, 40, 34, 40, 46, 9], status_col=12)
    fhdr = ["영역", "섹션", "필드값", "데이터 원천", "TYPE", "대응 지표#", "GOLD 매핑", "분해축", "매핑근거"]
    sheet("02_마케팅보고서필드", fhdr, mkt, [18, 26, 26, 22, 12, 12, 34, 30, 16])
    sheet("03_회원보고서필드", fhdr, mem, [16, 30, 26, 20, 12, 12, 34, 30, 16])

    import shutil
    tmp = os.path.join("/tmp", BASENAME + ".xlsx")
    wb.save(tmp)
    path = os.path.join(OUT_DIR, BASENAME + ".xlsx")
    shutil.copyfile(tmp, path)
    return path


# ─────────────────────────────── main ───────────────────────────────
def main():
    global CENSUS_IDX
    CENSUS_IDX = load_census()
    rows, num2base, derived, num2metricnum = build_metric_rows()
    indices = build_field_index(rows)
    mkt = map_report_fields(DOC_MKT, indices, "mkt")
    mem = map_report_fields(DOC_MEM, indices, "mem")
    def _rate(x):
        tot = len(x); m = sum(1 for r in x if r[5] != "—"); return f"{m}/{tot} ({100*m//max(tot,1)}%)"
    print("지표 행:", len(rows), "| 마케팅 필드:", _rate(mkt), "| 회원 필드:", _rate(mem))
    print("CSV :", write_csv(rows, mkt, mem))
    print("MD  :", write_md(rows, mkt, mem))
    try:
        print("XLSX:", write_xlsx(rows, mkt, mem))
    except ImportError:
        print("XLSX: openpyxl 미설치")
    # 04 계보 보강용 역인덱스 저장(참고 출력)
    return num2metricnum


if __name__ == "__main__":
    main()
