-- FACT_TARGET_PROJECT: 프로젝트/사업목표 팩트 (CRM_BIZ_TARGET, 월×조직×후원사업×캠페인)
-- Co-authored with CoCo
{{ config(
    tags=['gold_pending']
) }}

with t as (
    select * from {{ ref('CRM_BIZ_TARGET') }}
    where COALESCE(TARGET_CNT, 0) > 0
),
-- 🔴 [2026-09-29 O188] 이름 조인 팬아웃 차단 — `DIM_ORG.DEPARTMENT` 는 유일하지 않다
--   (실측: 목표 팀명 중 「사회공헌협력팀」 6행 · 「회원참여팀」·「컬쳐콘텐츠팀」·「사회공헌협력팀(사복)」 각 2행).
--   종전 스캐폴드는 0행이라 드러나지 않았고, 입고 즉시 목표가 최대 **6배** 복제될 뻔했다.
--   ⇒ 이름이 유일한 부서만 매칭하고 모호한 이름은 SK=0 으로 보낸다(크로스워크 확보 전 · 문서20 N-24).
-- 🆕 [2026-09-29 O188-E] 매칭 모집단을 **활성 조직 트리**(`DIM_ORG.IS_ACTIVE_ORG` · 조직표 CSV 규칙)로 좁힌다.
--   📏 xf98254 목표 팀명 10종 유일 매칭 = 4 → **7** · 잔여 = 활성 내 동명 `컬쳐콘텐츠팀`(2코드) 1 ·
--      조직명이 아닌 `지역사회`·`교육기관` 2 ⇒ 셋 다 SK=0 유지(값 창작 금지 · 현업 확인 = 30번 문서).
org_u as (
    select DEPARTMENT, ORG_SK
    from {{ ref('DIM_ORG') }}
    where IS_ACTIVE_ORG
    qualify COUNT(*) over (partition by DEPARTMENT) = 1
)

select
    COALESCE({{ month_key_clamp('TRY_TO_NUMBER(t.MONTH_KEY)') }}, 0)  as MONTH_KEY,
    COALESCE(o.ORG_SK, 0)                          as ORG_SK,
    COALESCE(s.SPONSORSHIP_SK, 0)                  as SPONSORSHIP_SK,
    COALESCE(c.CAMPAIGN_SK, 0)                     as CAMPAIGN_SK,      -- O188: 원천에 캠페인 축 없음 ⇒ 0(not_null 테스트)
    SUM(CASE WHEN t.TARGET_TYPE = '당초'   THEN t.TARGET_CNT END)  as ANNUAL_GOAL_CNT,
    SUM(CASE WHEN t.TARGET_TYPE LIKE '추경%' THEN t.TARGET_CNT END) as SUPP_GOAL_CNT,
    CAST(NULL AS NUMBER(18,4))                     as ANNUAL_CUM_GOAL_CNT,
    CAST(NULL AS NUMBER(18,4))                     as SUPP_CUM_GOAL_CNT,
    {{ gold_meta('CRM') }},
    -- 🆕 [2026-09-29 O188] 원천 입고 배선 · degen 2축(물리 위치 = 맨 끝 · 06_DDL 동기) — grain 에 포함.
    --   🔴 GOAL_TYPE_NM 을 group by 에서 빼면 연사업·팀이 합쳐져 **약 2배**가 된다(348,024 + 348,000 · N-24).
    --   ⚠️ 매칭 실측(xf98254 · 목표>0 월행 · 유일 부서만): 조직 연사업 360/820 · 팀 205/440 ·
    --      후원사업 연사업 594/820 · 팀 0/440 · 합계 348,024 · 348,000 보존(팬아웃 0)
    --      (팀 유형의 후원사업은 「국내·결연·기타·해외프로젝트」 그룹명이라 사업 차원과 grain 이 다르다 ⇒ SK=0).
    t.GOAL_TYPE_NM                                 as GOAL_TYPE_NM,
    t.CPR_DIV_NM                                   as CPR_DIV_NM,
    -- 🆕 [2026-09-29 O188-E] 원천 이름 degen 5축 — SV 노출용. 차원 매칭이 안 되는 팀명 3종·팀 유형 후원사업(4그룹)을
    --   SK=0 으로만 두면 SV 에서 「(미매핑)」 한 덩어리가 된다 ⇒ 원천 표기를 그대로 함께 싣는다(값 창작 0).
    --   🔴 grain 이 세분될 뿐 합계는 불변(SUM 은 같은 행을 다시 나눌 뿐이다).
    t.ORG_NM                                       as SRC_TEAM_NM,
    t.SPONSOR_BIZ_NM                               as SRC_SPONSOR_BIZ_NM,
    t.NEW_OLD_DIV_NM                               as NEW_OLD_DIV_NM,
    t.ORG_DIV_NM                                   as ORG_DIV_NM,
    t.DTL_DIV_NM                                   as DTL_DIV_NM
from t
left join org_u o
    on o.DEPARTMENT = t.ORG_NM
left join {{ ref('DIM_SPONSORSHIP') }} s
    on s.SPONSORSHIP_NAME = t.SPONSOR_BIZ_NM
left join {{ ref('DIM_CAMPAIGN') }} c
    on c.CAMPAIGN_NAME = t.CAMPAIGN_NM
group by 1, 2, 3, 4, t.GOAL_TYPE_NM, t.CPR_DIV_NM,
         t.ORG_NM, t.SPONSOR_BIZ_NM, t.NEW_OLD_DIV_NM, t.ORG_DIV_NM, t.DTL_DIV_NM
