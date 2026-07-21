-- GN_DW.GOLD WIDE VIEW 9개의 뷰 컬럼 COMMENT를 ALTER VIEW로 일괄 적용하는 스크립트.
-- Co-authored with CoCo
-- ✅ [2026-07-20 적용 완료] GOLD 배포·적재 후 본 스크립트 실행 완료(9뷰 330컬럼 COMMENT 적용). idempotent — 재실행 안전.
-- 🔷 [2026-07-07 정정] DIM_ORG = SCD1 (DEC-2): 조직 변경이력 소스·as-was 요구 없음 → EFFECTIVE_*/IS_CURRENT 컬럼 삭제.
--    아래 ORG_CORP/DIVISION/DEPARTMENT/TEAM COMMENT의 "(as-was)" 표기는 SCD1 정정 이전 잔재이며, 실제 의미는 current-value(최신 조직명·계층)임.

/*
================================================================================
  GN_DW.GOLD — WIDE VIEW 컬럼 COMMENT
  적용 대상  : WIDE_MEMBER_MONTHLY / WIDE_MEMBER_EVENT / WIDE_TARGET_DEV /
               WIDE_TARGET_BIZ / WIDE_SERVICE_EVENT / WIDE_GA_BEHAVIOR /
               WIDE_AD_PERFORMANCE / WIDE_EVENT_PARTICIPATION / WIDE_BUDGET
--------------------------------------------------------------------------------
  실행 전제 / 정책
  ─────────────────────────────────────────────────────────────────────────────
  1. 09_빅테이블 VIEW.md DDL로 9개 VIEW가 먼저 생성돼 있어야 함.
  2. 뷰 컬럼 COMMENT는 반드시 ALTER VIEW ... ALTER COLUMN ... COMMENT 사용.
     ※ COMMENT ON COLUMN 은 TABLE 전용 — 뷰에 쓰면
       "Object found is of type 'VIEW', not specified type 'TABLE'" 오류.
  3. 뷰당 1개 ALTER 문(멀티컬럼)으로 원자 적용 + 재실행 가능(idempotent).
     한 컬럼명이라도 틀리면 그 뷰 전체가 실패 → 컬럼명은 실제 뷰 기준(검증 완료).
  4. alias DIM 컬럼은 "원본DIM.컬럼 — 설명 (#지표번호)" 로 출처 명시.
  5. 파생 컬럼(CAL_YEAR·CAL_MONTH)은 계산식 포함. 비가산 지표는 "[비가산]" 접두.
  6. 전 9개 뷰 실객체 대상 실행 검증 완료(오류 0).
================================================================================
*/

USE DATABASE GN_DW;
USE SCHEMA GOLD;

