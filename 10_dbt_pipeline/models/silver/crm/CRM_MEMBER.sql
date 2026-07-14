-- CRM_MEMBER: 정기(FDRM) ∪ 일시(ONCE) 회원 통합 정제 (grain=MEMBER_DK, PK=MEMBER_DK)
-- Co-authored with CoCo
-- 원천: TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO
-- 정제: 타입 캐스팅 · NULL 표준화 · MEMBER_TYPE 파생 · 회원키 선행0/S접두 보존(VARCHAR)
-- ⚠️ Q6: 정기/일시 UNION 스키마 정렬(잠정). 코드→라벨(_NM)은 CRM_CODE 적재 후 채움(현재 NULL)
-- ⚠️ EMAIL/PSTMTR_RECPTN: 정기=코드(멀티값 '2,5,6'), 일시=Y/N — raw 보존(정규화는 후속)
{{ config(
    materialized='incremental',
    unique_key='MEMBER_DK',
    incremental_strategy='merge'
) }}

with regular as (
    select
        CAST({{ clean_str('MBER_NO') }} AS VARCHAR(10))       as MEMBER_DK,
        'FDRM'                                                 as MEMBER_TYPE,
        CAST({{ clean_str('MBER_DIV_CD') }} AS VARCHAR(3))     as MBER_DIV_CD,
        CAST(NULL AS VARCHAR)                                  as MBER_DIV_NM,
        CAST({{ clean_str('CPR_DIV_CD') }} AS VARCHAR(3))      as CPR_DIV_CD,
        CAST({{ clean_str('SEX') }} AS VARCHAR(2))             as SEX,
        CAST({{ clean_str('MBER_STAT_CD') }} AS VARCHAR(3))    as MBER_STAT_CD,
        CAST(NULL AS VARCHAR)                                  as MBER_STAT_NM,
        CAST({{ clean_str('CMPGN_CD') }} AS VARCHAR(20))       as CMPGN_CD,
        CAST({{ clean_str('ACT_DEPT_CD') }} AS VARCHAR(10))    as ACT_DEPT_CD,
        CAST({{ clean_str('REGIST_DEPT_CD') }} AS VARCHAR(10)) as REGIST_DEPT_CD,
        CAST({{ clean_str('JOIN_PATH_CD') }} AS VARCHAR(3))    as JOIN_PATH_CD,
        CAST({{ clean_str('HMPG_ID') }} AS VARCHAR(30))        as HMPG_ID,
        CAST(NULL AS VARCHAR(200))                             as ENTRPS_NM,
        CAST({{ clean_str('EMAIL_RECPTN_CD') }} AS VARCHAR)    as EMAIL_RECPTN,
        CAST({{ clean_str('PSTMTR_RECPTN_CD') }} AS VARCHAR)   as PSTMTR_RECPTN,
        FRST_REGIST_DT                                          as JOIN_DT,
        {{ dw_meta('TM_MM_FDRM_MBER_INFO') }}
    from {{ source('bronze_crm', 'TM_MM_FDRM_MBER_INFO') }}
),

once as (
    select
        CAST({{ clean_str('ONCE_MBER_NO') }} AS VARCHAR(10))   as MEMBER_DK,
        'ONCE'                                                 as MEMBER_TYPE,
        CAST({{ clean_str('MBER_DIV_CD') }} AS VARCHAR(3))     as MBER_DIV_CD,
        CAST(NULL AS VARCHAR)                                  as MBER_DIV_NM,
        CAST({{ clean_str('CPR_DIV_CD') }} AS VARCHAR(3))      as CPR_DIV_CD,
        CAST({{ clean_str('SEX') }} AS VARCHAR(2))             as SEX,
        CAST(NULL AS VARCHAR(3))                               as MBER_STAT_CD,
        CAST(NULL AS VARCHAR)                                  as MBER_STAT_NM,
        CAST(NULL AS VARCHAR(20))                              as CMPGN_CD,
        CAST(NULL AS VARCHAR(10))                              as ACT_DEPT_CD,
        CAST({{ clean_str('REGIST_DEPT_CD') }} AS VARCHAR(10)) as REGIST_DEPT_CD,
        CAST(NULL AS VARCHAR(3))                               as JOIN_PATH_CD,
        CAST({{ clean_str('HMPG_ID') }} AS VARCHAR(30))        as HMPG_ID,
        CAST({{ clean_str('ENTRPS_NM') }} AS VARCHAR(200))     as ENTRPS_NM,
        CAST({{ clean_str('EMAIL_RECPTN_YN') }} AS VARCHAR)    as EMAIL_RECPTN,
        CAST({{ clean_str('PSTMTR_RECPTN_YN') }} AS VARCHAR)   as PSTMTR_RECPTN,
        FRST_REGIST_DT                                          as JOIN_DT,
        {{ dw_meta('TM_MM_ONCE_MBER_INFO') }}
    from {{ source('bronze_crm', 'TM_MM_ONCE_MBER_INFO') }}
)

select * from regular
union all
select * from once
