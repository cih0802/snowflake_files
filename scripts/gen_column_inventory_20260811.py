"""GN_DW SILVER/GOLD 컬럼 인벤토리 CSV 생성 (라이브 메타데이터 기준).

30_output_share/02_{SILVER,gold} 스키마 컬럼 인벤토리_<날짜>.csv 를 생성한다.
스키마 구조·COMMENT 의 소유자는 DDL 이며, 본 스크립트는 라이브 카탈로그를 그대로 사영한다.
"""
import csv
import os
import re
import sys

import snowflake.connector

WS = os.environ.get("GN_DW_WS", "/workspace")
AS_OF = sys.argv[1] if len(sys.argv) > 1 else "20260903"
OUT_DIR = os.environ.get("GN_DW_OUT", os.path.join(WS, "30_output_share"))
PREV_DIR = os.path.join(WS, "30_output_share", "_archive", "20260806")
PREV_TAG = "20260811"

HEADER = ["테이블명", "테이블 한글명", "GRAIN", "테이블유형", "컬럼명", "컬럼 한글명", "타입", "NULLABLE",
          "키", "FK_타깃", "설명", "주의_제약(DDL)"]

AUDIT_PREFIX = "DW_"

TABLE_KOR_MAP = {
    # GOLD DIM
    "DIM_AD_CREATIVE": "광고소재/매체 차원",
    "DIM_BUDGET_ITEM": "예산 세세목 차원",
    "DIM_CAMPAIGN": "캠페인 차원",
    "DIM_DATE": "날짜 차원",
    "DIM_DEVICE": "디바이스 차원",
    "DIM_EVENT": "행사/이벤트 차원",
    "DIM_BIGQUERY_EVENT": "BigQuery 이벤트분류 차원",
    "DIM_BIGQUERY_SOURCE": "BigQuery 트래픽소스 차원",
    "DIM_MARKETING_CAMPAIGN": "마케팅캠페인 차원",
    "DIM_MEMBER": "회원 차원",
    "DIM_MEMBER_ACQUISITION": "회원 획득 귀속 차원",
    "DIM_MEMBER_CURRENT": "회원 현재행 차원",
    "DIM_MEMBER_IDENTITY": "회원 신원 브리지 차원",
    "DIM_MONTH": "월 차원",
    "DIM_ORG": "조직 차원",
    "DIM_PAYMENT": "납입×결제×회비유형 차원",
    "DIM_REASON": "사유코드 차원",
    "DIM_SEND_TYPE": "발송구분 차원",
    "DIM_SERVICE": "서비스 차원",
    "DIM_SPONSORSHIP": "후원사업 차원",
    # GOLD FACT
    "FACT_AD_BROADCAST": "광고성과 위성(방송)",
    "FACT_AD_BROADCAST_CASE": "광고성과 위성(재방송 사례)",
    "FACT_AD_DIGITAL": "광고성과 위성(디지털)",
    "FACT_AD_PERFORMANCE": "광고성과 코어 팩트",
    "FACT_BUDGET": "예산 팩트",
    "FACT_BUDGET_YEARLY": "연 예산 팩트",
    "FACT_DEV_ACHIEVEMENT": "회원개발 목표 대비 실적 팩트",
    "FACT_EVENT_PARTICIPATION": "행사 참여 팩트",
    "FACT_BIGQUERY_BEHAVIOR": "BigQuery 행동 팩트",
    "FACT_MEMBER_COHORT": "회원 획득 코호트 팩트",
    "FACT_MEMBER_EVENT": "회원 이벤트 팩트",
    "FACT_MEMBER_FEE": "회비 분해 팩트",
    "FACT_MEMBER_MONTHLY": "회원 월 팩트",
    "FACT_MEMBER_SPONSOR_BIZ": "회원×후원약정 팩트",
    "FACT_SERVICE_EVENT": "서비스/발송 이벤트 팩트",
    "FACT_TARGET_BIZ": "사업 목표 팩트",
    "FACT_TARGET_DEV": "회원개발 목표 팩트",
    # GOLD WIDE
    "WIDE_AD_BROADCAST": "방송광고 위성 팩트 평탄화",
    "WIDE_AD_BROADCAST_CASE": "재방송 사례 위성 팩트 평탄화",
    "WIDE_AD_COMBINED": "광고 팩트 통합 소비뷰",
    "WIDE_AD_DIGITAL": "디지털광고 위성 팩트 평탄화",
    "WIDE_AD_PERFORMANCE": "광고 성과 코어 팩트 평탄화",
    "WIDE_BUDGET": "예산 팩트 평탄화",
    "WIDE_EVENT_PARTICIPATION": "행사 참여 팩트 평탄화",
    "WIDE_BIGQUERY_BEHAVIOR": "BigQuery 행동 팩트 평탄화",
    "WIDE_MEMBER_EVENT": "회원 이벤트 팩트 평탄화",
    "WIDE_MEMBER_FEE": "회비 분해 팩트 평탄화",
    "WIDE_MEMBER_MONTHLY": "회원 월 팩트 평탄화",
    "WIDE_SERVICE_EVENT": "서비스/발송 팩트 평탄화",
    "WIDE_TARGET_BIZ": "사업목표 팩트 평탄화",
    "WIDE_TARGET_DEV": "회원개발 목표 팩트 평탄화",
    # SILVER
    "AGENCY_AD_BROADCAST": "방송광고 고유속성 위성",
    "AGENCY_AD_BROADCAST_CASE": "재방송 사례 언피벗 위성",
    "AGENCY_AD_CREATIVE": "광고 소재/매체 차원",
    "AGENCY_AD_DIGITAL": "디지털광고 고유속성 위성",
    "AGENCY_AD_PERFORMANCE": "광고성과 3소스 통합",
    "AGENCY_AD_ROW_DGT": "디지털광고 원천 무손실 staging",
    "AGENCY_AD_ROW_REBRDC": "재방송광고 원천 무손실 staging",
    "AGENCY_AD_ROW_VIDEO": "방송광고 원천 무손실 staging",
    "BIGQUERY_BASIC": "GA4 기반 테이블",
    "BIGQUERY_DEVICE": "GA 디바이스",
    "BIGQUERY_EVENT": "GA 이벤트 팩트 소스",
    "BIGQUERY_EVENT_DIM": "GA 이벤트분류",
    "BIGQUERY_IDENTITY": "GA 신원",
    "BIGQUERY_REFINED_DATA": "BigQuery 정제 데이터",
    "BIGQUERY_TRAFFIC_SOURCE": "GA 트래픽소스",
    "CRM_BIZ_TARGET": "사업목표 마스터",
    "CRM_CAMPAIGN": "캠페인 마스터",
    "CRM_CODE": "코드사전",
    "CRM_DEV_TARGET": "회원개발 목표",
    "CRM_EVENT": "행사 마스터",
    "CRM_EVENT_PARTICIPATION": "행사 참여자",
    "CRM_MARKETING_CAMPAIGN": "마케팅캠페인 마스터",
    "CRM_MEMBER": "회원 통합",
    "CRM_MEMBER_AMT_CHANGE": "약정 증감",
    "CRM_MEMBER_DEV": "개발약정",
    "CRM_MEMBER_DISCONTINUE": "후원중단",
    "CRM_MEMBER_RESPONSOR": "재후원",
    "CRM_MEMBER_SPONSOR_BIZ": "회원×후원약정",
    "CRM_MEMBER_SPONSOR_SPAN": "회원×후원약정 활동구간",
    "CRM_MEMBER_STATUS_HIST": "회원 상태전이 이력",
    "CRM_ORG": "조직 마스터",
    "CRM_PAYMENT_BILLING": "납입/청구",
    "CRM_PAYMENT_METHOD": "결제수단",
    "CRM_RELATION_ACTIVITY": "결연활동",
    "CRM_SEND_MEMBER": "발송×회원 상세",
    "CRM_SEND_REQUEST": "발송요청 마스터",
    "CRM_SEND_RESULT": "발송×채널 집계",
    "CRM_SPONSORSHIP": "후원사업 마스터",
    "CRM_SPONSOR_RELATION": "결연(아동)",
    "ERP_BUDGET": "예산 편성/추경/조정/집행",
    "ERP_BUDGET_ITEM": "예산과목 마스터",
    "ERP_BUDGET_YEARLY": "예산 연 총액",
    "IDENTITY_MEMBER_XREF": "신원 브리지",
}

