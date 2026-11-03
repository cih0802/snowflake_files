import streamlit as st
import os
import pandas as pd
import altair as alt

st.set_page_config(page_title="월간 회원개발실적", layout="wide")
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

# ---------------------------------------------------------------------------
# Styles
# ---------------------------------------------------------------------------
COMMON_CSS = """
<style>
.rpt { font-family:'Malgun Gothic','맑은 고딕',sans-serif; font-size:11px; }
.rpt table { width:100%; border-collapse:collapse; }
.rpt th, .rpt td { border:1px solid #bbb; padding:3px 6px; }
.rpt th { background:#D9E1F2; text-align:center; font-weight:bold; }
.rpt td { text-align:right; }
.rpt .l { text-align:left; }
.rpt .c { text-align:center; }
.rpt .grp { background:#F2F2F2; font-weight:bold; }
.rpt .sub { background:#FAFAFA; font-weight:bold; }
.rpt .total { background:#595959; color:#fff; font-weight:bold; }
.rpt .hq-sub { background:#A6A6A6; color:#fff; font-weight:bold; }
.rpt .nm-sub { background:#D6DCE4; font-weight:bold; }
.rpt .neg { color:#C00000; }
.rpt .pos { color:#0070C0; }
.rpt .bold { font-weight:bold; }
.rpt .unit { text-align:right; font-size:10px; color:#666; padding:2px 4px; }
.title-bar { text-align:center; font-size:18px; font-weight:bold; padding:12px 0 4px; }
</style>
"""


def f(v):
    if v is None or v == "" or v == "-":
        return "-"
    if isinstance(v, str):
        return v
    return f"{v:,.1f}"


def fp(v):
    if v is None or v == "" or v == "-":
        return "-"
    if isinstance(v, str):
        return v
    return f"{v:.0f}%"


def pct_cls(v):
    if not isinstance(v, (int, float)):
        return ""
    if v < 0:
        return ' class="neg"'
    return ""


# ---------------------------------------------------------------------------
# Data - Section 1: 2026년 8월 마감치
# ---------------------------------------------------------------------------
S1_ROWS = [
    # (indent, group_label, channel, m_target, m_actual, m_pct, c_target, c_actual, c_pct, y_target, y_pct)
    # 매체운영팀
    (2, "매체운영팀", "디지털",    12452, 8062.8,  65, 81613,  80479.8, 99,  124000, 65),
    (2, "",          "영상광고",   452,   899.0,  199, 2964,   6455.0, 218,  4500, 143),
    (2, "",          "재송출",    1556,  2200.2,  141, 10201, 16355.7, 160, 15500, 106),
    (2, "",          "콜개발",    1004,   934.1,   93, 6579,   6585.5, 100, 10000,  66),
    (1, "",          "소계",     15464, 12096.0,   78, 101357, 109876.0, 108, 154000, 71),
    # 마케팅기획1팀
    (2, "마케팅기획1팀", "방송",     None,    5.0, None, 700,   338.5,   48,  900,  38),
    (2, "",            "디지털",    620,  539.0,   87, 6320,  6393.5,  101, 10100,  63),
    (1, "",            "소계",      620,  544.0,   88, 7020,  6732.0,   96, 11000,  61),
    # 마케팅기획2팀
    (2, "마케팅기획2팀", "방송",     100,  141.5,  142, 7400,  7414.3,  100, 13400,  55),
    (2, "",            "뉴미디어",  None,    4.0, None, 900,   203.0,   23,  1800,  11),
    (2, "",            "디지털",    272,  363.3,  134, 2196,  1819.7,   83,  3300,  55),
    (1, "",            "소계",      372,  508.8,  137, 10496,  9437.0,   90, 18500,  51),
    # 컬쳐콘텐츠팀
    (2, "컬쳐콘텐츠팀", "디지털",    760,  249.8,   33, 7910,  4333.8,   55, 11500,  38),
    (1, "",            "소계",      760,  249.8,   33, 7910,  4333.8,   55, 11500,  38),
    # 나눔마케팅본부 소계
    (0, "", "나눔마케팅본부 소계",  17216, 13398.6, 78, 126783, 130378.8, 103, 195000, 67),
    # 회원참여팀
    (2, "회원참여팀", "온라인",      930, 1272.0, 137, 9760,  10348.4, 106, 13815,  75),
    (2, "",          "콜",          580,  605.5, 104, 6200,   6306.3, 102,  8740,  72),
    (2, "",          "오프라인",     35,   13.3,  38,  305,    233.8,  77,   445,  53),
    (1, "",          "소계",       1545, 1890.7, 122, 16265,  16888.5, 104, 23000,  73),
    # 기타 기업개발
    (2, "", "기타 기업개발(사회공헌협력팀)", None, 4.0, None, None, 88.0, None, None, None),
    # 본부 소계
    (0, "", "본부 소계",         18761, 15293.3, 82, 143048, 147355.3, 103, 218000, 68),
    # 대면모금, 시도본부
    (2, "", "대면모금",           2650, 3045.0, 115, 22970, 25038.7, 109, 30000, 83),
    (2, "", "시도본부 및 지부, 기타", 7562, 6981.1, 92, 72782, 51124.1, 70, 100000, 51),
    # 총계
    (0, "", "총 계",            28973, 25319.3, 87, 238800, 223518.1, 94, 348000, 64),
]


