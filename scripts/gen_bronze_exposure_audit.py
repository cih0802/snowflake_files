# BRONZE 노출감사: BRONZE×SILVER×GOLD 컬럼 대조 + dbt 하드코딩 검출 (전 원천 전면 감사)
# Co-authored with CoCo
"""
GN_DW BRONZE 노출 감사 스크립트.
목적: "보여줄 수 있는 BRONZE 데이터는 다 보여준다" — 현재 GOLD까지 도달하는 컬럼과 누락·하드코딩을 자동 식별.

근거 원칙:
  - P13 (커버리지≠정확도): 이름 기준 매칭이므로 '미노출'은 확정 아님(개명 미탐) → 신뢰도 열 병기.
  - P14 (부재판정은 실측 필수): 판정일 + 쿼리 근거 명시.

감사 범위: BRONZE 1,121 컬럼 (CRM 927 · AGENCY 102 · ERP 62 · GA4 30).

⚠️ 실행 경로 (중요)
  본 파일은 **커널(노트북 서비스) 실행용** 이며, 커널에서는 workspace 파일시스템이
  read-only 이고 dbt 모델 디렉터리에 접근할 수 없다. 따라서 커널 실행 시에는
  하드코딩 검출이 불가하여 정확도가 떨어진다.

  ▶ **정본 실행은 `scripts/run_bronze_audit_host.py` (호스트 러너)** 를 사용한다.
    - dbt 모델 SQL 을 직접 스캔 → 하드코딩/실적재를 모델 스코프로 정확히 판정
    - 계보 매핑 LINEAGE_MAP: (BRONZE 테이블 × 컬럼) → (GOLD 컬럼 × 모델)
    - 산출물을 workspace 30_output_share/ 에 직접 기록 (md·csv·xlsx)
    - 실행: python3 scripts/run_bronze_audit_host.py <snowflake_sql_execute 캐시디렉터리>

  본 파일은 커널에서 Snowpark 로 컬럼 인벤토리를 확인하는 보조 용도로 유지한다.
  판정 로직의 정본은 호스트 러너이며, 두 파일의 판정 기준이 갈리면 러너를 따른다.

출력(커널 실행 시): /tmp/bronze_audit_output/06_BRONZE노출감사.{md,csv}
접속: Snowpark get_active_session().
"""
import csv, os, re
from datetime import date
from snowflake.snowpark.context import get_active_session

# ── 설정 ──
OUT_DIR = "/tmp/bronze_audit_output"
BASENAME = "06_BRONZE노출감사"
GEN_PATH = "scripts/gen_bronze_exposure_audit.py"
PROV = f"자동 생성물 — 생성기 {GEN_PATH} 수정 후 재실행. 직접 편집 금지."
AUDIT_DATE = date.today().isoformat()

# PII·본문·감사메타 제외 대상 패턴
EXCLUDE_PATTERNS = [
    r"^(FRST_REGISTER|LST_RGSTR|FRST_REGIST|LST_UPDT|REG_DATE|UPD_DATE|DEL_YN|USE_YN).*",
    r"^(RGSTR_ID|UPDT_ID|REGISTER_ID|UPDATER_ID|FILLER.*)$",
    r"^(SND_MSG|DISCHARGE_REPORT|LETTER_CONTENT).*",
    r"^(MBER_NM|CHILD_NM_KOR|CHILD_NM_ENG|ADDR|ZIP|TEL|HP|MOBILE|FAX|EMAIL_ADDR).*",
]
EXCLUDE_RE = re.compile("|".join(EXCLUDE_PATTERNS), re.IGNORECASE)
DW_META_COLS = {"DW_SOURCE_SYSTEM", "DW_SOURCE_TABLE", "DW_LOAD_TS", "DW_UPDATE_TS", "DW_BATCH_ID"}