COL_KOR_EXPLICIT = {
    # 공통 감사 컬럼
    "DW_SOURCE_SYSTEM": "원천 시스템 식별",
    "DW_SOURCE_TABLE": "원천 테이블 식별",
    "DW_LOAD_TS": "최초 적재 시각",
    "DW_UPDATE_TS": "최종 갱신 시각",
    "DW_BATCH_ID": "적재 배치 식별자",
    # BigQuery / GA4
    "EVENT_SEQ": "이벤트 순번",
    "ID_SCHEME": "식별자 체계",
    "BIGQUERY_EVENT_SK": "BigQuery 이벤트 대리키",
    "BIGQUERY_SOURCE_SK": "BigQuery 트래픽소스 대리키",
    "BIGQUERY_MEMBER_ID": "BigQuery 회원 ID",
    "BIGQUERY_EVENT_CATEGORY": "BigQuery 이벤트 카테고리",
    "BIGQUERY_EVENT_LABEL": "BigQuery 이벤트 라벨",
    "BIGQUERY_EVENT_ACTION": "BigQuery 이벤트 액션",
    "BIGQUERY_UTM_SOURCE": "BigQuery UTM 소스",
    "BIGQUERY_UTM_MEDIUM": "BigQuery UTM 매체",
    "BIGQUERY_UTM_CONTENT": "BigQuery UTM 콘텐츠",
    "BIGQUERY_UTM_TERM": "BigQuery UTM 검색어",
    "BIGQUERY_SOURCE_MEDIUM": "BigQuery 소스/매체",
    "GA_SESSION_NUMBER": "GA 세션 번호",
    "ENGAGEMENT_TIME_MSEC": "참여 시간(밀리초)",
    "EVENT_CATEGORY": "이벤트 카테고리",
    "PERCENT_SCROLLED": "스크롤 비율",
    "DEVICE_TYPE": "기기 유형",
    "UTM_SOURCE": "UTM 소스",
    "UTM_MEDIUM": "UTM 매체",
    "UTM_CAMPAIGN": "UTM 캠페인",
    "UTM_CONTENT": "UTM 콘텐츠",
    "UTM_TERM": "UTM 검색어",
    "XCHAN_SOURCE": "크로스채널 소스",
    "XCHAN_MEDIUM": "크로스채널 매체",
    "XCHAN_CAMPAIGN": "크로스채널 캠페인",
    "GAC_SOURCE": "Google Ads 소스",
    "GAC_MEDIUM": "Google Ads 매체",
    "GAC_CAMPAIGN": "Google Ads 캠페인",
    "TARGET_GROUP": "타겟그룹",
    "AD_SOURCE_TYPE": "광고 원천유형",
    "EVENT_KIND": "행사 종류",
    "EVENT_CATEGORY_GROUP": "행사 카테고리 그룹",
    "EVENT_CATEGORY_NAME": "행사 카테고리명",
    "EVENT_NAME": "행사명/이벤트명",
    "EVENT_START_DATE": "행사 시작일",
    "EVENT_END_DATE": "행사 종료일",
    "EVENT_PLACE": "행사 장소",
    "EVENT_STATUS": "행사 상태",
    "MARKETING_CAMPAIGN": "마케팅캠페인",
    "INFLOW_PATH": "유입경로",
    "CAMPAIGN_TYPE": "캠페인 유형",
    "DOMESTIC_OVERSEAS": "국내/해외 구분",
    "BIZ_CASE_TYPE": "사업/사례 구분",
    "CPR_DIV_CD": "법인구분코드",
    "SPNSR_DIV_CD": "후원구분코드",
    "CMMN_BRND": "공통브랜드",
    "MKTG_UTM": "마케팅 UTM",
    "PAID_SPONSOR_BIZ_CNT": "유효 납입 후원사업 수",
    "NEW_FLAG": "신규 여부",
    "AD_PERF_DK": "광고성과 불변키",
    "MBER_INFLOW_PATH_NM": "회원 유입경로명",
    "PARTCPT_STAT_GROUP": "참여상태 그룹",
    "CMPGN_TY_NM": "캠페인 유형명",
    "EMAIL_STAT_CD": "이메일 상태코드",
    "ETC_CTTPC_REL_CD": "기타연락처 관계코드",
    "ETC_CTTPC_STAT_CD": "기타연락처 상태코드",
    "ETC_TSTM_DIV_CD": "기타 증서구분코드",
    "MOBLPHON_STAT_CD": "휴대폰 상태코드",
    "RELATNSP_DIV_CD": "결연 관계구분코드",
    "SLRCLD_LRR_CD": "급여공제 코드",
    "TSTM_DIV_CD": "증서구분코드",
}


