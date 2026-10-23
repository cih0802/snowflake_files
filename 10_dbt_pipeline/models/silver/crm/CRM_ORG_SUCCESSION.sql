-- =============================================================================
-- Purpose    : 폐지·개편 부서 → 현재 활성 부서 귀속 (O259 · DIM_ORG_SUCCESSION 규칙 Silver 이관 · DEC-63)
-- Target     : SILVER.CRM_ORG_SUCCESSION (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계) · 선행 = 08 DDL(또는 39_DEPLOY_SILVER_ORG_CLEAN.sql)
-- Depends on : ref CRM_ORG_CLEAN, ref CRM_MEMBER_DEV, ref CRM_MEMBER_SPONSOR_SPAN, ref ORG_SUCCESSION_MANUAL
-- Issue      : O259, O252, DEC-63, DEC-56
-- =============================================================================
-- CRM_ORG_SUCCESSION: grain = 부서(DEPT_ID) 1행 · CRM_ORG_CLEAN 과 1:1(활성 부서는 자기 자신).
--   GOLD.DIM_ORG_SUCCESSION 은 이 모델을 ref 해 SK 만 붙인다(규칙 정본 = 이 파일).
-- WARN: DEC-56 유지 — 원천 실적부서값은 바꾸지 않는다. 「현재 조직 기준 조회」용 별도 축이다.
--
-- 귀속 규칙(우선순위 · O252 그대로 이관 · 근거 = tmp/o252/evidence.md):
--   0 SELF 활성 부서(CRM_ORG_CLEAN.IS_ACTIVE_ORG) = 자기 자신
--   1 MANUAL seed ORG_SUCCESSION_MANUAL(현업 확정) — CUR_DEPT_ID 비우면 MANUAL_UNMAPPED
--   2 AUTO_NAME 활성 부서 중 같은 이름이 유일
--   3 AUTO_MEMBER_FLOW 그 부서 후원 회원의 2022년~ 개발 실적부서 분포에서
--                        lift(점유율 ÷ 전체 기준선) ≥ var('org_succ_min_lift') 이고 근거 ≥ var('org_succ_min_evidence') 건
--                        WARN: 최빈값을 쓰지 않는다 — 매체운영팀이 전체 개발의 43.8% 라 전부 그리로 쏠린다
--   4 AUTO_ACMSLT_PARENT 실적트리(ACMSLT_UPPER_DEPT_ID) 상위 중 첫 활성 노드 또는 활성 동명 유일 노드
--   5 AUTO_ORG_PARENT 조직트리(UPPER_DEPT_ID) 최근접 활성 상위 · 단 ORG_LEVEL ≥ 1(법인 루트 귀속은 무의미)
--   6 UNMAPPED CUR_* NULL — 소비 측은 '(미매핑 폐지부서)' 로 노출(합계 보존 · R2-7-3 축)
--
-- O259 추가 = 상위부서도 따로 매핑한다(하위·상위 USE_YN 교차 279 / 33 건 대응):
--   OLD_UPPER_DEPT_ID      원천 조직트리 상위(그대로)
--   OLD_UPPER_CUR_DEPT_ID  그 상위를 위 규칙으로 귀속한 현재 노드(상위부서 축 귀속)
--   CUR_UPPER_DEPT_ID      귀속된 현재 노드의 활성 상위(picker 「상위부서 → 팀」 쌍)
-- WARN: seed ORG_SUCCESSION_MANUAL 은 GOLD 스키마에 그대로 둔다(O259 결정 · 권한·적재 경로 무변경).
{%- set min_lift = var('org_succ_min_lift', 3) -%}
{%- set min_evd  = var('org_succ_min_evidence', 30) %}

