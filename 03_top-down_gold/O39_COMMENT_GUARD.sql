-- O39 무증상 오답 차단 — `*_MEMBERS` 컬럼이 「명」이 아니다 (COMMENT 전용 가드 · dbt build 불요)
-- Co-authored with CoCo
-- ============================================================================
-- 대상 : GN_DW.GOLD.FACT_MEMBER_EVENT(DEV_MEMBERS·STOP_MEMBERS) · FACT_SERVICE_EVENT(SEND_MEMBERS)
--        + 대응 WIDE 소비뷰 2종
-- 역할 : GN_DW_ADMIN
-- 근거 : 20_issue/10_진단_원인분석.md §23 (O39)
-- 측정일: 2026-08-05 (전 항목 GOLD·BRONZE 직접 실측 — 아래 §0)
-- 선례 : O28_O29_COMMENT_GUARD.sql — 동일 패턴(FACT=즉시·영구 / WIDE=즉시+모델 동시수정 · P33)
--
-- 🟢 무엇이 문제인가
--   컬럼명이 `*_MEMBERS` 라서 「명(회원수)」로 읽히는데, 실측하면 **행당 0/1 플래그**이고
--   `SUM` 은 **건수**를 준다. 같은 회원이 여러 사건을 만들면 그만큼 중복 계수된다.
--   이름·COMMENT 가 모두 「명」이라고 말하므로 에러도 경고도 없이 과대값이 나온다(P18·P19 유형).
--
-- 🔴 왜 「전수 스캔 후 일괄 교정」이 아니라 3개만인가 — 실측으로 갈랐다 (P70)
--   `%MEMBERS%` 컬럼 43종을 전수 시험한 결과 **패턴이 균일하지 않았다.** grain 이 다르면
--   같은 이름의 컬럼이 옳기도 하다. 이름만 보고 일괄 교정하면 **옳은 것을 틀리게 만든다.**
--     · ✅ `FACT_MEMBER_MONTHLY.DEV_MEMBERS` — **옳다.** 466개월 전부에서
--          `SUM(DEV_MEMBERS)` == `COUNT(DISTINCT MEMBER_DK)` (불일치 0개월 · 최대편차 0).
--          grain 이 월×회원이라 월 내 dedup 이 이미 반영돼 있다. **건드리지 않는다.**
--     · ✅ `FACT_MEMBER_COHORT.ACQ_MEMBERS`·`STOPPED_MEMBERS` — **옳다.** 1,585,949행 =
--          distinct 회원 1,585,949 → 1행=1회원이라 0/1 플래그의 SUM 이 곧 명수다.
--     · 🔴 아래 3종 — grain 이 회원보다 잘게 쪼개져 SUM 이 명수가 아니다. 교정 대상.
--
-- 🟢 왜 다음 빌드가 되돌리지 않는가 (선례 O28·O29 와 동일 · 검증 완료)
--   FACT 2종은 `dbt_project.yml` gold.fact = incremental + append + pre-hook TRUNCATE 이고
--   **컬럼 COMMENT 를 세팅하는 post_hook 이 없다**(모델 파일 실측 확인). TRUNCATE 는 COMMENT 를
--   지우지 않는다. 반면 **WIDE 는 뷰이고 post_hook 이 COMMENT 소유주**이므로 물리만 고치면
--   다음 build 가 되돌린다 → §3 의 모델 파일 수정이 **필수 동반**이다(P33).
--   재구축 대비 정본 = `03_top-down_gold/06_DDL.sql` 도 함께 고쳤다(488·490·575행).


