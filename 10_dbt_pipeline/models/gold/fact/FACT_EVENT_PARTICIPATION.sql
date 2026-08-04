-- FACT_EVENT_PARTICIPATION: 행사 참여 팩트 (SILVER.CRM_EVENT_PARTICIPATION 1,134,126행 적재 완료)
-- Co-authored with CoCo
-- 🔴 [O28 2026-08-04 주석 회수] 종전 주석은 *"Bronze 입고 후 실행"* · *"상태별 집계는 입고 후"* 였다.
--    **원인 오진이다** — BRONZE·SILVER 모두 적재 완료됐고(1,134,126행) 막고 있는 것은 입고가 아니라
--    `PARTCPT_STAT_CD` **코드체계 미확정**이다. 실측: 한 컬럼에 두 체계가 혼입돼 있다 —
--      · 일반행사(EVENT_KEY 접두 `EVENT_`)  = MS304 12종 110~220  970,788행
--      · 캠페인행사(접두 `CRMN_`)           = 소정수 1~6           152,096행 ← **의미 미확정**
--    소정수 1~6 은 대조로 확정 불가(코드사전 336그룹 중 1~6 포함 118그룹) → **현업 회신 필수**(문서20 §I).
--    그 확정 전에는 상태별 카운트 5종을 배선하면 **결손 창작**이다(P38) → 의도적 0 유지.
-- ⚠️ 미주입 14컬럼(카운트 6·횟수 4·degen NULL 2·FK 센티넬 2)의 사유는 컬럼 COMMENT 에 개별 명시했다
--    (정본 = `03_top-down_gold/06_DDL.sql` FEP 블록 · 가드 스크립트 = `O28_O29_COMMENT_GUARD.sql`).
-- 🟢 단 `PARTICIPATION_TIMES`·`CUM_APPLY_TIMES` 는 `PARTCPT_SEQ`(채움 100%) 기반이라 O28 과 무관하게
--    산출 가능하다 — 회신 대기 대상이 아니다(별건 배선 후보).
-- ⚠️ CAMPAIGN/SPONSORSHIP_SK=0 센티넬은 O8(다중 캠페인 귀속규칙) 현업 미회신 차단분이다.
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
{{ config(
    tags=['gold_pending']
) }}

with p as (
    select * from {{ ref('CRM_EVENT_PARTICIPATION') }}
)

select
    COALESCE({{ date_sk('p.PARTCPT_DT::DATE') }}, {{ date_sk('e.EVENT_START_DATE') }}, 0) as DATE_SK,  -- 참여일 없으면 행사시작일, 둘 다 없으면 센티넬0 (순서9)
    p.MBER_NO                                     as MEMBER_DK,
    COALESCE(e.EVENT_SK, 0)                        as EVENT_SK,
    0                                             as CAMPAIGN_SK,
    0                                             as SPONSORSHIP_SK,
    0 as TOTAL_CNT, 0 as WAIT_CNT, 0 as CANCEL_CNT, 0 as CONFIRM_CNT,
    -- 🔴 [DEC-30 2026-08-04] `RECRUIT_CNT` 제거 — `DIM_EVENT.RECRUIT_HEADCOUNT` 로 이관했다.
    --   모집인원은 행사 속성이므로 참여행 grain 에 두면 SUM 이 101.0배 과대계상된다(§18-D ② 실패).
    1 as PARTICIPATE_CNT, 0 as ABSENT_CNT, 1 as PARTICIPANT_CNT,
    0 as PARTICIPATION_TIMES, 0 as WAIT_TIMES, 0 as ABSENT_TIMES, 0 as CUM_APPLY_TIMES,
    p.RCPMNY_AMT                                  as REGULAR_DONATION,
    (p.PRZWIN_CD IS NOT NULL)                     as WIN_FLAG,
    CAST(NULL AS BOOLEAN)                          as SELF_PART_FLAG,
    p.PARTCPT_STAT_CD                             as PART_STATUS,
    p.PARTCPT_PATH_CD                             as PART_PATH,
    p.PARTCPT_CHNNL_CD                            as PART_CHANNEL,
    CAST(NULL AS BOOLEAN)                          as INCREASE_FLAG,
    -- 🟢 [DEC-30 2026-08-04] degenerate key 2종 — A군 잔여 해소 + 고아 식별자 보존.
    -- 🔴 `EVENT_BK` 가 반드시 필요한 이유(2026-08-04 빌드 후 실측으로 발견):
    --    행사 마스터에 없는 **53개 행사 · 263,611행(23.2%)** 은 `EVENT_SK` 가 전부 0 이 되어
    --    GOLD 에서 **서로 구별되지 않았다**(SILVER distinct 3,715 → GOLD distinct EVENT_SK 3,663).
    --    즉 "어느 고아 행사였는지"가 소실됐다. 이 컬럼이 그 정보를 보존한다.
    -- 🔷 행 유일 식별 = (EVENT_BK, MEMBER_DK, PARTCPT_SEQ). `EVENT_SK` 로 대체하면
    --    고아가 0 으로 뭉개져 **31,831키·63,783행이 충돌**한다(실측).
    -- ⚠️ `PARTCPT_SEQ` 는 식별자 전용 — 전역 순번이 아니고((행사,SEQ) 201,817),
    --    원천에 음수 20,844행·INT_MIN 1행이 있어 정렬·범위 조건에 쓰면 안 된다.
    p.EVENT_KEY                                   as EVENT_BK,
    p.PARTCPT_SEQ                                 as PARTCPT_SEQ,
    {{ gold_meta('CRM') }}
from p
left join {{ ref('DIM_EVENT') }} e
    on e.EVENT_BK = p.EVENT_KEY
