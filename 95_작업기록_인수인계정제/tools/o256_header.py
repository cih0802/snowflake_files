"""O256 — 원본 SQL 표준 헤더 부착 + clean80 규칙 정제(원본 1회 층).

사용: python3 o256_header.py <측정 csv> [--apply] [--only 접두]
- 기본 = dry-run: tmp/o256/header_plan.csv · tmp/o256/header_sample.md 만 쓴다(원본 무변경).
- --apply: 원본을 쓴다. 파일마다 ① 쓰기 전 2회 해시 동일 ② BAK 복사(있으면 덮지 않음)
           ③ 주석 제거 후 코드 동일 assert ④ 쓴 뒤 되읽기 대조. 순차 쓰기(병렬 금지 · R1-7-2).
- 헤더는 기존 주석 앞에 덧붙인다(서술 근거 문장은 지우지 않는다). 이미 헤더가 있으면 건너뛴다.
- 정제 = clean80.clean 이되 계정 로케이터는 원본에 남긴다(계정 제거는 빌드 훅 층 · build_handoff).
- 대상 = 80 대상 .sql 중 `mstr DDL 원본/` 제외.
"""
import csv, hashlib, io, os, re, shutil, sys, time
T = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, T)
import clean80
from clean80 import strip_comments

W = "/workspace/"
BAK = W + "95_작업기록_인수인계정제/_backup_O256_원본_20261021/"
OUT = W + "tmp/o256/"
MARK = "-- Purpose    :"
BAR = "-- " + "=" * 77


def clean_keep_acct(text):
    """clean80.clean 과 같되 scrub(계정 제거)을 끈다."""
    orig = clean80.scrub
    clean80.scrub = lambda s: s
    try:
        return clean80.clean(text)[0]
    finally:
        clean80.scrub = orig


def run_order_index():
    idx, sec = {}, ""
    for line in open(W + "문서실행순서.md", encoding="utf-8"):
        if line.startswith("# "):
            sec = line[2:].strip()
            continue
        m = re.match(r"^\s*(\d+)\.\s*[^/\n]*?/(\S.*?\.sql)", line)
        if m and sec != "개발계":
            name = "운영계" if sec == "운영계" else "기존 환경 갱신"
            idx.setdefault(m.group(2).strip(), []).append(f"{name} #{m.group(1)}")
    return idx


SEPLINE = re.compile(r"^[-=─━#*·\s]*$")


def purpose(rel, text):
    stem = os.path.splitext(os.path.basename(rel))[0]
    if dbt_kind(rel) == "snapshots":
        src = SRC.findall(text)
        return f"SCD2 이력 스냅샷 — 원천 {src[0][0]}.{src[0][1]}" if src else "SCD2 이력 스냅샷"
    inj = False
    for l in text.split("\n")[:20]:
        s = l.strip()
        if s.startswith("{#"):
            inj = "#}" not in s
        elif inj:
            inj = "#}" not in s
            s = "-- " + s
        if re.match(r"(?i)^use\s+(role|warehouse|schema|database)\b", s):
            continue
        if not (s.startswith("--") or s.startswith("{#")):
            if s and not s.startswith(("/*", "*")):
                break
            continue
        s = re.sub(r"^(--|\{#-?)\s*", "", s).rstrip("#}- ").strip()
        if not s or SEPLINE.match(s) or "Co-authored" in s:
            continue
        s = re.sub(r"^[🟢✅🆕📏🔴🟠🟡⚠️❌👤⬜\s]+", "", s)
        s = re.sub(r"^`?" + re.escape(stem) + r"(\.sql)?`?\s*[:—–-]+\s*", "", s)
        return s[:150] if s else "TBD"
    return "TBD"


CREATE = re.compile(r"(?i)\bcreate\s+(?:or\s+(?:replace|alter)\s+)?(?:secure\s+|transient\s+|temporary\s+)?"
                    r"(table|view|semantic\s+view|dynamic\s+table|task|procedure|function|schema|database|role|"
                    r"warehouse|stage|stream|masking\s+policy|row\s+access\s+policy|alert|agent|cortex\s+search\s+service|"
                    r"notification\s+integration|tag|file\s+format|sequence|user|resource\s+monitor|budget)"
                    r"\s+(?:if\s+not\s+exists\s+)?([A-Za-z0-9_$.\"]+)")
REF = re.compile(r"\{\{\s*ref\(\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}")
SRC = re.compile(r"\{\{\s*source\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}")
FQN = re.compile(r"(?i)\b(?:from|join)\s+(GN_DW\.[A-Za-z0-9_]+\.[A-Za-z0-9_]+)")
ANYFQN = re.compile(r"\b(GN_DW\.(?:BRONZE\w*|SILVER\w*|GOLD\w*|MSTR|SNAPSHOT)\.[A-Za-z0-9_]+)")
NOT_NAME = {"ON", "IN", "TO", "IF", "AS", "FROM"}
ALTER = re.compile(r"(?i)\balter\s+(semantic\s+view|agent|table|view|task|warehouse|user|cortex\s+search\s+service)"
                   r"\s+(?:if\s+exists\s+)?([A-Za-z0-9_$.]+)")
