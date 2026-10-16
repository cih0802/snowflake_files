# O217 — 비즈니스 정의 코퍼스 생성기 (Cortex Search 원천)
# 입력 = 90_provided_definition/ 의 지표·용어·조직·원천 정의 + tools/O217_routing_curated.csv
# 출력 = 12_agent개선과제/output/O217_biz_definition_corpus.csv
# --apply = GN_DW.SERVING.BIZ_DEFINITION_CORPUS 로 적재(테이블은 미리 만들어 둔다 · 덮어쓰기 = TRUNCATE+INSERT)
# 원칙: 셀 값은 요약·가필하지 않는다(R2-8) · 빈 셀은 빈 값 · 표기용 백틱만 걷어낸다
# Co-authored with CoCo
import argparse
import csv
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "90_provided_definition")
TOOLS = os.path.join(ROOT, "12_agent개선과제", "tools")
OUT = os.path.join(ROOT, "12_agent개선과제", "output", "O217_biz_definition_corpus.csv")
TABLE = "GN_DW.SERVING.BIZ_DEFINITION_CORPUS"
ALL = "MARKETING|MEMBER|EXECUTIVE"
COLS = [
    "DOC_ID", "DOC_TYPE", "TITLE", "SYNONYMS", "DEFINITION", "FORMULA",
    "AGENT_SCOPE", "TOOL_NAME", "SV_FIELD", "LIMITATION", "SOURCE_FILE", "SEARCH_TEXT",
    # 🆕 [O233-B] 맨 끝 추가(COPY 는 위치 기준) — 검색 품질용 파생 열 · 원천 내용 창작 없음
    "KEYWORDS", "IS_ADDITIVE",
    # 🆕 [O235] 맨 끝 추가 — 산식 등록 여부(Y = FORMULA 비어 있지 않음) · 검색 필터 속성
    "HAS_FORMULA",
]

# 🆕 [O233-B] 표기 변형 규칙(질문이 동의어와 조금만 달라도 키워드 색인이 맞도록) — 규칙 기반 · 의미 추가 없음
UNIT_SUFFIX = re.compile(r"\((건|명|%|%p|원|개월|일|회|만원)\)$")
SWAPS = [("율", "률"), ("률", "율"), ("누계", "누적"), ("누적", "누계")]


def variants(term):
    out = set()
    t = term.strip()
    if not t:
        return out
    base = UNIT_SUFFIX.sub("", t).strip()
    for s in {t, base}:
        out.add(s)
        out.add(re.sub(r"[\s·()\[\]/]+", "", s))  # 띄어쓰기·괄호·가운뎃점 제거
    for s in list(out):
        for a, b in SWAPS:
            if a in s:
                out.add(s.replace(a, b))
    return {x for x in out if x}


def keywords(r):
    terms = [r["TITLE"]] + [x for x in re.split(r"[,，]", r["SYNONYMS"]) if x.strip()]
    ks = set()
    for t in terms:
        ks |= variants(t)
    ks -= {r["TITLE"]}
    return " ".join(sorted(ks))


def is_additive(r):
    # 원천 문구에 「비가산」이 명시된 행만 N · 근거 없는 행은 빈 값(창작 금지)
    txt = " ".join([r["DEFINITION"], r["FORMULA"], r["LIMITATION"]])
    return "N" if "비가산" in txt else ""


def clean(s):
    s = (s or "").replace("`", "").strip()
    return re.sub(r"[ \t]+\n", "\n", s)


def rows(name):
    with open(os.path.join(SRC, name), encoding="utf-8-sig", newline="") as f:
        return list(csv.reader(f))


def rec(doc_id, doc_type, title, source, definition="", formula="", limitation="",
        synonyms="", scope=ALL, tool="", sv_field=""):
    return {
        "DOC_ID": doc_id, "DOC_TYPE": doc_type, "TITLE": clean(title),
        "SYNONYMS": clean(synonyms), "DEFINITION": clean(definition),
        "FORMULA": clean(formula), "AGENT_SCOPE": scope, "TOOL_NAME": clean(tool),
        "SV_FIELD": clean(sv_field), "LIMITATION": clean(limitation), "SOURCE_FILE": source,
    }


def common_metrics(out):
    f = "공통지표_flat_20261003.csv"
    seen = set()
    for i, r in enumerate(rows(f)[1:], 2):
        if len(r) < 5 or not r[1].strip().isdigit():
            continue
        n = r[1].strip()
        seen.add(n)
        lim = " · ".join(x for x in [clean(r[5]) and "데이터 출처: " + clean(r[5]),
                                      clean(r[6]) and "합의 필요사항: " + clean(r[6])] if x)
        out.append(rec("MET_CMN-" + n, "지표", r[2], "%s:%d" % (f, i),
                       "[%s] %s" % (clean(r[0]), clean(r[3])), r[4], lim))
    return seen