# ── GOLD 하드코딩 검출 결과 (2026-07-28 grep 실측 — dbt models/gold/) ──
HARDCODED = {
    "CAMPAIGN_SK": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 18, "pattern": "0 as CAMPAIGN_SK"},
    "AD_CREATIVE_SK": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 19, "pattern": "0 as AD_CREATIVE_SK"},
    "DEVICE_SK": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 20, "pattern": "0 as DEVICE_SK"},
    "ORG_SK": {"file": "10_dbt_pipeline/models/gold/dim/DIM_CAMPAIGN.sql", "line": 25, "pattern": "0 as ORG_SK"},
    "SPONSORSHIP_SK": {"file": "10_dbt_pipeline/models/gold/fact/FACT_BUDGET.sql", "line": 21, "pattern": "CAST(NULL AS NUMBER(38,0)) as SPONSORSHIP_SK"},
    "PAYMENT_SK": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 58, "pattern": "0 as PAYMENT_SK"},
    "REASON_SK": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 58, "pattern": "0 as REASON_SK"},
    "TIME_BAND": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 29, "pattern": "CAST(NULL AS VARCHAR) as TIME_BAND"},
    "CM_POSITION": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 30, "pattern": "CAST(NULL AS VARCHAR) as CM_POSITION"},
    "RT_TYPE": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 31, "pattern": "CAST(NULL AS VARCHAR) as RT_TYPE"},
    "AD_START_TIME": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 32, "pattern": "CAST(NULL AS VARCHAR) as AD_START_TIME"},
    "BROADCAST_DATE": {"file": "10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql", "line": 33, "pattern": "CAST(NULL AS DATE) as BROADCAST_DATE"},
    "PLATFORM_TYPE": {"file": "10_dbt_pipeline/models/gold/dim/DIM_AD_CREATIVE.sql", "line": 22, "pattern": "CAST(NULL AS VARCHAR) as PLATFORM_TYPE"},
    "DURATION_SEC": {"file": "10_dbt_pipeline/models/gold/dim/DIM_AD_CREATIVE.sql", "line": 25, "pattern": "CAST(NULL AS NUMBER(9,0)) as DURATION_SEC"},
    "TARGET_GROUP": {"file": "10_dbt_pipeline/models/gold/dim/DIM_AD_CREATIVE.sql", "line": 28, "pattern": "CAST(NULL AS VARCHAR) as TARGET_GROUP"},
    "DOMESTIC_OVERSEAS": {"file": "10_dbt_pipeline/models/gold/dim/DIM_CAMPAIGN.sql", "line": 22, "pattern": "CAST(NULL AS VARCHAR) as DOMESTIC_OVERSEAS"},
    "APPLY_CHANNEL": {"file": "10_dbt_pipeline/models/gold/dim/DIM_EVENT.sql", "line": 23, "pattern": "CAST(NULL AS VARCHAR) as APPLY_CHANNEL"},
    "EFFECTIVE_TO": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 74, "pattern": "CAST(NULL AS DATE) as EFFECTIVE_TO"},
    "REGION": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 103, "pattern": "CAST(NULL AS VARCHAR) as REGION"},
    "AGE_BAND": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 104, "pattern": "CAST(NULL AS VARCHAR) as AGE_BAND"},
    "NEW_EXISTING_FLAG": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 115, "pattern": "CAST(NULL AS VARCHAR) as NEW_EXISTING_FLAG"},
    "FIRST_SPONSORSHIP": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 120, "pattern": "CAST(NULL AS VARCHAR) as FIRST_SPONSORSHIP"},
    "LAST_STOP_DATE": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 121, "pattern": "CAST(NULL AS DATE) as LAST_STOP_DATE"},
    "LAST_CAMPAIGN": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 122, "pattern": "CAST(NULL AS VARCHAR) as LAST_CAMPAIGN"},
    "CURRENT_SPONSORSHIP": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER.sql", "line": 123, "pattern": "CAST(NULL AS VARCHAR) as CURRENT_SPONSORSHIP"},
    "MEMNUM": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER_IDENTITY.sql", "line": 27, "pattern": "CAST(NULL AS VARCHAR) as MEMNUM"},
    "CHILD_CODE": {"file": "10_dbt_pipeline/models/gold/dim/DIM_MEMBER_IDENTITY.sql", "line": 30, "pattern": "CAST(NULL AS VARCHAR) as CHILD_CODE"},
    "CORP": {"file": "10_dbt_pipeline/models/gold/dim/DIM_ORG.sql", "line": 19, "pattern": "CAST(NULL AS VARCHAR) as CORP"},
    "DIVISION": {"file": "10_dbt_pipeline/models/gold/dim/DIM_ORG.sql", "line": 20, "pattern": "CAST(NULL AS VARCHAR) as DIVISION"},
    "TEAM": {"file": "10_dbt_pipeline/models/gold/dim/DIM_ORG.sql", "line": 22, "pattern": "CAST(NULL AS VARCHAR) as TEAM"},
    "FEE_TYPE": {"file": "10_dbt_pipeline/models/gold/dim/DIM_PAYMENT.sql", "line": 19, "pattern": "CAST(NULL AS VARCHAR) as FEE_TYPE"},
    "SEND_TYPE_L": {"file": "10_dbt_pipeline/models/gold/dim/DIM_SERVICE.sql", "line": 17, "pattern": "CAST(NULL AS VARCHAR) as SEND_TYPE_L"},
    "SEND_TYPE_M": {"file": "10_dbt_pipeline/models/gold/dim/DIM_SERVICE.sql", "line": 18, "pattern": "CAST(NULL AS VARCHAR) as SEND_TYPE_M"},
    "SEND_TYPE_S": {"file": "10_dbt_pipeline/models/gold/dim/DIM_SERVICE.sql", "line": 19, "pattern": "CAST(NULL AS VARCHAR) as SEND_TYPE_S"},
    "PLAN_BUDGET_YEAR": {"file": "10_dbt_pipeline/models/gold/fact/FACT_BUDGET.sql", "line": 23, "pattern": "CAST(NULL AS NUMBER(18,2)) as PLAN_BUDGET_YEAR"},
    "EXEC_BUDGET_EST": {"file": "10_dbt_pipeline/models/gold/fact/FACT_BUDGET.sql", "line": 25, "pattern": "CAST(NULL AS NUMBER(18,2)) as EXEC_BUDGET_EST"},
    "FUNDRAISING_COST": {"file": "10_dbt_pipeline/models/gold/fact/FACT_BUDGET.sql", "line": 26, "pattern": "CAST(NULL AS NUMBER(18,2)) as FUNDRAISING_COST"},
    "SELF_PART_FLAG": {"file": "10_dbt_pipeline/models/gold/fact/FACT_EVENT_PARTICIPATION.sql", "line": 24, "pattern": "CAST(NULL AS BOOLEAN) as SELF_PART_FLAG"},
    "INCREASE_FLAG": {"file": "10_dbt_pipeline/models/gold/fact/FACT_EVENT_PARTICIPATION.sql", "line": 28, "pattern": "CAST(NULL AS BOOLEAN) as INCREASE_FLAG"},
    "AVG_SESSION_DURATION": {"file": "10_dbt_pipeline/models/gold/fact/FACT_GA_BEHAVIOR.sql", "line": 74, "pattern": "CAST(NULL AS NUMBER) as AVG_SESSION_DURATION"},
    "BOUNCE_RATE": {"file": "10_dbt_pipeline/models/gold/fact/FACT_GA_BEHAVIOR.sql", "line": 75, "pattern": "CAST(NULL AS NUMBER) as BOUNCE_RATE"},
    "STOP_DATE": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_EVENT.sql", "line": 18, "pattern": "CAST(NULL AS DATE) as STOP_DATE"},
    "STOP_REASON": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_EVENT.sql", "line": 19, "pattern": "CAST(NULL AS VARCHAR) as STOP_REASON"},
    "STOP_CHANNEL": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_EVENT.sql", "line": 20, "pattern": "CAST(NULL AS VARCHAR) as STOP_CHANNEL"},
    "JOIN_DATE": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_EVENT.sql", "line": 33, "pattern": "CAST(NULL AS DATE) as JOIN_DATE"},
    "DEV_TYPE": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 72, "pattern": "CAST(NULL AS VARCHAR) as DEV_TYPE"},
    "NEW_FLAG": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 73, "pattern": "CAST(NULL AS BOOLEAN) as NEW_FLAG"},
    "REDONATE_FLAG": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 73, "pattern": "CAST(NULL AS BOOLEAN) as REDONATE_FLAG"},
    "AMOUNT_BAND1": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 75, "pattern": "CAST(NULL AS VARCHAR) as AMOUNT_BAND1"},
    "AMOUNT_BAND2": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 75, "pattern": "CAST(NULL AS VARCHAR) as AMOUNT_BAND2"},
    "PERIOD_BAND1": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 76, "pattern": "CAST(NULL AS VARCHAR) as PERIOD_BAND1"},
    "PERIOD_BAND2": {"file": "10_dbt_pipeline/models/gold/fact/FACT_MEMBER_MONTHLY.sql", "line": 76, "pattern": "CAST(NULL AS VARCHAR) as PERIOD_BAND2"},
    "SEND_STATUS2": {"file": "10_dbt_pipeline/models/gold/fact/FACT_SERVICE_EVENT.sql", "line": 35, "pattern": "CAST(NULL AS VARCHAR) as SEND_STATUS2"},
    "MAIL_RECEIVE_FLAG": {"file": "10_dbt_pipeline/models/gold/fact/FACT_SERVICE_EVENT.sql", "line": 37, "pattern": "CAST(NULL AS BOOLEAN) as MAIL_RECEIVE_FLAG"},
    "MEMBER_STOP_FLAG": {"file": "10_dbt_pipeline/models/gold/fact/FACT_SERVICE_EVENT.sql", "line": 38, "pattern": "CAST(NULL AS BOOLEAN) as MEMBER_STOP_FLAG"},
    "ANNUAL_CUM_GOAL_CNT": {"file": "10_dbt_pipeline/models/gold/fact/FACT_TARGET_BIZ.sql", "line": 22, "pattern": "CAST(NULL AS NUMBER(18,4)) as ANNUAL_CUM_GOAL_CNT"},
    "SUPP_CUM_GOAL_CNT": {"file": "10_dbt_pipeline/models/gold/fact/FACT_TARGET_BIZ.sql", "line": 23, "pattern": "CAST(NULL AS NUMBER(18,4)) as SUPP_CUM_GOAL_CNT"},
    # FACT_AD_PERFORMANCE 추가 AD_COST (FACT_BUDGET)
    "AD_COST": {"file": "10_dbt_pipeline/models/gold/fact/FACT_BUDGET.sql", "line": 27, "pattern": "CAST(NULL AS NUMBER(18,2)) as AD_COST"},
}

