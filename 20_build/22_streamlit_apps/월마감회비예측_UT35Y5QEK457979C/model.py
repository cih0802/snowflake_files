"""model.json 로드, 섹션 정의, 계산 결과 → 표(DataFrame) 변환."""
from __future__ import annotations

import json
import os

import pandas as pd

from formula_engine import WorkbookCalc, XlError, col_to_num, num_to_col

HERE = os.path.dirname(os.path.abspath(__file__))
MONTH_COLS = ["D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"]
MONTH_LABELS = [f"{i}월" for i in range(1, 13)]

# (시작행, 끝행, 키, 편집가능) — 11개 시트 공통 레이아웃
SECTIONS = [
    (3, 14, "new_2025", False),
    (16, 43, "new_hq", True),
    (44, 71, "new_branch", True),
    (72, 99, "new_total", True),
    (102, 114, "old_2025", False),
    (116, 148, "old_2026", True),
]

# KPI/차트에 쓰는 셀 위치 (11개 시트 모두 라벨 동일함을 확인)
ROW = {
    "new_2025_cum": 14, "new_2026_cum": 97, "new_diff": 98, "new_month": 93,
    "new_members": 89, "new_active": 91,
    "old_2025_cum": 114, "old_2026_cum": 142, "old_diff": 143, "old_month": 138,
    "old_members": 134, "old_active": 136,
}


MODEL_PATH = os.path.join(HERE, "model.json")
SUMMARY_SHEETS = ("0. 후원사업별통합", "0-1. 월별통합")


def model_version() -> tuple[float, int]:
    """model.json 변경 감지용 (수정시각, 크기) — 캐시 키로 사용."""
    st_ = os.stat(MODEL_PATH)
    return st_.st_mtime, st_.st_size


def load_model() -> dict:
    with open(MODEL_PATH, encoding="utf-8") as f:
        mdl = json.load(f)
    for s in mdl["sheets"]:  # 이전 형식 model.json 호환
        s.setdefault("kind", "summary" if s["name"] in SUMMARY_SHEETS else "business")
        s.setdefault("cached_err", {})
    return mdl


def text(sheet: dict, coord: str) -> str:
    return sheet["cells"].get(coord, {}).get("t", "").strip()


def row_label(sheet: dict, r: int) -> tuple[str, str]:
    """(구분, 항목) — B열이 그룹(예: 회비예측 조정)이고 C열이 항목인 경우 처리."""
    b, c = text(sheet, f"B{r}"), text(sheet, f"C{r}")
    if c:
        return b, c
    return "", b


def section_title(sheet: dict, start: int) -> str:
    return text(sheet, f"B{start}") or f"{start}행"


def group_title(sheet: dict, start: int) -> str:
    return text(sheet, f"B{start - 1}") if start in (3, 102) else ""


def is_input(sheet: dict, coord: str) -> bool:
    c = sheet["cells"].get(coord)
    return c is not None and "v" in c


def compute_workbook(sheets: list[dict], overrides: dict | None = None, div0_as_zero: bool = False) -> dict:
    """24개 시트를 한 번에 계산(시트간 참조 포함) → {시트명: {좌표: 값}}.

    div0_as_zero=True: 0으로 나누기(#DIV/0!) 칸을 0 으로 처리 (대시보드 기본).
    """
    return WorkbookCalc({s["name"]: s["cells"] for s in sheets}, overrides, div0_as_zero).compute_all()


def val(values: dict, coord: str):
    v = values.get(coord)
    return None if v is None or isinstance(v, (XlError, bool)) else v


def section_rows(sheet: dict, start: int, end: int, show_hidden: bool) -> list[int]:
    hidden = set(sheet["hidden_rows"])
    rows = []
    for r in range(start, min(end, sheet["max_row"]) + 1):
        if r in hidden and not show_hidden:
            continue
        has_month = any(f"{c}{r}" in sheet["cells"] for c in MONTH_COLS)
        if has_month:
            rows.append(r)
    return rows


