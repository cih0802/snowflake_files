-- DIM_CAMPAIGN: 캠페인 차원 (CRM_CAMPAIGN 기반, 분류 4축 라벨)
-- Co-authored with CoCo
-- ⚠️ ORG_SK(주관조직 O10 미확정)=0 센티넬.
-- [2026-07-16 BRONZE 재입고 반영] 캠페인 분류가 원천에서 채워짐 → 3건 교정 + 2컬럼 신설:
--   1) CAMPAIGN_TYPE : CAST(CMPGN_CTGR_CD AS VARCHAR)(숫자코드 "17") → CMPGN_CTGR_NM(라벨) 로 교체.
--   2) BIZ_CASE_TYPE : CMPGN_TYPE1_BSN(국내/통합/해외) → CMPGN_TYPE2_NM(굿즈/기타/사례/사업) 로 **의미혼입 교정**.
--      종전 모델은 유형1을 사업/사례 자리에 넣었다(O16 과 동일한 위치매핑 오류). 전건 NULL 이라 무증상이었을 뿐이다.
--   3) DOMESTIC_OVERSEAS : CAST(NULL AS VARCHAR)(파생규칙 대기) → CMPGN_TYPE1_NM 으로 해소.
--   4) INFLOW_PATH(신설) : MM293 개발인입경로 라벨. ⚠️ 종전 여기 적혀 있던 *현업 "주요캠페인" 분류축*
--      표기는 2026-08-05 O37 에서 **거짓으로 판정·회수**했다(아래 O37 절 참조).
--   5) MARKETING_CAMPAIGN(신설) : MK_CMPGN_NM (Q16 해소).
-- ⚠️ 라벨 NULL 은 코드사전 미등재(고아)를 뜻한다 — 결측이 아니다.
-- [2026-08-05 O37] PARENT_CAMPAIGN_NAME 신설 + 거짓 주석 회수 2건.
--   1) PARENT_CAMPAIGN(=UPPER_CMPGN_CD)은 라벨이 아니라 **자기참조 코드**(값 도메인=CAMPAIGN_BK)다.
--      현업이 말하는 "주요캠페인"을 코드로만 보고 있었다 → 자기조인으로 라벨 신설(O25/G3 동일 패턴).
--      CRM_CAMPAIGN 은 CMPGN_CD 유일이므로 이 자기조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
--   2) 🔴 종전 주석 4)의 *INFLOW_PATH = 현업 "주요캠페인" 분류축* 은 **거짓이므로 회수**한다.
--      실제값이 디지털·방송·영상광고·지역개발·마케팅콜개발·대면모금·직원개발 = **모집 채널** 축이다.
--      "주요캠페인(캠페인카테고리)"에 해당하는 축은 CAMPAIGN_TYPE(MM294)이다(실측 확인).
-- 🔴🔴 [2026-08-25 O101 시정 · P85] `PARENT_CAMPAIGN_NAME`·`PROMO_METHOD_NAME` 이중 계산 해소.
--   `DEC-43`(O100)이 같은 두 라벨을 SILVER `CRM_CAMPAIGN` 에 신설했는데 이 모델은 자체 CTE
--   (`parent` 자기조인 · `code_promo` CM008)로 **같은 사실을 독립 재계산**하고 있었다
--   ⇒ 「같은 사실을 두 곳에 두면 반드시 어긋난다」(`P85` · 이 프로젝트가 반복 강조하는 원칙).
--   🟢 시정 시점 실측 = 두 경로 불일치 **0/36,163**(채움 34,704 동일) ⇒ **값 변화 없이** 계산 지점만
--   SILVER 로 단일화한다. 🔴 지금 일치한다는 것은 안전의 근거가 아니다 — 한쪽 조인 규칙이
--   바뀌는 순간 조용히 갈라지고, 그때는 어느 쪽이 맞는지 아무도 모른다.


with c as (
    select * from GN_DW.SILVER.CRM_CAMPAIGN
)

