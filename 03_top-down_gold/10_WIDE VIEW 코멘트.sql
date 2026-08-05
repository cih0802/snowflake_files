-- GN_DW.GOLD WIDE VIEW 12개의 뷰 컬럼 COMMENT를 ALTER VIEW로 일괄 적용하는 스크립트.
-- Co-authored with CoCo
-- ✅ [2026-07-20 적용 완료] GOLD 배포·적재 후 본 스크립트 실행 완료(9뷰 330컬럼 COMMENT 적용). idempotent — 재실행 안전.
-- ✅ [2026-07-28 순서9-I 확장·적용 완료] AGENCY 광고 위성 팩트 3종(DEC-8)에 맞춰 **9뷰 → 12뷰**로 확장.
--    실행 검증: ALTER VIEW 12/12 성공(컬럼명 오류 0) · 실측 **12뷰 411컬럼 전량 COMMENT 적용(누락 0)**.
--    · 7   WIDE_AD_PERFORMANCE  = 코어화(방송 degen 5종 제거 · AD_PERF_DK·AD_SOURCE_TYPE·DEVICE_SCOPE_DESC 추가)
--    · 7-A WIDE_AD_BROADCAST      (신설, 1:1)  · 7-B WIDE_AD_DIGITAL (신설, 1:1)
--    · 7-C WIDE_AD_BROADCAST_CASE (신설, 1:N — 코어 measure 미노출)
--    ⚠️ dbt 모델 `models/gold/wide/*.sql` 의 post_hook 과 **내용 동일(verbatim 대응)**. 한쪽만 고치면 drift.
-- 🔷 [2026-07-07 정정] DIM_ORG = SCD1 (DEC-2): 조직 변경이력 소스·as-was 요구 없음 → EFFECTIVE_*/IS_CURRENT 컬럼 삭제.
--    아래 ORG_CORP/DIVISION/DEPARTMENT/TEAM COMMENT의 "(as-was)" 표기는 SCD1 정정 이전 잔재이며, 실제 의미는 current-value(최신 조직명·계층)임.