-- ============================================================================
-- §0. 측정 근거 (2026-08-05 실측 · 실행 불요 · 재현용)
-- ============================================================================
/*
-- (1) FME — DEV_MEMBERS·STOP_MEMBERS 가 DEV_CNT·STOP_CNT 와 전 행 동일한 0/1 플래그
SELECT COUNT_IF(DEV_CNT <> DEV_MEMBERS)   AS DEV_DIFFER      -- 실측 0
     , COUNT_IF(STOP_CNT <> STOP_MEMBERS) AS STOP_DIFFER     -- 실측 0
     , MAX(DEV_MEMBERS) AS MAX_DEV_M, MAX(STOP_MEMBERS) AS MAX_STOP_M   -- 실측 1, 1
     , SUM(DEV_MEMBERS)  AS SUM_DEV_M                        -- 실측 2,291,878
     , COUNT(DISTINCT CASE WHEN DEV_CNT  > 0 THEN MEMBER_DK END) AS TRUE_DEV_M   -- 1,585,923 (44.5% 과대)
     , SUM(STOP_MEMBERS) AS SUM_STOP_M                       -- 실측 1,038,262
     , COUNT(DISTINCT CASE WHEN STOP_CNT > 0 THEN MEMBER_DK END) AS TRUE_STOP_M  --   903,064 (15.0% 과대)
FROM GN_DW.GOLD.FACT_MEMBER_EVENT;

-- (2) FME grain — 같은 회원이 같은 날 2건 이상 개발한 행이 존재(= dedup 안 돼 있다는 직접 증거)
SELECT COUNT(*) AS DEV_ROWS                                              -- 2,291,878
     , COUNT(DISTINCT MEMBER_DK || '|' || DATE_SK) AS DISTINCT_MEMBER_DAY -- 2,072,930
     , COUNT(*) - COUNT(DISTINCT MEMBER_DK || '|' || DATE_SK) AS EXTRA    --   218,948
FROM GN_DW.GOLD.FACT_MEMBER_EVENT WHERE DEV_CNT > 0;

-- (3) FSE — SEND_MEMBERS 는 전 행 1 → SUM = 행수. 최악(37.3배)
SELECT COUNT(*) AS ROWS_                     -- 38,470,780
     , SUM(SEND_MEMBERS) AS SUM_SEND_M       -- 38,470,780  (= 행수)
     , MAX(SEND_MEMBERS) AS MAX_SEND_M       -- 1
     , COUNT(DISTINCT MEMBER_DK) AS TRUE_M   --  1,031,971  (37.28배 과대)
FROM GN_DW.GOLD.FACT_SERVICE_EVENT;

-- (4) 교정 제외 확증 — FMM 은 466개월 전부 정확 일치
WITH m AS (SELECT MONTH_KEY, SUM(DEV_MEMBERS) sum_m,
                  COUNT(DISTINCT CASE WHEN DEV_CNT > 0 THEN MEMBER_DK END) true_m
           FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY GROUP BY 1)
SELECT COUNT(*) AS MONTHS_, COUNT_IF(sum_m <> true_m) AS MISMATCH, MAX(ABS(sum_m-true_m)) AS MAX_DIFF
FROM m;   -- 실측 466 / 0 / 0  → FMM 은 옳다

-- (5) 교정 제외 확증 — COHORT 는 1행=1회원
SELECT COUNT(*) AS ROWS_, COUNT(DISTINCT MEMBER_DK) AS MEMBERS_, SUM(ACQ_MEMBERS) AS SUM_ACQ
FROM GN_DW.GOLD.FACT_MEMBER_COHORT;   -- 실측 1,585,949 / 1,585,949 / 1,585,949  → 옳다
*/


USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;


-- ============================================================================
-- §1. FACT_MEMBER_EVENT — 개발(명)·중단(명) 경고 (즉시·영구)
-- ============================================================================

