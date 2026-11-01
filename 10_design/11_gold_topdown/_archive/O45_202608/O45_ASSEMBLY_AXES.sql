-- ============================================================================
-- O45_ASSEMBLY_AXES.sql — 보고서 섹션 조립 가능화: 축 3종 + 팩트 1종 신설
-- Co-authored with CoCo
-- 작성 2026-08-06 · 정본 이슈 = 20_issue/00_INDEX_이슈원장.md §O45
-- ----------------------------------------------------------------------------
-- 배경: O44 에서 보고서필드 507행을 전수 grain 검사한 결과 **구조적 조립불가 128필드**가
--   나왔다. 그 128건을 컬럼 단위로 원인 배정하니 **91건(71%)이 축 3종 + 팩트 1종**으로 열린다.
--     P0 매핑교정      39필드 (GOLD 변경 없음 — 생성기 override)
--     P1 회원귀속차원   41필드 (컬럼 2 + 뷰 1)
--     P2 회비팩트        7필드 (팩트 1)
--     P3 마케팅캠페인    4필드 (차원 1 + FK 2)
--
-- 🔴 실행 규약(dbt_project.yml gold.fact 주석 · O40-B P82):
--   GOLD 구조 소유주는 `03_top-down_gold/06_DDL.sql` 이고 dbt 는 구조를 덮지 않는다.
--   컬럼 추가 절차 = ① 06_DDL.sql 수정 ② **이 스크립트 실행** ③ INFORMATION_SCHEMA 확인
--                   ④ 모델 수정 ⑤ dbt build ⑥ 신규 컬럼 비NULL 검증
--   이 스크립트는 ②다. ①④는 이미 반영됐다. ⑤는 사용자 승인 후 실행한다.
--
-- 🔴 `CREATE OR REPLACE TABLE` 을 쓰지 않는다 — FK·GRANT·COMMENT 가 소실된다(순서9 G-1/G-2).
--   신규는 `CREATE TABLE IF NOT EXISTS`, 기존은 `ALTER TABLE ADD COLUMN`(물리 위치 = 맨 끝).
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE GN_DW;

-- ────────────────────────────────────────────────────────────────────────────
-- §0. 사전 기준값 캡처 (변경 후 대조용 — 이 값이 바뀌면 회귀다)
-- ────────────────────────────────────────────────────────────────────────────
--  기대 기준값 (실측 2026-08-06):
--    FACT_MEMBER_EVENT          4,633,105 행 · SPONSORSHIP_SK 비영 0 (배선 전)
--    FACT_MEMBER_COHORT         1,585,949 행 = 고유회원 1,585,949
--    DIM_CAMPAIGN                  36,144 행
--    FACT_AD_PERFORMANCE          243,545 행 · AD_CREATIVE_SK 비영 0
--    SILVER.CRM_PAYMENT_BILLING 47,521,872 행 · SUM(RQEST_AMT) 891,959,790,888
SELECT 'BASELINE' AS phase,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_EVENT)                    AS fme_rows,
       (SELECT COUNT_IF(SPONSORSHIP_SK <> 0) FROM GOLD.FACT_MEMBER_EVENT) AS fme_spb_nonzero,
       (SELECT COUNT(*) FROM GOLD.FACT_MEMBER_COHORT)                   AS fmc_rows,
       (SELECT COUNT(*) FROM GOLD.DIM_CAMPAIGN)                         AS dim_campaign_rows,
       (SELECT COUNT(*) FROM GOLD.FACT_AD_PERFORMANCE)                  AS fap_rows,
       (SELECT SUM(RQEST_AMT) FROM SILVER.CRM_PAYMENT_BILLING)          AS silver_billed;

