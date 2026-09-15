#!/usr/bin/env python3
"""o163_dec50_rename — DEC-50 SILVER 미집행 8건 개명 일괄 치환 (파일 지정형).

🔴 왜 스크립트인가
  · 대상 파일(`09_SILVER_적재쿼리`)은 치환 지점이 13곳이고 본문에 백틱·`$` 가 섞여 있어
    셸 경유가 금지된다(`R1-7-9`) ⇒ 스크립트 파일로 만들어 실행한다.

🔴🔴 가장 큰 위험 = 원천 컬럼명 파괴
  · `EP_GA_SESSION_ID` · `EP_GA_SESSION_NUMBER` 는 `SILVER.BIGQUERY_REFINED_DATA` 의
    **원천 컬럼**(외부 Python 적재 118컬럼 · 개명표 §1 `EXTERNAL_PYTHON` 축)이고 불변이어야 한다.
  · 그런데 이 두 이름은 개명 대상 `GA_SESSION_ID` / `GA_SESSION_NUMBER` 를 **부분문자열로 포함**한다.
  ⇒ 단순 치환하면 원천 참조가 깨져 build 가 죽는다.
  ⇒ negative lookbehind `(?<!EP_)` 로 보호하고, 실행 후 **EP_ 개수 불변**을 단정한다.

사용법
  python3 scripts/o163_dec50_rename.py --check <경로> [...]   # dry-run(기본)
  python3 scripts/o163_dec50_rename.py --apply <경로> [...]   # 적용
"""
import argparse
import re
import sys
from pathlib import Path

# 개명 규칙. 🔴 GOLD 기존 관례(`BIGQUERY_MEMBER_ID`·`BIGQUERY_EVENT_SK`·`BIGQUERY_SOURCE_SK`)를
#   따라 `BIGQUERY_` 접두로 통일한다(DEC-50 §36-A).
RULES = [
    # (?<!EP_) = 원천 `EP_GA_SESSION_*` 보호
    (re.compile(r"(?<!EP_)\bGA_SESSION_ID\b"), "BIGQUERY_SESSION_ID"),
    (re.compile(r"(?<!EP_)\bGA_SESSION_NUMBER\b"), "BIGQUERY_SESSION_NUMBER"),
    (re.compile(r"\bGA_SESSION_KEY\b"), "BIGQUERY_SESSION_KEY"),
    (re.compile(r"\bGA_MEMBER_ID\b"), "BIGQUERY_MEMBER_ID"),
]

# 실행 후 개수가 바뀌면 안 되는 보호 토큰.
GUARD = ["EP_GA_SESSION_ID", "EP_GA_SESSION_NUMBER"]


def process(path: Path, apply: bool):
    text = path.read_text(encoding="utf-8")
    before_lines = text.count("\n")
    guard_before = {g: text.count(g) for g in GUARD}

    out = text
    hits = {}
    for pat, repl in RULES:
        out, n = pat.subn(repl, out)
        if n:
            hits[repl] = n

    guard_after = {g: out.count(g) for g in GUARD}
    after_lines = out.count("\n")

    ok = True
    if guard_before != guard_after:
        print(f"  🔴 원천 토큰 개수 변동 — 치환 중단: {guard_before} → {guard_after}")
        ok = False
    if before_lines != after_lines:
        print(f"  🔴 줄 수 변동 {before_lines} → {after_lines}")
        ok = False

    total = sum(hits.values())
    label = "적용" if apply else "dry-run"
    print(f"{path} [{label}] 치환 {total}건 {hits or ''}"
          f" · 원천 보호 {guard_before} 유지={guard_before == guard_after}")

    if apply and ok and total:
        path.write_text(out, encoding="utf-8")
        # 🔴 R1-7-1 「부득이 전체를 다시 썼다면 즉시 되읽어 확인」 이행
        back = path.read_text(encoding="utf-8")
        if back != out:
            print("  🔴 되읽기 불일치 — 쓰기가 온전하지 않다")
            return False
        print("  🟢 되읽기 일치")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    all_ok = True
    for p in args.paths:
        path = Path(p)
        if not path.exists():
            print(f"🔴 부재: {p}")
            all_ok = False
            continue
        if not process(path, args.apply):
            all_ok = False

    print("🟢 PASS" if all_ok else "🔴 FAIL")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