# ── SILVER dbt SQL 참조 토큰 (이름매칭 보완) ──
SILVER_SQL_REFS = {
    "DATE", "CMPGN_NM", "UPPER_CMPGN_NM", "MEDIA_NM", "DEVICE", "MATR",
    "EXPS_CNT", "CLICK_CNT", "GA_CONV_MBER_CNT", "CONV_VU_CNT", "GA_AD_COST",
    "CHNNL_CMPNY", "BRDC_NM", "DVLP_MBER_CNT", "DVLP_CNT", "INBOUND_CALL_CNT",
    "AD_CNT", "BRDC_SCHDL_COST", "TIME_RNG_DIV_NM", "RE_BRDC_TY_NM",
    "BRDC_DATE", "MKT_CMPGN_NM", "CHNNL_NM", "MATR_NM", "SCHDL_NM",
    "ACTL_PUR_AD_COST_KRW", "CONV_CALL_CNT", "TIME_RNG", "CM_AREA", "AD_STRT_TIME",
    "AD_END_TIME", "AD_SEC", "SPOT_TY", "AD_VIEW_RT", "CM",
    "MATR_TY_NM", "CMPGN_TY_NM", "DUR_PD_MATR_CHN", "CHNNL_CMPNY_TY_NM",
    "MBER_NO", "SPNSR_CD", "SPNSR_BSNS_CD", "CMPGN_CD", "DEPT_CD",
    "SETLE_CD", "SETLE_WAY_CD", "SETLE_NM", "SETLE_WAY_NM",
    "DVLP_AMT", "RSPNS_AMT", "DSCNTC_RSN_CD", "DSCNTC_RSN_NM",
    "MNG_NO", "RELATNSP_KEY", "CHILD_NO",
    "BDGT_ITEM_NM", "BDGT_CATE_NM", "BDGT_TP_CD",
    "EVENT_DATE", "EVENT_TIMESTAMP", "EVENT_NAME", "EVENT_PARAMS",
    "USER_ID", "USER_PSEUDO_ID", "PLATFORM", "STREAM_ID", "IS_ACTIVE_USER",
    # CRM 추가 — SILVER SQL에서 직접 사용되는 주요 컬럼
    "BRND_CD", "BRND_NM", "MKTNG_CMPGN_NM", "SETLE_BANK_CD",
    "DVLP_GOAL_CNT", "DVLP_GOAL_AMT", "PRMO_MTHD_CD",
    "RGSTR_DEPT_CD", "CMPGN_STRT_DT", "CMPGN_END_DT",
    "SPNSR_BSNS_NM", "SPNSR_BSNS_ABBR_NM",
    "IRSD_AMT", "IRSD_RSN_CD", "IRSD_RSN_NM",
    "FDRM_MBER_STTS_CD", "FDRM_MBER_STTS_NM",
    "EVENT_NM", "EVENT_BGNG_DT", "EVENT_END_DT",
    "PRTCPNT_CNT", "RCRT_CNT", "WAIT_CNT", "CNCL_CNT", "CNFRM_CNT",
    "SNDNG_DT", "SNDNG_STTUS_CD", "SNDNG_STTUS_NM", "EMAIL_OPEN_YN",
    "FRST_SPNSR", "SPNSR_STRT_DT", "SPNSR_END_DT",
    "DSCNTC_DT", "DSCNTC_PATH", "RE_SPNSR_DT",
}


