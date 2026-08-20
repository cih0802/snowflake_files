create or replace view GN_DW.GOLD.WIDE_GA_BEHAVIOR
    (
      DATE_SK COMMENT $$행동 발생일 YYYYMMDD$$,
      PAGE_PATH COMMENT $$페이지경로+쿼리 (#105)$$,
      PAGE_LOCATION COMMENT $$페이지위치(URL 전체)$$,
      VISITS COMMENT $$방문수$$,
      EVENT_CNT COMMENT $$이벤트수$$,
      VIEW_CNT COMMENT $$조회수$$,
      SESSION_CNT COMMENT $$세션수$$,
      ENGAGED_SESSIONS COMMENT $$참여세션수$$,
      SCROLL_DEPTH COMMENT $$[비가산] 스크롤깊이 — 재합산 금지$$,
      ACTIVE_USERS COMMENT $$[비가산] 활성사용자 — 재합산 금지$$,
      TOTAL_USERS COMMENT $$[비가산] 총사용자 — 재합산 금지$$,
      AVG_SESSION_DURATION COMMENT $$[비가산] 평균세션시간 — 재합산 금지 (#98) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. GA4 원천 적재 범위 자체가 좁다(G-5 하드블로커). 실측 규모는 이슈원장 §O51-F.$$,
      BOUNCE_RATE COMMENT $$[비가산] 이탈율 — 재합산 금지 (#108) 🔴🔴[O51-F 실측] **전건 NULL — 원천 자체가 비어 있다**(`BRONZE_BIGQUERY 세션 지표`). 결측이 아니라 **대행사가 항목을 보고하지 않는다**: 0 이나 '해당없음' 으로 대체 해석하지 말 것(P21). 필터 조건으로 쓰면 전건이 탈락한다. GA4 원천 적재 범위 자체가 좁다(G-5 하드블로커). 실측 규모는 이슈원장 §O51-F.$$,
      ENGAGEMENT_RATE COMMENT $$[비가산] 참여율 — 재합산 금지$$,
      AVG_ENGAGEMENT_TIME_PER_SESSION COMMENT $$[비가산] 세션당 평균참여시간 — 재합산 금지$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      FULL_DATE COMMENT $$DIM_DATE.FULL_DATE — 실제 일자$$,
      YEAR COMMENT $$DIM_DATE.YEAR — 년 🔴🔴[O51-F 실측] **단일값이다 — GA4 실적재가 한 해의 일부 구간뿐이다**(G-5 하드블로커). 연도별·계절별 추이를 이 뷰로 산출하면 **구간 하나를 전체로 오독**한다. ⇒ 기간 비교는 광고·회원 팩트로 하고, GA 지표는 해당 구간 내부 분석에만 쓸 것. 실측 규모는 이슈원장 §O51-F.$$,
      MONTH COMMENT $$DIM_DATE.MONTH — 월$$,
      DAY_OF_WEEK COMMENT $$DIM_DATE.DAY_OF_WEEK — 요일$$,
      WEEK_OF_YEAR COMMENT $$DIM_DATE.WEEK_OF_YEAR — 주차$$,
      IS_HOLIDAY COMMENT $$DIM_DATE.IS_HOLIDAY — 휴일여부 🔴🔴[O51-F 실측] **휴일축이 미주입이다 — 전건 `FALSE`.** `DIM_DATE.IS_HOLIDAY` 에 TRUE 가 하나도 없다. NULL 이 아니라 FALSE 라서 **집계가 성공한 것처럼 보이고**, 「휴일 대비 평일 성과」 질의가 **전건 평일**로 응답된다. ⇒ 이 컬럼으로 휴일 분석을 하지 말 것(기지 **HOL-1** — 공휴일 원천이 전 스키마에 없어 외부 입고 대기). 실측 규모는 이슈원장 §O51-F.$$,
      IDENTITY_MEMBER_DK COMMENT $$DIM_MEMBER_IDENTITY.MEMBER_DK — 불변 회원키$$,
      IDENTITY_MEMBER_NO COMMENT $$DIM_MEMBER_IDENTITY.MEMBER_NO — 회원번호 (#110)$$,
      IDENTITY_MEMNUM COMMENT $$DIM_MEMBER_IDENTITY.MEMNUM — memnum (#111) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_GA_BEHAVIOR.IDENTITY_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 🔴익명 세션이 다수라 회원번호가 붙지 않는다 — 회원 귀속 분석은 `IDENTITY_SK` 를 `DIM_MEMBER_IDENTITY` 브리지로 풀어야 하며 unknown 비중을 분모에서 제외할지 먼저 정할 것(O49). 실측 규모는 이슈원장 §O51-F.$$,
      IDENTITY_GA_MEMBER_ID COMMENT $$DIM_MEMBER_IDENTITY.GA_MEMBER_ID — GA member_id (#112)$$,
      GA_EVENT_CATEGORY COMMENT $$DIM_GA_EVENT.EVENT_CATEGORY — 이벤트 카테고리 (#99)$$,
      GA_EVENT_LABEL COMMENT $$DIM_GA_EVENT.EVENT_LABEL — 이벤트 라벨 (#100)$$,
      GA_EVENT_ACTION COMMENT $$DIM_GA_EVENT.EVENT_ACTION — 이벤트 액션 (#101)$$,
      GA_UTM_SOURCE COMMENT $$DIM_GA_SOURCE.UTM_SOURCE — source$$,
      GA_UTM_MEDIUM COMMENT $$DIM_GA_SOURCE.UTM_MEDIUM — medium$$,
      GA_UTM_CONTENT COMMENT $$DIM_GA_SOURCE.UTM_CONTENT — 세션 수동 광고 콘텐츠 (#103)$$,
      GA_UTM_TERM COMMENT $$DIM_GA_SOURCE.UTM_TERM — 세션 수동 검색어 (#104)$$,
      GA_SOURCE_MEDIUM COMMENT $$DIM_GA_SOURCE.SOURCE_MEDIUM — 세션 소스/매체 (#109)$$,
      DEVICE_TYPE COMMENT $$DIM_DEVICE.DEVICE_TYPE — PC / M / APP$$,
      CAMPAIGN_BK COMMENT $$DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_GA_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_BRAND COMMENT $$DIM_CAMPAIGN.BRAND — 공통브랜드 (#117) 🔴🔴[O51-F 실측] **이 뷰에서 전건 NULL** — 원인은 차원이 아니라 **팩트 FK 가 전건 센티넬**이다: `FACT_GA_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ **이 축으로는 분해가 불가능하다.** 차원 자체는 채워져 있다. 실측 규모는 이슈원장 §O51-F.$$,
      CAMPAIGN_NAME COMMENT $$DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120) 🔴🔴[O51-F 실측] **전건 `'(미매핑)'` 센티넬** — NULL 이 아니라 **문자열**이라 GROUP BY 하면 단일 그룹이 생겨 **집계에 성공한 것처럼 보인다.** 원인 = `FACT_GA_BEHAVIOR.CAMPAIGN_SK` 의 실측값이 센티넬 하나뿐이다. ⇒ 이 컬럼으로 분해를 시도하지 말 것 — 「캠페인별」·「부서별」 요구에 **조용히 총계 1행**이 돌아온다. 실측 규모는 이슈원장 §O51-F.$$
    )
    comment = $$GA 행동 팩트(FGA) 평탄화 — DATE·GA_EVENT·GA_SOURCE·DEVICE·CAMPAIGN·IDENTITY. 비가산 지표의 상위 재합산 금지. IDENTITY_* 는 `DIM_MEMBER_IDENTITY` 활성으로 실조인된다 — 브리지는 1:1 이라 팬아웃이 없다(O49). 🔴🔴[O51-F 실측] **GA4 실적재 구간이 한 해의 일부뿐이다**(G-5 하드블로커) → `YEAR` 가 단일값이므로 연도·계절 추이를 이 뷰로 내면 **구간 하나를 전체로 오독**한다. 기간 비교는 광고·회원 팩트로 할 것. 🔴세션 품질 지표(AVG_SESSION_DURATION·BOUNCE_RATE)와 회원번호는 전건 비어 있고, 캠페인축은 전건 센티넬이다. 🔴휴일축(`IS_HOLIDAY`)도 전건 FALSE 로 미주입(**HOL-1**). ⚠️종전 기재 「GA4 1일 기반」은 stale 이었다 — 실적재 구간은 그보다 넓고, 정확한 범위는 이슈원장 §O51-F.$$
    as (
      -- WIDE_GA_BEHAVIOR: GA 행동 팩트(FGA) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.6)
-- Co-authored with CoCo
-- 2026-07-15: DIM_MEMBER_IDENTITY 활성화 → IDENTITY_* 4컬럼 실조인 복원(f.IDENTITY_SK = DIM_MEMBER_IDENTITY.IDENTITY_SK).
--    ⚠️[G-5 재확인] 현재 GA4 1일 샤드 기반(회원 매칭 커버리지 ~4.2%). 전기간 입고 시 재실행·재검증 필요(문서50 G-5 게이트).
-- 🔧 [2026-08-07 O51-C] materialization 전환: view -> gn_view_commented.
--   깨진 post_hook(`ALTER VIEW ... ALTER COLUMN ... COMMENT` = Snowflake 에 없는 문법) 제거.
--   COMMENT 정본은 `_wide_schema.yml` 로 이관됨 — 뷰=description · 컬럼=columns[].description.
--   ⚠️ columns[] 는 SELECT 와 개수·순서가 일치해야 한다(INFORMATION_SCHEMA 순서로 기계 생성).


select
    f.DATE_SK, f.PAGE_PATH, f.PAGE_LOCATION,
    f.VISITS, f.EVENT_CNT, f.VIEW_CNT, f.SESSION_CNT, f.ENGAGED_SESSIONS,
    f.SCROLL_DEPTH, f.ACTIVE_USERS, f.TOTAL_USERS,
    f.AVG_SESSION_DURATION, f.BOUNCE_RATE, f.ENGAGEMENT_RATE,
    f.AVG_ENGAGEMENT_TIME_PER_SESSION,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
    -- DIM_MEMBER_IDENTITY 활성(2026-07-15) → 실제 조인. ⚠️[G-5] GA4 1일 기반·커버리지 ~4.2%, 전기간 입고 시 재검증(문서50)
    mi.MEMBER_DK          as IDENTITY_MEMBER_DK,
    mi.MEMBER_NO          as IDENTITY_MEMBER_NO,
    mi.MEMNUM             as IDENTITY_MEMNUM,
    mi.GA_MEMBER_ID       as IDENTITY_GA_MEMBER_ID,
    ge.EVENT_CATEGORY     as GA_EVENT_CATEGORY,
    ge.EVENT_LABEL        as GA_EVENT_LABEL,
    ge.EVENT_ACTION       as GA_EVENT_ACTION,
    gs.UTM_SOURCE         as GA_UTM_SOURCE,
    gs.UTM_MEDIUM         as GA_UTM_MEDIUM,
    gs.UTM_CONTENT        as GA_UTM_CONTENT,
    gs.UTM_TERM           as GA_UTM_TERM,
    gs.SOURCE_MEDIUM      as GA_SOURCE_MEDIUM,
    dv.DEVICE_TYPE        as DEVICE_TYPE,
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME
from GN_DW.GOLD.FACT_GA_BEHAVIOR f
left join GN_DW.GOLD.DIM_DATE      d  on f.DATE_SK      = d.DATE_SK
left join GN_DW.GOLD.DIM_GA_EVENT  ge on f.GA_EVENT_SK  = ge.GA_EVENT_SK
left join GN_DW.GOLD.DIM_GA_SOURCE gs on f.GA_SOURCE_SK = gs.GA_SOURCE_SK
left join GN_DW.GOLD.DIM_DEVICE    dv on f.DEVICE_SK    = dv.DEVICE_SK
left join GN_DW.GOLD.DIM_CAMPAIGN  c  on f.CAMPAIGN_SK  = c.CAMPAIGN_SK
left join GN_DW.GOLD.DIM_MEMBER_IDENTITY mi on f.IDENTITY_SK = mi.IDENTITY_SK
    );