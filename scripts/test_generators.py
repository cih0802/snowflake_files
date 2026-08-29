#!/usr/bin/env python3
# 산출물 생성기 회귀 테스트 (골든 + 조용한 실패 3종 + 절차 강제)
# Co-authored with CoCo
"""
왜 이 파일이 있는가 — `99_NEXT_SESSION.md` §2-A·§2-B (2026-08-07 실측)

  🔴 `scripts/` 에 test·golden 이 **0건**이었다. 그래서 O47 세션의 사고 2건은
     **둘 다 오류를 내지 않는 조용한 실패**였고 우연히 발견됐다:
       · O47-B (앵커 동점 → 34행이 삽입 순서 의존) = *재빌드로 매핑 2건이 우연히 움직여서* 발견
       · P98   (수기 문서 편집이 생성기 라벨 사전을 오염) = *diff 를 떠 봐서* 발견
     ⇒ 지금 구조로는 다음 사고도 우연에 의존한다. 이 파일이 그 의존을 끊는다.

무엇을 검사하는가
  G  골든 대조     — `30_output_share/{04,05,06,08,09}` 의 행수·판정 분포를 고정한다.
  T1 순서 독립     — 앵커 동점 시 판정이 뒤집히는 사고(O47-B). 삽입 순서를 섞어도 결과 동일.
  T2 라벨 사전     — 수기 문서(`05_필드 인벤토리.md`)가 생성기 라벨 사전을 오염시키는 사고(P98).
                    쓰레기 라벨(상태 마커로 시작하는 주석) 색인 **0건**.
  T3 문자열 계약   — 생성기 간 출력 계약(`SV metric` 접두 · O46 §3-① · P92).
                    상수 · 05 생성기 소스 · 05 산출물 · 09 산출물 **4중 대조**.
  T4 절차 강제     — P97·P100 을 기계 검사한다. 「불가·경합」을 서술한 행은 그 근거에
                    **실제 식별자(백틱 표기)** 가 등장해야 한다. 서사만 있으면 실패다.

🔴 골든의 성격 — 이 골든은 **「데이터가 이 값이어야 한다」가 아니라 「생성기가 어제와 같은
   판정을 내려야 한다」** 는 계약이다. 데이터 입고로 값이 바뀌는 것은 정상이며, 그때는
   **바뀐 이유를 규명한 뒤** `--update-golden` 으로 갱신한다(PROC-3(c): 설명되지 않는 차이 0).
   ⇒ 그래서 실패 메시지에 **차이 내역을 전량 출력**한다. 개수만 보고 갱신하면 검증이 아니다.

실행
  python3 scripts/test_generators.py                # 검사
  python3 scripts/test_generators.py --update-golden # 차이 규명 후 골든 갱신
  python3 scripts/test_generators.py --self-check   # 🔴 일부러 깨뜨려 테스트가 실패하는지 확인

환경 — SQL 접속·census 불요. **산출물 파일과 생성기 소스만 읽는다**(그래서 매번 돌릴 수 있다).
"""
import argparse
import collections
import csv
import hashlib
import json
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # 🔴 샌드박스 sys.path[0] 고정 회피(P90-③)

WS = os.environ.get("GN_DW_WS", "/workspace")
OUT = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
GOLDEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "golden", "outputs.json")
DOC_INV = os.path.join(WS, "03_top-down_gold", "05_필드 인벤토리.md")
GEN_METRIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_metric_gold_mapping.py")

# ── 판정 축 ────────────────────────────────────────────────────────────────
# 「불가·경합」계열 = 근거에 식별자가 반드시 있어야 하는 판정(T4 대상).
#   ◐집계필요도 포함한다 — 「사전집계하라」는 처방이 어느 컬럼을 집계하라는 것인지 없으면 쓸 수 없다.
BLOCKING_VERDICTS = frozenset({
    "도달불가", "원천부재", "배분규칙필요", "형제팩트중복", "grain부정합", "타원천", "집계필요",
})
# 근거 칸에서 「필드명을 실제로 열거했는가」의 기계 판정 = 백틱 안의 대문자 식별자(`TBL` 또는 `TBL.COL`).
IDENT_IN_EVIDENCE = re.compile(r"`([A-Z][A-Z0-9_]*(?:\.[A-Z0-9_]+)?)`")

# 라벨 사전 오염 판정용(P98) — 상태 마커 / 문서 편집 마커 접두.
MARKERS_STATUS = "🔴🟠🟡🟢🔵⚠✅⛔◐❔🆕🔷▸"
EDIT_MARKER = re.compile(r"^\s*\*\*\[[^\]]*\]\*\*")

FAIL = []
PASSED = []


def ok(name, msg=""):
    PASSED.append(name)
    print(f"  PASS  {name}" + (f" — {msg}" if msg else ""))


def bad(name, msg):
    FAIL.append((name, msg))
    print(f"  FAIL  {name} — {msg}")


# ── 산출물 로더 ────────────────────────────────────────────────────────────
def read_csv_sections(path):
    """05·06 처럼 `## 절` 로 나뉜 CSV 를 {절: [헤더, ...행]} 으로. 절이 없으면 {"": [...]}."""
    rr = list(csv.reader(open(path, encoding="utf-8-sig")))
    secs, cur = collections.OrderedDict(), ""
    secs[cur] = []
    for r in rr:
        if r and r[0].startswith("## "):
            cur = r[0].strip()
            secs[cur] = []
            continue
        if r and r[0] and not r[0].startswith("#"):
            secs[cur].append(r)
    return {k: v for k, v in secs.items() if v}


def dicts(sec):
    hdr = sec[0]
    return [dict(zip(hdr, r)) for r in sec[1:]]


def load_09():
    p = os.path.join(OUT, "09_보고서필드_조립가능성.csv")
    return p, list(csv.DictReader(open(p, encoding="utf-8-sig")))


# 🔴 [O48-B 자기검토] `09` 가 없을 때 T1·T3·T4 가 크래시로 죽지 않게 한다 — 결손을 판정으로 알린다.
def load_09_safe(assertion):
    try:
        return load_09()[1]
    except Exception as e:
        bad(assertion, f"09 산출물을 읽을 수 없다: {type(e).__name__} {e}")
        return None