def run_audit():
    print(f"[{AUDIT_DATE}] BRONZE 노출감사 시작...")
    session = get_active_session()
    print("  INFORMATION_SCHEMA 조회...")
    df = session.sql("""
        SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
        FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA IN ('BRONZE_CRM','BRONZE_AGENCY','BRONZE_ERP','BRONZE_BIGQUERY','SILVER','GOLD')
        ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
    """).collect()
    print(f"  총 {len(df)}개 컬럼 조회.")

    bronze_map, silver_cols_all, gold_cols_all = {}, set(), set()
    for row in df:
        schema, table, col = row["TABLE_SCHEMA"], row["TABLE_NAME"], row["COLUMN_NAME"]
        dtype, pos = row["DATA_TYPE"], row["ORDINAL_POSITION"]
        if schema.startswith("BRONZE_"):
            key = f"{schema}.{table}"
            bronze_map.setdefault(key, []).append((col, dtype, pos))
        elif schema == "SILVER":
            silver_cols_all.add(col)
        elif schema == "GOLD":
            gold_cols_all.add(col)

    print("  BRONZE 전 컬럼 판정...")
    audit_rows = []
    stats = {}
    for bronze_key in sorted(bronze_map.keys()):
        schema_part = bronze_key.split(".")[0]
        source_sys = schema_part.replace("BRONZE_", "")
        table_name = bronze_key.split(".")[1]
        for col, dtype, pos in bronze_map[bronze_key]:
            col_upper = col.upper()
            verdict, confidence, note = classify(col_upper, silver_cols_all, gold_cols_all)
            audit_rows.append({
                "원천시스템": source_sys,
                "BRONZE_테이블": table_name,
                "BRONZE_컬럼": col,
                "데이터타입": dtype,
                "판정": verdict,
                "신뢰도": confidence,
                "비고": note,
            })
            stats[verdict] = stats.get(verdict, 0) + 1

    print(f"  감사 완료: 총 {len(audit_rows)}건")
    for k, v in sorted(stats.items(), key=lambda x: -x[1]):
        print(f"    {k}: {v}건")

    os.makedirs(OUT_DIR, exist_ok=True)
    write_csv(audit_rows)
    md_content = write_md(audit_rows, stats)
    print(f"\n  출력: {OUT_DIR}/{BASENAME}.{{md,csv}}")
    return audit_rows, stats