-- ────────────────────────────────────────────────────────────────────────────
-- §1. [P3] SILVER.CRM_MARKETING_CAMPAIGN — 마케팅캠페인 마스터 (신규)
--     구조 소유주 = 04_silver_design/08_SILVER_테이블DDL_20260714.sql
--     원천 BRONZE_CRM.TM_CM_MKTNG_CMPGN_MNG 323행 (이미 _sources.yml 등록됨)
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS SILVER.CRM_MARKETING_CAMPAIGN (
    MK_CMPGN_CD        VARCHAR      COMMENT 'PK. 마케팅캠페인 코드. TM_CM_CMPGN_MNG.MKTG_CMPGN_NM(NUMBER)의 문자 표현과 조인된다',
    MK_CMPGN_NM        VARCHAR      COMMENT '마케팅캠페인명. AGENCY 광고 CAMPAIGN_NM 과 이름 매칭되는 축(76/105 = 72.4%)',
    USE_YN             VARCHAR      COMMENT '사용여부(원천 그대로 — 폐지분도 과거 실적에 붙으므로 제외하지 않는다)',
    RM                 VARCHAR      COMMENT '비고',
    DW_SOURCE_SYSTEM   VARCHAR      COMMENT '원천 시스템',
    DW_LOAD_TS         TIMESTAMP_NTZ COMMENT '적재 시각',
    DW_UPDATE_TS       TIMESTAMP_NTZ COMMENT '갱신 시각',
    DW_BATCH_ID        VARCHAR      COMMENT '배치 식별'
)
COMMENT = '[O45] 마케팅캠페인 마스터. AGENCY(광고) ↔ CRM(개발실적)을 잇는 유일한 conformed 축. Q16 「전건 NULL」 오진 철회의 산물 — 실측 브리지 조인 100% 해소.';

-- ────────────────────────────────────────────────────────────────────────────
-- §2. [P3] GOLD.DIM_MARKETING_CAMPAIGN — 마케팅캠페인 차원 (신규)
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS GOLD.DIM_MARKETING_CAMPAIGN (
    MKTG_CAMPAIGN_SK    NUMBER       NOT NULL COMMENT '대리키 = gold_sk(MK_CMPGN_CD). 0 = (미매핑) Unknown 멤버',
    MKTG_CAMPAIGN_BK    VARCHAR      COMMENT '업무키 = 원천 MK_CMPGN_CD',
    MKTG_CAMPAIGN_NAME  VARCHAR      COMMENT '마케팅캠페인명. 🔴광고측(AGENCY CAMPAIGN_NM)과의 조인 키다 — 이름매칭이 유일 경로(AGENCY 원천에 캠페인 코드 컬럼 0개)',
    USE_YN              VARCHAR      COMMENT '사용여부(원천 그대로)',
    DEV_CAMPAIGN_CNT    NUMBER       COMMENT '🔴**팬아웃 경고축**: 이 마케팅캠페인에 매달린 개발캠페인 수. 1 보다 크면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다. 실측 2026-08-06 — 모집단 전체 323개: 평균 105.0·최대 13,176·합 33,915 / 광고 도달분 81개 한정: 평균 120.4·최대 901·합 9,750 / naive 조인 39,669,103행 = **181.6배**. 결합은 마케팅캠페인 grain 에서만 할 것',
    DW_SOURCE_SYSTEM    VARCHAR      COMMENT '원천 시스템',
    DW_LOAD_TS          TIMESTAMP_NTZ COMMENT '적재 시각',
    DW_UPDATE_TS        TIMESTAMP_NTZ COMMENT '갱신 시각',
    DW_BATCH_ID         VARCHAR      COMMENT '배치 식별',
    CONSTRAINT PK_DIM_MARKETING_CAMPAIGN PRIMARY KEY (MKTG_CAMPAIGN_SK)
)
COMMENT = '[O45] 마케팅캠페인 conformed 차원 (323행+Unknown). 광고 ↔ CRM 후원 결합이 성립하는 **유일한 grain**. 실측 2026-08-06: 광고 도달 89.7%(218,402/243,545) · 개발실적 도달 99.42% · 마케팅캠페인 grain 개발단가 73,842원. 🔴개발캠페인 grain 으로 내리면 181.6배 팬아웃(218,402행 → 39,669,103행) — 현업 광고비 배분 규칙 필요(Q10 재정의).';