def build_section1():
    html = '<div class="rpt">'
    html += '<table><tr class="unit"><td colspan="10">(단위: 건, %)</td></tr>'
    html += "<thead><tr>"
    html += '<th rowspan="2" style="width:10%">구분</th>'
    html += '<th rowspan="2" style="width:10%"></th>'
    html += '<th colspan="3" style="width:24%">8월</th>'
    html += '<th colspan="3" style="width:24%">누 계</th>'
    html += '<th rowspan="2" style="width:9%">연목표</th>'
    html += '<th rowspan="2" style="width:7%">달성률(%)</th>'
    html += "</tr><tr>"
    html += "<th>목표</th><th>실 적</th><th>%</th>"
    html += "<th>목표</th><th>실 적</th><th>%</th>"
    html += "</tr></thead><tbody>"

    prev_grp = None
    for indent, grp, ch, mt, ma, mp, ct, ca, cp, yt, yp in S1_ROWS:
        is_subtotal = indent == 1
        is_grand = indent == 0

        if is_grand and "총 계" in ch:
            cls = "total"
        elif is_grand and "본부 소계" in ch:
            cls = "hq-sub"
        elif is_grand and "나눔마케팅" in ch:
            cls = "nm-sub"
        elif is_subtotal:
            cls = "sub"
        else:
            cls = ""

        row_cls = f' class="{cls}"' if cls else ""
        html += f"<tr{row_cls}>"

        if grp and grp != prev_grp:
            count = sum(1 for _, g, *_ in S1_ROWS if g == grp or (g == "" and prev_grp_match(grp, S1_ROWS)))
            count = count_group(grp, S1_ROWS)
            html += f'<td rowspan="{count}" class="l" style="vertical-align:middle;font-weight:bold;background:#F2F2F2;">{grp}</td>'
            prev_grp = grp
        elif grp == "" and indent >= 1 and not is_grand:
            pass
        elif is_grand:
            html += f'<td class="l" colspan="1">{""}</td>'

        html += f'<td class="l">{ch}</td>'
        html += f"<td>{f(mt)}</td><td>{f(ma)}</td><td>{fp(mp)}</td>"
        html += f"<td>{f(ct)}</td><td>{f(ca)}</td><td>{fp(cp)}</td>"
        html += f"<td>{f(yt)}</td><td>{fp(yp)}</td>"
        html += "</tr>"

    html += "</tbody></table></div>"
    return html


def count_group(grp_name, rows):
    counting = False
    count = 0
    for indent, g, ch, *_ in rows:
        if g == grp_name:
            counting = True
            count += 1
        elif counting and g == "":
            if indent == 0:
                break
            count += 1
        elif counting and g != "":
            break
    return count


def prev_grp_match(grp, rows):
    return False


