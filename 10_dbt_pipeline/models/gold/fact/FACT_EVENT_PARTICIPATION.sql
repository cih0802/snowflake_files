-- FACT_EVENT_PARTICIPATION: 행사 참여 팩트 (SILVER.CRM_EVENT_PARTICIPATION 1,134,126행 적재 완료)
-- Co-authored with CoCo
-- 🔴 [O28 2026-08-04 주석 회수] 종전 주석은 *"Bronze 입고 후 실행"* · *"상태별 집계는 입고 후"* 였다.
--    **원인 오진이다** — BRONZE·SILVER 모두 적재 완료됐고 막고 있는 것은 입고가 아니라
--    `PARTCPT_STAT_CD` 코드체계였다. 한 컬럼에 두 체계가 혼입돼 있다(일반행사 ↔ 캠페인행사).
-- 🟢🟢 [2026-08-20 O93 재정정] **그 차단은 절반 해소됐다.** 종전 O28 서술 2가지가 지금은 틀리다:
--    ① *"캠페인행사 소정수 1~6 = 의미 미확정 → 현업 회신 필수"* → **회신 없이 확정됐다.**
--       O59-N/DEC-35 2단계의 `MS006` 사전 조인으로 6종에 한글 라벨이 달렸다
--       (신청·참여·대기·대기(결제)·취소·불참).
--    ② 두 체계의 **성격이 반대로 적혀 있었다** — 참여 상태 축은 일반행사가 아니라 **캠페인행사**다.
--       일반행사(`MS304`)는 `Success`·`N_step_right`·`N_step_fail` 로 **퍼널 단계** 축이라
--       신청확정/대기/취소/불참에 매핑되지 않는다.
--    ⇒ 대기·취소·불참 3종을 **캠페인행사 구간에 한해** 배선했다(상세는 아래 SELECT 주석).
--    ⚠️ 잔여 미해소 = `CONFIRM_CNT`(신청확정) 1종 — 사전에 그 라벨이 없다(문서20 §I 회신 대기).
-- ⚠️ 미주입 14컬럼(카운트 6·횟수 4·degen NULL 2·FK 센티넬 2)의 사유는 컬럼 COMMENT 에 개별 명시했다
--    (정본 = `03_top-down_gold/06_DDL.sql` FEP 블록 · 가드 스크립트 = `_archive/O28_O29_COMMENT_GUARD.sql`).
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
    -- ═══ [2026-08-20 O93] 상태별 카운트 부분 배선 — O28 차단이 **절반 해소됐다** ══════════════
    -- 🔴 위 O28 주석(3~9행)은 이제 **stale** 이다. 종전 판정은
    --    *"캠페인행사 소정수 1~6 은 의미 미확정 → 현업 회신 필수"* 였으나,
    --    O59-N/DEC-35 2단계가 `MS006` 사전을 붙인 뒤 그 6종에 **한글 라벨이 실제로 달렸다**:
    --      신청 · 참여 · 대기 · 대기(결제) · 취소 · 불참  ⇒ 회신 없이 판정 가능하다.
    -- 🔴 그리고 두 체계의 성격이 종전 서술과 **반대**다:
    --      · 캠페인행사(CRMN · MS006) = **참여 상태** 축 ⇒ 대기·취소·불참이 여기 있다.
    --      · 일반행사(EVENT · MS304)   = 라벨이 `Success`·`N_step_right`·`N_step_fail` 로
    --        **퍼널 단계** 축이다 ⇒ 신청확정/대기/취소/불참에 **매핑되지 않는다**(억지 매핑은 창작).
    --    ⇒ 그래서 아래 3종은 **CRMN 구간만** 채워지고 EVENT 구간은 0 이다. 판별자 = `EVENT_KIND`.
    --    🔴 이 0 을 「해당 없음」으로 읽어야 한다 — 「대기 0명」이 아니다.
    -- 🟢 라벨 문자열로 매칭하는 이유: 사전 문안이 바뀌면 매칭이 풀려 **0 으로 떨어진다**(안전한 방향).
    --    코드값(1~6)으로 매칭하면 사전이 재코딩될 때 **조용히 다른 상태로 배정**된다(위험한 방향).
    --    `PART_STATUS_GROUP` 가드로 사전 조인이 성립한 행만 판정한다.
    -- 🔴 R2-6: 구간별 실측 행수는 여기 적지 않는다 — 정본은 `20_issue/03_이슈상세.md` O28 항목이다.
    1 as TOTAL_CNT,   -- 총인원 = 참여행 1건 = 1. 상태 무관이라 코드체계와 독립적이다(전건 안전).
    -- 대기: '대기' 와 '대기(결제)' 를 함께 센다 — 둘 다 대기 상태의 하위 구분이다.
    IFF(p.PARTCPT_STAT_GROUP IS NOT NULL AND p.PARTCPT_STAT_NM LIKE '대기%', 1, 0)  as WAIT_CNT,
    IFF(p.PARTCPT_STAT_GROUP IS NOT NULL AND p.PARTCPT_STAT_NM = '취소', 1, 0)      as CANCEL_CNT,
    -- 🔴 신청확정 = 0 유지. 사전에 **'신청확정' 라벨이 없다** — 있는 것은 '신청' 과 '참여' 뿐이고
    --    「신청 → 신청확정」 또는 「참여 → 신청확정」 중 어느 쪽인지는 업무 정의라 우리가 고를 수 없다
    --    (고르면 라벨 창작 · DEC-17-B). ⇒ 현업 확인 항목으로 남긴다(문서20 §I 에 병기).
    0 as CONFIRM_CNT,
    -- 🔴 [DEC-30 2026-08-04] `RECRUIT_CNT` 제거 — `DIM_EVENT.RECRUIT_HEADCOUNT` 로 이관했다.
    --   모집인원은 행사 속성이므로 참여행 grain 에 두면 SUM 이 101.0배 과대계상된다(§18-D ② 실패).
    -- ⚠️ `PARTICIPATE_CNT`·`PARTICIPANT_CNT` 는 **이번에 건드리지 않았다** — 빈 컬럼이 아니라
    --    이미 상수 1 이 들어 있고(취소·불참 행도 1 = 기지 결함) 값을 바꾸면 기존 소비 쿼리의
    --    의미가 조용히 달라진다. 🟢 정확한 참여수가 필요하면 `PART_STATUS_NAME = '참여'` 로 필터할 것.
    1 as PARTICIPATE_CNT, 1 as PARTICIPANT_CNT,
    IFF(p.PARTCPT_STAT_GROUP IS NOT NULL AND p.PARTCPT_STAT_NM = '불참', 1, 0)      as ABSENT_CNT,
    0 as PARTICIPATION_TIMES, 0 as WAIT_TIMES, 0 as ABSENT_TIMES, 0 as CUM_APPLY_TIMES,
    p.RCPMNY_AMT                                  as REGULAR_DONATION,
    (p.PRZWIN_CD IS NOT NULL)                     as WIN_FLAG,
    CAST(NULL AS BOOLEAN)                          as SELF_PART_FLAG,
    p.PARTCPT_STAT_CD                             as PART_STATUS,
    p.PARTCPT_PATH_CD                             as PART_PATH,
    p.PARTCPT_CHNNL_CD                            as PART_CHANNEL,
    -- 🔴 [2026-09-01 O130] `INCREASE_FLAG` 드랍 — O96 판정(§7-B A군) 집행. 소비 0(WIDE 뷰 재생성 동반).
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
    {{ gold_meta('CRM') }},
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
left join {{ ref('DIM_EVENT') }} e
    on e.EVENT_BK = p.EVENT_KEY
