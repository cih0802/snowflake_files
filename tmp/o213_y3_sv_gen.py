"""O213 Y3 — SV 정본 DDL 에 차원을 덧붙이는 생성기.

입력 = tmp/o213_y3_sv_spec.tsv (sv · alias · col · expose · synonyms(|구분) · comment).
동작 = 정본 파일에서 그 SV 의 DIMENSIONS ( … ) 블록 끝에 항목을 덧붙인다(그 블록 서식 = 한 줄형/여러 줄형 감지).
가드 = ① 같은 노출명 이미 있으면 건너뜀 ② SV 안 동의어 중복이면 그 항목을 쓰지 않고 FAIL 보고 ③ 기본 dry-run.
사용 = python3 o213_y3_sv_gen.py [--apply]
"""
import collections, csv, hashlib, io, re, sys

APPLY = "--apply" in sys.argv
SPEC = "/workspace/tmp/o213_y3_sv_spec.tsv"
FILES = {
    "SV_MEMBER_EVENT": "05_2_SV_DDL_MEMBER_EVENT.sql",
    "SV_MEMBER_COHORT": "05_3_SV_DDL_MEMBER_COHORT.sql",
    "SV_MEMBER_SPONSOR_BIZ": "05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql",
    "SV_MEMBER_MONTHLY": "05_1_SV_DDL_MEMBER_MONTHLY.sql",
    "SV_SERVICE": "05_4_SV_DDL_SERVICE.sql",
    "SV_EVENT_PARTICIPATION": "05_5_SV_DDL_EVENT_PARTICIPATION.sql",
    "SV_RELATION_ACTIVITY": "05_12_SV_DDL_RELATION_ACTIVITY.sql",
    "SV_MEMBER_STATUS_ASOF": "05_17_SV_DDL_MEMBER_STATUS_ASOF.sql",
    "SV_GA_BEHAVIOR": "05_15_SV_DDL_GA_BEHAVIOR.sql",
    "SV_AD": "05_7_SV_DDL_AD.sql",
}
DIR = "/workspace/05_SV-Agent_ai/"


def block_span(t, sv):
    """그 SV CREATE 뒤 첫 'DIMENSIONS (' 의 여는 괄호 ~ 짝 닫는 괄호(따옴표 밖) 위치."""
    m = re.search(r"CREATE OR (?:REPLACE|ALTER) SEMANTIC VIEW GN_DW\.SERVING\." + sv + r"\b", t)
    i = t.index("DIMENSIONS (", m.end()) + len("DIMENSIONS ")
    depth, q, j = 0, False, i
    while j < len(t):
        c = t[j]
        if c == "'":
            q = not q
        elif not q and c == "(":
            depth += 1
        elif not q and c == ")":
            depth -= 1
            if depth == 0:
                return m.start(), i, j
        j += 1
    raise ValueError("unclosed DIMENSIONS for " + sv)


def sv_text(t, sv):
    s = re.search(r"CREATE OR (?:REPLACE|ALTER) SEMANTIC VIEW GN_DW\.SERVING\." + sv + r"\b", t).start()
    nxt = re.search(r"CREATE OR (?:REPLACE|ALTER) SEMANTIC VIEW", t[s + 10:])
    return t[s: s + 10 + nxt.start()] if nxt else t[s:]


def esc(s):
    return s.replace("'", "''")


spec = collections.defaultdict(list)
for r in csv.DictReader(io.open(SPEC, encoding="utf-8"), delimiter="\t"):
    spec[r["sv"]].append(r)

fail = 0
for sv, rows in spec.items():
    path = DIR + FILES[sv]
    t = io.open(path, encoding="utf-8").read()
    before = hashlib.sha256(t.encode()).hexdigest()[:16]
    body = sv_text(t, sv)
    syn_all = set(re.findall(r"'([^']+)'", " ".join(re.findall(r"SYNONYMS\s*=?\s*\(([^)]*)\)", body))))
    # 🔴 SV 문법 = `별칭.차원명 AS 물리식` ⇒ 노출(차원)명은 AS 앞쪽이다(O213 배포 오류로 실측 · 중간 「정정」은 틀렸다)
    exposed = set(x.upper() for x in re.findall(r"\b\w+\.(\w+)\s+AS\s+\w+\.", body, re.I))
    _, a, b = block_span(t, sv)
    inner = t[a + 1:b]
    multiline = bool(re.search(r"\n\s+WITH SYNONYMS", inner))
    ind = re.findall(r"\n(\s+)\w+\.\w+\s+AS\s", inner)
    ind = ind[-1] if ind else "    "
    add = []
    for r in rows:
        name = r["expose"].upper()
        syns = [s for s in r["synonyms"].split("|") if s]
        if name in exposed:
            print(f"  SKIP {sv}.{name} (이미 노출)")
            continue
        clash = [s for s in syns if s in syn_all]
        if clash:
            print(f"  🔴 FAIL {sv}.{name} 동의어 중복 {clash}")
            fail += 1
            continue
        syn_sql = ", ".join("'" + esc(s) + "'" for s in syns)
        head = f"{r['alias']}.{name} AS {r['alias']}.{r['col']}"
        if multiline:
            add.append(f"{ind}{head}\n{ind}  WITH SYNONYMS ({syn_sql})\n{ind}  COMMENT = '{esc(r['comment'])}'")
        else:
            add.append(f"{ind}{head} WITH SYNONYMS ({syn_sql}) COMMENT = '{esc(r['comment'])}'")
        syn_all.update(syns)
        exposed.add(name)
    if not add:
        print(f"{sv}: 추가 0")
        continue
    k = len(inner.rstrip())
    new_inner = inner[:k] + ",\n" + ",\n".join(add) + inner[k:]
    t2 = t[:a + 1] + new_inner + t[b:]
    print(f"{sv}: +{len(add)} ({'여러 줄' if multiline else '한 줄'}형) · {FILES[sv]} sha {before}")
    if APPLY:
        io.open(path, "w", encoding="utf-8").write(t2)
print("FAIL", fail, "· mode =", "APPLY" if APPLY else "DRY-RUN")
sys.exit(1 if fail else 0)