# ---------------------------------------------------------------------------
# Data - Section 2: 전년도 실적 비교현황
# ---------------------------------------------------------------------------
S2_ROWS = [
    # (grp, ch, m25, m26, m_chg, c25, c26, c_chg)
    ("매체운영팀", "디지털",    12839.4, 8062.8,  -37, 77381.1, 80479.8,   4),
    ("",          "영상광고",    514.5,  899.0,   75,  6945.0,  6455.0,  -7),
    ("",          "재송출",     1621.4, 2200.2,   36, 10911.9, 16355.7,  50),
    ("",          "콜개발",      806.7,  934.1,   16,  6600.2,  6585.5,   0),
    ("",          "소계",      15782.0, 12096.0, -23, 101838.2, 109876.0,  8),
    ("마케팅기획1팀", "방송",      None,    5.0, None,    None,   338.5, None),
    ("",            "디지털",    776.6,  539.0,  -31,  6332.2,  6393.5,   1),
    ("",            "소계",      776.6,  544.0,  -30,  6332.2,  6732.0,   6),
    ("마케팅기획2팀", "방송",     3406.5,  141.5,  -96, 11408.0,  7414.3, -35),
    ("",            "뉴미디어",  1281.4,    4.0, -100,  1577.9,   203.0, -87),
    ("",            "디지털",     472.0,  363.3,  -23,  1840.5,  1819.7,  -1),
    ("",            "소계",      5159.9,  508.8,  -90, 14826.4,  9437.0, -36),
    ("컬쳐콘텐츠팀", "디지털",     604.0,  249.8,  -59,  5616.0,  4333.8, -23),
    ("",            "소계",       604.0,  249.8,  -59,  5616.0,  4333.8, -23),
    ("", "나눔마케팅본부 소계",  22322.5, 13398.6, -40, 128612.8, 130378.8,  1),
    ("회원참여팀", "온라인",      1174.9, 1272.0,    8,  9360.7, 10348.4,  11),
    ("",          "콜",           651.9,  605.5,   -7,  5906.2,  6306.3,   7),
    ("",          "오프라인",      13.0,   13.3,    2,   151.5,   233.8,  54),
    ("",          "소계",        1839.8, 1890.7,    3, 15418.4, 16888.5,  10),
    ("", "기타 기업개발(사회공헌협력팀)", 16.0, 4.0, -75, 123.0, 88.0, -28),
    ("", "본부 소계",           24178.3, 15293.3, -37, 144154.2, 147355.3,   2),
    ("", "대면모금",              932.3, 3045.0, 227,  3940.2, 25038.7, 535),
    ("", "시도본부 및 지부, 기타", 5725.2, 6981.1,  22, 62359.8, 51124.1, -18),
    ("", "총계 (본부+지부)",     30835.7, 25319.3, -18, 210454.2, 223518.1,  6),
]


def build_section2():
    html = '<div class="rpt">'
    html += '<table><tr class="unit"><td colspan="8">(단위: 건, %)</td></tr>'
    html += "<thead><tr>"
    html += '<th rowspan="2" colspan="2" style="width:20%">구분</th>'
    html += '<th colspan="3">8월</th>'
    html += '<th colspan="3">누계</th>'
    html += "</tr><tr>"
    html += "<th>2025년</th><th>2026년</th><th>증감률(%)</th>"
    html += "<th>2025년</th><th>2026년</th><th>증감률(%)</th>"
    html += "</tr></thead><tbody>"

    prev_grp = None
    for grp, ch, m25, m26, mc, c25, c26, cc in S2_ROWS:
        is_bold = "소계" in ch or "총계" in ch or "본부" in ch or "나눔" in ch
        is_total = "총계" in ch
        is_hq = "본부 소계" in ch
        is_nm = "나눔마케팅" in ch

        cls = ""
        if is_total:
            cls = "total"
        elif is_hq:
            cls = "hq-sub"
        elif is_nm:
            cls = "nm-sub"
        elif "소계" in ch:
            cls = "sub"

        rc = f' class="{cls}"' if cls else ""
        html += f"<tr{rc}>"

        if grp and grp != prev_grp:
            cnt = count_group_s2(grp, S2_ROWS)
            html += f'<td rowspan="{cnt}" class="l" style="vertical-align:middle;font-weight:bold;background:#F2F2F2;">{grp}</td>'
            prev_grp = grp
        elif not grp:
            pass

        html += f'<td class="l">{ch}</td>'

        mc_c = pct_cls(mc)
        cc_c = pct_cls(cc)
        html += f"<td>{f(m25)}</td><td>{f(m26)}</td><td{mc_c}>{fp(mc)}</td>"
        html += f"<td>{f(c25)}</td><td>{f(c26)}</td><td{cc_c}>{fp(cc)}</td>"
        html += "</tr>"

    html += "</tbody></table></div>"
    return html


