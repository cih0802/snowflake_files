-- ============================================================================
-- 05_7_SV_DDL_AD.sql — Semantic View DDL 정본: SV_AD
--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).
--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.
--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

use role gn_dw_admin;
CREATE OR ALTER SEMANTIC VIEW GN_DW.SERVING.SV_AD
  TABLES (
    ad AS GN_DW.GOLD.WIDE_AD_COMBINED
      PRIMARY KEY (AD_PERF_DK)
      WITH SYNONYMS ('광고 실적', '광고 성과', '매체 실적')
      COMMENT = '온-오프라인 광고 성과 통합 분석 (base: GOLD.WIDE_AD_COMBINED). [Grain: 집행일 × 캠페인 × 소재 × 디바이스]. [활성 지표: 광고비/노출/클릭/전환/CTR/CVR/CPC/CPM/ROAS]. [주의: _SRC 접미 비율 지표 단순 재합산 금지]. [원천: AGENCY 3소스 + GA4 → SILVER.AGENCY_AD_* → GOLD.WIDE_AD_COMBINED].',
    device AS GN_DW.GOLD.DIM_DEVICE
      PRIMARY KEY (DEVICE_SK)
      WITH SYNONYMS ('기기', '디바이스', '매체기기')
      COMMENT = '기기(디바이스) 차원. [원천] 시스템=GA4(BigQuery→Snowflake) · BRONZE=GN_DW.BRONZE_BIGQUERY.EVENTS(device.category) · SILVER=GA4_DEVICE. 방송 행은 기기 개념이 없어 (해당없음).',
    mktg AS GN_DW.GOLD.DIM_MARKETING_CAMPAIGN
      PRIMARY KEY (MKTG_CAMPAIGN_SK)
      WITH SYNONYMS ('마케팅캠페인', '캠페인')
      COMMENT = '마케팅캠페인 conformed 차원 — 광고(대행사) ↔ 개발실적(CRM)을 잇는 **유일한 결합축**이다(O45). PK 유일이라 조인이 행수를 늘리지 않는다(실측: FAP 조인 후 행수 불변). 🔴 개발캠페인(DIM_CAMPAIGN) grain 으로 내려가면 광고비가 복제된다 — 결합은 이 grain 에서만 한다. [원천] 시스템=CRM(eCRM) 마스터 + 대행사 리포트의 캠페인명 이름매칭 · BRONZE=GN_DW.BRONZE_CRM: TM_CM_MKTNG_CMPGN_MNG · SILVER=CRM_MARKETING_CAMPAIGN.',
    date AS GN_DW.GOLD.DIM_DATE
      PRIMARY KEY (DATE_SK)
      WITH SYNONYMS ('날짜', '실적일')
      COMMENT = '일 차원. [원천] ETL 생성(달력) — 업무 원천 시스템 없음.'
  )
  RELATIONSHIPS (
    ad_to_date   AS ad (PERF_DATE_SK) REFERENCES date (DATE_SK),
    ad_to_device AS ad (DEVICE_SK)    REFERENCES device,
    ad_to_mktg   AS ad (MKTG_CAMPAIGN_SK) REFERENCES mktg
  )
  DIMENSIONS (
    mktg.MARKETING_CAMPAIGN AS mktg.MKTG_CAMPAIGN_NAME
      WITH SYNONYMS ('마케팅캠페인', '마케팅 캠페인명', '캠페인', '캠페인명')
      COMMENT = '마케팅캠페인명 — 광고와 CRM 개발실적을 잇는 **유일한 결합축**이다(O45). 🔴 광고행 전체가 이 축에 도달하지는 않는다 — 미도달분은 ''(미매핑)'' 한 덩어리이므로 **이 축으로 그루핑한 광고비 합계는 전체 광고비보다 작다**. 총계를 물으면 축 없이 답하고, 캠페인별로 물으면 미매핑 버킷의 존재를 함께 밝힌다. ⚠️ **개발캠페인(개별 캠페인명)별 분해는 여전히 불가**하다 — 한 마케팅캠페인에 개발캠페인이 다수 매달려 있어 광고비를 내리면 그 배수로 복제된다(현업 배분 규칙 필요). ⚠️ **소재(광고 소재)별 분해도 불가**하다(소재 연결키 부재 · Q10)',
    mktg.DEV_CAMPAIGN_CNT   AS mktg.DEV_CAMPAIGN_CNT
      WITH SYNONYMS ('개발캠페인 수', '팬아웃 배수')
      COMMENT = '🔴**팬아웃 경고축**: 이 마케팅캠페인에 매달린 개발캠페인 수. 1 보다 크면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다 — 이 값을 근거로 「개발캠페인별 ROI 는 배분 규칙 없이는 불가」라고 답한다',
    date.PERF_DATE    AS date.FULL_DATE  WITH SYNONYMS ('실적일', '광고일', '일자', '날짜') COMMENT = '광고 실적 발생일',
    date.FULL_DATE AS date.FULL_DATE  COMMENT = '달력 날짜(DIM_DATE.FULL_DATE) — PERF_DATE 와 같은 값이다(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.CAL_YEAR     AS date.YEAR       WITH SYNONYMS ('연도', '년')   COMMENT = '연도',
    date.CAL_MONTH    AS date.MONTH      WITH SYNONYMS ('월')          COMMENT = '월(1~12)',
    date.YEAR AS date.YEAR    COMMENT = '연도(DIM_DATE.YEAR) — CAL_YEAR 와 같은 값(Analyst 가 추측하는 식별자를 실재화). 둘 중 하나만 쓴다.',
    date.MONTH AS date.MONTH  COMMENT = '월(DIM_DATE.MONTH) — CAL_MONTH 와 같은 값(추측 식별자 실재화). 둘 중 하나만 쓴다.',
    date.CAL_QUARTER  AS date.QUARTER    WITH SYNONYMS ('분기')        COMMENT = '분기(1~4)',
    ad.AD_SOURCE_TYPE AS ad.AD_SOURCE_TYPE WITH SYNONYMS ('출처유형', '광고출처', '매체구분') COMMENT = '광고 출처유형. 코드값: ''DIGITAL'' · ''VIDEO''(방송 본방) · ''REBROADCAST''(재방송). 디지털/방송 measure 필터 필수. 실제값 3종: ''VIDEO''·''DIGITAL''·''REBROADCAST''',
    ad.DAY_OF_WEEK    AS ad.DAY_OF_WEEK    WITH SYNONYMS ('요일')   COMMENT = '요일. 실제값 7종: ''Fri''·''Mon''·''Sat''·''Sun''·''Thu''·''Tue''·''Wed''',
    ad.WEEK_OF_YEAR   AS ad.WEEK_OF_YEAR   WITH SYNONYMS ('주차')   COMMENT = '연중 주차',
    device.DEVICE_TYPE       AS device.DEVICE_TYPE       WITH SYNONYMS ('기기유형', '디바이스유형', '모바일', 'PC') COMMENT = '기기 유형. 실제 코드값: ''M''=모바일(GA4 mobile/tablet 통합) · ''PC''=데스크톱 · ''(해당없음)''=방송광고(기기 개념 없음) · ''(unknown)''=매핑 실패 센티넬. ⚠필터 시 ''MOBILE''/''TABLET'' 아님 — 모바일은 ''M''.',
    device.DEVICE_SCOPE_DESC AS device.DEVICE_SCOPE_DESC WITH SYNONYMS ('기기범위') COMMENT = '기기 범위 설명(예: 모바일(GA4 device.category=mobile/tablet)).',
    ad.AD_TYPE_NM     AS ad.AD_TYPE_NM     WITH SYNONYMS ('광고유형', '광고타입') COMMENT = '디지털 광고유형(검색/디스플레이 등). AD_SOURCE_TYPE=DIGITAL 전용. 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다).',
    ad.CREATIVE_TYPE  AS ad.CREATIVE_TYPE  WITH SYNONYMS ('소재유형', '크리에이티브유형') COMMENT = '크리에이티브 유형. 디지털 전용. 원천에 일부 행만 채워져 있어 부분집합이다. 실제값 5종: ''기타''·''영상''·''이미지''·''키워드''·''해당없음'' + NULL. ⚠️ ''해당없음''은 원천이 넣은 값이며 NULL 과 다르다(합치지 않는다 실측 정정 · 종전 4종)',
    ad.PAGE_TYPE      AS ad.PAGE_TYPE      WITH SYNONYMS ('페이지유형', '랜딩유형') COMMENT = '랜딩 페이지 유형. 디지털 전용. 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다). ⚠️ ''전체'' 값이 섞여 있고 **그 의미(랜딩 유형인지 대행사 리포트의 묶음 표기인지)는 원천 확인 전**이다 — 유형별 분해에 쓰되 그 사실을 밝히고, 의미를 추측해 설명하지 말 것. 🟢 집계행(총계 중복)은 아니다 — 광고비 합계가 전체와 겹치지 않음을 실측 확인했다',
    ad.AD_GROUP_NM    AS ad.AD_GROUP_NM    WITH SYNONYMS ('광고그룹', '그룹명') COMMENT = '광고 그룹명. 디지털 전용. 고카디널리티이며 원천 재적재로 값이 바뀐다 ⇒ 값 목록은 이 컬럼을 SELECT DISTINCT 로 조회한다(열거를 여기 박지 않는다).',
    ad.CHANNEL_COMPANY AS ad.CHANNEL_COMPANY WITH SYNONYMS ('채널사', '방송사', '매체사') COMMENT = '방송 채널사. VIDEO/REBROADCAST 전용. ⚠광고비 기준 정렬 시 광고비가 없는 채널사가 섞이므로 NULLS LAST 를 명시할 것.',
    ad.TIME_BAND       AS ad.TIME_BAND       WITH SYNONYMS ('시간대', '광고시간대') COMMENT = '방송 시간대. 방송 전용. ⚠️ 표기 형식이 원천마다 다르다 — VIDEO 는 ''N시대'' 구간 라벨, REBROADCAST 는 ''HH:MM:SS'' 시각이다(원천 재편) ⇒ 두 출처를 섞어 이 축으로 그루핑하지 말고 AD_SOURCE_TYPE 으로 먼저 나눈다.',
    ad.PROGRAM_NM      AS ad.PROGRAM_NM      WITH SYNONYMS ('프로그램', '프로그램명', '방송프로그램') COMMENT = '방송 프로그램명(고카디널리티 — Cortex Search 백킹 후보). 방송 전용.',
    ad.SPOT_TYPE       AS ad.SPOT_TYPE       WITH SYNONYMS ('스팟유형', '광고위치') COMMENT = '스팟 유형(전CM/중CM/후CM/SB). 방송 전용. 실제값 4종: ''CA''·''PR''·''SP''·''TJ'' + NULL',
    ad.CM_POSITION     AS ad.CM_POSITION     WITH SYNONYMS ('CM위치', '광고순서') COMMENT = 'CM 내 위치. 방송 전용. 실제값 16종: ''`''(🔴 **오염값** — 백틱 1문자이며 정상 CM 위치가 아니다. 이 값으로 필터하지 말 것 · 규모·경위는 이슈원장 참조)·''E-1st''·''E-2nd''·''E-3rd''·''E-4th''·''E-5th''·''E-6th''·''E-7th''·''T-1st''·''T-2nd''·''T-3rd''·''T-4th''·''T-5th''·''T-6th''·''T-7th''·''middle'' + NULL',
    ad.RT_TYPE         AS ad.RT_TYPE         WITH SYNONYMS ('재방유형', '방송유형구분') COMMENT = '본방/재방 유형. REBROADCAST 전용(VIDEO 는 전건 NULL). 실제값 2종: ''재송출''·''방송'' + NULL',
    ad.DURATION_SEC    AS ad.DURATION_SEC    WITH SYNONYMS ('초수', '광고초수', '영상초수', '광고길이', '초') COMMENT = '방송 광고 영상 초수(초 단위, 요구사항 #22). 방송(VIDEO/REBROADCAST) 전용. 실제값: 15·20·30·60 등 + NULL.'
  )
  METRICS (
    ad.TOTAL_AD_COST   AS SUM(ad.AD_COST)
      WITH SYNONYMS ('광고비', '광고비 총액', '매체비') COMMENT = '광고비 합계(원). F(가산). 디지털+방송 합산 가능.',
    ad.TOTAL_IMPRESSIONS AS SUM(ad.IMPRESSIONS)
      WITH SYNONYMS ('노출수', '노출', '임프레션') COMMENT = '노출수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_CLICKS AS SUM(ad.CLICKS)
      WITH SYNONYMS ('클릭수', '클릭') COMMENT = '클릭수 합계. F(가산). 디지털 전용(방송은 NULL).',
    ad.TOTAL_INBOUND_CALL AS SUM(ad.INBOUND_CALL)
      WITH SYNONYMS ('인바운드콜', '전화문의', '콜수') COMMENT = '인바운드 전화 건수 합계. F(가산). 방송 전용(디지털은 NULL) — VIDEO·REBROADCAST 모두 존재.',
    ad.TOTAL_AGENCY_CONV_MEMBERS AS SUM(ad.AGENCY_CONV_MEMBERS)
      WITH SYNONYMS ('대행사전환회원', '전환회원수', '대행사전환') COMMENT = '대행사 전환 회원수 합계. F(가산). 디지털 전용.',
    ad.CTR AS SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100
      WITH SYNONYMS ('클릭률', 'CTR') COMMENT = '공9 CTR(%) = 클릭수 ÷ 노출수 ×100. 비율(N). 디지털 전용.',
    ad.CVR AS SUM(ad.AGENCY_CONV_MEMBERS) / NULLIF(SUM(ad.CLICKS), 0) * 100
      WITH SYNONYMS ('전환율', 'CVR') COMMENT = '공10 CVR(%) = 대행사전환회원 ÷ 클릭수 ×100. 비율(N). 디지털 전용.',
    ad.TOTAL_CRM_DEV_CNT AS SUM(ad.CRM_DEV_CNT)
      WITH SYNONYMS ('CRM개발건', 'CRM 개발건수', '디지털개발건') COMMENT = 'CRM 개발건수 합계(디지털). F(가산). ⚠원천에 비정수(소수) 값이 섞여 있어 기여도 배분값일 가능성이 있다 → "건수"로 정수 단정 금지(어의 미확정, 03 §8.5 §6-H). ⚠원천이 개발건수 제공을 중단하고 단가를 직접 제공하는 포맷으로 바뀐 시점 이후는 미적재다 — 적재 구간은 데이터에서 확인할 것(03 §8.5.1).',
    ad.DEV_UNIT_PRICE AS SUM(CASE WHEN ad.CRM_DEV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.CRM_DEV_CNT), 0)
      WITH SYNONYMS ('개발단가', 'CPA', '건당 광고비') COMMENT = '공7 디지털 개발단가(원) = 광고비 ÷ CRM개발건. 비율(N). DIGITAL 전용. 분자를 개발건수 적재행으로 정합(미적재행 광고비 제외). ⚠원천 포맷 변경 이후 구간은 개발건수가 없어 산출 불가(NULL) — 산출 가능한 최신 구간은 데이터에서 확인할 것.',
    ad.GA_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.AGENCY_CONV_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.AGENCY_CONV_CNT), 0)
      WITH SYNONYMS ('GA 개발단가', 'GA CPA', 'GA 건당 광고비', '공8') COMMENT = '공8 GA 개발단가(원) = GA 광고비 ÷ GA 개발(건). 분모 = 대행사 리포트의 GA 전환(건). 비율(N). DIGITAL 전용(방송은 분모가 없어 NULL). 분자를 분모 적재행으로 정합. ⚠소수 전환값을 반올림하지 않는다. ⚠GA4 이벤트(BigQuery) 기반 후원건과는 규모가 다르다 — 이 지표의 분모는 대행사 보고값이다.',
    ad.TOTAL_READ_CNT AS SUM(ad.READ_CNT)
      WITH SYNONYMS ('조회수', '열람수', '읽기수') COMMENT = '콘텐츠 조회수 합계(디지털). F(가산).',
    ad.TOTAL_MEDIA_POTENTIAL AS SUM(ad.MEDIA_POTENTIAL_CUST_CNT)
      WITH SYNONYMS ('매체잠재고객수', '잠재고객') COMMENT = '매체 잠재고객수 합계(디지털). F(가산).',
    ad.TOTAL_AD_CNT AS SUM(ad.AD_CNT)
      WITH SYNONYMS ('방송횟수', '광고집행횟수', '편성횟수') COMMENT = '방송 광고 집행 횟수 합계. F(가산). VIDEO/REBROADCAST 전용.',
    ad.TOTAL_DVLP_CNT AS SUM(ad.DVLP_CNT)
      WITH SYNONYMS ('재방송개발건', '방송개발건', '방송 개발회원건수') COMMENT = '방송 개발건수 합계(대행사 보고). F(가산). VIDEO·REBROADCAST 전용(디지털은 NULL). 🔴 종전 「VIDEO 원천에 개발 컬럼이 구조적으로 부재」는 **원천 재편으로 거짓이 됐다** — VIDEO 도 개발건을 보고한다(일부 행만 채워짐 · 미보고 행은 NULL). ⚠️ 두 대행사 리포트의 개발 정의가 같은지는 원천 확인 전이다 ⇒ 합계를 물으면 AD_SOURCE_TYPE 별로 나눠 함께 보여준다.',
    ad.TOTAL_DVLP_MEMBER_CNT AS SUM(ad.DVLP_MEMBER_CNT)
      WITH SYNONYMS ('재방송개발회원', '방송개발회원', '방송 개발회원수') COMMENT = '방송 개발회원수 합계(대행사 보고). F(가산). VIDEO·REBROADCAST 전용 — VIDEO 는 일부 행만 채워짐(정정: 종전 「VIDEO 컬럼 부재」 철회).',
    ad.REBRDC_DEV_UNIT_PRICE AS SUM(CASE WHEN ad.DVLP_CNT IS NOT NULL THEN ad.AD_COST END) / NULLIF(SUM(ad.DVLP_CNT), 0)
      WITH SYNONYMS ('재방송 개발단가', '재방송 CPA', '재방송 건당 광고비') COMMENT = '재방송 개발단가(원) — 참고 지표(공8 아님 · 공8 은 GA_DEV_UNIT_PRICE) = 재방송 광고비 ÷ 재방송 개발건. 비율(N). **REBROADCAST 전용**(방송 전체 단가가 아님 · VIDEO 단가는 이 metric 의 범위 밖). 분자를 개발건수 적재행으로 정합. ⚠`AD_SOURCE_TYPE=''REBROADCAST''` 필터 전제 — VIDEO 혼합 시 과대계상된다.'
  )
  COMMENT = 'Phase-1 광고 실적 SV (base: GOLD.WIDE_AD_COMBINED). 대행사(디지털/방송) 일별 리포트 및 GA4 기반 광고비, 노출, 클릭, 전환, 방송실적 통합 뷰. ⚠️ 디지털/방송 measure는 상호배타적이며, 광고비만 전체 합산 가능. 마케팅캠페인(MKTG_CAMPAIGN_NAME) 축으로 분해 가능(소재별/개별캠페인별 분해 불가). 예산(SV_BUDGET) 및 회원개발실적(SV_MEMBER_EVENT)과의 교차 집계는 불가.'
  AI_SQL_GENERATION '핵심 규칙: (1) 출처 필터: 노출·클릭·CTR·CVR·CRM개발건·개발단가(공7)·조회수·잠재고객 질의는 AD_SOURCE_TYPE=''DIGITAL'' 자동 추가. 인바운드콜·방송횟수·방송 개발건수·방송 개발회원수는 AD_SOURCE_TYPE IN (''VIDEO'',''REBROADCAST'') 추가하고 개발건수는 출처별로 나눠 반환. GA 개발단가(공8)는 AD_SOURCE_TYPE=''DIGITAL'' 추가. 재방송 개발단가(참고 · 공8 아님)는 AD_SOURCE_TYPE=''REBROADCAST'' 추가. 광고비만 전체 합산 허용. (2) 기간 미지정 시: 최신 데이터 연월 기준 직전 12개월로 한정하며 GROUP BY ROLLUP((연,월)) 반환. (3) 캠페인 분해: MARKETING_CAMPAIGN 축으로 그루핑하며 ''(미매핑)'' 버킷 존재로 캠페인별 합계 < 전체 합계임을 명시. 소재별 및 개별 개발캠페인별 ROI/단가는 생성 거부 및 사유 안내. (4) 기기 필터: 모바일은 DEVICE_TYPE=''M'', 데스크톱은 ''PC''. 방송은 ''(해당없음)''. (5) 정렬: 방송 차원 광고비 기준 정렬 시 ORDER BY ... DESC NULLS LAST 사용. (기준시점 규칙) 「최근 N주·N개월」·기간 미지정 질의의 기준 시점은 **비상관 CTE 1개**에서 그 CTE 의 FROM 에 쓴 이름으로만 MAX 를 구하고 본 쿼리에 CROSS JOIN 한다. 스칼라·상관 서브쿼리로 기준 시점을 구하지 않는다. 광고 성과일은 ad 에 없다 — date.FULL_DATE(ad.PERF_DATE_SK = date.DATE_SK 조인)로만 건다(ad.PERF_DATE 는 없다). metric 이름을 컬럼처럼 참조하지 말고 정의식으로 집계한다. ORDER BY 에는 SELECT 별칭을 글자 그대로 쓴다. (전년대비) 전년 대비는 월(또는 주) 집계 CTE 를 만든 뒤 **그 CTE 를 연도-1 로 자기조인**한다(LAG 는 빠진 월이 있으면 어긋난다). 디지털 광고는 2024-01 부터 적재돼 있으므로 「전년 데이터 없음」으로 답하지 않는다. 광고와 개발실적의 전년 대비를 함께 물으면 이 SV(광고)와 SV_MEMBER_EVENT(개발)를 **각각 호출해 월 단위로 나란히** 보여주고, 한 SQL 로 조인하지 않는다(교차 집계 불가). (소속 테이블) 마케팅캠페인 축은 **mktg.MARKETING_CAMPAIGN** 이다 — ad 테이블에 없다(ad.MARKETING_CAMPAIGN 은 invalid identifier) ⇒ ad JOIN mktg ON ad.MKTG_CAMPAIGN_SK = mktg.MKTG_CAMPAIGN_SK 로 붙인다. 기기 축은 device.*, 날짜 축은 date.* 소속이다.'
  AI_VERIFIED_QUERIES (
    vqr_ad_cost_by_source AS (
      QUESTION '출처유형별 광고비 합계'
      VERIFIED_BY '(DW = O190)'
      SQL 'SELECT ad.AD_SOURCE_TYPE, SUM(ad.AD_COST) AS TOTAL_AD_COST FROM ad GROUP BY ad.AD_SOURCE_TYPE ORDER BY TOTAL_AD_COST DESC NULLS LAST'
    ),
    vqr_o191_digital_weekly_ctr AS (
      QUESTION '최근 8주 디지털 광고 주차별 노출·클릭·CTR'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH mx AS (SELECT MAX(date.FULL_DATE) AS md FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'') SELECT date.YEAR, ad.WEEK_OF_YEAR, SUM(ad.IMPRESSIONS) AS TOTAL_IMPRESSIONS, SUM(ad.CLICKS) AS TOTAL_CLICKS, SUM(ad.CLICKS) / NULLIF(SUM(ad.IMPRESSIONS), 0) * 100 AS CTR FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK CROSS JOIN mx WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'' AND date.FULL_DATE > DATEADD(WEEK, -8, mx.md) GROUP BY date.YEAR, ad.WEEK_OF_YEAR ORDER BY date.YEAR, ad.WEEK_OF_YEAR'
    ),
    vqr_o191_digital_monthly_yoy AS (
      QUESTION '디지털 광고 월별 노출·클릭·광고비 전년 동월 대비'
      VERIFIED_BY '(DW = O191)'
      SQL 'WITH m AS (SELECT date.YEAR AS YR, date.MONTH AS MN, SUM(ad.IMPRESSIONS) AS IMP, SUM(ad.CLICKS) AS CLK, SUM(ad.AD_COST) AS COST FROM ad JOIN date ON ad.PERF_DATE_SK = date.DATE_SK WHERE ad.AD_SOURCE_TYPE = ''DIGITAL'' GROUP BY date.YEAR, date.MONTH) SELECT c.YR, c.MN, c.IMP, p.IMP AS IMP_PREV_YEAR, c.CLK, p.CLK AS CLK_PREV_YEAR, c.COST, p.COST AS COST_PREV_YEAR, (c.CLK - p.CLK) / NULLIF(p.CLK, 0) * 100 AS CLK_YOY_PCT, (c.COST - p.COST) / NULLIF(p.COST, 0) * 100 AS COST_YOY_PCT FROM m c LEFT JOIN m p ON p.YR = c.YR - 1 AND p.MN = c.MN ORDER BY c.YR, c.MN'
    )
  );