def fmt_value(v, kind: str) -> str:
    if isinstance(v, XlError):
        return v.code
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if v is None:
        return ""
    if kind.startswith("pct"):
        return f"{v * 100:,.{int(kind[3])}f}%"
    if kind == "dec2":
        return f"{v:,.2f}"
    if kind == "dec1":
        return f"{v:,.1f}"
    return "-" if round(v) == 0 else f"{v:,.0f}"


def section_frames(sheet: dict, values: dict, start: int, end: int, show_hidden: bool):
    """표시용(문자열) DF, 숫자 DF, 입력셀 마스크 DF 반환."""
    disp, nums, mask = [], [], []
    idx = []
    for r in section_rows(sheet, start, end, show_hidden):
        if r == start:  # 섹션 제목행(메모 숫자, 어떤 식에서도 참조 안 됨)
            continue
        grp, item = row_label(sheet, r)
        header = text(sheet, f"D{r}") in ("Jan", "YR 2025", "YR 2026")
        if header:
            continue
        note = " / ".join(x for x in (text(sheet, f"P{r}"), text(sheet, f"Q{r}")) if x)
        d, n, m = [], [], []
        for c in MONTH_COLS:
            coord = f"{c}{r}"
            v = values.get(coord) if coord in sheet["cells"] else None
            if coord in sheet["cells"] and "t" in sheet["cells"][coord]:
                v = None
            kind = sheet["fmt"].get(coord, "int")
            d.append(fmt_value(v, kind))
            n.append(None if isinstance(v, XlError) else v)
            m.append(is_input(sheet, coord))
        idx.append(r)
        disp.append([r, grp, item or "(보조계산)", *d, note])
        nums.append(n)
        mask.append(m)
    cols = ["행", "구분", "항목", *MONTH_LABELS, "비고"]
    return (
        pd.DataFrame(disp, columns=cols),
        pd.DataFrame(nums, columns=MONTH_LABELS, index=idx),
        pd.DataFrame(mask, columns=MONTH_LABELS, index=idx),
    )


def input_rows(sheet: dict, start: int, end: int) -> list[int]:
    out = []
    for r in range(start, end + 1):
        if text(sheet, f"D{r}") in ("Jan", "YR 2025", "YR 2026"):
            continue
        if r == start:  # 섹션 제목행 옆 메모 숫자
            continue
        if any(is_input(sheet, f"{c}{r}") for c in MONTH_COLS):
            out.append(r)
    return out


def kpis(values: dict) -> dict:
    g = lambda key: val(values, f"O{ROW[key]}") or 0.0
    out = {k: g(k) for k in ROW}
    out["total_2025"] = out["new_2025_cum"] + out["old_2025_cum"]
    out["total_2026"] = out["new_2026_cum"] + out["old_2026_cum"]
    out["total_diff"] = out["total_2026"] - out["total_2025"]
    return out


def monthly_series(values: dict) -> pd.DataFrame:
    """월별 회비(월)·누적, 활동회원 (2025 추경 월회비는 누적의 차분)."""
    def row(r):
        return [val(values, f"{c}{r}") or 0.0 for c in MONTH_COLS]

    def diff(cum):
        return [cum[0]] + [cum[i] - cum[i - 1] for i in range(1, 12)]

    new25, old25 = row(ROW["new_2025_cum"]), row(ROW["old_2025_cum"])
    return pd.DataFrame({
        "월": MONTH_LABELS,
        "2025 신규 월회비": diff(new25),
        "2026 신규 월회비": row(ROW["new_month"]),
        "2025 기존 월회비": diff(old25),
        "2026 기존 월회비": row(ROW["old_month"]),
        "2025 누적회비": [a + b for a, b in zip(new25, old25)],
        "2026 누적회비": [a + b for a, b in zip(row(ROW["new_2026_cum"]), row(ROW["old_2026_cum"]))],
        "2026 신규 월말활동회원": row(ROW["new_members"]),
        "2026 기존 월말활동회원": row(ROW["old_members"]),
    })