COMMENT ON COLUMN GN_DW.GOLD.FACT_MEMBER_EVENT.DEV_MEMBERS IS
'🔴 **「명」이 아니다 — 개발 사건 플래그(0/1)** 다. 이름과 종전 COMMENT 가 모두 "개발(명)"이라고 말했으나 실측(2026-08-05 · O39)은 다르다: 이 컬럼은 전 행에서 `DEV_CNT` 와 **완전히 동일**하며(불일치 0행 · 값 0/1), `SUM` 하면 **개발(건)** 이 나온다.
[금지] `SUM(DEV_MEMBERS)` 를 개발(명)으로 쓰지 말 것 — 실측 2,291,878 이며 실제 고유회원 1,585,923 대비 **44.5% 과대**다. 같은 회원이 같은 날 2건 이상 약정한 행이 218,948건 있어 이 grain(1행=1사건)에는 회원 dedup 이 들어 있지 않다.
[정본] 개발(명)(#148) = `COUNT(DISTINCT MEMBER_DK)`. 월 단위 개발(명)이 필요하면 이미 dedup 된 `FACT_MEMBER_MONTHLY.DEV_MEMBERS`(월×회원 grain · 466개월 전부 정확 검증)를 쓴다.
[범위] 값 범위는 `DEV_CNT` 와 같다(정본 공#121 개발구분 = 신규1·증액2·재후원4 한정 · O24).';

COMMENT ON COLUMN GN_DW.GOLD.FACT_MEMBER_EVENT.STOP_MEMBERS IS
'🔴 **「명」이 아니다 — 중단 사건 플래그(0/1)** 다. 실측(2026-08-05 · O39) 전 행에서 `STOP_CNT` 와 **완전히 동일**(불일치 0행)하며 `SUM` 은 **중단(건)** 이다.
[금지] `SUM(STOP_MEMBERS)` 를 중단(명)으로 쓰지 말 것 — 실측 1,038,262 이며 실제 고유회원 903,064 대비 **15.0% 과대**다.
[정본] 중단(명) = `COUNT(DISTINCT MEMBER_DK)`.';


-- ============================================================================
-- §2. FACT_SERVICE_EVENT — 발송(명) 경고 (즉시·영구) · 🔴 과대율 최악
-- ============================================================================

COMMENT ON COLUMN GN_DW.GOLD.FACT_SERVICE_EVENT.SEND_MEMBERS IS
'🔴 **「명」이 아니다 — 발송 플래그(전 행 값 1)** 다. `SUM` 은 곧 **행수 = 발송 건수**다.
[금지] `SUM(SEND_MEMBERS)` 를 발송(명)으로 쓰지 말 것 — 실측 38,470,780 이며 실제 고유회원 1,031,971 대비 **37.3배 과대**다(본 프로젝트에서 확인된 `*_MEMBERS` 오표기 중 최악).
[정본] 발송(명)(#85) = `COUNT(DISTINCT MEMBER_DK)`. Agent 는 `SV_SERVICE.DISTINCT_SEND_MEMBERS` 를 쓴다 — 2026-08-05 에 synonym ''발송 회원수'' 를 `TOTAL_SEND_MEMBERS`(건수)에서 떼어 그쪽으로 옮겼다.
[참고] 발송 건수를 원하면 이 컬럼 SUM 이 맞다 — 다만 그때는 「건」이라고 쓸 것.';


-- ============================================================================
-- §3. 🔴 WIDE 소비뷰 — 즉시 반영 + **모델 post_hook 동시 수정 필수** (P33)
--   아래 ALTER 는 지금 즉시 반영되지만, WIDE 는 뷰이고 post_hook 이 COMMENT 소유주이므로
--   다음 dbt build 가 되돌린다. 같은 문구를 아래 두 모델 파일에 이미 반영했다:
--     · 10_dbt_pipeline/models/gold/wide/WIDE_MEMBER_EVENT.sql  (DEV_MEMBERS·STOP_MEMBERS)
--     · 10_dbt_pipeline/models/gold/wide/WIDE_SERVICE_EVENT.sql (SEND_MEMBERS)
-- ============================================================================

ALTER VIEW GN_DW.GOLD.WIDE_MEMBER_EVENT ALTER
    COLUMN DEV_MEMBERS COMMENT '🔴「명」이 아니다 — 개발 사건 플래그(0/1). SUM 은 개발(건)이며 실측 2,291,878 로 실제 고유회원 1,585,923 대비 44.5% 과대다(O39). 개발(명)(#148)은 COUNT(DISTINCT MEMBER_DK). 월 단위는 FACT_MEMBER_MONTHLY.DEV_MEMBERS 사용.',
    COLUMN STOP_MEMBERS COMMENT '🔴「명」이 아니다 — 중단 사건 플래그(0/1). SUM 은 중단(건)이며 실측 1,038,262 로 실제 고유회원 903,064 대비 15.0% 과대다(O39). 중단(명)은 COUNT(DISTINCT MEMBER_DK).';

ALTER VIEW GN_DW.GOLD.WIDE_SERVICE_EVENT ALTER
    COLUMN SEND_MEMBERS COMMENT '🔴「명」이 아니다 — 발송 플래그(전 행 1). SUM 은 행수=발송 건수이며 실측 38,470,780 로 실제 고유회원 1,031,971 대비 37.3배 과대다(O39). 발송(명)(#85)은 COUNT(DISTINCT MEMBER_DK).';


-- ============================================================================
-- §4. 검증 — 반영 확인 (P33: 완료 판정은 문서가 아니라 INFORMATION_SCHEMA 스캔)
-- ============================================================================

-- 4-A. 교정 대상 3+3 건에 경고가 실렸는가 (기대: 6행 · ALL TRUE)
SELECT TABLE_NAME, COLUMN_NAME,
       COMMENT LIKE '%「명」이 아니다%' AS HAS_WARNING,
       LEFT(COMMENT, 60) AS HEAD
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'GOLD'
  AND ( (TABLE_NAME = 'FACT_MEMBER_EVENT'   AND COLUMN_NAME IN ('DEV_MEMBERS','STOP_MEMBERS'))
     OR (TABLE_NAME = 'WIDE_MEMBER_EVENT'   AND COLUMN_NAME IN ('DEV_MEMBERS','STOP_MEMBERS'))
     OR (TABLE_NAME = 'FACT_SERVICE_EVENT'  AND COLUMN_NAME = 'SEND_MEMBERS')
     OR (TABLE_NAME = 'WIDE_SERVICE_EVENT'  AND COLUMN_NAME = 'SEND_MEMBERS') )
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 4-B. 🔴 교정 제외 대상이 훼손되지 않았는가 (기대: FMM·COHORT 는 경고 없음 = FALSE)
SELECT TABLE_NAME, COLUMN_NAME, COMMENT LIKE '%「명」이 아니다%' AS MUST_BE_FALSE, COMMENT
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'GOLD'
  AND ( (TABLE_NAME = 'FACT_MEMBER_MONTHLY' AND COLUMN_NAME = 'DEV_MEMBERS')
     OR (TABLE_NAME = 'FACT_MEMBER_COHORT'  AND COLUMN_NAME IN ('ACQ_MEMBERS','STOPPED_MEMBERS')) )
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 4-C. 값은 변하지 않았는가 (COMMENT 전용 작업이므로 불변이어야 한다)
SELECT SUM(DEV_MEMBERS) AS SUM_DEV_M, SUM(STOP_MEMBERS) AS SUM_STOP_M
FROM GN_DW.GOLD.FACT_MEMBER_EVENT;   -- 기대 2,291,878 / 1,038,262


-- ============================================================================
-- §5. 잔여 — 본 스크립트 범위 밖 (별건 이슈 · 결정 필요)
-- ============================================================================
-- 🔴 O39-B **전건 0 컬럼군** — 위 전수 스캔 중 함께 드러났다. 값이 0 이라 무증상이며,
--    "실제 0" 으로 오독될 수 있어 별건으로 등재했다. COMMENT 경고 대상 후보:
--      · FACT_MEMBER_MONTHLY : ACTIVE_CNT · ACTIVE_MEMBERS · INCREASE_CNT · INCREASE_MEMBERS ·
--                              ACTIVE_CUM_CNT · ACTIVE_CUM_MEMBERS  (6종 · 40,054,883행 전건 0)
--        ⚠️ `ACTIVE_CNT` 는 활동회원 계열 지표의 **분모**로 쓰이는 축이라 영향 범위 확인이 선결이다.
--      · FACT_MEMBER_EVENT   : UNPAID_STOP_CNT · UNPAID_STOP_MEMBERS (전건 0)
--      · FACT_SERVICE_EVENT  : SUCCESS_MEMBERS · FAIL_MEMBERS · OPEN_MEMBERS ·
--                              LETTER_PART_* · GIFT_PART_MEMBERS · D5_* · SERVICE_CNT/MEMBERS
--        (일부는 기존 C-9-R·B1 로 기재됨 — 중복 등재 말고 대조 후 병합할 것)
-- 🟠 O39-C **개명 여부** — 본 가드는 COMMENT 만 고친다. §22-H(`HAS_GOAL`→`HAS_POSITIVE_GOAL`)의
--    교훈은 "이름이 오해를 부르면 개명한다"였다. `*_MEMBERS` → `*_FLAG` 개명은 하류(WIDE·SV·
--    문서·저장쿼리)를 깨므로 영향 범위를 먼저 조사한 뒤 사용자 결정으로 진행한다.

-- Co-authored with CoCo
