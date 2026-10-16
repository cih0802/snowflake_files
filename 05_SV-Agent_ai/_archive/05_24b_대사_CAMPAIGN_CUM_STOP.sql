-- ============================================================================
-- 05_24b_대사_CAMPAIGN_CUM_STOP.sql — 🆕 O236 운영계(jw08094) 반영·대사 스크립트
--   순서 = [0] 신규 테이블만 생성 → 👤 dbt build --select FACT_CAMPAIGN_CUM_STOP → 05_24 SV → [1]~[4] 대사
--   🔴 03_top-down_gold/06_DDL.sql 전체를 다시 돌리지 마라 — CREATE OR REPLACE 라 GOLD 전량이 비워진다.
--      정본 블록은 06_DDL 에 있고, 운영계에는 아래 [0] 만 실행한다(같은 정의 · IF NOT EXISTS).
--   🟢 판정 기준값(jw08094 · 2026-01~09 · FMM 직접 합 · 사용자 실측):
--      중단 246,039.2325 · 개발 249,973.7993 · 연도초(1월 행) 1,535,149.1022 · 전사 누계중단율 13.78%
-- Co-authored with CoCo
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [0] 신규 테이블만 생성(06_DDL 정본 블록과 같은 정의)
CREATE TABLE IF NOT EXISTS GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP (
    BASE_MONTH_KEY        NUMBER(6,0)     NOT NULL COMMENT '기준연월 YYYYMM. 누계 = 같은 해 1월 ~ 이 월. 🔴 기준월 하나를 골라 조회한다 — 여러 기준월을 SUM 하면 누계가 겹친다',
    BASE_YEAR             NUMBER(4,0)     NOT NULL COMMENT '기준연도 YYYY(= BASE_MONTH_KEY 의 연도 · 연도초 기준 해)',
    CAMPAIGN_SK           NUMBER(38,0)    NOT NULL COMMENT '대리키 ※비강제 FK→DIM_CAMPAIGN. 중단·연도초 = 후원사업 대표캠페인(FMSS) · 개발 = 개발 사건 캠페인(FME) · 0 = 미매핑',
    CUM_STOP_CNT          NUMBER(18,4)    COMMENT '누계중단(건) = 1월~기준월 중단 후원사업 약정금액 ÷ 10,000 (FMM STOP_AMT_CNT 와 같은 식)',
    CUM_DEV_CNT           NUMBER(18,4)    COMMENT '누계개발(건) = 1월~기준월 MSTR 개발(건)(인정금액 ÷ 10,000) 합 (FMM DEV_CNT 와 같은 원천)',
    YEAR_START_ACTIVE_CNT NUMBER(18,4)    COMMENT '연도초활동회원(건) = 기준연도 1월 as-of 활동 후원사업 약정금액 ÷ 10,000 (FMM 1월 행 YEAR_START_ACTIVE_CNT 와 같은 판정) · 기준월마다 1회만 들어간다',
    DW_SOURCE_SYSTEM      VARCHAR         NOT NULL COMMENT '원천 시스템 식별 (공통감사)',
    DW_LOAD_TS            TIMESTAMP_NTZ   NOT NULL COMMENT '최초 적재 시각 (공통감사)',
    DW_UPDATE_TS          TIMESTAMP_NTZ   COMMENT '최종 갱신 시각 (공통감사)',
    DW_BATCH_ID           VARCHAR         COMMENT '적재 배치 식별자 = dbt invocation_id (공통감사)'
) COMMENT = '캠페인별 누계중단율(신규 #17) 분자·분모 팩트. [Grain: BASE_MONTH_KEY × CAMPAIGN_SK]. [대상 집합 = FACT_MEMBER_MONTHLY 회원×월 스파인 — 전 캠페인 합 = FMM 1~기준월 합(연도초는 1월 행)]. [원천: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN · FACT_MEMBER_EVENT]. [적재: dbt]';
ALTER TABLE GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP ADD CONSTRAINT FK_FCCS_DIM_CAMPAIGN
    FOREIGN KEY (CAMPAIGN_SK) REFERENCES GN_DW.GOLD.DIM_CAMPAIGN (CAMPAIGN_SK) NOT ENFORCED NORELY;

