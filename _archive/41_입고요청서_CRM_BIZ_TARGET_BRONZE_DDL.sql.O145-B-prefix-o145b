-- BRONZE DDL 제안 — CRM 사업목표 원천 테이블 (입고 요청서 첨부)
-- Co-authored with CoCo
-- ============================================================================
-- 목적: 현업으로부터 사업목표 데이터 입고 시 BRONZE 적재 대상 테이블.
-- 원천: CRM (현업 수동입력 — 매출 실적 확인 후 사후 조정 프로세스)
-- 블로커: E-6 (40_입고대기_원천의존.md)
-- SILVER 후속: GN_DW.SILVER.CRM_BIZ_TARGET → GOLD FTG-B
-- ============================================================================
-- 업무 특성:
--   - 목표는 ERP가 아닌 CRM에서 관리 (사후 조정 방식)
--   - 추경 발생 시 기존 행 수정 X → 새 행 추가 (버전 누적)
--   - 목표유형: '당초' / '추경1차' / '추경2차'
-- ============================================================================

CREATE TABLE IF NOT EXISTS GN_DW.BRONZE_CRM.CRM_BIZ_TARGET (
    -- === 업무 키 ===
    TARGET_YEAR         NUMBER(4,0)     COMMENT '목표연도 (YYYY)',
    MONTH_NO            NUMBER(2,0)     COMMENT '월 (1~12, 연간이면 NULL)',
    ORG_CD              VARCHAR(50)     COMMENT '조직코드 (FK→DIM_ORG)',
    ORG_NM              VARCHAR(200)    COMMENT '조직명 (부서/팀)',
    SPONSOR_BIZ_NM      VARCHAR(200)    COMMENT '후원사업명',
    CAMPAIGN_NM         VARCHAR(200)    COMMENT '캠페인명 (없으면 NULL)',

    -- === 목표 건수 ===
    TARGET_TYPE         VARCHAR(20)     COMMENT '목표유형: 당초 / 추경1차 / 추경2차',
    TARGET_CNT          NUMBER(18,4)    COMMENT '목표 건수(건) — 지표사전 #152~155 기준, GOLD FACT_TARGET_BIZ(ANNUAL/SUPP_GOAL_CNT)와 정합. ※현업이 금액(원)으로만 관리 시 SILVER에서 /10000 파생',

    -- === 확정 이력 ===
    CONFIRMED_DATE      DATE            COMMENT '등록일 (이 목표를 확정한 일자)',
    CONFIRMED_BY        VARCHAR(100)    COMMENT '확정자 (입력 담당자)',
    REMARK              VARCHAR(500)    COMMENT '비고 (사유 등 자유기술)',

    -- === 메타/감사 (BRONZE 공통) ===
    _SRC_FILE           VARCHAR         COMMENT '원천 파일명 또는 CRM 화면명',
    _SRC_SHEET          VARCHAR         COMMENT '시트명 (Excel인 경우)',
    _LOADED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP() COMMENT '적재 시각',
    _BATCH_ID           VARCHAR         COMMENT '적재 배치 식별자'
)
COMMENT = 'BRONZE — CRM 사업목표 원천 (현업 CRM 입력). 버전누적(당초/추경 공존). → SILVER.CRM_BIZ_TARGET으로 정제.'
;

-- ============================================================================
-- 적재 예시 (CSV/Excel 파일 입고 시)
-- ============================================================================
/*
COPY INTO GN_DW.BRONZE_CRM.CRM_BIZ_TARGET
FROM @GN_DW.BRONZE_CRM.STG_CRM_FILES/biz_target/
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"')
ON_ERROR = 'CONTINUE'
;
*/

-- ============================================================================
-- 입력 규칙 (현업 안내용)
-- ============================================================================
/*
1. 목표유형은 '당초', '추경1차', '추경2차' 중 택1
2. 조직코드는 기존 DIM_ORG 코드와 동일하게 입력
3. 추경 시 기존 행 수정 X → 새 행 추가 (동일 월×조직×후원사업에 여러 유형 공존)
4. 등록일(CONFIRMED_DATE)은 이 목표를 확정한 날짜 (필수)

예시:
| TARGET_YEAR | MONTH_NO | ORG_CD | ORG_NM   | SPONSOR_BIZ_NM | TARGET_TYPE | TARGET_CNT | CONFIRMED_DATE | REMARK       |
| 2026        | 1        | ORG001 | 서울지부 | 아동후원       | 당초        | 30000      | 2026-01-05     |              |
| 2026        | 1        | ORG001 | 서울지부 | 아동후원       | 추경1차     | 35000      | 2026-04-10     | 1Q 실적 반영 |
*/