def count_group_s2(grp_name, rows):
    counting = False
    count = 0
    for g, ch, *_ in rows:
        if g == grp_name:
            counting = True
            count += 1
        elif counting and g == "":
            if "소계" in ch and count > 0:
                count += 1
                break
            count += 1
        elif counting and g != "":
            break
    return count


# ---------------------------------------------------------------------------
# Data - Section 3: 4개년 개발현황
# ---------------------------------------------------------------------------
YEARLY_DATA = {
    "2023년": [21506, 22132, 16603, 15046, 15222, 13458, 15453, 13465, 10369, 11317, 16521, 19071],
    "2024년": [19034, 14961, 14612, 13944, 15033, 15535, 18169, 15762, 14605, 13742, 19571, 18553],
    "2025년": [19453, 18556, 17045, 13296, 13561, 18557, 19508, 24178, 16398, 12486, 20633, 20992],
    "2026년": [24224, 20220, 16082, 14485, 20709, 19764, 16578, 15293, None, None, None, None],
}

TEAM_COMPARE = {
    "매체운영팀":     (15782, 12096),
    "마케팅기획1팀":   (777,    544),
    "마케팅기획2팀":   (5160,   509),
    "컬쳐콘텐츠팀":   (604,    250),
    "회원참여팀":     (1840,  1891),
    "기타 기업개발":   (16,      4),
}

TEAM_CUM_COMPARE = {
    "매체운영팀":     (101838, 109876),
    "마케팅기획1팀":   (6332,   6732),
    "마케팅기획2팀":   (14826,  9437),
    "컬쳐콘텐츠팀":   (5616,   4334),
    "회원참여팀":     (15418, 16888),
    "기타 기업개발":   (123,     88),
}


def build_yearly_table():
    html = '<div class="rpt">'
    html += '<table><tr class="unit"><td colspan="14">(단위: 건)</td></tr><thead><tr>'
    html += "<th>구분</th>"
    for m in range(1, 13):
        html += f"<th>{m}월</th>"
    html += "<th>계</th></tr></thead><tbody>"
    for yr, vals in YEARLY_DATA.items():
        is26 = "2026" in yr
        total = sum(v for v in vals if v is not None)
        html += "<tr>"
        html += f'<td class="l bold">{yr}</td>'
        for v in vals:
            html += f"<td>{f'{v:,}' if v else ''}</td>"
        html += f"<td class='bold'>{total:,}</td>"
        html += "</tr>"
    html += "</tbody></table></div>"
    return html


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------
st.html(COMMON_CSS)
st.markdown('<div class="title-bar">2026년 8월 개발 현황</div>', unsafe_allow_html=True)
st.caption("2026. 09. 08.")

st.markdown("### 1. 회원개발")
st.markdown("#### 1) 2026년 8월 마감치")
st.html(build_section1())

st.divider()
st.markdown("#### 2) 전년도 실적 비교현황")
st.html(build_section2())

st.divider()
st.markdown("#### 3) 본부 4개년 개발현황 및 전월대비 증감")

# Line chart - 4-year monthly trend
months = list(range(1, 13))
chart_rows = []
for yr, vals in YEARLY_DATA.items():
    for i, v in enumerate(vals):
        if v is not None:
            chart_rows.append({"월": i + 1, "건수": v, "연도": yr})
line_df = pd.DataFrame(chart_rows)

line_chart = (
    alt.Chart(line_df)
    .mark_line(point=True, strokeWidth=2)
    .encode(
        x=alt.X("월:O", title="월"),
        y=alt.Y("건수:Q", title="건수", scale=alt.Scale(zero=False)),
        color=alt.Color("연도:N", title="연도"),
        tooltip=["연도", "월", "건수"],
    )
    .properties(height=350)
)
st.altair_chart(line_chart)
st.html(build_yearly_table())

