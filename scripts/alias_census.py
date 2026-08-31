#!/usr/bin/env python3
# dbt 모델 SELECT 별칭을 「pass-through 동명 / pass-through 이명 / 표현식」으로 분류해 명명 규약 위반 후보를 센다.
# Co-authored with CoCo
#
# 판정 축 (DEC-25 15-A 를 전 계층으로 일반화한 사용자 요청의 기계 판정)
#   A 동명 pass-through   : 순수 컬럼 참조 + 별칭이 원천명과 같다      -> 규약 준수
#   B 이명 pass-through   : 순수 컬럼 참조 + 별칭이 원천명과 다르다    -> 🔴 개명 후보(원천명 복원)
#   C 표현식             : 함수/CASE/연산/문자열결합 등 로직이 있다   -> 의미명 타당성 검토 대상
#
# 한계(과소·과대 둘 다 가능하므로 판정에 그대로 쓰지 말 것):
#   - 여러 줄에 걸친 CASE/함수는 별칭이 있는 마지막 줄만 보므로 C 로 잡힌다(의도된 근사).
#   - `select *` 로 흘러가는 컬럼은 별칭이 없어 이 분모에 없다.
#   - UNION ALL 분기·JOIN 유래는 별칭만으로 판별되지 않는다 -> 별도 축(union/join 보유 모델)으로 함께 센다.
import csv
import pathlib
import re
import sys

ROOT = pathlib.Path("/workspace/10_dbt_pipeline/models")

# `<expr> as <ALIAS>` 의 꼬리를 잡는다. 주석줄(--)과 jinja 줄은 제외한다.
ALIAS_RE = re.compile(r"^(?P<expr>.*?)\s+as\s+(?P<alias>[A-Za-z_][A-Za-z0-9_]*)\s*,?\s*$", re.IGNORECASE)
BARE_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
QUAL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)$")

# 🔴 [O122 정정] 이것들은 컬럼이 아니다 — 리터럴이거나 여러 줄 식의 종결 토큰이다.
#   초판이 `NULL as DW_BATCH_ID`(32건)와 `end as DURATION_SEC` 를 「이명 pass-through」로
#   오분류해 SILVER 위반을 90건으로 과대 집계했다. 분모에서 빼지 말고 D 로 분리해 센다.
NOT_A_COLUMN = {"NULL", "END", "TRUE", "FALSE", "DEFAULT"}
# 🟢 라벨 조인 유래 = DEC-25 15-A 「라벨 컬럼 = 분석 용어명」이 **규정한** 개명이다(위반이 아니다).
LABEL_SOURCES = {"DTL_CD_NM", "CD_NM"}


def layer_of(path: pathlib.Path) -> str:
    parts = path.relative_to(ROOT).parts
    return parts[0] if parts else "?"


def classify(expr: str, alias: str):
    """(class, source_name) 을 돌려준다."""
    e = expr.strip()
    if BARE_RE.match(e):
        src = e
    else:
        m = QUAL_RE.match(e)
        if not m:
            return "C_expr", None
        src = m.group(1)
    if src.upper() in NOT_A_COLUMN:
        return "D_literal", src
    if src.upper() in LABEL_SOURCES:
        return "E_label_join", src
    return ("A_same" if src.upper() == alias.upper() else "B_renamed"), src


def main() -> int:
    rows = []
    model_axes = []
    for path in sorted(ROOT.rglob("*.sql")):
        text = path.read_text(encoding="utf-8")
        low = text.lower()
        model_axes.append(
            {
                "model": path.stem,
                "layer": layer_of(path),
                "has_union_all": "union all" in low,
                "has_join": bool(re.search(r"\bjoin\b", low)),
                "path": str(path.relative_to(ROOT)),
            }
        )
        for lineno, line in enumerate(text.splitlines(), 1):
            s = line.strip()
            if not s or s.startswith("--") or s.startswith("{") or s.startswith("#"):
                continue
            m = ALIAS_RE.match(s)
            if not m:
                continue
            alias = m.group("alias")
            if alias.upper() in {"SELECT", "FROM", "WHERE", "WITH", "AND", "OR", "ON"}:
                continue
            klass, src = classify(m.group("expr"), alias)
            rows.append(
                {
                    "layer": layer_of(path),
                    "model": path.stem,
                    "lineno": lineno,
                    "class": klass,
                    "source_name": src or "",
                    "alias": alias,
                    "path": str(path.relative_to(ROOT)),
                }
            )

    out = pathlib.Path("/workspace/30_output_share/_o122_alias_census.csv")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["layer", "model", "lineno", "class", "source_name", "alias", "path"])
        w.writeheader()
        w.writerows(rows)

    layers = sorted({r["layer"] for r in rows})
    classes = ["A_same", "B_renamed", "C_expr", "D_literal", "E_label_join"]
    print("== 별칭 분류 (분모 = 별칭이 명시된 SELECT 항목) ==")
    header = f"{'layer':8}" + "".join(f"{c:>14}" for c in classes) + f"{'합':>8}"
    print(header)
    for lay in layers:
        sub = [r for r in rows if r["layer"] == lay]
        cells = "".join(f"{sum(1 for r in sub if r['class'] == c):>14}" for c in classes)
        print(f"{lay:8}{cells}{len(sub):>8}")
    cells = "".join(f"{sum(1 for r in rows if r['class'] == c):>14}" for c in classes)
    print(f"{'TOTAL':8}{cells}{len(rows):>8}")

    print("\n== 모델 축 (union all / join 보유 = 비즈니스 로직 유입 지점) ==")
    for lay in sorted({m["layer"] for m in model_axes}):
        sub = [m for m in model_axes if m["layer"] == lay]
        u = sum(1 for m in sub if m["has_union_all"])
        j = sum(1 for m in sub if m["has_join"])
        print(f"{lay:10} 모델 {len(sub):3} · union_all {u:3} · join {j:3}")

    print(f"\n🟢 상세 CSV = {out}  (행 {len(rows)})")
    print("⚠️ 이 수치는 근사다 — 여러 줄 CASE 는 C 로 잡히고 `select *` 경유 컬럼은 분모 밖이다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
