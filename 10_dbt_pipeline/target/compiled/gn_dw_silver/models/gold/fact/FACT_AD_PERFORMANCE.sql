-- FACT_AD_PERFORMANCE: 광고성과 코어 팩트 (SILVER.AGENCY_AD_PERFORMANCE), 순서9-C 신설 · 9-I 재설계.
-- Co-authored with CoCo
-- grain: AD_PERF_DK (원천 1행 = 팩트 1행). 분석축 = PERF_DATE × CAMPAIGN × AD_CREATIVE × DEVICE.
--
-- ⚠️ [2026-07-28 DEC-8] 코어는 **3원천 공통 속성만** 보유한다. 방송 고유 degen 5종
--    (TIME_BAND·CM_POSITION·RT_TYPE·AD_START_TIME·BROADCAST_DATE)은 위성 FACT_AD_BROADCAST 로 이관.
--    이관 사유: 방송 전용이라 디지털 197,686행에서 항상 NULL → 희소 팩트 + NULL 의미 모호.
-- ⚠️ [2026-07-28 DEC-10] `DEVICE_SK` **실배선 완료**. 종전 `0 as DEVICE_SK` 하드코딩으로 235,572행
--    전건 (unknown) → 지표 공14(기기별) 사용 불가 상태였다.
--    ✅ 이전 주석의 "AGENCY device 도메인 ≠ GA4 기반 DIM_DEVICE" 단정은 **실측과 불일치**였다(P14 위반):
--       AGENCY DEVICE_NM = M(138,274) · PC(59,412) · NULL(37,886) → GOLD DIM_DEVICE {M, PC} 와 네이티브 동일.
--       NULL 37,886 = VIDEO 35,822 + REBRDC 2,064 = 방송 전량(기기 개념 부재) 으로 전량 설명된다.
--    라우팅: 실기기 → 해시 SK / 방송(AD_SOURCE_TYPE 방송 2종) → `(해당없음)` 멤버 / 그 외 미매핑 → 0(unknown).
--
-- ⚠️ 잔여 스캐폴드 (게이트 미해소 — 해소 시 본 주석과 함께 정정할 것):
--   · CAMPAIGN_SK=0: 캠페인 이름매칭(Q10 연결키·DIM_CAMPAIGN 키 확정) 대기. 이름컬럼 존재 → 후속 매칭 가능.
--   · AD_CREATIVE_SK=0: DIM_AD_CREATIVE 키(MD5[SOURCE|MEDIA|CREATIVE|TYPE|CM_AREA|AD_SEC])가
--     성과테이블에 미보유(TYPE/CM_AREA/AD_SEC 부재) → 정합 조인 불가. 부분키 매칭 설계 대기.


with p as (
    select * from GN_DW.SILVER.AGENCY_AD_PERFORMANCE
),
dev as (
    -- 기기 차원 조회용 축약 — DEVICE_TYPE 은 GOLD 내 유일값이므로 fan-out 없음.
    select DEVICE_TYPE, DEVICE_SK from GN_DW.GOLD.DIM_DEVICE
)

select
    p.AD_PERF_DK                            as AD_PERF_DK,
    COALESCE(CASE WHEN p.AD_DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(p.AD_DATE, 'YYYYMMDD')) END, 0) as PERF_DATE_SK,
    0                            as CAMPAIGN_SK,      -- Q10 이름매칭 대기
    0                            as AD_CREATIVE_SK,   -- 소재 부분키 매칭 대기
    -- DEC-10 기기축 실배선: 실기기 조인 → 실패 시 방송은 (해당없음), 그 외는 0(unknown)
    COALESCE(d_real.DEVICE_SK, d_na.DEVICE_SK, 0)     as DEVICE_SK,
    p.AD_COST                    as AD_COST,
    p.IMPRESSION_CNT             as IMPRESSIONS,
    p.CLICK_CNT                  as CLICKS,
    p.INBOUND_CALL_CNT           as INBOUND_CALL,
    p.CONV_MEMBER_CNT            as GA_CONV_MEMBERS,  -- O16 해소: DIGITAL 전용(재방송 개발실적 제외)
    p.CONV_UNIT_CNT              as GA_CONV_CNT,      -- O16 해소: DIGITAL 전용(재방송 개발실적 제외)
    DAYNAME(p.AD_DATE)           as DAY_OF_WEEK,      -- degen(AD_DATE 파생)
    WEEKOFYEAR(p.AD_DATE)        as WEEK_OF_YEAR,     -- degen(AD_DATE 파생)
    p.AD_SOURCE_TYPE                    as AD_SOURCE_TYPE,          -- degen 출처 명시축(DEC-8·§3-A-4): DIGITAL/VIDEO/REBROADCAST
    'AGENCY'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'caf0ed7e-1e99-4c1d-b479-e0fc6272f462'                    AS DW_BATCH_ID
from p
-- 실기기 매칭(DGT). 방송행은 DEVICE_NM 이 NULL 이라 매칭되지 않는다.
left join dev d_real
       on d_real.DEVICE_TYPE = p.DEVICE_NM
-- 방송행 전용 `(해당없음)` 라우팅(DEC-10)
left join dev d_na
       on d_na.DEVICE_TYPE = '(해당없음)'
      and p.AD_SOURCE_TYPE in ('VIDEO','REBROADCAST')