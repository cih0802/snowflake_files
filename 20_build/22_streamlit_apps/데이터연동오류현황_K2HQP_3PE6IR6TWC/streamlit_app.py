import re
import html
import inspect
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pandas as pd
import streamlit as st
import streamlit.components.v1 as components
from snowflake.snowpark.context import get_active_session


# =========================================================
# 1. 기본 설정
# =========================================================
st.set_page_config(
    page_title="데이터 연동 오류 현황",
    page_icon="📋",
    layout="wide",
)

session = get_active_session()
KST = ZoneInfo("Asia/Seoul")

st.title("데이터 연동 오류 현황")
st.caption(
    "오류 발생 내역을 최신순으로 확인합니다. "
    "오류 현황에서는 요약 내용을, 오류 원문에서는 저장된 메시지 전체를 확인할 수 있습니다."
)


# =========================================================
# 2. 조회 조건
# =========================================================
today = datetime.now(KST).date()

c1, c2, c3 = st.columns([2, 1, 1])

with c1:
    date_range = st.date_input(
        "조회 기간",
        value=(today - timedelta(days=6), today),
        format="YYYY-MM-DD",
    )

with c2:
    selected_type = st.selectbox(
        "데이터 유형",
        ["전체", "영상매체", "디지털", "기타"],
    )

with c3:
    # 다른 입력창의 라벨 높이와 맞추기 위한 여백
    st.markdown(
        '<div style="height: 24px;"></div>',
        unsafe_allow_html=True,
    )

    refresh = st.button(
        "새로고침",
        use_container_width=True,
    )


keyword = st.text_input(
    "오류 검색",
    placeholder="파일명, 변수명, 오류 내용 등을 입력하세요.",
)


if len(date_range) != 2:
    st.info("조회 시작일과 종료일을 선택해 주세요.")
    st.stop()

start_date, end_date = date_range


# =========================================================
# 3. 데이터 조회
# ERR_DATETIME은 한국 현지 시각으로 저장된 것으로 가정
# =========================================================
@st.cache_data(ttl=60, show_spinner=False)
def load_errors(start, end):

    sql = """
        SELECT
            ERR_SEQ,
            ERR_DATETIME,
            DATA_TYPE,
            ERR_INFO
        FROM GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO
        WHERE ERR_DATETIME >= TO_TIMESTAMP_NTZ(?)
          AND ERR_DATETIME < TO_TIMESTAMP_NTZ(?)
        ORDER BY ERR_DATETIME DESC, ERR_SEQ DESC
    """

    return session.sql(
        sql,
        params=[
            f"{start} 00:00:00",
            f"{end} 00:00:00",
        ],
    ).to_pandas()


if refresh:
    load_errors.clear()


try:
    with st.spinner("오류 내역을 조회하고 있습니다."):
        df = load_errors(
            start_date.isoformat(),
            (end_date + timedelta(days=1)).isoformat(),
        )

except Exception as e:
    st.error(
        "오류 테이블을 조회하지 못했습니다. "
        "접근 권한과 테이블명을 확인해 주세요."
    )
    st.code(str(e), language=None)
    st.stop()


# =========================================================
# 4. 조회 결과 기본 처리
# =========================================================
if df.empty:
    st.success("선택한 기간에 저장된 오류가 없습니다.")
    st.stop()


df["DATA_TYPE"] = (
    df["DATA_TYPE"]
    .fillna("미분류")
    .astype(str)
)

df["ERR_INFO"] = (
    df["ERR_INFO"]
    .fillna("")
    .astype(str)
    .map(html.unescape)
)


# ERR_DATETIME 형식 정리
df["ERR_DATETIME"] = pd.to_datetime(
    df["ERR_DATETIME"],
    errors="coerce",
)