/*
================================================================================
  GN_DW.GOLD — WIDE VIEW 컬럼 COMMENT
  적용 대상  : WIDE_MEMBER_MONTHLY / WIDE_MEMBER_EVENT / WIDE_TARGET_DEV /
               WIDE_DEV_ACHIEVEMENT(신설 2026-08-05 O38) /
               WIDE_TARGET_BIZ / WIDE_SERVICE_EVENT / WIDE_GA_BEHAVIOR /
               WIDE_AD_PERFORMANCE / WIDE_AD_BROADCAST / WIDE_AD_DIGITAL /
               WIDE_AD_BROADCAST_CASE / WIDE_EVENT_PARTICIPATION / WIDE_BUDGET
--------------------------------------------------------------------------------
  실행 전제 / 정책
  ─────────────────────────────────────────────────────────────────────────────
  1. 09_빅테이블 VIEW.md DDL로 12개 VIEW가 먼저 생성돼 있어야 함.
  2. 뷰 컬럼 COMMENT는 반드시 ALTER VIEW ... ALTER COLUMN ... COMMENT 사용.
     ※ COMMENT ON COLUMN 은 TABLE 전용 — 뷰에 쓰면
       "Object found is of type 'VIEW', not specified type 'TABLE'" 오류.
  3. 뷰당 1개 ALTER 문(멀티컬럼)으로 원자 적용 + 재실행 가능(idempotent).
     한 컬럼명이라도 틀리면 그 뷰 전체가 실패 → 컬럼명은 실제 뷰 기준(검증 완료).
  4. alias DIM 컬럼은 "원본DIM.컬럼 — 설명 (#지표번호)" 로 출처 명시.
  5. 파생 컬럼(CAL_YEAR·CAL_MONTH)은 계산식 포함. 비가산 지표는 "[비가산]" 접두.
     대행사 산정 파생(`_SRC`, DEC-9)은 "비가산 N" + DW 재계산식을 함께 기재.
  6. 전 12개 뷰 실객체 대상 실행 검증 완료(오류 0 · 2026-07-28 재검증).
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
-- 3-A. WIDE_DEV_ACHIEVEMENT  [신설 2026-08-05 O38 — 목표 대비 실적]
--   설계 근거·실측치 = dbt 모델 헤더 + 09_빅테이블 VIEW.md §3-A. 정본 SQL 은 dbt 모델이다.
--   🔴 [2026-08-05 후속] 플래그를 **HAS_GOAL_ROW(행 존재) / HAS_POSITIVE_GOAL(값 편성)** 로 분리했다.
--      종전 단일 `HAS_GOAL` 은 이름이 「목표 편성」으로 읽혀 달성율 분자 스코프에 오용됐고
--      목표 0 행의 실적이 분모 없이 분자에 들어가 비율이 폭증했다. COMMENT 교정만으로는
--      이름이 계속 오해를 부르므로 **개명**으로 구조에서 막았다.
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_DEV_ACHIEVEMENT
    ALTER COLUMN MONTH_KEY        COMMENT '목표·실적 공통 월키 YYYYMM (월 conform 축)',
          COLUMN CAL_YEAR         COMMENT 'FLOOR(MONTH_KEY/100) — 연도',
          COLUMN CAL_MONTH        COMMENT 'MOD(MONTH_KEY,100) — 월',
          COLUMN ORG_SK           COMMENT '조직 대리키 (FK→DIM_ORG). 실적측은 실적부서(ACMSLT_DEPT_CD) 기준',
          COLUMN ORG_DEPARTMENT   COMMENT '부서명 (정본 #116) — 장표 첫 축. DIM_ORG.DEPARTMENT',
          COLUMN ORG_DIVISION     COMMENT 'DIM_ORG.DIVISION — 실적지부. ⚠️산출규칙 미확정으로 전건 NULL (CONF-4)',
          COLUMN ORG_TEAM         COMMENT 'DIM_ORG.TEAM — 팀. ⚠️보류로 전건 NULL (CONF-4)',
          COLUMN ORG_CORP         COMMENT 'DIM_ORG.CORP — 법인. ⚠️부서 차원에서 산출 불가로 전건 NULL (CONF-4)',
          COLUMN DEV_TYPE         COMMENT '개발구분 코드 (MM015 중 1신규·2증액·4재후원). 정본 공#121 개발 정의와 일치하는 축 — 목표·실적 공통',
          COLUMN DEV_TYPE_NAME    COMMENT '개발구분명 (MM015 라벨). 코드는 DEV_TYPE',
          COLUMN GOAL_CNT         COMMENT '월 회원개발목표(건) — 장표 「월 목표」. 원천 CRM TM_CM_MBER_DVLP_GOAL',
          COLUMN ACTUAL_CNT       COMMENT '월 개발실적(건) — 장표 「월 실적」. FME.DEV_CNT 월 롤업(코드 1·2·4 한정)',
          COLUMN GOAL_CNT_YTD     COMMENT '(누계)월 목표(건) — 당해년 1월~당월 누적. 🔴월 비가산 — 월을 가로질러 합산 금지',
          COLUMN ACTUAL_CNT_YTD   COMMENT '(누계)월 실적(건) — 당해년 1월~당월 누적. 🔴월 비가산',
          COLUMN GOAL_CNT_YEAR    COMMENT '연 목표(건) — 당해년 12개월 합. 별도 저장 지표가 아니라 월 목표의 연 합계다(정본 공#3). 🔴월 비가산',
          COLUMN ACTUAL_CNT_YEAR  COMMENT '연 실적(건) — 당해년 12개월 합. 🔴월 비가산',
          COLUMN HAS_GOAL_ROW     COMMENT '목표 **행**의 존재 여부 — 값이 0 이거나 NULL 이어도 TRUE 다. 🔴**달성율 스코프로 쓰지 말 것**: 원천이 2020년부터 부서×월×개발구분 조합을 전량 행 생성하고 미편성분을 0 으로 채우므로 목표 행의 과반이 0 이다. 이 플래그로 분자를 스코프하면 목표 0 행의 실적이 분모 없이 분자에 들어가 달성율이 폭증한다(실측 확인 후 교정). 달성율은 HAS_POSITIVE_GOAL 을 쓴다. 이 컬럼의 용도는 「목표 행 자체가 없는 조합」(=FALSE)을 찾는 것이다',
          COLUMN HAS_POSITIVE_GOAL COMMENT '🟢**목표가 실제로 편성됐는지**(GOAL_CNT>0) — 달성율 분모·분자 스코프의 **정본**이다. 목표 미편성 부서·월의 실적이 분자에 섞이면 달성율이 조용히 과대해진다(P18·P63). SV_DEV_ACHIEVEMENT.ACHIEVEMENT_RATE 는 이 조건을 식에 못박아 두었으므로 소비 시 별도 필터가 불필요하다. ⚠️FALSE 는 「목표 0 건으로 명시」와 「목표 미입력(원천 NULL)」을 함께 담는다 — 구분이 필요하면 FACT_TARGET_DEV.GOAL_CNT IS NULL 로 팩트에서 본다',
          COLUMN HAS_ACTUAL       COMMENT '실적 발생 여부. FALSE 는 목표만 편성된 월(미래월 포함)이다 — 실적 0 으로 읽되 「미달」로 단정하지 말 것';
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
-- 7. WIDE_AD_PERFORMANCE (코어)
--    ⚠️ [2026-07-28 순서9-I DEC-8] 방송 degen 5종(TIME_BAND·CM_POSITION·RT_TYPE·
--       AD_START_TIME·BROADCAST_DATE)은 위성 WIDE_AD_BROADCAST 로 이관 → 본 뷰에서 제거.
--    ⚠️ DEC-12 명명 분리: AD_SOURCE_TYPE(원천 출처축) ≠ AD_CREATIVE_TYPE(소재 광고유형).
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_AD_PERFORMANCE
    ALTER COLUMN AD_PERF_DK          COMMENT '광고성과 행 식별자(grain) — 위성 뷰 조인키',
          COLUMN PERF_DATE_SK        COMMENT '광고 실적일 YYYYMMDD',
          COLUMN AD_COST             COMMENT '광고비(원)',
          COLUMN IMPRESSIONS         COMMENT '노출수(디지털 전용)',
          COLUMN CLICKS              COMMENT '클릭수(디지털 전용)',
          COLUMN INBOUND_CALL        COMMENT '인입콜수',
          COLUMN GA_CONV_MEMBERS     COMMENT 'GA전환수(명) — 디지털 전용(O16 교정: 재방송 개발실적 제외)',
          COLUMN GA_CONV_CNT         COMMENT 'GA전환수(건/VU) — 디지털 전용(O16 교정: 재방송 개발실적 제외)',
          COLUMN DAY_OF_WEEK         COMMENT '요일(팩트 degen)',
          COLUMN WEEK_OF_YEAR        COMMENT '주차(팩트 degen)',
          COLUMN AD_SOURCE_TYPE      COMMENT '광고 원천유형 DIGITAL/VIDEO/REBROADCAST — 출처 명시축(팩트 degen, DEC-8)',
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
          COLUMN AD_CREATIVE_TYPE    COMMENT 'DIM_AD_CREATIVE.AD_TYPE — 소재 광고유형 (⚠️AD_SOURCE_TYPE 과 다른 개념)',
          COLUMN AD_TARGET_GROUP     COMMENT 'DIM_AD_CREATIVE.TARGET_GROUP — 타겟그룹',
          COLUMN DEVICE_TYPE         COMMENT 'DIM_DEVICE.DEVICE_TYPE — PC / M / (해당없음)방송 / (unknown)',
          COLUMN DEVICE_SCOPE_DESC   COMMENT 'DIM_DEVICE.DEVICE_SCOPE_DESC — 기기축 적용범위 자기설명(DEC-10)';

-- ============================================================================
-- 7-A. WIDE_AD_BROADCAST  [순서9-I 신설] 방송광고 위성(1:1)
--      코어 measure 동반 노출(DEC-13) — ⚠️코어 뷰와 합산 시 이중계상.
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_AD_BROADCAST
    ALTER COLUMN AD_PERF_DK          COMMENT '광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키',
          COLUMN AD_SOURCE_TYPE      COMMENT '광고 원천유형 VIDEO/REBROADCAST (본 뷰는 방송 2종만)',
          COLUMN PERF_DATE_SK        COMMENT '광고 실적일 YYYYMMDD',
          COLUMN AD_COST             COMMENT '[코어] 광고비(원) — VIDEO=실집행·REBRDC=편성비용',
          COLUMN INBOUND_CALL        COMMENT '[코어] 인입콜수',
          COLUMN TIME_BAND           COMMENT '시간대',
          COLUMN CM_POSITION         COMMENT 'CM위치 (VIDEO 전용)',
          COLUMN RT_TYPE             COMMENT 'RT(재방송)유형 (REBRDC 전용)',
          COLUMN AD_START_TIME       COMMENT '광고시작시간 (VIDEO 전용)',
          COLUMN AD_END_TIME         COMMENT '광고종료시간 (VIDEO 전용)',
          COLUMN BROADCAST_DATE      COMMENT '송출일 — 실적일(PERF_DATE_SK)과 다를 수 있음',
          COLUMN PROGRAM_NM          COMMENT '프로그램/편성명',
          COLUMN CHANNEL_COMPANY     COMMENT '채널사',
          COLUMN CHANNEL_COMPANY_TYPE COMMENT '채널사유형 (VIDEO 전용)',
          COLUMN SPOT_TYPE           COMMENT 'SPOT유형 (VIDEO 전용)',
          COLUMN DURATION_SEC        COMMENT '광고 초수 (VIDEO 전용)',
          COLUMN DAY_DIV             COMMENT '요일구분 평일/주말 (VIDEO 전용)',
          COLUMN PRG_START_TIME      COMMENT '프로그램 시작시간 (VIDEO 전용)',
          COLUMN CTV_DIV             COMMENT 'CTV구분 (VIDEO 전용)',
          COLUMN BRDC_DIV            COMMENT '방송구분 (REBRDC 전용)',
          COLUMN AD_CNT              COMMENT '광고횟수',
          COLUMN CONV_CALL_CNT       COMMENT '전환콜 (VIDEO 전용) — 인입콜과 별개',
          COLUMN DVLP_MEMBER_CNT     COMMENT '개발회원수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리)',
          COLUMN DVLP_CNT            COMMENT '개발건수 (REBRDC 전용) — ⚠️GA 전환이 아님(O16 분리)',
          COLUMN AD_VIEW_RT_SRC      COMMENT '광고시청률(대행사 산정) — 비가산 N, 재합산 금지',
          COLUMN CPC_SRC             COMMENT 'CPC(대행사 산정) — 비가산 N, 재합산 금지',
          COLUMN DW_SOURCE_SYSTEM    COMMENT '원천 시스템 식별',
          COLUMN PERF_FULL_DATE      COMMENT 'DIM_DATE.FULL_DATE — 실적일 일자',
          COLUMN PERF_YEAR           COMMENT 'DIM_DATE.YEAR — 실적일 년',
          COLUMN PERF_MONTH          COMMENT 'DIM_DATE.MONTH — 실적일 월',
          COLUMN PERF_QUARTER        COMMENT 'DIM_DATE.QUARTER — 실적일 분기',
          COLUMN PERF_IS_HOLIDAY     COMMENT 'DIM_DATE.IS_HOLIDAY — 실적일 휴일여부',
          COLUMN CAMPAIGN_NAME       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명',
          COLUMN AD_MEDIA_NAME       COMMENT 'DIM_AD_CREATIVE.MEDIA_NAME — 매체명',
          COLUMN AD_CREATIVE         COMMENT 'DIM_AD_CREATIVE.CREATIVE — 소재';

-- ============================================================================
-- 7-B. WIDE_AD_DIGITAL  [순서9-I 신설] 디지털광고 위성(1:1)
--      코어 measure 동반 노출(DEC-13) · _SRC 전량 비가산 N(DEC-9).
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_AD_DIGITAL
    ALTER COLUMN AD_PERF_DK          COMMENT '광고성과 행 식별자(grain) — 코어 WIDE_AD_PERFORMANCE 조인키',
          COLUMN AD_SOURCE_TYPE      COMMENT '광고 원천유형 — 본 뷰는 DIGITAL 만',
          COLUMN PERF_DATE_SK        COMMENT '광고 실적일 YYYYMMDD',
          COLUMN AD_COST             COMMENT '[코어] GA 광고비(원)',
          COLUMN IMPRESSIONS         COMMENT '[코어] 노출수 — CTR 분모',
          COLUMN CLICKS              COMMENT '[코어] 클릭수 — CTR 분자',
          COLUMN GA_CONV_MEMBERS     COMMENT '[코어] GA전환수(명) — CVR 분자(O16 교정 후 디지털 전용)',
          COLUMN GA_CONV_CNT         COMMENT '[코어] GA전환수(건/VU) — CPA 분모(O16 교정 후 디지털 전용)',
          COLUMN PAGE_TYPE           COMMENT '페이지유형',
          COLUMN AD_GROUP_NM         COMMENT '광고그룹명',
          COLUMN GROUP_DIV           COMMENT '그룹구분',
          COLUMN CREATIVE_TYPE       COMMENT '소재유형(원천 표기)',
          COLUMN AD_TYPE_NM          COMMENT '광고유형명(대행사 표기) — ⚠️AD_SOURCE_TYPE 과 다른 개념',
          COLUMN READ_CNT           COMMENT '읽음수',
          COLUMN MEDIA_POTENTIAL_CUST_CNT COMMENT '매체 잠재고객수',
          COLUMN CRM_DEV_CNT         COMMENT 'CRM 개발건수',
          COLUMN CTR_SRC             COMMENT 'CTR(대행사 산정) — 비가산 N. DW 재계산=SUM(CLICKS)/SUM(IMPRESSIONS)',
          COLUMN CVR_SRC             COMMENT 'CVR(대행사 산정) — 비가산 N. DW 재계산=SUM(GA_CONV_MEMBERS)/SUM(CLICKS)',
          COLUMN CPC_SRC             COMMENT 'CPC(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(CLICKS)',
          COLUMN CPM_SRC             COMMENT 'CPM(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(IMPRESSIONS)*1000',
          COLUMN CPA_SRC             COMMENT 'CPA(대행사 산정) — 비가산 N. DW 재계산=SUM(AD_COST)/SUM(GA_CONV_CNT)',
          COLUMN DEV_UNIT_PRICE_SRC  COMMENT '개발단가(대행사 산정) — 비가산 N',
          COLUMN VTR_SRC             COMMENT 'VTR(대행사 산정) — 비가산 N, base 부재로 재계산 불가',
          COLUMN DW_SOURCE_SYSTEM    COMMENT '원천 시스템 식별',
          COLUMN PERF_FULL_DATE      COMMENT 'DIM_DATE.FULL_DATE — 실적일 일자',
          COLUMN PERF_YEAR           COMMENT 'DIM_DATE.YEAR — 실적일 년',
          COLUMN PERF_MONTH          COMMENT 'DIM_DATE.MONTH — 실적일 월',
          COLUMN PERF_QUARTER        COMMENT 'DIM_DATE.QUARTER — 실적일 분기',
          COLUMN PERF_IS_HOLIDAY     COMMENT 'DIM_DATE.IS_HOLIDAY — 실적일 휴일여부',
          COLUMN CAMPAIGN_NAME       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명',
          COLUMN AD_MEDIA_NAME       COMMENT 'DIM_AD_CREATIVE.MEDIA_NAME — 매체명',
          COLUMN AD_CREATIVE         COMMENT 'DIM_AD_CREATIVE.CREATIVE — 소재',
          COLUMN DEVICE_TYPE         COMMENT 'DIM_DEVICE.DEVICE_TYPE — M / PC (디지털은 기기 실존)';

-- ============================================================================
-- 7-C. WIDE_AD_BROADCAST_CASE  [순서9-I 신설] 재방송 사례 위성(코어에 1:N)
--      ⚠️ 코어 measure 미노출(DEC-13 1:N 규칙 — fan-out 방지). 분포 분석 전용.
-- ============================================================================
ALTER VIEW GN_DW.GOLD.WIDE_AD_BROADCAST_CASE
    ALTER COLUMN AD_PERF_DK          COMMENT 'grain 1/2 · 광고성과 행 식별자 — 코어 WIDE_AD_PERFORMANCE 조인키(1:N)',
          COLUMN CASE_SEQ            COMMENT 'grain 2/2 · 사례 순번 1~3 (원천 CASE1~CASE3 언피벗축)',
          COLUMN AD_SOURCE_TYPE      COMMENT '광고 원천유형 — 본 뷰는 REBROADCAST 만',
          COLUMN PERF_DATE_SK        COMMENT '광고 실적일 YYYYMMDD',
          COLUMN BIZ_DIV             COMMENT '사례 사업구분',
          COLUMN FAMILY_TYPE         COMMENT '사례 가족유형',
          COLUMN APPEAL_POINT        COMMENT '사례 어필포인트',
          COLUMN CASE_DIV            COMMENT '사례구분',
          COLUMN RT_TYPE             COMMENT 'RT(재방송)유형 — 위성 FAD_B 에서 동반',
          COLUMN PROGRAM_NM          COMMENT '프로그램/편성명 — 위성 FAD_B 에서 동반',
          COLUMN CHANNEL_COMPANY     COMMENT '채널사 — 위성 FAD_B 에서 동반',
          COLUMN BROADCAST_DATE      COMMENT '송출일 — 위성 FAD_B 에서 동반',
          COLUMN DW_SOURCE_SYSTEM    COMMENT '원천 시스템 식별',
          COLUMN PERF_FULL_DATE      COMMENT 'DIM_DATE.FULL_DATE — 실적일 일자',
          COLUMN PERF_YEAR           COMMENT 'DIM_DATE.YEAR — 실적일 년',
          COLUMN PERF_MONTH          COMMENT 'DIM_DATE.MONTH — 실적일 월',
          COLUMN PERF_QUARTER        COMMENT 'DIM_DATE.QUARTER — 실적일 분기',
          COLUMN CAMPAIGN_NAME       COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명';

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
