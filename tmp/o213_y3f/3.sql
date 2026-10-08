CREATE OR REPLACE TABLE GN_DW.SILVER.GA4_USER_DEMOGRAPHIC (
    EVENT_DT            DATE            COMMENT '집계 일자(원천 DATE YYYYMMDD).',
    DEVICE_CATEGORY     VARCHAR(20)     COMMENT '기기 카테고리 desktop·mobile·tablet (GA4 원값).',
    USER_GENDER         VARCHAR(20)     COMMENT '성별 female·male·unknown (GA4 추정 · unknown = 추정 불가 버킷).',
    USER_AGE_BRACKET    VARCHAR(20)     COMMENT '연령대 18-24·25-34·35-44·45-54·55-64·65+·unknown (GA4 추정).',
    SESSIONS            NUMBER(38,0)    COMMENT '세션수(가산).',
    TOTAL_USERS         NUMBER(38,0)    COMMENT '총 사용자수 — grain 단위 고유값 · 🔴 비가산.',
    NEW_USERS           NUMBER(38,0)    COMMENT '신규 사용자수 — grain 단위 고유값 · 🔴 비가산.',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_SOURCE_TABLE     VARCHAR         COMMENT '원천 테이블 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA4 인구통계 일 집계. [Grain: 일 × 기기 × 성별 × 연령대]. [주의: GA4 Data API 집계 · 이벤트 원천(BIGQUERY_*)과 모수 상이 · 사용자수 비가산]. [원천: GA4 → BRONZE_GA4.GA4_USER_DEMOGRAPHIC].'