def classify(col_upper, silver_cols_all, gold_cols_all):
    if EXCLUDE_RE.match(col_upper):
        return "제외(PII·본문·메타)", "—", "패턴 매칭 제외"
    if col_upper in DW_META_COLS:
        return "제외(DW메타)", "—", "DW 감사 메타컬럼"
    if col_upper in HARDCODED:
        hc = HARDCODED[col_upper]
        return "⚠️설계O·값미주입", "높음", f"{hc['file']}:{hc['line']} `{hc['pattern']}`"
    if col_upper in gold_cols_all:
        return "노출됨(GOLD)", "높음", ""
    in_silver = col_upper in silver_cols_all
    silver_ref = col_upper in SILVER_SQL_REFS
    if in_silver or silver_ref:
        confidence = "높음" if in_silver else "중간(SQL참조)"
        return "SILVER까지만", confidence, ""
    return "미노출(검토대상)", "낮음(이름기반·P13)", "개명·param승격 가능성 있음"


def write_csv(audit_rows):
    path = os.path.join(OUT_DIR, BASENAME + ".csv")
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow([f"# 생성기: {GEN_PATH} | 감사일: {AUDIT_DATE}"])
        w.writerow([f"# {PROV}"])
        w.writerow([])
        header = ["원천시스템", "BRONZE_테이블", "BRONZE_컬럼", "데이터타입", "판정", "신뢰도", "비고"]
        w.writerow(header)
        for r in audit_rows:
            w.writerow([r[h] for h in header])
    print(f"  CSV: {path}")


