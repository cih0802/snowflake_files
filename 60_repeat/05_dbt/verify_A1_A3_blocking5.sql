-- A1/A3 BLOCKING-5 부분해소 검증쿼리 — dbt build 후 실행(읽기전용)
-- Co-authored with CoCo
-- ============================================================================
-- 대상: FACT_MEMBER_MONTHLY(A1)·FACT_SERVICE_EVENT(A3)
-- 실행 시점: EXECUTE DBT PROJECT ... ARGS='build --select FACT_MEMBER_MONTHLY FACT_SERVICE_EVENT' 후
-- 기대치(build 전 시뮬 실측, 2026-07-21):
--   FMM: 40,054,883행 = distinct grain · HAS_BILLING=TRUE 37,792,336 · EVENT_ONLY 2,262,547 · DEV 2.97M/STOP 0.97M
--   FSE: SERVICE_SK 커버 99.97%(38,459,467) · DIM_SERVICE 미매칭 0건
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- [A1-1] FMM 행수·grain 유일성·HAS_BILLING 분포 (fan-out 0 확인)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    COUNT(*)                                          AS TOTAL_ROWS,          -- 기대 ~40,054,883
    COUNT(DISTINCT MONTH_KEY || '|' || MEMBER_DK)     AS DISTINCT_GRAIN,      -- = TOTAL_ROWS (유일)
    COUNT_IF(HAS_BILLING)                             AS HAS_BILLING_TRUE,    -- 기대 37,792,336 (구 스파인)
    COUNT_IF(NOT HAS_BILLING)                         AS EVENT_ONLY_ROWS,     -- 기대 ~2,262,547
    COUNT_IF(HAS_BILLING IS NULL)                     AS HAS_BILLING_NULL     -- 기대 0 (NOT NULL 제약)
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;

-- ─────────────────────────────────────────────────────────────────────────────
-- [A1-2] FMM DEV/STOP 실채움 확인 (구 전건 0 → nonzero)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    COUNT_IF(DEV_CNT  > 0)                            AS DEV_CNT_NONZERO,     -- 기대 ~2,970,417
    COUNT_IF(STOP_CNT > 0)                            AS STOP_CNT_NONZERO,    -- 기대 ~972,376
    SUM(DEV_CNT)                                      AS DEV_CNT_SUM,
    SUM(STOP_CNT)                                     AS STOP_CNT_SUM,
    SUM(DEV_MEMBERS)                                  AS DEV_MEMBERS_SUM     -- FMM 설계상 STOP_MEMBERS 컬럼 없음(DEV_MEMBERS만 존재)
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;

-- ─────────────────────────────────────────────────────────────────────────────
-- [A1-3] 보수 뷰 불변 검증 — HAS_BILLING=TRUE 부분집합이 구 billing 집계와 일치하는가
--   FME rollup 소스(GOLD.FACT_MEMBER_EVENT)와 교차: DEV/STOP 합이 FME 총합과 일치해야 함(누락 0)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    (SELECT SUM(DEV_CNT)  FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY) AS FMM_DEV_SUM,
    (SELECT SUM(DEV_CNT)  FROM GN_DW.GOLD.FACT_MEMBER_EVENT)   AS FME_DEV_SUM,   -- = FMM_DEV_SUM (롤업 무손실)
    (SELECT SUM(STOP_CNT) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY) AS FMM_STOP_SUM,
    (SELECT SUM(STOP_CNT) FROM GN_DW.GOLD.FACT_MEMBER_EVENT)   AS FME_STOP_SUM;  -- = FMM_STOP_SUM

-- ─────────────────────────────────────────────────────────────────────────────
-- [A1-4] 회비 measure 무영향 확인 — HAS_BILLING=TRUE 행에만 PAID_FEE/BILLED_AMT 존재
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    COUNT_IF(HAS_BILLING AND PAID_FEE IS NOT NULL)    AS BILL_ROWS_WITH_FEE,
    COUNT_IF(NOT HAS_BILLING AND PAID_FEE IS NOT NULL) AS EVENT_ONLY_WITH_FEE,  -- 기대 0 (event-only 는 회비 NULL)
    SUM(PAID_FEE)                                     AS PAID_FEE_TOTAL,        -- A1 전후 불변이어야 함
    SUM(BILLED_AMT)                                   AS BILLED_AMT_TOTAL
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;

-- ─────────────────────────────────────────────────────────────────────────────
-- [A3-1] FSE SERVICE_SK 커버리지 + DIM_SERVICE 참조무결성
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    COUNT(*)                                          AS TOTAL_ROWS,          -- 기대 38,470,780
    COUNT_IF(SERVICE_SK <> 0)                         AS SK_MAPPED,           -- 기대 ~38,459,467
    ROUND(100.0 * COUNT_IF(SERVICE_SK<>0) / COUNT(*), 2) AS PCT_MAPPED,       -- 기대 99.97
    COUNT_IF(SERVICE_SK <> 0
             AND SERVICE_SK NOT IN (SELECT SERVICE_SK FROM GN_DW.GOLD.DIM_SERVICE)) AS SK_ORPHAN,  -- 기대 0
    COUNT_IF(SEND_TITLE IS NOT NULL)                  AS TITLE_FILLED         -- A3: 제목 실채움(구 전건 NULL)
FROM GN_DW.GOLD.FACT_SERVICE_EVENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- [A3-2] SERVICE_SK 조인 스모크 — 채널×타입별 발송 분포(상위 10)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    d.CHANNEL,
    d.SUBTYPE,
    COUNT(*)          AS SEND_ROWS,
    SUM(f.SEND_MEMBERS) AS SEND_MEMBERS
FROM GN_DW.GOLD.FACT_SERVICE_EVENT f
JOIN GN_DW.GOLD.DIM_SERVICE d ON f.SERVICE_SK = d.SERVICE_SK
GROUP BY d.CHANNEL, d.SUBTYPE
ORDER BY SEND_ROWS DESC
LIMIT 10;
