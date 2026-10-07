-- ============================================================================
-- 05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql — Semantic View DDL 정본: SV_MEMBER_SERVICE_COHORT (🆕 O205 · 2차 Agent 개선 B)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · 🔴 선행 = dbt build `WIDE_MEMBER_SERVICE_COHORT`(사용자 실행 · R4-1). 뷰가 없으면 이 DDL 은 실패한다.
--   · 근거(2026-10-07 O205 실측 · 원천 직접 집계):
--     선넘는좋은일 상위캠페인 가입(2026-01~09) 4,174명 = 즉시 알림톡 수신 3,508 · 미수신 666
--     일반행사 참여 회원 = 수신 1,173(33.44%) · 미수신 265(39.79%) · D5 중단 매칭 수신 121
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT
  TABLES (
    svc AS GN_DW.GOLD.WIDE_MEMBER_SERVICE_COHORT
      WITH SYNONYMS ('서비스 수신 코호트', '알림톡 수신 회원', '서비스 수신 회원', '수신 미수신 비교')
      COMMENT = '서비스 수신 코호트(grain = 회원 × 서비스그룹 × 수신연도 · 미수신은 연도 NULL 단일 행). 발송·획득 코호트·중단·행사참여를 회원 단위로 미리 결합했다. [원천: CRM(eCRM·UMS) → BRONZE_CRM → GOLD.FACT_MESSAGE_DISPATCH·DIM_MEMBER_ACQUISITION·FACT_MEMBER_EVENT·FACT_EVENT_ATTENDANCE → GOLD.WIDE_MEMBER_SERVICE_COHORT]. 🔴 서비스그룹은 발송 제목 부분일치 임시 규칙(현업 확인 대기).'
  )
  DIMENSIONS (
    svc.SERVICE_GROUP_CD AS svc.SERVICE_GROUP_CD WITH SYNONYMS ('서비스그룹코드') COMMENT = '서비스그룹 코드. 실제값 4종: ''SNG_INSTANT''(선넘는좋은일 신규 즉시 · 개별화서비스신규(사단)의 선넘는좋은일 즉시 알림톡)·''PERSONAL_NEW_SADAN''(개별화 신규 사단)·''LUCKY_CARD''(행운의 카드)·''LONGTERM_THANKS''(장기회원 서비스). 🔴 반드시 하나로 고정한다',
    svc.SERVICE_GROUP_NAME AS svc.SERVICE_GROUP_NAME WITH SYNONYMS ('서비스그룹', '서비스명', '알림톡 서비스') COMMENT = '서비스그룹 이름(임시 규칙 라벨). 실제값 4종: ''선넘는좋은일 신규 즉시''·''개별화 신규(사단)''·''행운의 카드''·''장기회원 서비스''',
    svc.RECEIVE_YEAR AS svc.RECEIVE_YEAR WITH SYNONYMS ('수신연도', '발송연도') COMMENT = '수신연도. 미수신 행은 NULL',
    svc.RECEIVED_FLAG AS svc.RECEIVED_FLAG WITH SYNONYMS ('수신여부', '수신 여부', '받은 회원') COMMENT = 'TRUE = 그 그룹 수신 · FALSE = 획득 코호트 회원 중 미수신',
    svc.FIRST_RECEIVE_DATE AS svc.FIRST_RECEIVE_DATE WITH SYNONYMS ('첫 수신일', '수신일') COMMENT = '그 연도 첫 수신일',
    svc.D5_STOP_FLAG AS svc.D5_STOP_FLAG WITH SYNONYMS ('5일 내 중단', '발송 후 5일 이내 중단') COMMENT = '발송 다음날~+5일(D+1~D+5) 중단 매칭 여부. 🔴 인과가 아니라 시간창 매칭',
    svc.D5_INCREASE_FLAG AS svc.D5_INCREASE_FLAG WITH SYNONYMS ('5일 내 증액') COMMENT = 'D+1~D+5 증액 매칭 여부. 🔴 시간창 매칭',
    svc.D5_STOP_REASON AS svc.D5_STOP_REASON WITH SYNONYMS ('중단사유') COMMENT = 'D+1~D+5 첫 중단 사건의 중단사유',
    svc.D5_STOP_CHANNEL AS svc.D5_STOP_CHANNEL WITH SYNONYMS ('중단경로') COMMENT = 'D+1~D+5 첫 중단 사건의 중단경로',
    svc.D5_STOP_SPONSORSHIP AS svc.D5_STOP_SPONSORSHIP WITH SYNONYMS ('중단 후원사업', '후원사업') COMMENT = 'D+1~D+5 첫 중단 사건이 끊은 후원사업',
    svc.ACQ_DATE AS svc.ACQ_DATE WITH SYNONYMS ('가입일', '획득일') COMMENT = '획득(가입) 일자 — 「○월부터 ○월까지 가입한 회원」은 이 축으로 거른다',
    svc.ACQ_YEAR AS svc.ACQ_YEAR WITH SYNONYMS ('가입연도') COMMENT = '획득 연도',
    svc.ACQ_CAMPAIGN_NAME AS svc.ACQ_CAMPAIGN_NAME WITH SYNONYMS ('가입캠페인', '캠페인명') COMMENT = '획득 캠페인명',
    svc.ACQ_PARENT_CAMPAIGN_NAME AS svc.ACQ_PARENT_CAMPAIGN_NAME WITH SYNONYMS ('상위캠페인', '가입 상위캠페인') COMMENT = '획득 상위캠페인명. 🔴 「선넘는좋은일 캠페인으로 가입」은 ILIKE ''%선넘는좋은일%'' 로 이 축을 거른다(캠페인명에는 없다)',
    svc.ACQ_CAMPAIGN_TYPE AS svc.ACQ_CAMPAIGN_TYPE WITH SYNONYMS ('캠페인카테고리', '주요캠페인') COMMENT = '획득 캠페인카테고리',
    svc.ACQ_INFLOW_PATH AS svc.ACQ_INFLOW_PATH WITH SYNONYMS ('개발인입경로', '인입경로') COMMENT = '획득 개발인입경로',
    svc.ACQ_CPR_DIV_NM AS svc.ACQ_CPR_DIV_NM WITH SYNONYMS ('법인구분') COMMENT = '획득 세부캠페인 법인구분(통합/사단/사복)',
    svc.ACQ_SPONSORSHIP_NAME AS svc.ACQ_SPONSORSHIP_NAME WITH SYNONYMS ('가입 후원사업', '획득 후원사업') COMMENT = '획득 후원사업',
    svc.ACQ_AGE_BAND AS svc.ACQ_AGE_BAND WITH SYNONYMS ('연령대') COMMENT = '획득 시점 연령대 — 현재 나이가 아니다',
    svc.ACQ_REGION AS svc.ACQ_REGION WITH SYNONYMS ('지역') COMMENT = '획득 시점 지역 — 현재 거주지가 아니다',
    svc.ACQ_GENDER AS svc.ACQ_GENDER WITH SYNONYMS ('성별') COMMENT = '획득 시점 성별',
    svc.EVER_STOPPED_FLAG AS svc.EVER_STOPPED_FLAG WITH SYNONYMS ('중단 이력') COMMENT = '최초 중단 이력 여부'
  )
  METRICS (
    svc.MEMBER_COUNT AS COUNT(DISTINCT svc.MEMBER_DK)
      WITH SYNONYMS ('회원수', '명')
      COMMENT = '고유 회원수(명). 🔴 서비스그룹 하나로 고정한 상태에서 쓴다.',
    svc.GENERAL_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('온라인 이벤트 참여 회원수', '일반행사 참여 회원수')
      COMMENT = '일반행사(EVENT 원천 · 온라인 다단계 이벤트) 참여 기록이 있는 고유 회원수.',
    svc.GENERAL_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('온라인 이벤트 참여율', '일반행사 참여율')
      COMMENT = '일반행사 참여율(%) = 참여 회원 ÷ 회원. N(비가산).',
    svc.CAMPAIGN_EVENT_PART_MEMBERS AS COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('문화이벤트 참여 회원수', '캠페인행사 참여 회원수')
      COMMENT = '캠페인행사(CRMN 원천) 참여 기록이 있는 고유 회원수. 🔴 「문화이벤트」 = 캠페인행사 매핑은 현업 확인 대기 — 답변에 그 전제를 밝힌다.',
    svc.CAMPAIGN_EVENT_PART_RATE AS DIV0(COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100
      WITH SYNONYMS ('문화이벤트 참여율', '캠페인행사 참여율')
      COMMENT = '캠페인행사 참여율(%). N(비가산).',
    svc.AVG_GENERAL_EVENT_PART_ROWS AS AVG(svc.GENERAL_EVENT_PART_ROWS)
      WITH SYNONYMS ('평균 이벤트 참여횟수', '1인당 참여횟수')
      COMMENT = '행당 평균 일반행사 참여 기록 수. 🔴 수신연도를 고정한 상태에서 쓴다(연도별 행 중복).',
    svc.AVG_GENERAL_EVENT_PART_ROWS_AFTER AS AVG(svc.GENERAL_EVENT_PART_ROWS_AFTER)
      WITH SYNONYMS ('수신 후 평균 참여횟수')
      COMMENT = '첫 수신일 이후 평균 일반행사 참여 기록 수(수신 행만 · 미수신은 NULL 이라 제외된다).',
    svc.D5_STOP_MEMBERS AS COUNT(DISTINCT IFF(svc.D5_STOP_FLAG, svc.MEMBER_DK, NULL))
      WITH SYNONYMS ('5일 내 중단 회원수')
      COMMENT = 'D+1~D+5 중단 매칭 고유 회원수(시간창 매칭 · 인과 아님).',
    svc.AVG_TENURE_DAYS AS AVG(svc.TENURE_DAYS)
      WITH SYNONYMS ('평균 후원유지기간', '평균 유지기간(일)')
      COMMENT = '평균 후원 유지기간(일). 🔴 수신연도를 고정한 상태에서 쓴다.',
    svc.AVG_ACQ_SPNSR_AMT AS AVG(svc.ACQ_SPNSR_AMT)
      WITH SYNONYMS ('평균 후원금액', '평균 약정금액')
      COMMENT = '획득 시점 평균 약정 후원금액(원).',
    svc.AVG_D5_STOP_SPONSOR_DAYS AS AVG(svc.D5_STOP_SPONSOR_DAYS)
      WITH SYNONYMS ('중단 회원 평균 후원기간')
      COMMENT = 'D5 중단 회원의 평균 후원기간(일 · 획득일 → D5 중단일 · O205-B). 🔴 중단 사건 원천에는 후원금액이 없다 — 중단 회원의 후원금액은 AVG_ACQ_SPNSR_AMT(획득 시점 약정금액)로 답하고 그 전제를 밝힌다.'
  )
  COMMENT = '서비스 수신 코호트 SV(🆕 O205). 「서비스 수신/미수신 회원의 이벤트 참여율 비교」·「발송 후 5일 이내 중단한 회원의 가입캠페인·중단사유·후원금액·연령대·후원사업·후원기간」·「연도별 수신회원 유지기간·참여횟수」에 쓴다. 🔴 수신·미수신 차이는 인과(서비스 효과)가 아니다.'
  AI_SQL_GENERATION '핵심 규칙: (1) 반드시 svc.SERVICE_GROUP_CD 를 하나로 고정한다. (2) 연도별 질문은 svc.RECEIVE_YEAR 로 고정하고, 수신/미수신 비교는 svc.RECEIVED_FLAG 로 나눈다(미수신은 RECEIVE_YEAR 가 NULL 이므로 연도 조건을 걸면 사라진다 — 미수신 비교가 필요하면 연도 조건을 RECEIVED_FLAG = TRUE 쪽에만 건다). (3) 회원수·참여율은 반드시 COUNT(DISTINCT svc.MEMBER_DK) 기반 지표를 쓴다. (4) 「선넘는좋은일 캠페인으로 가입」은 svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE ''%선넘는좋은일%'', 가입기간은 svc.ACQ_DATE 로 거른다. (5) 「온라인 이벤트」 = 일반행사 지표, 「문화이벤트」 = 캠페인행사 지표로 답하되 그 매핑이 현업 확인 대기임을 밝힌다. (6) 「효과가 높다/낮다」를 인과로 단정하지 않는다 — 지표 차이로만 표현한다. (7) 「오픈」 조건은 이 SV 에 없다(알림톡 오픈 원천 부재) — 수신 기준으로 답하고 그 사실을 밝힌다. (8) 🔴 「수신 회원」·「발송 후 5일 내 중단」·「수신회원 유지기간·참여횟수」 질문은 반드시 svc.RECEIVED_FLAG = TRUE 로 거른다 — 거르지 않으면 미수신(획득 코호트 전체) 회원이 모수에 섞인다. 수신 회원수를 말할 때는 이 조건을 건 값만 쓴다. (9) 장기회원 서비스의 법인(사단·사복)은 제목 접두로만 드러나고 이 SV 에는 제목 법인 축이 없다(2025·2026 제목에는 「사단」 표기가 없고 「사복」 또는 표기 없음만 있다) — 「(사단)」을 물으면 서비스그룹 전체(법인 구분 없음)로 답하고 그 한계를 밝힌다. 획득 세부캠페인 법인구분(svc.ACQ_CPR_DIV_NM)은 발송 법인과 다른 축이므로 대신 쓰지 않는다.'
  AI_VERIFIED_QUERIES (
    vqr_o205_sng_part AS (
      QUESTION '선넘는좋은일 캠페인으로 2026년 1월부터 9월까지 가입한 회원 중 선넘는좋은일 즉시 알림톡 수신/미수신 회원의 온라인 이벤트·문화이벤트 참여율 비교'
      VERIFIED_BY '(DW = O205 원천 직접 집계 · 기대값은 파일 머리 주석)'
      SQL 'SELECT svc.RECEIVED_FLAG, COUNT(DISTINCT svc.MEMBER_DK) AS MEMBER_COUNT, DIV0(COUNT(DISTINCT IFF(svc.GENERAL_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100 AS GENERAL_EVENT_PART_RATE, DIV0(COUNT(DISTINCT IFF(svc.CAMPAIGN_EVENT_PART_ROWS > 0, svc.MEMBER_DK, NULL)), COUNT(DISTINCT svc.MEMBER_DK)) * 100 AS CAMPAIGN_EVENT_PART_RATE FROM svc WHERE svc.SERVICE_GROUP_CD = ''SNG_INSTANT'' AND svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE ''%선넘는좋은일%'' AND svc.ACQ_DATE BETWEEN ''2026-01-01'' AND ''2026-09-30'' GROUP BY svc.RECEIVED_FLAG ORDER BY svc.RECEIVED_FLAG'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인) — VQR 기대값 = 수신 3,508 · 미수신 666 (O205 원천 직접 집계)
SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_SERVICE_COHORT
  DIMENSIONS svc.RECEIVED_FLAG
  METRICS svc.MEMBER_COUNT, svc.GENERAL_EVENT_PART_RATE, svc.CAMPAIGN_EVENT_PART_RATE
  WHERE svc.SERVICE_GROUP_CD = 'SNG_INSTANT'
    AND svc.ACQ_PARENT_CAMPAIGN_NAME ILIKE '%선넘는좋은일%'
    AND svc.ACQ_DATE BETWEEN '2026-01-01' AND '2026-09-30');