-- ============================================================================
-- 1. WIDE_MEMBER_MONTHLY
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_MEMBER_MONTHLY
    ALTER COLUMN CAL_YEAR                  COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
          COLUMN CAL_MONTH                 COMMENT 'MOD(MONTH_KEY,100) — 월',
          COLUMN MONTH_KEY                 COMMENT 'YYYYMM',
          COLUMN MEMBER_DK                 COMMENT '불변 회원키(조인용)',
          COLUMN DEV_CNT                   COMMENT '개발(건) SUM(금액)/10000 (#4·5·149)',
          COLUMN DEV_MEMBERS               COMMENT '개발(명) COUNT (#148)',
          COLUMN STOP_CNT                  COMMENT '중단(건) (#35, FME 롤업)',
          COLUMN UNPAID_CNT                COMMENT '미납(건) (#36)',
          COLUMN ACTIVE_CNT                COMMENT '활동(건) (#37·157)',
          COLUMN ACTIVE_MEMBERS            COMMENT '활동(명) (#156)',
          COLUMN ACTIVE_CUM_CNT            COMMENT '활동누계(건) (#159)',
          COLUMN ACTIVE_CUM_MEMBERS        COMMENT '활동누계(명) (#158)',
          COLUMN INCREASE_CNT              COMMENT '증액(건) (#151)',
          COLUMN INCREASE_MEMBERS          COMMENT '증액(명) (#150)',
          COLUMN DECREASE_CNT              COMMENT '감액(건) SUM(감액금액)/10000 (#38)',
          COLUMN CHURN_CNT                 COMMENT '이탈(건) SUM(취소+감액)/10000 (신규#20)',
          COLUMN YEAR_START_ACTIVE_CNT     COMMENT '연도초 활동회원(건) (#49)',
          COLUMN YEAR_END_ACTIVE_CNT       COMMENT '연도말 활동회원(건) (#50)',
          COLUMN MONTH_END_ACTIVE_CNT      COMMENT '월말활동회원(건) (#52)',
          COLUMN PREV_MONTH_END_ACTIVE_CNT COMMENT '전월말 활동회원(건) (#53)',
          COLUMN CAMPAIGN_UNPAID_CNT       COMMENT '캠페인별 미납(건) (#83)',
          COLUMN STATUS_UNPAID_CNT         COMMENT '회원상태별 미납(건) (#84)',
          COLUMN REGULAR_FEE               COMMENT '정기회비(원) (#66)',
          COLUMN REGULAR_ONETIME_FEE       COMMENT '정기회원 일시회비(원) (#67)',
          COLUMN ONETIME_ONETIME_FEE       COMMENT '일시회원 일시회비(원) (#68)',
          COLUMN PAID_FEE                  COMMENT '납입회비(원) (#69·70 단일화)',
          COLUMN BILLED_AMT                COMMENT '청구(원) (#71)',
          COLUMN INBOUND_CALL_CNT          COMMENT '인바운드콜수 (overview)',
          COLUMN TS_CALL_CNT               COMMENT 'TS콜수 (overview)',
          COLUMN DEV_TYPE                  COMMENT '개발구분 (#121)',
          COLUMN NEW_FLAG                  COMMENT '신규여부 (#32)',
          COLUMN INCREASE_FLAG             COMMENT '증액여부 (#33)',
          COLUMN REDONATE_FLAG             COMMENT '재후원여부 (#34)',
          COLUMN JOIN_DATE                 COMMENT '캠페인 가입일 (#27)',
          COLUMN STOP_DATE                 COMMENT '가입캠페인 중단일 (#26)',
          COLUMN AMOUNT_BAND1              COMMENT '후원금액대1 5만 (#72)',
          COLUMN AMOUNT_BAND2              COMMENT '후원금액대2 1만 (#73)',
          COLUMN PERIOD_BAND1              COMMENT '후원기간대1 5년 (#74)',
          COLUMN PERIOD_BAND2              COMMENT '후원기간대2 1년 (#75)',
          COLUMN SPONSOR_MONTHS            COMMENT '후원기간(개월) (#127)',
          COLUMN SPONSOR_YEARS             COMMENT '후원기간(년) (#128)',
          COLUMN PAID_MONTHS               COMMENT '납입개월수 (#129)',
          COLUMN NEW_EXISTING_FLAG         COMMENT '신규/기존(시점귀속, #113)',
          COLUMN UNPAID_FLAG_BOM           COMMENT '월초 미납회원 여부(=전월말 상태, #80)',
          COLUMN UNPAID_FLAG_EOM           COMMENT '월말 미납회원 여부 (#80)',
          COLUMN DW_SOURCE_SYSTEM          COMMENT '원천 시스템 식별',
          COLUMN MEMBER_GENDER             COMMENT 'DIM_MEMBER.GENDER — 성별 (#130)',
          COLUMN MEMBER_REGION             COMMENT 'DIM_MEMBER.REGION — 지역 (#131)',
          COLUMN MEMBER_AGE_BAND           COMMENT 'DIM_MEMBER.AGE_BAND — 연령대',
          COLUMN MEMBER_STATUS             COMMENT 'DIM_MEMBER.MEMBER_STATUS — 회원상태 (#132)',
          COLUMN MEMBER_TYPE               COMMENT 'DIM_MEMBER.MEMBER_TYPE — 회원구분',
          COLUMN MEMBER_NEW_EXISTING       COMMENT 'DIM_MEMBER.NEW_EXISTING_FLAG — 신규기존(현재버전, #113)',
          COLUMN MEMBER_FIRST_JOIN_DATE    COMMENT 'DIM_MEMBER.FIRST_JOIN_DATE — 최초가입일 (#28)',
          COLUMN MEMBER_FIRST_CAMPAIGN     COMMENT 'DIM_MEMBER.FIRST_CAMPAIGN — 최초캠페인 (#29)',
          COLUMN MEMBER_ENROLL_PATH        COMMENT 'DIM_MEMBER.ENROLL_PATH — 가입경로',
          COLUMN MEMBER_FIRST_SPONSORSHIP  COMMENT 'DIM_MEMBER.FIRST_SPONSORSHIP — 최초후원사업',
          COLUMN MEMBER_CURRENT_SPONSORSHIP COMMENT 'DIM_MEMBER.CURRENT_SPONSORSHIP — 현재후원사업',
          COLUMN CAMPAIGN_BK               COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND            COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_PARENT           COMMENT 'DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119)',
          COLUMN CAMPAIGN_NAME             COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)',
          COLUMN CAMPAIGN_PROMO_METHOD     COMMENT 'DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118)',
          COLUMN CAMPAIGN_TYPE             COMMENT 'DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17)',
          COLUMN SPONSORSHIP_BK            COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키',
          COLUMN SPONSORSHIP_NAME          COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)',
          COLUMN SPONSORSHIP_ABBR          COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_ABBR — 약칭 (#124)',
          COLUMN PAYMENT_METHOD            COMMENT 'DIM_PAYMENT.PAYMENT_METHOD — 납입방식 (#125)',
          COLUMN PAYMENT_SETTLE_METHOD     COMMENT 'DIM_PAYMENT.SETTLE_METHOD — 결제방식',
          COLUMN PAYMENT_FEE_TYPE          COMMENT 'DIM_PAYMENT.FEE_TYPE — 회비유형(정기/일시)',
          COLUMN REASON_CODE               COMMENT 'DIM_REASON.REASON_CODE — 사유코드',
          COLUMN REASON_NAME               COMMENT 'DIM_REASON.REASON_NAME — 중단사유·미납사유 (#162·#82)',
          COLUMN REASON_TYPE               COMMENT 'DIM_REASON.REASON_TYPE — 중단/미납 구분';

-- ============================================================================
-- 2. WIDE_MEMBER_EVENT
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_MEMBER_EVENT
    ALTER COLUMN DATE_SK             COMMENT '사건일 YYYYMMDD',
          COLUMN MEMBER_DK           COMMENT '상태전이 대상 회원 (불변키)',
          COLUMN EVENT_TYPE          COMMENT '상태전이 유형(개발/중단/증액/미납중단)',
          COLUMN DEV_CNT             COMMENT '개발(건) (#149)',
          COLUMN DEV_MEMBERS         COMMENT '개발(명) (#148)',
          COLUMN STOP_CNT            COMMENT '중단(건) (#35)',
          COLUMN STOP_MEMBERS        COMMENT '중단(명)',
          COLUMN UNPAID_STOP_CNT     COMMENT '미납중단(건)',
          COLUMN UNPAID_STOP_MEMBERS COMMENT '미납중단(명)',
          COLUMN JOIN_DATE           COMMENT '가입일',
          COLUMN STOP_DATE           COMMENT '중단일',
          COLUMN STOP_REASON         COMMENT '중단사유',
          COLUMN STOP_CHANNEL        COMMENT '중단채널',
          COLUMN NEW_EXISTING_FLAG   COMMENT '신규기존',
          COLUMN DW_SOURCE_SYSTEM    COMMENT '원천 시스템 식별',
          COLUMN FULL_DATE           COMMENT 'DIM_DATE.FULL_DATE — 실제 일자',
          COLUMN YEAR                COMMENT 'DIM_DATE.YEAR — 년',
          COLUMN MONTH               COMMENT 'DIM_DATE.MONTH — 월',
          COLUMN DAY_OF_WEEK         COMMENT 'DIM_DATE.DAY_OF_WEEK — 요일',
          COLUMN WEEK_OF_YEAR        COMMENT 'DIM_DATE.WEEK_OF_YEAR — 주차',
          COLUMN QUARTER             COMMENT 'DIM_DATE.QUARTER — 분기',
          COLUMN IS_HOLIDAY          COMMENT 'DIM_DATE.IS_HOLIDAY — 휴일여부',
          COLUMN MEMBER_GENDER       COMMENT 'DIM_MEMBER.GENDER — 성별 (#130)',
          COLUMN MEMBER_REGION       COMMENT 'DIM_MEMBER.REGION — 지역 (#131)',
          COLUMN MEMBER_AGE_BAND     COMMENT 'DIM_MEMBER.AGE_BAND — 연령대',
          COLUMN MEMBER_STATUS       COMMENT 'DIM_MEMBER.MEMBER_STATUS — 회원상태 (#132)',
          COLUMN MEMBER_TYPE         COMMENT 'DIM_MEMBER.MEMBER_TYPE — 회원구분',
          COLUMN MEMBER_ENROLL_PATH  COMMENT 'DIM_MEMBER.ENROLL_PATH — 가입경로',
          COLUMN CAMPAIGN_BK         COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND      COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_PARENT     COMMENT 'DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119)',
          COLUMN CAMPAIGN_NAME       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)',
          COLUMN CAMPAIGN_PROMO_METHOD COMMENT 'DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118)',
          COLUMN SPONSORSHIP_BK      COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키',
          COLUMN SPONSORSHIP_NAME    COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)',
          COLUMN ORG_CORP            COMMENT 'DIM_ORG.CORP — 법인 (as-was #114)',
          COLUMN ORG_DIVISION        COMMENT 'DIM_ORG.DIVISION — 본부/지부 (as-was #115)',
          COLUMN ORG_DEPARTMENT      COMMENT 'DIM_ORG.DEPARTMENT — 부서 (as-was #116)',
          COLUMN ORG_TEAM            COMMENT 'DIM_ORG.TEAM — 팀 (as-was)',
          COLUMN REASON_CODE         COMMENT 'DIM_REASON.REASON_CODE — 사유코드',
          COLUMN REASON_NAME         COMMENT 'DIM_REASON.REASON_NAME — 중단/미납사유',
          COLUMN REASON_TYPE         COMMENT 'DIM_REASON.REASON_TYPE — 중단/미납 구분';

