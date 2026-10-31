"""1. 월마감반영 — 2026년 연사업계획 회비예측 (24개 시트).

원본 엑셀('★[확정]2026년 연사업계획 회비예측.xlsx')의 표와 셀 계산식을 그대로 재현하고,
탭 최상단에서 고른 연도·마감월까지의 월마감 실적(0. 월마감 백데이터, Snowflake)을
11개 사업 시트의 해당 월 입력 칸에 넣어 같은 계산식으로 회비를 예측한다.
"""
import pandas as pd
import streamlit as st

import app_common as A
import closing as C
import model as M

SECTION_NAMES = {
    "new_2025": "신규 · 2025 추경",
    "new_hq": "신규 · 2026 본부",
    "new_branch": "신규 · 2026 지부",
    "new_total": "신규 · 2026 본부+지부",
    "old_2025": "기존 · 2025 추경",
    "old_2026": "기존 · 2026 예측",
}

get_model = A.get_model


def won(v: float | None) -> str:
    """원 → 억원 표기 (계산 오류면 '#DIV/0!')."""
    return "#DIV/0!" if v is None else f"{v / 1e8:,.1f}억"


def pct(v: float | None) -> str:
    return "#DIV/0!" if v is None else f"{v * 100:.1f}%"


def editor_key(name: str, sec: str) -> str:
    return f"ed::{name}::{sec}"


def is_pct(sheet: dict, r: int, cols: list[str]) -> bool:
    return any(sheet["fmt"].get(f"{c}{r}", "").startswith("pct") for c in cols)


# ───────────────────────── 입력값 편집 ─────────────────────────
def business_editor_base(sheet: dict, start: int, end: int) -> pd.DataFrame:
    data = []
    for r in M.input_rows(sheet, start, end):
        grp, item = M.row_label(sheet, r)
        pct = is_pct(sheet, r, M.MONTH_COLS)
        vals = []
        for c in M.MONTH_COLS:
            cell = sheet["cells"].get(f"{c}{r}")
            vals.append((cell["v"] * 100 if pct else cell["v"]) if cell and "v" in cell else None)
        data.append([r, item or grp, "%" if pct else "건/원", *vals])
    return pd.DataFrame(data, columns=["행", "항목", "단위", *M.MONTH_LABELS])


def summary_editor_base(sheet: dict) -> pd.DataFrame:
    lay = M.layout_of(sheet)
    heads = M.summary_headers(sheet, lay["value_cols"])
    data = []
    for r in M.summary_input_rows(sheet):
        _, item = M.summary_label(sheet, r)
        vals = []
        for c in lay["value_cols"]:
            cell = sheet["cells"].get(f"{c}{r}")
            vals.append(cell["v"] if cell and "v" in cell else None)
        data.append([r, item, *vals])
    return pd.DataFrame(data, columns=["행", "항목", *heads])


def collect_overrides(sheet: dict) -> dict:
    """data_editor 편집 내역(session_state) → {셀좌표: 값}."""
    ov = {}
    name = sheet["name"]
    if sheet["kind"] == "business":
        targets = [(sec, M.input_rows(sheet, s, e), M.MONTH_COLS, M.MONTH_LABELS)
                   for s, e, sec, editable in M.SECTIONS if editable]
    else:
        lay = M.layout_of(sheet)
        targets = [("inputs", M.summary_input_rows(sheet), lay["value_cols"],
                    M.summary_headers(sheet, lay["value_cols"]))]
    for sec, rows, cols, heads in targets:
        state = st.session_state.get(editor_key(name, sec))
        if not state:
            continue
        for ri, changes in state.get("edited_rows", {}).items():
            r = rows[int(ri)]
            pct = sheet["kind"] == "business" and is_pct(sheet, r, cols)
            for col, v in changes.items():
                if col not in heads or v is None:
                    continue
                coord = f"{cols[heads.index(col)]}{r}"
                if M.is_input(sheet, coord):
                    ov[coord] = float(v) / 100 if pct else float(v)
    return ov


def reset_sheet(name: str) -> None:
    for key in [k for k in st.session_state if str(k).startswith(f"ed::{name}::")]:
        del st.session_state[key]


def reset_all() -> None:
    for key in [k for k in st.session_state if str(k).startswith("ed::")]:
        del st.session_state[key]


