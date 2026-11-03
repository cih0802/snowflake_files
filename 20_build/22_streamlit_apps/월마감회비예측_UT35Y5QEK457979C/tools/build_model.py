"""엑셀 원본(★[확정]2026년 연사업계획 회비예측.xlsx)에서
11개 후원사업 시트 + 통합 시트 2개(0. 후원사업별통합, 0-1. 월별통합)의
값/계산식/표시형식/라벨을 추출해 model.json 으로 저장한다.

앱 실행 시에는 openpyxl 없이 model.json 만 사용한다.
엑셀이 바뀌면 이 스크립트를 다시 실행:  python tools/build_model.py
"""
import json
import os
import sys

import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.dirname(HERE)
SRC = os.path.join(os.path.dirname(APP_DIR), "★[확정]2026년 연사업계획 회비예측.xlsx")
OUT = os.path.join(APP_DIR, "model.json")

BUSINESS_SHEETS = [
    "1. 해외아동결연", "2. 국내(사단)", "3. 보건의료", "4. 식수위생", "5. 해외교육",
    "6. 희망학교", "7. 재난구호", "8. 해외지역", "9. 대북", "10. 좋은이웃", "11. 전체사업",
]
SUMMARY_SHEETS = ["0. 후원사업별통합", "0-1. 월별통합"]
# 사업별 월별 시트 (엑셀 순서, 숨김 '9-1. 기타월별'은 visible 체크로 제외)
MONTHLY_SHEETS = [
    "1-1. 결연월별", "2-1.국내(사단)월별", "3-1. 보건의료월별 ", "4-1. 식수위생월별", "5-1.해외교육월별",
    "6-1.희망학교월별", "7-1.재난구호월별", "8-1.해외지역월별", "9-1. 기타월별", "9-1. 대북월별",
    "10-1. 좋은이웃월별", "11-1. 전체사업월별",
]


def fmt_kind(number_format: str) -> str:
    """표시 형식을 pct / int / dec 로 단순화."""
    if "%" in number_format:
        return "pct2" if "0.00%" in number_format else ("pct1" if "0.0%" in number_format else "pct0")
    if "0.00" in number_format:
        return "dec2"
    if "0.0" in number_format:
        return "dec1"
    return "int"


def extract(ws, vs, kind: str) -> dict:
    cells, cached, cached_err, fmts = {}, {}, {}, {}
    max_col = 17 if kind == "business" else ws.max_column  # 사업 시트: A..Q, 통합: 전체(A..U)
    for row in ws.iter_rows(min_row=1, max_row=ws.max_row, max_col=max_col):
        for c in row:
            if c.value is None:
                continue
            coord, v = c.coordinate, c.value
            if isinstance(v, str) and v.startswith("="):
                cells[coord] = {"f": v}
                cv = vs[coord].value
                if isinstance(cv, (bool, int, float)):
                    cached[coord] = cv
                elif isinstance(cv, str) and cv.startswith("#"):
                    cached_err[coord] = cv
            elif isinstance(v, (int, float)) and not isinstance(v, bool):
                cells[coord] = {"v": v}
            else:
                cells[coord] = {"t": str(v)}
            if c.column >= 4:
                fmts[coord] = fmt_kind(c.number_format or "General")
    return {
        "name": ws.title,
        "kind": kind,
        "max_row": ws.max_row,
        "max_col": max_col,
        "cells": cells,
        "cached": cached,
        "cached_err": cached_err,
        "fmt": fmts,
        "hidden_rows": sorted(r for r, d in ws.row_dimensions.items() if d.hidden),
    }


def main(src: str = SRC) -> None:
    wb = openpyxl.load_workbook(src)
    wv = openpyxl.load_workbook(src, data_only=True)
    model = {"source": os.path.basename(src), "sheets": []}
    for names, kind in ((BUSINESS_SHEETS, "business"), (SUMMARY_SHEETS, "summary"),
                        (MONTHLY_SHEETS, "monthly")):
        for name in names:
            if wb[name].sheet_state != "visible":
                continue
            model["sheets"].append(extract(wb[name], wv[name], kind))
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(model, f, ensure_ascii=False, separators=(",", ":"))
    print(f"saved {OUT} ({os.path.getsize(OUT):,} bytes, {len(model['sheets'])} sheets)")


if __name__ == "__main__":
    main(*sys.argv[1:])