def derive_table_korean_name(table, tbl_comment):
    if table in TABLE_KOR_MAP:
        return TABLE_KOR_MAP[table]
    if not tbl_comment:
        return table
    c = re.sub(r"[🔴🟢⛔⚠️🟡🟠]", "", tbl_comment).strip()
    c = re.sub(r"^\[[^\]]+\]\s*", "", c).strip()
    head = re.split(r"[.。\n(—]", c)[0].strip()
    return head or table


def derive_column_korean_name(table, col, col_comment):
    if (table, col) in COL_KOR_EXPLICIT:
        return COL_KOR_EXPLICIT[(table, col)]
    if col in COL_KOR_EXPLICIT:
        return COL_KOR_EXPLICIT[col]
    if not col_comment:
        return col

    c = col_comment.strip()
    c = re.sub(r"\[(원천보존|파생|코어|비가산)\]", "", c).strip()
    c = re.sub(r"[🔴🟢⛔⚠️🟡🟠]", "", c).strip()

    # WIDE 뷰 형식: TABLE.COL — 설명
    m = re.match(r"^[A-Z0-9_]+\.[A-Z0-9_]+\s*—\s*(.*)$", c)
    if m:
        c = m.group(1).strip()

    for sep in (" ← ", " — ", " -> ", " → "):
        if sep in c:
            c = c.split(sep)[0].strip()

    c = re.split(r"[.\n]", c)[0].strip()
    c = re.sub(r"\(#[0-9·, ]+\)", "", c).strip()
    c = re.sub(r"#[0-9·, ]+", "", c).strip()
    c = re.sub(r"코드id:[A-Za-z0-9_]+", "", c).strip()
    c = re.sub(r"\[사유:[^\]]+\]", "", c).strip()
    c = re.sub(r"\[[^\]]*전용[^\]]*\]", "", c).strip()
    c = re.sub(r"\[[^\]]*\]", "", c).strip()
    c = re.sub(r"\[[^\]]*$", "", c).strip()  # 닫히지 않은 대괄호 제거
    c = re.sub(r"\((?:ETL[^\)]*|PK[^\)]*|조인용|코드\s*라벨|자연키|원천[^\)]*)\)", "", c).strip()
    c = re.sub(r"\([^\)]*$", "", c).strip()  # 닫히지 않은 소괄호 제거

    c = c.strip(" ,.-·:;")
    if not c or c == col:
        return col
    return c