# =========================================================
# 5. 오류 유형 및 쉬운 요약
# 원문은 수정하지 않고 별도 요약 컬럼만 생성
# =========================================================
def describe_error(message):

    message = str(message)
    lower = message.lower()


    # -----------------------------------------------------
    # 파일 다운로드 오류
    # -----------------------------------------------------
    if "filenotdownloadable" in lower:
        return (
            "파일 다운로드",
            "현재 다운로드 방식으로 받을 수 없는 파일",
        )


    if "google drive" in lower:
        return (
            "파일 다운로드",
            "Google Drive 파일 다운로드 실패",
        )


    # -----------------------------------------------------
    # DB / 컬럼 매핑 오류
    # -----------------------------------------------------
    if (
        "db 매핑" in lower
        or "정의되지 않은 컬럼" in lower
    ):
        return (
            "컬럼 매핑",
            "원본 파일의 컬럼이 DB 매핑 정의와 일치하지 않음",
        )


    # -----------------------------------------------------
    # Python NameError 계열
    # -----------------------------------------------------
    if "is not defined" in lower:

        match = re.search(
            r"name\s+['\"](.+?)['\"]\s+is not defined",
            message,
            flags=re.IGNORECASE,
        )

        variable = (
            match.group(1)
            if match
            else "확인 필요"
        )

        return (
            "코드 오류",
            f"정의되지 않은 변수: {variable}",
        )


    # -----------------------------------------------------
    # 형변환 오류
    # -----------------------------------------------------
    if "failed to cast" in lower:

        match = re.search(
            r'variant value\s+"(.*?)"\s+to\s+(\w+)',
            message,
            flags=re.IGNORECASE | re.DOTALL,
        )

        if match:

            value, target = match.groups()

            if not value.strip():
                summary = (
                    f"빈 값을 {target} 형식으로 "
                    "변환하지 못함"
                )

            else:
                summary = (
                    f"값 [{value}]을 {target} 형식으로 "
                    "변환하지 못함"
                )

            return (
                "형변환 오류",
                summary,
            )

        return (
            "형변환 오류",
            "데이터 형식을 변환하지 못함",
        )


    # -----------------------------------------------------
    # SQL 오류
    # -----------------------------------------------------
    if (
        "sql compilation" in lower
        or "invalid identifier" in lower
    ):
        return (
            "SQL 오류",
            "SQL 구문 또는 컬럼명 확인 필요",
        )


    # -----------------------------------------------------
    # 그 외 오류
    # -----------------------------------------------------
    compact = " ".join(
        message.split()
    )

    summary = (
        compact[:100]
        + ("…" if len(compact) > 100 else "")
    )

    return (
        "기타",
        summary,
    )


descriptions = df["ERR_INFO"].map(
    describe_error
)

df["오류 유형"] = descriptions.map(
    lambda item: item[0]
)

df["오류 요약"] = descriptions.map(
    lambda item: item[1]
)


# =========================================================
# 6. 필터 적용
# =========================================================
if selected_type == "기타":

    df = df[
        ~df["DATA_TYPE"].isin(
            ["영상매체", "디지털"]
        )
    ].copy()


elif selected_type != "전체":

    df = df[
        df["DATA_TYPE"] == selected_type
    ].copy()


# ---------------------------------------------------------
# 검색어 필터
# ---------------------------------------------------------
if keyword.strip():

    search_text = (
        df["ERR_INFO"].fillna("")
        + " "
        + df["DATA_TYPE"].fillna("")
        + " "
        + df["오류 유형"].fillna("")
        + " "
        + df["오류 요약"].fillna("")
    )

    df = df[
        search_text.str.contains(
            keyword.strip(),
            case=False,
            regex=False,
            na=False,
        )
    ].copy()


if df.empty:
    st.info(
        "선택한 조건에 해당하는 오류가 없습니다."
    )
    st.stop()


# =========================================================
# 7. 최신 오류부터 정렬
# 중요: df 생성/필터링이 끝난 후 실행
# =========================================================
display_df = df.sort_values(
    ["ERR_DATETIME", "ERR_SEQ"],
    ascending=[False, False],
).copy()