-- ────────────────────────────────────────────────────────────────────────────
-- §3. [P3] 기존 객체에 마케팅캠페인 FK 추가 (물리 위치 = 맨 끝)
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE GOLD.DIM_CAMPAIGN
    ADD COLUMN IF NOT EXISTS MKTG_CAMPAIGN_SK NUMBER
    COMMENT '[O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 🔴MARKETING_CAMPAIGN 은 라벨이라 광고 팩트가 참조할 수 없었다 — 이 FK 가 conformed 축이다. 0 = 미매핑';

ALTER TABLE GOLD.FACT_AD_PERFORMANCE
    ADD COLUMN IF NOT EXISTS MKTG_CAMPAIGN_SK NUMBER
    COMMENT '[O45] 마케팅캠페인 대리키 (FK→DIM_MARKETING_CAMPAIGN). 광고↔CRM 결합축. 도달 89.7% · 미도달 10.3%는 0(미매핑) — 이 버킷을 「미집행」으로 읽지 말 것. 🔴개발캠페인(CAMPAIGN_SK) grain 결합 금지(200배 팬아웃)';

-- ────────────────────────────────────────────────────────────────────────────
-- §4. [P1] FACT_MEMBER_COHORT — 획득 부서·획득 후원사업 축 추가
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE GOLD.FACT_MEMBER_COHORT
    ADD COLUMN IF NOT EXISTS ACQ_ORG_SK NUMBER
    COMMENT '[O45] **획득(최초개발) 시점 실적부서** 대리키 (FK→DIM_ORG). 원천 ACMSLT_DEPT_CD 채움 99.9999%·343종. 🔴개발실적보고의 「부서」(=사건 부서)와 다르다 — 사건 부서는 FACT_MEMBER_EVENT.ORG_SK';

ALTER TABLE GOLD.FACT_MEMBER_COHORT
    ADD COLUMN IF NOT EXISTS ACQ_SPONSORSHIP_SK NUMBER
    COMMENT '[O45] **획득 시점 후원사업** 대리키 (FK→DIM_SPONSORSHIP). 원천 SPNSR_BSNS_ID 채움 100%·29종·고아 0. 🔴납입 대상 후원사업과 다르다 — 회비별 후원사업은 FACT_MEMBER_FEE.SPONSORSHIP_SK';

