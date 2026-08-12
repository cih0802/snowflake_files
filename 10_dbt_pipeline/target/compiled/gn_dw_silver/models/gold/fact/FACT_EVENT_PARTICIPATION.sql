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
--    (정본 = `03_top-down_gold/06_DDL.sql` FEP 블록 · 가드 스크립트 = `_archive/O28_O29_COMMENT_GUARD.sql`).
-- 🟢 단 `PARTICIPATION_TIMES`·`CUM_APPLY_TIMES` 는 `PARTCPT_SEQ`(채움 100%) 기반이라 O28 과 무관하게
--    산출 가능하다 — 회신 대기 대상이 아니다(별건 배선 후보).
-- ⚠️ CAMPAIGN/SPONSORSHIP_SK=0 센티넬은 O8(다중 캠페인 귀속규칙) 현업 미회신 차단분이다.
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.


with p as (
    select * from GN_DW.SILVER.CRM_EVENT_PARTICIPATION
)

select
    COALESCE(CASE WHEN p.PARTCPT_DT::DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(p.PARTCPT_DT::DATE, 'YYYYMMDD')) END, CASE WHEN e.EVENT_START_DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(e.EVENT_START_DATE, 'YYYYMMDD')) END, 0) as DATE_SK,  -- 참여일 없으면 행사시작일, 둘 다 없으면 센티넬0 (순서9)
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
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '3597d1ab-90a3-4cbe-8064-e4fa5228209e'                    AS DW_BATCH_ID,
    -- 🟢 [2026-08-11 O59-N · DEC-35 2단계] 참여 3축 코드→라벨 전파. 코드사전 조인은 SILVER 소관.
    --    🔴 PART_STATUS_GROUP 이 O28 다체계의 **구조적 판별축**이다(종전에는 COMMENT 경고뿐이었다).
    --    신설 위치 = 감사컬럼 뒤(정본 DDL 규약 · 물리 ordinal 이 ALTER 로 맨 끝).
    p.PARTCPT_STAT_GROUP                          as PART_STATUS_GROUP,
    p.PARTCPT_STAT_NM                             as PART_STATUS_NAME,
    p.PARTCPT_PATH_GROUP                          as PART_PATH_GROUP,
    p.PARTCPT_PATH_NM                             as PART_PATH_NAME,
    p.PARTCPT_CHNNL_GROUP                         as PART_CHANNEL_GROUP,
    p.PARTCPT_CHNNL_NM                            as PART_CHANNEL_NAME,
    -- 🟢 [2026-08-12 O61 · D2 구조 처방] 원천 계열 판별 2컬럼 (명세 = 99 §0-Y-1 · 근거 = 원장 §O59-S ③④).
    --   🔴 종전 판별자는 `DIM_EVENT.EVENT_KIND(_NAME)` 뿐이었고 그것은 **아래 left join 에서 온다** ⇒
    --      행사 마스터 미매칭 구간은 `'(미매핑)'` 이라 **계열을 알려주지 못했다**(가장 큰 단일 버킷).
    --      이 2컬럼은 SILVER 의 **원천 분기**(`DW_SOURCE_TABLE`)에서 오므로 조인 성패와 무관하다.
    --   🔴 어휘는 `DIM_EVENT` 와 conform 한다 — 새 어휘를 만들면 두 축의 교차 검증이 깨진다.
    --   🔴 `ELSE` 를 쓰지 않는다(P31) — 매핑에 없는 원천이 인입되면 NULL 로 드러나고,
    --      yml `accepted_values`(2종)와 게이트 종수 검사가 즉시 실패해 갱신을 강제한다.
    case p.DW_SOURCE_TABLE
         when 'BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL' then 'EVENT'
         when 'BRONZE_CRM.TD_MS_CRMN_PRTCPNT'      then 'CRMN' end as EVENT_KIND,
    case p.DW_SOURCE_TABLE
         when 'BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL' then '일반행사'
         when 'BRONZE_CRM.TD_MS_CRMN_PRTCPNT'      then '캠페인행사' end as EVENT_KIND_NAME
from p
left join GN_DW.GOLD.DIM_EVENT e
    on e.EVENT_BK = p.EVENT_KEY