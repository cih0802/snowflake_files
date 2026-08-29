-- GN_DW.SILVER 정제 테이블 DDL — C 계정 재현용
-- 2026-08-20 (초판) · 2026-08-29 갱신
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   A 계정의 GN_DW.SILVER.BIGQUERY_REFINED_DATA 구조를 C 계정에 그대로 재현한다.
--   CSV 적재는 위치(순서) 기반이므로 적재 전에 반드시 이 DDL을 먼저 실행해야 한다.
--
-- 이관 경로 / TOPOLOGY
--   A ──(Direct Share · 동일 리전)──▶ B ──(로컬 다운로드)──▶ 로컬 ──(업로드)──▶ C (다른 리전)
--
-- 실행 계정 / 역할
--   C (Target), ACCOUNTADMIN
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md  → 5.1(DDL 재생성) / 5.5(SILVER 적재)
--   [출처]     50_handoff/02_데이터마이그 A_PRODUCER.sql 6.2
--              → SELECT GET_DDL('TABLE','GN_DW.SILVER.BIGQUERY_REFINED_DATA', TRUE);
--   [원천 정의] 99_provided_definition/18_silver_bigquery_refined.sql
--              → 2026-08-29 기계 대조 결과 **본 파일과 차이 0**(컬럼명·순서·타입·COMMENT 전건 일치).
--   [형제 DDL] 50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql (브론즈 3스키마 52테이블)
--              50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql     (ML 예측결과 16종)
--              ⚠️ 세 파일을 모두 실행해야 이관 대상 69 테이블이 완성된다. 선후 관계는 없다.
--   [후속]     50_handoff/07_데이터마이그 C_CONSUMER.sql  A.5 (이 테이블 적재)
--
-- 변경 이력 / CHANGES
--   2026-08-29
--     · 원천 정의 문서(18번)와 기계 대조 — **구조 변경 0건**. DDL 본문은 손대지 않았다.
--     · 형제·후속 문서 참조 정정: 「04_2번」 → 본 파일이 **06번**이다 ·
--       「06번 C_CONSUMER」 → **07번** · 브론즈 50 → **52** · 총계 67 → **69**.
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
--   GN_DW.SILVER.BIGQUERY_REFINED_DATA — 1 테이블
--   ⚠️ A 는 SILVER 스키마 중 이 테이블 하나만 공유한다(02번 2.1). 다른 SILVER 테이블은 대상이 아니다.
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
USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS GN_DW;
CREATE SCHEMA   IF NOT EXISTS GN_DW.SILVER
  COMMENT = '정제 계층 - A 원천 SILVER 이관분 (BigQuery/GA4 통합)';