-- ────────────────────────────────────────────────────────────────────────────
-- §5. [P2] GOLD.FACT_MEMBER_FEE — 회비 분해 팩트 (신규)
--     grain: MEMBER_DK × MONTH_KEY × SPONSORSHIP_SK × FEE_DIV_CD × PAYMENT_TYPE × PAYMENT_SK
--     실측 조합수 ≈ 39,810,101
--     🔴 왜 FMM 에 컬럼 추가가 아닌가: FMM grain = 회원×월 정확히 1행(40,054,883 = distinct
--        member-month). 후원사업을 붙이면 회원-월-후원사업 39,563,730 vs 회원-월 37,148,615
--        = 6.5% 증가로 **grain 이 깨진다**. grain 이 다르면 팩트를 나눈다.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS GOLD.FACT_MEMBER_FEE (
    -- 🔴 타입 규약(2026-08-06 교정): FK 는 **참조 PK 와 타입이 정확히 일치**해야 한다.
    --    DIM_DATE.DATE_SK = NUMBER(8,0) 이므로 *_DATE_SK 를 맨 NUMBER(=38,0)로 두면
    --    "Primary key and foreign key data type does not match" 로 FK 선언이 실패한다.
    --    MEMBER_DK 는 VARCHAR(10)(전 팩트 일관), MONTH_KEY 는 NUMBER(6,0)(전 팩트 일관).
    MONTH_KEY           NUMBER(6,0)  COMMENT '회비월 YYYYMM (FK→DIM_MONTH 개념축). 무효/NULL 이면 납입월 폴백, 둘 다 무효면 0=Unknown월 — FMM 과 동일 규칙',
    MEMBER_DK           VARCHAR(10)  COMMENT '회원 자연키 (VARCHAR(10) 규약 · FK→DIM_MEMBER.MEMBER_DK)',
    SPONSORSHIP_SK      NUMBER(38,0) COMMENT '🔴**납입 대상** 후원사업 대리키 (FK→DIM_SPONSORSHIP). 회비 행에 붙은 값이다(원천 채움 99.83%). 획득 후원사업(FMC.ACQ_SPONSORSHIP_SK)과 의미가 다르다',
    PAYMENT_SK          NUMBER(38,0) COMMENT '결제수단 대리키 (FK→DIM_PAYMENT). ⚠️라벨 커버리지 99.3% — 원천 11종 중 5종은 코드그룹 미특정으로 0(미매핑). 원본은 SETLE_CD 참조',
    FEE_DIV_CD          VARCHAR      COMMENT '회비구분 코드(PM010). 🔴기부금 행은 원천이 NULL — 결측이 아니라 해당없음',
    FEE_DIV_NAME        VARCHAR      COMMENT '회비구분명: 정기·선물금·일시·긴급구호 (PM010 라벨)',
    PAYMENT_TYPE        VARCHAR      COMMENT '납입유형 = 회비/기부금. 🔴납부율·미납 분석은 회비만으로 스코프 — 기부금은 청구(RQEST_AMT) 전건 NULL 이라 분모에 못 들어간다(O40)',
    SETLE_CD            VARCHAR      COMMENT 'degen: 결제수단 원본 코드. 라벨 없는 5종(3·10·6·13·7)을 잃지 않기 위해 보존 — 현업 코드그룹 확인 대상(O45-B)',
    LAST_PAY_DATE_SK    NUMBER(8,0)  COMMENT '해당 조합의 **최종 납입일** (FK→DIM_DATE). 🔴시점 축이며 합계가 아니다. FMM 은 월 팩트라 「기준일(납입일)」은 이 팩트에서만 답한다',
    LAST_BILL_DATE_SK   NUMBER(8,0)  COMMENT '해당 조합의 최종 청구일 (FK→DIM_DATE)',
    BILLED_AMT          NUMBER(38,2) COMMENT '청구액(원) = SUM(RQEST_AMT). FMM 과 동일 식 → 전체 합계 일치 필수(기준값 891,959,790,888)',
    PAID_FEE            NUMBER(38,2) COMMENT '납입 총액(원) = 회비 + 기부금. 🔴납부율 분자로 쓰지 말 것(O40)',
    PAID_FEE_BILLABLE   NUMBER(38,2) COMMENT '회비 납입액(원) — 납부율 분자 정본(O40)',
    UNPAID_BILLED_AMT   NUMBER(38,2) COMMENT '미납 청구액(원) — DEC-3 정본 = PAY_STAT_CD IN (F, NULL) 인 청구액. 🔴차감식 아님. ⚠️조회 시점 스냅샷',
    BILLING_ROWS        NUMBER       COMMENT '집계된 원천 회비행 수. 🔴금액도 「건수」도 아니다(정본 (건) 정의는 CONF-2 미결)',
    UNPAID_FLAG         BOOLEAN      COMMENT '해당 조합에 미납 청구행이 하나라도 있는가(BOOLOR_AGG)',
    DW_SOURCE_SYSTEM    VARCHAR      COMMENT '원천 시스템',
    DW_LOAD_TS          TIMESTAMP_NTZ COMMENT '적재 시각',
    DW_UPDATE_TS        TIMESTAMP_NTZ COMMENT '갱신 시각',
    DW_BATCH_ID         VARCHAR      COMMENT '배치 식별'
)
COMMENT = '[O45] 회비 분해 팩트. grain = 회원 × 회비월 × 후원사업 × 회비구분 × 납입유형 × 결제수단(≈39.8M행). 🔴FACT_MEMBER_MONTHLY 의 회비 measure 와 같은 표에서 합산 금지 — 동일 원천 이중계상이다. FMM = 회원-월 상태·요약 전용, 이 팩트 = 회비 분해 전용. measure 식은 FMM 과 완전히 동일(O40 정본)하므로 총계가 일치해야 한다.';

