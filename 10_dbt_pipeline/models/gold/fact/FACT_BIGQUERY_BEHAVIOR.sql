-- FACT_BIGQUERY_BEHAVIOR: BigQuery 행동 팩트 (BIGQUERY_EVENT + BigQuery DIM 조인, 일 grain)
-- Co-authored with CoCo
-- grain: DATE_SK×IDENTITY_SK×BIGQUERY_EVENT_SK×BIGQUERY_SOURCE_SK×DEVICE_SK×CAMPAIGN_SK×PAGE_PATH
-- IDENTITY_SK = IDENTITY_MEMBER_XREF(pseudo→회원) → DIM_MEMBER_IDENTITY 매칭분, 미매칭=0(센티넬). CAMPAIGN_SK=NULL.
-- ⚠️ [G-5 재확인] IDENTITY 결선은 BigQuery 1일 샤드 기반(회원 커버리지 ~4.2%). 전기간 입고 시 재실행·재검증 필요(문서50 G-5 게이트).
-- ⚠️ 비/준가산 지표(AVG_SESSION_DURATION·BOUNCE_RATE)는 grain 값 — 상위 재합산 금지(06_DDL §6)
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존. append 라 unique_key 불요.
-- 🔄🔴 [2026-09-22] **전량 TRUNCATE 재적재 → 범위 재적재(일일 증분)로 전환.**
--   왜: 매 run 전량 재계산은 순수 낭비였다(실측 33일 14.9초 → 전일자 환산 ≈ 7분).
--   pre-hook 이 `macros/gold_fact_purge.sql` 로 분기한다 — `RANGED_FACTS` 에 이 모델명 등재 필수.
--     · 그 매크로가 `DELETE … WHERE DATE_SK <창>` 을 내고, 아래 `e` CTE 가 **같은 창**을 append 한다.
--     · 창 정의 지점은 `macros/ga4_range_predicate.sql` 의 `ga4_load_window()` 하나다.
--       DELETE 는 `_sk`(NUMBER YYYYMMDD) 렌더러, 여기는 DATE 렌더러를 쓰지만 창은 동일하다.
--   🔴 **이 파일에 `pre_hook` 을 쓰지 말 것** — dbt 는 hook 을 누적하므로 TRUNCATE 와 DELETE 가
--      함께 돌아 팩트가 창 크기로 쪼그라든다(에러 없이 행수만 줄어든다 · gold_fact_purge.sql 주석).
--   🔴 범위 DELETE 의 전제 3가지(grain 에 DATE_SK · 집계가 일자 내 폐쇄 · DATE_SK=0 공집합)는
--      `macros/gold_fact_purge.sql` 헤더에 적혀 있다. 지표를 추가할 때 ②를 깨지 않는지 확인하라
--      (월간 유니크처럼 일자를 넘나드는 집계를 넣으면 범위 재적재가 틀린 값을 낸다).
--   🔴🔴 **[2026-09-22 O177] 열린 백로그와 직접 맞닿는다 — `A4-W` 배선 6건의 1번이 이 모델이다**
--      (`99_NEXT_SESSION_조각/99_NEXT_SESSION-O0176-A.md:70`). 그 항목은 아래 `CAMPAIGN_SK`
--      센티넬 0 을 `SILVER.BIGQUERY_EVENT.UTM_CAMPAIGN` 으로 배선하라고 지시한다(🟢 컬럼 실재).
--      ⇒ 🟢 **그 배선은 이 범위 재적재와 양립한다** — `UTM_CAMPAIGN` 은 이벤트 행의 속성이므로
--        group by 에 들어가도 집계가 **일자 안에서 닫힌다**(전제 ② 유지).
--      🔴 단 배선 시 **전량 백필이 필요하다** — 창 밖 과거 행의 `CAMPAIGN_SK` 는 센티넬로 남는다
--        (롤링 윈도우는 창 밖을 건드리지 않는다) ⇒ `ga4_dt_ranges` 주석을 풀어 전 구간 재적재하라.
--        ⚠️ 이 「배선 후 백필 의무」는 증분화가 **새로 만든** 절차다. 배선만 하고 끝내면
--           과거 전체가 센티넬로 남아 **에러 없이** 지표가 틀린다.
{{ config(
    tags=['gold_ready']
) }}

with e as (
    -- 🔴 창 술어 = pre-hook DELETE 범위와 **반드시 동일**해야 멱등이다(정의 지점: ga4_load_window).
    select * from {{ ref('BIGQUERY_EVENT') }}
    where {{ ga4_range_predicate('EVENT_DT') }}
),
-- pseudo→회원 매칭(1 pseudo 1행 = XREF grain). IDENTITY_SK 해소용, fan-out 없음.
xref as (
    select USER_PSEUDO_ID, MEMBER_DK
    from {{ ref('IDENTITY_MEMBER_XREF') }}
    where MEMBER_DK is not null
    qualify row_number() over (partition by USER_PSEUDO_ID order by MEMBER_DK) = 1
),