select
    ABS(HASH(COALESCE(CAST(c.CMPGN_CD AS VARCHAR), '∅')))                 as CAMPAIGN_SK,
    c.CMPGN_CD                                    as CAMPAIGN_BK,
    c.BRND_NM                                     as BRAND,
    c.UPPER_CMPGN_CD                              as PARENT_CAMPAIGN,      -- 🔴 코드(라벨 아님)
    c.CMPGN_NM                                    as CAMPAIGN_NAME,
    c.PR_MTH_CD                                   as PROMO_METHOD,
    c.CMPGN_CTGR_NM                               as CAMPAIGN_TYPE,        -- MM294 카테고리 라벨 = 현업 "주요캠페인"
    c.CMPGN_TYPE1_NM                              as DOMESTIC_OVERSEAS,    -- MM295 국내/통합/해외
    c.CMPGN_TYPE2_NM                              as BIZ_CASE_TYPE,        -- MM296 굿즈/기타/사례/사업
    c.MBER_INFLOW_PATH_NM                         as INFLOW_PATH,          -- MM293 개발인입경로(=모집 채널)
    c.MK_CMPGN_NM                                 as MARKETING_CAMPAIGN,   -- Q16 마케팅캠페인
    TRY_TO_DATE(c.CMPGN_STRT_DE, 'YYYYMMDD')      as CAMPAIGN_OPEN_DATE,
    0                                             as ORG_SK,               -- ⚠️ 센티넬(O10 주관조직 미확정)
    -- [O101 · P85] 상위캠페인·홍보방법 라벨 = SILVER `CRM_CAMPAIGN` 승계(자체 재계산 제거).
    --   상위가 없거나 원천 코드가 없으면 NULL 이며 '(미매핑)'으로 창작하지 않는다(P21).
    c.PARENT_CAMPAIGN_NAME                        as PARENT_CAMPAIGN_NAME,
    c.PROMO_METHOD_NAME                           as PROMO_METHOD_NAME,
    -- [2026-08-06 O45] 🔴 마케팅캠페인 **conformed FK**(물리 위치 = 맨 끝, ALTER ADD COLUMN 규약).
    --   `MARKETING_CAMPAIGN` 은 라벨이라 광고 팩트가 참조할 수 없었다 → 광고↔CRM 결합 불가(O44).
    --   실측: 브리지 조인 `MK_CMPGN_CD = MKTG_CMPGN_NM::varchar` **33,915/33,915 = 100% 해소** ·
    --   개발실적 커버리지 **2,278,685/2,291,878 = 99.42%**.
    COALESCE(mk.MKTG_CAMPAIGN_SK, 0)              as MKTG_CAMPAIGN_SK,
    -- [2026-08-25 안내2] 세부캠페인 후원구분·법인구분(현업 요건 — Gold 까지 적재). SILVER CRM_CAMPAIGN 라벨 그대로 승계.
    c.SPNSR_DIV_CD                                 as SPNSR_DIV_CD,   -- CM035 1=정기후원·2=일시후원
    c.SPNSR_DIV_NM                                 as SPNSR_DIV_NM,
    c.CPR_DIV_CD                                   as CPR_DIV_CD,     -- CM019 A=통합·I=사단·S=사복
    c.CPR_DIV_NM                                   as CPR_DIV_NM,
    -- [2026-08-25 안내1 후속] 회원 개발이력 비정규화 요건의 잔여 2컬럼(공통브랜드·UTM) — SILVER CRM_CAMPAIGN 라벨 그대로 승계.
    c.CMMN_BRND                                    as CMMN_BRND,      -- MM297 공통브랜드 코드
    c.CMMN_BRND_NM                                 as CMMN_BRND_NM,
    c.MKTG_UTM                                     as MKTG_UTM,       -- TM_CM_MKTNG_UTM.MK_UTM 코드
    c.MKTG_UTM_NM                                  as MKTG_UTM_NM,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'd38ba6a1-836d-4cd8-ac8f-ef838313ba18'                    AS DW_BATCH_ID
from c
-- [O101 · P85] `parent`·`code_promo` 조인 제거 — 두 라벨을 SILVER 에서 승계하므로 불필요하다.
--   부수 효과 = `CRM_CAMPAIGN` 재스캔 1회 + `CRM_CODE` 스캔 1회 감소.
-- [2026-08-06 O45] MKTG_CAMPAIGN_BK 는 차원에서 유일하다 fan-out 0.
left join GN_DW.GOLD.DIM_MARKETING_CAMPAIGN mk
       on mk.MKTG_CAMPAIGN_BK = TO_VARCHAR(c.MKTG_CMPGN_NM)

union all
-- unknown 멤버(SK=0): 팩트 CAMPAIGN_SK=0(미매핑) 조인 유실 방지
select 0, '(미매핑)', NULL, NULL, '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL, 0,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'd38ba6a1-836d-4cd8-ac8f-ef838313ba18'                    AS DW_BATCH_ID