with recursive o as (
    select c.DEPT_ID, c.DEPT_NM, c.UPPER_DEPT_ID, c.ACMSLT_UPPER_DEPT_ID,
           c.IS_ACTIVE_ORG as ACT, c.ORG_LEVEL, c.ORG_PATH, c.ACTIVE_UPPER_DEPT_ID
    from {{ ref('CRM_ORG_CLEAN') }} c
),
act_nm as (
    select DEPT_NM, MIN(DEPT_ID) as DEPT_ID, COUNT(*) as K
    from o where ACT group by DEPT_NM
),
-- 2 동명 유일
r_name as (
    select x.DEPT_ID, n.DEPT_ID as CUR_ID
    from o x join act_nm n on n.DEPT_NM = x.DEPT_NM and n.K = 1
    where not x.ACT
),
-- 3 회원 흐름(lift)
base as (
    select d.ACMSLT_DEPT_CD as CUR_ID,
           COUNT(*) / SUM(COUNT(*)) over () as B
    from {{ ref('CRM_MEMBER_DEV') }} d
    join o a on a.DEPT_ID = d.ACMSLT_DEPT_CD and a.ACT
    where d.OCCRRNC_DE >= '20220101' and d.OCCRRNC_DE < '9999'
    group by d.ACMSLT_DEPT_CD
),
mem as (
    select distinct sp.MBER_NO, sp.ACMSLT_DEPT_CD as DEPT_ID
    from {{ ref('CRM_MEMBER_SPONSOR_SPAN') }} sp
    join o x on x.DEPT_ID = sp.ACMSLT_DEPT_CD and not x.ACT
),
flow as (
    select m.DEPT_ID, d.ACMSLT_DEPT_CD as CUR_ID, COUNT(*) as N
    from mem m
    join {{ ref('CRM_MEMBER_DEV') }} d on d.MBER_NO = m.MBER_NO
    join o a on a.DEPT_ID = d.ACMSLT_DEPT_CD and a.ACT
    where d.OCCRRNC_DE >= '20220101' and d.OCCRRNC_DE < '9999'
    group by m.DEPT_ID, d.ACMSLT_DEPT_CD
),
flow_s as (
    -- 점유율 분모 = 그 부서 회원의 활성 부서 개발 전체(10건 미만 후보도 분모에는 포함)
    select f.DEPT_ID, f.CUR_ID, f.N,
           f.N / SUM(f.N) over (partition by f.DEPT_ID)              as SHARE
    from flow f
),
r_flow as (
    -- WARN: Snowflake 는 윈도 함수 안에 윈도 함수를 중첩할 수 없다 ⇒ 점유율을 flow_s 에서 먼저 계산한다
    select s.DEPT_ID, s.CUR_ID, s.N, s.SHARE, s.SHARE / b.B as LIFT
    from flow_s s join base b on b.CUR_ID = s.CUR_ID
    where s.N >= 10
    qualify ROW_NUMBER() over (
        partition by s.DEPT_ID
        order by s.SHARE / b.B * LEAST(s.N, 200) desc, s.CUR_ID
    ) = 1
),
-- 4 실적트리 상위
wa (START_ID, CUR_ID, HOP) as (
    select DEPT_ID, ACMSLT_UPPER_DEPT_ID, 1 from o where not ACT and ACMSLT_UPPER_DEPT_ID is not null
    union all
    select wa.START_ID, u.ACMSLT_UPPER_DEPT_ID, wa.HOP + 1
    from wa join o u on u.DEPT_ID = wa.CUR_ID
    where wa.HOP < 10 and u.ACMSLT_UPPER_DEPT_ID is not null and u.ACMSLT_UPPER_DEPT_ID <> u.DEPT_ID
),
r_acm as (
    select wa.START_ID as DEPT_ID,
           MIN_BY(IFF(u.ACT, u.DEPT_ID, n.DEPT_ID), wa.HOP) as CUR_ID
    from wa
    join o u on u.DEPT_ID = wa.CUR_ID
    left join act_nm n on n.DEPT_NM = u.DEPT_NM and n.K = 1
    where u.ACT or n.DEPT_ID is not null
    group by wa.START_ID
),
-- 5 조직트리 상위(L≥1)
wo (START_ID, CUR_ID, HOP) as (
    select DEPT_ID, UPPER_DEPT_ID, 1 from o where not ACT and UPPER_DEPT_ID is not null
    union all
    select wo.START_ID, u.UPPER_DEPT_ID, wo.HOP + 1
    from wo join o u on u.DEPT_ID = wo.CUR_ID
    where wo.HOP < 10 and not u.ACT and u.UPPER_DEPT_ID is not null and u.UPPER_DEPT_ID <> u.DEPT_ID
),
r_org as (
    select wo.START_ID as DEPT_ID, MIN_BY(u.DEPT_ID, wo.HOP) as CUR_ID
    from wo join o u on u.DEPT_ID = wo.CUR_ID and u.ACT and u.ORG_LEVEL >= 1
    group by wo.START_ID
),
man as (
    select OLD_DEPT_ID, NULLIF(TRIM(CUR_DEPT_ID), '') as CUR_DEPT_ID, CONFIRMED_BY, CONFIRMED_DT, NOTE
    from {{ ref('ORG_SUCCESSION_MANUAL') }}
),
pick as (
    select x.DEPT_ID, x.DEPT_NM, x.UPPER_DEPT_ID, x.ACT,
        case
            when x.ACT                                                      then 'SELF'
            when man.OLD_DEPT_ID is not null and man.CUR_DEPT_ID is null    then 'MANUAL_UNMAPPED'
            when man.OLD_DEPT_ID is not null                                then 'MANUAL'
            when rn.CUR_ID is not null                                      then 'AUTO_NAME'
            when rf.LIFT >= {{ min_lift }} and rf.N >= {{ min_evd }}        then 'AUTO_MEMBER_FLOW'
            when ra.CUR_ID is not null                                      then 'AUTO_ACMSLT_PARENT'
            when ro.CUR_ID is not null                                      then 'AUTO_ORG_PARENT'
            else 'UNMAPPED'
        end as MAP_METHOD,
        case
            when x.ACT                                                      then x.DEPT_ID
            when man.OLD_DEPT_ID is not null                                then man.CUR_DEPT_ID
            when rn.CUR_ID is not null                                      then rn.CUR_ID
            when rf.LIFT >= {{ min_lift }} and rf.N >= {{ min_evd }}        then rf.CUR_ID
            when ra.CUR_ID is not null                                      then ra.CUR_ID
            else ro.CUR_ID
        end as CUR_DEPT_ID,
        rf.CUR_ID as FLOW_CAND_DEPT_ID, rf.N as FLOW_EVIDENCE_CNT, rf.SHARE as FLOW_SHARE, rf.LIFT as FLOW_LIFT,
        man.CONFIRMED_BY, man.CONFIRMED_DT, man.NOTE
    from o x
    left join man       on man.OLD_DEPT_ID = x.DEPT_ID
    left join r_name rn on rn.DEPT_ID = x.DEPT_ID
    left join r_flow rf on rf.DEPT_ID = x.DEPT_ID
    left join r_acm  ra on ra.DEPT_ID = x.DEPT_ID
    left join r_org  ro on ro.DEPT_ID = x.DEPT_ID
)

