"""월마감 백데이터 (Snowflake) → '1. 월마감반영' 입력 칸 대응.

원천: GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA (월마감 후원사업 집계)
  STDR_MT(YYYYMM) × AGGR_TY_NM(개발/중단/감액/활동/회비) × SPNSR_BSNS_GRP_NM(후원사업)
  × NEW_EXST_DIV_NM + HDQ_BRNCH_GRP_NM (신규-본부 / 신규-지부 / 기존-기존)
  VALUE1 = 건수 또는 월 납입(원), VALUE2 = 누계 납입(원, 회비만)
  기존 중단은 허수회원 제외 값 (2026-01 엑셀 백데이터 − 490건).
"""
from __future__ import annotations

import pandas as pd

import model as M

SOURCE_VIEW = "GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA"
# 결과 컬럼은 normalize() 입력 형태에 맞춘다. 바인드: 시작월, 종료월 (YYYYMM 문자열)
CLOSING_SQL = """
SELECT TO_NUMBER(STDR_MT) AS MONTH_KEY, AGGR_TY_NM, SPNSR_BSNS_GRP_NM, NEW_EXST_DIV_NM, HDQ_BRNCH_GRP_NM,
       VALUE1, VALUE2
FROM GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA
WHERE STDR_MT BETWEEN ? AND ?
ORDER BY 1, 2, 3, 4, 5
"""
CLOSING_PARAMS = ["202601", "209912"]

METRICS = ["개발", "중단", "감액", "활동", "회비"]
FILLED_METRICS = ["개발", "중단", "감액", "활동", "회비"]  # 원천에서 채우는 지표
DIVS = ["신규-본부", "신규-지부", "기존"]

# 백데이터 후원사업명 → 1. 월마감반영 사업 시트
BUSINESS_SHEET = {
    "해외아동결연": "1. 해외아동결연",
    "국내(사단)": "2. 국내(사단)",
    "보건의료지원사업": "3. 보건의료",
    "식수위생지원사업": "4. 식수위생",
    "해외교육지원사업": "5. 해외교육",
    "희망학교지원사업": "6. 희망학교",
    "재난구호지원사업": "7. 재난구호",
    "해외지역개발사업": "8. 해외지역",
    "대북지원사업": "9. 대북",
    "좋은이웃": "10. 좋은이웃",
    "전체사업지원": "11. 전체사업",
}

# (집계유형, 구분) → 사업 시트 행 (열 = 해당 월, 1월=D … 12월=O)
CELL_ROW = {
    ("개발", "신규-본부"): 19, ("개발", "신규-지부"): 47, ("개발", "기존"): 120,
    ("중단", "신규-본부"): 22, ("중단", "신규-지부"): 50, ("중단", "기존"): 123,
    ("감액", "신규-본부"): 24, ("감액", "신규-지부"): 52, ("감액", "기존"): 125,
    ("활동", "신규-본부"): 33, ("활동", "신규-지부"): 61, ("활동", "기존"): 134,
    ("회비", "신규-본부"): 37, ("회비", "신규-지부"): 65, ("회비", "기존"): 138,
}

# 허수회원 (2025년 고액허수회원) — 회원통계보고서 대시보드의 '허수회원 제외' 목록과 동일.
# Snowflake 집계는 허수회원을 제외한 값이므로, '제외 해제' 시 아래 건수를 다시 더한다.
#   1945685: 국내(사단) 10건 / 1894701: 국내(사단) 50, 해외교육 100, 식수위생 50, 보건의료 50,
#            재난구호 100, 해외지역개발 80, 전체사업지원 50  → 합계 490건 (2026-01 기존 중단)
HOSU_ADJUST = {
    (202601, "중단", "기존"): {
        "국내(사단)": 60, "해외교육지원사업": 100, "식수위생지원사업": 50, "보건의료지원사업": 50,
        "재난구호지원사업": 100, "해외지역개발사업": 80, "전체사업지원": 50,
    },
}
HOSU_NOTE = ("2025년 고액허수회원 제외 (회원통계보고서 대시보드와 동일)\n\n"
             "• 1945685 — 국내(사단) 10건\n"
             "• 1894701 — 국내(사단) 50, 해외교육 100, 식수위생 50, 보건의료 50, "
             "재난구호 100, 해외지역개발 80, 전체사업지원 50건\n\n"
             "합계 490건 (2026-01 기존 중단)")


def div_of(new_exst: str, hdq: str) -> str:
    return "기존" if new_exst == "기존" else f"{new_exst}-{hdq}"


