-- ERP_EXPENSE_RESOLUTION: 지출결의 명세 (1행 = 원천 1행) · 🆕 [2026-10-08 O213-F Y3-K]
-- Co-authored with CoCo
-- 원천 BRONZE_ERP.EXPENSE_RESOLUTION(O114-B 선언 · 종전 소비 모델 0). 값 가공 없음(R2-7) · TRIM/NULLIF 만.
-- 🔴🔴 예산 원장(ERP_BUDGET·FACT_BUDGET)과 합산·조인 금지 — 과목키 일치 0.02% · 금액 약 9.9배(_sources.yml O114-B 실측).
-- 🔴 원천 grain 이 깨끗하지 않다(2026-10-08 실측): 61,785행 · 결의번호 32,746 · 전 컬럼 동일 행 7,287.
--    동일 행이 반복 명세인지 적재 중복인지 판별할 수 없어 **제거하지 않는다**(합계 = 원천 212,342,534,942원 보존).
--    ⇒ ROW_SEQ 로 행을 식별한다(결의번호 내 일련 · 결정적 정렬). 🔴 현업 확인 = 문서20 N-29 ⑧.
-- pre-hook = silver_purge 기본(TRUNCATE) · 전량 재적재.
{{ config(materialized='incremental') }}

select
    NULLIF(TRIM(RESOLUTION_NO), '')              as RESOLUTION_NO,
    row_number() over (
        partition by RESOLUTION_NO
        order by SOURCE_NO, SUBDTL_ITEM_NM, DESCRIPTIONVARCHAR, SUM_AMT, CONTENTS_DELIMITER) as ROW_SEQ,
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
    '{{ invocation_id }}'                        as DW_BATCH_ID
from {{ source('bronze_erp', 'EXPENSE_RESOLUTION') }}