# Bar charts - 2025 vs 2026
st.markdown("##### 2025년 vs 2026년 당월 비교 (8월, 단위: 건)")
team_rows = []
for team, (v25, v26) in TEAM_COMPARE.items():
    team_rows.append({"팀": team, "건수": v25, "연도": "8월 2025년"})
    team_rows.append({"팀": team, "건수": v26, "연도": "8월 2026년"})
team_df = pd.DataFrame(team_rows)

bar1 = (
    alt.Chart(team_df)
    .mark_bar()
    .encode(
        x=alt.X("팀:N", title="", sort=list(TEAM_COMPARE.keys())),
        y=alt.Y("건수:Q", title="건수"),
        color=alt.Color("연도:N"),
        xOffset="연도:N",
        tooltip=["팀", "연도", "건수"],
    )
    .properties(height=300)
)
st.altair_chart(bar1)

st.markdown("##### 2025년 VS 2026년 누계 비교 (단위: 건)")
cum_rows = []
for team, (v25, v26) in TEAM_CUM_COMPARE.items():
    cum_rows.append({"팀": team, "건수": v25, "연도": "2025년"})
    cum_rows.append({"팀": team, "건수": v26, "연도": "2026년"})
cum_df = pd.DataFrame(cum_rows)

bar2 = (
    alt.Chart(cum_df)
    .mark_bar()
    .encode(
        x=alt.X("팀:N", title="", sort=list(TEAM_CUM_COMPARE.keys())),
        y=alt.Y("건수:Q", title="건수"),
        color=alt.Color("연도:N"),
        xOffset="연도:N",
        tooltip=["팀", "연도", "건수"],
    )
    .properties(height=300)
)
st.altair_chart(bar2)

st.divider()
st.markdown("#### 4) 후원사업별 누계 회원 개발")

S4_ROWS = [
    ("매체운영팀", "국내",  76335, 53172.9, 70, 76335, 51118.4, 67, None, 2054.5, None),
    ("",          "결연",   9845,  6149.0, 62,  9845,  6149.0, 62, None, None, None),
    ("",          "해외",  46440, 42001.0, 90, 46440, 42001.0, 90, None, None, None),
    ("",          "기타",  21380,  8553.1, 40, 21380,  8553.1, 40, None, None, None),
    ("",          "소 계", 154000, 109876.0, 71, 154000, 107821.5, 70, None, 2054.5, None),
    ("마케팅기획1팀", "국내", 11000, 6721.5, 61, 11000, 6389.0, 58, None, 332.5, None),
    ("",            "결연", None, None, None, None, None, None, None, None, None),
    ("",            "해외", None, 9.0, None, None, 9.0, None, None, None, None),
    ("",            "기타", None, 1.5, None, None, 1.5, None, None, None, None),
    ("",            "소 계", 11000, 6732.0, 61, 11000, 6399.5, 58, None, 332.5, None),
    ("마케팅기획2팀", "국내", None, 1.0, None, None, 1.0, None, None, None, None),
    ("",            "결연", 9250, 4348.3, 47, 9250, 4348.3, 47, None, None, None),
    ("",            "해외", 9250, 5058.2, 55, 9250, 5058.2, 55, None, None, None),
    ("",            "기타", None, 29.5, None, None, 29.5, None, None, None, None),
    ("",            "소 계", 18500, 9437.0, 51, 18500, 9437.0, 51, None, None, None),
    ("컬쳐콘텐츠팀", "국내", None, 1.0, None, None, 1.0, None, None, None, None),
    ("",            "결연", None, None, None, None, None, None, None, None, None),
    ("",            "해외", 8780, 2613.9, 30, 8780, 2613.9, 30, None, None, None),
    ("",            "기타", 2720, 1718.9, 63, 2720, 1718.9, 63, None, None, None),
    ("",            "소 계", 11500, 4333.8, 38, 11500, 4333.8, 38, None, None, None),
    ("회원참여팀", "국내", 9660, 7812.1, 81, 9660, 6425.1, 67, None, 1387.0, None),
    ("",          "결연", 6910, 4811.7, 70, 6910, 4811.7, 70, None, None, None),
    ("",          "해외", 5520, 3433.7, 62, 5520, 3433.7, 62, None, None, None),
    ("",          "기타",  910,  831.0, 91,  910,  831.0, 91, None, None, None),
    ("",          "소 계", 23000, 16888.5, 73, 23000, 15501.5, 67, None, 1387.0, None),
    ("기타기업개발\n(사회공헌협력팀)", "국내", None, 13.0, None, None, 3.0, None, None, 10.0, None),
    ("",          "결연", None, 38.0, None, None, 38.0, None, None, None, None),
    ("",          "해외", None, 37.0, None, None, 37.0, None, None, None, None),
    ("",          "기타", None, None, None, None, None, None, None, None, None),
    ("",          "소 계", None, 88.0, None, None, 78.0, None, None, 10.0, None),
    ("본부 총계", "국내", 96995, 67721.5, 70, 96995, 63937.5, 66, None, 3784.0, None),
    ("",         "결연", 26005, 15347.0, 59, 26005, 15347.0, 59, None, None, None),
    ("",         "해외", 69990, 53152.8, 76, 69990, 53152.8, 76, None, None, None),
    ("",         "기타", 25010, 11134.0, 45, 25010, 11134.0, 45, None, None, None),
    ("",         "소 계", 218000, 147355.3, 68, 218000, 143571.3, 66, None, 3784.0, None),
]