# ── 측정 (골든 생성·대조 공용) ──────────────────────────────────────────────
# 🔴 [2026-08-07 O48-B 자기검토] 종전 `measure()` 는 **산출물 1종이 없으면 `FileNotFoundError` 로
#   죽었다**(실측: `08` 삭제 → 스택트레이스 · T1~T4 **전부 미실행**). 산출물 미생성·개명은 **가장 흔한
#   사고**인데 하필 그때 테스트가 아무것도 진단하지 못한다. ⇒ 파일 단위로 감싸 **결손을 판정으로
#   보고**하고 나머지 검사를 계속한다. 「도구가 죽는 것」과 「도구가 불합격을 알리는 것」은 다르다.
def _guard(m, key, fn):
    try:
        fn()
    except Exception as e:
        m.setdefault("_read_errors", []).append(f"{key}: {type(e).__name__} {e}")


# ── 산출물 기대 목록·신선도 (2026-08-13 O65 신설) ─────────────────────────────
# 🔴 이 목록이 **계약**이다. 종전에는 「한 폴더에 9종이 있다」가 암묵 전제였고, 판본 교체(O59-T)가
#   그 전제를 조용히 깼다. 파일을 옮기는 작업은 앞으로도 있을 것이므로 목록을 코드에 고정한다.
# ⚠️ `02_원천결손_Gap분석.md` 는 **수기 문서이고 생성기가 없어** 아카이브에만 있다 ⇒ 의도적 제외.
#   (제외를 주석으로 남기지 않으면 다음 세션이 「누락」으로 오인해 되돌린다.)
MANIFEST = [
    "01_DW_현업활용가이드.md",                 # 수기
    "03_GN_DW_개념도.html",
    "04_컬럼계보매핑.csv", "04_컬럼계보매핑.md", "04_컬럼계보매핑.xlsx",
    "05_지표GOLD매핑.csv", "05_지표GOLD매핑.md", "05_지표GOLD매핑.xlsx",
    "06_BRONZE노출감사.csv", "06_BRONZE노출감사.md", "06_BRONZE노출감사.xlsx",
    "07_코드체계_관문측정.md",
    "08_SILVER→GOLD_보존율.csv", "08_SILVER→GOLD_보존율.md",
    "09_보고서필드_조립가능성.csv", "09_보고서필드_조립가능성.md", "09_섹션배너.json",
]
# 측정일을 헤더에서 읽을 수 있는 산출물. 🔴 키 이름이 파일마다 다르다(실측):
#   `measured:`(04·05·07·08·09) · `audit_date:`(06) · `updated:`(01 수기) · JSON `"generated"`(03)
MEASURED_KEYS = ["01_DW_현업활용가이드.md", "03_GN_DW_개념도.html",
                 "04_컬럼계보매핑.md", "05_지표GOLD매핑.md", "06_BRONZE노출감사.md",
                 "07_코드체계_관문측정.md", "08_SILVER→GOLD_보존율.md",
                 "09_보고서필드_조립가능성.md"]
DATE_RE = re.compile(r'(?:measured|audit_date|updated|"generated")\s*[:=]?\s*"?\s*(\d{4}-\d{2}-\d{2})')


