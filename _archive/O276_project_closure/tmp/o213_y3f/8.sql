CREATE TABLE IF NOT EXISTS GN_DW.SILVER.ERP_EXPENSE_RESOLUTION
COMMENT = '지출결의 명세. [Grain: RESOLUTION_NO × ROW_SEQ (원천 1행)]. [주의: 예산 원장과 합산·조인 금지 · 전 컬럼 동일 행 보존]. [원천: ERP → BRONZE_ERP.EXPENSE_RESOLUTION]. 🆕 O213-F'
AS
select
    NULLIF(TRIM(RESOLUTION_NO), '')              as RESOLUTION_NO,
    row_number() over (partition by RESOLUTION_NO order by SOURCE_NO) as ROW_SEQ,
    TRY_TO_NUMBER(YEAR)                          as RESOLUTION_YEAR,
    WRITE_DATE                                   as WRITE_DATE,
    NULLIF(TRIM(RESOLUTION_DEPT_NM), '')         as RESOLUTION_DEPT_NM,
    NULLIF(TRIM(EXPS_RESOLUTION_NM), '')         as EXPS_RESOLUTION_NM,
    NULLIF(TRIM(SOURCE_DIV_NM), '')              as SOURCE_DIV_NM,
    NULLIF(TRIM(SOURCE_NO), '')                  as SOURCE_NO,
    NULLIF(TRIM(BDGT_UNIT_NM), '')               as BDGT_UNIT_NM,
    NULLIF(TRIM(MOK_NM), '')                     as MOK_NM,
    NULLIF(TRIM(DTL_ITEM_NM), '')                as DTL_ITEM_NM,
    NULLIF(TRIM(SUBDTL_ITEM_NM), '')             as SUBDTL_ITEM_NM,
    NULLIF(TRIM(FUND_SOURCE_NM), '')             as FUND_SOURCE_NM,
    NULLIF(TRIM(BDGT_ITEM_NM), '')               as BDGT_ITEM_NM,
    DESCRIPTIONVARCHAR                           as DESCRIPTION,
    SUM_AMT                                      as SUM_AMT,
    NULLIF(TRIM(CONTENTS_DELIMITER), '')         as CONTENTS_DELIMITER,
    'ERP'                                        as DW_SOURCE_SYSTEM,
    'BRONZE_ERP.EXPENSE_RESOLUTION'              as DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ           as DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ           as DW_UPDATE_TS,
    'x'                                          as DW_BATCH_ID
from GN_DW.BRONZE_ERP.EXPENSE_RESOLUTION
limit 0