-- ⏸ 여기서 멈춘다 → 👤 dbt build --select FACT_CAMPAIGN_CUM_STOP → 05_24_SV_DDL_CAMPAIGN_CUM_STOP.sql 실행 후 아래를 돈다
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- [1] 🔴 핵심 대사 — 2026-09 기준 전 캠페인 합 = FMM 2026-01~09 합(연도초 = 1월 행). DIFF 3개가 모두 0 이어야 한다.
WITH f AS (
    SELECT SUM(CUM_STOP_CNT) AS stop_f, SUM(CUM_DEV_CNT) AS dev_f, SUM(YEAR_START_ACTIVE_CNT) AS ys_f
    FROM GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP WHERE BASE_MONTH_KEY = 202609
), m AS (
    SELECT SUM(CASE WHEN MONTH_KEY BETWEEN 202601 AND 202609 THEN STOP_AMT_CNT END) AS stop_m,
           SUM(CASE WHEN MONTH_KEY BETWEEN 202601 AND 202609 THEN DEV_CNT END)      AS dev_m,
           SUM(CASE WHEN MONTH_KEY = 202601 THEN YEAR_START_ACTIVE_CNT END)         AS ys_m
    FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY
)
SELECT stop_f, stop_m, stop_f - stop_m AS diff_stop,
       dev_f,  dev_m,  dev_f  - dev_m  AS diff_dev,
       ys_f,   ys_m,   ys_f   - ys_m   AS diff_ys,
       stop_f / NULLIF(dev_f + ys_f, 0) * 100 AS total_rate_pct   -- 기대 ≈ 13.78
FROM f, m;

-- [2] 캠페인 미귀속(SK=0) 비율 — FMM 「그 달 캠페인」 축 중단 미귀속 58.3% 대비 얼마나 줄었는가
SELECT SUM(IFF(CAMPAIGN_SK = 0, CUM_STOP_CNT, 0)) / NULLIF(SUM(CUM_STOP_CNT), 0) * 100          AS stop_unmapped_pct,
       SUM(IFF(CAMPAIGN_SK = 0, CUM_DEV_CNT, 0)) / NULLIF(SUM(CUM_DEV_CNT), 0) * 100            AS dev_unmapped_pct,
       SUM(IFF(CAMPAIGN_SK = 0, YEAR_START_ACTIVE_CNT, 0)) / NULLIF(SUM(YEAR_START_ACTIVE_CNT), 0) * 100 AS ys_unmapped_pct
FROM GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP WHERE BASE_MONTH_KEY = 202609;

-- [3] 캠페인 규칙 차이 실측 — 개발(FME 사건 캠페인) ≠ 후원사업 대표캠페인(FMSS) 인 2026-01~09 개발 비율
--     (후원사업 SPONSORSHIP_SK 로 잇는다 · 개발건이 그 후원사업 대표캠페인과 다른 캠페인에 귀속된 몫)
SELECT SUM(IFF(e.CAMPAIGN_SK <> s.CAMPAIGN_SK, e.DEV_CNT, 0)) / NULLIF(SUM(e.DEV_CNT), 0) * 100 AS dev_campaign_mismatch_pct,
       SUM(IFF(s.CAMPAIGN_SK IS NULL, e.DEV_CNT, 0)) / NULLIF(SUM(e.DEV_CNT), 0) * 100            AS dev_no_span_pct
FROM GN_DW.GOLD.FACT_MEMBER_EVENT e
LEFT JOIN (SELECT MEMBER_DK, SPONSORSHIP_SK, ANY_VALUE(CAMPAIGN_SK) AS CAMPAIGN_SK
             FROM GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN GROUP BY 1, 2) s
  ON s.MEMBER_DK = e.MEMBER_DK AND s.SPONSORSHIP_SK = e.SPONSORSHIP_SK
WHERE e.DATE_SK BETWEEN 20260101 AND 20260930 AND e.DEV_CNT <> 0;

-- [4] 음성 검증 — 여러 기준월을 SUM 하면 커진다(=「기준월 1개 고정」 규칙의 근거). sum_1_9 > only_09 이면 정상.
SELECT SUM(IFF(BASE_MONTH_KEY = 202609, CUM_STOP_CNT, 0))               AS only_09,
       SUM(IFF(BASE_MONTH_KEY BETWEEN 202601 AND 202609, CUM_STOP_CNT, 0)) AS sum_1_9
FROM GN_DW.GOLD.FACT_CAMPAIGN_CUM_STOP;

-- [5] SV 스모크 — 상위 10 캠페인 + 전체(ROLLUP)
SELECT * FROM SEMANTIC_VIEW(
    GN_DW.SERVING.SV_CAMPAIGN_CUM_STOP
    DIMENSIONS fccs.BASE_MONTH_KEY, campaign.CAMPAIGN_NAME
    METRICS fccs.CUM_STOP, fccs.CUM_DEV, fccs.YEAR_START_ACTIVE, fccs.CUM_STOP_RATE)
WHERE BASE_MONTH_KEY = 202609
ORDER BY CUM_STOP DESC
LIMIT 10;