# =========================================================
# 8. 상단 요약
# =========================================================
total_count = len(display_df)

error_type_count = (
    display_df["오류 유형"]
    .nunique()
)

latest_time = (
    display_df["ERR_DATETIME"]
    .max()
)


m1, m2, m3 = st.columns(3)


with m1:
    st.metric(
        "오류 건수",
        f"{total_count:,}건",
    )


with m2:
    st.metric(
        "오류 유형",
        f"{error_type_count:,}개",
    )


with m3:

    if pd.notna(latest_time):

        latest_text = (
            latest_time.strftime(
                "%Y-%m-%d %H:%M"
            )
        )

    else:
        latest_text = "-"

    st.metric(
        "최근 발생",
        latest_text,
    )


st.markdown("")


# =========================================================
# 9. 탭 구성
# =========================================================
tab_summary, tab_original = st.tabs(
    [
        "오류 현황",
        "오류 원문",
    ]
)


# =========================================================
# 10. 오류 현황 탭
# =========================================================
with tab_summary:

    st.subheader(
        f"오류 현황 · {len(display_df):,}건"
    )

    st.caption(
        "오류 원문을 기준으로 유형과 주요 내용을 "
        "쉽게 확인할 수 있도록 정리한 화면입니다."
    )


    summary_df = display_df[
        [
            "ERR_SEQ",
            "ERR_DATETIME",
            "DATA_TYPE",
            "오류 유형",
            "오류 요약",
        ]
    ].copy()


    summary_df = summary_df.rename(
        columns={
            "ERR_SEQ": "번호",
            "ERR_DATETIME": "발생 시각",
            "DATA_TYPE": "데이터 유형",
        }
    )


    # 발생 시각 문자열 변환
    summary_df["발생 시각"] = (
        pd.to_datetime(
            summary_df["발생 시각"],
            errors="coerce",
        )
        .dt.strftime(
            "%Y-%m-%d %H:%M:%S"
        )
    )


    st.dataframe(
        summary_df,
        use_container_width=True,
        hide_index=True,
        height=620,
        column_config={

            "번호": st.column_config.NumberColumn(
                "번호",
                width="small",
            ),

            "발생 시각": st.column_config.TextColumn(
                "발생 시각",
                width="medium",
            ),

            "데이터 유형": st.column_config.TextColumn(
                "데이터 유형",
                width="small",
            ),

            "오류 유형": st.column_config.TextColumn(
                "오류 유형",
                width="small",
            ),

     "오류 요약": st.column_config.TextColumn(
                "오류 요약",
                width="large",
            ),
        },
    )


    st.caption(
        "열 제목을 클릭하면 해당 열을 기준으로 "
        "오름차순/내림차순 정렬할 수 있습니다."
    )


