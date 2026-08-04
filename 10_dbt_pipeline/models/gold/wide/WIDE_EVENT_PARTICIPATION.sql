-- WIDE_EVENT_PARTICIPATION: 행사 참여 팩트(FEP) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.8)
-- Co-authored with CoCo
{{ config(
    materialized='view',
    post_hook=[
      "COMMENT ON VIEW {{ this }} IS '행사 참여 팩트 평탄화 (FEP × DATE·MEMBER[현재버전]·EVENT·CAMPAIGN·SPONSORSHIP).'",
      "ALTER VIEW {{ this }} ALTER COLUMN DATE_SK COMMENT '참여일 YYYYMMDD', COLUMN MEMBER_DK COMMENT '참여 회원 (불변키)', COLUMN TOTAL_CNT COMMENT '총인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것', COLUMN WAIT_CNT COMMENT '대기인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것', COLUMN CANCEL_CNT COMMENT '취소인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것', COLUMN CONFIRM_CNT COMMENT '신청확정인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것', COLUMN PARTICIPATE_CNT COMMENT '참여인원 — ⚠️ 행당 상수 1 하드코딩(집계 아님). 취소·불참 행도 1 이므로 상태별 분해 불가', COLUMN ABSENT_CNT COMMENT '불참인원 — 🔴 전건 0(미배선). 원인=O28 코드체계 미확정. 0 을 실측값으로 읽지 말 것', COLUMN PARTICIPANT_CNT COMMENT '참여자수 — ⚠️ 행당 상수 1(=행수). 회원 중복 미제거 → 「몇 명」은 COUNT(DISTINCT MEMBER_DK) 사용((행사,회원) 802,298 < 행수 1,134,126)', COLUMN PARTICIPATION_TIMES COMMENT '참여횟수 — 🔴 전건 0(미배선). 🟢 원천 `PARTCPT_SEQ` 100% 채움이고 O28 과 무관하게 산출 가능', COLUMN WAIT_TIMES COMMENT '대기횟수 — 🔴 전건 0(미배선). O28 확정 후 산출', COLUMN ABSENT_TIMES COMMENT '불참횟수 — 🔴 전건 0(미배선). O28 확정 후 산출', COLUMN CUM_APPLY_TIMES COMMENT '누적신청횟수 — 🔴 전건 0(미배선). `PARTCPT_SEQ` 기반 산출 가능(O28 무관)', COLUMN REGULAR_DONATION COMMENT '정기후원금(원)', COLUMN WIN_FLAG COMMENT '당첨여부', COLUMN SELF_PART_FLAG COMMENT '본인참여여부 — 🔴 전건 NULL(미배선). 원천 대응 미확정', COLUMN PART_STATUS COMMENT '🔴 참여상태 — **코드체계 2개 혼입**(O28). 일반행사=MS304(110=Success·120=Fail·130~220=N_step_right/fail) 707,476행 / 캠페인행사=소정수 1~6 152,046행(의미 미확정·문서20 §I). 판별자=`EVENT_KIND`(단 고아 23.2% 는 `(미매핑)`). **두 체계 합산·GROUP BY 금지** · 한글 비교는 0행 반환', COLUMN PART_PATH COMMENT '참여경로', COLUMN PART_CHANNEL COMMENT '참여채널', COLUMN INCREASE_FLAG COMMENT '증액여부 — 🔴 전건 NULL(미배선). 증액 정소재지는 `FACT_MEMBER_EVENT.DVLP_DIV_CD`(MM015 코드2)', COLUMN DW_SOURCE_SYSTEM COMMENT '원천 시스템 식별', COLUMN FULL_DATE COMMENT 'DIM_DATE.FULL_DATE — 실제 일자', COLUMN YEAR COMMENT 'DIM_DATE.YEAR — 년', COLUMN MONTH COMMENT 'DIM_DATE.MONTH — 월', COLUMN DAY_OF_WEEK COMMENT 'DIM_DATE.DAY_OF_WEEK — 요일', COLUMN WEEK_OF_YEAR COMMENT 'DIM_DATE.WEEK_OF_YEAR — 주차', COLUMN IS_HOLIDAY COMMENT 'DIM_DATE.IS_HOLIDAY — 휴일여부', COLUMN SEX COMMENT 'DIM_MEMBER.SEX — 성별 코드 raw(CM013 0~8). 라벨=SEX_NM(원천)·MEMBER_GENDER_NAME(분석)', COLUMN SEX_NM COMMENT 'DIM_MEMBER.SEX_NM — CM013 원천 라벨(국내/외국인 축 보존)', COLUMN MEMBER_GENDER_NAME COMMENT 'DIM_MEMBER.GENDER_NAME — 성별 (#130) CM017 분석 라벨: 남자/여자/기타/단체/기업', COLUMN MEMBER_AREA_CD COMMENT 'DIM_MEMBER.AREA_CD — 지역 코드 raw(CM018 18종 + sentinel ''0''). 라벨=MEMBER_REGION', COLUMN MEMBER_REGION COMMENT 'DIM_MEMBER.REGION — 지역 (#131) CM018 약칭 라벨(서울/경기/인천…). ⚠️개발약정 **시점 스냅샷**이라 SCD2 버전별로 다를 수 있다(O27). ONCE(일시회원)는 개발약정 부재로 NULL', COLUMN MEMBER_AGE_CD COMMENT 'DIM_MEMBER.AGE — 연령대 코드 raw(CM014 1~12). 🔴연속형 나이가 아니다(1=10대미만…9=70대이상·10=단체·11=기업·12=기타). 라벨=MEMBER_AGE_BAND', COLUMN MEMBER_AGE_BAND COMMENT 'DIM_MEMBER.AGE_BAND — 연령대 CM014 라벨. ⚠️개발약정 **시점 스냅샷**(O27). ONCE 는 NULL', COLUMN MBER_STAT_CD COMMENT 'DIM_MEMBER.MBER_STAT_CD — 회원상태 코드 raw(MM010)', COLUMN MEMBER_STATUS_NAME COMMENT 'DIM_MEMBER.MEMBER_STATUS_NAME — 회원상태 (#132) MM010 라벨: 1활동회원·2~11미납·12후원중단', COLUMN MBER_DIV_CD COMMENT 'DIM_MEMBER.MBER_DIV_CD — 회원구분 코드 raw(MM018)', COLUMN MEMBER_TYPE_NAME COMMENT 'DIM_MEMBER.MEMBER_TYPE_NAME — 회원구분 MM018 라벨(개인/기업/단체)', COLUMN EVENT_BK COMMENT 'DIM_EVENT.EVENT_BK — 행사 업무키', COLUMN EVENT_KIND COMMENT 'DIM_EVENT.EVENT_KIND — 🔴 행사종류 코드 raw(`EVENT`=일반행사 / `CRMN`=캠페인행사). ⚠️종전 COMMENT 「온라인/오프라인」 은 **거짓**이었다(실측 도메인 EVENT 376·CRMN 3,410·NULL 1) → 그 값으로 필터하면 0행 반환. 라벨=`EVENT_KIND_NAME`. 🔷 이 컬럼이 `PART_STATUS` 코드체계 판별자다', COLUMN EVENT_CATEGORY COMMENT 'DIM_EVENT.EVENT_CATEGORY — 행사구분', COLUMN EVENT_NAME COMMENT 'DIM_EVENT.EVENT_NAME — 행사명', COLUMN EVENT_START_DATE COMMENT 'DIM_EVENT.EVENT_START_DATE — 행사기간 시작', COLUMN EVENT_END_DATE COMMENT 'DIM_EVENT.EVENT_END_DATE — 행사기간 종료', COLUMN EVENT_APPLY_CHANNEL COMMENT 'DIM_EVENT.APPLY_CHANNEL — 신청경로', COLUMN EVENT_RECRUIT_HEADCOUNT COMMENT 'DIM_EVENT.RECRUIT_HEADCOUNT — 행사 모집인원(정원). 채움 88.8%. 🔴**행사 grain 값이다** — 참여행마다 반복되므로 이 뷰에서 SUM 하면 101.0배 과대계상된다(행사 참값 4,513,184). 행사 단위로 MAX/평균 또는 DISTINCT 행사 기준으로만 집계할 것', COLUMN PART_EVENT_BK COMMENT '원천 행사키(degenerate key) — 🔴고아 행사 식별자 보존용. 행사 마스터에 없는 53개 행사·263,611행(23.2%)은 EVENT_SK 가 0 으로 뭉개져 서로 구별되지 않았다. ⚠️차원측 EVENT_BK 와 다르다(그쪽은 고아가 ''(미매핑)''). 접두 EVENT_/CRMN_ 가 PART_STATUS 코드체계 판별자', COLUMN PARTCPT_SEQ COMMENT '참여 일련번호(degenerate key) — 🔷(PART_EVENT_BK,MEMBER_DK,PARTCPT_SEQ) 가 행을 유일 식별한다. EVENT_SK 로 대체하면 고아 31,831키·63,783행이 충돌. ⚠️전역 순번 아님 · 원천에 음수 20,844행·INT_MIN 1행 → 식별자 전용, 정렬·범위조건 금지', COLUMN CAMPAIGN_BK COMMENT 'DIM_CAMPAIGN.CAMPAIGN_BK — 캠페인 업무키', COLUMN CAMPAIGN_BRAND COMMENT 'DIM_CAMPAIGN.BRAND — 공통브랜드 (#117)', COLUMN CAMPAIGN_NAME COMMENT 'DIM_CAMPAIGN.CAMPAIGN_NAME — 캠페인명 (#120)', COLUMN SPONSORSHIP_BK COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_BK — 후원사업 업무키', COLUMN SPONSORSHIP_NAME COMMENT 'DIM_SPONSORSHIP.SPONSORSHIP_NAME — 후원사업 전체 (#123)'"
    ]
) }}

