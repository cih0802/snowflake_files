"""여러 탭(페이지)이 같이 쓰는 모델 로드·계산 캐시·월마감 백데이터 조회·연월 선택."""
from __future__ import annotations

import os
from datetime import timedelta

import pandas as pd
import streamlit as st

import closing as C
import model as M


@st.cache_resource
def _load_model(version: tuple) -> dict:
    return M.load_model()


def get_model() -> dict:
    # model.json 이 바뀌면(수정시각/크기) 캐시를 새로 읽는다
    return _load_model(M.model_version())


@st.cache_resource(show_spinner=False, max_entries=64)
def compute_cached(version: tuple, ov_key: tuple) -> dict:
    # cache_resource: 결과를 pickle 하지 않고 메모리에 그대로 둔다 (XlError 객체 포함 가능, 읽기 전용으로만 사용)
    ov = {sheet: dict(items) for sheet, items in ov_key}
    # 실적이 0 인 달 등으로 생기는 0으로 나누기(#DIV/0!)는 0 으로 처리
    return M.compute_workbook(get_model()["sheets"], ov, div0_as_zero=True)


def ov_to_key(ov: dict) -> tuple:
    return tuple(sorted((n, tuple(sorted(d.items()))) for n, d in ov.items() if d))


def new_error_sheets(values: dict, base: dict) -> dict[str, int]:
    """실적/수정값 반영으로 새로 생긴 오류(#DIV/0! 등) 칸 수 — 사업 시트별."""
    from formula_engine import XlError
    out = {}
    for s in get_model()["sheets"]:
        if s["kind"] != "business":
            continue
        n = sum(1 for k, v in values[s["name"]].items()
                if isinstance(v, XlError) and not isinstance(base[s["name"]].get(k), XlError))
        if n:
            out[s["name"]] = n
    return out


def load_closing_raw() -> tuple[pd.DataFrame, str | None]:
    """Snowflake 월마감 집계 조회 (10분 캐시). 실패 시 (빈 DF, 오류 메시지)."""
    fixture = os.getenv("FEE_CLOSING_FIXTURE")  # 로컬 테스트용 CSV
    if fixture:
        return pd.read_csv(fixture), None
    try:
        conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
        df = conn.query(C.CLOSING_SQL, params=C.CLOSING_PARAMS, ttl=timedelta(minutes=10))
        return df, None
    except Exception as e:  # 권한/네트워크 오류여도 대시보드는 계획값으로 동작
        return pd.DataFrame(), f"{type(e).__name__}: {e}"


def closing_data() -> tuple[pd.DataFrame, str | None]:
    """정규화 + 허수회원 토글 적용된 월마감 데이터."""
    raw, err = load_closing_raw()
    df = C.normalize(raw)
    return C.apply_hosu(df, st.session_state.get("exclude_hosu", True)), err


def refresh_closing() -> None:
    st.cache_data.clear()


def _sync(src: str, dst: str) -> None:
    st.session_state[dst] = st.session_state[src]


def closing_selector(df: pd.DataFrame, page: str, err: str | None) -> tuple[int | None, int | None]:
    """탭 최상단 연도·월 선택 (0·1번 탭이 같은 선택값을 공유). 마감 없음 → (None, None)."""
    months = C.available_months(df)
    with st.container(border=True):
        if err:
            st.error(f"월마감 백데이터({C.SOURCE_VIEW}) 조회 실패 — 연사업계획 값으로 표시합니다.\n\n{err}",
                     icon=":material/cloud_off:")
        if not months:
            st.info("조회 가능한 월마감 데이터가 없습니다. 연사업계획(엑셀) 값으로 계산합니다.")
            return None, None
        years = sorted(months)
        st.session_state.setdefault("closing_year", years[-1])
        if st.session_state["closing_year"] not in years:
            st.session_state["closing_year"] = years[-1]
        c1, c2, c3, c4 = st.columns([1, 1, 2, 1], vertical_alignment="bottom")
        yk, mk, hk = f"{page}_year", f"{page}_month", f"{page}_hosu"
        st.session_state[yk] = st.session_state["closing_year"]
        year = c1.selectbox("연도", years, key=yk, format_func=lambda y: f"{y}년",
                            on_change=_sync, args=(yk, "closing_year"))
        ms = months[year]
        st.session_state.setdefault("closing_month", ms[-1])
        if st.session_state["closing_month"] not in ms:
            st.session_state["closing_month"] = ms[-1]
        st.session_state[mk] = st.session_state["closing_month"]
        month = c2.selectbox("마감월", ms, key=mk, format_func=lambda m: f"{m}월 마감",
                             on_change=_sync, args=(mk, "closing_month"))
        st.session_state[hk] = st.session_state.get("exclude_hosu", True)
        c3.toggle("허수회원 제외", key=hk, on_change=_sync, args=(hk, "exclude_hosu"), help=C.HOSU_NOTE)
        c4.button("새로고침", icon=":material/refresh:", on_click=refresh_closing,
                  help="Snowflake 최신 적재분을 다시 조회합니다.", width="stretch")
        st.caption(f"원천: {C.SOURCE_VIEW} · {year}년 1월~{month}월 마감 실적을 반영합니다.")
    return year, month