# =========================================================
# 11. 오류 원문 탭
# =========================================================
with tab_original:

    st.subheader(
        f"오류 원문 · {len(display_df):,}건"
    )

    st.caption(
        "DB에 저장된 오류 메시지를 전체 내용으로 확인합니다."
    )


    # -----------------------------------------------------
    # HTML 특수문자 처리
    # -----------------------------------------------------
    def escape_text(value):

        if pd.isna(value):
            return ""

        return html.escape(
            str(value)
        )


    rows = []


    # -----------------------------------------------------
    # 원문 테이블 행 생성
    # -----------------------------------------------------
    for _, row in display_df.iterrows():

        timestamp = row[
            "ERR_DATETIME"
        ]


        if pd.notna(timestamp):

            if hasattr(
                timestamp,
                "strftime",
            ):
                time_text = (
                    timestamp.strftime(
                        "%Y-%m-%d\n%H:%M:%S"
                    )
                )

            else:
                time_text = str(
                    timestamp
                )

        else:
            time_text = ""


        rows.append(
            "<tr>"
            f'<td class="err-number">'
            f'{escape_text(row["ERR_SEQ"])}'
            "</td>"
            f'<td class="err-time">'
            f'{escape_text(time_text)}'
            "</td>"
            f'<td class="err-type">'
            f'{escape_text(row["DATA_TYPE"])}'
            "</td>"
            f'<td class="err-message">'
            f'{escape_text(row["ERR_INFO"])}'
            "</td>"
            "</tr>"
        )


    # =====================================================
    # 11-1. 원문 테이블 HTML
    # =====================================================
    table_html = """
    <style>

    .error-original-wrap {
        width: 100%;
        border: 1px solid #e2e6eb;
        border-radius: 8px;
        overflow: hidden;
        background: #ffffff;
    }


    .error-original-table {
        width: 100%;
        table-layout: fixed;
        border-collapse: collapse;
        font-size: 13px;
        color: #334155;
        background: #ffffff;
    }


    .error-original-table th {
        padding: 12px;
        background: #f5f7fa;
        color: #475569;
        font-weight: 600;
        text-align: left;
        border-bottom: 1px solid #e2e6eb;

        cursor: pointer;
        user-select: none;

        position: sticky;
        top: 0;
        z-index: 1;
    }


    .error-original-table th:hover {
        background: #e8eef6;
    }


    .error-original-table td {
        padding: 14px 12px;
        vertical-align: top;

        border-bottom:
            1px solid #e8ecf0;

        line-height: 1.7;
    }


    .error-original-table th + th,
    .error-original-table td + td {
        border-left:
            1px solid #e8ecf0;
    }


    .error-original-table
    tbody tr:nth-child(even) {
        background: #fafbfc;
    }


    .error-original-table
    tbody tr:hover {
        background: #f0f5fb;
    }


    .error-original-table
    tbody tr:last-child td {
        border-bottom: none;
    }


    .error-original-table
    .err-number {
        text-align: center;
        color: #64748b;
    }


    .error-original-table
    .err-time {
        white-space: pre-line;

        font-size: 12px;
        color: #64748b;
    }


    .error-original-table
    .err-type {
        overflow-wrap: anywhere;
        font-weight: 600;
    }


    .error-original-table
    .err-message {
        white-space: pre-wrap;

        overflow-wrap: anywhere;
        word-break: normal;

        color: #1f2937;

        font-family:
            Consolas,
            "Courier New",
            monospace;

        font-size: 12px;
    }


    .error-sort-arrow {
        margin-left: 5px;

        color: #64748b;

        font-size: 11px;
    }

    </style>


    <div class="error-original-wrap">

        <table class="error-original-table">

            <colgroup>
                <col style="width: 6%;">
                <col style="width: 13%;">
                <col style="width: 9%;">
                <col style="width: 72%;">
            </colgroup>


            <thead>

                <tr>
                    <th>번호</th>
                    <th>발생 시각</th>
                    <th>데이터 유형</th>
                    <th>오류 원문</th>
                </tr>

            </thead>


            <tbody>
    """ + "".join(rows) + """
            </tbody>

        </table>

    </div>
    """


    # =====================================================
    # 11-2. 원문 테이블 정렬 JavaScript
    # =====================================================
    sort_script = """
    <script>

    (function () {

        const table =
            document.querySelector(
                ".error-original-table"
            );

        if (!table) {
            return;
        }


        const tbody =
            table.querySelector(
                "tbody"
            );


        const headers =
            Array.from(
                table.querySelectorAll(
                    "thead th"
                )
            );


        let sortedColumn = -1;
        let ascending = true;


        headers.forEach(
            (header, columnIndex) => {


                const label =
                    header.textContent.trim();


                const arrow =
                    document.createElement(
                        "span"
                    );


                arrow.className =
                    "error-sort-arrow";

                arrow.textContent =
                    "↕";


                header.appendChild(
                    arrow
                );


                header.tabIndex = 0;

                header.title =
                    label + " 정렬";


                header.setAttribute(
                    "aria-sort",
                    "none"
                );


                function sortRows() {


                    ascending = (
                        sortedColumn
                        === columnIndex
                    )
                        ? !ascending
                        : true;


                    sortedColumn =
                        columnIndex;


                    const tableRows =
                        Array.from(
                            tbody.rows
                        );


                    tableRows.sort(
                        (rowA, rowB) => {


                            const valueA =
                                rowA
                                    .cells[
                                        columnIndex
                                    ]
                                    .textContent
                                    .trim();


                            const valueB =
                                rowB
                                    .cells[
                                        columnIndex
                                    ]
                                    .textContent
                                    .trim();


                            let comparison;


                            // 번호
                            if (
                                columnIndex === 0
                            ) {

                                const numberA =
                                    Number(
                                        valueA
                                    );

                                const numberB =
                                    Number(
                                        valueB
                                    );


                                if (
                                    !Number.isNaN(
                                        numberA
                                    )
                                    &&
                                    !Number.isNaN(
                                        numberB
                                    )
                                ) {

                                    comparison =
                                        numberA
                                        - numberB;

                                } else {

                                    comparison =
                                        valueA.localeCompare(
                                            valueB,
                                            "ko",
                                            {
                                                numeric:
                                                    true
                                            }
                                        );
                                }

                            } else {

                                comparison =
                                    valueA.localeCompare(
                                        valueB,
                                        "ko",
                                        {
                                            numeric:
                                                true
                                        }
                                    );
                            }


                            return ascending
                                ? comparison
                                : -comparison;

                        }
                    );


                    tableRows.forEach(
                        row =>
                            tbody.appendChild(
                                row
                            )
                    );


                    headers.forEach(
                        (item, index) => {


                            const active =
                                index
                                === columnIndex;


                            const currentArrow =
                                item.querySelector(
                                    ".error-sort-arrow"
                                );


                            if (
                                currentArrow
                            ) {

                                currentArrow.textContent =
                                    active
                                        ? (
                                            ascending
                                                ? "▲"
                                                : "▼"
                                        )
                                        : "↕";
                            }


                            item.setAttribute(
                                "aria-sort",

                                active
                                    ? (
                                        ascending
                                            ? "ascending"
                                            : "descending"
                                    )
                                    : "none"
                            );
                        }
                    );
                }


                header.addEventListener(
                    "click",
                    sortRows
                );


                header.addEventListener(
                    "keydown",
                    function (event) {

                        if (
                            event.key
                            === "Enter"
                            ||
                            event.key
                            === " "
                        ) {

                            event.preventDefault();

                            sortRows();
                        }
                    }
                );
            }
        );

    })();

    </script>
    """


    sortable_html = (
        table_html
        + sort_script
    )


    # =====================================================
    # 11-3. Streamlit 버전에 따른 HTML 출력
    # =====================================================
    supports_javascript = False


    if hasattr(
        st,
        "html",
    ):

        try:

            supports_javascript = (
                "unsafe_allow_javascript"
                in inspect.signature(
                    st.html
                ).parameters
            )

        except Exception:
            supports_javascript = False


    if supports_javascript:

        st.html(
            sortable_html,
            unsafe_allow_javascript=True,
        )


    else:

        components.html(
            """
            <style>

            body {
                margin: 0;

                font-family:
                    -apple-system,
                    BlinkMacSystemFont,
                    "Segoe UI",
                    sans-serif;
            }

            </style>
            """
            + sortable_html,

            height=800,
            scrolling=True,
        )


    st.caption(
        "열 제목 클릭: 오름차순 ▲ / 다시 클릭: 내림차순 ▼ · "
        "조회 조건 변경이나 새로고침 시 최신순으로 돌아갑니다."
    )