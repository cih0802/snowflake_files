-- =============================================================================
-- Purpose    : O266 — 디지털 최종정산금액 배선 · 마케팅캠페인 × 월 비용·개발 결합 팩트·SV · MSTR 읽기 권한 (기존 환경 갱신)
-- Target     : GOLD.FACT_AD_PERFORMANCE · GOLD.WIDE_AD_COMBINED · GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST · SERVING.SV_AD · SV_MKTG_CAMPAIGN_COST · SV_MEMBER_COHORT · AGENT_MARKETING
-- Run order  : 기존 환경 갱신 #45 ([D0] → [D1] → 👤 dbt 재배포·build → [D2] → SV 3종 재배포 → Agent 버전업 → [D3])
-- Depends on : 45_DEPLOY_SEND_GBN_AT_OPEN.sql(#43·#44) 선행 · 06_DDL 2026-10-28 O266 판 · GN_DW.MSTR 스키마 실재
-- Issue      : O266 (현업 = 마케팅 Agent 피드백 1~4)
-- =============================================================================
-- 왜 이 파일이 필요한가
--   ① 「광고비」 질문에 최종정산금액(광고비+마크업+부가세)을 원했다 — 원천 DGT_AD_CMPGN_DTLS.LAST_STMT_AMT 는 SILVER 에서 멈춰 있었다.
--      (영상·재방송 원천에는 정산 개념 컬럼이 없다 ⇒ 디지털만 · 사용자 결정 ㉠-b = 광고비와 나란히)
--   ② 「마케팅캠페인별 광고비 / 개발건수 / 제작비를 한 표로」 — SV 3개로 나뉘어 표 3개가 나왔다 ⇒ 결합 팩트 + SV 신설(결정 ㉡-a).
--      개발(건) = MSTR 기준 ⇒ dbt 롤(GN_DW_DBT)에 GN_DW.MSTR 읽기 권한이 필요하다(정본 = 00_mstr_schema_role.sql [4-b]).
--   ③ LTV 표 형식 고정 · 캠페인명 조회 재시도 = Agent spec(12_agent개선과제/tools/o266_patch_marketing_spec.py) · SV_MEMBER_COHORT VQR.
--   WARN: 06_DDL 전체를 재실행하지 마라(CREATE OR REPLACE ⇒ 데이터 소실 · R2-9). 새 환경은 이 파일이 필요 없다.
-- =============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [D0] 권한 — dbt 실행 롤 MSTR 읽기(정본 = 15_MSTR 이관 PoC/snowflake 적용 ddl/00_mstr_schema_role.sql [4-b] · 재실행 무해)
GRANT USAGE ON SCHEMA GN_DW.MSTR TO ROLE GN_DW_DBT;
GRANT SELECT ON ALL TABLES    IN SCHEMA GN_DW.MSTR TO ROLE GN_DW_DBT;
GRANT SELECT ON ALL VIEWS     IN SCHEMA GN_DW.MSTR TO ROLE GN_DW_DBT;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.MSTR TO ROLE GN_DW_DBT;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA GN_DW.MSTR TO ROLE GN_DW_DBT;

-- [D0-b] 변경 전 기준값(build 전 · 결과를 기록한다)
SELECT 'before' AS phase,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                                  AS fap_rows,
       (SELECT SUM(AD_COST) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                              AS fap_ad_cost,
       (SELECT SUM(LAST_STMT_AMT) FROM GN_DW.SILVER.AGENCY_AD_ROW_DGT)                        AS silver_dgt_settle;

-- [D1] 열 추가·신규 테이블 (dbt build 전) — 맨 끝 · 재실행 무해
ALTER TABLE GN_DW.GOLD.FACT_AD_PERFORMANCE ADD COLUMN IF NOT EXISTS LAST_STMT_AMT NUMBER(38,2)
    COMMENT '최종정산금액(원) = 광고비 + 마크업 + 부가세(원천 DGT_AD_CMPGN_DTLS.LAST_STMT_AMT) [DGT 전용 · VIDEO 는 정산 개념 컬럼 없음 · REBRDC TOT_COST 는 총비용이라 대체물 아님 ⇒ NULL] (O266)';
-- 신규 결합 팩트 — 구조 정본 = 06_DDL FACT_MKTG_CAMPAIGN_MONTHLY_COST 블록(IF NOT EXISTS 로 옮김)
CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST (
    MKTG_CAMPAIGN_SK    NUMBER(38,0)    NOT NULL COMMENT '마케팅캠페인 대리키(FK→DIM_MARKETING_CAMPAIGN). 0 = (미매핑) — 광고·개발이 마케팅캠페인에 닿지 않은 버킷(제작비는 0 버킷에 넣지 않는다).',
    MONTH_KEY           NUMBER(6,0)     NOT NULL COMMENT '연월 YYYYMM(광고 = 실적일 · 제작비 = 결의 작성일 · 개발 = MSTR 기준년월).',
    AD_COST             NUMBER(38,2)    COMMENT '광고비(원) = FACT_AD_PERFORMANCE.AD_COST 합(디지털+영상+재방송). 그 달 광고 행이 없으면 NULL.',
    AD_COST_DIGITAL     NUMBER(38,2)    COMMENT '디지털 광고비(원) — 대행사 리포트 광고비(마크업·부가세 제외).',
    AD_COST_VIDEO       NUMBER(38,2)    COMMENT '영상 광고비(원) — 최종광고비(정산 개념 컬럼 없음).',
    AD_COST_REBROADCAST NUMBER(38,2)    COMMENT '재방송 광고비(원) — 편성비(총비용 TOT_COST 아님).',
    LAST_STMT_AMT       NUMBER(38,2)    COMMENT '디지털 최종정산금액(원) = 광고비 + 마크업 + 부가세. 디지털 전용 — 영상·재방송 정산액은 원천에 없다.',
    PROD_COST           NUMBER(38,2)    COMMENT '제작비(원) = 지출결의 금액 중 세부캠페인코드 기재분 전체. 🔴 제작비 세세목 정의가 아직 없어(현업 확인 대기) 세세목으로 거르지 않는다 · 코드 미기재 지출은 캠페인을 알 수 없어 빠진다 ⇒ 전체 지출의 일부만 잡히며 실제 캠페인 제작비와 다르다.',
    PROD_RESOLUTION_CNT NUMBER(38,0)    COMMENT '제작비 결의 건수(그 달 · COUNT DISTINCT · 월 간 합산 금지).',
    DEV_CNT_MSTR        NUMBER(18,4)    COMMENT '개발(건) MSTR 기준 = 후원금액 ÷ 10,000 · 개발구분 신규·증액·재후원(1·2·4). GN_DW 개발건수(사건 건수)와 다르다.',
    NEW_DEV_CNT_MSTR    NUMBER(18,4)    COMMENT '신규 개발(건) MSTR 기준(개발구분 1).',
    DEV_MEMBERS_MSTR    NUMBER(38,0)    COMMENT '개발 회원수(그 달 · COUNT DISTINCT · 월 간·캠페인 간 합산 금지).',
    DW_SOURCE_SYSTEM    VARCHAR(20)     COMMENT '원천 시스템(MULTI = AGENCY·ERP·MSTR 결합).',
    DW_LOAD_TS          TIMESTAMP_NTZ   COMMENT '적재 시각',
    DW_UPDATE_TS        TIMESTAMP_NTZ   COMMENT '갱신 시각',
    DW_BATCH_ID         VARCHAR         COMMENT 'dbt invocation_id',
    PRIMARY KEY (MKTG_CAMPAIGN_SK, MONTH_KEY)
) COMMENT = '마케팅캠페인 × 월 비용·개발 결합 팩트. [Grain: MKTG_CAMPAIGN_SK × MONTH_KEY]. [주의: 개발단가 = 광고비 ÷ MSTR 개발(건) — SV_AD 공7(대행사 CRM 개발건)과 분모가 다르다 · 제작비는 캠페인코드 기재분만]. [원천: FACT_AD_PERFORMANCE · FACT_EXPENSE_RESOLUTION · MSTR.F_MM_SPNSR_DVLP_SUM]. (O266)';
-- [D1-b] [O266-B] 제작비 COMMENT 갱신(위 IF NOT EXISTS 가 건너뛴 기존 테이블용 · 재실행 무해 · 문안 = 06_DDL 과 동일)
ALTER TABLE GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST MODIFY COLUMN PROD_COST
    COMMENT '제작비(원) = 지출결의 금액 중 세부캠페인코드 기재분 전체. 🔴 제작비 세세목 정의가 아직 없어(현업 확인 대기) 세세목으로 거르지 않는다 · 코드 미기재 지출은 캠페인을 알 수 없어 빠진다 ⇒ 전체 지출의 일부만 잡히며 실제 캠페인 제작비와 다르다.';

-- 👤 [dbt] 재배포(ALTER DBT PROJECT … ADD VERSION) → build --select FACT_AD_PERFORMANCE+ FACT_MKTG_CAMPAIGN_MONTHLY_COST
--   운영계 = 정규 build 에 포함(R2-9 · 기간 지정 재적재 없음) · 신규 팩트는 전 구간 재계산형(gold_fact_purge TRUNCATE)이라 백필이 아니다.

-- [D2] 대사 — 기대값(개발계 ZS83821 · build 전 원천 실측 · 2026-10-28)
--   FAP 정산액 합 ≈ SILVER DGT 합 41,089,073,328.05([D0-b] 실측 · 원천 DOUBLE ⇒ NUMBER(38,2) 행별 반올림 차 수백 원 허용) · DIGITAL 외 정산액 0행 · NULL 5행
--   결합 팩트 광고비 합 = FAP 광고비 합(60,191,254,704.38 · 미매핑 0 버킷 포함) · 개발(건) 합 = MSTR 1·2·4 합 885,881.0585
--   제작비 합 = 지출결의 MKTG_CAMPAIGN_SK <> 0 합 3,295,334,668 · PK 중복 0
--   모델 렌더 사전 실측(build 전 · 임시 테이블) = 3,960행 · 202301~202610 · 미매핑(SK 0) 광고비 8,932,473,528.51 · 개발(건) 1,426.1
SELECT 'fap'                                                                   AS chk,
       SUM(LAST_STMT_AMT)                                                      AS settle_sum,
       COUNT_IF(AD_SOURCE_TYPE <> 'DIGITAL' AND LAST_STMT_AMT IS NOT NULL)     AS non_digital_settle,
       COUNT_IF(AD_SOURCE_TYPE = 'DIGITAL' AND LAST_STMT_AMT IS NULL)          AS digital_null
FROM GN_DW.GOLD.FACT_AD_PERFORMANCE;

SELECT (SELECT SUM(AD_COST) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST)                       AS mcc_ad,
       (SELECT SUM(AD_COST) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE WHERE PERF_DATE_SK > 0)            AS fap_ad,
       (SELECT SUM(LAST_STMT_AMT) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST)                 AS mcc_settle,
       (SELECT SUM(DEV_CNT_MSTR) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST)                  AS mcc_dev,
       (SELECT ROUND(SUM(SPNSR_AMT_CNT), 4) FROM GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM
         WHERE DVLP_DIV_CD IN ('1', '2', '4'))                                                       AS mstr_dev,
       (SELECT SUM(PROD_COST) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST)                     AS mcc_prod,
       (SELECT SUM(SUM_AMT) FROM GN_DW.GOLD.FACT_EXPENSE_RESOLUTION
         WHERE MKTG_CAMPAIGN_SK <> 0 AND DATE_SK > 0)                                               AS fer_prod,
       (SELECT COUNT(*) - COUNT(DISTINCT MKTG_CAMPAIGN_SK, MONTH_KEY)
          FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST)                                          AS pk_dup;

-- 👤 [D2 다음] SV 재배포 3종 = 05_07_SV_DDL_AD.sql · 🆕 05_31_SV_DDL_MKTG_CAMPAIGN_COST.sql · 05_03_SV_DDL_MEMBER_COHORT.sql
--            Agent = cortex_project/agents/AGENT_MARKETING/agent_spec.yaml → 12_agent개선과제/tools/o217_agent_io.py apply AGENT_MARKETING <yaml>

-- [D3] SV 반영 확인 — 지표 3종 · VQR 2종 실재
SELECT SEMANTIC_VIEW_NAME, NAME
FROM GN_DW.INFORMATION_SCHEMA.SEMANTIC_METRICS
WHERE (SEMANTIC_VIEW_NAME = 'SV_AD' AND NAME = 'AD_SETTLE_AMT')
   OR (SEMANTIC_VIEW_NAME = 'SV_MKTG_CAMPAIGN_COST' AND NAME IN ('TOTAL_AD_COST', 'TOTAL_PROD_COST', 'TOTAL_DEV_CNT_MSTR'))
ORDER BY 1, 2;