def verify(sheet: dict, values: dict) -> tuple[int, int]:
    """엑셀 저장값(숫자·TRUE/FALSE·오류값)과 비교 → (비교 칸수, 불일치 칸수)."""
    n = bad = 0
    for coord, cv in sheet["cached"].items():
        n += 1
        v = values.get(coord)
        if isinstance(cv, bool):
            ok = v is cv
        else:
            ok = isinstance(v, (int, float)) and not isinstance(v, bool) and abs(v - cv) <= 1e-9 * max(1.0, abs(cv))
        bad += not ok
    for coord, code in sheet.get("cached_err", {}).items():
        n += 1
        v = values.get(coord)
        # 대시보드는 #DIV/0! 를 0 으로 표시하므로 0 도 일치로 본다
        bad += not (repr(v) == code or (code == "#DIV/0!" and v == 0))
    return n, bad


# ───────────────────── 통합 시트 (0. 후원사업별통합 / 0-1. 월별통합) ─────────────────────
SUMMARY_LAYOUT = {
    "0. 후원사업별통합": {
        "value_cols": [num_to_col(i) for i in range(col_to_num("E"), col_to_num("R") + 1)],
        "check_cols": ["T", "U"],
        "blocks": [(3, 11, "신규(본부)"), (12, 20, "신규(지부)"), (21, 29, "신규(본부+지부)"),
                   (30, 39, "기존"), (40, 49, "통합"), (50, 55, "2025 비교 · 명수 예측")],
    },
    "0-1. 월별통합": {
        "value_cols": [num_to_col(i) for i in range(col_to_num("E"), col_to_num("Q") + 1)],
        "check_cols": ["R", "S"],
        "blocks": [(3, 11, "신규(본부)"), (12, 20, "신규(지부)"), (21, 29, "신규(본부+지부)"),
                   (30, 39, "기존"), (40, 49, "통합"), (50, 51, "2025 연사업 비교"),
                   (53, 67, "월별 지표 (회비·개발·중단·납입율)")],
    },
}
# 0. 후원사업별통합의 사업 상세열(소계 H=총 해외프젝, O=총 기타사업, E=합계 제외)
BIZ_DETAIL_COLS = ["F", "G", "I", "J", "K", "L", "M", "N", "P", "Q", "R"]


def layout_of(sheet: dict) -> dict:
    """통합/월별 시트 레이아웃 (사업별 월별 시트는 0-1. 월별통합과 같은 틀, 행 3~57)."""
    if sheet["name"] in SUMMARY_LAYOUT:
        return SUMMARY_LAYOUT[sheet["name"]]
    blocks = [(3, 11, "신규(본부)"), (12, 20, "신규(지부)"), (21, 29, "신규(본부+지부)"),
              (30, 39, "기존"), (40, 49, "통합"), (50, 51, "2025 연사업 비교"),
              (53, 57, "월별 지표 (회비·개발·중단)")]
    if sheet["max_row"] > 57:
        blocks.append((58, sheet["max_row"], "추가 메모"))
    return {"value_cols": [num_to_col(i) for i in range(col_to_num("E"), col_to_num("Q") + 1)],
            "check_cols": [], "blocks": blocks}


def cell_label(sheet: dict, r: int) -> str:
    """셀이 속한 행의 항목명 (사업 시트: B/C열, 통합·월별 시트: B/C/D열)."""
    if sheet.get("kind") == "business":
        grp, item = row_label(sheet, r)
    else:
        grp, item = summary_label(sheet, r)
    return " / ".join(x for x in (grp, item) if x) or f"{r}행"