joined as (
    select
        COALESCE({{ date_sk('e.EVENT_DT') }}, 0)                            as DATE_SK,        -- 범위밖/NULL → 0 (순서9)
        COALESCE(dmi.IDENTITY_SK, 0)                                        as IDENTITY_SK,   -- 매칭 회원 SK / 미매칭=0(센티넬)
        COALESCE(gev.BIGQUERY_EVENT_SK, 0)                                  as BIGQUERY_EVENT_SK,
        COALESCE(gs.BIGQUERY_SOURCE_SK, 0)                                  as BIGQUERY_SOURCE_SK,
        COALESCE(dv.DEVICE_SK, 0)                                           as DEVICE_SK,
        0                                                                   as CAMPAIGN_SK,   -- 센티넬(미매핑) — DIM_CAMPAIGN 적재 후 해소
        COALESCE(SPLIT_PART(e.PAGE_LOCATION, '?', 1), '(none)')              as PAGE_PATH,
        e.PAGE_LOCATION                                                      as PAGE_LOCATION,
        e.USER_PSEUDO_ID,
        e.BIGQUERY_SESSION_ID,
        e.EVENT_NAME,
        e.IS_ACTIVE_USER,
        e.SESSION_ENGAGED,
        e.ENGAGEMENT_TIME_MSEC,
        e.PERCENT_SCROLLED
    from e
    left join {{ ref('DIM_BIGQUERY_EVENT') }}  gev
        on  EQUAL_NULL(gev.EVENT_CATEGORY, e.EVENT_CATEGORY)
        and EQUAL_NULL(gev.EVENT_LABEL,    e.EVENT_LABEL)
        and EQUAL_NULL(gev.EVENT_ACTION,   e.EVENT_ACTION)
    left join {{ ref('DIM_BIGQUERY_SOURCE') }} gs
        on  EQUAL_NULL(gs.UTM_SOURCE, e.UTM_SOURCE)
        and EQUAL_NULL(gs.UTM_MEDIUM, e.UTM_MEDIUM)
    left join {{ ref('DIM_DEVICE') }}    dv
        on  EQUAL_NULL(dv.DEVICE_TYPE, e.DEVICE_TYPE)
    left join xref x
        on  x.USER_PSEUDO_ID = e.USER_PSEUDO_ID
    left join {{ ref('DIM_MEMBER_IDENTITY') }} dmi
        on  dmi.MEMBER_DK = x.MEMBER_DK
),

-- ⚠️ [O94] 집계를 CTE 로 분리한 이유 = AVG_ENGAGEMENT_TIME_PER_SESSION 상한 가드를 outer 에서 1회만 걸기 위함.
--    컬럼 이름·순서는 종전과 동일하다(DDL insert 순서 보존 · WIDE_BIGQUERY_BEHAVIOR 영향 없음).
agg as (
select
    DATE_SK,
    IDENTITY_SK,
    BIGQUERY_EVENT_SK,
    BIGQUERY_SOURCE_SK,
    DEVICE_SK,
    CAMPAIGN_SK,
    PAGE_PATH,
    MAX(PAGE_LOCATION)                                                       as PAGE_LOCATION,
    COUNT_IF(EVENT_NAME = 'session_start')                                  as VISITS,
    COUNT(*)                                                                 as EVENT_CNT,
    COUNT_IF(EVENT_NAME = 'page_view')                                      as VIEW_CNT,
    COUNT(DISTINCT USER_PSEUDO_ID || '|' || BIGQUERY_SESSION_ID)             as SESSION_CNT,
    COUNT(DISTINCT IFF(SESSION_ENGAGED = '1',
        USER_PSEUDO_ID || '|' || BIGQUERY_SESSION_ID, NULL))                 as ENGAGED_SESSIONS,
    MAX(PERCENT_SCROLLED)                                                    as SCROLL_DEPTH,
    COUNT(DISTINCT IFF(IS_ACTIVE_USER, USER_PSEUDO_ID, NULL))               as ACTIVE_USERS,
    COUNT(DISTINCT USER_PSEUDO_ID)                                          as TOTAL_USERS,
    CAST(NULL AS NUMBER)                                                     as AVG_SESSION_DURATION,  -- ⚠️ 세션지속 산식 미정
    CAST(NULL AS NUMBER)                                                     as BOUNCE_RATE,           -- ⚠️ 비가산·정의 대기
    DIV0(
        COUNT(DISTINCT IFF(SESSION_ENGAGED='1', USER_PSEUDO_ID||'|'||BIGQUERY_SESSION_ID, NULL)),
        COUNT(DISTINCT USER_PSEUDO_ID || '|' || BIGQUERY_SESSION_ID)
    )                                                                        as ENGAGEMENT_RATE,
    DIV0(SUM(ENGAGEMENT_TIME_MSEC) / 1000.0,
        COUNT(DISTINCT USER_PSEUDO_ID || '|' || BIGQUERY_SESSION_ID))         as AVG_ENGAGEMENT_TIME_PER_SESSION,  -- 초 단위(NUMBER(9,4)) — 상한 가드는 아래 outer select
    {{ gold_meta('BIGQUERY') }}
from joined
group by DATE_SK, IDENTITY_SK, BIGQUERY_EVENT_SK, BIGQUERY_SOURCE_SK, DEVICE_SK, CAMPAIGN_SK, PAGE_PATH
)

-- ⚠️ [O94] 상한 가드 — 봇/크롤러성 장기 세션이 누적 참여시간으로 DDL 타입 NUMBER(9,4) 상한을 넘겨
--    build 를 죽였다(100046/22003). 범위 초과분만 NULL 로 두고 타입은 보존한다(06_DDL 무변경).
--    가드 상수 100000 = NUMBER(9,4) 정수부 5자리 한계에서 나온 값이며 실측치가 아니다(R2-6).
--    🔴 근본 처리(봇 세션 필터 정책 · 임계값 업무 합의)는 미정 — 원장 §O94 승계.
--    🔴 이 가드는 이 1컬럼만 막는다 — EVENT_CNT·SESSION_CNT 등 가산 지표에는 해당 세션이 그대로 남는다.
--    `* replace` 를 쓰는 이유 = 컬럼 이름·순서를 손으로 다시 적지 않아 DDL insert 순서가 어긋날 수 없다.
select * replace (
    IFF(ABS(AVG_ENGAGEMENT_TIME_PER_SESSION) < 100000,
        AVG_ENGAGEMENT_TIME_PER_SESSION, NULL) as AVG_ENGAGEMENT_TIME_PER_SESSION
)
from agg