-- FK: 신규 팩트의 차원 참조 (순서9 규약 — fact FK 는 명시 선언)
ALTER TABLE GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_SPONSORSHIP
    FOREIGN KEY (SPONSORSHIP_SK) REFERENCES GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK);
ALTER TABLE GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_PAYMENT
    FOREIGN KEY (PAYMENT_SK) REFERENCES GOLD.DIM_PAYMENT (PAYMENT_SK);
ALTER TABLE GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_PAY_DATE
    FOREIGN KEY (LAST_PAY_DATE_SK) REFERENCES GOLD.DIM_DATE (DATE_SK);
ALTER TABLE GOLD.FACT_MEMBER_FEE ADD CONSTRAINT FK_FMF_BILL_DATE
    FOREIGN KEY (LAST_BILL_DATE_SK) REFERENCES GOLD.DIM_DATE (DATE_SK);

ALTER TABLE GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_ACQ_ORG
    FOREIGN KEY (ACQ_ORG_SK) REFERENCES GOLD.DIM_ORG (ORG_SK);
ALTER TABLE GOLD.FACT_MEMBER_COHORT ADD CONSTRAINT FK_FMC_ACQ_SPONSORSHIP
    FOREIGN KEY (ACQ_SPONSORSHIP_SK) REFERENCES GOLD.DIM_SPONSORSHIP (SPONSORSHIP_SK);
ALTER TABLE GOLD.DIM_CAMPAIGN ADD CONSTRAINT FK_DIM_CAMPAIGN_MKTG
    FOREIGN KEY (MKTG_CAMPAIGN_SK) REFERENCES GOLD.DIM_MARKETING_CAMPAIGN (MKTG_CAMPAIGN_SK);
ALTER TABLE GOLD.FACT_AD_PERFORMANCE ADD CONSTRAINT FK_FAP_MKTG_CAMPAIGN
    FOREIGN KEY (MKTG_CAMPAIGN_SK) REFERENCES GOLD.DIM_MARKETING_CAMPAIGN (MKTG_CAMPAIGN_SK);

-- ────────────────────────────────────────────────────────────────────────────
-- §6. 구조 반영 검증 (③ 단계 — dbt build 전에 반드시 통과해야 한다)
--     🔴 이 관문을 건너뛰면 O40 의 무증상 컬럼 폐기가 재발한다(P82).
-- ────────────────────────────────────────────────────────────────────────────
SELECT 'GATE-1 신규 객체 4종' AS gate,
       COUNT_IF(TABLE_SCHEMA='SILVER' AND TABLE_NAME='CRM_MARKETING_CAMPAIGN')    AS silver_mktg,
       COUNT_IF(TABLE_SCHEMA='GOLD'   AND TABLE_NAME='DIM_MARKETING_CAMPAIGN')    AS gold_dim_mktg,
       COUNT_IF(TABLE_SCHEMA='GOLD'   AND TABLE_NAME='FACT_MEMBER_FEE')           AS gold_fact_fee
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('SILVER','GOLD');
--  기대: silver_mktg=1 · gold_dim_mktg=1 · gold_fact_fee=1

SELECT 'GATE-2 신규 컬럼 4종' AS gate, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='GOLD'
  AND (   (TABLE_NAME='FACT_MEMBER_COHORT'  AND COLUMN_NAME IN ('ACQ_ORG_SK','ACQ_SPONSORSHIP_SK'))
       OR (TABLE_NAME='DIM_CAMPAIGN'        AND COLUMN_NAME = 'MKTG_CAMPAIGN_SK')
       OR (TABLE_NAME='FACT_AD_PERFORMANCE' AND COLUMN_NAME = 'MKTG_CAMPAIGN_SK'))
ORDER BY TABLE_NAME, COLUMN_NAME;
--  기대: 4행 (전부 NUMBER)

-- ⏸ 여기서 멈춘다. 다음은 `dbt build` 이며 **사용자 승인 후** 실행한다.
--    build 후 §7 사후 검증(별도 스크립트 O45_VERIFY.sql)을 반드시 돌릴 것.
