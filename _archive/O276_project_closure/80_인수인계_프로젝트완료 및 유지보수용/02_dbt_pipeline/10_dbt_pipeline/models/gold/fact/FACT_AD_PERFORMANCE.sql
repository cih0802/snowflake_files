-- =============================================================================
-- Purpose    : 광고성과 코어 팩트 (SILVER.AGENCY_AD_PERFORMANCE), 순서9-C 신설 · 9-I 재설계.
-- Target     : GOLD.FACT_AD_PERFORMANCE (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref AGENCY_AD_PERFORMANCE, ref DIM_DEVICE, ref CRM_CAMPAIGN, ref DIM_MARKETING_CAMPAIGN, ref AGENCY_AD_ROW_DGT, ref AGENCY_AD_ROW_VIDEO 외 2
-- Issue      : DEC-8, DEC-10, O45, O225 외 10
-- =============================================================================
-- FACT_AD_PERFORMANCE: 광고성과 코어 팩트 (SILVER.AGENCY_AD_PERFORMANCE), 순서9-C 신설 · 9-I 재설계.
-- grain: AD_PERF_DK (원천 1행 = 팩트 1행). 분석축 = PERF_DATE × CAMPAIGN × AD_CREATIVE × DEVICE.
--
-- WARN: [2026-07-28 DEC-8] 코어는 **3원천 공통 속성만** 보유한다. 방송 고유 degen 5종
--    (TIME_BAND·CM_POSITION·RT_TYPE·AD_START_TIME·BROADCAST_DATE)은 위성 FACT_AD_BROADCAST 로 이관.
--    이관 사유: 방송 전용이라 디지털 197,686행에서 항상 NULL → 희소 팩트 + NULL 의미 모호.
-- WARN: [2026-07-28 DEC-10] `DEVICE_SK` **실배선 완료**. 종전 `0 as DEVICE_SK` 하드코딩으로 235,572행
--    전건 (unknown) → 지표 공14(기기별) 사용 불가 상태였다.
--     이전 주석의 "AGENCY device 도메인 ≠ GA4 기반 DIM_DEVICE" 단정은 **실측과 불일치**였다(P14 위반):
--       AGENCY DEVICE_NM = M(138,274) · PC(59,412) · NULL(37,886) → GOLD DIM_DEVICE {M, PC} 와 네이티브 동일.
--       NULL 37,886 = VIDEO 35,822 + REBRDC 2,064 = 방송 전량(기기 개념 부재) 으로 전량 설명된다.
--    라우팅: 실기기 → 해시 SK / 방송(AD_SOURCE_TYPE 방송 2종) → `(해당없음)` 멤버 / 그 외 미매핑 → 0(unknown).
--
-- WARN: 잔여 스캐폴드 (게이트 미해소 — 해소 시 본 주석과 함께 정정할 것):
--   · CAMPAIGN_SK=0: **개발캠페인** 직접 매칭은 여전히 대기(Q10). 단 [2026-08-06 O45] 부터
--     **마케팅캠페인 축(`MKTG_CAMPAIGN_SK`)이 89.7% 로 살아 있다** → 광고↔개발 결합은 그 grain 에서
--     성립한다. 「광고와 CRM 은 연결할 수 없다」는 서술은 회수됐다(P61).
--   · AD_CREATIVE_SK=0: DIM_AD_CREATIVE 키(MD5[SOURCE|MEDIA|CREATIVE|TYPE|CM_AREA|AD_SEC])가
--     성과테이블에 미보유(TYPE/CM_AREA/AD_SEC 부재) → 정합 조인 불가. 부분키 매칭 설계 대기.
{{ config(
    tags=['gold_pending']
) }}

with p as (
    select * from {{ ref('AGENCY_AD_PERFORMANCE') }}
),
dev as (
    -- 기기 차원 조회용 축약 — DEVICE_TYPE 은 GOLD 내 유일값이므로 fan-out 없음.
    select DEVICE_TYPE, DEVICE_SK from {{ ref('DIM_DEVICE') }}
),
--  [2026-10-14 O225] UTM 보조 경로 — 이름매칭(O45) 실패 행에만 적용한다(이름매칭 우선).
--   왜: DIGITAL 미매핑 11,379,933,112원(33.69%) 중 8,686,093,136원이 UTM 후보를 가진다(이전 계정 실측).
--   WARN: 1:N 을 버리지 않는다(`HAVING = 1` 폐기 금지 · 작업계획 §15-9) — 광고행마다 as-of 대표 1개:
--     ① 캠페인 시작일 ≤ 광고일(시점 필터) ② 매핑 행수 최다 ③ 시작일 최근 ④ 마케팅캠페인명 ⑤ 코드(결정성).
--   WARN: [O225 교정] §15-9 초안은 ② 시작일 최근 → ③ 행수 순이었다 — 실측하니 1:N 비용 57.3억 중
--     turn24b 4,895,482,455원 전액이 협업 캠페인(사진실의광선생님_* · 매핑 6행)으로, meal24a 779,488,400원이
--     `사진실의광선생님_정용화` 로 갔다(본 캠페인 `유어턴(2기)` 609행 · `국내결식(한끼모험)` 은 0원) ⇒ 행수 우선으로 뒤집었다.
--   WARN: 「가장 최근 생성」 단독 규칙은 쓰지 않는다(광고일 이후 생성 캠페인 귀속 22.47% · 시점 역전).
--   이름매칭 ↔ UTM 1:1 일치 = 91.9%(광고비 기준 13,849,338,516 / 15,062,608,889) ⇒ 이름매칭을 우선한다.
utm_cand as (
    select
        c.MKTG_UTM_NM                                       as UTM_NM,
        mk.MKTG_CAMPAIGN_SK                                 as MKTG_CAMPAIGN_SK,
        mk.MKTG_CAMPAIGN_NAME                               as MKTG_CAMPAIGN_NAME,
        mk.MKTG_CAMPAIGN_BK                                 as MKTG_CAMPAIGN_BK,
        min(TRY_TO_DATE(c.CMPGN_STRT_DE, 'YYYYMMDD'))       as STRT_DATE,
        count(*)                                            as MAP_ROWS
    from {{ ref('CRM_CAMPAIGN') }} c
    join {{ ref('DIM_MARKETING_CAMPAIGN') }} mk
      on mk.MKTG_CAMPAIGN_BK = TO_VARCHAR(c.MKTG_CMPGN_NM)
    where c.MKTG_UTM_NM is not null
    group by 1, 2, 3, 4
),
utm_pick as (
    select
        p.AD_PERF_DK,
        u.MKTG_CAMPAIGN_SK,
        count(*) over (partition by p.AD_PERF_DK)          as CAND_CNT
    from p
    join {{ ref('AGENCY_AD_ROW_DGT') }} d on d.AD_PERF_DK = p.AD_PERF_DK
    join utm_cand u
      on u.UTM_NM = d.UTM_CMPGN_NM
     and u.STRT_DATE <= p.AD_DATE
    qualify row_number() over (
        partition by p.AD_PERF_DK
        order by u.MAP_ROWS desc, u.STRT_DATE desc, u.MKTG_CAMPAIGN_NAME, u.MKTG_CAMPAIGN_BK
    ) = 1
),
--  [2026-10-16 O238 W3-L4 · 사용자 결정 = 코드형 값만 즉시 연결] 영상 「상위캠페인」 열의 코드형 값(U####)
--   → CRM 상위캠페인코드 → 하위 캠페인의 마케팅캠페인. WARN: 마케팅캠페인이 **정확히 1개**인 코드만 쓴다(1:N 은 미매핑 유지 · 추측 금지).
--   이름형 값(TV_ 접두 등)은 쓰지 않는다 — 현업 코드 전환(O238 W5) 대기. 실측 = 코드 10종 전건 1:1 · 3,406행.
video_code_mk as (
    select UPPER(TRIM(c.UPPER_CMPGN_CD)) as UPPER_CODE, MIN(mk.MKTG_CAMPAIGN_SK) as MKTG_CAMPAIGN_SK
    from {{ ref('CRM_CAMPAIGN') }} c
    join {{ ref('DIM_MARKETING_CAMPAIGN') }} mk
      on mk.MKTG_CAMPAIGN_BK = TO_VARCHAR(c.MKTG_CMPGN_NM)
    where c.UPPER_CMPGN_CD is not null and c.MKTG_CMPGN_NM is not null
    group by 1
    having COUNT(DISTINCT mk.MKTG_CAMPAIGN_SK) = 1
),
--  [2026-10-25 O262 · 사용자 결정 = O261-B ㉮ [5] 채택 · N-29 ⑥ 보류 해제] 영상 이름형 상위캠페인(SILVER UPPER_CAMPAIGN_NM)
--   → 마케팅캠페인명 정확 일치. 코드 경로(UPPER_CODE) **뒤** 순위 · 이름이 DIM 에서 유일한 것만(HAVING = 1 · 추측 금지).
--   실측(build 후) = 이름형 4,086행 중 DIM 이름 일치 643행 — 전부 이미 NAME 경로로 **같은 캠페인**(다른 캠페인 0)
--     ⇒ 현 데이터에서 새로 연결되는 행 0 · 경로는 신규 값 대비. CRM 캠페인명 일치 5종은 CRM 마케팅캠페인명이 비어 경로 없음.
video_name_mk as (
    select MKTG_CAMPAIGN_NAME as MKTG_NAME, MIN(MKTG_CAMPAIGN_SK) as MKTG_CAMPAIGN_SK
    from {{ ref('DIM_MARKETING_CAMPAIGN') }}
    group by 1
    having COUNT(*) = 1
)

select
    p.AD_PERF_DK                            as AD_PERF_DK,
    COALESCE({{ date_sk('p.AD_DATE') }}, 0) as PERF_DATE_SK,
    0                            as CAMPAIGN_SK,      -- Q10 이름매칭 대기
    0                            as AD_CREATIVE_SK,   -- 소재 부분키 매칭 대기
    -- DEC-10 기기축 실배선: 실기기 조인 → 실패 시 방송은 (해당없음), 그 외는 0(unknown)
    COALESCE(d_real.DEVICE_SK, d_na.DEVICE_SK, 0)     as DEVICE_SK,
    p.AD_COST                    as AD_COST,
    p.IMPRESSION_CNT             as IMPRESSIONS,
    p.CLICK_CNT                  as CLICKS,
    p.INBOUND_CALL_CNT           as INBOUND_CALL,
    p.CONV_MEMBER_CNT            as AGENCY_CONV_MEMBERS,  -- O16 해소: DIGITAL 전용(재방송 개발실적 제외)
    p.CONV_UNIT_CNT              as AGENCY_CONV_CNT,      -- O16 해소: DIGITAL 전용(재방송 개발실적 제외)
    DAYNAME(p.AD_DATE)           as DAY_OF_WEEK,      -- degen(AD_DATE 파생)
    WEEKOFYEAR(p.AD_DATE)        as WEEK_OF_YEAR,     -- degen(AD_DATE 파생)
    p.AD_SOURCE_TYPE                    as AD_SOURCE_TYPE,          -- degen 출처 명시축(DEC-8·§3-A-4): DIGITAL/VIDEO/REBROADCAST
    -- ── [2026-08-06 O45] WARN: 마케팅캠페인 축 신설(물리 위치 = 맨 끝, ALTER ADD COLUMN 규약) ──
    --   종전 `CAMPAIGN_SK=0` 만 있어 **광고 ↔ CRM 후원 결합이 전면 불가**했다(O44 차단 4필드 + ROAS).
    --    원천은 살아 있었다: `SILVER.AGENCY_AD_PERFORMANCE.CAMPAIGN_NM` 채움 240,291/243,545(98.7%)·110종.
    --      GOLD 로 전파되지 않은 **배선 누락**이었다(원천 부재가 아니다).
    --   실측 도달률: `DIM_MARKETING_CAMPAIGN`(323행) 이름매칭 **218,402/243,545 = 89.7%**
    --   실측 결합 결과(마케팅캠페인 grain): 79 캠페인 · 광고행 216,481(폭발 0) ·
    --      광고비 34,209,625,719원 · 개발 463,279건 → **개발단가 73,842원**
    --   WARN: **개발캠페인(`CAMPAIGN_SK`) grain 으로 내리지 말 것** — 팬아웃 실측(2026-08-06 재측정):
    --      광고캠페인명 110종 중 마스터와 일치 **81종** → 개발캠페인 **9,750종**(평균 120.4 · 최대 901)
    --      → naive 조인 시 **218,402행 → 39,669,103행 = 181.6배 폭발**하고 광고비가 그만큼 복제된다.
    --      WARN: 종전 기술 「76종 · 9,037종 · 평균 118.9 · 183,170→36,629,512 = 200배」는 **재현 불가**
    --         하여 위 실측값으로 교체했다(P89). 같은 문단의 89.7%·98.7% 는 재현된다.
    --      개발캠페인 단위 ROI 는 현업의
    --      **광고비 배분 규칙**이 있어야 한다(Q10 재정의 — 원천 입고 사안이 아니다).
    --   WARN: 이름매칭이 유일한 경로다(AGENCY 원천 3종에 캠페인 **코드 컬럼 0개**) → 10.3% 미도달은
    --      센티넬 0 으로 간다. 이 버킷을 「미집행」으로 읽지 말 것.
    COALESCE(mk.MKTG_CAMPAIGN_SK, up.MKTG_CAMPAIGN_SK, cm_mk.MKTG_CAMPAIGN_SK, vc.MKTG_CAMPAIGN_SK, rc.MKTG_CAMPAIGN_SK, vn.MKTG_CAMPAIGN_SK, 0) as MKTG_CAMPAIGN_SK,   -- O225: 이름 → UTM · O232: → 소재 매핑(MKTG) · O238: → 영상 상위캠페인코드 · O245: → 재방송 상위캠페인코드 · O262: → 영상 상위캠페인명 → 0
    {{ gold_meta('AGENCY') }},
    --  [2026-09-29 O188] 신규지표 #9 「매체별 직접모금비」 — REBRDC 비용 분해 전파(물리 위치 = 맨 끝 · 06_DDL 동기)
    p.CONTENTS_PUR_COST          as CONTENTS_PUR_COST,
    p.CALL_CTR_OPER_COST         as CALL_CTR_OPER_COST,
    p.TOT_COST                   as TOT_COST,
    --  [2026-10-08 O213-F Y3-G] 광고 분류 축 10 — AD_PERF_DK 1:1(ROW_DGT·ROW_VIDEO 키 유일 실측) · 감사컬럼 뒤 append.
    --   원천 컬럼명 원칙(O212) · 원천에 개념이 없는 출처 행은 NULL(결측 아님). 상위캠페인명(코드·이름 혼재)은 ~~보류(문서20 N-29 ⑥)~~ ⇒ [O262] 분리 후 맨 끝 2열로 승격.
    p.MEDIA_CHANNEL_NM           as MEDIA_CHANNEL_NM,      -- 매체/채널(전 원천)
    p.CREATIVE_NM                as CREATIVE_NM,           -- 소재명(DGT MATR · VIDEO MATR_NM · REBRDC BRDC_NM)
    p.COST_TYPE                  as COST_TYPE,             -- 비용유형 GA/집행/편성
    COALESCE(d.BDGT_SOURCE_NM, v.BDGT_SOURCE_NM)  as BDGT_SOURCE_NM,   -- 예산출처(사단·사복·통합 · DGT·VIDEO)
    COALESCE(d.MATR_TY_NM, v.MATR_TY_NM)          as MATR_TY_NM,       -- 소재유형(DGT·VIDEO)
    d.CMPGN_TYPE_BSN_NM          as CMPGN_TYPE_BSN_NM,     -- 캠페인유형(사업) [DGT 전용]
    d.UTM_CMPGN_NM               as UTM_CMPGN_NM,          -- UTM 캠페인 [DGT 전용]
    v.BSNS_CASE_DIV_NM           as BSNS_CASE_DIV_NM,      -- 사업/사례 구분 [VIDEO 전용]
    v.CM                         as CM,                    -- CM 구분(전CM·중CM·후CM) [VIDEO 전용]
    v.DMST_OVSEA_DIV_NM          as DMST_OVSEA_DIV_NM,     -- 국내/해외 구분 [VIDEO 전용]
    --  [2026-10-14 O225] 귀속 경로·후보 수(06_DDL 동기 · 맨 끝 append) — 1:N 은 버리지 않고 표시한다.
    case when mk.MKTG_CAMPAIGN_SK is not null then 'NAME'
         when up.MKTG_CAMPAIGN_SK is not null then 'UTM'
         when cm_mk.MKTG_CAMPAIGN_SK is not null then 'CREATIVE_MAP'
         when vc.MKTG_CAMPAIGN_SK is not null then 'UPPER_CODE'
         when rc.MKTG_CAMPAIGN_SK is not null then 'UPPER_CODE'
         when vn.MKTG_CAMPAIGN_SK is not null then 'UPPER_NAME'    -- O262
          else 'NONE' end         as MKTG_MAP_METHOD,
    iff(mk.MKTG_CAMPAIGN_SK is null, up.CAND_CNT, NULL)  as MKTG_MAP_CAND_CNT,
    --  [2026-10-15 O232 · 사용자 확정 추천안] 소재 매핑 3순위 — 이름매칭·UTM 실패 행에만 적용한다(06_DDL 동기 · 맨 끝 append).
    --   재방송 = 캠페인카테고리 수준(한 방송에 마케팅캠페인 6~23개 → 아래로 배분하지 않는다) · 영상 = 마케팅캠페인 1개 확정분만 MKTG.
    --   WARN: 매핑표는 dbt 가 만들지 않는다(SILVER.AD_CREATIVE_CAMPAIGN_MAP · 소유자 롤 적재 · 08 DDL 정본).
    iff(mk.MKTG_CAMPAIGN_SK is null and up.MKTG_CAMPAIGN_SK is null, cm.MAP_LEVEL, NULL)       as AD_MAP_LEVEL,
    iff(mk.MKTG_CAMPAIGN_SK is null and up.MKTG_CAMPAIGN_SK is null, cm.CMPGN_CTGR_NM, NULL)   as AD_MAP_CMPGN_CTGR_NM,
    --  [2026-10-15 O232-B · 사용자 요청] 광고비 귀속 카테고리(전 광고행 단일 축 · 06_DDL 동기 · 맨 끝 append)
    --   우선순위 = 이름매칭·UTM 연결 → 그 마케팅캠페인의 대표 카테고리(MKTG_REP) → 소재 매핑 확정 카테고리(CREATIVE_MAP) → NULL.
    --   WARN: MKTG_REP 는 대표값이다 — 다중이면 AD_CTGR_IS_MULTI = TRUE(광고비 기준 약 72%) · CREATIVE_MAP 은 확정이라 FALSE.
    --   WARN: 이름매칭이 성공하면 그 캠페인 값만 쓴다(카테고리가 비어도 UTM 쪽으로 넘어가지 않는다) ⇒ coalesce 가 아니라 iff.
    case when mk.MKTG_CAMPAIGN_SK is not null then mk.CMPGN_CTGR_CD
         when up.MKTG_CAMPAIGN_SK is not null then up_mk.CMPGN_CTGR_CD
         else cm.CMPGN_CTGR_CD end                                                as AD_CTGR_CD,
    case when mk.MKTG_CAMPAIGN_SK is not null then mk.CMPGN_CTGR_NM
         when up.MKTG_CAMPAIGN_SK is not null then up_mk.CMPGN_CTGR_NM
         else cm.CMPGN_CTGR_NM end                                                as AD_CTGR_NM,
    case when mk.MKTG_CAMPAIGN_SK is not null then iff(mk.CMPGN_CTGR_CD is null, 'NONE', 'MKTG_REP')
         when up.MKTG_CAMPAIGN_SK is not null then iff(up_mk.CMPGN_CTGR_CD is null, 'NONE', 'MKTG_REP')
         when cm.CMPGN_CTGR_NM is not null then 'CREATIVE_MAP'
         else 'NONE' end                                                          as AD_CTGR_SRC,
    case when mk.MKTG_CAMPAIGN_SK is not null then mk.CMPGN_CTGR_IS_MULTI
         when up.MKTG_CAMPAIGN_SK is not null then up_mk.CMPGN_CTGR_IS_MULTI
         when cm.CMPGN_CTGR_NM is not null then FALSE end                         as AD_CTGR_IS_MULTI,
    --  [2026-10-15 O233 · 사용자 결정 #36] 표시 전용 카테고리명 나열(06_DDL 동기 · 맨 끝 append) — AD_CTGR_NM 과 같은 우선순위.
    --   MKTG_REP = 그 마케팅캠페인의 나열(첫 항목 = AD_CTGR_NM) · CREATIVE_MAP = 확정 이름 1개 · NONE = NULL.
    --   WARN: 그루핑·필터·합산 금지 — 집계는 AD_CTGR_NM 으로만 한다.
    case when mk.MKTG_CAMPAIGN_SK is not null then iff(mk.CMPGN_CTGR_CD is null, NULL, mk.CMPGN_CTGR_NM_LIST)
         when up.MKTG_CAMPAIGN_SK is not null then iff(up_mk.CMPGN_CTGR_CD is null, NULL, up_mk.CMPGN_CTGR_NM_LIST)
         else cm.CMPGN_CTGR_NM end                                                as AD_CTGR_NM_LIST,
    --  [2026-10-25 O262 · N-29 ⑥ 보류 해제] 영상 상위캠페인 코드·이름(SILVER O262 형태 분리 · 06_DDL 동기 · 맨 끝 append)
    --   VIDEO 전용 · 그 밖 원천 개념 부재 NULL · 두 열 동시 채움 0(SILVER 테스트 assert_aap_upper_cmpgn_split).
    p.UPPER_CAMPAIGN_CD          as UPPER_CAMPAIGN_CD,     -- 코드형(U####) = CRM 상위캠페인코드
    p.UPPER_CAMPAIGN_NM          as UPPER_CAMPAIGN_NM,     -- 이름형(~2026-05 · 원천이 개명 전 값을 둠)
    --  [2026-10-25 O262-B · 33_카테고리_GOLD반영계획 §1] 캠페인 유형 라벨 원값 3열(staging 1:1 · 06_DDL 동기 · 맨 끝 append)
    d.CMPGN_TYPE1_BSN_NM         as CMPGN_TYPE1_BSN_NM,    -- 국내·해외·통합·전체 [DGT 전용]
    d.CMPGN_TYPE2_BSN_NM         as CMPGN_TYPE2_BSN_NM,    -- 사례·사업·굿즈·기타·통합 [DGT 전용]
    v.CMPGN_TY_NM                as CMPGN_TY_NM,           -- 「해외 사례」 등 국내외×사업사례 결합 라벨 [VIDEO 전용 · CTV 시트 외 NULL]
    --  [2026-10-28 O266 · 사용자 결정 ㉠-b] 최종정산금액(원천 LAST_STMT_AMT = 광고비 + 마크업 + 부가세 · 06_DDL 동기 · 맨 끝 append)
    --   DGT 전용 — VIDEO 는 정산 개념 컬럼이 없고(LAST_AD_COST = 코어 AD_COST) REBRDC TOT_COST 는 「총비용」(편성+콘텐츠+콜센터)이라 대체물이 아니다 ⇒ NULL.
    --   실측(ZS83821) = 410.9억 · AD_COST+MARKUP+VAT 일치 238,218/240,105행 · NULL 5행.
    iff(p.AD_SOURCE_TYPE = 'DIGITAL', d.LAST_STMT_AMT, NULL)  as LAST_STMT_AMT
from p
left join {{ ref('AGENCY_AD_ROW_DGT') }}   d on d.AD_PERF_DK = p.AD_PERF_DK
left join {{ ref('AGENCY_AD_ROW_VIDEO') }} v on v.AD_PERF_DK = p.AD_PERF_DK
-- 실기기 매칭(DGT). 방송행은 DEVICE_NM 이 NULL 이라 매칭되지 않는다.
left join dev d_real
       on d_real.DEVICE_TYPE = p.DEVICE_NM
-- 방송행 전용 `(해당없음)` 라우팅(DEC-10)
left join dev d_na
       on d_na.DEVICE_TYPE = '(해당없음)'
      and p.AD_SOURCE_TYPE in ('VIDEO','REBROADCAST')
-- [2026-08-06 O45] 마케팅캠페인 이름매칭. `MKTG_CAMPAIGN_NAME` 은 차원에서 유일하므로 fan-out 0.
left join {{ ref('DIM_MARKETING_CAMPAIGN') }} mk
       on mk.MKTG_CAMPAIGN_NAME = p.CAMPAIGN_NM
-- [2026-10-14 O225] UTM 보조 경로 — utm_pick 은 AD_PERF_DK 당 1행(qualify) ⇒ fan-out 0.
left join utm_pick up
       on up.AD_PERF_DK = p.AD_PERF_DK
--  [2026-10-15 O232-B] UTM 경로 캠페인의 대표 카테고리 — SK = PK ⇒ fan-out 0.
left join {{ ref('DIM_MARKETING_CAMPAIGN') }} up_mk
       on up_mk.MKTG_CAMPAIGN_SK = up.MKTG_CAMPAIGN_SK
--  [2026-10-15 O232] 소재 매핑 — PK(AD_SOURCE_TYPE, CREATIVE_NM) 유일 ⇒ fan-out 0 · 마케팅캠페인명은 DIM 에서 유일(실측 53/53).
left join {{ source('silver_external', 'AD_CREATIVE_CAMPAIGN_MAP') }} cm
       on cm.AD_SOURCE_TYPE = p.AD_SOURCE_TYPE
      and cm.CREATIVE_NM = p.CREATIVE_NM
left join {{ ref('DIM_MARKETING_CAMPAIGN') }} cm_mk
       on cm.MAP_LEVEL = 'MKTG'
       and cm_mk.MKTG_CAMPAIGN_NAME = cm.MKTG_CAMPAIGN_NAME
--  [2026-10-16 O238] 영상 코드형 상위캠페인 — video_code_mk 는 코드당 1행(HAVING = 1) ⇒ fan-out 0.
--   [2026-10-23 O260] 원천 13번 개명 `UPPER_CMPGN_NM` → `UPPER_CMPGN_CD`(값 = 종전과 같은 코드 · 조인식 불변).
left join video_code_mk vc
       on p.AD_SOURCE_TYPE = 'VIDEO'
      and vc.UPPER_CODE = UPPER(TRIM(v.UPPER_CMPGN_CD))
--  [2026-10-18 O245 · O238 W6] 재방송(특집·재송출) 상위캠페인코드 — 원천 입고 확인(재측정: 방송 165/237 · 재송출 1,722/1,953 채움 ·
--   CRM 상위캠페인코드 일치 100%). 영상과 같은 규칙 = 마케팅캠페인이 정확히 1개인 코드만(video_code_mk 재사용 · 1:N 78행은 미매핑 유지).
--   실측 효과 = 재방송 2,190행 중 1,809행 · 광고비 12,211,671,575원 연결. 「캠페인코드」 열(마케팅캠페인명 기대)은 CRM 일치 0 ⇒ 쓰지 않는다.
left join {{ ref('AGENCY_AD_ROW_REBRDC') }} rb on rb.AD_PERF_DK = p.AD_PERF_DK
left join video_code_mk rc
       on p.AD_SOURCE_TYPE = 'REBROADCAST'
      and rc.UPPER_CODE = UPPER(TRIM(rb.UPPER_CMPGN_CD::VARCHAR))
--  [2026-10-25 O262] 영상 이름형 상위캠페인 — video_name_mk 는 이름당 1행(HAVING = 1) ⇒ fan-out 0.
left join video_name_mk vn
       on p.AD_SOURCE_TYPE = 'VIDEO'
      and vn.MKTG_NAME = p.UPPER_CAMPAIGN_NM
