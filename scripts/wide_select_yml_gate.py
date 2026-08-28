#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""WIDE 모델의 SELECT 별칭 목록 ↔ `_wide_schema.yml` `columns[]` 를 **순서까지** 대조한다.
Co-authored with CoCo

왜 필요한가 (2026-08-28 O105)
  `materialized='gn_view_commented'` 경로는 yml `columns[].description` 을 **SELECT 순서대로** 컬럼
  COMMENT 로 붙인다 ⇒ 이름·개수·순서가 어긋나면 **build ERROR** 이거나(운이 나쁘면) **엉뚱한 컬럼에
  엉뚱한 COMMENT** 가 붙는다(모델 머리말이 *"SELECT 컬럼 추가·삭제·순서 변경 시 yml 을 동시에
  재생성할 것 — 불일치는 build ERROR 다"* 라고 경고한다).
  🔴 이 세션 초판 대조기는 **한 줄에 콤마로 여러 컬럼이 온 구간**(`f.DATE_SK, f.MEMBER_DK, ...`)을
  놓쳐 44/73 으로 세고 「불일치」로 오판했다 — 분모를 먼저 확인하지 않은 것이다(`P128` 축).
  ⇒ 토큰 분할을 **줄이 아니라 콤마**로 한다.

사용법
  python3 scripts/wide_select_yml_gate.py [모델명 ...]     # 기본 = WIDE_MEMBER_EVENT
"""
import re
import sys

import yaml

YML = "/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml"
SQL_DIR = "/workspace/10_dbt_pipeline/models/gold/wide"

ALIAS = re.compile(r"\bas\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", re.I)
BARE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)\s*$")


def select_cols(path):
    raw = open(path, encoding="utf-8").read()
    # 최상위 SELECT 본문만 취한다: 첫 'select' 이후 ~ 첫 'from ' 앞
    body = re.split(r"(?im)^\s*select\s*$", raw, maxsplit=1)
    assert len(body) > 1, f"{path}: 단독 select 줄을 찾지 못했다"
    body = re.split(r"(?im)^\s*from\s+", body[1], maxsplit=1)[0]
    clean = "\n".join(ln.split("--")[0] for ln in body.split("\n"))
    out, unknown = [], []
    for tok in clean.split(","):
        t = " ".join(tok.split())
        if not t:
            continue
        m = ALIAS.search(t) or BARE.match(t)
        if m:
            out.append(m.group(1))
        else:
            unknown.append(t[:70])
    return out, unknown


def main() -> None:
    models = sys.argv[1:] or ["WIDE_MEMBER_EVENT"]
    d = yaml.safe_load(open(YML, encoding="utf-8"))
    fail = 0
    for name in models:
        mdl = [m for m in d["models"] if m["name"] == name]
        assert mdl, f"{name} 이 yml 에 없다"
        ycols = [c["name"] for c in mdl[0].get("columns", [])]
        scols, unknown = select_cols(f"{SQL_DIR}/{name}.sql")
        ok = scols == ycols
        print(f"{'🟢' if ok else '🔴'} {name}: SELECT {len(scols)} ↔ yml {len(ycols)} · 순서 일치 {ok}")
        if unknown:
            print(f"   ⚠️ 미분류 토큰 {len(unknown)}건(파서 확인 필요): {unknown[:3]}")
        if not ok:
            fail += 1
            for i, (a, b) in enumerate(zip(scols, ycols)):
                if a != b:
                    print(f"   첫 불일치 idx {i}: SELECT={a} ↔ yml={b}")
                    break
            print(f"   SELECT only: {[c for c in scols if c not in ycols]}")
            print(f"   yml only   : {[c for c in ycols if c not in scols]}")
    print()
    print("🟢 PASS" if not fail else f"🔴 FAIL — 불일치 {fail}건")
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