# ───────────────────────── 표 스타일 ─────────────────────────
def styled(disp: pd.DataFrame, mask: pd.DataFrame, value_heads: list[str], coords: list[list[str]], ov: dict):
    css = pd.DataFrame("", index=disp.index, columns=disp.columns)
    actual = closing_ov.get(name, {})
    for i in range(len(disp)):
        for j, h in enumerate(value_heads):
            k = disp.columns.get_loc(h)
            cell = disp.iat[i, k]
            if coords[i][j] in ov:
                css.iat[i, k] = "background-color:#ffd8a8;font-weight:600"
            elif coords[i][j] in actual:
                css.iat[i, k] = "background-color:#d0ebff;font-weight:600"
            elif mask.iat[i, j]:
                css.iat[i, k] = "background-color:#fff3bf"
            if cell.startswith("#") or cell == "FALSE":
                css.iat[i, k] = "color:#c92a2a"
            elif cell == "TRUE":
                css.iat[i, k] = "color:#2b8a3e"
    return disp.style.apply(lambda _: css, axis=None)


def show_table(df_styled, n_rows: int, key: str, heads: list[str], coords: list[list[str]],
               extra_config: dict | None = None) -> None:
    """표 + 칸 클릭 시 그 칸의 엑셀 계산식/참조값 표시."""
    event = st.dataframe(df_styled, hide_index=True, width="stretch", height=min(38 * (n_rows + 1), 1100),
                         key=key, on_select="rerun", selection_mode="single-cell",
                         column_config={"행": st.column_config.NumberColumn(width="small"),
                                        **(extra_config or {})})
    cells = event.selection.get("cells", []) if event else []
    if not cells:
        return
    ri, col = cells[0]
    if col not in heads or ri >= len(coords):
        return
    show_formula(coords[ri][heads.index(col)])


def show_formula(coord: str) -> None:
    src = closing_src.get((name, coord))
    if src and coord not in all_ov.get(name, {}):
        cell = by_name[name]["cells"].get(coord, {})
        fmt = by_name[name]["fmt"].get(coord, "int")
        plan = cell.get("f") or (M.fmt_value(cell["v"], fmt) if "v" in cell else "(빈 칸)")
        with st.container(border=True):
            st.markdown(f"**{name} !{coord}** · {M.cell_label(by_name[name], int(coord[1:]))} — "
                        f"값: `{M.fmt_value(wb_values[name].get(coord), fmt)}`")
            st.caption(f"{src}  \n연사업계획(엑셀) 원래 값/계산식: `{plan}`")
        return
    info = M.formula_info(by_name, wb_values, name, coord, all_ov)
    with st.container(border=True):
        st.markdown(f"**{name} !{coord}** · {info['label']} — 값: `{info['value']}`")
        if info["formula"]:
            st.code(info["formula"], language="excel", wrap_lines=True)
            if info["refs"]:
                st.dataframe(pd.DataFrame(info["refs"], columns=["참조 셀", "항목", "값"]), hide_index=True,
                             height=min(35 * (len(info["refs"]) + 1), 300))
        else:
            st.caption(info["kind"])


def long_frame(sheet: dict, values: dict) -> pd.DataFrame:
    out = []
    for start, end, sec, _ in M.SECTIONS:
        disp, nums, _ = M.section_frames(sheet, values, start, end, show_hidden=True)
        for i, r in enumerate(nums.index):
            out.append([sheet["name"], SECTION_NAMES[sec], r, disp.at[i, "구분"], disp.at[i, "항목"],
                        *nums.loc[r].tolist()])
    return pd.DataFrame(out, columns=["시트", "섹션", "행", "구분", "항목", *M.MONTH_LABELS])


def summary_long_frame(sheet: dict, values: dict) -> pd.DataFrame:
    lay = M.layout_of(sheet)
    heads = M.summary_headers(sheet, lay["value_cols"])
    out = []
    for start, end, title in lay["blocks"]:
        for r in range(start, end + 1):
            if not any(f"{c}{r}" in sheet["cells"] for c in lay["value_cols"]):
                continue
            grp, item = M.summary_label(sheet, r)
            out.append([sheet["name"], title, r, grp, item,
                        *[M.val(values, f"{c}{r}") for c in lay["value_cols"]]])
    return pd.DataFrame(out, columns=["시트", "블록", "행", "구분", "항목", *heads])


