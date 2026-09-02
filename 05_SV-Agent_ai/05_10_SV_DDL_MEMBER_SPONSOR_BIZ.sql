-- GN_DW 3단계: Semantic View DDL 정본 — SV_MEMBER_SPONSOR_BIZ (회원×후원약정, 캠페인/후원사업별 활동회원)
-- Co-authored with CoCo
-- ============================================================================
-- ▶ 이 파일의 위상 [2026-08-21 신설]
--   대상 SV = **SV_MEMBER_SPONSOR_BIZ** — 이 파일 하나로 독립 실행된다.
--   파일 규약·선행 조건의 정본 = `05_0_SV_DDL.sql` §공통 규약(CREATE OR ALTER·독립 실행·
--   실행 역할 GN_DW_ADMIN·선행 조건 dbt build 하나) — 이 파일에 다시 복제하지 않는다.
--
-- ▶ 무엇을 답하는 SV 인가
--   **"캠페인별/후원사업별 활동회원"** 질문. base = `GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ`
--   (grain = MEMBER_DK × SPNSR_BSNS_NO, 2,170,572행 실측 2026-08-21).
--
--   🔴 **`SV_MEMBER_MONTHLY` 가 이 질문에 답할 수 없는 이유**: `FACT_MEMBER_MONTHLY.CAMPAIGN_SK` 는
--      회원grain 다중캠페인(19.0%·최대690, O8 미결)이라 전건 센티넬(0)이다. 그런데 이 SV 의 base
--      (약정 grain)에서는 캠페인이 거의 1:1(다중 137건=0.01%·최대2, 실측)이라 O8 이 이 grain 에서는
--      사실상 무해하다 — 그래서 대표캠페인 결정적 규칙 1개로 CAMPAIGN_SK 를 100% 배선했다.
--
-- ▶ 활동 판정 — 이 SV 는 "지금 시점" 과 "특정 월 as-of" 를 구분해서 제공한다
--   (1) **지금 시점**: `IS_CURRENTLY_ACTIVE`(DSCNTC_MONTH_KEY IS NULL) 기반 metric 을 바로 쓴다.
--   (2) **특정 월(예: 202606) as-of**: 이 SV 에 사전 정의된 metric 이 없다 — 원시 축
--       `START_MONTH_KEY`·`DSCNTC_MONTH_KEY` 를 노출해 WHERE 절로 직접 구성한다
--       (`START_MONTH_KEY <= :월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > :월)`).
--       이 판정식은 `FACT_MEMBER_MONTHLY`#51(월말활동회원)과 동일 철학이며, 재후원 시 새
--       SPNSR_BSNS_NO 가 발급되므로 tie-break 가 불필요하다(CRM_MEMBER_SPONSOR_SPAN 코멘트 근거).
--
-- ▶ 🔴🔴 이중계상 경고 — 전체 활동회원수와 이 SV 의 캠페인·후원사업별 합계는 다르다
--   한 회원이 캠페인 A 약정과 캠페인 B 약정을 동시에 활동 중일 수 있다 — 그 경우 두 캠페인
--   각각에 그 회원이 잡힌다(`IS_MULTI_SPONSORSHIP` 과 동일 성격의 정상 현상). ⇒ **캠페인·후원사업별
--   합계 ≠ 전체 활동회원수**(FACT_MEMBER_MONTHLY.ACTIVE_MEMBERS 총계). 이 SV 는 "캠페인/후원사업
--   시각"의 정본이고, "전체 활동회원 수"는 여전히 `SV_MEMBER_MONTHLY` 가 정본이다 — 둘을 같은 표에서
--   합산하거나 대체하지 않는다.
--
-- ▶ 설계 판단
--   (1) 단일 팩트 + DIM 2개 조인(SPONSORSHIP·CAMPAIGN) — 둘 다 대리키 1:1 조인이라 fan-out 0.
--   (2) `SPNSR_BSNS_NO` 자체는 노출하되 "유일키 아님"을 COMMENT 에 명시(28건 공동후원 쌍 실측).
--   (3) "명" 계열 metric 은 전부 COUNT(DISTINCT MEMBER_DK) — 이 팩트는 회원당 여러 행(다중약정)이라
--       행 수를 "명"으로 쓰면 과대해진다(*_MEMBERS 계열 함정, O39 유형).
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