def new_metrics(out):
    f = "신규지표_20260820.csv"
    rs = rows(f)
    start = next(i for i, r in enumerate(rs) if len(r) > 2 and r[2].strip() == "신규지표")
    seen = set()
    for i, r in enumerate(rs[start + 1:], start + 2):
        if len(r) < 5 or not r[1].strip().isdigit():
            continue
        seen.add(r[1].strip())
        lim = " · ".join(x for x in [clean(r[5]), clean(r[6]) if len(r) > 6 else ""] if x)
        out.append(rec("MET_NEW-" + r[1].strip(), "지표", r[2], "%s:%d" % (f, i),
                       "[%s] %s" % (clean(r[0]), clean(r[3])), r[4], lim))
    return seen


def additional_metrics(out, common_seen, new_seen):
    f = "07_추가_지표사전_20260813기준.md"
    sec = None
    with open(os.path.join(SRC, f), encoding="utf-8") as fh:
        for i, line in enumerate(fh, 1):
            if line.startswith("## 1."):
                sec = "CMN"
            elif line.startswith("## 2."):
                sec = "NEW"
            elif line.startswith("## 3."):
                sec = None
            m = re.match(r"^\| (\d+) \|(.*)\|\s*$", line)
            if not (sec and m):
                continue
            n = m.group(1)
            c = [x.strip().replace("<br>", "\n") for x in m.group(2).split("|")]
            if (sec == "CMN" and n in common_seen) or (sec == "NEW" and n in new_seen):
                continue  # 공통지표_flat(20261003) · 신규지표(20260820) 판본이 우선
            lim = ("데이터 출처: " if sec == "CMN" else "비고: ") + c[4] if c[4] else ""
            out.append(rec("MET_%s-%s" % (sec, n), "지표", c[1], "%s:%d" % (f, i),
                           "[%s] %s" % (c[0], c[2]), c[3], lim))


def terms(out):
    f = "지표용어통합 20260623.csv"
    for i, r in enumerate(rows(f)[1:], 2):
        if len(r) < 3 or not r[1].strip():
            continue
        lim = " · ".join(x for x in ["지표구분: " + clean(r[0]),
                                      clean(r[3]) and "데이터타입: " + clean(r[3]),
                                      clean(r[4]) if len(r) > 4 else ""] if x)
        out.append(rec("TERM-%04d" % (i - 1), "용어", r[1], "%s:%d" % (f, i), r[2], "", lim))


def orgs(out):
    seen = set()
    for f in ["조직도_20260914.csv", "gni_실적부서.csv"]:
        for i, r in enumerate(rows(f)[1:], 2):
            if len(r) < 2 or not r[1].strip() or r[1].strip() in seen:
                continue
            seen.add(r[1].strip())
            out.append(rec("ORG-" + r[1].strip(), "조직", r[0], "%s:%d" % (f, i),
                           "부서 경로: " + clean(r[2]) if len(r) > 2 else "",
                           "", "부서코드: " + r[1].strip()))


def source_refs(out):
    f = "테이블정의 20260629.csv"
    for i, r in enumerate(rows(f)[1:], 2):
        if len(r) < 5 or not r[1].strip():
            continue
        out.append(rec("SRC_TBL-" + r[1].strip(), "원천참고", r[1], "%s:%d" % (f, i),
                       r[4], "", "BRONZE_CRM 원천 테이블 · SQL 식별자로 쓰지 않는다(SV 논리명만 사용)"))
    f = "컬럼정의서 20260714.csv"
    for i, r in enumerate(rows(f)[1:], 2):
        if len(r) < 9 or not r[3].strip():
            continue
        code = clean(r[7]) and " · 코드그룹 " + clean(r[7])
        out.append(rec("SRC_COL-%s-%s.%s" % (r[0].strip(), r[1].strip(), r[3].strip()), "원천참고",
                       "%s (%s.%s)" % (clean(r[8]), r[1].strip(), r[3].strip()),
                       "%s:%d" % (f, i), clean(r[8]) + code, "",
                       "BRONZE_CRM 원천 컬럼 · SQL 식별자로 쓰지 않는다(SV 논리명만 사용)"))
    f = "GA4스키마 20260626.csv"
    for i, r in enumerate(rows(f)[1:], 2):
        if len(r) < 6 or not (r[1].strip() or r[2].strip()):
            continue
        name = ".".join(x for x in [r[1].strip(), r[2].strip()] if x)
        out.append(rec("SRC_GA4-%04d" % (i - 1), "원천참고", "GA4 " + name, "%s:%d" % (f, i),
                       r[5], "", "GA4 BigQuery export 원천 필드 · SQL 식별자로 쓰지 않는다"))