def status_banner(sheet: dict, values: dict, n_ov: int, scope: str) -> None:
    if n_ov:
        st.warning(f"{scope} 입력값 {n_ov}칸을 수정해 재계산한 결과입니다.", icon=":material/edit:")
        return
    if closing_ov:
        n_act = sum(len(d) for d in closing_ov.values())
        st.info(f"{sel_year}년 1~{sel_month}월 마감 실적 {n_act:,}칸(파란 칸)을 반영해 계산한 결과입니다.",
                icon=":material/cloud_done:")
        return
    n, bad = M.verify(sheet, values)
    if bad == 0:
        st.success(f"엑셀 계산 결과와 {n:,}칸 모두 일치", icon=":material/check_circle:")
    else:
        st.error(f"엑셀 계산 결과와 {bad:,}/{n:,}칸 불일치", icon=":material/error:")


# ───────────────────────── 화면: 공통 ─────────────────────────
mdl = get_model()
sheets = mdl["sheets"]
by_name = {s["name"]: s for s in sheets}
summary_names = [s["name"] for s in sheets if s["kind"] == "summary"]
monthly_names = [s["name"] for s in sheets if s["kind"] == "monthly"]
business_names = [s["name"] for s in sheets if s["kind"] == "business"]
captions = {"0. 후원사업별통합": "11개 사업 연간 통합", "0-1. 월별통합": "11개 사업 월별 통합"}

with st.sidebar:
    st.header("회비예측 2026")
    st.caption(f"원본: {mdl['source']}")
    # 순서: 통합 2개 → 사업별 월별 11개 → 사업 시트 11개
    options = summary_names + monthly_names + business_names
    name = st.radio("시트", options, key="sheet_choice",
                    captions=[captions.get(o, "") for o in options])
    show_hidden = st.toggle("엑셀 숨김행 표시", value=False, help="엑셀에서 숨겨진 행도 표시")
    show_check = st.toggle("검산 열 표시 (통합 시트)", value=False,
                           help="0. 후원사업별통합 T·U열, 0-1. 월별통합 R·S열의 검산식(TRUE/FALSE, 차이)")
    st.divider()
    st.button("이 시트 입력값 초기화", on_click=reset_sheet, args=(name,), icon=":material/restart_alt:",
              width="stretch")
    st.button("전체 시트 입력값 초기화", on_click=reset_all, icon=":material/delete_sweep:", width="stretch")
    st.caption("노란 칸 = 엑셀 입력값, 파란 칸 = 월마감 실적, 주황 칸 = 직접 수정한 값")
    st.caption("표의 칸을 클릭하면 표 아래에 엑셀 계산식과 참조 셀 값이 표시됩니다.")

# ───────────────────────── 연도·마감월 선택 + 월마감 실적 반영 ─────────────────────────
closing_df, closing_err = A.closing_data()
sel_year, sel_month = A.closing_selector(closing_df, "reflect", closing_err)
if sel_year is not None:
    closing_ov, closing_src = C.closing_overrides(closing_df, sel_year, sel_month)
else:
    closing_ov, closing_src = {}, {}

all_ov = {s["name"]: collect_overrides(s) for s in sheets}
ov_key = A.ov_to_key(C.merge_overrides(closing_ov, all_ov))  # 직접 수정값이 실적보다 우선
wb_values = A.compute_cached(M.model_version(), ov_key)
if ov_key:
    err_sheets = A.new_error_sheets(wb_values, A.compute_cached(M.model_version(), ()))
    if err_sheets:
        st.warning("실적/수정값 반영 후 엑셀 계산식에서 오류(#DIV/0! 등)가 새로 생긴 사업 시트: "
                   + ", ".join(f"{k} {v}칸" for k, v in err_sheets.items())
                   + ". 실적이 0인 칸을 분모로 쓰는 계산식(예: 누계납입율 = 누계회비 ÷ 활동누계) 때문이며, "
                   "엑셀에 같은 값을 넣어도 동일하게 나타납니다. 오류는 통합 시트 합계로 전파됩니다.",
                   icon=":material/warning:")
total_ov = sum(len(d) for d in all_ov.values())
sheet = by_name[name]
values = wb_values[name]
ov = all_ov[name]


