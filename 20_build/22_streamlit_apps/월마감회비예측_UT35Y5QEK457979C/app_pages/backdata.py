"""0. 월마감 백데이터 — Snowflake 월마감 집계(개발·중단·감액·활동·회비)를 자동 조회."""
import pandas as pd
import streamlit as st

import app_common as A
import closing as C

df, err = A.closing_data()
year, month = A.closing_selector(df, "backdata", err)

if year is not None:
    mk = year * 100 + month
    st.subheader(f"{year}년 {month}월 마감 백데이터")
    st.caption("후원사업별 신규-본부 / 신규-지부 / 기존 집계. 이 값이 '1. 월마감반영' 탭 사업 시트의 "
               f"{month}월 열 입력 칸에 자동으로 들어갑니다.")

    tabs = st.tabs([f"{i}. {m}" for i, m in enumerate(C.METRICS, start=1)])
    for tab, metric in zip(tabs, C.METRICS):
        with tab:
            if metric not in C.FILLED_METRICS:
                # 활동·회비: MSTR 팩트에 없어 공란 — 로직 추가 예정. 1번 탭은 엑셀 계산식으로 계산
                blank = pd.DataFrame({"후원사업": [*C.BUSINESS_SHEET, "합계"],
                                      **{c: [None] * (len(C.BUSINESS_SHEET) + 1)
                                         for c in [*C.DIVS, "당월 합계", "누계 합계"]
                                         if metric == "회비" or c not in ("당월 합계", "누계 합계")},
                                      **({"합계": [None] * (len(C.BUSINESS_SHEET) + 1)} if metric != "회비" else {})})
                st.dataframe(blank, hide_index=True, width="stretch", height=38 * (len(blank) + 1))
                st.info(f"{metric} 데이터는 준비 중입니다(공란). 로직이 추가되기 전까지 '1. 월마감반영' 탭의 "
                        f"{metric} 칸은 연사업계획 엑셀 계산식으로 계산됩니다.", icon=":material/hourglass_empty:")
                continue
            tbl = C.summary_table(df, mk, metric)  # 마지막 행 = 합계
            unit = "원" if metric == "회비" else "건"
            if metric == "회비":
                # 당월 합계 옆에 누계 합계 (VALUE2 = 누계 납입)
                cum = df[(df["월키"] == mk) & (df["지표"] == "회비")].groupby("사업")["누계"].sum()
                tbl = tbl.rename(columns={"합계": "당월 합계"})
                tbl["누계 합계"] = cum.reindex(tbl.index).fillna(0.0)
                tbl.loc["합계", "누계 합계"] = cum.sum()
            show = tbl.reset_index().rename(columns={"index": "후원사업", "사업": "후원사업"})
            num_cols = [c for c in show.columns if c != "후원사업"]
            total_row = show.index[-1]
            styler = (show.style
                      .format({c: "{:,.0f}" if metric == "회비" else "{:,.1f}" for c in num_cols})
                      .apply(lambda r: ["font-weight:700;background-color:#e7f5ff" if r.name == total_row else ""
                                        for _ in r], axis=1))
            st.dataframe(styler, hide_index=True, width="stretch",
                         height=38 * (len(show) + 1),
                         column_config={c: st.column_config.Column(f"{c} ({unit})") for c in num_cols})
            if metric == "회비":
                st.caption("당월 = 월 납입(원, 1번 탭에 들어가는 값), 누계 = 1월부터 해당 월까지 누계 납입(원)")
            if metric == "중단" and (mk, "중단", "기존") in C.HOSU_ADJUST:
                hosu = sum(C.HOSU_ADJUST[(mk, "중단", "기존")].values())
                st.caption(f"허수회원 제외 {'적용 (원천 값 그대로)' if st.session_state.get('exclude_hosu', True) else '해제 (허수 건수 다시 더함)'} "
                           f"— 해당 월 기존 중단 허수 {hosu:,}건")

    with st.expander("1번 탭 입력 칸 대응표"):
        st.dataframe(C.mapping_table(), hide_index=True, width="stretch")
        st.caption("사업명 대응: " + ", ".join(f"{k} → {v}" for k, v in C.BUSINESS_SHEET.items()))

    with st.expander("원천 데이터 (행 단위)"):
        sub = df[df["월키"] == mk].sort_values(["지표", "사업", "구분"])
        st.dataframe(sub[["월키", "지표", "사업", "구분", "값", "누계"]], hide_index=True, width="stretch",
                     column_config={"값": st.column_config.NumberColumn(format="localized"),
                                    "누계": st.column_config.NumberColumn(format="localized")})
        st.download_button("CSV 다운로드", sub.to_csv(index=False).encode("utf-8-sig"),
                           file_name=f"월마감백데이터_{mk}.csv", mime="text/csv", icon=":material/download:")

    months = C.available_months(df)
    st.caption("적재된 마감월: " + " · ".join(f"{y}년 {', '.join(f'{m}월' for m in ms)}"
                                         for y, ms in months.items()))