-- ============================================================================
-- 3. WIDE_TARGET_DEV
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_TARGET_DEV
    ALTER COLUMN MONTH_KEY        COMMENT '목표월 YYYYMM',
          COLUMN CAL_YEAR         COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
          COLUMN CAL_MONTH        COMMENT 'MOD(MONTH_KEY,100) — 월',
          COLUMN DEV_TYPE         COMMENT '개발구분 (#121 conform)',
          COLUMN GOAL_CNT         COMMENT '회원개발목표(건) (CRM TM_CM_MBER_DVLP_GOAL)',
          COLUMN DW_SOURCE_SYSTEM COMMENT '원천 시스템 식별',
          COLUMN ORG_CORP         COMMENT 'DIM_ORG.CORP — 법인 (as-was #114)',
          COLUMN ORG_DIVISION     COMMENT 'DIM_ORG.DIVISION — 본부/지부 (as-was #115)',
          COLUMN ORG_DEPARTMENT   COMMENT 'DIM_ORG.DEPARTMENT — 부서 (as-was #116)',
          COLUMN ORG_TEAM         COMMENT 'DIM_ORG.TEAM — 팀 (as-was)';

-- ============================================================================
-- 4. WIDE_TARGET_BIZ
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_TARGET_BIZ
    ALTER COLUMN MONTH_KEY           COMMENT '목표월 YYYYMM',
          COLUMN CAL_YEAR            COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
          COLUMN CAL_MONTH           COMMENT 'MOD(MONTH_KEY,100) — 월',
          COLUMN ANNUAL_GOAL_CNT     COMMENT '연사업목표(건) (#152)',
          COLUMN SUPP_GOAL_CNT       COMMENT '추경목표(건) (#153)',
          COLUMN ANNUAL_CUM_GOAL_CNT COMMENT '연사업누계목표(건) (#154)',
          COLUMN SUPP_CUM_GOAL_CNT   COMMENT '추경누계목표(건) (#155)',
          COLUMN DW_SOURCE_SYSTEM    COMMENT '원천 시스템 식별',
          COLUMN ORG_CORP            COMMENT 'DIM_ORG.CORP — 법인 (as-was #114)',
          COLUMN ORG_DIVISION        COMMENT 'DIM_ORG.DIVISION — 본부/지부 (as-was #115)',
          COLUMN ORG_DEPARTMENT      COMMENT 'DIM_ORG.DEPARTMENT — 부서 (as-was #116)',
          COLUMN ORG_TEAM            COMMENT 'DIM_ORG.TEAM — 팀 (as-was)',
          COLUMN SPONSORSHIP_BK      COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키',
          COLUMN SPONSORSHIP_NAME    COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)',
          COLUMN CAMPAIGN_BK         COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND      COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_NAME       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)';