def curated(out):
    f = os.path.join(TOOLS, "O217_routing_curated.csv")
    with open(f, encoding="utf-8-sig", newline="") as fh:
        for r in csv.DictReader(fh):
            out.append(rec(r["DOC_ID"], r["DOC_TYPE"], r["TITLE"], r["SOURCE_FILE"],
                           r["DEFINITION"], r["FORMULA"], r["LIMITATION"],
                           r["SYNONYMS"].replace("|", ", "), r["AGENT_SCOPE"],
                           r["TOOL_NAME"], r["SV_FIELD"]))


def synonym_overlay(out):
    # 🆕 [O233] 동의어 오버레이 — 90_provided_definition 원천에는 SYNONYMS 칸이 없다(R2-8 · 원천 무수정).
    #   tools/O233_synonym_overlay.csv 의 DOC_ID 행에 한해 **빈 SYNONYMS 만** 채운다(덮어쓰기 금지).
    f = os.path.join(TOOLS, "O233_synonym_overlay.csv")
    if not os.path.exists(f):
        return
    by_id = {r["DOC_ID"]: r for r in out}
    with open(f, encoding="utf-8-sig", newline="") as fh:
        for o in csv.DictReader(fh):
            r = by_id.get(o["DOC_ID"])
            if r is None:
                sys.exit("동의어 오버레이 DOC_ID 부재: %s" % o["DOC_ID"])
            if r["SYNONYMS"]:
                sys.exit("동의어 오버레이 대상이 이미 값을 가짐(덮어쓰기 금지): %s" % o["DOC_ID"])
            r["SYNONYMS"] = clean(o["SYNONYMS"].replace("|", ", "))


def build():
    out = []
    curated(out)
    seen = common_metrics(out)
    new_seen = new_metrics(out)
    additional_metrics(out, seen, new_seen)
    terms(out)
    orgs(out)
    source_refs(out)
    synonym_overlay(out)
    for r in out:
        # 🆕 [O233-B] SEARCH_TEXT = Markdown 헤더·불릿(청크 경계·라벨이 임베딩·LLM 모두에 분명해진다)
        r["KEYWORDS"] = keywords(r)
        r["IS_ADDITIVE"] = is_additive(r)
        r["HAS_FORMULA"] = "Y" if r["FORMULA"] else "N"
        parts = ["# [%s] %s" % (r["DOC_TYPE"], r["TITLE"])]
        for k, lab in [("SYNONYMS", "동의어"), ("DEFINITION", "정의"), ("FORMULA", "계산식"),
                       ("TOOL_NAME", "도구"), ("SV_FIELD", "SV 필드"), ("LIMITATION", "한계")]:
            if r[k]:
                parts.append("- **%s**: %s" % (lab, r[k]))
            elif k == "FORMULA" and r["DOC_TYPE"] in ("지표", "용어"):
                # 🆕 [O235] 산식 공란을 본문에 명시 — 산식 질문에 이 행을 근거로 쓰지 않게 한다(내용 창작 없음)
                parts.append("- **계산식**: 이 항목에는 미등록(원천 공란)")
        if r["IS_ADDITIVE"] == "N":
            parts.append("- **집계**: 비가산 — 하위 값을 더해 합계를 만들지 않는다")
        r["SEARCH_TEXT"] = "\n".join(parts)
    ids = [r["DOC_ID"] for r in out]
    dup = sorted({x for x in ids if ids.count(x) > 1})
    if dup:
        sys.exit("DOC_ID 중복: %s" % dup[:10])
    return out


def apply(out):
    import pandas as pd
    from snowflake.snowpark import Session
    token = open(os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")).read().strip()
    s = Session.builder.configs({
        "account": os.environ["SNOWFLAKE_ACCOUNT"], "host": os.environ["SNOWFLAKE_HOST"],
        "authenticator": "oauth", "token": token,
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE"), "role": os.environ.get("SNOWFLAKE_ROLE"),
        "database": "GN_DW", "schema": "SERVING",
    }).create()
    s.sql("TRUNCATE TABLE " + TABLE).collect()
    df = pd.DataFrame(out, columns=COLS)
    s.write_pandas(df, "BIZ_DEFINITION_CORPUS", database="GN_DW", schema="SERVING",
                   auto_create_table=False, overwrite=False, quote_identifiers=True)
    n = s.sql("SELECT COUNT(*) FROM " + TABLE).collect()[0][0]
    print("적재 행수 =", n)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="Snowflake 테이블에 적재(기본 = CSV 만)")
    a = ap.parse_args()
    out = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS)
        w.writeheader()
        w.writerows(out)
    from collections import Counter
    print("행수 =", len(out), dict(Counter(r["DOC_TYPE"] for r in out)))
    if a.apply:
        apply(out)


if __name__ == "__main__":
    main()