-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_ANALYST;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_VIEWER;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW GN_DW.SERVING.SV_AD TO ROLE GN_DW_SERVICE;

USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)
SELECT (SELECT TOTAL_AD_COST FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_AD METRICS TOTAL_AD_COST)) AS sv_val,
       (SELECT SUM(AD_COST)  FROM GN_DW.GOLD.FACT_AD_PERFORMANCE)                           AS fact_val;

SELECT (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_PERFORMANCE) AS fap,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_DIGITAL)     AS dig,
       (SELECT COUNT(*) FROM GN_DW.GOLD.FACT_AD_BROADCAST)   AS brc,
       (SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_AD_COMBINED) AS combined;

SELECT CAL_YEAR, AD_SOURCE_TYPE, TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS date.CAL_YEAR, ad.AD_SOURCE_TYPE
  METRICS TOTAL_AD_COST, CTR, CVR, DEV_UNIT_PRICE
)
WHERE AD_SOURCE_TYPE = 'DIGITAL'
ORDER BY 1;

SELECT AD_SOURCE_TYPE, DEVICE_TYPE, TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.AD_SOURCE_TYPE, device.DEVICE_TYPE
  METRICS TOTAL_AD_COST, TOTAL_CLICKS, TOTAL_INBOUND_CALL, TOTAL_AD_CNT
)
ORDER BY 1, 2;

SELECT CHANNEL_COMPANY, TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
FROM SEMANTIC_VIEW(
  GN_DW.SERVING.SV_AD
  DIMENSIONS ad.CHANNEL_COMPANY
  METRICS TOTAL_AD_COST, TOTAL_INBOUND_CALL, TOTAL_AD_CNT, TOTAL_DVLP_CNT
)
WHERE CHANNEL_COMPANY IS NOT NULL
ORDER BY TOTAL_AD_COST DESC NULLS LAST
LIMIT 10;
