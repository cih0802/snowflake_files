-- ============================================================================
-- 05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql — Semantic View DDL 정본: SV_MEMBER_SPONSOR_BIZ
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
  TABLES (
    fmsb AS GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN
      WITH SYNONYMS ('회원 후원약정', '캠페인별 활동회원', '후원사업별 활동회원')
      COMMENT = '회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].',
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
  DIMENSIONS (
    fmsb.MEMBER_DK        AS fmsb.MEMBER_DK    WITH SYNONYMS ('회원번호') COMMENT = '회원 (불변키)',
    fmsb.SPNSR_BSNS_NO    AS fmsb.SPNSR_BSNS_NO WITH SYNONYMS ('후원사업번호', '약정번호') COMMENT = '회원별 후원약정 일련번호. 🔴단독 유일키 아니다 — 공동후원 쌍(부부 등)이 2개 회원에 공유되는 사례가 실재한다. 분류축이 아니다(분류는 SPONSORSHIP 축)',
    sponsorship.SPONSORSHIP AS sponsorship.SPONSORSHIP_NAME WITH SYNONYMS ('후원사업', '후원사업명', '사업') COMMENT = '후원사업명(마스터). 미매핑 없음(전건 매칭 실측 확인)',
    sponsorship.SPONSORSHIP_DIV AS sponsorship.SPONSORSHIP_DIV_NAME WITH SYNONYMS ('정기일시구분') COMMENT = '정기후원/일시후원 구분(CM035). 실제값 2종: ''정기후원''·''일시후원''.',
    sponsorship.SPONSORSHIP_ABBR_CATEGORY AS sponsorship.SPONSORSHIP_GROUP_NAME WITH SYNONYMS ('후원사업 약칭', '후원사업 카테고리') COMMENT = '후원사업 약칭 그룹(CM003). 실제값 6종: ''결연''·''국내''·''기타''·''북한''·''해외''·''해외구호''.',
    campaign.CAMPAIGN     AS campaign.CAMPAIGN_NAME WITH SYNONYMS ('캠페인', '캠페인명') COMMENT = '대표캠페인명. 판정 규칙 = CRM_MEMBER_DEV 사건 중 ①신규사건이 있으면 그 신규사건 ②없으면 최초사건(동률 0 확인). 사건 자체가 없는 약정은 "(미매핑)"(0). ⚠️단일 회원-grain 캠페인 분해(FACT_MEMBER_MONTHLY 기준)와는 다른 축이다 — 이 SV 는 약정grain 이라 값이 다르게 나올 수 있다',
    fmsb.ACQ_CMPGN_CTGR_NM AS fmsb.ACQ_CMPGN_CTGR_NM WITH SYNONYMS ('캠페인 카테고리', '주요캠페인') COMMENT = '대표캠페인 카테고리 라벨(MM294). 🔴적재 시점 동결값(구 campaign.CAMPAIGN_TYPE 대체)',
    fmsb.IS_MULTI_CAMPAIGN AS fmsb.IS_MULTI_CAMPAIGN WITH SYNONYMS ('다중캠페인 여부') COMMENT = '참고용 투명성 플래그 — 이 SPNSR_BSNS_NO 의 전체 사건에서 캠페인이 2개 이상이었는지. 대표캠페인 채택 규칙과는 별개. 🟢실측상 극소수이며 최대 2개다(규모는 이슈원장·04 §0.9 참조)',
    fmsb.START_MONTH_KEY  AS fmsb.START_MONTH_KEY WITH SYNONYMS ('활동개시월') COMMENT = '활동 개시 월키 YYYYMM. 특정월 as-of 활동 판정 시 이 축과 DSCNTC_MONTH_KEY 를 함께 WHERE 절로 비교한다(AI_SQL_GENERATION 참조)',
    fmsb.DSCNTC_MONTH_KEY AS fmsb.DSCNTC_MONTH_KEY WITH SYNONYMS ('중단월') COMMENT = '중단 월키 YYYYMM. 🔴NULL=미중단(현재까지 활동)이며 결측이 아니다'
  )
  METRICS (
    fmsb.CURRENTLY_ACTIVE_MEMBERS AS COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL))
      WITH SYNONYMS ('지금 활동회원수', '현재 활동회원')
      COMMENT = '**지금 시점** 활동회원수(명) = 미중단 약정을 보유한 고유회원. N(비가산). 🔴전체 활동회원수 정본은 SV_MEMBER_MONTHLY.ACTIVE_MEMBERS 다 — 이 metric 을 캠페인·후원사업으로 GROUP BY 하면 한 회원이 여러 축에 중복 집계될 수 있어 **합계가 전체보다 클 수 있다**(다중 후원 정상 현상). 특정 과거월 as-of 는 이 metric 이 아니라 START_MONTH_KEY·DSCNTC_MONTH_KEY 원시축으로 직접 WHERE 를 구성한다.',
    fmsb.TOTAL_REGISTRATIONS AS COUNT(*)
      WITH SYNONYMS ('약정건수', '등록건수')
      COMMENT = '약정(SPNSR_BSNS_NO) 행수. F(가산). 🔴"명"이 아니다 — 회원당 여러 약정을 가질 수 있다',
    fmsb.DISTINCT_MEMBERS AS COUNT(DISTINCT fmsb.MEMBER_DK)
      WITH SYNONYMS ('고유회원수', '약정보유회원수')
      COMMENT = '활동여부 무관, 이 팩트에 약정이 하나라도 있는 고유 회원수(명). N(비가산)',
    fmsb.CURRENTLY_ACTIVE_SPNSR_AMT AS SUM(IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.SPNSR_AMT, 0))
      WITH SYNONYMS ('지금 활동 약정금액', '현재 활동 후원금액')
      COMMENT = '**지금 시점** 미중단 약정의 SPNSR_AMT 합(원). F(가산). 🔴정본 (건) 표기로 바꾸려면 이 값을 만원 단위로 환산한다(CONF-2 규약) — 이 SV 는 원단위로 노출하고 환산은 소비 시 명시한다.',
    fmsb.TOTAL_SPNSR_AMT AS SUM(fmsb.SPNSR_AMT)
      WITH SYNONYMS ('약정금액 총계')
      COMMENT = '활동여부 무관 SPNSR_AMT 합(원). F(가산)'
  )
  COMMENT = '회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].'
  AI_SQL_GENERATION '핵심 규칙: (1) 활동회원 총계 vs 분해: 전체 활동회원수 총계는 SV_MEMBER_MONTHLY 로 라우팅. 캠페인별/후원사업별 분해 시에만 본 뷰의 CURRENTLY_ACTIVE_MEMBERS 사용. (2) 다중후원 안내: 캠페인/후원사업별 합계 > 전체 활동회원수(다중 후원 정상 현상)임을 명시. (3) 특정 과거월 as-of: 과거 특정월 활동 판정은 START_MONTH_KEY <= 월 AND (DSCNTC_MONTH_KEY IS NULL OR DSCNTC_MONTH_KEY > 월) 조건으로 직접 구성. (4) 회원 식별: 회원 식별은 항상 MEMBER_DK 기준.'
  AI_VERIFIED_QUERIES (
    vqr_active_by_sponsorship AS (
      QUESTION '후원사업별 지금 활동회원 수'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT sponsorship.SPONSORSHIP, COUNT(DISTINCT IFF(fmsb.DSCNTC_MONTH_KEY IS NULL, fmsb.MEMBER_DK, NULL)) AS CURRENTLY_ACTIVE_MEMBERS FROM fmsb LEFT JOIN sponsorship ON fmsb.SPONSORSHIP_SK = sponsorship.SPONSORSHIP_SK GROUP BY sponsorship.SPONSORSHIP ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ TO ROLE GN_DW_SERVICE;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_REGISTRATIONS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS TOTAL_REGISTRATIONS)) AS sv_val,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_SPONSORSHIP_SPAN)                                                   AS fact_val;

SELECT (SELECT DISTINCT_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS DISTINCT_MEMBERS)) AS distinct_members,
       (SELECT TOTAL_REGISTRATIONS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS TOTAL_REGISTRATIONS)) AS total_regs;

SELECT SPONSORSHIP, CAMPAIGN, CURRENTLY_ACTIVE_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
       DIMENSIONS SPONSORSHIP, CAMPAIGN
       METRICS CURRENTLY_ACTIVE_MEMBERS)
ORDER BY CURRENTLY_ACTIVE_MEMBERS DESC NULLS LAST
LIMIT 20;

SELECT SUM(CURRENTLY_ACTIVE_MEMBERS) AS sum_by_campaign
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ
       DIMENSIONS CAMPAIGN
       METRICS CURRENTLY_ACTIVE_MEMBERS);
SELECT CURRENTLY_ACTIVE_MEMBERS AS total_no_axis
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SPONSOR_BIZ METRICS CURRENTLY_ACTIVE_MEMBERS);

SHOW SEMANTIC VIEWS LIKE 'SV_MEMBER_SPONSOR_BIZ' IN SCHEMA GN_DW.SERVING;
