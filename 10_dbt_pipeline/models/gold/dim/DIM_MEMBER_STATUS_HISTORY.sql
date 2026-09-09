-- DIM_MEMBER_STATUS_HISTORY: 회원 차원 SCD2 다중 버전 이력 (CRM_MEMBER 현재값 + STATUS_HIST 이력)
-- Co-authored with CoCo
-- 【회원번호 체계】 CRM은 정식(FDRM)·일시(ONCE)를 별도 테이블로 분리 관리:
--   FDRM → TM_MM_FDRM_MBER_INFO: 번호 0000000~9999999 (7자리, leading-zero 보존)
--   ONCE → TM_MM_ONCE_MBER_INFO: 번호 S00000000~S09999999 (S접두+8자리=9자)
--   GA4 user_id는 이 둘을 단일 필드로 통합 표현 → 'S' 접두 유무로 FDRM/ONCE 판별.
--   MEMBER_DK=VARCHAR(10) 필수·NUMBER 캐스팅 절대 금지.
-- 🔴 이 테이블은 SCD2 다중 버전(792만 행)이므로, 팩트와 직접 조인하지 말고 정규 1회원 1행인 DIM_MEMBER를 사용하십시오.
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook='TRUNCATE TABLE IF EXISTS {{ this }}',
    tags=['gold_ready']
) }}

with m as (
    select * from {{ ref('CRM_MEMBER') }}
),

-- 상태이력(FDRM 전용): 동일 시점(일자) 중복은 최종상태(max SER_NO)로 축약
hist_collapsed as (
    select
        MBER_NO                                       as MBER_NO,
        EFFECTIVE_FROM::DATE                          as EFF_FROM,
        CHN_STAT_CD                                   as STATUS_CD,
        BF_STAT_CD                                    as PREV_STATUS_CD
    from {{ ref('CRM_MEMBER_STATUS_HIST') }}
    qualify row_number() over (partition by MBER_NO, EFFECTIVE_FROM::DATE order by SER_NO desc) = 1
),

-- 축약본에서 SCD2 구간(EFFECTIVE_TO)·현재플래그 재계산
hist_scd2 as (
    select
        MBER_NO,
        STATUS_CD,
        PREV_STATUS_CD,
        EFF_FROM,
        lead(EFF_FROM) over (partition by MBER_NO order by EFF_FROM)             as EFF_TO,
        (lead(EFF_FROM) over (partition by MBER_NO order by EFF_FROM) is null)   as IS_CUR
    from hist_collapsed
),

-- (A) 이력 보유 회원(FDRM) = 상태버전별 다중행
versioned as (
    select
        {{ gold_sk(['m.MEMBER_DK', 'h.EFF_FROM']) }}  as MEMBER_SK,
        m.MEMBER_DK, m.SEX, m.SEX_NM, m.MBER_DIV_CD, m.MEMBER_TYPE, m.FRST_REGIST_DT, m.CMPGN_CD, m.JOIN_PATH_CD,
        h.STATUS_CD                                   as MBER_STAT_CD,
        h.PREV_STATUS_CD                              as PREV_MBER_STAT_CD,
        h.EFF_FROM                                    as EFFECTIVE_FROM,
        h.EFF_TO                                      as EFFECTIVE_TO,
        h.IS_CUR                                      as IS_CURRENT
    from m
    join hist_scd2 h on m.MEMBER_DK = h.MBER_NO
),

-- (B) 이력 미보유(FDRM 무이력 + ONCE 전체) = 가입일 기준 단일버전
single as (
    select
        {{ gold_sk(['m.MEMBER_DK', 'm.FRST_REGIST_DT']) }}   as MEMBER_SK,
        m.MEMBER_DK, m.SEX, m.SEX_NM, m.MBER_DIV_CD, m.MEMBER_TYPE, m.FRST_REGIST_DT, m.CMPGN_CD, m.JOIN_PATH_CD,
        m.MBER_STAT_CD                                as MBER_STAT_CD,
        CAST(NULL AS VARCHAR)                          as PREV_MBER_STAT_CD,
        m.FRST_REGIST_DT::DATE                               as EFFECTIVE_FROM,
        CAST(NULL AS DATE)                            as EFFECTIVE_TO,
        TRUE                                          as IS_CURRENT
    from m
    where m.MEMBER_DK not in (select MBER_NO from hist_scd2)
),

unioned as (
    select * from versioned
    union all
    select * from single
),

-- 개발약정 시점 스냅샷
dev_snap as (
    select
        MBER_NO                                           as MBER_NO,
        try_to_date(OCCRRNC_DE, 'YYYYMMDD')               as DEV_DT,
        AREA_CD                                           as AREA_CD,
        AGE                                                as AGE
    from {{ ref('CRM_MEMBER_DEV') }}
    where OCCRRNC_DE not in ('19000101', '99991231')
      and try_to_date(OCCRRNC_DE, 'YYYYMMDD') is not null
    qualify row_number() over (
        partition by MBER_NO, try_to_date(OCCRRNC_DE, 'YYYYMMDD')
        order by SER_NO desc nulls last) = 1
),

member_snap as (
    select
        u.MEMBER_SK                                       as MEMBER_SK,
        d.AREA_CD                                          as AREA_CD,
        d.AGE                                              as AGE
    from unioned u
    asof join dev_snap d
        match_condition (u.EFFECTIVE_FROM >= d.DEV_DT)
        on u.MEMBER_DK = d.MBER_NO
),