select
    f.DATE_SK, f.MEMBER_DK,
    -- [DEC-30] f.RECRUIT_CNT 제거 → e.RECRUIT_HEADCOUNT(행사 차원)으로 대체
    f.TOTAL_CNT, f.WAIT_CNT, f.CANCEL_CNT,
    f.CONFIRM_CNT, f.PARTICIPATE_CNT, f.ABSENT_CNT,
    f.PARTICIPANT_CNT, f.PARTICIPATION_TIMES,
    f.WAIT_TIMES, f.ABSENT_TIMES, f.CUM_APPLY_TIMES,
    f.REGULAR_DONATION,
    f.WIN_FLAG, f.SELF_PART_FLAG, f.PART_STATUS,
    f.PART_PATH, f.PART_CHANNEL, f.INCREASE_FLAG,
    -- [DEC-30] degen key 2종. 🔷유일 식별 = (PART_EVENT_BK, MEMBER_DK, PARTCPT_SEQ).
    --   ⚠️PART_EVENT_BK(팩트·고아 포함 전건) 와 EVENT_BK(차원 매칭·고아는 '(미매핑)') 는 다르다.
    f.EVENT_BK            as PART_EVENT_BK,
    f.PARTCPT_SEQ         as PARTCPT_SEQ,
    f.DW_SOURCE_SYSTEM,
    d.FULL_DATE, d.YEAR, d.MONTH, d.DAY_OF_WEEK, d.WEEK_OF_YEAR, d.IS_HOLIDAY,
    -- [2026-08-03 O26] 회원 속성 노출 재구성 — 코드=BRONZE 원천명 · 라벨=분석 용어.
    --   종전은 코드만(`MEMBER_GENDER`=M/F/U 등) 노출해 현업이 WIDE 에서 코드만 보던 상태였다.
    m.SEX                 as SEX,                     -- CM013 코드 raw
    m.SEX_NM              as SEX_NM,                  -- CM013 원천 라벨(국내/외국인 축)
    m.GENDER_NAME         as MEMBER_GENDER_NAME,      -- CM017 분석 라벨 = 정본 공#130
    m.AREA_CD             as MEMBER_AREA_CD,          -- [O27] CM018 코드 raw (라벨=MEMBER_REGION)
    m.REGION              as MEMBER_REGION,
    m.AGE                 as MEMBER_AGE_CD,           -- [O27] CM014 코드 raw. ⚠️연속형 나이 아님
    m.AGE_BAND            as MEMBER_AGE_BAND,
    m.MBER_STAT_CD        as MBER_STAT_CD,            -- MM010 코드 raw
    m.MEMBER_STATUS_NAME  as MEMBER_STATUS_NAME,      -- MM010 분석 라벨(#132)
    m.MBER_DIV_CD         as MBER_DIV_CD,             -- MM018 코드 raw
    m.MEMBER_TYPE_NAME    as MEMBER_TYPE_NAME,        -- MM018 분석 라벨
    e.EVENT_BK            as EVENT_BK,
    e.EVENT_KIND          as EVENT_KIND,
    e.EVENT_CATEGORY      as EVENT_CATEGORY,
    e.EVENT_NAME          as EVENT_NAME,
    e.EVENT_START_DATE    as EVENT_START_DATE,
    e.EVENT_END_DATE      as EVENT_END_DATE,
    e.APPLY_CHANNEL       as EVENT_APPLY_CHANNEL,
    e.RECRUIT_HEADCOUNT   as EVENT_RECRUIT_HEADCOUNT,  -- [DEC-30] 행사 정원(행사 grain) — 참여행 반복 합산 금지
    c.CAMPAIGN_BK         as CAMPAIGN_BK,
    c.BRAND               as CAMPAIGN_BRAND,
    c.CAMPAIGN_NAME       as CAMPAIGN_NAME,
    s.SPONSORSHIP_BK      as SPONSORSHIP_BK,
    s.SPONSORSHIP_NAME    as SPONSORSHIP_NAME
from {{ ref('FACT_EVENT_PARTICIPATION') }} f
left join {{ ref('DIM_DATE') }} d on f.DATE_SK = d.DATE_SK
left join (
    select MEMBER_DK, SEX, SEX_NM, GENDER_NAME, AREA_CD, REGION, AGE, AGE_BAND, MBER_STAT_CD, MEMBER_STATUS_NAME, MBER_DIV_CD, MEMBER_TYPE_NAME
    from {{ ref('DIM_MEMBER') }}
    where IS_CURRENT = TRUE
    qualify ROW_NUMBER() OVER (PARTITION BY MEMBER_DK
        ORDER BY EFFECTIVE_FROM DESC NULLS LAST, MEMBER_SK DESC) = 1
) m on f.MEMBER_DK = m.MEMBER_DK
left join {{ ref('DIM_EVENT') }}       e on f.EVENT_SK       = e.EVENT_SK
left join {{ ref('DIM_CAMPAIGN') }}    c on f.CAMPAIGN_SK    = c.CAMPAIGN_SK
left join {{ ref('DIM_SPONSORSHIP') }} s on f.SPONSORSHIP_SK = s.SPONSORSHIP_SK