select
    p.DEPT_ID                                      as OLD_DEPT_ID,
    p.DEPT_NM                                      as OLD_DEPARTMENT,
    p.ACT                                          as OLD_IS_ACTIVE_ORG,
    p.UPPER_DEPT_ID                                as OLD_UPPER_DEPT_ID,
    pu.CUR_DEPT_ID                                 as OLD_UPPER_CUR_DEPT_ID,
    c.DEPT_ID                                      as CUR_DEPT_ID,
    c.DEPT_NM                                      as CUR_DEPARTMENT,
    c.ORG_PATH                                     as CUR_ORG_PATH,
    c.ORG_LEVEL                                    as CUR_ORG_LEVEL,
    c.ACTIVE_UPPER_DEPT_ID                         as CUR_UPPER_DEPT_ID,
    p.MAP_METHOD                                   as MAP_METHOD,
    (p.MAP_METHOD not in ('SELF', 'UNMAPPED', 'MANUAL_UNMAPPED'))  as IS_REMAPPED,
    (p.MAP_METHOD in ('SELF', 'MANUAL', 'MANUAL_UNMAPPED'))        as IS_CONFIRMED,
    p.FLOW_CAND_DEPT_ID                            as FLOW_CAND_DEPT_ID,
    p.FLOW_EVIDENCE_CNT                            as FLOW_EVIDENCE_CNT,
    ROUND(p.FLOW_SHARE, 4)                         as FLOW_SHARE,
    ROUND(p.FLOW_LIFT, 2)                          as FLOW_LIFT,
    p.CONFIRMED_BY                                 as CONFIRMED_BY,
    p.CONFIRMED_DT                                 as CONFIRMED_DT,
    p.NOTE                                         as NOTE,
    'CRM'                                          as DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()                            as DW_LOAD_TS,
    CURRENT_TIMESTAMP()                            as DW_UPDATE_TS,
    NULL                                           as DW_BATCH_ID
from pick p
left join o c on c.DEPT_ID = p.CUR_DEPT_ID and c.ACT
left join pick pu on pu.DEPT_ID = p.UPPER_DEPT_ID