# ───────────────────────── 화면: 통합 시트 ─────────────────────────
def render_summary() -> None:
    lay = M.layout_of(by_name[name])
    value_heads = M.summary_headers(sheet, lay["value_cols"])
    v = lambda c: M.val(values, c)  # 계산 오류(#DIV/0!) → None

    st.title(name)
    if sheet["kind"] == "summary":
        status_banner(sheet, values, total_ov, "24개 시트에서")
    else:
        src = business_names[monthly_names.index(name)] if len(monthly_names) == len(business_names) else ""
        status_banner(sheet, values, len(all_ov.get(src, {})) + len(ov), f"'{src}' 시트 / 이 시트에서")
    if name == "0. 후원사업별통합":
        with st.container(horizontal=True):
            st.metric("2026 통합 회비 (12월 누적)", won(v("E47")), border=True)
            st.metric("2025 엔딩예측 대비", won(v("E51")), border=True)
            st.metric("2025 연사업(이사회 승인) 대비", won(v("E53")), border=True)
            st.metric("통합 활동율", pct(v("E48")), border=True)
            st.metric("통합 납입율", pct(v("E49")), border=True)
            st.metric("연도말 명수 예측", "#DIV/0!" if v("E55") is None else f"{v('E55'):,.0f}명", border=True)
    else:
        with st.container(horizontal=True):
            st.metric("2026 통합 회비 (12월 누적)", won(v("Q47")), border=True)
            st.metric("2025 연사업 대비", won(v("Q51")), border=True)
            st.metric("12월 월회비", won(v("Q54")), border=True)
            st.metric("통합 활동율 (12월)", pct(v("Q48")), border=True)
            st.metric("통합 납입율 (12월)", pct(v("Q49")), border=True)

    tab_tbl, tab_chart, tab_edit = st.tabs(
        [":material/table: 표(계산 결과)", ":material/bar_chart: 차트", ":material/edit_note: 입력값 수정"])

    with tab_tbl:
        st.caption(("11개 후원사업 시트" if sheet["kind"] == "summary" else "해당 후원사업 시트") +
                   "의 신규(본부)·신규(지부)·신규(본부+지부)·기존 값을 엑셀과 동일한 "
                   "시트간 참조식으로 가져와 계산합니다.")
        for start, end, title in lay["blocks"]:
            disp, mask, rows, cols = M.summary_frames(sheet, values, start, end, show_hidden, show_check)
            if disp.empty:
                continue
            heads = list(disp.columns[3:])
            coords = [[f"{c}{r}" for c in cols] for r in rows]
            with st.expander(title, expanded=True):
                show_table(styled(disp, mask, heads, coords, ov), len(disp), f"tbl::{name}::{start}", heads, coords)

    with tab_chart:
        if name == "0. 후원사업별통합":
            bc = M.BIZ_DETAIL_COLS
            labels = M.summary_headers(sheet, bc)
            biz = pd.DataFrame({
                "사업": labels,
                "2026 신규(본부+지부)": M.row_values(values, 29, bc),
                "2026 기존": M.row_values(values, 39, bc),
                "2026 통합": M.row_values(values, 47, bc),
                "2025 엔딩예측": M.row_values(values, 50, bc),
                "2025 연사업": M.row_values(values, 52, bc),
                "증감(엔딩예측 대비)": M.row_values(values, 51, bc),
            }).set_index("사업")
            c1, c2 = st.columns(2)
            with c1, st.container(border=True):
                st.markdown("**사업별 2026 회비 구성 (원)**")
                st.bar_chart(biz[["2026 신규(본부+지부)", "2026 기존"]], horizontal=True)
            with c2, st.container(border=True):
                st.markdown("**사업별 2026 vs 2025 (원)**")
                st.bar_chart(biz[["2026 통합", "2025 엔딩예측", "2025 연사업"]], horizontal=True, stack=False)
            with st.container(border=True):
                st.markdown("**사업별 회비 증감액 (2025 엔딩예측 대비, 원)**")
                st.bar_chart(biz[["증감(엔딩예측 대비)"]], horizontal=True)
        else:
            mc = [M.num_to_col(i) for i in range(M.col_to_num("F"), M.col_to_num("Q") + 1)]
            idx = pd.CategoricalIndex(M.MONTH_LABELS, categories=M.MONTH_LABELS, ordered=True)

            def monthly(cum):  # 누적 → 월별 (0-1. 월별통합 62·63행과 같은 식)
                return [cum[0]] + [cum[i] - cum[i - 1] for i in range(1, 12)]

            mon = pd.DataFrame({
                "2026 누적회비": M.row_values(values, 47, mc),
                "2025 연사업 누적": M.row_values(values, 50, mc),
                "월별 회비(신규)": monthly(M.row_values(values, 29, mc)),
                "월별 회비(기존)": monthly(M.row_values(values, 39, mc)),
                "월별 개발": M.row_values(values, 55, mc),
                "월별 중단": M.row_values(values, 56, mc),
                "월납입율(신규)": M.row_values(values, 65, mc),
                "월납입율(기존)": M.row_values(values, 66, mc),
                "월납입율(합계)": M.row_values(values, 67, mc),
                "활동율(신규)": M.row_values(values, 27, mc),
                "활동율(기존)": M.row_values(values, 37, mc),
                "활동율(통합)": M.row_values(values, 48, mc),
            }, index=idx)
            c1, c2 = st.columns(2)
            with c1, st.container(border=True):
                st.markdown("**누적회비: 2026 예측 vs 2025 연사업 (원)**")
                st.line_chart(mon[["2026 누적회비", "2025 연사업 누적"]])
            with c2, st.container(border=True):
                st.markdown("**월별 회비 (신규/기존, 원)**")
                st.bar_chart(mon[["월별 회비(신규)", "월별 회비(기존)"]])
            c3, c4 = st.columns(2)
            with c3, st.container(border=True):
                st.markdown("**월별 개발 vs 중단 (건)**")
                st.bar_chart(mon[["월별 개발", "월별 중단"]], stack=False)
            with c4, st.container(border=True):
                if sheet["kind"] == "summary":
                    st.markdown("**월납입율**")
                    st.line_chart(mon[["월납입율(신규)", "월납입율(기존)", "월납입율(합계)"]])
                else:  # 사업별 월별 시트에는 월납입율 행(65~67)이 없음
                    st.markdown("**활동율 추이**")
                    st.line_chart(mon[["활동율(신규)", "활동율(기존)", "활동율(통합)"]])

    with tab_edit:
        st.caption("이 시트의 직접 입력값(2025 비교 기준값 등)을 수정할 수 있습니다. "
                   "신규·기존 값은 11개 후원사업 시트에서 수정하면 자동 반영됩니다.")
        base = summary_editor_base(sheet)
        if base.empty:
            st.info("이 시트에는 직접 입력값이 없습니다.")
        else:
            st.data_editor(base, key=editor_key(name, "inputs"), hide_index=True, width="stretch",
                           disabled=["행", "항목"],
                           column_config={h: st.column_config.NumberColumn(h, format="%.4f") for h in value_heads})
        changed = {n: len(d) for n, d in all_ov.items() if d}
        if changed:
            st.markdown("**현재 반영 중인 수정 내역**")
            st.dataframe(pd.DataFrame({"시트": list(changed), "수정 칸수": list(changed.values())}),
                         hide_index=True)

    st.divider()
    st.download_button(f"{name} 계산 결과 CSV",
                       summary_long_frame(sheet, values).to_csv(index=False).encode("utf-8-sig"),
                       file_name=f"{name}_계산결과.csv", mime="text/csv", icon=":material/download:")


