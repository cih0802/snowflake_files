"""월마감 회비예측 대시보드 — 진입 파일 (상단 탭 네비게이션).

0. 월마감 백데이터  : Snowflake 월마감 집계 자동 조회
1. 월마감반영       : 연사업계획 엑셀 24개 시트 계산식 + 선택 월까지의 마감 실적 반영
2. 비교1(월별비교)  : 준비 중
3. 비교2(연도마감비교): 준비 중
"""
import streamlit as st

st.set_page_config(page_title="월마감회비예측", page_icon=":material/monitoring:", layout="wide")

page = st.navigation([
    st.Page("app_pages/backdata.py", title="0. 월마감 백데이터", icon=":material/database:", url_path="backdata"),
    st.Page("app_pages/closing_reflect.py", title="1. 월마감반영", icon=":material/table_view:",
            url_path="closing", default=True),
    st.Page("app_pages/compare_monthly.py", title="2. 비교1(월별비교)", icon=":material/compare_arrows:",
            url_path="compare-monthly"),
    st.Page("app_pages/compare_yearly.py", title="3. 비교2(연도마감비교)", icon=":material/stacked_line_chart:",
            url_path="compare-yearly"),
], position="top")

st.title(page.title)
page.run()