EXEC = re.compile(r"(?i)\bexecute\s+dbt\s+project\s+([A-Za-z0-9_.]+)")
CALL = re.compile(r"(?i)\bcall\s+([A-Za-z0-9_.]+)\s*\(")
ISSUE = re.compile(r"\b(O\d{2,3}(?:-[A-Z])?|DEC-\d+(?:-[A-Z])?|DR-\d+|A8-\d+)\b")


def uniq(xs, n):
    out = []
    for x in xs:
        if x not in out:
            out.append(x)
    return ", ".join(out[:n]) + (f" 외 {len(out) - n}" if len(out) > n else "") if out else "-"


def dbt_kind(rel):
    p = rel.split("/")
    return p[1] if rel.startswith("10_dbt_pipeline/") and len(p) > 2 and p[1] in ("models", "macros", "tests", "snapshots") else None


def header(rel, text, ro):
    stem = os.path.splitext(os.path.basename(rel))[0]
    code = strip_comments(text)
    k = dbt_kind(rel)
    if k == "models":
        layer = rel.split("/")[2].upper()
        target = f"{layer}.{stem} (dbt model)"
    elif k == "macros":
        target = "macro " + uniq(re.findall(r"\{%-?\s*macro\s+(\w+)", text), 4)
    elif k == "tests":
        target = f"dbt singular test {stem} (반환 0행 = PASS)"
    elif k == "snapshots":
        target = "snapshot " + uniq(re.findall(r"\{%-?\s*snapshot\s+(\w+)", text), 3)
    else:
        cr = [(a, b) for a, b in CREATE.findall(code) if b.strip('"').upper() not in NOT_NAME]
        target = uniq([f"{' '.join(a.upper().split())} {b.strip(chr(34))}" for a, b in cr], 4)
        if target == "-":
            alt = [f"{' '.join(a.upper().split())} {b} (변경)" for a, b in ALTER.findall(code)]
            alt += [f"DBT PROJECT {b} (실행)" for b in EXEC.findall(code)]
            alt += [f"PROCEDURE {b} (호출)" for b in CALL.findall(code)]
            target = uniq(alt, 4) if alt else "- (조회·검증 전용 · 객체 생성 없음)"
    if k:
        dep = uniq([f"ref {r}" for r in REF.findall(text)] + [f"source {a}.{b}" for a, b in SRC.findall(text)], 6)
        run = ("dbt build (문서실행순서 dbt 단계)" if k in ("models", "snapshots", "tests")
               else "dbt 가 호출 (직접 실행 없음)")
    else:
        own = {b.strip('"').upper() for _, b in CREATE.findall(code)}
        pool = ANYFQN.findall(code) if "SEMANTIC VIEW" in target else FQN.findall(code)
        dep = uniq([f for f in pool if f.upper() not in own], 6)
        run = " · ".join(ro.get(rel, [])) or "수동 실행 (문서실행순서 미등재)"
    iss = uniq(ISSUE.findall("\n".join(l for l in text.split("\n") if "--" in l or "{#" in l)), 4)
    lines = [BAR, f"{MARK} {purpose(rel, text)}", f"-- Target     : {target}", f"-- Run order  : {run}",
             f"-- Depends on : {dep}", f"-- Issue      : {iss}", BAR]
    return "\n".join(l[:400] for l in lines) + "\n"


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def main():
    apply = "--apply" in sys.argv
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8")))
    rels = sorted({r["rel"] for r in rows if r["rel"].endswith(".sql") and "mstr DDL 원본" not in r["rel"]})
    rels = [r for r in rels if r.startswith(only)]
    ro = run_order_index()
    os.makedirs(OUT, exist_ok=True)
    plan, n_w = [], 0
    for rel in rels:
        p = W + rel
        raw = io.open(p, encoding="utf-8", errors="surrogateescape", newline="").read()
        if MARK in raw[:3000]:
            plan.append((rel, "skip(헤더 있음)", "", "", "", "", "")); continue
        body = clean_keep_acct(raw)
        new = header(rel, raw, ro) + body
        assert strip_comments(new) == strip_comments(raw), ("CODE CHANGED", rel)
        hl = header(rel, raw, ro).split("\n")
        plan.append((rel, "plan", *[x.split(":", 1)[1].strip() for x in hl[1:6]]))
        if not apply or new == raw:
            continue
        h1 = sha(p); time.sleep(0.3); h2 = sha(p)
        assert h1 == h2, ("UNSTABLE", rel)
        b = BAK + rel
        if not os.path.exists(b):
            os.makedirs(os.path.dirname(b), exist_ok=True)
            shutil.copyfile(p, b)
            assert sha(b) == h1, ("BAK", rel)
        io.open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(new)
        assert io.open(p, encoding="utf-8", errors="surrogateescape", newline="").read() == new, ("READBACK", rel)
        n_w += 1
    with open(OUT + "header_plan.csv", "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh); w.writerow(["rel", "status", "Purpose", "Target", "Run order", "Depends on", "Issue"]); w.writerows(plan)
    tbd = [r[0] for r in plan if r[2] == "TBD"]
    notgt = [r[0] for r in plan if r[1] == "plan" and r[3] == "-"]
    print("대상", len(rels), "plan", sum(r[1] == "plan" for r in plan), "skip", sum(r[1] != "plan" for r in plan),
          "Purpose TBD", len(tbd), "Target 없음", len(notgt), "written", n_w)
    for t in tbd:
        print("  TBD", t)


if __name__ == "__main__":
    main()
