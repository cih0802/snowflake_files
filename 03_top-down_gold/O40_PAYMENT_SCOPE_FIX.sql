-- O40 납부율·미납금액 모집단 불일치 교정 — 실행 순서 스크립트
-- Co-authored with CoCo
-- ============================================================================
-- 근거 : 20_issue/10_진단_원인분석.md §24 (O40)
-- 역할 : GN_DW_ADMIN
-- 측정일: 2026-08-05 (GOLD·SILVER·BRONZE 3계층 직접 실측)
--
-- 🔴 무엇이 틀렸나 (단일 원인)
--   `FACT_MEMBER_MONTHLY.PAID_FEE`(=SUM(PAY_AMT))는 **회비 ∪ 기부금** 이고
--   `BILLED_AMT`(=SUM(RQEST_AMT))는 **회비뿐**이다. 기부금 원천 `TM_PM_DNTN_DTLS` 에는
--   청구 컬럼이 **아예 없다**(SILVER 실측: PAYMENT_TYPE='기부금' 1,130,252행 전건 RQEST_AMT NULL).
--   → 나누면 분자에만 기부금이 더해진다 = **분자·분모 모집단 불일치**(P63).
--
-- 🔴 무증상이 아니라 이미 사고가 났다 — 전 기간 실측
--     SV_MEMBER_MONTHLY.PAYMENT_RATE     = **100.3608%**   (비율이 100% 초과)
--     SV_MEMBER_MONTHLY.TOTAL_UNPAID_AMT = **-3,218,518,220**  (미납금액이 음수)
--   2025 만 보면 93.98% / 123억으로 **그럴싸해서 더 위험했다**(Agent 가 실제로 이 값을 답했다).
--
--   | 지표 | 현행(결함) | 정본 | 오차 |
--   |---|---|---|---|
--   | 2025 납부율 | 93.98% | **85.65%** | +8.32%p 과대 |
--   | 2025 미납금액 | 12,335,580,090 | **29,251,314,636** | 2.37배 과소(169억 누락) |
--
-- 🟢 판별자는 `PAYMENT_TYPE` — 실측으로 정확하다(추론 아님)
--     PAYMENT_TYPE='회비'   46,391,620행 = MBRFEE_DIV_CD 비NULL 46,391,620행  ← **정확 일치**
--     PAYMENT_TYPE='기부금'  1,130,252행 = MBRFEE_DIV_CD 비NULL          0행
--   ⚠️ `ONETIME_ONETIME_FEE`(회원유형 ONCE) 차감 방식은 채택하지 않았다 — 축이 다르고
--      마스터부재 314행이 어디에도 안 들어가 40,000원 새어나간다(실측).
--
-- ============================================================================
-- 🔴 실행 순서 — 반드시 이 순서로. §2 는 사용자가 실행한다.
-- ============================================================================
--   §1  ALTER TABLE ADD COLUMN            (아래 · 즉시 실행 가능 · 가산적·무해)
--   §2  dbt build (FACT_MEMBER_MONTHLY)   ← 🔴 **사용자 실행 대기**
--   §3  적재 검증                          (아래 · build 후)
--   §4  SV metric 신설·교정                (05_1_SV_DDL_MEMBER_MONTHLY.sql · build 후)
--
-- ⚠️ §1 만 하고 §2 를 안 하면 두 컬럼이 **전건 NULL** 로 남는다. 그 상태를 "값이 없다"로
--    오독하지 않도록 컬럼 COMMENT 에 「적재 대기」를 함께 넣는다(아래 §1-B).
-- ⚠️ SV metric(§4)은 컬럼이 적재된 **뒤에** 올린다 — 먼저 올리면 컴파일은 되지만
--    전건 NULL 을 정답처럼 답한다(P18). 그래서 이번 세션에서는 §4 를 올리지 않고
--    기존 metric 에 **경고만** 실었다(배포 완료).


USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- ============================================================================
-- §1. 컬럼 추가 (가산적 · 기존 값·행수 영향 0)
-- ============================================================================
ALTER TABLE GN_DW.GOLD.FACT_MEMBER_MONTHLY
    ADD COLUMN IF NOT EXISTS PAID_FEE_BILLABLE  NUMBER(18,2),
                             UNPAID_BILLED_AMT  NUMBER(18,2);

