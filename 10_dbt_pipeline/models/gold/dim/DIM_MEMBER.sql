-- =============================================================================
-- Purpose    : 정규 회원 마스터 차원 (회원 1명 = 1행, IS_CURRENT=TRUE 투영) — 분석가 및 Cortex Analyst 기본 진입점
-- Target     : GOLD.DIM_MEMBER (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref DIM_MEMBER_STATUS_HISTORY, ref FACT_MEMBER_SPONSORSHIP_SPAN, ref CRM_MEMBER, ref CRM_CAMPAIGN, ref DIM_SPONSORSHIP, ref CRM_CODE
-- Issue      : O188-F, O191-G, O213-D, O237-C
-- =============================================================================
-- DIM_MEMBER: 정규 회원 마스터 차원 (회원 1명 = 1행, IS_CURRENT=TRUE 투영) — 분석가 및 Cortex Analyst 기본 진입점
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook='TRUNCATE TABLE IF EXISTS {{ this }}',
    tags=['gold_ready']
) }}

select
    h.MEMBER_SK,
    h.MEMBER_DK,
    h.MEMBER_TYPE,
    h.SEX,
    h.SEX_NM,
    h.GENDER_NAME,
    h.MBER_STAT_CD,
    h.MEMBER_STATUS_NAME,
    h.MEMBER_STATUS_GROUP,
    h.MBER_DIV_CD,
    h.MEMBER_TYPE_NAME,
    h.JOIN_PATH_CD,
    h.ENROLL_PATH_NAME,
    h.FIRST_JOIN_DATE,
    h.FIRST_CAMPAIGN,
    h.REGION,
    h.AGE_BAND,
    h.FIRST_SPONSORSHIP,
    h.LAST_STOP_DATE,
    h.EFFECTIVE_FROM,
    h.DW_SOURCE_SYSTEM,
    h.DW_LOAD_TS,
    h.DW_UPDATE_TS,
    h.DW_BATCH_ID,
    --  [2026-09-29 O188-F] 가입캠페인(CRM_MEMBER.CMPGN_CD)의 공통브랜드(MM297) — 「공통브랜드 기준 가입경로」.
    --    SILVER 에서 직접 조인한다 — DIM_MEMBER_ACQUISITION(FME→COHORT 경유)을 참조하면 의존이 길어지고
    --      순환 위험이 생긴다. xf98254 = 1,606,883명 채움 · 획득 차원 ACQ_CMMN_BRND_NM 과 99.73% 일치
    --      (불일치 = 가입캠페인 ≠ 최초개발캠페인 회원 · 둘은 다른 정의다).
    c.CMMN_BRND                                   as JOIN_CMMN_BRND,
    c.CMMN_BRND_NM                                as JOIN_CMMN_BRND_NM,
    --  [2026-09-30 O191-G · 2차-B GOLD 전파] SILVER CRM_MEMBER 승계(회원 grain · 이관유무 = ONCE 전용).
    m.CHRCTR_RECPTN_YN                            as CHRCTR_RECPTN_YN,
    m.SPECL_MNG_CD1                               as SPECL_MNG_CD1,
    m.FDRM_MBER_TRNSFER_FG                        as FDRM_MBER_TRNSFER_FG,
    --  [2026-10-08 O213-D · 7차 Y3-C] 회원 분류 축 라벨 배선 — 「브론즈에 있는데 Agent 가 답하지 못한다」 해소.
    --   라벨 정본 = SILVER.CRM_CODE(코드그룹은 2026-10-08 실측 확정 · 사전에 없는 코드는 라벨 NULL + 코드 보존 · R2-7).
    m.RELATNSP_DIV_CD                             as RELATNSP_DIV_CD,
    c_rel.DTL_CD_NM                               as RELATNSP_DIV_NAME,
    c_sp1.DTL_CD_NM                               as SPECL_MNG_NAME,
    m.SPECL_MNG_CD2                               as SPECL_MNG_CD2,
    c_sp2.DTL_CD_NM                               as SPECL_MNG2_NAME,
    sp.SPONSORSHIP_NAME                           as FIRST_SPONSORSHIP_NAME,
    m.MOBLPHON_STAT_CD                            as MOBLPHON_STAT_CD,
    c_mob.DTL_CD_NM                               as MOBLPHON_STAT_NAME,
    m.ETC_CTTPC_STAT_CD                           as ETC_CTTPC_STAT_CD,
    c_etc.DTL_CD_NM                               as ETC_CTTPC_STAT_NAME,
    m.EMAIL_STAT_CD                               as EMAIL_STAT_CD,
    c_eml.DTL_CD_NM                               as EMAIL_STAT_NAME,
    m.TSTM_DIV_CD                                 as TSTM_DIV_CD,
    c_ts.DTL_CD_NM                                as TSTM_DIV_NAME,
    m.ETC_TSTM_DIV_CD                             as ETC_TSTM_DIV_CD,
    c_ets.DTL_CD_NM                               as ETC_TSTM_DIV_NAME,
    c_rl.DTL_CD_NM                                as REL_NAME,
    c_sl.DTL_CD_NM                                as SLRCLD_LRR_NAME,
    -- 수신동의는 복수 선택 문자열(예: '2,3,5')이다 ⇒ 항목별 플래그로 편다. 코드그룹 = 이메일 MS028 · 우편 MS027.
    --   WARN: 원천 값 'Y'·'N'·'0'(구 체계 · 항목 미상)과 NULL 은 플래그 NULL 로 둔다 — 항목을 추정하지 않는다.
    {%- set eml = "m.EMAIL_RECPTN" %}
    {%- set pst = "m.PSTMTR_RECPTN" %}
    {%- set eml_ok = eml ~ " is not null and " ~ eml ~ " not in ('Y','N','0')" %}
    {%- set pst_ok = pst ~ " is not null and " ~ pst ~ " not in ('Y','N','0')" %}
    iff({{ eml_ok }}, array_contains('1'::variant, split({{ eml }}, ',')), null) as EMAIL_RECV_REFUSE_YN,
    iff({{ eml_ok }}, array_contains('2'::variant, split({{ eml }}, ',')), null) as EMAIL_RECV_REGULAR_YN,
    iff({{ eml_ok }}, array_contains('3'::variant, split({{ eml }}, ',')), null) as EMAIL_RECV_RELATION_YN,
    iff({{ eml_ok }}, array_contains('4'::variant, split({{ eml }}, ',')), null) as EMAIL_RECV_THANKS_YN,
    iff({{ eml_ok }}, array_contains('5'::variant, split({{ eml }}, ',')), null) as EMAIL_RECV_WEBZINE_YN,
    iff({{ eml_ok }}, array_contains('6'::variant, split({{ eml }}, ',')), null) as EMAIL_RECV_DEV_YN,
    iff({{ pst_ok }}, array_contains('1'::variant, split({{ pst }}, ',')), null) as POST_RECV_REFUSE_YN,
    iff({{ pst_ok }}, array_contains('2'::variant, split({{ pst }}, ',')), null) as POST_RECV_REGULAR_YN,
    iff({{ pst_ok }}, array_contains('3'::variant, split({{ pst }}, ',')), null) as POST_RECV_RELATION_YN,
    iff({{ pst_ok }}, array_contains('4'::variant, split({{ pst }}, ',')), null) as POST_RECV_NEW_THANKS_YN,
    --  [2026-10-16 O237-C · 공#31 최종캠페인 · 잠정(사용자 결정)] 가장 최근 시작한 후원약정(span)의 대표캠페인 코드.
    --    MSTR 로직 없음 · 90 정의서 = 「CRM 최종 캠페인 명」뿐 ⇒ 원천 SND_MEMBER_LIST.LAST_CMPGN(발송 대상 546,221명)과
    --      파생안(1,621,410명)을 비교해 회원수·활동금액이 큰 파생안을 택했다(원천과 일치 58% · 정의 차이 = 잠정 표기).
    --   WARN: 같은 시작월이 여러 개면 SPNSR_CMPGN_CD 가 큰 쪽(결정적 tie-break) · span 이 없는 회원(일시회원 등)은 NULL(R2-7).
    lc.LAST_CAMPAIGN                              as LAST_CAMPAIGN,
    --  [2026-10-25 O262-B · 33 §1] 회원 등록부서 코드 raw(정기 FDRM · 일시 ONCE 공통 = CRM_MEMBER.REGIST_DEPT_CD) — 06_DDL 동기 · 맨 끝 append
    --   WARN: 개발 실적부서(FACT 의 ORG_SK = ACMSLT_DEPT_CD)와 **다른 축**이다. 부서명이 필요하면 DIM_ORG 를 코드로 잇는다.
    m.REGIST_DEPT_CD                              as REGIST_DEPT_CD
from {{ ref('DIM_MEMBER_STATUS_HISTORY') }} h
left join (
    select MEMBER_DK, SPNSR_CMPGN_CD as LAST_CAMPAIGN
    from {{ ref('FACT_MEMBER_SPONSORSHIP_SPAN') }}
    where SPNSR_CMPGN_CD is not null
    qualify row_number() over (partition by MEMBER_DK
                               order by START_MONTH_KEY desc nulls last, SPNSR_CMPGN_CD desc) = 1
) lc on lc.MEMBER_DK = h.MEMBER_DK
left join {{ ref('CRM_MEMBER') }}   m on m.MEMBER_DK = h.MEMBER_DK
left join {{ ref('CRM_CAMPAIGN') }} c on c.CMPGN_CD  = m.CMPGN_CD
left join {{ ref('DIM_SPONSORSHIP') }} sp on sp.SPONSORSHIP_BK = h.FIRST_SPONSORSHIP
left join {{ ref('CRM_CODE') }} c_rel on c_rel.CD_ID = 'MM019' and c_rel.DTL_CD_ID = m.RELATNSP_DIV_CD
left join {{ ref('CRM_CODE') }} c_sp1 on c_sp1.CD_ID = 'MM012' and c_sp1.DTL_CD_ID = m.SPECL_MNG_CD1
left join {{ ref('CRM_CODE') }} c_sp2 on c_sp2.CD_ID = 'MM012' and c_sp2.DTL_CD_ID = m.SPECL_MNG_CD2
left join {{ ref('CRM_CODE') }} c_mob on c_mob.CD_ID = 'MM008' and c_mob.DTL_CD_ID = m.MOBLPHON_STAT_CD
left join {{ ref('CRM_CODE') }} c_etc on c_etc.CD_ID = 'MM008' and c_etc.DTL_CD_ID = m.ETC_CTTPC_STAT_CD
left join {{ ref('CRM_CODE') }} c_eml on c_eml.CD_ID = 'MM009' and c_eml.DTL_CD_ID = m.EMAIL_STAT_CD
left join {{ ref('CRM_CODE') }} c_ts  on c_ts.CD_ID  = 'MS026' and c_ts.DTL_CD_ID  = m.TSTM_DIV_CD
left join {{ ref('CRM_CODE') }} c_ets on c_ets.CD_ID = 'MS026' and c_ets.DTL_CD_ID = m.ETC_TSTM_DIV_CD
left join {{ ref('CRM_CODE') }} c_rl  on c_rl.CD_ID  = 'CM009' and c_rl.DTL_CD_ID  = m.REL_CD
left join {{ ref('CRM_CODE') }} c_sl  on c_sl.CD_ID  = 'CM029' and c_sl.DTL_CD_ID  = m.SLRCLD_LRR_CD
where h.IS_CURRENT