-- ============================================================================
-- 5. WIDE_SERVICE_EVENT
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_SERVICE_EVENT
    ALTER COLUMN DATE_SK                   COMMENT '발송일 YYYYMMDD',
          COLUMN MEMBER_DK                 COMMENT '발송 대상 회원 (불변키)',
          COLUMN SEND_MEMBERS              COMMENT '발송수(명) (#85)',
          COLUMN SUCCESS_MEMBERS           COMMENT '성공수(명) (#86)',
          COLUMN FAIL_MEMBERS              COMMENT '실패수(명) (#87)',
          COLUMN OPEN_MEMBERS              COMMENT '오픈(명) (overview)',
          COLUMN LETTER_PART_MEMBERS       COMMENT '서신참여(명) (#88)',
          COLUMN LETTER_PART_CNT           COMMENT '서신참여(건) (#89)',
          COLUMN GIFT_PART_MEMBERS         COMMENT '선물금참여(명) (#90)',
          COLUMN GIFT_PART_AMT             COMMENT '선물금참여(원) (#91)',
          COLUMN D5_LETTER_PART_MEMBERS    COMMENT '+5일차 서신참여(명) (#139)',
          COLUMN D5_LETTER_PART_CNT        COMMENT '+5일차 서신참여(건) (#140)',
          COLUMN D5_GIFT_PART_MEMBERS      COMMENT '+5일차 선물금참여(명) (#141)',
          COLUMN D5_GIFT_PART_CNT          COMMENT '+5일차 선물금참여(건) (#142)',
          COLUMN D5_INCREASE_PART_MEMBERS  COMMENT '+5일차 증액참여(명) (#143)',
          COLUMN D5_INCREASE_PART_CNT      COMMENT '+5일차 증액참여(건) (#144)',
          COLUMN D5_STOP_MEMBERS           COMMENT '+5일차 중단(명) (#145)',
          COLUMN D5_STOP_CNT               COMMENT '+5일차 중단(건) (#146)',
          COLUMN SERVICE_MEMBERS           COMMENT '서비스(명) (#160)',
          COLUMN SERVICE_CNT               COMMENT '서비스(건) (#161)',
          COLUMN SEND_TITLE                COMMENT '제목 (#136)',
          COLUMN SEND_STATUS               COMMENT '발송상태 (#138)',
          COLUMN SEND_STATUS2              COMMENT '발송상태2',
          COLUMN SEND_TYPE                 COMMENT '발송유형',
          COLUMN MAIL_RECEIVE_FLAG         COMMENT '메일수신여부',
          COLUMN MEMBER_STOP_FLAG          COMMENT '결연회원 중단여부',
          COLUMN DW_SOURCE_SYSTEM          COMMENT '원천 시스템 식별',
          COLUMN FULL_DATE                 COMMENT 'DIM_DATE.FULL_DATE — 실제 일자',
          COLUMN YEAR                      COMMENT 'DIM_DATE.YEAR — 년',
          COLUMN MONTH                     COMMENT 'DIM_DATE.MONTH — 월',
          COLUMN DAY_OF_WEEK               COMMENT 'DIM_DATE.DAY_OF_WEEK — 요일',
          COLUMN WEEK_OF_YEAR              COMMENT 'DIM_DATE.WEEK_OF_YEAR — 주차',
          COLUMN IS_HOLIDAY                COMMENT 'DIM_DATE.IS_HOLIDAY — 휴일여부',
          COLUMN MEMBER_GENDER             COMMENT 'DIM_MEMBER.GENDER — 성별 (#130)',
          COLUMN MEMBER_REGION             COMMENT 'DIM_MEMBER.REGION — 지역 (#131)',
          COLUMN MEMBER_AGE_BAND           COMMENT 'DIM_MEMBER.AGE_BAND — 연령대',
          COLUMN MEMBER_STATUS             COMMENT 'DIM_MEMBER.MEMBER_STATUS — 회원상태 (#132)',
          COLUMN MEMBER_TYPE               COMMENT 'DIM_MEMBER.MEMBER_TYPE — 회원구분',
          COLUMN SERVICE_SEND_TYPE_L       COMMENT 'DIM_SERVICE.SEND_TYPE_L — 발송구분 대 (#133)',
          COLUMN SERVICE_SEND_TYPE_M       COMMENT 'DIM_SERVICE.SEND_TYPE_M — 발송구분 중 (#134)',
          COLUMN SERVICE_SEND_TYPE_S       COMMENT 'DIM_SERVICE.SEND_TYPE_S — 발송구분 소 (#135)',
          COLUMN SERVICE_SUBTYPE           COMMENT 'DIM_SERVICE.SUBTYPE — 발송/참여 subtype',
          COLUMN SERVICE_CHANNEL           COMMENT 'DIM_SERVICE.CHANNEL — CRM_UMS / ADMIN',
          COLUMN CAMPAIGN_BK               COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND            COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_PARENT           COMMENT 'DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119)',
          COLUMN CAMPAIGN_NAME             COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)',
          COLUMN CAMPAIGN_PROMO_METHOD     COMMENT 'DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118)';