-- §1-B. COMMENT — 「적재 대기」 명시(build 전 전건 NULL 오독 방지)
COMMENT ON COLUMN GN_DW.GOLD.FACT_MEMBER_MONTHLY.PAID_FEE_BILLABLE IS
'회비만 납입액(원) — 납부율 분자 **정본**(O40). `PAYMENT_TYPE=''회비''` 행의 PAY_AMT 합.
🔴`PAID_FEE` 와 다르다: 그쪽은 회비+기부금 총수납액이고, 기부금은 원천에 청구 컬럼이 없어 분모에 들어갈 수 없다.
[정본 산식] 납부율 = PAID_FEE_BILLABLE / BILLED_AMT × 100. 2025 기준 85.65%.
⚠️**적재 대기**: dbt build 전이면 전건 NULL 이다 — "값 없음"으로 읽지 말 것.';

COMMENT ON COLUMN GN_DW.GOLD.FACT_MEMBER_MONTHLY.UNPAID_BILLED_AMT IS
'미납 청구액(원) — 정본 **DEC-3** 정의(O40): `PAY_STAT_CD IN (''F'', NULL)` 인 행의 **RQEST_AMT** 합.
🔴차감식(BILLED−PAID)을 쓰지 말 것 — 기부금이 미납을 상쇄해 **2.37배 과소**해진다(2025: 123억 vs 정본 293억).
⚠️분자는 청구액이다(PAY_AMT 아님) — 미납은 "청구했으나 들어오지 않은 금액"이다.
⚠️**적재 대기**: dbt build 전이면 전건 NULL 이다.';

-- §1-C. HAS_BILLING 오표기 교정 (build 불요 · 즉시)
COMMENT ON COLUMN GN_DW.GOLD.FACT_MEMBER_MONTHLY.HAS_BILLING IS
'결제(billing) 행 존재 여부 — TRUE=결제 스파인(구 37.79M) · FALSE=개발/중단 전용 월(회비 measure NULL).
🔴**「회비만」 스코프가 아니다**(O40). 기저 CTE 가 회비(TM_PM_MBRFEE_ACMSLT)와 **기부금(TM_PM_DNTN_DTLS)을
함께** 담으므로 TRUE 인 행에도 기부금이 섞이고, 청구가 없는 기부금 전용 월도 TRUE 다
(2025 실측: HAS_BILLING=TRUE 8,514,780행 중 청구 0/NULL 행 **28,521건**).
→ 이 필터를 걸어도 **납부율 분자는 정화되지 않는다.** 회비 기준이 필요하면 `PAID_FEE_BILLABLE` 을 쓴다.
「HAS_BILLING=TRUE 로 걸었으니 회비 기준」이라는 서술은 **틀렸다**.';


-- ============================================================================
-- §2. 🔴 dbt build — **사용자 실행 대기** (작업조건 5)
-- ============================================================================
/*
build --select FACT_MEMBER_MONTHLY --target dev

기대: ERROR=0. ⚠️gold.fact = incremental + append + pre-hook TRUNCATE 이므로 전량 재적재된다
     (40,054,883행). 신규 2컬럼만 채워지고 기존 measure 는 값이 바뀌지 않아야 한다 → §3 로 확인.
*/


-- ============================================================================
-- §3. 적재 검증 (build 후 · 기대값은 저작 전 시뮬레이션으로 산출한 실측치)
-- ============================================================================

-- 3-A. 기존 값 불변 + 신규 2컬럼 적재 (2025)
SELECT SUM(BILLED_AMT)        AS BILLED,             -- 기대 204,757,262,930 (불변)
       SUM(PAID_FEE)          AS PAID_ALL,           -- 기대 192,421,682,840 (불변)
       SUM(PAID_FEE_BILLABLE) AS PAID_FEE_ONLY,      -- 기대 175,381,890,496 (신규)
       SUM(UNPAID_BILLED_AMT) AS UNPAID_DEC3,        -- 기대  29,251,314,636 (신규)
       ROUND(SUM(PAID_FEE_BILLABLE) / NULLIF(SUM(BILLED_AMT),0) * 100, 2) AS TRUE_RATE,   -- 기대 85.65
       ROUND(SUM(UNPAID_BILLED_AMT) / NULLIF(SUM(BILLED_AMT),0) * 100, 2) AS TRUE_UNPAID_RATIO -- 기대 14.29
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY
WHERE MONTH_KEY BETWEEN 202501 AND 202512;