# ───────────────────────── 화면: 11개 후원사업 시트 ─────────────────────────
def render_business() -> None:
    k = M.kpis(values)
    st.title(name)
    status_banner(sheet, values, len(ov), "이 시트")
    with st.container(horizontal=True):
        st.metric("2026 회비 합계(누적)", won(k["total_2026"]), delta=f"{won(k['total_diff'])} vs 2025 추경",
                  border=True)
        st.metric("신규회비 (본부+지부)", won(k["new_2026_cum"]), delta=won(k["new_diff"]), border=True)
        st.metric("기존회비", won(k["old_2026_cum"]), delta=won(k["old_diff"]), border=True)
        st.metric("12월 신규 활동율", f"{k['new_active'] * 100:.1f}%", border=True)
        st.metric("12월 기존 활동율", f"{k['old_active'] * 100:.1f}%", border=True)

    tab_tbl, tab_edit, tab_chart, tab_sum = st.tabs(
        [":material/table: 표(계산 결과)", ":material/edit_note: 입력값 수정", ":material/bar_chart: 차트",
         ":material/summarize: 11개 사업 요약"])

    with tab_tbl:
        for start, end, sec, _ in M.SECTIONS:
            g = M.group_title(sheet, start)
            if g:
                st.subheader(g)
            disp, nums, mask = M.section_frames(sheet, values, start, end, show_hidden)
            if disp.empty:
                continue
            coords = [[f"{c}{r}" for c in M.MONTH_COLS] for r in nums.index]
            with st.expander(M.section_title(sheet, start), expanded=sec in ("new_total", "old_2026")):
                show_table(styled(disp, mask, M.MONTH_LABELS, coords, ov), len(disp), f"tbl::{name}::{start}",
                           M.MONTH_LABELS, coords, {"비고": st.column_config.TextColumn(width="large")})

    with tab_edit:
        st.caption("2026 예측 섹션의 입력값만 수정할 수 있습니다. 비율은 % 단위로 입력하세요. "
                   "빈 칸은 엑셀 계산식 칸이라 입력해도 반영되지 않습니다. "
                   "수정값은 0. 후원사업별통합 / 0-1. 월별통합에도 자동 반영됩니다.")
        for start, end, sec, editable in M.SECTIONS:
            if not editable:
                continue
            base = business_editor_base(sheet, start, end)
            if base.empty:
                continue
            st.markdown(f"**{SECTION_NAMES[sec]}** — {M.section_title(sheet, start)}")
            st.data_editor(base, key=editor_key(name, sec), hide_index=True, width="stretch",
                           disabled=["행", "항목", "단위"],
                           column_config={m: st.column_config.NumberColumn(m, format="%.4f")
                                          for m in M.MONTH_LABELS})

    with tab_chart:
        ms = M.monthly_series(values).set_index("월")
        ms.index = pd.CategoricalIndex(ms.index, categories=M.MONTH_LABELS, ordered=True)
        c1, c2 = st.columns(2)
        with c1, st.container(border=True):
            st.markdown("**누적회비: 2025 추경 vs 2026 예측 (원)**")
            st.line_chart(ms[["2025 누적회비", "2026 누적회비"]])
        with c2, st.container(border=True):
            st.markdown("**월 회비: 신규 (원)**")
            st.bar_chart(ms[["2025 신규 월회비", "2026 신규 월회비"]], stack=False)
        c3, c4 = st.columns(2)
        with c3, st.container(border=True):
            st.markdown("**월 회비: 기존 (원)**")
            st.bar_chart(ms[["2025 기존 월회비", "2026 기존 월회비"]], stack=False)
        with c4, st.container(border=True):
            st.markdown("**2026 월말 활동회원 (건)**")
            st.line_chart(ms[["2026 신규 월말활동회원", "2026 기존 월말활동회원"]])

    with tab_sum:
        rows = []
        for bn in business_names:
            kk = M.kpis(wb_values[bn])
            rows.append({
                "사업": bn, "수정": "✎" if all_ov[bn] else "",
                "2025 신규": kk["new_2025_cum"], "2026 신규": kk["new_2026_cum"],
                "2025 기존": kk["old_2025_cum"], "2026 기존": kk["old_2026_cum"],
                "2025 합계": kk["total_2025"], "2026 합계": kk["total_2026"], "차액": kk["total_diff"],
            })
        summ = pd.DataFrame(rows)
        tot = summ.select_dtypes("number").sum()
        summ = pd.concat([summ, pd.DataFrame([{"사업": "합계(1~11)", "수정": "", **tot.to_dict()}])],
                         ignore_index=True)
        summ["증감률"] = summ["차액"] / summ["2025 합계"].where(summ["2025 합계"] != 0)
        money = {c: st.column_config.NumberColumn(c, format="localized")
                 for c in summ.columns if c.startswith("20") or c == "차액"}
        st.caption("12월 누적회비 기준 (단위: 원). 수정 표시(✎)는 입력값을 바꾼 사업입니다. "
                   "엑셀 통합 기준 표는 사이드바의 '0. 후원사업별통합'을 보세요.")
        st.dataframe(summ, hide_index=True, width="stretch",
                     column_config={**money, "증감률": st.column_config.NumberColumn("증감률", format="percent")})
        with st.container(border=True):
            st.markdown("**사업별 2026 회비 (신규/기존, 원)**")
            st.bar_chart(summ.iloc[:-1].set_index("사업")[["2026 신규", "2026 기존"]], horizontal=True)

        st.divider()
        st.download_button("현재 시트 계산 결과 CSV",
                           long_frame(sheet, values).to_csv(index=False).encode("utf-8-sig"),
                           file_name=f"{name}_계산결과.csv", mime="text/csv", icon=":material/download:")
        full = pd.concat([long_frame(by_name[bn], wb_values[bn]) for bn in business_names], ignore_index=True)
        st.download_button("11개 시트 전체 계산 결과 CSV", full.to_csv(index=False).encode("utf-8-sig"),
                           file_name="회비예측_11개시트_계산결과.csv", mime="text/csv", icon=":material/download:")


if sheet["kind"] in ("summary", "monthly"):
    render_summary()
else:
    render_business()