def write_md(audit_rows, stats):
    lines = []
    lines.append("<!-- LLM-METADATA")
    lines.append("doc_id: BRONZE_EXPOSURE_AUDIT")
    lines.append("doc_role: BRONZE 전 원천 전면 감사 결과 (GOLD 노출 여부 판정)")
    lines.append("project: GN_DW")
    lines.append(f"audit_date: {AUDIT_DATE}")
    lines.append(f"generator: {GEN_PATH}")
    lines.append("principle: P13(커버리지≠정확도)·P14(부재판정은 실측필수)")
    lines.append("END-METADATA -->")
    lines.append("")
    lines.append("# BRONZE 노출감사 결과")
    lines.append("")
    lines.append(f"> ⚙️ **생성기**: `{GEN_PATH}` — {PROV}")
    lines.append(f"> **감사일**: {AUDIT_DATE} | **범위**: BRONZE 전 원천 {len(audit_rows)}컬럼")
    lines.append(f"> **원칙**: P13(이름매칭 한계·개명 미탐 가능) · P14(부재판정은 실측+측정일 필수)")
    lines.append("")
    lines.append("## 1. 요약 통계")
    lines.append("")
    lines.append("| 판정 | 건수 | 비율 |")
    lines.append("|---|---|---|")
    total = len(audit_rows)
    for verdict in ["노출됨(GOLD)", "⚠️설계O·값미주입", "SILVER까지만", "미노출(검토대상)", "제외(PII·본문·메타)", "제외(DW메타)"]:
        cnt = stats.get(verdict, 0)
        pct = f"{cnt/total*100:.1f}%" if total else "0%"
        lines.append(f"| {verdict} | {cnt} | {pct} |")
    lines.append(f"| **합계** | **{total}** | 100% |")
    lines.append("")
    lines.append("## 2. ⚠️ 최우선 조치군: GOLD 설계O·값 미주입 (하드코딩)")
    lines.append("")
    lines.append("dbt GOLD 모델에서 `0 as X_SK` 또는 `CAST(NULL AS ..) as X`로 하드코딩된 컬럼.")
    lines.append("GOLD 스키마에 이미 자리가 있으나 SILVER/BRONZE 값이 배선되지 않은 상태.")
    lines.append("")
    lines.append("| GOLD 컬럼 | 파일:행 | 하드코딩 패턴 |")
    lines.append("|---|---|---|")
    for col, info in sorted(HARDCODED.items()):
        lines.append(f"| `{col}` | `{info['file']}:{info['line']}` | `{info['pattern']}` |")
    lines.append("")
    lines.append("## 3. 원천별 상세")
    lines.append("")
    sources = sorted(set(r["원천시스템"] for r in audit_rows))
    for src in sources:
        src_rows = [r for r in audit_rows if r["원천시스템"] == src]
        lines.append(f"### {src} ({len(src_rows)}컬럼)")
        lines.append("")
        tables = sorted(set(r["BRONZE_테이블"] for r in src_rows))
        for tbl in tables:
            tbl_rows = [r for r in src_rows if r["BRONZE_테이블"] == tbl]
            lines.append(f"#### {tbl} ({len(tbl_rows)}컬럼)")
            lines.append("")
            lines.append("| 컬럼 | 타입 | 판정 | 신뢰도 | 비고 |")
            lines.append("|---|---|---|---|---|")
            for r in tbl_rows:
                lines.append(f"| `{r['BRONZE_컬럼']}` | {r['데이터타입']} | {r['판정']} | {r['신뢰도']} | {r['비고']} |")
            lines.append("")
    lines.append("---")
    lines.append(f"_감사일 {AUDIT_DATE} · Co-authored with CoCo_")
    content = "\n".join(lines)
    path = os.path.join(OUT_DIR, BASENAME + ".md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  MD : {path}")
    return content


if __name__ == "__main__":
    run_audit()