-- 3-B. 🔴 상한 불변식 — 교정 납부율이 100% 를 넘는 연도가 0 이어야 한다 (P73·P77)
--      ⚠️ grain 은 **연도 집계**다(P77: 상한 검사는 grain 을 명시한다).
SELECT FLOOR(MONTH_KEY/100) AS CAL_YEAR,
       ROUND(SUM(PAID_FEE_BILLABLE)/NULLIF(SUM(BILLED_AMT),0)*100, 2) AS RATE
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY
GROUP BY 1 HAVING SUM(BILLED_AMT) > 0 AND SUM(PAID_FEE_BILLABLE) > SUM(BILLED_AMT)
ORDER BY 2 DESC;   -- 기대 0행

-- 3-C. 🔴 미납금액이 음수인 구간이 없어야 한다 (차감식 폐기의 핵심 효과)
SELECT COUNT_IF(UNPAID_BILLED_AMT < 0) AS MUST_BE_0
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;   -- 기대 0

-- 3-D. 정합성 — 미납청구액 ≤ 청구액 (연도 집계)
SELECT FLOOR(MONTH_KEY/100) AS CAL_YEAR
FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY
GROUP BY 1 HAVING SUM(UNPAID_BILLED_AMT) > SUM(BILLED_AMT);   -- 기대 0행

-- 3-E. BRONZE 독립 대조 (DEC-3 정의를 원천에서 직접 재계산 · 2025)
SELECT SUM(RQEST_AMT) AS BRONZE_UNPAID_2025   -- 기대 29,251,314,636 = 3-A 의 UNPAID_DEC3
FROM GN_DW.BRONZE_CRM.TM_PM_MBRFEE_ACMSLT
WHERE MBRFEE_MT BETWEEN '202501' AND '202512'
  AND (PAY_STAT_CD = 'F' OR PAY_STAT_CD IS NULL);


-- ============================================================================
-- §4. SV metric 신설·교정 (build 후 · 05_1_SV_DDL_MEMBER_MONTHLY.sql 에 반영)
-- ============================================================================
/*
신설:
  fmm.TOTAL_PAID_FEE_BILLABLE AS SUM(fmm.PAID_FEE_BILLABLE)
    SYNONYMS ('납입회비','회비 납입액','납입회비 총액')
  fmm.PAYMENT_RATE_FEE  AS SUM(fmm.PAID_FEE_BILLABLE) / NULLIF(SUM(fmm.BILLED_AMT),0) * 100
    SYNONYMS ('납부율','수납율','회비 납부율')          ← 🔴'납부율' synonym 을 이쪽으로 **이전**(P79)
  fmm.TOTAL_UNPAID_AMT_DEC3 AS SUM(fmm.UNPAID_BILLED_AMT)
    SYNONYMS ('총미납금액','미납액','미납금액')          ← 🔴synonym 이전(P79)
  fmm.UNPAID_RATIO_DEC3 AS SUM(fmm.UNPAID_BILLED_AMT) / NULLIF(SUM(fmm.BILLED_AMT),0) * 100
    SYNONYMS ('미납비중','미납율')                      ← 🔴synonym 이전(P79)

기존(결함) metric 처리 — **삭제하지 않는다**(저장 쿼리·문서 참조가 있을 수 있다):
  PAYMENT_RATE / TOTAL_UNPAID_AMT / UNPAID_RATIO / TOTAL_PAID_FEE
  → 이번 세션에 이미 COMMENT 경고 + synonym 회수를 배포했다. build 후에는 위 신설 metric 이
    자연어를 받아가므로 결함 metric 은 「총액 기준」 보조 지표로만 남는다.

⚠️ AI_SQL_GENERATION 의 "적재 대기" 문구는 build 후 **반드시 제거**할 것 — 안 지우면 Agent 가
   정상 지표를 두고 "대기 중"이라고 답한다(사문화 주석 = O28·O29 에서 겪은 유형).
*/

-- Co-authored with CoCo
