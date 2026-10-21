-- =============================================================================
-- Purpose    : 공휴일 마스터 — GOLD.DIM_DATE.IS_HOLIDAY 의 SILVER 경유 원천.
-- Target     : SILVER.CRM_HOLIDAY (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : source bronze_crm_ref.TM_CM_SCHDUL_MNG
-- Issue      : DR-25, O188
-- =============================================================================
-- CRM_HOLIDAY: 공휴일 마스터 — GOLD.DIM_DATE.IS_HOLIDAY 의 SILVER 경유 원천.
--  [2026-10-20 DR-25] 종전 DIM_DATE 가 `BRONZE_CRM.TM_CM_SCHDUL_MNG` 를 직접 읽었다(GOLD→BRONZE · 레이어 원칙 위반).
--   사용자 결정 = SILVER 모델을 끼워 넣는다. 필터 규칙은 DIM_DATE 에서 **그대로 이관**했다(의미 변경 0):
--     · SCHDUL_DIV_CD='0' = 공휴일(현업 회신 · 문서20 F-5 · O188).
--     · 한글 없는 제목(2013-01-01 '123123' 등 2건)은 입력 테스트로 제외(같은 날 '새해' 행이 따로 있다).
--     · WARN: 2021·2022 는 13일로 다른 해보다 적다 — 원천 기재 그대로이며 보정하지 않는다.
--   · grain = 일자. 실측(IW20760) 원천 256행 → 251일(5일은 제목 2건) ⇒ 제목은 LISTAGG, 행수는 SRC_ROW_CNT.
--   · WARN: source 는 `bronze_crm_ref` — dev2 의 BRONZE_CRM_2 에 이 테이블이 없다(_sources.yml 주석).
--   · WARN: 구조 정본 = `04_silver_design/08_SILVER_테이블DDL_20260714.sql` 의 CRM_HOLIDAY 블록(DDL 선행 필수).
WITH src AS (
    SELECT SCHDUL_DE, TRIM(SCHDUL_TIT) AS SCHDUL_TIT
    FROM GN_DW.BRONZE_CRM.TM_CM_SCHDUL_MNG
    WHERE SCHDUL_DIV_CD = '0'
      AND SCHDUL_DE IS NOT NULL
      AND REGEXP_LIKE(SCHDUL_TIT, '.*[가-힣].*')
)
SELECT
  CAST(SCHDUL_DE AS DATE)                                              AS HOLIDAY_DATE,
  CAST(LISTAGG(DISTINCT SCHDUL_TIT, ' / ') WITHIN GROUP (ORDER BY SCHDUL_TIT) AS VARCHAR) AS HOLIDAY_NM,
  CAST(COUNT(*) AS NUMBER(5,0))                                        AS SRC_ROW_CNT,
  CAST('CRM' AS VARCHAR)                                               AS DW_SOURCE_SYSTEM,
  CAST('BRONZE_CRM.TM_CM_SCHDUL_MNG' AS VARCHAR)                       AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                                   AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()::TIMESTAMP_NTZ                                   AS DW_UPDATE_TS,
  CAST('b67f4402-58f8-4f78-bd36-31fecd4eb48e' AS VARCHAR)                               AS DW_BATCH_ID
FROM src
GROUP BY SCHDUL_DE