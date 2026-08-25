-- FACT_MEMBER_SPONSOR_BIZ: 회원×후원약정(SPNSR_BSNS_NO) 팩트
-- Co-authored with CoCo
-- [2026-08-21 신설] "캠페인별/후원사업별 활동회원" 질문에 답하기 위해 신설.
--   배경: FACT_MEMBER_MONTHLY.CAMPAIGN_SK 는 회원 grain(다중캠페인 19.0%·최대690)이라 O8 미결로 전건 센티넬(0)이다.
--   그런데 약정(SPNSR_BSNS_NO) grain 에서는 캠페인이 거의 1:1(다중 137건=0.01%·최대 2, 실측)이라
--   O8 문제가 이 grain 에서는 사실상 발생하지 않는다.
--
-- grain = MEMBER_DK × SPNSR_BSNS_NO. 🔴 SPNSR_BSNS_NO 단독은 PK 가 아니다 — 실측 28건이
--   서로 다른 두 회원(공동후원 쌍, 예: 부부)에 공유된다(CRM_MEMBER_SPONSOR_SPAN 실측).
--   (MBER_NO, SPNSR_BSNS_NO) 쌍은 2,170,572행 = 전건 유일(실측 확인, 중복 0).
--   SPNSR_NO 도 PK 후보가 아니다 — 한 SPNSR_NO 가 여러 SPNSR_BSNS_NO 를 가질 수 있다(Q15, distinct 2,103,041 vs 총행 2,170,572).
--
-- grain 선택 근거(A안 vs B안, 2026-08-21 실측):
--   A안(약정 grain, 비확장) = 2,170,572행 ← 채택
--   B안(월 확장 grain, MEMBER×SPNSR_BSNS_NO×MONTH_KEY) = 실측 105,428,370행
--     (FACT_MEMBER_MONTHLY 40,054,883행의 2.6배) → 비용 대비 이점 없어 폐기.
--   활동 판정(as-of)은 SV/소비 계층에서 START_MONTH_KEY~DSCNTC_MONTH_KEY 구간으로 계산한다
--   (CRM_MEMBER_SPONSOR_SPAN·FACT_MEMBER_MONTHLY#51 과 동일 as-of 철학 — 월별로 물리 확장하지 않는다).
--
-- 캠페인 귀속 규칙(대표캠페인, 결정적 단일 규칙):
--   CRM_MEMBER_DEV 사건 중 우선순위 ①DVLP_DIV_CD='1'(신규) ②그 외, 그 안에서 최초일자(OCCRRNC_DE)·
--   최소일련번호(SER_NO) 오름차순 1건 채택.
--   실측(2026-08-21): 신규사건 보유 1,687,546건(신규사건 내 다중캠페인 32건도 이 규칙으로 결정적 해소) ·
--   신규사건 부재 483,028건(전체 2,170,574건의 22.3%)은 전체 사건 중 최초사건 캠페인으로 대체
--   — 이 그룹은 최초사건 시점 캠페인이 100% 단일(동률 0건, 실측 확인) ·
--   두 경로 모두 사건이 아예 없는 6건은 CAMPAIGN_SK=0(미매핑, P21 — '(미매핑)' 라벨 창작 없음).
-- IS_MULTI_CAMPAIGN: 그 SPNSR_BSNS_NO 의 전체 사건에서 distinct CMPGN_CD > 1 인지(참고용 투명성 플래그).
--   실측 137건(0.01%)·최대 2. 대표캠페인 채택 규칙과는 별개로, 다중이었다는 사실 자체를 감추지 않는다.
--
-- 활동 판정은 이 팩트가 직접 하지 않는다 — START_MONTH_KEY·DSCNTC_MONTH_KEY 원본을 그대로 노출하고
-- "특정 월 as-of 활동 여부"는 소비 계층(SV) 에서 계산한다(FMM#51 과 동일 판정식 재사용 — CONF-3 tie-break 불요,
-- 재후원 시 새 SPNSR_BSNS_NO 발급으로 이미 반영됨, CRM_MEMBER_SPONSOR_SPAN 코멘트 참조).


with span as (
    select * from GN_DW.SILVER.CRM_MEMBER_SPONSOR_SPAN
),

-- 대표캠페인: 우선순위 신규(1) > 그 외, 그 안에서 최초일자·최소일련번호
campaign_pick as (
    select
        SPNSR_BSNS_NO,
        CMPGN_CD,
        row_number() over (
            partition by SPNSR_BSNS_NO
            order by iff(DVLP_DIV_CD = '1', 0, 1), OCCRRNC_DE, SER_NO
        ) as rn
    from GN_DW.SILVER.CRM_MEMBER_DEV
),
campaign_rep as (
    select SPNSR_BSNS_NO, CMPGN_CD
    from campaign_pick
    where rn = 1
),

-- 다중캠페인 참고 플래그(실측 137건·0.01%·최대 2)
campaign_multi as (
    select SPNSR_BSNS_NO, count(distinct CMPGN_CD) as DISTINCT_CAMPAIGNS
    from GN_DW.SILVER.CRM_MEMBER_DEV
    group by SPNSR_BSNS_NO
)

select
    span.MBER_NO                                    as MEMBER_DK,
    span.SPNSR_NO,
    span.SPNSR_BSNS_NO,
    coalesce(dsp.SPONSORSHIP_SK, 0)                  as SPONSORSHIP_SK,
    coalesce(dcp.CAMPAIGN_SK, 0)                     as CAMPAIGN_SK,
    iff(cm.DISTINCT_CAMPAIGNS > 1, TRUE, FALSE)      as IS_MULTI_CAMPAIGN,
    span.START_MONTH_KEY,
    span.DSCNTC_MONTH_KEY,
    span.SPNSR_AMT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '0a0f03d1-d7c1-4e10-a7c3-7a79d0fcb1ad'                    AS DW_BATCH_ID
from span
left join campaign_rep cr
       on cr.SPNSR_BSNS_NO = span.SPNSR_BSNS_NO
left join campaign_multi cm
       on cm.SPNSR_BSNS_NO = span.SPNSR_BSNS_NO
left join GN_DW.GOLD.DIM_SPONSORSHIP dsp
       on dsp.SPONSORSHIP_BK = span.SPNSR_BSNS_ID
left join GN_DW.GOLD.DIM_CAMPAIGN dcp
       on dcp.CAMPAIGN_BK = cr.CMPGN_CD