def normalize(raw: pd.DataFrame) -> pd.DataFrame:
    """조회 결과 → [월키, 연, 월, 지표, 사업, 구분, 값, 누계] (NULL=0)."""
    df = raw.rename(columns=str.upper).copy()
    if df.empty:
        return pd.DataFrame(columns=["월키", "연", "월", "지표", "사업", "구분", "값", "누계"])
    out = pd.DataFrame({
        "월키": df["MONTH_KEY"].astype(int),
        "지표": df["AGGR_TY_NM"],
        "사업": df["SPNSR_BSNS_GRP_NM"],
        "구분": [div_of(a, b) for a, b in zip(df["NEW_EXST_DIV_NM"], df["HDQ_BRNCH_GRP_NM"])],
        "값": pd.to_numeric(df["VALUE1"], errors="coerce").fillna(0.0).astype(float),
        "누계": pd.to_numeric(df["VALUE2"], errors="coerce").astype(float),
    })
    out["연"] = out["월키"] // 100
    out["월"] = out["월키"] % 100
    return out


def apply_hosu(df: pd.DataFrame, exclude: bool) -> pd.DataFrame:
    """원천 값은 허수회원 제외. exclude=True: 그대로. False: 허수 건수를 다시 더함(엑셀 백데이터와 동일)."""
    if exclude or df.empty:
        return df
    df = df.copy()
    for (mk, metric, div), by_biz in HOSU_ADJUST.items():
        for biz, n in by_biz.items():
            m = (df["월키"] == mk) & (df["지표"] == metric) & (df["구분"] == div) & (df["사업"] == biz)
            df.loc[m, "값"] = df.loc[m, "값"] + n
    return df


def available_months(df: pd.DataFrame) -> dict[int, list[int]]:
    out: dict[int, list[int]] = {}
    for mk in sorted(df["월키"].unique()) if not df.empty else []:
        out.setdefault(int(mk) // 100, []).append(int(mk) % 100)
    return out


def summary_table(df: pd.DataFrame, month_key: int, metric: str) -> pd.DataFrame:
    """사업 11개 × (신규-본부, 신규-지부, 기존, 합계) — 엑셀 백데이터 사업별 요약과 같은 형태."""
    sub = df[(df["월키"] == month_key) & (df["지표"] == metric)]
    piv = sub.pivot_table(index="사업", columns="구분", values="값", aggfunc="sum").reindex(
        index=list(BUSINESS_SHEET), columns=DIVS).fillna(0.0)
    piv["합계"] = piv.sum(axis=1)
    piv.loc["합계"] = piv.sum()
    return piv


def closing_overrides(df: pd.DataFrame, year: int, month: int) -> tuple[dict, dict]:
    """year 의 1~month 월 실적 → ({시트: {좌표: 값}}, {(시트, 좌표): 설명})."""
    ov: dict[str, dict[str, float]] = {}
    src: dict[tuple[str, str], str] = {}
    sub = df[(df["연"] == year) & (df["월"] <= month)]
    for row in sub.itertuples(index=False):
        sheet = BUSINESS_SHEET.get(row.사업)
        r = CELL_ROW.get((row.지표, row.구분))
        if sheet is None or r is None or not 1 <= row.월 <= 12:
            continue
        coord = f"{M.MONTH_COLS[row.월 - 1]}{r}"
        ov.setdefault(sheet, {})[coord] = float(row.값)
        src[(sheet, coord)] = f"{row.연}-{row.월:02d} 마감 실적 · {row.지표} · {row.구분} ({SOURCE_VIEW})"
    return ov, src


def mapping_table() -> pd.DataFrame:
    rows = []
    for (metric, div), r in CELL_ROW.items():
        rows.append({"집계유형": metric, "구분": div, "1번 탭 사업 시트 행": r,
                     "열": "해당 월 (1월=D … 12월=O)"})
    return pd.DataFrame(rows)


def merge_overrides(*layers: dict) -> dict:
    """{시트: {좌표: 값}} 여러 겹을 순서대로 덮어씀 (뒤가 우선)."""
    out: dict[str, dict[str, float]] = {}
    for layer in layers:
        for sheet, cells in layer.items():
            out.setdefault(sheet, {}).update(cells)
    return out


def results_for(sheets: list[dict], df: pd.DataFrame, year: int, month: int) -> dict:
    """2·3번 비교 탭용: 해당 마감 버전의 24개 시트 계산 결과 {시트: {좌표: 값}}."""
    ov, _ = closing_overrides(df, year, month)
    return M.compute_workbook(sheets, ov, div0_as_zero=True)