def build_section4():
    html = '<div class="rpt">'
    html += '<table><tr class="unit"><td colspan="11">(단위: 건, %)</td></tr><thead>'
    html += "<tr>"
    html += '<th rowspan="2" colspan="2" style="width:16%">구 분</th>'
    html += '<th colspan="3">사단+사복 누계실적<br>(0101~0831)</th>'
    html += '<th colspan="3">사단법인 누계실적<br>(0101~0831)</th>'
    html += '<th colspan="3">사회복지법인 누계실적<br>(0101~0831)</th>'
    html += "</tr><tr>"
    html += "<th>연목표</th><th>누계실적</th><th>달성률(%)</th>" * 3
    html += "</tr></thead><tbody>"

    prev_grp = None
    for row in S4_ROWS:
        grp, ch = row[0], row[1]
        ss_target, ss_actual, ss_pct = row[2], row[3], row[4]
        sd_target, sd_actual, sd_pct = row[5], row[6], row[7]
        sf_target, sf_actual, sf_pct = row[8], row[9], row[10]

        is_sub = "소 계" in ch
        is_total = "본부 총계" in grp

        cls = ""
        if is_total and is_sub:
            cls = "total"
        elif is_total:
            cls = "hq-sub"
        elif is_sub:
            cls = "sub"

        rc = f' class="{cls}"' if cls else ""
        html += f"<tr{rc}>"

        if grp and grp != prev_grp:
            cnt = sum(1 for r in S4_ROWS if r[0] == grp) + sum(
                1 for i, r in enumerate(S4_ROWS)
                if r[0] == "" and i > 0 and is_child_of(grp, i, S4_ROWS)
            )
            cnt = count_grp_s4(grp, S4_ROWS)
            html += (
                f'<td rowspan="{cnt}" class="l" '
                f'style="vertical-align:middle;font-weight:bold;background:#F2F2F2;">'
                f'{grp.replace(chr(10), "<br>")}</td>'
            )
            prev_grp = grp
        elif not grp:
            pass

        html += f'<td class="l">{ch}</td>'
        html += f"<td>{f(ss_target)}</td><td>{f(ss_actual)}</td><td>{fp(ss_pct)}</td>"
        html += f"<td>{f(sd_target)}</td><td>{f(sd_actual)}</td><td>{fp(sd_pct)}</td>"
        html += f"<td>{f(sf_target)}</td><td>{f(sf_actual)}</td><td>{fp(sf_pct)}</td>"
        html += "</tr>"

    html += "</tbody></table></div>"
    return html


def is_child_of(grp, idx, rows):
    for i in range(idx - 1, -1, -1):
        if rows[i][0] != "":
            return rows[i][0] == grp
    return False


def count_grp_s4(grp_name, rows):
    counting = False
    count = 0
    for g, ch, *_ in rows:
        if g == grp_name:
            counting = True
            count += 1
        elif counting and g == "":
            count += 1
            if "소 계" in ch:
                break
        elif counting and g != "":
            break
    return count


st.html(build_section4())