def connect():
    tok = open(os.environ["SNOWFLAKE_TOKEN_FILE_PATH"]).read().strip()
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        host=os.environ["SNOWFLAKE_HOST"],
        token=tok,
        authenticator="oauth",
        role=os.environ.get("SNOWFLAKE_ROLE"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE"),
        database="GN_DW",
    )


def q(cur, sql):
    cur.execute(sql)
    cols = [c[0] for c in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def fmt_type(r):
    t = r["DATA_TYPE"]
    if t in ("TEXT", "VARCHAR", "STRING"):
        return "VARCHAR"
    if t in ("NUMBER", "DECIMAL", "NUMERIC", "FIXED"):
        p, s = r["NUMERIC_PRECISION"], r["NUMERIC_SCALE"]
        if p is None:
            return "NUMBER"
        return f"NUMBER({p},{s if s is not None else 0})"
    if t == "FLOAT":
        return "FLOAT"
    if t == "BOOLEAN":
        return "BOOLEAN"
    if t.startswith("TIMESTAMP_"):
        return t
    return t


# GRAIN: 테이블 COMMENT 에 명시된 grain 선언 또는 정본 표준 grain 매핑을 사용한다.
TABLE_GRAIN_MAP = {
    # GOLD DIM
    "DIM_AD_CREATIVE": "1소재/매체 (AD_CREATIVE_SK)",
    "DIM_BUDGET_ITEM": "1예산 세세목 (BUDGET_ITEM_SK)",
    "DIM_CAMPAIGN": "1캠페인 (CAMPAIGN_SK)",
    "DIM_DATE": "1일 (DATE_SK)",
    "DIM_DEVICE": "1디바이스 (DEVICE_SK)",
    "DIM_EVENT": "1행사 (EVENT_SK)",
    "DIM_BIGQUERY_EVENT": "1BigQuery 이벤트분류 (BIGQUERY_EVENT_SK)",
    "DIM_BIGQUERY_SOURCE": "1BigQuery 트래픽소스 (BIGQUERY_SOURCE_SK)",
    "DIM_MARKETING_CAMPAIGN": "1마케팅캠페인 (MARKETING_CAMPAIGN_SK)",
    "DIM_MEMBER": "회원 × 상태버전 (SCD2, MEMBER_SK)",
    "DIM_MEMBER_ACQUISITION": "1회원 획득시점 (MEMBER_DK)",
    "DIM_MEMBER_CURRENT": "1회원 현재상태 (MEMBER_DK)",
    "DIM_MEMBER_IDENTITY": "MEMBER_DK × BigQuery member_id (1신원브리지)",
    "DIM_MONTH": "1개월 (MONTH_KEY)",
    "DIM_ORG": "1조직노드 (ORG_SK)",
    "DIM_PAYMENT": "납입 × 결제 × 회비유형 (PAYMENT_SK)",
    "DIM_REASON": "1사유코드 (REASON_SK)",
    "DIM_SEND_TYPE": "대 × 중 × 소 발송계층 (SEND_TYPE_SK)",
    "DIM_SERVICE": "1서비스 (SERVICE_SK)",
    "DIM_SPONSORSHIP": "1후원사업 (SPONSORSHIP_SK)",
    # GOLD FACT
    "FACT_AD_BROADCAST": "AD_PERF_DK (코어 1:1)",
    "FACT_AD_BROADCAST_CASE": "AD_PERF_DK × CASE_SEQ",
    "FACT_AD_DIGITAL": "AD_PERF_DK (코어 1:1)",
    "FACT_AD_PERFORMANCE": "AD_PERF_DK (일자 × 마케팅캠페인 × 소재 × 기기)",
    "FACT_BUDGET": "MONTH_KEY × ORG_SK × BUDGET_ITEM_SK",
    "FACT_BUDGET_YEARLY": "YEAR × ORG_SK × BUDGET_ITEM_SK",
    "FACT_DEV_ACHIEVEMENT": "MONTH_KEY × ORG_SK × DEV_TYPE",
    "FACT_EVENT_PARTICIPATION": "DATE_SK × MEMBER_DK × EVENT_SK",
    "FACT_BIGQUERY_BEHAVIOR": "DATE_SK × IDENTITY_SK × BIGQUERY_EVENT_SK × BIGQUERY_SOURCE_SK × DEVICE_SK × CAMPAIGN_SK × PAGE",
    "FACT_MEMBER_COHORT": "1회원 획득코호트 (MEMBER_DK)",
    "FACT_MEMBER_EVENT": "DATE_SK × MEMBER_DK × EVENT_TYPE",
    "FACT_MEMBER_FEE": "MEMBER_DK × MONTH_KEY × SPONSORSHIP_SK × PAYMENT_SK",
    "FACT_MEMBER_MONTHLY": "MONTH_KEY × MEMBER_DK",
    "FACT_MEMBER_SPONSOR_BIZ": "MEMBER_DK × SPNSR_BSNS_NO",
    "FACT_SERVICE_EVENT": "DATE_SK × MEMBER_DK × SERVICE_SK × CAMPAIGN_SK",
    "FACT_TARGET_BIZ": "MONTH_KEY × ORG_SK × SPONSORSHIP_SK",
    "FACT_TARGET_DEV": "MONTH_KEY × ORG_SK × DEV_TYPE",
    # GOLD WIDE
    "WIDE_AD_BROADCAST": "AD_PERF_DK (방송광고 평탄화 1:1)",
    "WIDE_AD_BROADCAST_CASE": "AD_PERF_DK × CASE_SEQ (재방송사례 평탄화)",
    "WIDE_AD_COMBINED": "AD_PERF_DK (광고 3종 1:1 통합)",
    "WIDE_AD_DIGITAL": "AD_PERF_DK (디지털광고 평탄화 1:1)",
    "WIDE_AD_PERFORMANCE": "AD_PERF_DK (광고성과 코어 평탄화)",
    "WIDE_BUDGET": "MONTH_KEY × ORG × BUDGET_ITEM",
    "WIDE_EVENT_PARTICIPATION": "DATE_SK × MEMBER_DK × EVENT",
    "WIDE_BIGQUERY_BEHAVIOR": "DATE_SK × IDENTITY × BIGQUERY_EVENT × BIGQUERY_SOURCE × DEVICE × CAMPAIGN × PAGE",
    "WIDE_MEMBER_EVENT": "DATE_SK × MEMBER_DK × EVENT_TYPE",
    "WIDE_MEMBER_FEE": "MEMBER_DK × MONTH_KEY × SPONSORSHIP × PAYMENT",
    "WIDE_MEMBER_MONTHLY": "MONTH_KEY × MEMBER_DK",
    "WIDE_SERVICE_EVENT": "DATE_SK × MEMBER_DK × SERVICE × CAMPAIGN",
    "WIDE_TARGET_BIZ": "MONTH_KEY × ORG × SPONSORSHIP",
    "WIDE_TARGET_DEV": "MONTH_KEY × ORG × DEV_TYPE",
    # SILVER
    "AGENCY_AD_BROADCAST": "AD_PERF_DK (코어 1:1)",
    "AGENCY_AD_BROADCAST_CASE": "AD_PERF_DK × CASE_SEQ",
    "AGENCY_AD_CREATIVE": "1소재 (CREATIVE_DK)",
    "AGENCY_AD_DIGITAL": "AD_PERF_DK (코어 1:1)",
    "AGENCY_AD_PERFORMANCE": "AD_PERF_DK (소스 × 일자 × 소재 × 캠페인)",
    "AGENCY_AD_ROW_DGT": "1행 (원천 staging row)",
    "AGENCY_AD_ROW_REBRDC": "1행 (원천 staging row)",
    "AGENCY_AD_ROW_VIDEO": "1행 (원천 staging row)",
    "BIGQUERY_BASIC": "EVENT_DT × EVENT_SEQ (1이벤트)",
    "BIGQUERY_DEVICE": "1디바이스",
    "BIGQUERY_EVENT": "EVENT_DT × EVENT_SEQ (1이벤트)",
    "BIGQUERY_EVENT_DIM": "1이벤트명/파라미터",
    "BIGQUERY_IDENTITY": "USER_PSEUDO_ID × ID_SCHEME (1신원)",
    "BIGQUERY_REFINED_DATA": "1이벤트 (원천 staging row)",
    "BIGQUERY_TRAFFIC_SOURCE": "1트래픽소스 (session/last-click)",
    "CRM_BIZ_TARGET": "연/월 × 조직 × 사업 (1목표)",
    "CRM_CAMPAIGN": "1캠페인 (CMPGN_CD)",
    "CRM_CODE": "코드그룹 × 코드 (CD_ID, DTL_CD_ID)",
    "CRM_DEV_TARGET": "월 × 조직 × 개발구분 (1목표)",
    "CRM_EVENT": "1행사 (EVENT_KEY)",
    "CRM_EVENT_PARTICIPATION": "행사 × 참여자 (EVENT_KEY, MEMBER_DK, PARTCPT_SEQ)",
    "CRM_MARKETING_CAMPAIGN": "1마케팅캠페인 (MKTG_CMPGN_KEY)",
    "CRM_MEMBER": "1회원 (MEMBER_DK)",
    "CRM_MEMBER_AMT_CHANGE": "1약정증감 (MBER_NO, CHG_SEQ)",
    "CRM_MEMBER_DEV": "1개발약정 (MBER_NO, DVLP_SEQ)",
    "CRM_MEMBER_DISCONTINUE": "1후원중단 (MBER_NO, DSCNTC_SEQ)",
    "CRM_MEMBER_RESPONSOR": "1재후원 (MBER_NO, RSPNSR_SEQ)",
    "CRM_MEMBER_SPONSOR_BIZ": "회원 × 후원사업 (MBER_NO, SPNSR_BSNS_NO)",
    "CRM_MEMBER_SPONSOR_SPAN": "회원 × 후원사업 (MBER_NO, SPNSR_BSNS_NO)",
    "CRM_MEMBER_STATUS_HIST": "회원 × 상태전이 (MBER_NO, STAT_CHG_SEQ)",
    "CRM_ORG": "1조직노드 (DEPT_ID)",
    "CRM_PAYMENT_BILLING": "1납입/청구 (PAY_KEY)",
    "CRM_PAYMENT_METHOD": "1결제수단 (MBER_NO, SETLE_MTHD_SEQ)",
    "CRM_RELATION_ACTIVITY": "1결연활동 (MBER_NO, ACTVT_SEQ)",
    "CRM_SEND_MEMBER": "발송 × 회원 (SNDNG_KEY, MBER_NO)",
    "CRM_SEND_REQUEST": "1발송요청 (SNDNG_KEY)",
    "CRM_SEND_RESULT": "발송 × 채널 (SNDNG_KEY, CHNL_DIV_CD)",
    "CRM_SPONSORSHIP": "1후원사업 (SPNSR_BSNS_ID)",
    "CRM_SPONSOR_RELATION": "1결연아동 (MBER_NO, CHILD_NO)",
    "ERP_BUDGET": "예산과목 × 월 (BUDGET_ITEM_DK, YYYYMM)",
    "ERP_BUDGET_ITEM": "1예산과목 (BUDGET_ITEM_DK)",
    "ERP_BUDGET_YEARLY": "예산과목 × 연도 (BUDGET_ITEM_DK, YYYY)",
    "IDENTITY_MEMBER_XREF": "USER_PSEUDO_ID × MEMBER_DK (1신원매칭)",
}

GRAIN_PATTERNS = [
    r"grain\s*=\s*([^.。\n]{1,60}?)(?:\s*[.。)]|$)",
    r"1행\s*=\s*([^.·\n)]{1,40})",
    r"PK\s*=\s*([A-Z_0-9×]{3,60})",
    r"\(1([^)]{1,30})\s*grain\)",
    r"\((1[^)]{1,30})\)",
]

TRAILING = " ·—-,·()"


def clip(s, n=48):
    """n자를 넘으면 마지막 구분자에서 자른다(단어 중간 절단 방지)."""
    s = s.strip(TRAILING)
    if len(s) <= n:
        return s
    cut = s[:n]
    for sep in ("·", " ", "×", ",", "("):
        i = cut.rfind(sep)
        if i > n // 2:
            return cut[:i].strip(TRAILING)
    return cut.strip(TRAILING)


def derive_grain(table, tbl_comment, prev_grain):
    if table in TABLE_GRAIN_MAP:
        return TABLE_GRAIN_MAP[table]
    c = re.sub(r"[🔴🟢⛔⚠️🟡🟠]", "", (tbl_comment or "")).strip()
    if c:
        for pat in GRAIN_PATTERNS:
            m = re.search(pat, c, re.IGNORECASE)
            if m:
                g = m.group(1).strip(TRAILING)
                if g and not g.startswith("source(") and not g.startswith("http"):
                    if pat.startswith("1행"):
                        g = g if g.startswith("1") else "1" + g
                    return clip(g, 60)
    if prev_grain and not prev_grain.startswith("source(") and not prev_grain.startswith("http"):
        return prev_grain
    return ""


# 원천 구조 변경으로 신설된 테이블의 도메인 라벨 (이전 판본 라벨 체계 승계)
SILVER_TYPE_OVERRIDE = {
    "CRM_BIZ_TARGET": "마스터",
    "CRM_MARKETING_CAMPAIGN": "마스터",
}


def derive_table_type(schema, table, prev_type):
    if prev_type:
        return prev_type
    if schema == "SILVER" and table in SILVER_TYPE_OVERRIDE:
        return SILVER_TYPE_OVERRIDE[table]
    if schema == "GOLD":
        for p, v in (("DIM_", "DIMENSION"), ("FACT_", "FACT"), ("WIDE_", "WIDE")):
            if table.startswith(p):
                return v
        return ""
    # SILVER: 원천 시스템 접두 기반
    if table.startswith("AGENCY_"):
        return "광고"
    if table.startswith("ERP_"):
        return "ERP"
    if table.startswith("GA4_") or table.startswith("BIGQUERY_"):
        return "GA4"
    if table.startswith("IDENTITY_"):
        return "신원"
    if table.startswith("CRM_"):
        return "CRM"
    return ""


def derive_key(col, pk_cols, fk_map):
    parts = []
    if col in pk_cols:
        parts.append("PK")
    elif col.endswith("_DK"):
        parts.append("DK")
    elif col.endswith("_BK"):
        parts.append("BK")
    if col in fk_map:
        parts.append("FK")
    return ",".join(parts)


def note(col, prev_note):
    if col.startswith(AUDIT_PREFIX):
        return "공통감사"
    return prev_note or ""


def load_prev(path):
    """이전 판본에서 사람이 정제한 GRAIN·테이블유형·FK_타깃·주의를 승계한다."""
    grain, ttype, fk, notes = {}, {}, {}, {}
    # 02_ 접두사 여부 모두 검사
    if not os.path.exists(path):
        alt_path = path.replace("/02_", "/")
        if os.path.exists(alt_path):
            path = alt_path
        else:
            return grain, ttype, fk, notes
    for r in csv.DictReader(open(path, encoding="utf-8-sig")):
        t, c = r["테이블명"].strip(), r["컬럼명"].strip()
        if r.get("GRAIN", "").strip():
            grain[t] = r["GRAIN"].strip()
        if r.get("테이블유형", "").strip():
            ttype[t] = r["테이블유형"].strip()
        if r.get("FK_타깃", "").strip():
            fk[(t, c)] = r["FK_타깃"].strip()
        if r.get("주의_제약(DDL)", "").strip():
            notes[(t, c)] = r["주의_제약(DDL)"].strip()
    return grain, ttype, fk, notes


def build(cur, schema, prev_file, out_file):
    prev_grain, prev_ttype, prev_fk, prev_notes = load_prev(prev_file)

    cols = q(cur, f"""
        SELECT c.TABLE_NAME, c.ORDINAL_POSITION, c.COLUMN_NAME, c.DATA_TYPE,
               c.NUMERIC_PRECISION, c.NUMERIC_SCALE, c.IS_NULLABLE, c.COMMENT AS COL_COMMENT,
               t.TABLE_TYPE, t.COMMENT AS TBL_COMMENT
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS c
        JOIN GN_DW.INFORMATION_SCHEMA.TABLES t
          ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
        WHERE c.TABLE_SCHEMA = '{schema}'
        ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION
    """)

    pk = {}
    for r in q(cur, f"SHOW PRIMARY KEYS IN SCHEMA GN_DW.{schema}"):
        pk.setdefault(r["table_name"], set()).add(r["column_name"])

    fk = {}
    for r in q(cur, f"SHOW IMPORTED KEYS IN SCHEMA GN_DW.{schema}"):
        fk[(r["fk_table_name"], r["fk_column_name"])] = \
            f'{r["pk_table_name"]}.{r["pk_column_name"]}'

    rows = []
    for r in cols:
        t, c = r["TABLE_NAME"], r["COLUMN_NAME"]
        fk_target = fk.get((t, c)) or prev_fk.get((t, c), "")
        key = derive_key(c, pk.get(t, set()), {c} if fk_target else set())
        rows.append([
            t,
            derive_table_korean_name(t, r["TBL_COMMENT"]),
            derive_grain(t, r["TBL_COMMENT"], prev_grain.get(t)),
            derive_table_type(schema, t, prev_ttype.get(t)),
            c,
            derive_column_korean_name(t, c, r["COL_COMMENT"]),
            fmt_type(r),
            "Y" if r["IS_NULLABLE"] == "YES" else "N",
            key,
            fk_target,
            (r["COL_COMMENT"] or "").replace("\r\n", " ").replace("\n", " ").strip(),
            note(c, prev_notes.get((t, c))),
        ])

    with open(out_file, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(HEADER)
        w.writerows(rows)

    tbls = len({r[0] for r in rows})
    print(f"{out_file}: {tbls} tables / {len(rows)} columns")
    return rows


def main():
    conn = connect()
    cur = conn.cursor()
    build(cur, "SILVER",
          f"{PREV_DIR}/SILVER 스키마 컬럼 인벤토리_{PREV_TAG}.csv",
          f"{OUT_DIR}/02_SILVER 스키마 컬럼 인벤토리_{AS_OF}.csv")
    build(cur, "GOLD",
          f"{PREV_DIR}/gold 스키마 컬럼 인벤토리_{PREV_TAG}.csv",
          f"{OUT_DIR}/02_gold 스키마 컬럼 인벤토리_{AS_OF}.csv")
    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
