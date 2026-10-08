CREATE OR REPLACE TABLE GN_DW.SILVER.SEARCH_CONSOLE_DATA (
    EVENT_DT            DATE            COMMENT '검색 일자(원천 DATE).',
    QUERY               VARCHAR         COMMENT '검색어(구글 검색창 입력 원문).',
    PAGE                VARCHAR         COMMENT '노출된 페이지 URL.',
    COUNTRY             VARCHAR(10)     COMMENT '검색자 국가 = ISO 3166-1 alpha-3 소문자 코드(예 kor·usa) · 원천에 라벨 없음.',
    DEVICE              VARCHAR(20)     COMMENT '검색 기기 DESKTOP·MOBILE·TABLET.',
    CLICKS              NUMBER(38,0)    COMMENT '클릭수(가산).',
    IMPRESSIONS         NUMBER(38,0)    COMMENT '노출수(가산).',
    CTR                 FLOAT           COMMENT '클릭률(행 단위) · 🔴 합산·평균 금지 — SUM(CLICKS)/SUM(IMPRESSIONS).',
    POSITION            FLOAT           COMMENT '평균 노출순위(행 단위) · 🔴 합산 금지 — 노출 가중 평균.',
    RESPONSE_AGGREGATION_TYPE VARCHAR(20) COMMENT 'GSC 집계 방식(전건 byPage).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '구글 서치콘솔 검색 성과. [Grain: 일 × 검색어 × 페이지 × 국가 × 기기]. [주의: CTR·POSITION 비가산 · SEARCH_CONSOLE_DATA2 는 중복 복사본이라 미사용]. [원천: GSC → BRONZE_GSC.SEARCH_CONSOLE_DATA].'