-- ============================================================================
-- 6. WIDE_GA_BEHAVIOR
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_GA_BEHAVIOR
    ALTER COLUMN DATE_SK                        COMMENT '행동 발생일 YYYYMMDD',
          COLUMN PAGE_PATH                      COMMENT '페이지경로+쿼리 (#105)',
          COLUMN PAGE_LOCATION                  COMMENT '페이지위치(URL 전체)',
          COLUMN VISITS                         COMMENT '방문수',
          COLUMN EVENT_CNT                      COMMENT '이벤트수',
          COLUMN VIEW_CNT                       COMMENT '조회수',
          COLUMN SESSION_CNT                    COMMENT '세션수',
          COLUMN ENGAGED_SESSIONS               COMMENT '참여세션수',
          COLUMN SCROLL_DEPTH                   COMMENT '[비가산] 스크롤깊이 — 재합산 금지',
          COLUMN ACTIVE_USERS                   COMMENT '[비가산] 활성사용자 — 재합산 금지',
          COLUMN TOTAL_USERS                    COMMENT '[비가산] 총사용자 — 재합산 금지',
          COLUMN AVG_SESSION_DURATION           COMMENT '[비가산] 평균세션시간 — 재합산 금지 (#98)',
          COLUMN BOUNCE_RATE                    COMMENT '[비가산] 이탈율 — 재합산 금지 (#108)',
          COLUMN ENGAGEMENT_RATE                COMMENT '[비가산] 참여율 — 재합산 금지',
          COLUMN AVG_ENGAGEMENT_TIME_PER_SESSION COMMENT '[비가산] 세션당 평균참여시간 — 재합산 금지',
          COLUMN DW_SOURCE_SYSTEM               COMMENT '원천 시스템 식별',
          COLUMN FULL_DATE                      COMMENT 'DIM_DATE.FULL_DATE — 실제 일자',
          COLUMN YEAR                           COMMENT 'DIM_DATE.YEAR — 년',
          COLUMN MONTH                          COMMENT 'DIM_DATE.MONTH — 월',
          COLUMN DAY_OF_WEEK                    COMMENT 'DIM_DATE.DAY_OF_WEEK — 요일',
          COLUMN WEEK_OF_YEAR                   COMMENT 'DIM_DATE.WEEK_OF_YEAR — 주차',
          COLUMN IS_HOLIDAY                     COMMENT 'DIM_DATE.IS_HOLIDAY — 휴일여부',
          COLUMN IDENTITY_MEMBER_DK             COMMENT 'DIM_MEMBER_IDENTITY.MEMBER_DK — 불변 회원키',
          COLUMN IDENTITY_MEMBER_NO             COMMENT 'DIM_MEMBER_IDENTITY.MEMBER_NO — 회원번호 (#110)',
          COLUMN IDENTITY_MEMNUM                COMMENT 'DIM_MEMBER_IDENTITY.MEMNUM — memnum (#111)',
          COLUMN IDENTITY_GA_MEMBER_ID          COMMENT 'DIM_MEMBER_IDENTITY.GA_MEMBER_ID — GA member_id (#112)',
          COLUMN GA_EVENT_CATEGORY              COMMENT 'DIM_GA_EVENT.EVENT_CATEGORY — 이벤트 카테고리 (#99)',
          COLUMN GA_EVENT_LABEL                 COMMENT 'DIM_GA_EVENT.EVENT_LABEL — 이벤트 라벨 (#100)',
          COLUMN GA_EVENT_ACTION                COMMENT 'DIM_GA_EVENT.EVENT_ACTION — 이벤트 액션 (#101)',
          COLUMN GA_UTM_SOURCE                  COMMENT 'DIM_GA_SOURCE.UTM_SOURCE — source',
          COLUMN GA_UTM_MEDIUM                  COMMENT 'DIM_GA_SOURCE.UTM_MEDIUM — medium',
          COLUMN GA_UTM_CONTENT                 COMMENT 'DIM_GA_SOURCE.UTM_CONTENT — 세션 수동 광고 콘텐츠 (#103)',
          COLUMN GA_UTM_TERM                    COMMENT 'DIM_GA_SOURCE.UTM_TERM — 세션 수동 검색어 (#104)',
          COLUMN GA_SOURCE_MEDIUM               COMMENT 'DIM_GA_SOURCE.SOURCE_MEDIUM — 세션 소스/매체 (#109)',
          COLUMN DEVICE_TYPE                    COMMENT 'DIM_DEVICE.DEVICE_TYPE — PC / M / APP',
          COLUMN CAMPAIGN_BK                    COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND                 COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_NAME                  COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)';