def artifact_measured(path):
    """산출물 헤더의 측정일을 읽는다. 없거나 파일이 없으면 None(= 골든 대조에서 드러난다)."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as f:
        head = f.read(4000)          # 헤더 블록만 본다(본문의 과거 측정일 인용에 걸리지 않도록)
    mt = DATE_RE.search(head)
    return mt.group(1) if mt else None


def schema_fingerprint():
    """GOLD·SILVER 컬럼 목록의 지문. 스키마가 바뀌면 산출물은 stale 이다.

    🔴 왜 「파일 존재」가 아니라 지문인가: O64 는 인벤토리 파일이 **있는데도** A4 로 6컬럼이 바뀌어
       stale 이 된 것을 겪었다. 존재 검사로는 그 상태를 구별할 수 없다.
    ⚠️ DB 를 직접 조회하지 않는다 — `/tmp/schema.json`(dump_schema.py 산출)이 있을 때만 계산하고,
       없으면 None 을 돌려 **「미측정」으로 보고**한다(없는 것을 통과로 만들지 않는다).
    """
    p = os.environ.get("GN_DW_SCHEMA", "/tmp/schema.json")
    if not os.path.exists(p):
        return None
    s = json.load(open(p, encoding="utf-8"))
    payload = json.dumps({
        "gold": {k: v for k, v in sorted(s.get("gold_cols", {}).items())},
        "silver": {k: v for k, v in sorted(s.get("silver_cols", {}).items())},
        "views": sorted(s.get("views", [])),
        "tables": sorted(s.get("tables", [])),
    }, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def measure():
    """산출물에서 골든 지표를 측정한다. 골든 생성과 대조가 **같은 코드**를 쓴다."""
    m = {}
    # 09 — 조립가능성
    def _09():
        _, r09 = load_09()
        m["09.rows"] = len(r09)
        m["09.verdicts"] = dict(collections.Counter(r["조립가능도"] for r in r09))
        m["09.verdict_kinds"] = len(m["09.verdicts"])
        m["09.tie_rows"] = sum(1 for r in r09 if r["앵커_경합"])
        m["09.tie_sections"] = sorted({f'{r["보고서"]} | {r["섹션"]} | {r["앵커_경합"]}'
                                       for r in r09 if r["앵커_경합"]})
        m["09.anchors"] = dict(collections.Counter(r["앵커_팩트"] for r in r09))
        # 🔴 [O48-B 자기검토] **앵커별 카운트만으로는 O47-B 를 잡지 못한다.** 실측으로 확인했다:
        #   행수가 같은 두 섹션의 앵커를 **서로 교환**하면 카운트가 완전히 보존되어 골든 23지표가
        #   전부 통과했다. 그런데 O47-B 사고의 형태가 바로 **「섹션의 앵커가 뒤집힌다」** 이므로
        #   골든이 정작 그 사고를 놓치고 있었다. ⇒ **섹션 → (앵커, 경합) 매핑을 전량** 고정한다.
        #   29섹션이라 크기도 문제되지 않는다. 카운트는 요약으로 함께 남긴다.
        m["09.section_anchor"] = {f'{r["보고서"]} | {r["섹션"]}':
                                 f'{r["앵커_팩트"]} | {r["앵커_경합"]}' for r in r09}
        m["09.sv_prefix_rows"] = sum(1 for r in r09 if r["GOLD_매핑"].startswith("SV metric"))
        m["09.evidence_violations"] = sorted(
            f'{r["보고서"]}|{r["섹션"]}|{r["필드값"]}'
            for r in r09
            if (r["조립가능도"] in BLOCKING_VERDICTS or r["앵커_경합"])
            and not IDENT_IN_EVIDENCE.search(r["판정_근거(실측)"]))
    _guard(m, "09", _09)

    # 05 — 지표 GOLD 매핑
    def _05():
        s05 = read_csv_sections(os.path.join(OUT, "05_지표GOLD매핑.csv"))
        k_metric = next(k for k in s05 if k.startswith("## 지표 → GOLD"))
        d05 = dicts(s05[k_metric])
        m["05.metric_rows"] = len(d05)
        m["05.status"] = dict(collections.Counter(r["상태"] for r in d05))
        m["05.sv_bound_rows"] = sum(1 for r in d05 if r["GOLD_배속"] == "SV")
        m["05.field_sections"] = {k: len(v) - 1 for k, v in s05.items() if "보고서필드" in k}
    _guard(m, "05", _05)

    # 04 · 06 · 08 — 행수와 판정 분포
    def _04():
        r04 = list(csv.DictReader(open(os.path.join(OUT, "04_컬럼계보매핑.csv"), encoding="utf-8-sig")))
        m["04.rows"] = len(r04)
    _guard(m, "04", _04)

    def _06():
        s06 = read_csv_sections(os.path.join(OUT, "06_BRONZE노출감사.csv"))
        d06 = dicts(next(iter(s06.values())))
        m["06.rows"] = len(d06)
        m["06.verdicts"] = dict(collections.Counter(r["판정"] for r in d06))
    _guard(m, "06", _06)

    def _08():
        r08 = list(csv.DictReader(open(os.path.join(OUT, "08_SILVER→GOLD_보존율.csv"), encoding="utf-8-sig")))
        m["08.rows"] = len(r08)
        m["08.status"] = dict(collections.Counter(r["STATUS"] for r in r08))
    _guard(m, "08", _08)

    # 07 — md 전용. 존재·생성기 표기만 확인(수치는 md 본문 파싱이 취약해 골든에 넣지 않는다).
    p07 = os.path.join(OUT, "07_코드체계_관문측정.md")
    m["07.exists"] = os.path.exists(p07)

    # ── 산출물 축 (2026-08-13 O65 신설) ──────────────────────────────────────
    # 🔴 왜 신설하는가: O59-T 가 구 판본을 아카이브로 옮기고 4종만 재생성했을 때,
    #   `06`~`09` 부재를 이 게이트는 **골든 대조 실패로만** 드러냈다(계산이 뒤달려 원인이 묻혔다).
    #   더 나쁜 것은 **부재를 못 잡는 파일이 있었다**는 점이다 — md·xlsx·`09_섹션배너.json`·`07` 은
    #   measure() 가 읽지 않으므로 **사라져도 게이트가 통과**한다. ⇒ 기대 목록을 명시 고정한다.
    # 🔴 그리고 「파일이 있다」는 **신선하다는 뜻이 아니다**(O64 가 인벤토리에서 같은 것을 겪었다).
    #   산출물별 측정일을 골든에 박아 **판본 혼재가 드러나게** 한다 — 종전 골든은 최상위
    #   `measured` 1개뿐이라 `04`(08-11) 와 `09`(08-13) 가 한 날짜로 뭉개졌다.
    m["art.files"] = {rel: os.path.exists(os.path.join(OUT, rel)) for rel in MANIFEST}
    m["art.measured"] = {rel: artifact_measured(os.path.join(OUT, rel)) for rel in MEASURED_KEYS}

    # 결손·파싱 실패는 **골든 차이가 아니라 그 자체로 불합격**이다(골든에 넣으면 「결손이 정상」이 된다).
    m["_read_errors"] = sorted(m.get("_read_errors", []))

    # 라벨 사전 — P98 회귀 감시 지표. 산출물이 아니라 **생성기 입력 문서**의 상태다.
    try:
        import gen_metric_gold_mapping as GMM
        idx, ents = GMM.load_gold_inventory()
        # 🆕 🔴🔴 [2026-08-28 O111-B] **카운트 대신 키 목록을 저장한다.**
        #   왜: O111 착수 시점에 이 세 지표가 골든과 **+3** 씩 달랐는데, 골든이 **개수만**
        #   담고 있어 「어느 3건인가」를 귀속할 수 없었다(`_archive` 에 그 문서의 이전 판본도
        #   없다) ⇒ `--update-golden` 의 전제 조건인 **「차이를 전량 규명」이 원리적으로 불가**했다.
        #   🟢 `diff()` 는 이미 리스트를 **원소 단위로 열거**하므로, 목록으로 저장하면
        #   다음 차이는 그 자리에서 「무엇이 늘고 무엇이 사라졌는가」로 나온다.
        #   ⚠️ 개수도 함께 남긴다(사람이 읽는 요약 · 회귀 비교의 빠른 축).
        ent_keys = sorted('%s.%s' % (e['table'], e['col']) for e in ents)
        m["inv.entries"] = len(ents)
        m["inv.entry_keys"] = ent_keys
        m["inv.index_keys"] = len(idx)
        m["inv.index_key_list"] = sorted(idx)
        m["inv.unreachable"] = sorted({f'{e["table"]}.{e["col"]}' for e in ents
                                       if e["label"][:1] in MARKERS_STATUS
                                       or EDIT_MARKER.match(e["label"])})
        desc = sorted({f'{e["table"]}.{e["col"]}' for e in ents
                       if len(e["label"]) > 40 or "**" in e["label"]
                       or "←" in e["label"]})
        m["inv.desc_cells"] = len(desc)
        m["inv.desc_cell_list"] = desc
        per = collections.defaultdict(set)
        for e in ents:
            per[e["label_norm"]].add(f'{e["table"]}.{e["col"]}')
        m["inv.label_collisions"] = sum(1 for v in per.values() if len(v) > 1)
    except Exception as e:
        m["inv.error"] = str(e)
    return m


# ── G. 골든 대조 ───────────────────────────────────────────────────────────
def diff(name, want, got, path=""):
    """차이를 전량 열거한다 — 개수만 보고 갱신하면 검증이 아니다."""
    out = []
    if isinstance(want, dict) and isinstance(got, dict):
        for k in sorted(set(want) | set(got)):
            out += diff(name, want.get(k), got.get(k), f"{path}.{k}" if path else str(k))
    elif isinstance(want, list) and isinstance(got, list):
        for x in sorted(set(map(str, want)) - set(map(str, got))):
            out.append(f"{path}: 골든에만 있음 → {x}")
        for x in sorted(set(map(str, got)) - set(map(str, want))):
            out.append(f"{path}: 산출물에만 있음 → {x}")
    elif want != got:
        out.append(f"{path}: 골든 {want!r} ≠ 산출물 {got!r}")
    return out


def test_golden():
    print("[G] 골든 대조 — 30_output_share/{04,05,06,08,09} + 산출물별 측정일·기대목록")
    got = measure()
    # 🔴 결손·파싱 실패는 **골든 대조와 별개의 독립 불합격**이다. 골든에 담으면 「결손이 정상」이 된다.
    if got.get("_read_errors"):
        bad("G.artifacts-readable", f'산출물 {len(got["_read_errors"])}종을 읽을 수 없다')
        for e in got["_read_errors"]:
            print("          · " + e)
    else:
        ok("G.artifacts-readable", "산출물 5종 전부 읽힘")
    if not os.path.exists(GOLDEN):
        bad("G.golden-exists", f"골든이 없다: {GOLDEN} — --update-golden 으로 최초 생성할 것")
        return
    g = json.load(open(GOLDEN, encoding="utf-8"))
    d = diff("G", g["metrics"], got)
    if d:
        bad("G.golden-match", f"{len(d)}건 차이 (골든 측정일 {g.get('measured')})")
        for line in d[:40]:
            print("          · " + line)
        if len(d) > 40:
            print(f"          · … 외 {len(d) - 40}건")
        print("          ⇒ 🔴 차이를 **전량 규명**한 뒤 --update-golden. 규명 없이 갱신하면 골든이 무의미하다.")
    else:
        ok("G.golden-match", f"{len(got)}개 지표 일치 (골든 {g.get('measured')})")


# ── T5. 산출물 축 — 기대 목록·측정일·신선도 (2026-08-13 O65 신설) ─────────────
def test_artifact_axis():
    print("[T5] 산출물 축 — 기대 목록 · 측정일 · 신선도 (O65)")
    missing = [rel for rel in MANIFEST if not os.path.exists(os.path.join(OUT, rel))]
    if missing:
        bad("T5.manifest", f"기대 산출물 {len(missing)}/{len(MANIFEST)}종 부재 — {', '.join(missing)}")
    else:
        ok("T5.manifest", f"기대 산출물 {len(MANIFEST)}종 전부 존재(`02` 는 수기·아카이브 전용으로 의도적 제외)")

    # 측정일 — 파싱 실패는 그 자체로 불합격이다(헤더 규약이 깨진 것이므로).
    dates = {rel: artifact_measured(os.path.join(OUT, rel)) for rel in MEASURED_KEYS}
    nod = [k for k, v in dates.items() if v is None]
    if nod:
        bad("T5.measured-parsable", f"측정일 헤더를 읽을 수 없는 산출물 {len(nod)}종 — {', '.join(nod)}")
    else:
        uniq = sorted(set(dates.values()))
        msg = f"{len(dates)}종 전부 측정일 보유 · 판본 {len(uniq)}종({' · '.join(uniq)})"
        if len(uniq) > 1:
            msg += " ⚠️ 혼재 — 인용 시 산출물별 측정일을 밝힐 것"
        ok("T5.measured-parsable", msg)

    # 신선도 — 스키마 지문이 골든과 다르면 산출물이 stale 이다.
    fp = schema_fingerprint()
    g = json.load(open(GOLDEN, encoding="utf-8")) if os.path.exists(GOLDEN) else {}
    want = g.get("schema_fingerprint")
    if fp is None:
        ok("T5.freshness", "⚪ 미측정 — `/tmp/schema.json` 없음(먼저 `dump_schema.py`). "
                           "🔴 미측정을 통과로 읽지 말 것")
    elif want is None:
        bad("T5.freshness", f"골든에 스키마 지문이 없다(현재 {fp}) — 산출물 재생성 후 --update-golden")
    elif fp != want:
        bad("T5.freshness", f"스키마가 바뀌었다(골든 {want} ≠ 현재 {fp}) ⇒ 산출물 06~09 는 **stale** "
                            "— 재생성 후 차이를 규명하고 --update-golden")
    else:
        ok("T5.freshness", f"스키마 지문 일치({fp}) — 산출물이 현행 스키마 기준이다")


# ── T1. 앵커 동점 순서 독립 (O47-B) ─────────────────────────────────────────
def test_anchor_order():
    print("[T1] 앵커 동점 — 삽입 순서 독립 (O47-B)")
    try:
        import gen_section_assembly as GSA
    except Exception as e:
        bad("T1.import", f"gen_section_assembly import 실패: {e}")
        return
    if not hasattr(GSA, "pick_anchor"):
        bad("T1.contract", "pick_anchor() 가 없다 — 앵커 선정이 다시 main() 안으로 인라인됐다(테스트 불가 상태)")
        return

    # ⓐ 실제 사고 재현 — 3-7 좌측의 3파 동점(FMM:2 / FGA:2 / FSE:2).
    tie3 = {"FACT_MEMBER_MONTHLY": 2, "FACT_GA_BEHAVIOR": 2, "FACT_SERVICE_EVENT": 2}
    base = GSA.pick_anchor(collections.Counter(tie3))
    keys = list(tie3)
    rnd = random.Random(20260807)
    for i in range(200):
        rnd.shuffle(keys)
        c = collections.Counter()
        for k in keys:                      # 삽입 순서를 매번 바꾼다
            c[k] = tie3[k]
        if GSA.pick_anchor(c) != base:
            bad("T1.tie-deterministic",
                f"삽입 순서 {keys} 에서 결과가 달라졌다: {GSA.pick_anchor(c)} ≠ {base}")
            return
    if not base[1]:
        bad("T1.tie-exposed", f"3파 동점인데 경합이 노출되지 않았다: {base}")
        return
    if base[1].count("/") != 2:
        bad("T1.tie-exposed", f"경합 팩트 수가 3이어야 한다: {base[1]!r}")
        return
    ok("T1.tie-deterministic", f"200회 순서 셔플 동일 · 경합 노출 {base[1]}")

    # 비동점은 최다 hit 를 고르고 경합을 노출하지 않는다.
    a, t = GSA.pick_anchor(collections.Counter({"FACT_B": 1, "FACT_A": 3}))
    if (a, t) != ("FACT_A", ""):
        bad("T1.clear-winner", f"비동점 선정이 틀렸다: {(a, t)}")
    else:
        ok("T1.clear-winner", "비동점 = 최다 hit · 경합 미노출")

    # 🔴 산출물 대조 — 실제 09 에서 경합 섹션의 모든 행이 같은 앵커·같은 경합 라벨을 갖는가.
    #   섹션 내에서 앵커가 갈리면 앵커 산정이 행 단위로 새고 있다는 뜻이다.
    r09 = load_09_safe("T1.section-uniform")
    if r09 is None:
        return
    bysec = collections.defaultdict(set)
    for r in r09:
        bysec[(r["보고서"], r["섹션"])].add((r["앵커_팩트"], r["앵커_경합"]))
    split = {k: v for k, v in bysec.items() if len(v) > 1}
    if split:
        bad("T1.section-uniform", f"섹션 내 앵커 불일치 {len(split)}건: {list(split)[:3]}")
    else:
        ok("T1.section-uniform", f"{len(bysec)}섹션 전부 앵커 단일")


# ── T2. 라벨 사전 오염 (P98) ────────────────────────────────────────────────
def test_label_dict():
    print("[T2] 라벨 사전 — 수기 문서 주석 오염 (P98)")
    try:
        import gen_metric_gold_mapping as GMM
    except Exception as e:
        bad("T2.import", f"gen_metric_gold_mapping import 실패: {e}")
        return

    # ⓐ 가드 단위 검사 — 상태 마커로 시작하는 주석 셀은 라벨이 아니다.
    poison = [
        "🔴 **DEV 브랜치 전용**(실측 1,010,680) · **STOP 전건 0**",
        "⚠️ 재검토 예정 — O47",
        "✅ 배선 완료(2026-08-07)",
        "⛔ 불가 — 원천 부재",
        "◐ 사전집계 필요",
        "🆕 신규 축",
        "▸ 부기",
    ]
    leaked = [s for s in poison if GMM._inv_label(s)]
    if leaked:
        bad("T2.marker-guard", f"주석이 라벨로 통과했다 {len(leaked)}건: {leaked}")
    else:
        ok("T2.marker-guard", f"상태 마커 주석 {len(poison)}종 전부 라벨 아님")

    # 정상 라벨은 계속 통과해야 한다 — 가드가 과잉이면 매핑이 조용히 줄어든다.
    for s, want in [("개발(건) SUM(금액)/10000 (#4·5)", "개발(건)"),
                    ("납입회비(원) (#69·70 단일화)", "납입회비(원)")]:
        got = GMM._inv_label(s)
        if got != want:
            bad("T2.normal-label", f"정상 라벨이 깨졌다: {s!r} → {got!r} (기대 {want!r})")
            break
    else:
        ok("T2.normal-label", "정상 라벨 파싱 유지")

    # ⓑ 실제 정본 문서로 색인 — 쓰레기 라벨 0건이어야 한다.
    if not os.path.exists(DOC_INV):
        bad("T2.inventory", f"정본 인벤토리가 없다: {DOC_INV}")
        return
    try:
        idx, entries = GMM.load_gold_inventory()
    except Exception as e:
        bad("T2.inventory", f"load_gold_inventory 실패: {e}")
        return

    # 🔴 하드 실패 = **P98 계열 2종**. 둘 다 「도달할 수 없는 색인 키」를 만든다.
    #   ① 상태 마커로 시작 — 주석 셀을 라벨로 색인
    #   ② 편집 마커 접두 잔존(`**[2026-08-03 O25 신설]** …`) — `_norm` 이 날짜·이슈번호를 남겨
    #      색인 키가 `20260803o25신설중단사유명` 이 된다(실측 14건 · O48 에서 교정)
    hard = sorted({f'{e["table"]}.{e["col"]} = {e["label"][:48]!r}' for e in entries
                   if e["label"][:1] in MARKERS_STATUS or EDIT_MARKER.match(e["label"])})
    if hard:
        bad("T2.no-unreachable-label", f"도달 불가 색인 키 {len(hard)}건: {hard[:5]}")
    else:
        ok("T2.no-unreachable-label", f"엔트리 {len(entries)} · 색인 {len(idx)} · 도달불가 0건")

    # 🔵 골든 고정 = **설명 셀**(라벨이 아니라 서술이 들어온 칸). 파서가 더 잘할 수 없는
    #   부분이고 기존부터 있던 큐레이션 부채다 → 하드 실패로 두지 않고 **수를 얼어붙힌다**.
    #   늘어나면 인벤토리 편집이 설명 칸 계약을 더 깨뜨렸다는 뜻이므로 골든 대조가 잡는다.
    desc_cells = sorted({f'{e["table"]}.{e["col"]}' for e in entries
                         if len(e["label"]) > 40 or "**" in e["label"] or "←" in e["label"]})
    ok("T2.desc-cells-frozen", f"설명 셀(라벨 아님) {len(desc_cells)}건 — 골든이 이 수를 고정한다")

    # ⓒ first-wins 충돌 — `setdefault` 는 문서 순서에 판정을 의존시킨다(P98-③).
    #   충돌 자체는 정상일 수 있으나 **선점된 쪽이 무엇인지 보이지 않으면** 사고가 조용해진다.
    per = collections.defaultdict(list)
    for e in entries:
        per[e["label_norm"]].append(f'{e["table"]}.{e["col"]}')
    collide = {k: v for k, v in per.items() if len(set(v)) > 1}
    ok("T2.first-wins-visible",
       f"라벨 충돌 {len(collide)}건 (색인은 문서 순서 first-wins — 골든이 이 수를 고정한다)")
    return len(collide)


# ── T3. 생성기 간 문자열 계약 (P92 · O46 §3-①) ──────────────────────────────
def test_string_contract():
    print("[T3] 문자열 계약 — 'SV metric' 접두 (P92)")
    try:
        import gen_section_assembly as GSA
    except Exception as e:
        bad("T3.import", f"import 실패: {e}")
        return
    pref = getattr(GSA, "SV_METRIC_PREFIX", None)
    if not pref:
        bad("T3.constant", "SV_METRIC_PREFIX 상수가 없다 — 계약이 리터럴로 흩어져 있으면 한쪽만 바뀐다")
        return
    ok("T3.constant", f"SV_METRIC_PREFIX = {pref!r}")

    # ① 소비자(09 검사기)가 그 상수로 판정하는가 — 리터럴로 되돌아가면 계약이 깨진다.
    src_gsa = open(GSA.__file__, encoding="utf-8").read()
    if "gmap.startswith(SV_METRIC_PREFIX)" not in src_gsa:
        bad("T3.consumer-uses-constant", "judge() 가 SV_METRIC_PREFIX 를 쓰지 않는다(리터럴 복귀)")
    else:
        ok("T3.consumer-uses-constant", "judge() 가 상수로 판정")

    # ② 생산자(05 생성기) 소스가 그 접두로 문자열을 만드는가.
    src_gmm = open(GEN_METRIC, encoding="utf-8").read()
    n_emit = len(re.findall(r'"' + re.escape(pref), src_gmm))
    if n_emit == 0:
        bad("T3.producer-emits", f"05 생성기 소스에 {pref!r} 로 시작하는 문자열이 없다 — 접두가 개명됐다")
    else:
        ok("T3.producer-emits", f"05 생성기 emit {n_emit}곳")

    # ③ 05 산출물 — GOLD_배속 == 'SV' ⟺ 매핑이 접두로 시작.
    s05 = read_csv_sections(os.path.join(OUT, "05_지표GOLD매핑.csv"))
    d05 = dicts(s05[next(k for k in s05 if k.startswith("## 지표 → GOLD"))])
    mism = [r["지표#"] for r in d05
            if (r["GOLD_배속"] == "SV") != r["GOLD_매핑(물리컬럼/SV base)"].startswith(pref)]
    if mism:
        bad("T3.artifact-05", f"배속 SV ⟺ 접두 불일치 {len(mism)}건: {mism[:8]}")
    else:
        ok("T3.artifact-05", f"지표 {len(d05)}행 · 배속 SV ⟺ 접두 완전 일치")

    # ④ 09 산출물 — 접두 ⟺ 판정 '판정불가(SV파생)'. 이것이 O46 에서 무너진 지점이다.
    r09 = load_09_safe("T3.artifact-09")
    if r09 is None:
        return
    mism2 = [f'{r["섹션"]}|{r["필드값"]}' for r in r09
             if r["GOLD_매핑"].startswith(pref) != (r["조립가능도"] == "판정불가(SV파생)")]
    if mism2:
        bad("T3.artifact-09", f"접두 ⟺ SV파생 판정 불일치 {len(mism2)}건: {mism2[:5]}")
    else:
        ok("T3.artifact-09", f"{len(r09)}행 접두 ⟺ SV파생 완전 일치")


# ── T4. 절차 강제 — P97·P100 기계 검사 ──────────────────────────────────────
def test_evidence_discipline():
    print("[T4] 절차 강제 — 불가·경합 근거에 식별자 열거 (P97·P100)")
    r09 = load_09_safe("T4.evidence-has-identifier")
    if r09 is None:
        return
    target = [r for r in r09 if r["조립가능도"] in BLOCKING_VERDICTS or r["앵커_경합"]]
    viol = [r for r in target if not IDENT_IN_EVIDENCE.search(r["판정_근거(실측)"])]
    if viol:
        bad("T4.evidence-has-identifier",
            f"대상 {len(target)}행 중 {len(viol)}행이 식별자 없이 서사만 적었다")
        for r in viol[:10]:
            print(f"          · {r['섹션'][:24]} | {r['필드값'][:20]} | {r['조립가능도']} "
                  f"| {r['판정_근거(실측)'][:70]}")
    else:
        ok("T4.evidence-has-identifier", f"불가·경합 {len(target)}행 전부 식별자 열거")

    # 경합 행은 경합 팩트를 **둘 이상** 명시해야 한다 — 한쪽만 적으면 P100 재발이다.
    ties = [r for r in r09 if r["앵커_경합"]]
    short = [r for r in ties
             if not all(f.strip() in r["판정_근거(실측)"] for f in r["앵커_경합"].split("/"))]
    if short:
        bad("T4.tie-lists-all-facts", f"경합 {len(ties)}행 중 {len(short)}행이 경합 팩트를 전부 적지 않았다")
    else:
        ok("T4.tie-lists-all-facts", f"경합 {len(ties)}행 전부 경합 팩트 전량 명시")

    # 「집계필요」는 처방(사전집계 대상)을 적어야 한다 — 판정만 있고 처방이 없으면 §2-C 재발.
    agg = [r for r in r09 if r["조립가능도"] == "집계필요"]
    noscript = [r for r in agg if "집계" not in r["판정_근거(실측)"]]
    if noscript:
        bad("T4.agg-has-prescription", f"집계필요 {len(agg)}행 중 {len(noscript)}행에 처방 서술 없음")
    else:
        ok("T4.agg-has-prescription", f"집계필요 {len(agg)}행 전부 처방 서술 있음")


# ── 자기검증 — 일부러 깨뜨려 테스트가 실패하는지 확인 ─────────────────────────
# 🔴 [O48-B 자기검토] 종전 self-check 는 **생성기 3종만** 깨뜨렸다. 그래서 「골든이 산출물 변형을
#   실제로 잡는가」와 「T4 가 근거 훼손을 잡는가」는 검증되지 않은 채 남았고, 그 틈에서 **실제 결함
#   2건이 나왔다**(D8 개수 보존 앵커 교환을 골든이 놓침 · D1 산출물 결손 시 크래시).
#   ⇒ **산출물 변형 3종을 추가**해 5종으로 늘린다. 산출물은 `/tmp` 사본을 변형하므로 정본은 무해.
def _mutated_out(mutate):
    """OUT 사본을 /tmp 에 만들고 09 CSV 를 mutate(rows) 로 변형한 뒤 그 디렉터리를 돌려준다."""
    import shutil
    import tempfile
    d = tempfile.mkdtemp(prefix="gn_dw_selfcheck_")
    for f in os.listdir(OUT):
        src = os.path.join(OUT, f)
        if os.path.isfile(src):
            shutil.copy2(src, d)
    p = os.path.join(d, "09_보고서필드_조립가능성.csv")
    rows = list(csv.DictReader(open(p, encoding="utf-8-sig")))
    hdr = list(rows[0].keys())
    mutate(rows)
    w = csv.DictWriter(open(p, "w", encoding="utf-8", newline=""), fieldnames=hdr)
    w.writeheader()
    w.writerows(rows)
    return d


def _swap_two_section_anchors(rows):
    """행수가 같은 두 섹션의 앵커를 **서로 교환** — 앵커별 카운트가 완전히 보존된다(D8 재현)."""
    bysec = collections.defaultdict(list)
    for r in rows:
        bysec[(r["보고서"], r["섹션"])].append(r)
    sizes = collections.defaultdict(list)
    for k, v in bysec.items():
        sizes[len(v)].append(k)
    for _n, ks in sorted(sizes.items()):
        per = {}
        for k in ks:
            per.setdefault(bysec[k][0]["앵커_팩트"], []).append(k)
        anc = [a for a in sorted(per) if a and a != "—"]
        if len(anc) >= 2:
            ka, kb = per[anc[0]][0], per[anc[1]][0]
            for r in bysec[ka]:
                r["앵커_팩트"] = anc[1]
            for r in bysec[kb]:
                r["앵커_팩트"] = anc[0]
            return f"{ka[1][:18]} ↔ {kb[1][:18]} ({anc[0]} ↔ {anc[1]})"
    return "교환 대상 없음"


def _strip_evidence_identifiers(rows):
    """차단 판정 3행의 근거에서 식별자를 지워 **서사만** 남긴다(P97·P100 위반 재현)."""
    n = 0
    for r in rows:
        if r["조립가능도"] == "도달불가" and n < 3:
            r["판정_근거(실측)"] = "차원으로 가는 경로가 없어 이 필드는 얻을 수 없다"
            n += 1
    return f"{n}행 근거 훼손"


def _run_isolated(fn, out_dir=None):
    """FAIL 을 비운 뒤 fn 을 돌리고 실패 여부를 돌려준다. out_dir 이 있으면 OUT 을 임시 교체."""
    global FAIL, PASSED, OUT
    keep = OUT
    if out_dir:
        OUT = out_dir
    FAIL, PASSED = [], []
    try:
        fn()
    finally:
        OUT = keep
    return bool(FAIL)


def self_check():
    """🔴 테스트가 통과만 하면 검증이 아니다. 생성기 3종 + 산출물 5종을 실제로 깨뜨려 본다."""
    print("=" * 78)
    print("[SELF] 일부러 깨뜨려 테스트가 실패하는지 확인 — 8종(O65 에서 산출물 축 2종 추가)")
    print("=" * 78)
    import gen_section_assembly as GSA
    import gen_metric_gold_mapping as GMM
    results = []

    # ⓐ 앵커 동점 — 삽입 순서 의존(`Counter.most_common`)으로 되돌린다.
    orig = GSA.pick_anchor
    GSA.pick_anchor = lambda hit: (collections.Counter(hit).most_common(1)[0][0] if hit else None, "")
    global FAIL, PASSED
    FAIL, PASSED = [], []
    test_anchor_order()
    results.append(("ⓐ 앵커 동점 → most_common 복귀", bool(FAIL)))
    GSA.pick_anchor = orig

    # ⓑ 라벨 사전 — 상태 마커 가드를 제거한다.
    orig2 = GMM._inv_label
    GMM._inv_label = lambda desc: re.split(GMM.INV_DELIMS, re.sub(r"\([^()]*#[^()]*\)", "", desc or ""))[0].strip(" .·")
    FAIL, PASSED = [], []
    test_label_dict()
    results.append(("ⓑ 라벨 사전 → 마커 가드 제거", bool(FAIL)))
    GMM._inv_label = orig2

    # ⓒ 문자열 계약 — 접두 상수를 개명한다.
    orig3 = GSA.SV_METRIC_PREFIX
    GSA.SV_METRIC_PREFIX = "SV 지표"
    FAIL, PASSED = [], []
    test_string_contract()
    results.append(("ⓒ 문자열 계약 → 접두 개명", bool(FAIL)))
    GSA.SV_METRIC_PREFIX = orig3

    # ── 산출물 변형 — 골든·T4 가 정말 잡는지 (O48-B 에서 추가) ──
    # ⓓ 🔴 개수 보존 앵커 교환. 종전 골든(앵커별 카운트)은 이것을 **놓쳤다** — D8 이 이 항목의 존재 이유다.
    d = _mutated_out(_swap_two_section_anchors)
    detail = _swap_two_section_anchors.__doc__.split("—")[0].strip()
    results.append((f"ⓓ 산출물 → 섹션 앵커 개수 보존 교환 ({detail})",
                    _run_isolated(test_golden, d)))

    # ⓔ 근거에서 식별자 제거 — T4(P97·P100) 가 서사만 남은 행을 잡는지.
    d2 = _mutated_out(_strip_evidence_identifiers)
    results.append(("ⓔ 산출물 → 차단 3행 근거에서 식별자 제거",
                    _run_isolated(test_evidence_discipline, d2)))

    # ⓕ 산출물 1종 결손 — 크래시가 아니라 **판정**으로 나와야 한다(D1).
    import shutil
    d3 = _mutated_out(lambda rows: None)
    os.remove(os.path.join(d3, "08_SILVER→GOLD_보존율.csv"))
    detected = _run_isolated(test_golden, d3)
    results.append(("ⓕ 산출물 1종 결손 → 크래시 없이 판정", detected))

    # ── T5 축 자기검사 (2026-08-13 O65) ──────────────────────────────────────
    # 🔴 ⓖ 는 **종전 사각을 정확히 겨냥한다**: `07` 은 measure() 가 읽지 않으므로 사라져도 골든이
    #   통과했다. 그래서 골든이 아니라 **manifest 축**이 잡는지를 본다.
    d4 = _mutated_out(lambda rows: None)
    # 🔴 음성 샘플 먼저 — 온전한 사본에서 manifest 가 통과해야 「깨서 잡혔다」가 의미를 갖는다(P106).
    clean_ok = not _run_isolated(lambda: test_artifact_axis(), d4)
    os.remove(os.path.join(d4, "07_코드체계_관문측정.md"))
    broke = _run_isolated(lambda: test_artifact_axis(), d4)
    results.append(("ⓖ 산출물 → 골든이 읽지 않는 파일(`07`) 삭제 → manifest 축이 잡는다",
                    broke and clean_ok))

    # ⓗ 신선도 — 스키마가 바뀐 상태를 흉내내 stale 판정이 나오는지 본다.
    orig_fp = globals()["schema_fingerprint"]
    globals()["schema_fingerprint"] = lambda: "deadbeefdeadbeef"
    stale_detected = _run_isolated(lambda: test_artifact_axis())
    globals()["schema_fingerprint"] = orig_fp
    # ⚠️ 골든에 지문이 없으면 이 항목은 「골든에 지문 없음」으로도 FAIL 하므로 구별해 둔다.
    _g = json.load(open(GOLDEN, encoding="utf-8")) if os.path.exists(GOLDEN) else {}
    results.append(("ⓗ 스키마 지문 변경 → stale 판정"
                    + ("" if _g.get("schema_fingerprint") else " ⚠️ 골든에 지문 미기록 상태"),
                    stale_detected))

    for tmp in (d, d2, d3, d4):
        shutil.rmtree(tmp, ignore_errors=True)

    print("-" * 78)
    allgood = True
    for name, detected in results:
        print(f"  {'검출됨 ✅' if detected else '검출 실패 🔴'}  {name}")
        allgood &= detected
    print("-" * 78)
    FAIL, PASSED = ([] if allgood else [("SELF", "깨뜨렸는데 검출하지 못한 항목이 있다")]), []
    return allgood


def update_golden(reason=None, label=None):
    m = measure()
    os.makedirs(os.path.dirname(GOLDEN), exist_ok=True)
    prev = json.load(open(GOLDEN, encoding="utf-8")) if os.path.exists(GOLDEN) else None
    if prev:
        d = diff("G", prev["metrics"], m)
        print(f"골든 갱신 — 차이 {len(d)}건")
        for line in d:
            print("  · " + line)
    from datetime import date
    fp = schema_fingerprint()
    # 🆕 🔴🔴 [2026-08-28 O111-B 자기시정] **지문을 못 구했으면 이전 값을 보전한다.**
    #   종전 구현은 `fp = None` 을 그대로 써서, `/tmp/schema.json` 이 없는 세션이
    #   `--update-golden` 을 돌리면 **살아 있던 지문을 조용히 지웠다**
    #   (`/tmp` 는 세션마다 비워지므로 이것은 예외가 아니라 **기본 상황**이다).
    #   ⇒ 그러면 `T5.freshness` 가 「골든에 스키마 지문이 없다」로 바뀌어 **신선도 검사가 꺼진다**
    #   — 검사가 꺼지는 것은 FAIL 보다 나쁘다(`P106`). 🔴 O111-B 가 실제로 한 번 지웠고
    #   이 가드로 복원했다.
    if fp is None and prev and prev.get("schema_fingerprint"):
        fp = prev["schema_fingerprint"]
        print("  🟢 스키마 지문 보전 — 현재 측정 불가(`/tmp/schema.json` 부재)라 "
              "이전 골든 값(%s)을 유지한다(지우지 않는다)." % fp)
    if fp is None:
        print("  ⚠️ `/tmp/schema.json` 이 없어 **스키마 지문을 기록하지 못했다** — "
              "`dump_schema.py` 를 먼저 돌리고 다시 갱신할 것(지문 없는 골든은 신선도 검사를 못 한다).")
    # 🆕 🔴 [2026-08-28 O111-B] **재발행 사유·라벨·시각을 이력으로 남긴다.**
    #   O109 가 `index_row_gate`·`doc_heading_gate` 골든에는 이 계약을 넣었는데
    #   **이 골든만 빠져 있었다** ⇒ 「정당한 재발행」과 「FAIL 을 덮은 재발행」을
    #   나중에 **구별할 수 없다**(`R1-7-4` 가 막으려는 바로 그 상태).
    import time as _t
    # 🔴 [2026-08-29 O114-B] 라벨 해소를 재구현하지 않는다 — `snapshot_util.resolve_label()` 이
    #   유일한 산식이다(`R3-9 ㉡` 「같은 것을 다르게 재는 지점」 · `index_row_gate` 와 동일 시정).
    import snapshot_util as _snap
    entry = {
        "date": _t.strftime("%Y-%m-%d %H:%M:%S"),
        "label": _snap.resolve_label(label),
        "reason": reason or "(사유 미기재)",
        "diff_count": len(d) if prev else 0,
    }
    hist = (prev.get("history") if prev else None) or []
    json.dump({
        "_doc": "산출물 생성기 회귀 골든. 생성/대조 = scripts/test_generators.py (measure()). "
                "🔴 수기 편집 금지 — 차이를 전량 규명한 뒤 --update-golden 으로 갱신한다. "
                "⚠️ 최상위 `measured` 는 **이 골든을 갱신한 날**이고 산출물의 측정일이 아니다 — "
                "산출물별 측정일은 metrics['art.measured'] 에 있다(판본 혼재가 여기서 드러난다). "
                "🆕 `history` = 재발행 사유 이력(O111-B 신설 · 규명 없는 갱신을 사후 식별하기 위함).",
        "measured": os.environ.get("GN_DW_MEASURED", date.today().isoformat()),
        "schema_fingerprint": fp,
        "history": hist + [entry],
        "metrics": m,
    }, open(GOLDEN, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    print("WROTE:", GOLDEN, f"· 스키마 지문 {fp}")
    print("   발행 이력 = %s · %s · %s" % (entry["date"], entry["label"], entry["reason"]))
    if not reason:
        print("   🟠 `--reason` 미지정 — 다음 세션이 「왜 올렸는지」를 알 수 없다.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--update-golden", action="store_true")
    ap.add_argument("--reason", default=None,
                    help="골든 재발행 사유(권고 · 미지정이면 경고 · O111-B 신설)")
    ap.add_argument("--label", default=None,
                    help="재발행 세션 라벨(생략 시 환경변수 SESSION_LABEL)")
    ap.add_argument("--self-check", action="store_true", help="일부러 깨뜨려 검출 여부 확인(생성기 3종 + 산출물 5종)")
    a = ap.parse_args()
    if a.update_golden:
        update_golden(a.reason, a.label)
        return 0
    if a.self_check:
        return 0 if self_check() else 1

    print("=" * 78)
    print("산출물 생성기 회귀 테스트 — 99_NEXT_SESSION §2-A·§2-B")
    print("=" * 78)
    test_golden()
    test_artifact_axis()
    test_anchor_order()
    test_label_dict()
    test_string_contract()
    test_evidence_discipline()
    print("-" * 78)
    print(f"PASS {len(PASSED)} · FAIL {len(FAIL)}")
    for n, m in FAIL:
        print(f"  🔴 {n} — {m}")
    print("-" * 78)
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
