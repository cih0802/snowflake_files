CREATE OR REPLACE TABLE GN_DW.GOLD.FACT_GA4_DEMOGRAPHIC (
    DATE_SK             NUMBER(8,0)     COMMENT '집계 일자 YYYYMMDD(FK→DIM_DATE · 0 = Unknown).',
    DEVICE_CATEGORY     VARCHAR(20)     COMMENT '기기 desktop·mobile·tablet.',
    USER_GENDER         VARCHAR(20)     COMMENT '성별 female·male·unknown(GA4 추정 불가 버킷).',
    USER_AGE_BRACKET    VARCHAR(20)     COMMENT '연령대 18-24 ~ 65+ · unknown.',
    SESSIONS            NUMBER(38,0)    COMMENT '세션수(가산).',
    TOTAL_USERS         NUMBER(38,0)    COMMENT '총 사용자수 · 🔴 비가산(grain 고유값).',
    NEW_USERS           NUMBER(38,0)    COMMENT '신규 사용자수 · 🔴 비가산(grain 고유값).',
    DW_SOURCE_SYSTEM    VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS          TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID         VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = 'GA4 인구통계 일 팩트. [Grain: DATE_SK × 기기 × 성별 × 연령대]. [주의: GA4 Data API 집계 · 이벤트 원천과 모수 상이 · 사용자수 비가산]. [원천: GA4 → SILVER.GA4_USER_DEMOGRAPHIC].'