-- ---------------------------------------------------------------------
-- TABLE 1/1 : GN_DW.SILVER.BIGQUERY_REFINED_DATA  (118 컬럼, ITEMS=ARRAY)
-- ---------------------------------------------------------------------
create or replace TABLE GN_DW.SILVER.BIGQUERY_REFINED_DATA (
	BATCH_EVENT_INDEX NUMBER(38,0) COMMENT '동일 배치 안에서 이벤트가 기록된 순번',
	EVENT_DATE VARCHAR(16777216) COMMENT '이벤트가 발생하거나 기록된 날짜',
	EVENT_TIMESTAMP NUMBER(38,0) COMMENT '이벤트가 발생한 시각을 나타내는 타임스탬프',
	EVENT_NAME VARCHAR(16777216) COMMENT '사용자 행동 또는 전환을 구분하는 이벤트명',
	EVENT_VALUE_IN_USD VARCHAR(16777216) COMMENT '이벤트 값이 미국 달러 기준으로 환산된 금액',
	EVENT_BUNDLE_SEQUENCE_ID NUMBER(38,0) COMMENT '이벤트 번들의 순차 식별값',
	IS_ACTIVE_USER BOOLEAN COMMENT '활성 사용자 여부를 나타내는 값',
	USER_ID VARCHAR(16777216) COMMENT '서비스에서 설정한 사용자 식별자',
	USER_PSEUDO_ID VARCHAR(16777216) COMMENT 'GA4가 부여한 익명 사용자 또는 기기 기반 식별자',
	USER_FIRST_TOUCH_TIMESTAMP NUMBER(38,0) COMMENT '사용자가 처음 유입되거나 처음 접속한 시점',
	EP_CAMPAIGN VARCHAR(16777216) COMMENT '캠페인명',
	EP_CAMPAIGN_ID VARCHAR(16777216) COMMENT '캠페인 식별값',
	EP_CHANGE_DONATION_UP VARCHAR(16777216) COMMENT '후원 증액 또는 변경 이벤트 여부로 해석 가능한 값',
	EP_CHANGE_DONATION_UP_AMOUNT VARCHAR(16777216) COMMENT '후원 증액 또는 변경 금액으로 해석 가능한 값',
	EP_CONTENT VARCHAR(16777216) COMMENT '광고 소재 또는 콘텐츠 구분값',
	EP_CURRENCY VARCHAR(16777216) COMMENT '금액 데이터의 통화 단위',
	EP_DONATION_ONCE VARCHAR(16777216) COMMENT '일시후원 여부를 나타내는 값',
	EP_DONATION_ONCE_AMOUNT VARCHAR(16777216) COMMENT '일시후원 금액',
	EP_DONATION_REGULAR VARCHAR(16777216) COMMENT '정기후원 여부를 나타내는 값',
	EP_DONATION_REGULAR_AMOUNT VARCHAR(16777216) COMMENT '정기후원 금액',
	EP_ENGAGED_SESSION_EVENT VARCHAR(16777216) COMMENT '참여 세션으로 판단되는 이벤트 여부',
	EP_ENGAGEMENT_TIME_MSEC VARCHAR(16777216) COMMENT '사용자의 참여 시간 또는 체류 시간을 밀리초 단위로 기록한 값',
	EP_ENTRANCES VARCHAR(16777216) COMMENT '해당 페이지 또는 이벤트가 세션 진입에 해당하는지 나타내는 값',
	EP_EVENT_ACTION VARCHAR(16777216) COMMENT '이벤트의 구체적인 사용자 행동명',
	EP_EVENT_CATEGORY VARCHAR(16777216) COMMENT '이벤트를 분류하는 상위 카테고리',
	EP_EVENT_LABEL VARCHAR(16777216) COMMENT '이벤트의 세부 라벨 또는 보조 설명값',
	EP_GA_SESSION_ID VARCHAR(16777216) COMMENT 'GA4 세션 식별자',
	EP_GA_SESSION_NUMBER VARCHAR(16777216) COMMENT '사용자 기준 세션 순번',
	EP_GAD_CAMPAIGNID VARCHAR(16777216) COMMENT 'Google Ads 캠페인 ID로 활용 가능한 값',
	EP_GAD_SOURCE VARCHAR(16777216) COMMENT 'Google Ads 유입 소스 관련 식별값',
	EP_GCLID VARCHAR(16777216) COMMENT 'Google 광고 클릭을 식별하는 클릭 ID',
	EP_LINK_CLASSES VARCHAR(16777216) COMMENT '클릭된 링크 또는 버튼의 CSS 클래스 정보',
	EP_LINK_DOMAIN VARCHAR(16777216) COMMENT '클릭된 링크의 도메인',
	EP_LINK_ID VARCHAR(16777216) COMMENT '클릭된 링크 또는 버튼의 ID',
	EP_LINK_IMAGE VARCHAR(16777216) COMMENT '클릭된 이미지 링크 또는 이미지 URL',
	EP_LINK_TEXT VARCHAR(16777216) COMMENT '클릭된 링크 또는 버튼의 표시 문구',
	EP_LINK_TITLE VARCHAR(16777216) COMMENT '클릭된 링크의 title 속성 또는 보조 설명',
	EP_LINK_URL VARCHAR(16777216) COMMENT '클릭된 링크의 목적지 URL',
	EP_MEDIUM VARCHAR(16777216) COMMENT '유입 매체 또는 채널 유형',
	EP_OUTBOUND VARCHAR(16777216) COMMENT '외부 링크 이동 여부를 나타내는 값',
	EP_PAGE_LOCATION VARCHAR(16777216) COMMENT '이벤트가 발생한 페이지 URL',
	EP_PAGE_REFERRER VARCHAR(16777216) COMMENT '해당 페이지로 오기 전 참조 URL',
	EP_PAGE_TITLE VARCHAR(16777216) COMMENT '이벤트가 발생한 페이지 제목',
	EP_PAYMENT_TYPE VARCHAR(16777216) COMMENT '결제수단',
	EP_PERCENT_SCROLLED VARCHAR(16777216) COMMENT '페이지 스크롤 도달 비율',
	EP_PROMOTION_ID VARCHAR(16777216) COMMENT '프로모션 또는 배너 식별값',
	EP_PROMOTION_NAME VARCHAR(16777216) COMMENT '프로모션 또는 배너 이름',
	EP_SEARCH_TERM VARCHAR(16777216) COMMENT '사이트 내 검색어 또는 사용자가 입력한 검색어',
	EP_SESSION_ENGAGED VARCHAR(16777216) COMMENT '세션 참여 여부',
	EP_SOURCE VARCHAR(16777216) COMMENT '유입 소스',
	EP_TERM VARCHAR(16777216) COMMENT '검색어, 타겟, 키워드 또는 세부 캠페인 구분값',
	EP_TRANSACTION_ID VARCHAR(16777216) COMMENT '거래 또는 후원 완료를 식별하는 ID (오늘의 리포트 : 약정id)',
	EP_VALUE VARCHAR(16777216) COMMENT '이벤트에 연결된 금액 또는 수치값',
	EP_VIDEO_CURRENT_TIME VARCHAR(16777216) COMMENT '동영상 이벤트 발생 시점의 현재 재생 위치',
	EP_VIDEO_DURATION VARCHAR(16777216) COMMENT '동영상 전체 재생 길이',
	EP_VIDEO_PERCENT VARCHAR(16777216) COMMENT '동영상 시청 완료 또는 진행 비율',
	EP_VIDEO_PROVIDER VARCHAR(16777216) COMMENT '동영상 제공 플랫폼',
	EP_VIDEO_TITLE VARCHAR(16777216) COMMENT '동영상 제목',
	EP_VIDEO_URL VARCHAR(16777216) COMMENT '동영상 URL',
	UP_BIZ_TYPE VARCHAR(16777216) COMMENT '후원 또는 관심 사업 유형',
	UP_DONATION_TYPE VARCHAR(16777216) COMMENT '후원 구분 유형',
	UP_DONOR_TYPE VARCHAR(16777216) COMMENT '후원자 유형',
	UP_LOGIN_STATUS VARCHAR(16777216) COMMENT '로그인 여부',
	UP_MEMBER_ID VARCHAR(16777216) COMMENT '회원 식별자',
	UP_MEMBER_TYPE VARCHAR(16777216) COMMENT '회원 상태 또는 회원 구분',
	UP_USER_ID VARCHAR(16777216) COMMENT '서비스에서 설정한 사용자 식별자',
	USER_LTV_CURRENCY VARCHAR(16777216) COMMENT '금액 데이터의 통화 단위',
	USER_LTV_REVENUE VARCHAR(16777216) COMMENT '사용자 기준 누적 수익 또는 가치',
	DEVICE_CATEGORY VARCHAR(16777216) COMMENT '기기 유형',
	DEVICE_IS_LIMITED_AD_TRACKING VARCHAR(16777216) COMMENT '광고 추적 제한 여부',
	DEVICE_LANGUAGE VARCHAR(16777216) COMMENT '기기 또는 브라우저 언어 설정',
	DEVICE_MOBILE_BRAND_NAME VARCHAR(16777216) COMMENT '모바일 기기 브랜드명',
	DEVICE_MOBILE_MARKETING_NAME VARCHAR(16777216) COMMENT '모바일 기기의 마케팅용 모델명',
	DEVICE_MOBILE_MODEL_NAME VARCHAR(16777216) COMMENT '모바일 기기 모델명',
	DEVICE_MOBILE_OS_HARDWARE_MODEL VARCHAR(16777216) COMMENT '모바일 OS 또는 하드웨어 모델 정보',
	DEVICE_OPERATING_SYSTEM VARCHAR(16777216) COMMENT '운영체제',
	DEVICE_OPERATING_SYSTEM_VERSION VARCHAR(16777216) COMMENT '운영체제 버전',
	DEVICE_WEB_INFO_BROWSER VARCHAR(16777216) COMMENT '웹 브라우저명',
	DEVICE_WEB_INFO_BROWSER_VERSION VARCHAR(16777216) COMMENT '웹 브라우저 버전',
	DEVICE_WEB_INFO_HOSTNAME VARCHAR(16777216) COMMENT '이벤트가 발생한 호스트명',
	GEO_CITY VARCHAR(16777216) COMMENT '도시 정보',
	GEO_CONTINENT VARCHAR(16777216) COMMENT '대륙 정보',
	GEO_COUNTRY VARCHAR(16777216) COMMENT '국가 정보',
	GEO_METRO VARCHAR(16777216) COMMENT '대도시권 또는 광역권 정보',
	GEO_REGION VARCHAR(16777216) COMMENT '지역 또는 시도 정보',
	GEO_SUB_CONTINENT VARCHAR(16777216) COMMENT '하위 대륙 정보',
	CTS_MANUAL_CAMPAIGN_ID VARCHAR(16777216) COMMENT '수동 캠페인 ID 또는 UTM 캠페인 ID',
	CTS_MANUAL_CAMPAIGN_NAME VARCHAR(16777216) COMMENT '수동 캠페인명 또는 UTM 캠페인명',
	CTS_MANUAL_CONTENT VARCHAR(16777216) COMMENT '수동 콘텐츠값 또는 UTM content',
	CTS_MANUAL_MEDIUM VARCHAR(16777216) COMMENT '수동 매체값 또는 UTM medium',
	CTS_MANUAL_SOURCE VARCHAR(16777216) COMMENT '수동 소스값 또는 UTM source',
	CTS_MANUAL_TERM VARCHAR(16777216) COMMENT '수동 검색어값 또는 UTM term',
	STSLC_CRC_CAMPAIGN_ID VARCHAR(16777216) COMMENT '캠페인 식별값',
	STSLC_CRC_CAMPAIGN_NAME VARCHAR(16777216),
	STSLC_CRC_DEFAULT_CHANNEL_GROUP VARCHAR(16777216),
	STSLC_CRC_MEDIUM VARCHAR(16777216) COMMENT '유입 매체 또는 채널 유형',
	STSLC_CRC_PRIMARY_CHANNEL_GROUP VARCHAR(16777216),
	STSLC_CRC_SOURCE VARCHAR(16777216) COMMENT '유입 소스',
	STSLC_CRC_SOURCE_PLATFORM VARCHAR(16777216),
	STSLC_GAC_AD_GROUP_ID VARCHAR(16777216),
	STSLC_GAC_AD_GROUP_NAME VARCHAR(16777216),
	STSLC_GAC_CAMPAIGN_NAME VARCHAR(16777216),
	STSLC_MC_CAMPAIGN_NAME VARCHAR(16777216),
	STSLC_MC_CONTENT VARCHAR(16777216) COMMENT '광고 소재 또는 콘텐츠 구분값',
	STSLC_MC_MEDIUM VARCHAR(16777216) COMMENT '유입 매체 또는 채널 유형',
	STSLC_MC_SOURCE VARCHAR(16777216) COMMENT '유입 소스',
	STSLC_MC_SOURCE_PLATFORM VARCHAR(16777216),
	STSLC_MC_TERM VARCHAR(16777216) COMMENT '검색어, 타겟, 키워드 또는 세부 캠페인 구분값',
	TS_MEDIUM VARCHAR(16777216) COMMENT '사용자가 유입된 마케팅 채널 또는 매체 유형',
	TS_NAME VARCHAR(16777216) COMMENT '객체(캠페인, 프로모션, 폼, 사용자 입력 항목 등)의 이름 또는 명칭',
	TS_SOURCE VARCHAR(16777216) COMMENT '사용자가 유입된 웹사이트, 광고 플랫폼 또는 채널의 출처',
	STREAM_ID VARCHAR(16777216) COMMENT 'GA4 데이터 스트림 식별자',
	PLATFORM VARCHAR(16777216) COMMENT '이벤트가 발생한 플랫폼 구분값',
	ECOMMERCE_PURCHASE_REVENUE VARCHAR(16777216) COMMENT '구매 또는 후원 전환 금액',
	ECOMMERCE_TOTAL_ITEM_QUANTITY VARCHAR(16777216) COMMENT '전체 항목 수량',
	ECOMMERCE_TRANSACTION_ID VARCHAR(16777216) COMMENT '거래 또는 후원 완료를 식별하는 ID',
	ECOMMERCE_UNIQUE_ITEMS VARCHAR(16777216) COMMENT '고유 항목 수',
  ITEMS ARRAY COMMENT '배열값. item_category: 항목 카테고리 / item_id: 항목 식별값 / item_name: 항목명 또는 후원 사업명 / item_revenue: 항목별 수익 또는 후원 금액 / price: 항목 가격 또는 후원 금액 / promotion_id: 프로모션 또는 배너 식별값 / promotion_name: 프로모션 또는 배너 이름 / quantity: 항목 수량'
);

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
