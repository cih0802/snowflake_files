-- ============================================================================
-- 05_14_SV_DDL_MEMBER_MONTHLY_KPI.sql — Semantic View DDL 정본: SV_MEMBER_MONTHLY_KPI
--   · 🆕 [2026-10-03 O201-D] 공45·46·47 활동율(누계개발 분모) 전용 SV
--   · base = GOLD.WIDE_MEMBER_MONTHLY_KPI(dbt view · 월 × 신규기존 모집단 집계)
--   · 🔴 선행 = `dbt build --project-dir 10_dbt_pipeline --select WIDE_MEMBER_MONTHLY_KPI` (사람 실행 · R4-1)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY_KPI
  TABLES (
    kpi AS GN_DW.GOLD.WIDE_MEMBER_MONTHLY_KPI
      WITH SYNONYMS ('회원 활동율', '활동율 집계')
      COMMENT = '회원 월 지표 모집단 집계(grain = 월 × 신규기존). 🔴 행이 회원이 아니다 — 회원 속성으로 분해하지 않는다. 누계개발(건) = 당해년도 1월~조회월 개발(건) 합계(사용자 확정 2026-10-03).'
  )
  DIMENSIONS (
    kpi.MONTH_KEY AS kpi.MONTH_KEY WITH SYNONYMS ('연월', '조회연월') COMMENT = 'YYYYMM 정수 · 🔴 비율 지표는 한 달을 지정해 쓴다',
    kpi.CAL_YEAR  AS kpi.CAL_YEAR  WITH SYNONYMS ('연도', '년') COMMENT = '연도(YYYY)',
    kpi.NEW_EXISTING_FLAG AS kpi.NEW_EXISTING_FLAG WITH SYNONYMS ('신규기존구분', '신규/기존') COMMENT = '신규기존구분(공113) — 그 달 회원 행의 구분'
  )
  METRICS (
    kpi.DEV_CUM_AMT_CNT_SUM AS SUM(kpi.DEV_CUM_AMT_CNT)
      WITH SYNONYMS ('누계개발(건)', '누계개발건', '당해년 누계개발') COMMENT = '누계개발(건) = 당해년도 1월~조회월의 개발(건) 합계 · 개발(건) = **MSTR 정의**(O202): 신규·재후원·증액 MSTR 인정금액 ÷ 10,000(활동(건)과 같은 단위). 🔴 한 달을 지정한다(누계라 여러 달을 더하지 않는다).',
    kpi.DEV_CUM_EVENT_CNT_SUM AS SUM(kpi.DEV_CUM_CNT)
      WITH SYNONYMS ('누계개발 회원월 경유') COMMENT = '참고 — 같은 MSTR 개발(건)을 회원 월 팩트(FMM) 경유로 누적한 값(O202 이후 정의 동일 · 신규기존 판정 경로만 다르다). 🔴 활동율 계산에는 DEV_CUM_AMT_CNT_SUM 을 쓴다.',
    kpi.ACTIVE_RATE AS SUM(kpi.MONTH_END_ACTIVE_CNT) / NULLIF(SUM(kpi.YEAR_START_ACTIVE_CNT) + SUM(kpi.DEV_CUM_AMT_CNT), 0) * 100
      WITH SYNONYMS ('활동율', '공45', '전체회원 활동율') COMMENT = '공45 활동율(%) = 월말활동(건) ÷ (연도초활동(건) + 누계개발(건)) ×100. 비율(N). 🔴 한 달을 지정한다.',
    kpi.ACTIVE_RATE_NEW AS SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '신규' THEN kpi.ACTIVE_CNT END)
        / NULLIF(SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '신규' THEN kpi.DEV_CUM_AMT_CNT END), 0) * 100
      WITH SYNONYMS ('신규 활동율', '공46') COMMENT = '공46 신규 활동율(%) = 활동(건)[신규] ÷ 누계개발(건)[신규] ×100. 🟢 [O202 · 2026-10-06 현업 회신] 지표 사전 표기(누계개발 ÷ 활동)는 분자·분모가 바뀐 **오타**였다 — 교정본이다. 비율(N). 🔴 한 달을 지정한다.',
    kpi.ACTIVE_RATE_EXISTING AS SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '기존' THEN kpi.ACTIVE_CNT END)
        / NULLIF(SUM(CASE WHEN kpi.NEW_EXISTING_FLAG = '기존' THEN kpi.DEV_CUM_AMT_CNT + kpi.YEAR_START_ACTIVE_CNT END), 0) * 100
      WITH SYNONYMS ('기존 활동율', '공47') COMMENT = '공47 기존 활동율(%) = 활동(건)[기존] ÷ (누계개발(건)[기존] + 연도초활동(건)[기존]) ×100. 비율(N). 🔴 한 달을 지정한다.'
  )
  COMMENT = '회원 활동율(공45·46·47) SV (base: GOLD.WIDE_MEMBER_MONTHLY_KPI · grain = 월 × 신규기존). 누계개발(건) = 당해년도 1월~조회월 개발(건) 합계. 🔴 회원 월 실적 상세(회비·미납 등)는 SV_MEMBER_MONTHLY 소관이며 두 SV 수치를 한 표에서 합산하지 않는다.';

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY_KPI TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY_KPI TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_MONTHLY_KPI TO ROLE GN_DW_SERVICE;

-- 스모크(배포 후)
-- SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY_KPI
--   METRICS kpi.ACTIVE_RATE, kpi.ACTIVE_RATE_NEW, kpi.ACTIVE_RATE_EXISTING DIMENSIONS kpi.MONTH_KEY)
-- WHERE MONTH_KEY = 202512;
