-- BRONZE DDL 제안 — ERP 사업목표 원천 테이블 (입고 요청서 첨부)
-- Co-authored with CoCo
-- ============================================================================
-- 목적: 현업으로부터 사업목표 데이터 입고 시 BRONZE 적재 대상 테이블.
-- 블로커: E-6 (40_입고대기_원천의존.md)
-- SILVER 후속: GN_DW.SILVER.ERP_BIZ_TARGET → GOLD FTG-B
-- ============================================================================
-- ※ 원천 형태 확인 후 컬럼명·타입 조정 가능. 아래는 SILVER 스펙 역산 제안안.
-- ============================================================================

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE_ERP.BIZ_TARGET_RAW (
    -- === 업무 키 ===
    TARGET_YEAR         NUMBER(4,0)     COMMENT '목표연도 (YYYY)',
    MONTH_NO            NUMBER(2,0)     COMMENT '월 (1~12, 연간이면 NULL)',
    ORG_NM              VARCHAR(200)    COMMENT '조직명 (부서/팀)',
    SPONSOR_BIZ_NM      VARCHAR(200)    COMMENT '후원사업명',
    CAMPAIGN_NM         VARCHAR(200)    COMMENT '캠페인명 (없으면 NULL)',

    -- === 목표 금액 ===
    TARGET_TYPE         VARCHAR(20)     COMMENT '목표유형: ANNUAL(당초) / REVISED(추경) / CUMULATIVE(누계)',
    TARGET_AMT          NUMBER(38,0)    COMMENT '목표 금액 (원 단위)',

    -- === 메타/감사 (BRONZE 공통) ===
    _SRC_FILE           VARCHAR         COMMENT '원천 파일명 또는 리포트명',
    _SRC_SHEET          VARCHAR         COMMENT '시트명 (Excel인 경우)',
    _LOADED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT '적재 시각',
    _BATCH_ID           VARCHAR         COMMENT '적재 배치 식별자'
)
COMMENT = 'BRONZE — ERP 사업목표 원천 (현업 제공 대기). 입고 후 SILVER.ERP_BIZ_TARGET으로 정제.'
;

-- ============================================================================
-- 적재 예시 (CSV/Excel 파일 입고 시)
-- ============================================================================
/*
COPY INTO GN_DW.BRONZE_ERP.BIZ_TARGET_RAW
FROM @GN_DW.BRONZE_ERP.STG_ERP_FILES/biz_target/
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"')
ON_ERROR = 'CONTINUE'
;
*/