/* =====================================================================================
   10. SV_MEMBER_SPONSOR_BIZ (member/marketing Agent) — base FACT_MEMBER_SPONSOR_BIZ
       grain = 회원 × 후원약정(SPNSR_BSNS_NO)
   ===================================================================================== */
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
  TABLES (
    fmsb AS GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ
      WITH SYNONYMS ('회원 후원약정', '캠페인별 활동회원', '후원사업별 활동회원')
      COMMENT = '회원×후원약정 팩트. grain = MEMBER_DK × SPNSR_BSNS_NO. "캠페인별/후원사업별 활동회원" 질의 전용 — 전체 활동회원수 정본은 SV_MEMBER_MONTHLY다. [원천] 시스템=CRM(eCRM) · BRONZE=GN_DW.BRONZE_CRM · SILVER=CRM_MEMBER_SPONSOR_SPAN(활동구간)+CRM_MEMBER_DEV(캠페인귀속) · GOLD=FACT_MEMBER_SPONSOR_BIZ.',
    sponsorship AS GN_DW.GOLD.DIM_SPONSORSHIP
      PRIMARY KEY (SPONSORSHIP_SK)
      WITH SYNONYMS ('후원사업 차원')
      COMMENT = '후원사업 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.',
    campaign AS GN_DW.GOLD.DIM_CAMPAIGN
      PRIMARY KEY (CAMPAIGN_SK)
      WITH SYNONYMS ('캠페인 차원')
      COMMENT = '캠페인 마스터. PK 유일이라 조인이 행수를 늘리지 않는다.'
  )
  RELATIONSHIPS (
    fmsb_to_sponsorship AS fmsb (SPONSORSHIP_SK) REFERENCES sponsorship,
    fmsb_to_campaign    AS fmsb (CAMPAIGN_SK)    REFERENCES campaign
  )
  -- 🔴 [2026-08-21 실배포 교정] 조인된 DIM 컬럼은 반드시 그 DIM 자신의 별칭으로 노출한다
  --   (`sponsorship.X AS sponsorship.Y`, `fmsb.X AS 조인테이블.Y` 아님) — 최초 시도(`fmsb.X AS dsp.Y`)는
  --   `invalid identifier` 로 컴파일 실패했다(05_2 MEMBER_EVENT 패턴과 대조해 원인 확인).
  DIMENSIONS (
    -- ── 회원·약정 식별(degen) ──────────────────────────────────────────────────
    fmsb.MEMBER_DK        AS fmsb.MEMBER_DK    WITH SYNONYMS ('회원번호') COMMENT = '회원 (불변키)',
    fmsb.SPNSR_BSNS_NO    AS fmsb.SPNSR_BSNS_NO WITH SYNONYMS ('후원사업번호', '약정번호') COMMENT = '회원별 후원약정 일련번호. 🔴단독 유일키 아니다 — 공동후원 쌍(부부 등)이 2개 회원에 공유되는 사례가 실재한다. 분류축이 아니다(분류는 SPONSORSHIP 축)',
    -- ── 후원사업(분류) ────────────────────────────────────────────────────────
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명', '사업') COMMENT = '후원사업명(마스터). 미매핑 없음(전건 매칭 실측 확인)',
    sponsorship.SPONSORSHIP_DIV AS sponsorship.SPONSORSHIP_DIV_NAME WITH SYNONYMS ('정기일시구분') COMMENT = '정기후원/일시후원 구분(CM035)',
    sponsorship.SPONSORSHIP_ABBR_CATEGORY AS sponsorship.SPONSORSHIP_GROUP_NAME WITH SYNONYMS ('후원사업 약칭', '후원사업 카테고리') COMMENT = '후원사업 약칭 그룹(CM003, 6종: 국내/결연/해외구호/북한/기타/해외)',
    -- ── 캠페인(대표) ──────────────────────────────────────────────────────────
    campaign.CAMPAIGN     AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인', '캠페인명') COMMENT = '대표캠페인명. 판정 규칙 = CRM_MEMBER_DEV 사건 중 ①신규사건이 있으면 그 신규사건 ②없으면 최초사건(동률 0 확인). 사건 자체가 없는 약정은 "(미매핑)"(0). ⚠️단일 회원-grain 캠페인 분해(FACT_MEMBER_MONTHLY 기준)와는 다른 축이다 — 이 SV 는 약정grain 이라 값이 다르게 나올 수 있다',
    -- [DEC-43] `DIM_CAMPAIGN` 실시간 조인(campaign.CAMPAIGN_TYPE) → `FACT_MEMBER_SPONSOR_BIZ.ACQ_*`
    --   동결값으로 전환. 대표사건의 캠페인 마스터가 이후 정정돼도 이 약정의 카테고리는 바뀌지 않는다.
    fmsb.CAMPAIGN_TYPE AS fmsb.ACQ_CMPGN_CTGR_NM WITH SYNONYMS ('캠페인 카테고리', '주요캠페인') COMMENT = '대표캠페인 카테고리 라벨(MM294). 🔴적재 시점 동결값(구 campaign.CAMPAIGN_TYPE 대체)',
    fmsb.IS_MULTI_CAMPAIGN AS fmsb.IS_MULTI_CAMPAIGN WITH SYNONYMS ('다중캠페인 여부') COMMENT = '참고용 투명성 플래그 — 이 SPNSR_BSNS_NO 의 전체 사건에서 캠페인이 2개 이상이었는지. 대표캠페인 채택 규칙과는 별개. 🟢실측상 극소수이며 최대 2개다(규모는 이슈원장·04 §0.9 참조)',
    -- ── 활동 구간(원시 as-of 축) ─────────────────────────────────────────────
    fmsb.START_MONTH_KEY  AS fmsb.START_MONTH_KEY WITH SYNONYMS ('활동개시월') COMMENT = '활동 개시 월키 YYYYMM. 특정월 as-of 활동 판정 시 이 축과 DSCNTC_MONTH_KEY 를 함께 WHERE 절로 비교한다(AI_SQL_GENERATION 참조)',
    fmsb.DSCNTC_MONTH_KEY AS fmsb.DSCNTC_MONTH_KEY WITH SYNONYMS ('중단월') COMMENT = '중단 월키 YYYYMM. 🔴NULL=미중단(현재까지 활동)이며 결측이 아니다'
  )
  METRICS (
    -- ── 규모(명) — 전부 DISTINCT, 회원당 다건이라 행수로 세면 과대 ────────────
    fmsb.CURRENTLY_ACTIVE_MEMBERS AS COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL))
      WITH SYNONYMS ('지금 활동회원수', '현재 활동회원')
      COMMENT = '**지금 시점** 활동회원수(명) = 미중단 약정을 보유한 고유회원. N(비가산). 🔴전체 활동회원수 정본은 SV_MEMBER_MONTHLY.ACTIVE_MEMBERS 다 — 이 metric 을 캠페인·후원사업으로 GROUP BY 하면 한 회원이 여러 축에 중복 집계될 수 있어 **합계가 전체보다 클 수 있다**(다중 후원 정상 현상). 특정 과거월 as-of 는 이 metric 이 아니라 START_MONTH_KEY·DSCNTC_MONTH_KEY 원시축으로 직접 WHERE 를 구성한다.',
    fmsb.TOTAL_REGISTRATIONS AS COUNT(*)
      WITH SYNONYMS ('약정건수', '등록건수')
      COMMENT = '약정(SPNSR_BSNS_NO) 행수. F(가산). 🔴"명"이 아니다 — 회원당 여러 약정을 가질 수 있다',
    fmsb.DISTINCT_MEMBERS AS COUNT(DISTINCT fmsb.MEMBER_DK)
      WITH SYNONYMS ('고유회원수', '약정보유회원수')
      COMMENT = '활동여부 무관, 이 팩트에 약정이 하나라도 있는 고유 회원수(명). N(비가산)',
    -- ── 금액 ──────────────────────────────────────────────────────────────────
    fmsb.CURRENTLY_ACTIVE_SPNSR_AMT AS SUM(IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.SPNSR_AMT, 0))
      WITH SYNONYMS ('지금 활동 약정금액', '현재 활동 후원금액')
      COMMENT = '**지금 시점** 미중단 약정의 SPNSR_AMT 합(원). F(가산). 🔴정본 (건) 표기로 바꾸려면 이 값을 만원 단위로 환산한다(CONF-2 규약) — 이 SV 는 원단위로 노출하고 환산은 소비 시 명시한다.',
    fmsb.TOTAL_SPNSR_AMT AS SUM(fmsb.SPNSR_AMT)
      WITH SYNONYMS ('약정금액 총계')
      COMMENT = '활동여부 무관 SPNSR_AMT 합(원). F(가산)'
  )
  COMMENT = 'Phase-1 회원×후원약정 SV (base: GOLD.FACT_MEMBER_SPONSOR_BIZ, grain: MEMBER_DK × SPNSR_BSNS_NO). 캠페인별/후원사업별 활동회원(CURRENTLY_ACTIVE_MEMBERS), 약정금액(CURRENTLY_ACTIVE_SPNSR_AMT), 등록건수 뷰. ⚠️ 전체 활동회원수 총계는 SV_MEMBER_MONTHLY 가 정본. 다중 후원으로 인해 캠페인/후원사업별 합계는 전체 활동회원수보다 클 수 있음.'
  AI_SQL_GENERATION '핵심 규칙: (1) 활동회원 총계 vs 분해: 전체 활동회원수 총계는 SV_MEMBER_MONTHLY 로 라우팅. 캠페인별/후원사업별 분해 시에만 본 뷰의 CURRENTLY_ACTIVE_MEMBERS 사용. (2) 다중후원 안내: 캠페인/후원사업별 합계 > 전체 활동회원수(다중 후원 정상 현상)임을 명시. (3) 특정 과거월 as-of: 과거 특정월 활동 판정은 START_MONTH_KEY <= 월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > 월) 조건으로 직접 구성. (4) 회원 식별: 회원 식별은 항상 MEMBER_DK 기준.';

