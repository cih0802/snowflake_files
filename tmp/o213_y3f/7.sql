CREATE OR REPLACE TABLE GN_DW.GOLD.DIM_RELATIONSHIP (
    RELATNSP_KEY            NUMBER(10,0)    NOT NULL PRIMARY KEY COMMENT '결연키(PK · FACT_RELATION_ACTIVITY.RELATNSP_KEY 조인키).',
    MEMBER_DK               VARCHAR(10)     COMMENT '결연 회원번호(FK→DIM_MEMBER).',
    SPNSR_NO                VARCHAR(9)      COMMENT '후원번호.',
    SPNSR_BSNS_NO           NUMBER(19,0)    COMMENT '후원사업번호.',
    CHILD_CD                NUMBER(10,0)    COMMENT '결연 아동코드.',
    RELATNSP_STRT_DE        DATE            COMMENT '결연 시작일.',
    RELATNSP_DSCNTC_DE      DATE            COMMENT '결연 중단일(진행 중 결연은 NULL).',
    RELATNSP_DSCNTC_YN      VARCHAR(1)      COMMENT '결연 중단 여부 원값 0/1(1 = 중단).',
    IS_DISCONTINUED         VARCHAR(1)      COMMENT '결연 중단 여부 Y/N(원값 1→Y · 0→N 파생).',
    RELATNSP_DSCNTC_RSN_CD  VARCHAR         COMMENT '결연 중단(종료) 사유 코드(MM002).',
    RELATNSP_DSCNTC_RSN_NAME VARCHAR        COMMENT '결연 중단(종료) 사유명(MM002 라벨 · 후원중단·18세종결교체·아동퇴소교체 등).',
    DW_SOURCE_SYSTEM        VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS              TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS            TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID             VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '결연 차원. [Grain: RELATNSP_KEY (1행=1결연)]. [주의: 결연 상태·중단사유는 현재값 · 사건 이력은 FACT_RELATION_CHANGE/DEV]. [원천: CRM → SILVER.CRM_SPONSOR_RELATION].'