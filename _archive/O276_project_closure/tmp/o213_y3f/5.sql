CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_SEARCH_CONSOLE (
    DATE_SK             NUMBER(8,0)     COMMENT '검색 일자 YYYYMMDD(FK→DIM_DATE · 0 = Unknown).',
    QUERY               VARCHAR         COMMENT '검색어(구글 검색창 입력 원문).',
    PAGE                VARCHAR         COMMENT '노출 페이지 URL.',
    COUNTRY             VARCHAR(10)     COMMENT '검색자 국가 ISO alpha-3 소문자 코드(kor·usa…) · 라벨 없음.',
    DEVICE              VARCHAR(20)     COMMENT '검색 기기 DESKTOP·MOBILE·TABLET.',
    CLICKS              NUMBER(38,0)    COMMENT '클릭수(가산).',
    IMPRESSIONS         NUMBER(38,0)    COMMENT '노출수(가산).',
    CTR                 FLOAT           COMMENT '행 단위 클릭률 · 🔴 비가산.',
    POSITION            FLOAT           COMMENT '행 단위 평균순위 · 🔴 비가산.',
    POSITION_X_IMPRESSIONS FLOAT        COMMENT 'POSITION × IMPRESSIONS — 노출 가중 평균순위 산출용(SUM 후 SUM(IMPRESSIONS) 로 나눈다).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '구글 검색 노출·클릭 팩트. [Grain: DATE_SK × QUERY × PAGE × COUNTRY × DEVICE]. [주의: GA4 유입 세션과 다른 원천 · CTR·POSITION 비가산]. [원천: GSC → SILVER.SEARCH_CONSOLE_DATA].'