-- ── GRANT ──────────────────────────────────────────────────────────────────
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_SERVICE;

/* =====================================================================================
   스모크 — 절대값이 아니라 불변식으로 판정한다.
   ===================================================================================== */

-- (F-1) fan-out 0 : SV 행수 == 팩트 행수
SELECT (SELECT TOTAL_REGISTRATIONS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS TOTAL_REGISTRATIONS)) AS sv_val,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_SPONSOR_BIZ)                                                        AS fact_val;
--   판정: sv_val == fact_val == 2,170,572

-- (F-2) "명" 이 행수와 다른가 — DISTINCT 가 실제로 작동하는지 확인(O39 유형)
SELECT (SELECT DISTINCT_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS DISTINCT_MEMBERS)) AS distinct_members,
       (SELECT TOTAL_REGISTRATIONS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS TOTAL_REGISTRATIONS)) AS total_regs;
--   판정: distinct_members <= total_regs (같으면 정상, 초과는 불가능 — 초과 시 조인 fan-out 의심)

-- (F-3) 캠페인·후원사업별 분해가 실제로 되는가
SELECT SPONSORSHIP, CAMPAIGN, CURRENTLY_ACTIVE_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
       DIMENSIONS SPONSORSHIP, CAMPAIGN
       METRICS CURRENTLY_ACTIVE_MEMBERS)
ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST
LIMIT 20;
--   판정: 두 축 모두 값이 나오고 "(미매핑)" 버킷이 보인다

-- (F-4) 캠페인별 합계가 전체보다 클 수 있음을 확인(다중후원 정상 현상 — 합산 경고 검증)
SELECT SUM(CURRENTLY_ACTIVE_MEMBERS) AS sum_by_campaign
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
       DIMENSIONS CAMPAIGN
       METRICS CURRENTLY_ACTIVE_MEMBERS);
SELECT CURRENTLY_ACTIVE_MEMBERS AS total_no_axis
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS CURRENTLY_ACTIVE_MEMBERS);
--   판정: sum_by_campaign >= total_no_axis (다중 후원 회원 중복 반영 — 같으면 다중후원 0명이라는 뜻)

-- (F-5) 소유권
SHOW SEMANTIC VIEWS LIKE 'SV_MEMBER_SPONSOR_BIZ' IN SCHEMA GN_DW.SERVING;
--   판정: owner = GN_DW_ADMIN

-- ============================================================================
-- _Co-authored with CoCo_
-- ============================================================================