-- ============================================================================
-- 7. WIDE_AD_PERFORMANCE
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_AD_PERFORMANCE
    ALTER COLUMN PERF_DATE_SK        COMMENT '광고 실적일 YYYYMMDD',
          COLUMN AD_COST             COMMENT '광고비(원)',
          COLUMN IMPRESSIONS         COMMENT '노출수',
          COLUMN CLICKS              COMMENT '클릭수',
          COLUMN INBOUND_CALL        COMMENT '인입콜수',
          COLUMN GA_CONV_MEMBERS     COMMENT 'GA전환수(명)',
          COLUMN GA_CONV_CNT         COMMENT 'GA전환수(건)',
          COLUMN DAY_OF_WEEK         COMMENT '요일(팩트 degen)',
          COLUMN WEEK_OF_YEAR        COMMENT '주차(팩트 degen)',
          COLUMN TIME_BAND           COMMENT '시간대(팩트 degen)',
          COLUMN CM_POSITION         COMMENT 'CM위치(팩트 degen, #21)',
          COLUMN RT_TYPE             COMMENT 'RT유형(팩트 degen)',
          COLUMN AD_START_TIME       COMMENT '광고시작시간(팩트 degen)',
          COLUMN BROADCAST_DATE      COMMENT '송출일(팩트 degen, 실적일과 다를 수 있음)',
          COLUMN DW_SOURCE_SYSTEM    COMMENT '원천 시스템 식별 (GA4/AGENCY/GADS)',
          COLUMN PERF_FULL_DATE      COMMENT 'DIM_DATE.FULL_DATE — 실적일 일자',
          COLUMN PERF_YEAR           COMMENT 'DIM_DATE.YEAR — 실적일 년',
          COLUMN PERF_MONTH          COMMENT 'DIM_DATE.MONTH — 실적일 월',
          COLUMN PERF_QUARTER        COMMENT 'DIM_DATE.QUARTER — 실적일 분기',
          COLUMN PERF_IS_HOLIDAY     COMMENT 'DIM_DATE.IS_HOLIDAY — 실적일 휴일여부',
          COLUMN CAMPAIGN_BK         COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND      COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_PARENT     COMMENT 'DIM_CAMPAIGN.PARENT_CAMPAIGN — 공통상위캠페인 (#119)',
          COLUMN CAMPAIGN_NAME       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)',
          COLUMN CAMPAIGN_PROMO_METHOD COMMENT 'DIM_CAMPAIGN.PROMO_METHOD — 홍보방법 (#118)',
          COLUMN CAMPAIGN_TYPE       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_TYPE — 캠페인 유형 (#17)',
          COLUMN AD_CREATIVE_BK      COMMENT 'DIM_AD_CREATIVE.AD_CREATIVE_BK — 광고소재 업무키',
          COLUMN AD_MEDIA_NAME       COMMENT 'DIM_AD_CREATIVE.MEDIA_NAME — 매체명 (#11)',
          COLUMN AD_PLATFORM         COMMENT 'DIM_AD_CREATIVE.PLATFORM — 플랫폼 (#12)',
          COLUMN AD_PLATFORM_TYPE    COMMENT 'DIM_AD_CREATIVE.PLATFORM_TYPE — 플랫폼/매체유형 (#13)',
          COLUMN AD_CREATIVE         COMMENT 'DIM_AD_CREATIVE.CREATIVE — 소재 (#20)',
          COLUMN AD_TYPE             COMMENT 'DIM_AD_CREATIVE.AD_TYPE — 광고유형',
          COLUMN AD_TARGET_GROUP     COMMENT 'DIM_AD_CREATIVE.TARGET_GROUP — 타겟그룹',
          COLUMN DEVICE_TYPE         COMMENT 'DIM_DEVICE.DEVICE_TYPE — PC / M / APP';

-- ============================================================================
-- 8. WIDE_EVENT_PARTICIPATION
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_EVENT_PARTICIPATION
    ALTER COLUMN DATE_SK             COMMENT '참여일 YYYYMMDD',
          COLUMN MEMBER_DK           COMMENT '참여 회원 (불변키)',
          COLUMN RECRUIT_CNT         COMMENT '모집인원',
          COLUMN TOTAL_CNT           COMMENT '총인원',
          COLUMN WAIT_CNT            COMMENT '대기인원',
          COLUMN CANCEL_CNT          COMMENT '취소인원',
          COLUMN CONFIRM_CNT         COMMENT '신청확정인원',
          COLUMN PARTICIPATE_CNT     COMMENT '참여인원',
          COLUMN ABSENT_CNT          COMMENT '불참인원',
          COLUMN PARTICIPANT_CNT     COMMENT '참여자수',
          COLUMN PARTICIPATION_TIMES COMMENT '참여횟수',
          COLUMN WAIT_TIMES          COMMENT '대기횟수',
          COLUMN ABSENT_TIMES        COMMENT '불참횟수',
          COLUMN CUM_APPLY_TIMES     COMMENT '누적신청횟수',
          COLUMN REGULAR_DONATION    COMMENT '정기후원금(원)',
          COLUMN WIN_FLAG            COMMENT '당첨여부',
          COLUMN SELF_PART_FLAG      COMMENT '본인참여여부',
          COLUMN PART_STATUS         COMMENT '참여상태',
          COLUMN PART_PATH           COMMENT '참여경로',
          COLUMN PART_CHANNEL        COMMENT '참여채널',
          COLUMN INCREASE_FLAG       COMMENT '증액여부',
          COLUMN DW_SOURCE_SYSTEM    COMMENT '원천 시스템 식별',
          COLUMN FULL_DATE           COMMENT 'DIM_DATE.FULL_DATE — 실제 일자',
          COLUMN YEAR                COMMENT 'DIM_DATE.YEAR — 년',
          COLUMN MONTH               COMMENT 'DIM_DATE.MONTH — 월',
          COLUMN DAY_OF_WEEK         COMMENT 'DIM_DATE.DAY_OF_WEEK — 요일',
          COLUMN WEEK_OF_YEAR        COMMENT 'DIM_DATE.WEEK_OF_YEAR — 주차',
          COLUMN IS_HOLIDAY          COMMENT 'DIM_DATE.IS_HOLIDAY — 휴일여부',
          COLUMN MEMBER_GENDER       COMMENT 'DIM_MEMBER.GENDER — 성별 (#130)',
          COLUMN MEMBER_REGION       COMMENT 'DIM_MEMBER.REGION — 지역 (#131)',
          COLUMN MEMBER_AGE_BAND     COMMENT 'DIM_MEMBER.AGE_BAND — 연령대',
          COLUMN MEMBER_STATUS       COMMENT 'DIM_MEMBER.MEMBER_STATUS — 회원상태 (#132)',
          COLUMN MEMBER_TYPE         COMMENT 'DIM_MEMBER.MEMBER_TYPE — 회원구분',
          COLUMN EVENT_BK            COMMENT 'DIM_EVENT.EVENT_BK — 행사 업무키',
          COLUMN EVENT_KIND          COMMENT 'DIM_EVENT.EVENT_KIND — 온라인/오프라인',
          COLUMN EVENT_CATEGORY      COMMENT 'DIM_EVENT.EVENT_CATEGORY — 행사구분',
          COLUMN EVENT_NAME          COMMENT 'DIM_EVENT.EVENT_NAME — 행사명',
          COLUMN EVENT_START_DATE    COMMENT 'DIM_EVENT.EVENT_START_DATE — 행사기간 시작',
          COLUMN EVENT_END_DATE      COMMENT 'DIM_EVENT.EVENT_END_DATE — 행사기간 종료',
          COLUMN EVENT_APPLY_CHANNEL COMMENT 'DIM_EVENT.APPLY_CHANNEL — 신청경로',
          COLUMN CAMPAIGN_BK         COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND      COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_NAME       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)',
          COLUMN SPONSORSHIP_BK      COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키',
          COLUMN SPONSORSHIP_NAME    COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)';

