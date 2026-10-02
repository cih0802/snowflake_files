-- GN_DW.SILVER 정제 테이블 DDL — C 계정 재현용
-- 최근 갱신일 : 2026-10-02  (🆕 O198 예측용 집계 3종 추가 · 1→4테이블 · 초판 2026-08-20 · 2026-08-29 갱신 · 2026-09-15 원천 정의 소실 반영 · 2026-09-28 원천 복구 재대조)
--   ⚠️ 2026-09-15 · 2026-09-28 갱신은 **헤더 주석만**이다 — DDL 본문 118컬럼은 한 줄도 바뀌지 않았다.
-- 🟢 파일명에 날짜를 넣지 않는다(2026-09-15 사용자 결정 · 구 파일명 = *_20260820).
--    이유 = 갱신마다 개명하면 참조 문서(01·02·03·05·07번)와 게이트 경로를 매번 함께 고쳐야 하고,
--    한 곳이라도 놓치면 참조가 깨진다. **날짜는 파일 안에만 적는다.**
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   A 계정의 GN_DW.SILVER 이관 대상 **4테이블**(BIGQUERY_REFINED_DATA + 예측용 집계 3종 · 🆕 O198) 구조를 C 계정에 그대로 재현한다.
--   CSV 적재는 위치(순서) 기반이므로 적재 전에 반드시 이 DDL을 먼저 실행해야 한다.
--
-- 이관 경로 / TOPOLOGY
--   A ──(Direct Share · 동일 리전)──▶ B ──(로컬 다운로드)──▶ 로컬 ──(업로드)──▶ C (다른 리전)
--
-- 실행 계정 / 역할
--   C (Target), GN_DW_ADMIN
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md  → 5.1(DDL 재생성) / 5.5(SILVER 적재)
--   [출처]     50_handoff/02_데이터마이그 A_PRODUCER.sql 6.2
--              → SELECT GET_DDL('TABLE','GN_DW.SILVER.BIGQUERY_REFINED_DATA', TRUE);
--   [원천 정의] 90_provided_definition/18_silver_ddl.sql  (🆕 2026-10-02 재수령 · SILVER 스키마 전체 61테이블 · 이관은 4개만)
--   [구 원천명] 99_provided_definition/18_silver_bigquery_refined.sql
--              → 🔴 **2026-09-15 자로 이 파일은 SILVER 정의가 아니다.** 내용이
--                 16_bronze_gsc_ddl.sql(BRONZE_GSC DDL)과 **바이트 동일**로 교체되었다.
--                 ⇒ 99_provided_definition/*.sql 전건에 BIGQUERY_REFINED_DATA 가 **0건**이다
--                    ⇒ 본 파일은 대조할 원천을 잃었다. **DDL 본문은 손대지 않았다**
--                      (2026-08-29 대조 시점의 「차이 0」이 마지막 유효 판정이다).
--                 🔴 게이트는 이제 SILVER 축1 을 「인수인계에만 있다」로 1건 낸다 — 이것은
--                    본 파일의 결함이 아니라 **원천 문서 소실의 신호**다. 파일을 고쳐 없애지 마라.
--                 ⇒ 조치 = 현업에 18번(SILVER 정의) 재공유 요청. 받으면 다시 기계 대조한다.
--              → 2026-08-29 기계 대조 결과 본 파일과 차이 0(컬럼명·순서·타입·COMMENT 전건 일치).
--                 ⚠️ 이 판정은 **교체 이전 판본** 기준이다.
--   [형제 DDL] 50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql (브론즈 5스키마 64테이블)
--              50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql     (ML 예측결과 12종 · O198)
--              ⚠️ 세 파일을 모두 실행해야 이관 대상 80 테이블(브론즈 64 + SILVER 4 + ML 12)이 완성된다. 선후 관계는 없다.
--              🟢 [2026-09-15] 01·02·02_1·03·05·07번의 「브론즈 52 · 총계 69」 표기를 60/77 로  (🔴 2026-09-17 재갱신 = 브론즈 61 · 총계 78 · 🔴 2026-09-28 재갱신 = 브론즈 64 · ML 17 · 총계 82 · 🔴 2026-10-02 현행 = 브론즈 64 · SILVER 4 · ML 12 · 총계 80)
--                 일괄 정정했다(2세대 stale 해소). 판정 재현 = python3 scripts/handoff_ddl_gate.py 축7.
--   [후속]     50_handoff/07_데이터마이그 C_CONSUMER.sql  A.5 (이 테이블 적재)
--
-- 변경 이력 / CHANGES
--   2026-10-02  🆕 O198 · 사용자 지시 + 원천 18번 재수령(SILVER 스키마 전체 61테이블)
--     + [TABLE] ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA (17컬럼) · ANNUAL_MBRFEE_PRDT_ACTL_DATA (29컬럼) · MM_SPNSR_CLS_AGGR_DATA (8컬럼)
--        · 원천 무변경 발췌 · 반정형 없음 ⇒ 07번 TRY_PARSE_JSON 대상 아님 · 02번 2.1 에서 share 부여.
--     · BIGQUERY_REFINED_DATA 118컬럼 = 재수령 원천과 6축 차이 0 · DDL 본문 무변경.
--     · 게이트 범위 = `handoff_ddl_gate.SILVER_SCOPE`(4) — 원천의 나머지 57테이블은 이관 대상 아님.
--   2026-09-28
--     🟢 원천 18번이 SILVER 정의로 **복구**되었다 — 게이트 SILVER 6축 **차이 0**(본 파일 118컬럼과 전건 일치).
--        ⇒ 위 「원천 정의 소실」 경고(2026-09-15)는 **해소**되었다. DDL 본문은 이번에도 손대지 않았다.
--     · 형제 문서 수치 갱신: 04번 = 브론즈 **64테이블**(CRM 53) · 05번 = ML **17종** · 총계 78 → **82**. (⚠️ 2026-10-02 현행 = ML 12 · SILVER 4 · 총계 80)
--   2026-09-15
--     🔴 원천 정의 문서(18번) 소실 — 내용이 16번(BRONZE_GSC DDL)으로 교체되었다(바이트 동일).
--        ⇒ **DDL 본문 118컬럼은 한 줄도 고치지 않았다.** 고칠 근거(원천)가 없기 때문이다.
--        ⇒ 게이트 SILVER 축1 1건은 이 사실의 신호다(본 파일 결함이 아니다).
--     · 형제 문서 참조 정정: 04번 = 브론즈 5스키마 **60테이블** · 총계 **77**(종전 52/69 표기).
--     · 01·02·02_1·03·05·07번의 52/69 표기를 **일괄 정정**했다(2세대 stale 해소 · 게이트 축7 기준값도 갱신).
--     · 04·06번 파일명에서 날짜를 뗐다(사용자 결정) — 참조 문서 6곳 + 게이트 경로를 함께 고쳤다.
--   2026-08-29
--     · 원천 정의 문서(18번)와 기계 대조 — **구조 변경 0건**. DDL 본문은 손대지 않았다.
--     · 형제·후속 문서 참조 정정: 「04_2번」 → 본 파일이 **06번**이다 ·
--       「06번 C_CONSUMER」 → **07번** · 브론즈 50 → 52 · 총계 67 → 69 (⚠️ 2026-09-17 기준 61 / 78 → 2026-09-28 현행 64 / 82).
--     · 스테이지 실측 절 신설(아래).
--   2026-08-20  초판.
--
-- 스테이지 적재 실측 / STAGE STATE  (2026-08-29 · SANDBOX.TOOLS.MIG_LOAD_STAGE)
--   🔴 SILVER/ 하위 = **0건**. 이 테이블은 아직 언로드되지 않았다.
--        LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE/SILVER/;   -- 0 rows
--   ⚠️ 같은 시점에 BRONZE_CRM 업로드가 **진행 중**이었다(파일이 계속 증가) ⇒
--      「0건」은 「대상이 아니다」가 아니라 **「아직 오지 않았다」**로 읽는다.
--      적재 착수 직전에 다시 LIST 해서 실재를 확인한 뒤 07번 A.5 를 실행한다.
--   참고: 같은 시점 ML/ 하위는 16테이블/54파일로 완료 상태였다(05번 참조).
--
-- 본 파일의 범위 / SCOPE
--   GN_DW.SILVER — **4 테이블** (🆕 O198)
--     1 BIGQUERY_REFINED_DATA (118) · 2 ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA (17) · 3 ANNUAL_MBRFEE_PRDT_ACTL_DATA (29) · 4 MM_SPNSR_CLS_AGGR_DATA (8)
--   ⚠️ A 는 SILVER 스키마 중 이 4개만 공유한다(02번 2.1). 다른 SILVER 테이블(원천 18번의 나머지 57)은 대상이 아니다.
--   ⚠️ C 의 dbt SILVER 모델과 테이블명 충돌 0(2026-10-02 실측) — 단 dbt 가 모르는 객체이므로 스키마 재생성 시 유실된다.
--
-- 구조 요약 / STRUCTURE
--   컬럼 수 : 118
--   반정형  : 118번째 ITEMS (ARRAY) — 이 1개뿐이다.
--             → CSV 왕복 시 JSON 문자열로 들어가므로 적재 시 TRY_PARSE_JSON($118) 필수.
--                (07번 A.5 참조. 이 위치가 어긋나면 전량 오적재된다.)
--   접두어 규칙 : EP_=event_params · UP_=user_properties · CTS_=collected_traffic_source
--                 STSLC_=session_traffic_source_last_click · TS_=traffic_source
--                 ECOMMERCE_=ecommerce · DEVICE_/GEO_=device/geo 평탄화
--   ⇒ event_params / user_properties 등의 평탄화가 A 원천에서 이미 끝나 있다.
--
-- 🟠 컬럼 COMMENT 공백 9건 / UNDOCUMENTED COLUMNS  (2026-08-29 게이트 실측 · 현업 확인 대상)
--   118컬럼 중 **9컬럼이 원천(18번)·본 파일 양쪽 모두 COMMENT 가 없다.**
--   ⇒ 이관 무결성 위반은 아니다(양쪽이 동일하다). **문서화 공백**이며 A 원천에서 물려받은 것이다.
--   대상 — 전부 STSLC_(session_traffic_source_last_click) 계열이다:
--     · STSLC_CRC_CAMPAIGN_NAME          · STSLC_CRC_DEFAULT_CHANNEL_GROUP
--     · STSLC_CRC_PRIMARY_CHANNEL_GROUP  · STSLC_CRC_SOURCE_PLATFORM
--     · STSLC_GAC_AD_GROUP_ID            · STSLC_GAC_AD_GROUP_NAME
--     · STSLC_GAC_CAMPAIGN_NAME          · STSLC_MC_CAMPAIGN_NAME
--     · STSLC_MC_SOURCE_PLATFORM
--   🔴 임의로 문안을 창작해 채우지 않았다 — 같은 계열의 다른 컬럼(CRC_/GAC_/MC_ 접두)에는
--      COMMENT 가 있어서 「빠진 것」인지 「의미가 확정되지 않은 것」인지 구별되지 않는다.
--      원천 소관자 확인 후 채운다. 채울 때는 **원천(18번)을 먼저 고치고** 본 파일에 옮긴다
--      (본 파일만 채우면 게이트 축5 가 「COMMENT 변형」으로 잡는다).
--   판정 재현 = python3 scripts/handoff_ddl_gate.py  (SILVER 대상 · 🟠 경고 9건)
--
-- 🟢 구조 검증은 기계로 한다 / VERIFICATION
--   python3 scripts/handoff_ddl_gate.py
--     → 원천 18번과 6축(테이블집합·컬럼순서·타입·DEFAULT·컬럼COMMENT·테이블COMMENT) 대조.
--     2026-08-29 결과 = **판정 축 0건**(무변경 이관 성립) · 🟠 경고 9건(위 절).
--   🔴 손으로 118컬럼을 눈으로 대조하지 마라 — O113 이 그 방식의 임시 도구로
--      「차이 0」을 냈을 때 실제로는 COMMENT·DEFAULT 축을 아예 보지 않고 있었다.
--
-- ⚠️ 주의
--   - 이 SILVER 는 **A 계정 원천의 정제 계층**이다.
--     04_silver_design/08_SILVER_테이블DDL_20260714.sql 의 SILVER(38테이블, C 자체 변환 설계)와는
--     별개의 산출물이며 **같은 GN_DW.SILVER 스키마명**을 쓴다.
--     · 현재 BIGQUERY_REFINED_DATA 는 그 38테이블 목록에 없어 테이블명 직접 충돌은 없다.
--     · 다만 GN_DW.SILVER 는 dbt(10_dbt_pipeline/models/silver/**)가 소유하는 스키마다.
--       이 테이블은 dbt 가 모르는 객체로 남으므로 lineage 에 잡히지 않는다.
--       스키마 단위 재생성(CREATE OR REPLACE SCHEMA)을 하면 유실되므로 주의한다.
--   - 컬럼 수/순서가 A 원천과 다르면 CSV 적재가 전량 실패하거나 한 칸씩 밀려 오적재된다.
--     이관 직전 02번 6.2 의 GET_DDL 결과와 이 파일을 반드시 대조하고,
--     07번 A.1 (4)(CSV 헤더 ↔ 테이블 구조 대조)가 0건인 것을 확인한 뒤 적재한다.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
CREATE DATABASE IF NOT EXISTS GN_DW;

USE ROLE GN_DW_ADMIN;
CREATE SCHEMA   IF NOT EXISTS GN_DW.SILVER
  COMMENT = '정제 계층 - A 원천 SILVER 이관분 (BigQuery/CRM 통합)';

-- ---------------------------------------------------------------------
-- TABLE 1/4 : GN_DW.SILVER.BIGQUERY_REFINED_DATA  (118 컬럼, ITEMS=ARRAY)
-- ---------------------------------------------------------------------
create or replace TABLE GN_DW.SILVER.BIGQUERY_REFINED_DATA (
	BATCH_EVENT_INDEX NUMBER(38,0) COMMENT '배치 내 이벤트 순번',
	EVENT_DATE VARCHAR(16777216) COMMENT '이벤트 발생일',
	EVENT_TIMESTAMP NUMBER(38,0) COMMENT '이벤트 발생 시각',
	EVENT_NAME VARCHAR(16777216) COMMENT '이벤트명',
	EVENT_VALUE_IN_USD VARCHAR(16777216) COMMENT '이벤트 금액(USD)',
	EVENT_BUNDLE_SEQUENCE_ID NUMBER(38,0) COMMENT '이벤트 번들 순번',
	IS_ACTIVE_USER BOOLEAN COMMENT '활성 사용자 여부',
	USER_ID VARCHAR(16777216) COMMENT '사용자 ID',
	USER_PSEUDO_ID VARCHAR(16777216) COMMENT 'GA 익명 사용자 ID',
	USER_FIRST_TOUCH_TIMESTAMP NUMBER(38,0) COMMENT '사용자 최초 접속 시각',
	EP_CAMPAIGN VARCHAR(16777216) COMMENT '캠페인명',
	EP_CAMPAIGN_ID VARCHAR(16777216) COMMENT '캠페인 ID',
	EP_CHANGE_DONATION_UP VARCHAR(16777216) COMMENT '후원 증액 여부',
	EP_CHANGE_DONATION_UP_AMOUNT VARCHAR(16777216) COMMENT '후원 증액 금액',
	EP_CONTENT VARCHAR(16777216) COMMENT '콘텐츠',
	EP_CURRENCY VARCHAR(16777216) COMMENT '금액 통화',
	EP_DONATION_ONCE VARCHAR(16777216) COMMENT '일시후원 여부',
	EP_DONATION_ONCE_AMOUNT VARCHAR(16777216) COMMENT '일시후원 금액',
	EP_DONATION_REGULAR VARCHAR(16777216) COMMENT '정기후원 여부',
	EP_DONATION_REGULAR_AMOUNT VARCHAR(16777216) COMMENT '정기후원 금액',
	EP_ENGAGED_SESSION_EVENT VARCHAR(16777216) COMMENT '참여 세션 이벤트 여부',
	EP_ENGAGEMENT_TIME_MSEC VARCHAR(16777216) COMMENT '참여 시간(ms)',
	EP_ENTRANCES VARCHAR(16777216) COMMENT '세션 진입 여부',
	EP_EVENT_ACTION VARCHAR(16777216) COMMENT '이벤트 액션',
	EP_EVENT_CATEGORY VARCHAR(16777216) COMMENT '이벤트 카테고리',
	EP_EVENT_LABEL VARCHAR(16777216) COMMENT '이벤트 라벨',
	EP_GA_SESSION_ID VARCHAR(16777216) COMMENT 'GA 세션 ID',
	EP_GA_SESSION_NUMBER VARCHAR(16777216) COMMENT '사용자 세션 순번',
	EP_GAD_CAMPAIGNID VARCHAR(16777216) COMMENT '구글애즈 캠페인 ID',
	EP_GAD_SOURCE VARCHAR(16777216) COMMENT '구글애즈 유입 소스',
	EP_GCLID VARCHAR(16777216) COMMENT '구글 광고 클릭 ID',
	EP_LINK_CLASSES VARCHAR(16777216) COMMENT '클릭 링크 클래스',
	EP_LINK_DOMAIN VARCHAR(16777216) COMMENT '클릭 링크 도메인',
	EP_LINK_ID VARCHAR(16777216) COMMENT '클릭 링크 ID',
	EP_LINK_IMAGE VARCHAR(16777216) COMMENT '클릭 이미지',
	EP_LINK_TEXT VARCHAR(16777216) COMMENT '클릭 링크 문구',
	EP_LINK_TITLE VARCHAR(16777216) COMMENT '클릭 링크 제목',
	EP_LINK_URL VARCHAR(16777216) COMMENT '클릭 링크 URL',
	EP_MEDIUM VARCHAR(16777216) COMMENT '유입 매체',
	EP_OUTBOUND VARCHAR(16777216) COMMENT '외부 링크 여부',
	EP_PAGE_LOCATION VARCHAR(16777216) COMMENT '페이지 URL',
	EP_PAGE_REFERRER VARCHAR(16777216) COMMENT '이전 페이지 URL',
	EP_PAGE_TITLE VARCHAR(16777216) COMMENT '페이지 제목',
	EP_PAYMENT_TYPE VARCHAR(16777216) COMMENT '결제수단',
	EP_PERCENT_SCROLLED VARCHAR(16777216) COMMENT '페이지 스크롤 비율',
	EP_PROMOTION_ID VARCHAR(16777216) COMMENT '프로모션 ID',
	EP_PROMOTION_NAME VARCHAR(16777216) COMMENT '프로모션명',
	EP_SEARCH_TERM VARCHAR(16777216) COMMENT '검색어',
	EP_SESSION_ENGAGED VARCHAR(16777216) COMMENT '세션 참여 여부',
	EP_SOURCE VARCHAR(16777216) COMMENT '유입 소스',
	EP_TERM VARCHAR(16777216) COMMENT '검색어',
	EP_TRANSACTION_ID VARCHAR(16777216) COMMENT '거래 ID',
	EP_VALUE VARCHAR(16777216) COMMENT '값',
	EP_VIDEO_CURRENT_TIME VARCHAR(16777216) COMMENT '동영상 현재 재생 시간',
	EP_VIDEO_DURATION VARCHAR(16777216) COMMENT '동영상 전체 재생 시간',
	EP_VIDEO_PERCENT VARCHAR(16777216) COMMENT '동영상 비율',
	EP_VIDEO_PROVIDER VARCHAR(16777216) COMMENT '동영상 플랫폼',
	EP_VIDEO_TITLE VARCHAR(16777216) COMMENT '동영상 제목',
	EP_VIDEO_URL VARCHAR(16777216) COMMENT '동영상 URL',
	UP_BIZ_TYPE VARCHAR(16777216) COMMENT '후원 사업 유형',
	UP_DONATION_TYPE VARCHAR(16777216) COMMENT '후원 유형',
	UP_DONOR_TYPE VARCHAR(16777216) COMMENT '후원자 유형',
	UP_LOGIN_STATUS VARCHAR(16777216) COMMENT '로그인 상태',
	UP_MEMBER_ID VARCHAR(16777216) COMMENT '회원 ID',
	UP_MEMBER_TYPE VARCHAR(16777216) COMMENT '회원 유형',
	UP_USER_ID VARCHAR(16777216) COMMENT 'UP사용자 ID',
	USER_LTV_CURRENCY VARCHAR(16777216) COMMENT 'LTV 금액 통화',
	USER_LTV_REVENUE VARCHAR(16777216) COMMENT '사용자 LTV',
	DEVICE_CATEGORY VARCHAR(16777216) COMMENT '기기 유형',
	DEVICE_IS_LIMITED_AD_TRACKING VARCHAR(16777216) COMMENT '기기 광고 추적 제한 여부',
	DEVICE_LANGUAGE VARCHAR(16777216) COMMENT '기기 언어',
	DEVICE_MOBILE_BRAND_NAME VARCHAR(16777216) COMMENT '모바일 기기 브랜드명',
	DEVICE_MOBILE_MARKETING_NAME VARCHAR(16777216) COMMENT '모바일 기기 마케팅명',
	DEVICE_MOBILE_MODEL_NAME VARCHAR(16777216) COMMENT '모바일 기기 모델명',
	DEVICE_MOBILE_OS_HARDWARE_MODEL VARCHAR(16777216) COMMENT '모바일 OS/하드웨어 모델',
	DEVICE_OPERATING_SYSTEM VARCHAR(16777216) COMMENT '기기 운영체제',
	DEVICE_OPERATING_SYSTEM_VERSION VARCHAR(16777216) COMMENT '기기 운영체제 버전',
	DEVICE_WEB_INFO_BROWSER VARCHAR(16777216) COMMENT '웹 브라우저',
	DEVICE_WEB_INFO_BROWSER_VERSION VARCHAR(16777216) COMMENT '웹 브라우저 버전',
	DEVICE_WEB_INFO_HOSTNAME VARCHAR(16777216) COMMENT '웹 호스트명',
	GEO_CITY VARCHAR(16777216) COMMENT '도시',
	GEO_CONTINENT VARCHAR(16777216) COMMENT '대륙',
	GEO_COUNTRY VARCHAR(16777216) COMMENT '국가',
	GEO_METRO VARCHAR(16777216) COMMENT '광역권',
	GEO_REGION VARCHAR(16777216) COMMENT '지역',
	GEO_SUB_CONTINENT VARCHAR(16777216) COMMENT '하위 대륙',
	CTS_MANUAL_CAMPAIGN_ID VARCHAR(16777216) COMMENT '수동 캠페인 ID',
	CTS_MANUAL_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '수동 캠페인명',
	CTS_MANUAL_CONTENT VARCHAR(16777216) COMMENT '수동 광고 소재',
	CTS_MANUAL_MEDIUM VARCHAR(16777216) COMMENT '수동 유입 매체',
	CTS_MANUAL_SOURCE VARCHAR(16777216) COMMENT '수동 유입 소스',
	CTS_MANUAL_TERM VARCHAR(16777216) COMMENT '수동 검색어/키워드',
	STSLC_CRC_CAMPAIGN_ID VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 ID',
	STSLC_CRC_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인명',
	STSLC_CRC_DEFAULT_CHANNEL_GROUP VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 기본 채널',
	STSLC_CRC_MEDIUM VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 유입 매체',
	STSLC_CRC_PRIMARY_CHANNEL_GROUP VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 주요 채널',
	STSLC_CRC_SOURCE VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캄패인 유입 소스',
	STSLC_CRC_SOURCE_PLATFORM VARCHAR(16777216) COMMENT '세션 최종 클릭 크로스 캠페인 소스 플랫폼',
	STSLC_GAC_AD_GROUP_ID VARCHAR(16777216) COMMENT '세션 최종 클릭 구글애즈 광고그룹 ID',
	STSLC_GAC_AD_GROUP_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 구글애즈 광고그룹명',
	STSLC_GAC_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 구글애즈 캠페인명',
	STSLC_MC_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 캠페인명',
	STSLC_MC_CONTENT VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 광고 소재',
	STSLC_MC_MEDIUM VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 유입 매체',
	STSLC_MC_SOURCE VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 유입 소스',
	STSLC_MC_SOURCE_PLATFORM VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 소스 플랫폼',
	STSLC_MC_TERM VARCHAR(16777216) COMMENT '세션 최종 클릭 수동 검색어/키워드',
	TS_MEDIUM VARCHAR(16777216) COMMENT 'TS유입 매체',
	TS_NAME VARCHAR(16777216) COMMENT 'TS유입 객체명',
	TS_SOURCE VARCHAR(16777216) COMMENT 'TS유입 소스',
	STREAM_ID VARCHAR(16777216) COMMENT '스트림 ID',
	PLATFORM VARCHAR(16777216) COMMENT '플랫폼',
	ECOMMERCE_PURCHASE_REVENUE VARCHAR(16777216) COMMENT '이커머스 후원 금액',
	ECOMMERCE_TOTAL_ITEM_QUANTITY VARCHAR(16777216) COMMENT '이커머스 전체 상품 수량',
	ECOMMERCE_TRANSACTION_ID VARCHAR(16777216) COMMENT '이커머스 거래 ID',
	ECOMMERCE_UNIQUE_ITEMS VARCHAR(16777216) COMMENT '이커머스 고유 상품',
	ITEMS ARRAY COMMENT '후원 항목 정보'
)COMMENT='빅쿼리 평탄화 데이터'
;

-- ---------------------------------------------------------------------
-- TABLE 2/4 : GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA  (17 컬럼 · 반정형 없음)
--   🆕 [2026-10-02 O198] 기획실 연간 개발 목표/실적 집계(DATA_TYPE_NM = 목표/실적 · M01~M12 건수)
--   원천 18번(2026-10-02 재수령분) 무변경 발췌 · A 의 갱신 프로시저(SP_*)는 이관하지 않는다(데이터만 이관).
-- ---------------------------------------------------------------------
create or replace TABLE GN_DW.SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA (
	YEAR VARCHAR(16777216) COMMENT '연도',
	DATA_TYPE_NM VARCHAR(16777216) COMMENT '목표 실적 구분 명',
	DEPT_DIV_NM VARCHAR(16777216) COMMENT '부서 구분 명',
	NEW_EXST_DIV_NM VARCHAR(16777216) COMMENT '신규기존구분명',
	SPNSR_BSNS_GRP_NM VARCHAR(16777216) COMMENT '후원 사업 그룹 명',
	M01 NUMBER(38,13) COMMENT '1월 건수',
	M02 NUMBER(38,13) COMMENT '2월 건수',
	M03 NUMBER(38,13) COMMENT '3월 건수',
	M04 NUMBER(38,13) COMMENT '4월 건수',
	M05 NUMBER(38,13) COMMENT '5월 건수',
	M06 NUMBER(38,13) COMMENT '6월 건수',
	M07 NUMBER(38,13) COMMENT '7월 건수',
	M08 NUMBER(38,13) COMMENT '8월 건수',
	M09 NUMBER(38,13) COMMENT '9월 건수',
	M10 NUMBER(38,13) COMMENT '10월 건수',
	M11 NUMBER(38,13) COMMENT '11월 건수',
	M12 NUMBER(38,13) COMMENT '12월 건수'
)COMMENT='연간 개발 목표 실적 집계 데이터'
;

-- ---------------------------------------------------------------------
-- TABLE 3/4 : GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA  (29 컬럼 · 반정형 없음)
--   🆕 [2026-10-02 O198] 회원실 회비예측 예측/실측(DATA_TYPE_NM = 예측/실측)
--   원천 18번(2026-10-02 재수령분) 무변경 발췌 · A 의 갱신 프로시저(SP_*)는 이관하지 않는다(데이터만 이관).
-- ---------------------------------------------------------------------
create or replace TABLE GN_DW.SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA (
	DATA_TYPE_NM VARCHAR(16777216) COMMENT '예측 실측 구분 명',
	SPNSR_BSNS_GRP_NM VARCHAR(16777216) COMMENT '후원 사업 그룹 명',
	NEW_EXST_DIV_NM VARCHAR(16777216) COMMENT '신규기존구분명',
	HDQ_BRNCH_GRP_NM VARCHAR(16777216) COMMENT '본부 지부 그룹 명',
	STDR_MT VARCHAR(16777216) COMMENT '기준월',
	DVLP_CNT NUMBER(38,10) COMMENT '개발건수',
	CMLT_DVLP_CNT NUMBER(38,10) COMMENT '누적개발건수',
	ADJ_DSCNTC_RT NUMBER(38,10) COMMENT '조정 중단율',
	ADJ_DSCNTC_CNT NUMBER(38,10) COMMENT '조정 중단건수',
	ADJ_RDCAMT_RT NUMBER(38,10) COMMENT '조정 감액율',
	ADJ_RDCAMT_CNT NUMBER(38,10) COMMENT '조정 감액건수',
	ADJ_RECALC_DSCNTC_RT NUMBER(38,10) COMMENT '조정 재산출 중단율',
	ADJ_DSCNTC_CNT2 NUMBER(38,10) COMMENT '조정 중단건수2',
	ADJ_CMLT_DSCNTC_CNT NUMBER(38,10) COMMENT '조정 누계 중단건수',
	DSCNTC_RT NUMBER(38,10) COMMENT '중단율',
	DSCNTC_CNT NUMBER(38,10) COMMENT '중단건수',
	RDCAMT_RT NUMBER(38,10) COMMENT '감액율',
	SPNSR_BSNS_CHN_DEC_CNT NUMBER(38,10) COMMENT '후원사업변경감소건수',
	RDCAMT_CNT NUMBER(38,10) COMMENT '2 감액 건수2',
	CMLT_EOM_ACT_MBER_CNT NUMBER(38,10) COMMENT '누적 월말활동회원건수',
	CMLT_ACT_MBER_CNT NUMBER(38,10) COMMENT '누적 활동회원건수',
	ACT_RT NUMBER(38,10) COMMENT '활동율',
	ADJ_MT_PAY_RT NUMBER(38,10) COMMENT '조정 월납입율',
	ADJ_MBRFEE_AMT NUMBER(38,10) COMMENT '조정 회비',
	ADJ_CMLT_PAY_RT NUMBER(38,10) COMMENT '조정 누계납입율',
	ADJ_CMLT_MBRFEE_AMT NUMBER(38,10) COMMENT '조정 누계회비',
	CMLT_PAY_RT NUMBER(38,10) COMMENT '누계납입율',
	CMLT_MBRFEE_AMT NUMBER(38,10) COMMENT '누적 회비',
	MBRFEE_DIFF_AMT NUMBER(38,10) COMMENT '회비 차액'
)COMMENT='회원실 연간 회비 예측 실측 데이터'
;

-- ---------------------------------------------------------------------
-- TABLE 4/4 : GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA  (8 컬럼 · 반정형 없음)
--   🆕 [2026-10-02 O198] 회원실 회비예측 월간 후원 분류별 집계(실측 입력)
--   원천 18번(2026-10-02 재수령분) 무변경 발췌 · A 의 갱신 프로시저(SP_*)는 이관하지 않는다(데이터만 이관).
-- ---------------------------------------------------------------------
create or replace TABLE GN_DW.SILVER.MM_SPNSR_CLS_AGGR_DATA (
	STDR_MT VARCHAR(16777216) COMMENT '기준월',
	AGGR_TY_NM VARCHAR(16777216) COMMENT '집계 유형명',
	CPR_NM VARCHAR(16777216) COMMENT '법인명',
	SPNSR_BSNS_GRP_NM VARCHAR(16777216) COMMENT '후원 사업 그룹 명',
	NEW_EXST_DIV_NM VARCHAR(16777216) COMMENT '신규기존구분명',
	HDQ_BRNCH_GRP_NM VARCHAR(16777216) COMMENT '본부 지부 그룹 명',
	VALUE1 NUMBER(38,10) COMMENT '값1',
	VALUE2 NUMBER(38,10) COMMENT '값2'
)COMMENT='회원실 회비예측 월간 후원 분류별 집계'
;

-- ---------------------------------------------------------------------
-- 🆕 [O198] 테이블별 컬럼 수 (기대: BIGQUERY_REFINED_DATA 118 · ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA 17 · ANNUAL_MBRFEE_PRDT_ACTL_DATA 29 · MM_SPNSR_CLS_AGGR_DATA 8)
-- ---------------------------------------------------------------------
SELECT table_name, COUNT(*) AS n_cols
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER'
  AND table_name IN ('BIGQUERY_REFINED_DATA', 'ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA',
                     'ANNUAL_MBRFEE_PRDT_ACTL_DATA', 'MM_SPNSR_CLS_AGGR_DATA')
GROUP BY 1 ORDER BY 1;

-- ---------------------------------------------------------------------
-- 생성 확인 (기대: 118 컬럼 / ITEMS ordinal_position = 118, data_type = ARRAY)
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS n_cols
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA';

SELECT ordinal_position, column_name, data_type
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SILVER' AND table_name = 'BIGQUERY_REFINED_DATA'
  AND data_type IN ('ARRAY', 'VARIANT', 'OBJECT')
ORDER BY 1;
-- → 118 / ITEMS / ARRAY 한 줄만 나와야 한다.
--   여기서 나온 ordinal_position 이 07번 A.5 의 TRY_PARSE_JSON($n) 위치와 같아야 한다.
--   다르면 07번 A.5 의 $n 을 먼저 고친 뒤 적재할 것.