def formula_info(by_name: dict, wb_values: dict, sheet_name: str, coord: str, overrides: dict) -> dict:
    """셀의 엑셀 계산식과 참조 셀 값 목록."""
    from formula_engine import tokenize, expand_range, split_ref

    sheet = by_name[sheet_name]
    cell = sheet["cells"].get(coord)
    r = split_ref(coord)[1]
    value = wb_values.get(sheet_name, {}).get(coord)
    disp = fmt_value(value, sheet["fmt"].get(coord, "int")) if cell and "t" not in cell else ""
    info = {"label": cell_label(sheet, r), "value": disp or "(빈 칸)", "formula": "", "refs": [], "kind": ""}
    if coord in overrides.get(sheet_name, {}):
        info["kind"] = f"직접 수정한 입력값 (엑셀 원래 값: {fmt_value(cell['v'], sheet['fmt'].get(coord, 'int'))})"
        return info
    if cell is None:
        info["kind"] = "빈 칸 (계산식 없음)"
        return info
    if "v" in cell:
        info["kind"] = "엑셀 입력값 (계산식 없음) — '입력값 수정' 탭에서 바꿀 수 있습니다."
        return info
    if "t" in cell:
        info["kind"] = "텍스트"
        return info
    info["formula"] = cell["f"]
    seen = []
    for kind, v, sh in tokenize(cell["f"][1:]):
        if kind not in ("ref", "range"):
            continue
        target = sh or sheet_name
        cs = expand_range(v) if kind == "range" else [v.replace("$", "")]
        for c in cs:
            if (target, c) in seen:
                continue
            seen.append((target, c))
            tsheet = by_name.get(target)
            tv = wb_values.get(target, {}).get(c)
            lab = cell_label(tsheet, split_ref(c)[1]) if tsheet else ""
            fmt = tsheet["fmt"].get(c, "int") if tsheet else "int"
            ref = c if target == sheet_name else f"'{target}'!{c}"
            info["refs"].append([ref, lab, fmt_value(tv, fmt) if tv is not None else "(빈 칸)"])
    return info


def summary_headers(sheet: dict, cols: list[str]) -> list[str]:
    out = []
    for c in cols:
        h = text(sheet, f"{c}2")
        out.append({"Jan": "1월", "Feb": "2월", "Mar": "3월", "Apr": "4월", "May": "5월", "Jun": "6월",
                    "Jul": "7월", "Aug": "8월", "Sep": "9월", "Oct": "10월", "Nov": "11월",
                    "Dec": "12월"}.get(h, h) or f"{c}열")
    return out


def summary_label(sheet: dict, r: int) -> tuple[str, str]:
    b = text(sheet, f"B{r}")
    item = text(sheet, f"C{r}") or text(sheet, f"D{r}")
    return (b, item) if item else ("", b)


def summary_frames(sheet: dict, values: dict, start: int, end: int, show_hidden: bool, show_check: bool):
    """통합 시트 블록 → (표시 DF, 입력셀 마스크 DF, 행번호, 값 열 목록)."""
    lay = layout_of(sheet)
    cols = lay["value_cols"] + (lay["check_cols"] if show_check else [])
    heads = summary_headers(sheet, lay["value_cols"]) + ([f"검산 {c}" for c in lay["check_cols"]] if show_check else [])
    hidden = set(sheet["hidden_rows"])
    disp, mask, rows = [], [], []
    for r in range(start, end + 1):
        if r in hidden and not show_hidden:
            continue
        if not any(f"{c}{r}" in sheet["cells"] for c in lay["value_cols"]):
            continue
        grp, item = summary_label(sheet, r)
        d, m = [], []
        for c in cols:
            coord = f"{c}{r}"
            cell = sheet["cells"].get(coord)
            v = None if cell is None or "t" in cell else values.get(coord)
            d.append(fmt_value(v, sheet["fmt"].get(coord, "int")))
            m.append(is_input(sheet, coord))
        disp.append([r, grp, item, *d])
        mask.append(m)
        rows.append(r)
    return (pd.DataFrame(disp, columns=["행", "구분", "항목", *heads]),
            pd.DataFrame(mask, columns=heads), rows, cols)


def summary_input_rows(sheet: dict) -> list[int]:
    lay = layout_of(sheet)
    return [r for r in range(1, sheet["max_row"] + 1)
            if any(is_input(sheet, f"{c}{r}") for c in lay["value_cols"])]


def row_values(values: dict, r: int, cols: list[str]) -> list[float]:
    return [val(values, f"{c}{r}") or 0.0 for c in cols]