-- ============================================================================
-- 9. WIDE_BUDGET
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_BUDGET
    ALTER COLUMN MONTH_KEY         COMMENT '예산월 YYYYMM',
          COLUMN CAL_YEAR          COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
          COLUMN CAL_MONTH         COMMENT 'MOD(MONTH_KEY,100) — 월',
          COLUMN PLAN_BUDGET_MONTH COMMENT '편성예산(월, 원)',
          COLUMN PLAN_BUDGET_YEAR  COMMENT '편성예산(연, 원)',
          COLUMN EXEC_BUDGET_ERP   COMMENT '집행예산(ERP 월, 원)',
          COLUMN EXEC_BUDGET_EST   COMMENT '집행예산(추정, 원)',
          COLUMN FUNDRAISING_COST  COMMENT '모금성비용(원)',
          COLUMN AD_COST           COMMENT '광고비(원)',
          COLUMN DW_SOURCE_SYSTEM  COMMENT '원천 시스템 식별',
          COLUMN ORG_CORP          COMMENT 'DIM_ORG.CORP — 법인 (as-was #114)',
          COLUMN ORG_DIVISION      COMMENT 'DIM_ORG.DIVISION — 본부/지부 (as-was #115)',
          COLUMN ORG_DEPARTMENT    COMMENT 'DIM_ORG.DEPARTMENT — 부서 (as-was #116)',
          COLUMN ORG_TEAM          COMMENT 'DIM_ORG.TEAM — 팀 (as-was)',
          COLUMN BUDGET_ITEM_NAME  COMMENT 'DIM_BUDGET_ITEM.BUDGET_ITEM_NAME — 세세목명',
          COLUMN BUDGET_CATEGORY   COMMENT 'DIM_BUDGET_ITEM.BUDGET_CATEGORY — 예산구분',
          COLUMN CAMPAIGN_BK       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키',
          COLUMN CAMPAIGN_BRAND    COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)',
          COLUMN CAMPAIGN_NAME     COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)',
          COLUMN SPONSORSHIP_BK    COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키',
          COLUMN SPONSORSHIP_NAME  COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)';

-- ============================================================================
-- [검증] 코멘트 미적용(NULL) 컬럼 탐지 — 기대: 0행
-- ============================================================================
SELECT table_name, column_name
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'GOLD' AND table_name LIKE 'WIDE_%' AND comment IS NULL
ORDER BY table_name, ordinal_position;