first_biz as (
    select
        MBER_NO                                            as MBER_NO,
        SPNSR_BSNS_ID                                      as FIRST_SPONSORSHIP
    from {{ ref('CRM_MEMBER_DEV') }}
    where OCCRRNC_DE not in ('19000101', '99991231')
      and SPNSR_BSNS_ID is not null
    qualify row_number() over (partition by MBER_NO order by OCCRRNC_DE asc, SER_NO asc) = 1
),

stop_snap as (
    select
        MBER_NO                                            as MBER_NO,
        try_to_date(SPNSR_DSCNTC_DE, 'YYYYMMDD')           as STOP_DT
    from {{ ref('CRM_MEMBER_DISCONTINUE') }}
    where try_to_date(SPNSR_DSCNTC_DE, 'YYYYMMDD') is not null
    qualify row_number() over (
        partition by MBER_NO, try_to_date(SPNSR_DSCNTC_DE, 'YYYYMMDD')
        order by SER_NO desc nulls last) = 1
),

member_stop as (
    select
        u.MEMBER_SK                                        as MEMBER_SK,
        s.STOP_DT                                          as LAST_STOP_DATE
    from unioned u
    asof join stop_snap s
        match_condition (u.EFFECTIVE_FROM >= s.STOP_DT)
        on u.MEMBER_DK = s.MBER_NO
),

code_type as (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'MM018'
),
code_status as (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'MM010'
),
code_path as (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'MM014'
),
code_gender as (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'CM017'
),
code_area as (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'CM018'
),
code_ageband as (
    select DTL_CD_ID, DTL_CD_NM from {{ ref('CRM_CODE') }} where CD_ID = 'CM014'
)

select
    u.MEMBER_SK                                   as MEMBER_SK,
    u.MEMBER_DK                                   as MEMBER_DK,
    u.SEX                                         as SEX,
    u.SEX_NM                                      as SEX_NM,
    cg.DTL_CD_NM                                  as GENDER_NAME,
    ms.AREA_CD                                    as AREA_CD,
    ca.DTL_CD_NM                                  as REGION,
    ms.AGE                                        as AGE,
    cab.DTL_CD_NM                                 as AGE_BAND,
    u.MBER_STAT_CD                                as MBER_STAT_CD,
    u.MBER_DIV_CD                                 as MBER_DIV_CD,
    ct.DTL_CD_NM                                  as MEMBER_TYPE_NAME,
    case when u.MBER_STAT_CD is not null then cs.DTL_CD_NM
         when u.MEMBER_TYPE = 'ONCE'     then '(해당없음)'
         else null end                            as MEMBER_STATUS_NAME,
    CASE
        WHEN u.MBER_STAT_CD = '1'                                            THEN '정상'
        WHEN u.MBER_STAT_CD IN ('2','3','4','5','6','7','8','9','10','11')   THEN '미납'
        WHEN u.MBER_STAT_CD = '12'                                          THEN '중단'
        WHEN u.MEMBER_TYPE = 'ONCE'                                         THEN '(해당없음)'
        ELSE NULL
    END                                           as MEMBER_STATUS_GROUP,
    u.PREV_MBER_STAT_CD                           as PREV_MBER_STAT_CD,
    cps.DTL_CD_NM                                 as PREV_MEMBER_STATUS_NAME,
    u.FRST_REGIST_DT::DATE                        as FIRST_JOIN_DATE,
    u.CMPGN_CD                                    as FIRST_CAMPAIGN,
    u.JOIN_PATH_CD                                as JOIN_PATH_CD,
    case when u.JOIN_PATH_CD is not null then cp.DTL_CD_NM
         when u.MEMBER_TYPE = 'ONCE'     then '(해당없음)'
         else null end                            as ENROLL_PATH_NAME,
    fb.FIRST_SPONSORSHIP                          as FIRST_SPONSORSHIP,
    st.LAST_STOP_DATE                             as LAST_STOP_DATE,
    u.EFFECTIVE_FROM                              as EFFECTIVE_FROM,
    u.EFFECTIVE_TO                                as EFFECTIVE_TO,
    u.IS_CURRENT                                  as IS_CURRENT,
    {{ gold_meta('CRM') }},
    u.MEMBER_TYPE                                 as MEMBER_TYPE
from unioned u
left join member_snap  ms  on u.MEMBER_SK       = ms.MEMBER_SK
left join member_stop  st  on u.MEMBER_SK       = st.MEMBER_SK
left join first_biz    fb  on u.MEMBER_DK       = fb.MBER_NO
left join code_type    ct  on u.MBER_DIV_CD     = ct.DTL_CD_ID
left join code_status  cs  on u.MBER_STAT_CD    = cs.DTL_CD_ID
left join code_status  cps on u.PREV_MBER_STAT_CD = cps.DTL_CD_ID
left join code_path    cp  on u.JOIN_PATH_CD    = cp.DTL_CD_ID
left join code_gender  cg  on u.SEX             = cg.DTL_CD_ID
left join code_area    ca  on ms.AREA_CD        = ca.DTL_CD_ID
left join code_ageband cab on to_varchar(ms.AGE) = cab.DTL_CD_ID
