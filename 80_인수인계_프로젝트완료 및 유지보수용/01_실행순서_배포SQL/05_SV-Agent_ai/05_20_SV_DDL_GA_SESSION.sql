-- =============================================================================
-- Purpose    : Semantic View DDL 정본: SV_GA_SESSION ( O213-F Y3-F)
-- Target     : SEMANTIC VIEW GN_DW.SERVING.SV_GA_SESSION
-- Run order  : 운영계 #37 · 기존 환경 갱신 #2 · 기존 환경 갱신 #17
-- Depends on : GN_DW.GOLD.FACT_BIGQUERY_SESSION, GN_DW.GOLD.DIM_DATE, GN_DW.GOLD.DIM_MEMBER_IDENTITY, GN_DW.SILVER.BIGQUERY_SESSION
-- Issue      : O213-F, O213, O212, O241
-- =============================================================================
-- ============================================================================
-- 05_20_SV_DDL_GA_SESSION.sql — Semantic View DDL 정본: SV_GA_SESSION ( O213-F Y3-F)
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능.
--   · WARN: 선행 = dbt build `BIGQUERY_SESSION+` + 전량 백필(--vars bigquery_dt_ranges) — 백필 전에는 최근 3일치뿐이다.
--   · 왜 신설했나 — 현업 「브론즈엔 후원자유형·국가·브라우저가 있는데 왜 답을 못 하나」:
--     SILVER.BIGQUERY_REFINED_DATA 의 세션 속성 25축이 GOLD·SV 어디에도 없었다(O213 Y1 lineage NONE).
--     SV_GA_BEHAVIOR(FACT_BIGQUERY_BEHAVIOR · 이벤트×페이지 grain)에 넣으면 grain 이 깨진다 ⇒ 세션 grain SV 분리.
--   · 축 이름 = 원천 컬럼명 원칙(O212) · 한글은 동의어로 준다.
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_GA_SESSION
  TABLES (
    gs AS GN_DW.GOLD.FACT_BIGQUERY_SESSION
      WITH SYNONYMS ('GA 세션', '웹 세션', '홈페이지 방문', '방문 세션', 'GA4 세션')
      COMMENT = 'GA4 세션 팩트(1행 = 1일 × 1세션). 「후원자유형·회원유형·국가·기기·브라우저·유입채널별 방문(세션)·방문자」 질문용. [원천: GA4(BigQuery export) → SILVER.BIGQUERY_REFINED_DATA → SILVER.BIGQUERY_SESSION → GOLD.FACT_BIGQUERY_SESSION]. 🔴 페이지·이벤트 단위 질문은 SV_GA_BEHAVIOR 소관이며 이 SV 와 한 표에 합산하지 않는다(같은 원천 · 다른 grain). 🔴 자정을 넘는 세션은 일자별 2행이다 — 세션수는 반드시 고유 세션키로 센다(SESSION_CNT).',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '방문일')
      COMMENT = '일 차원. [원천] ETL 생성(달력).',
    ident AS GN_DW.GOLD.DIM_MEMBER_IDENTITY
      PRIMARY KEY (IDENTITY_SK)
      WITH SYNONYMS ('회원 식별', 'GA 회원')
      COMMENT = '🆕 [O245 공112] 회원 식별 결선 차원(GA member id ↔ CRM 회원번호). GA member id 는 CRM 회원번호와 같은 값이다(2026-10-18 실측 불일치 0).'
  )
  RELATIONSHIPS (
    gs_to_date AS gs (DATE_SK) REFERENCES date,
    gs_to_ident AS gs (IDENTITY_SK) REFERENCES ident
  )
  DIMENSIONS (
    date.VISIT_DATE AS date.FULL_DATE WITH SYNONYMS ('방문일', '일자', '날짜') COMMENT = '세션 일자(GA4 event_date · 한국시간 기준 속성).',
    date.CAL_YEAR AS date.YEAR WITH SYNONYMS ('연도', '년') COMMENT = '연도',
    date.CAL_MONTH AS date.MONTH WITH SYNONYMS ('월') COMMENT = '월(1~12)',
    gs.PLATFORM AS gs.PLATFORM WITH SYNONYMS ('플랫폼', '웹/앱') COMMENT = '플랫폼(GA4 원값 · 2026-10-08 실측 전건 WEB — 앱 데이터는 이 원천에 없다).',
    gs.DEVICE_CATEGORY AS gs.DEVICE_CATEGORY WITH SYNONYMS ('기기', '기기 유형', 'PC/모바일') COMMENT = '기기 카테고리 desktop·mobile·tablet (GA4 원값).',
    gs.DEVICE_OPERATING_SYSTEM AS gs.DEVICE_OPERATING_SYSTEM WITH SYNONYMS ('운영체제', 'OS') COMMENT = '운영체제(Windows·iOS·Android·Macintosh 등 GA4 원값).',
    gs.DEVICE_WEB_INFO_BROWSER AS gs.DEVICE_WEB_INFO_BROWSER WITH SYNONYMS ('브라우저') COMMENT = '브라우저(Chrome·Safari·Samsung Internet 등 GA4 원값).',
    gs.DEVICE_LANGUAGE AS gs.DEVICE_LANGUAGE WITH SYNONYMS ('기기 언어', '언어') COMMENT = '기기 언어 설정(ko-kr·ko·ko-cn 등 GA4 원값 · ko-kr 과 ko 는 원천에서 별도 값).',
    gs.DEVICE_MOBILE_BRAND_NAME AS gs.DEVICE_MOBILE_BRAND_NAME WITH SYNONYMS ('휴대폰 제조사', '기기 브랜드') COMMENT = '기기 제조사(Apple·Samsung 등 GA4 원값).',
    gs.DEVICE_WEB_INFO_HOSTNAME AS gs.DEVICE_WEB_INFO_HOSTNAME WITH SYNONYMS ('사이트', '호스트', '도메인') COMMENT = '방문 사이트 호스트명(www·m·ad·campaign.goodneighbors.kr · hope.gni.kr 등). 사이트별 방문 질문에 쓴다.',
    gs.GEO_CONTINENT AS gs.GEO_CONTINENT WITH SYNONYMS ('대륙') COMMENT = '접속 대륙(GA4 IP 추정 · 영문 원값).',
    gs.GEO_SUB_CONTINENT AS gs.GEO_SUB_CONTINENT WITH SYNONYMS ('지역(대륙 하위)') COMMENT = '접속 하위 대륙(Eastern Asia 등 · 영문 원값).',
    gs.GEO_COUNTRY AS gs.GEO_COUNTRY WITH SYNONYMS ('국가', '접속 국가') COMMENT = '접속 국가(South Korea 등 영문 원값 · IP 추정).',
    gs.GEO_METRO AS gs.GEO_METRO WITH SYNONYMS ('광역권') COMMENT = '접속 광역권(GA4 metro · 국내는 대부분 (not set)).',
    gs.TS_SOURCE AS gs.TS_SOURCE WITH SYNONYMS ('최초 유입 소스', '첫 유입 소스') COMMENT = '사용자 최초 유입 소스(GA4 traffic_source · 사용자 단위 first touch · 세션 유입과 다르다).',
    gs.TS_MEDIUM AS gs.TS_MEDIUM WITH SYNONYMS ('최초 유입 매체', '첫 유입 매체') COMMENT = '사용자 최초 유입 매체(GA4 traffic_source.medium · first touch).',
    gs.CTS_MANUAL_MEDIUM AS gs.CTS_MANUAL_MEDIUM WITH SYNONYMS ('수동 태깅 매체', 'UTM 매체(수집 시점)') COMMENT = '수집 시점 수동 UTM medium(collected_traffic_source).',
    gs.EP_MEDIUM AS gs.EP_MEDIUM WITH SYNONYMS ('이벤트 매체') COMMENT = '세션 첫 이벤트의 medium 파라미터(event_params.medium).',
    gs.STSLC_CRC_DEFAULT_CHANNEL_GROUP AS gs.STSLC_CRC_DEFAULT_CHANNEL_GROUP WITH SYNONYMS ('기본 채널 그룹', '유입 채널') COMMENT = '세션 기본 채널 그룹(GA4 session cross-channel default channel group · Organic Search·Direct·Display 등). 「유입 채널별」 질문의 1순위 축.',
    gs.STSLC_CRC_PRIMARY_CHANNEL_GROUP AS gs.STSLC_CRC_PRIMARY_CHANNEL_GROUP WITH SYNONYMS ('주 채널 그룹') COMMENT = '세션 주 채널 그룹(GA4 primary channel group · Display·Cross-network·Direct 등).',
    gs.STSLC_CRC_SOURCE_PLATFORM AS gs.STSLC_CRC_SOURCE_PLATFORM WITH SYNONYMS ('유입 플랫폼', '광고 플랫폼') COMMENT = '세션 유입 소스 플랫폼(Manual·Google Ads·Other Ads·Meta Ads·Unlabeled).',
    gs.STSLC_GAC_CAMPAIGN_NAME AS gs.STSLC_GAC_CAMPAIGN_NAME WITH SYNONYMS ('구글애즈 캠페인', 'Google Ads 캠페인', '공102') COMMENT = '세션 유입 Google Ads 캠페인명(구글애즈 경유 세션만 값 · 그 밖 NULL).',
    gs.STSLC_GAC_AD_GROUP_NAME AS gs.STSLC_GAC_AD_GROUP_NAME WITH SYNONYMS ('구글애즈 광고그룹') COMMENT = '세션 유입 Google Ads 광고그룹명(구글애즈 경유 세션만 값).',
    gs.UP_MEMBER_TYPE AS gs.UP_MEMBER_TYPE WITH SYNONYMS ('회원유형', '방문자 회원유형', '로그인 회원유형') COMMENT = '홈페이지가 GA4 에 보낸 회원유형(비로그인·정기회원·중단회원·일시회원·앱회원·정기후원 등 원값). 🔴 GTM 미치환 값 「{{정기회원/일시회원/중단회원/앱회원 등}}」 이 섞여 있다 — 의미를 추정하지 말고 「미치환(수집 오류)」으로 밝힌다.',
    gs.UP_DONOR_TYPE AS gs.UP_DONOR_TYPE WITH SYNONYMS ('후원자유형', '개인/단체/기업') COMMENT = '후원자유형(개인·단체·기업 원값 · 후원 이력 사용자만 값 · 그 밖 NULL).',
    gs.UP_DONATION_TYPE AS gs.UP_DONATION_TYPE WITH SYNONYMS ('후원 행동 유형', '신규/증액/감액/재후원') COMMENT = '후원 행동 유형(신규후원·증액후원·증액·감액·재후원 원값 · 「증액」과 「증액후원」은 원천에서 별도 값).',
    gs.UP_BIZ_TYPE AS gs.UP_BIZ_TYPE WITH SYNONYMS ('관심 후원사업', '후원사업 유형') COMMENT = '후원사업 유형(해외아동결연·보건의료지원사업·국내아동권리보호사업 등 원값 · 457종 · 후원 페이지 진입 사용자만 값).',
    gs.UP_LOGIN_STATUS AS gs.UP_LOGIN_STATUS WITH SYNONYMS ('로그인 여부') COMMENT = '로그인 여부 y·n 원값. 🔴 GTM 미치환 값 「{{로그인여부}}」 가 섞여 있다 — 수집 오류로 밝힌다.',
    gs.EP_PAYMENT_TYPE AS gs.EP_PAYMENT_TYPE WITH SYNONYMS ('결제수단', '후원 결제수단') COMMENT = '세션 내 후원 결제 이벤트의 결제수단(신용카드·계좌이체·네이버페이 원값 · 결제 이벤트 없는 세션은 NULL).',
    gs.IS_MEMBER_MATCHED AS IFF(gs.IDENTITY_SK > 0, 'Y', 'N') WITH SYNONYMS ('회원 식별 여부') COMMENT = 'CRM 회원과 매칭된 방문자인가(Y/N · IDENTITY_MEMBER_XREF 결선 · 매칭률 낮음).',
    ident.MEMBER_DK AS IFF(ident.IDENTITY_SK > 0, ident.MEMBER_DK, NULL) WITH SYNONYMS ('공112', 'GA member id', 'GA 회원번호', '회원번호', 'CRM 회원번호') COMMENT = '🆕 [O245 공112] GA member id = CRM 회원번호(MEMBER_DK · 같은 값 · 사용자 결정 2026-10-18 = CRM 에 있는 회원이면 노출). 비회원·미매칭 세션은 NULL 이다(IS_MEMBER_MATCHED = N). 회원별 방문 질문에 쓰고, 다른 SV 와는 이 회원번호로 대조한다.'
  )
  METRICS (
    gs.SESSION_CNT AS COUNT(DISTINCT gs.BIGQUERY_SESSION_KEY)
      WITH SYNONYMS ('세션수', '방문수', '방문(회)', '공92', '공97')
      COMMENT = '고유 세션수(회). 🔴 비가산 — 일자별 값을 더하지 말고 기간을 한 번에 센다(자정 경계 세션 중복 방지).',
    gs.USER_CNT AS COUNT(DISTINCT gs.USER_PSEUDO_ID)
      WITH SYNONYMS ('방문자수', '사용자수', '방문자(명)', '공94')
      COMMENT = '고유 방문자수(명 · 브라우저/기기 단위 pseudo id). 🔴 비가산.',
    gs.ENGAGED_SESSION_CNT AS COUNT(DISTINCT IFF(gs.ENGAGED_FLAG = 1, gs.BIGQUERY_SESSION_KEY, NULL))
      WITH SYNONYMS ('참여 세션수', '참여 방문수')
      COMMENT = 'GA4 참여 세션수(10초 이상·전환·2페이지 이상 · session_engaged=1). 🔴 비가산.',
    gs.PAGE_VIEW_SUM AS SUM(gs.PAGE_VIEW_CNT)
      WITH SYNONYMS ('페이지뷰', '조회수', '페이지뷰(회)', '공96')
      COMMENT = 'page_view 이벤트 수 합(회). F(가산).',
    gs.EVENT_SUM AS SUM(gs.EVENT_CNT)
      WITH SYNONYMS ('이벤트수', '이벤트(건)', '공95')
      COMMENT = '전체 이벤트 수 합(건). F(가산).',
    gs.AVG_SESSION_ENGAGEMENT_SEC AS SUM(gs.ENGAGEMENT_TIME_MSEC) / 1000 / NULLIF(COUNT(DISTINCT gs.BIGQUERY_SESSION_KEY), 0)
      WITH SYNONYMS ('평균세션시간', 'GA 평균세션시간', '세션당 평균 참여시간', '공98', '평균세션시간(추천안A)', '공98A')
      COMMENT = '공#98 GA 평균세션시간(초) 잠정 = 참여시간 합(engagement_time_msec ÷ 1,000) ÷ 고유 세션수. GA4 「세션당 평균 참여시간」 정의다(UA 세션 지속시간과 다르다 — 답변에 밝힌다). 참여시간 미수집 세션은 0초로 분모에 남는다. 비율(N · 재집계 금지). O240 신설. 🆕 [O241] 추천안A — 추천안B(AVG_SESSION_DURATION_SEC)와 병기한다.',
    --  [2026-10-16 O241] 공98 추천안B(잠정) — UA식 세션 지속시간
    gs.AVG_SESSION_DURATION_SEC AS SUM(gs.SESSION_DURATION_SEC) / NULLIF(COUNT(DISTINCT gs.BIGQUERY_SESSION_KEY), 0)
      WITH SYNONYMS ('평균세션시간(추천안B)', 'UA 세션 지속시간', '세션 지속시간', '공98B')
      COMMENT = '공#98 추천안B(잠정) 평균세션시간(초) = 세션 지속시간(마지막 − 첫 이벤트 시각) 합 ÷ 고유 세션수. UA 「평균 세션 시간」 근사다. 한계: 이벤트 1건뿐인 세션은 0초 · 자정을 넘는 세션은 첫 일자 행에만 지속시간이 실린다(월 경계 세션은 다음 달 분모에 0초로 남을 수 있다). 비율(N · 재집계 금지).',
    gs.BOUNCE_RATE AS (1 - COUNT(DISTINCT IFF(gs.ENGAGED_FLAG = 1, gs.BIGQUERY_SESSION_KEY, NULL)) / NULLIF(COUNT(DISTINCT gs.BIGQUERY_SESSION_KEY), 0)) * 100
      WITH SYNONYMS ('이탈율', 'GA 이탈율', '이탈률', '공108')
      COMMENT = '공#108 GA 이탈율(%) = (1 − 참여 세션 ÷ 전체 세션) × 100. GA4 bounce rate 정의(참여하지 않은 세션 비율). 비율(N · 재집계 금지). 🔴 FACT_BIGQUERY_BEHAVIOR.BOUNCE_RATE 컬럼은 전건 NULL 이라 쓰지 않는다. O240 신설.'
  )
  COMMENT = 'GA4 세션 SV. 「회원유형·후원자유형·후원사업유형·국가·기기·브라우저·사이트·유입채널별 방문(세션)·방문자·페이지뷰」 질문에 쓴다. 🔴 페이지 경로·이벤트 분류 질문은 SV_GA_BEHAVIOR 소관(다른 grain · 합산 금지). 🔴 인구통계(성별·연령)는 SV_GA_DEMOGRAPHIC · 구글 검색어·노출은 SV_SEARCH_CONSOLE 소관. 제외 축: EP_GAD_SOURCE(라벨 없는 숫자 코드).'
  AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] (가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 `__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. (나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 (CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). (다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.
  [O241-R 반올림 · 전 SV 공통] 최종 SELECT 에서 비율(%)·평균·확률·초·기여도 등 소수 값은 ROUND(<식>, 2)::NUMBER(38,2) 로 반올림해 출력한다(FLOAT 그대로 두면 0.98999… 처럼 보이므로 NUMBER 로 캐스팅한다 · 집계 식 바깥에 씌우며 정렬·필터에는 원래 식을 쓴다). 금액·건수·명수는 숫자형 그대로 둔다(문자열로 바꾸지 않는다 — 쉼표는 답변 작성 단계에서 붙인다). [O206 출력 규칙 · 전 SV 공통] 최종 SELECT 의 모든 출력 컬럼에 큰따옴표 한글 별칭을 붙인다 — 형식 = <식> AS "한글명". 한글명은 그 차원·지표의 WITH SYNONYMS 첫 항목을 쓰고, 단위가 COMMENT 에 있으면 괄호로 붙인다(예: "세션수(회)" · "방문자수(명)"). 영문 식별자를 출력 컬럼명으로 남기지 않는다. 따옴표 없는 한글 별칭은 문법 오류이므로 반드시 큰따옴표로 감싼다. [O206-C 합계 규칙] 답변에 쓸 합계·총계는 반드시 SQL 이 낸다 — 그룹별 결과와 함께 GROUP BY ROLLUP 합계 행을 반환한다(고유 세션·방문자수 합계는 ROLLUP 이 다시 세므로 그룹 합과 다를 수 있다 — 그 차이를 밝힌다).
  핵심 규칙: (1) 기간 미지정 시 데이터에 존재하는 최신 월 하나로 한정하고 밝힌다. (2) 세션·방문자수는 일자별 값을 더하지 않는다. (3) NULL 값은 「값 없음(해당 없음)」으로 밝히고 다른 값으로 합치지 않는다. (4) 「{{…}}」 형태 값은 GTM 미치환 수집 오류로 밝힌다. (5) 회원 단위 후원 실적은 이 SV 가 아니라 CRM SV 소관이다.
  🆕 [O241 추천안 A/B 병기] (6) 「평균세션시간」(공98) 질문은 추천안 A·B 두 값을 한 SELECT 로 낸다 — A = AVG_SESSION_ENGAGEMENT_SEC 식(참여시간 합 ÷ 1,000 ÷ 고유 세션수 · GA4 세션당 평균 참여시간) · B = AVG_SESSION_DURATION_SEC 식(SESSION_DURATION_SEC 합 ÷ 고유 세션수 · UA식 세션 지속시간). 각 값 아래 정의를 1줄씩 쓰고 「현업 결정 전 잠정 · 두 안 병기」를 밝힌다. 한쪽만 물으면(「추천안B」·「UA 세션 지속시간」) 그 값만 낸다.'
  AI_VERIFIED_QUERIES (
    vqr_o241_avg_session_ab AS (
      QUESTION '2026년 월별 GA 평균세션시간 추천안 A·B'
      VERIFIED_BY '(O241 · 2026-09 기대 A ≈ 31.87초 · B ≈ 90.27초 · 원천 BIGQUERY_REFINED_DATA 직접식)'
      SQL 'SELECT date.MONTH AS "월", SUM(gs.ENGAGEMENT_TIME_MSEC) / 1000 / NULLIF(COUNT(DISTINCT gs.BIGQUERY_SESSION_KEY), 0) AS "평균세션시간(추천안A)(초)", SUM(gs.SESSION_DURATION_SEC) / NULLIF(COUNT(DISTINCT gs.BIGQUERY_SESSION_KEY), 0) AS "평균세션시간(추천안B)(초)" FROM gs JOIN date ON gs.DATE_SK = date.DATE_SK WHERE date.YEAR = 2026 GROUP BY date.MONTH ORDER BY 1'
    ),
    vqr_o213f_donor_type AS (
      QUESTION '2026년 9월 후원자유형별 홈페이지 방문 세션수'
      VERIFIED_BY '(O213-F · 팩트 직접 집계 대조 · 값 없음 52,503 · 개인 992 · 단체 29 · 기업 4)'
      SQL 'SELECT gs.UP_DONOR_TYPE AS "후원자유형", COUNT(DISTINCT gs.BIGQUERY_SESSION_KEY) AS "세션수(회)" FROM gs WHERE gs.DATE_SK BETWEEN 20260901 AND 20260930 GROUP BY ROLLUP(gs.UP_DONOR_TYPE) ORDER BY 2 DESC'
    )
  );

GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_SESSION TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_SESSION TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_GA_SESSION TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크 — SV 고유 세션수 = 팩트 고유 세션키 수
SELECT (SELECT SESSION_CNT FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_GA_SESSION METRICS gs.SESSION_CNT)) AS sv_val,
       (SELECT COUNT(DISTINCT BIGQUERY_SESSION_KEY) FROM GN_DW.GOLD.FACT_BIGQUERY_SESSION)         AS fact_val,
       (SELECT COUNT(DISTINCT BIGQUERY_SESSION_KEY) FROM GN_DW.SILVER.BIGQUERY_SESSION)            AS silver_val;
