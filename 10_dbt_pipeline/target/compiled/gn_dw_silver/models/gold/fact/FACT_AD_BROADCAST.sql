-- FACT_AD_BROADCAST: 광고성과 위성 — 방송(VIDEO·REBRDC) 고유속성. 순서9-I 신설(DEC-8).
-- Co-authored with CoCo
-- grain: AD_PERF_DK — 코어 FACT_AD_PERFORMANCE 와 **1:1**(방송 2원천 행만 존재, 실측 37,886행).
-- ⚠️ 조인: `FACT_AD_PERFORMANCE f JOIN FACT_AD_BROADCAST b USING (AD_PERF_DK)` — 1:1이라 fan-out 없음.
-- ⚠️ 여기 담긴 degen 5종(TIME_BAND·CM_POSITION·RT_TYPE·AD_START_TIME·BROADCAST_DATE)은 종전 코어에
--    `CAST(NULL AS ..)` 하드코딩으로 자리만 있던 컬럼이다(값미주입 결함군). 본 위성에서 **실배선**된다.
-- ⚠️ 컬럼 내 NULL 은 '두 방송 원천 중 한쪽에만 있는 속성'을 뜻하며 결측이 아니다
--    (예: SPOT_TYPE·DURATION_SEC 는 VIDEO 전용 / RT_TYPE·BRDC_DIV 는 REBRDC 전용).
-- ⚠️ O16 해소: DVLP_MEMBER_CNT·DVLP_CNT = 재방송 **개발실적**. 종전 코어의 GA_CONV_MEMBERS·GA_CONV_CNT
--    자리에 위치매핑돼 'GA 전환'으로 혼입돼 있던 값을 고유 이름으로 분리했다(문서10 §8-I(8)).
-- ⚠️ `_SRC` = 대행사 산정 파생값(DEC-9). **N(비가산)** — SUM 금지, 집계는 base 재계산값 사용.


select
    AD_PERF_DK              as AD_PERF_DK,
    TIME_BAND               as TIME_BAND,               -- 시간대
    CM_POSITION             as CM_POSITION,             -- CM위치 (VIDEO 전용)
    RT_TYPE                 as RT_TYPE,                 -- RT유형 (REBRDC 전용)
    AD_START_TIME           as AD_START_TIME,           -- 광고시작시간 (VIDEO 전용)
    AD_END_TIME             as AD_END_TIME,             -- 광고종료시간 (VIDEO 전용)
    BROADCAST_DATE          as BROADCAST_DATE,          -- 송출일 (≠ 코어 PERF_DATE_SK 실적일)
    PROGRAM_NM              as PROGRAM_NM,              -- 프로그램/편성명
    CHANNEL_COMPANY         as CHANNEL_COMPANY,         -- 채널사
    CHANNEL_COMPANY_TYPE    as CHANNEL_COMPANY_TYPE,    -- 채널사유형 (VIDEO 전용)
    SPOT_TYPE               as SPOT_TYPE,               -- SPOT유형 (VIDEO 전용)
    DURATION_SEC            as DURATION_SEC,            -- 광고 초수 (VIDEO 전용)
    DAY_DIV                 as DAY_DIV,                 -- 요일구분 평일/주말 (VIDEO 전용)
    PRG_START_TIME          as PRG_START_TIME,          -- 프로그램 시작시간 (VIDEO 전용)
    CTV_DIV                 as CTV_DIV,                 -- CTV구분 (VIDEO 전용)
    BRDC_DIV                as BRDC_DIV,                -- 방송구분 (REBRDC 전용)
    AD_CNT                  as AD_CNT,                  -- 광고횟수
    CONV_CALL_CNT           as CONV_CALL_CNT,           -- 전환콜 (인입콜과 별개, VIDEO 전용)
    DVLP_MEMBER_CNT         as DVLP_MEMBER_CNT,         -- O16: 개발회원수 (REBRDC 전용)
    DVLP_CNT                as DVLP_CNT,                -- O16: 개발건수 (REBRDC 전용)
    AD_VIEW_RT_SRC          as AD_VIEW_RT_SRC,          -- N(비가산) 대행사 산정, 재계산 불가
    CPC_SRC                 as CPC_SRC,                 -- N(비가산) 대행사 산정, DW=AD_COST/CLICKS
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '8892b58a-55ca-4860-92ec-fb71fa7ce65a'                    AS DW_BATCH_ID
from GN_DW.SILVER.AGENCY_AD_BROADCAST