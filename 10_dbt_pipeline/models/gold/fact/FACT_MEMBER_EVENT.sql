-- FACT_MEMBER_EVENT: 회원 사건 팩트 스캐폴드 (개발 ∪ 후원중단, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 행당 카운트 1 부여(회원 dedup·차원 SK 해소는 입고 후). SPONSORSHIP/ORG/REASON_SK=0 센티넬.
-- [2026-07-30] CAMPAIGN_SK = 개발측 배선 완료(B3 부분해소) / 중단측 0 센티넬 유지(D1 미확정).
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.
--
-- ============================================================================
-- [2026-08-03 O24] 개발구분 도메인 부분적재 해소 + DEV_CNT 정본 교정
-- ----------------------------------------------------------------------------
-- 결함: 종전 dev 브랜치는 원천의 `DVLP_DIV_CD`(정본 MM015 = 1신규·2증액·3감액·4재후원·5후원중단)를
--   무시하고 전건 EVENT_TYPE='DEV' · DEV_CNT=1 로 하드코딩했다. 결과 2건:
--   ① 상태축 소실 — 현업이 보는 6상태 중 증액·감액이 GOLD 에서 사라진 것으로 보였다(항의 트리거).
--      실제로는 미적재가 아니라 **의미혼입**(O16 계열): 행은 있으나 라벨이 뭉개졌다.
--   ② DEV_CNT 56.86% 과대계상 — 감액(292,285)·후원중단(1,010,680)이 "개발실적"으로 계상됐다.
--      두 코드의 SPNSR_AMT 합계는 각각 -124.4억·-215.2억(음수)인 이탈성 사건이다.
--      정본 공#121 "개발구분 = 신규, 증액, 재후원" → 개발 = 코드 1·2·4 = 2,291,878건.
--      독립 확증: FACT_TARGET_DEV.DEV_TYPE 실측값이 '1'·'2'·'4' 3종뿐이다(감액·중단 없음).
--
-- 조치: BRONZE 코드체계를 그대로 노출한다(현업이 아직 BRONZE 를 보고 있어 신개념 도입 금지).
--   · `DVLP_DIV_CD` — 원천 컬럼명·raw 코드(1~5) 무변환. 중단 원천 행은 NULL(원천에 컬럼 부재)
--   · `DVLP_DIV_NM` — MM015 라벨. 컬럼명은 정본 컬럼정의서 504행의 현업 용어쌍을 그대로 사용
--   · `SPNSR_AMT`   — 원금액 보존(설계 §1 "`(건)`=SUM(금액)/10000 다수 → 원금액 보존").
--                     정본 공#38 감액(건)·#151 증액(건)이 금액÷10,000 이라 행수로 세면 정의 파괴(CONF-2)
--   · `DEV_CNT`/`DEV_MEMBERS` — 코드 1·2·4 한정으로 교정
--
-- 미채택(사유 명시):
--   · `EVENT_TYPE` 도메인 확장 — 기존 'DEV'/'STOP' 전제 소비처(FMM 롤업·WIDE·SV)를 깨므로 보존.
--     상태축은 위 신설 2컬럼이 담당한다. EVENT_TYPE 은 "원천 계통"(개발원천/중단원천) 축으로 재정의.
--   · `DEV_TYPE`(#121) 컬럼 신설 — `DVLP_DIV_CD` 와 축이 중복. FTD/FMM conform 은 코드값으로 성립.
--   · `TM_MM_FDRM_MBER_IRSD`(증감) 편입 — 정본 `테이블정의 20260629.csv:36` 이 `RDCAMT_YN` 을
--     "안 바뀌는 경우도 있음"으로 명시 불신. 실측 확증: 명백 오분류 752키 + 증액·감액 동시존재로
--     판정불가 50,295키(16.5%). 또 IRSD 키의 99.62%가 이미 DVLP_AMT 코드 2·3에 존재하는 부분집합.
--
-- 🔴 잔여 미결(현업 확인 대기 · 이슈 O24): 후원중단이 두 원천에 중복 존재한다.
--   코드5 키 924,044 중 923,931(99.99%)이 중단원천에 **동일 회원·동일 일자**로 있다.
--   → 코드5 행은 DEV_CNT=0·STOP_CNT=0 으로 두어 measure 중복계상은 없으나,
--     `DVLP_DIV_NM='후원중단'` 을 행수로 세면 STOP 과 이중계상된다. 합산 금지.
-- ============================================================================
{{ config(
    tags=['gold_pending']
) }}

-- [2026-07-30 B3 개발측 해소] 유효 캠페인키 집합. 고아 CMPGN_CD(실측 18행)를 SK=0(unknown 멤버 R5)로
-- 흡수해 FK 고아를 만들지 않는다. CRM_CAMPAIGN 은 CMPGN_CD 유일(실측 36,143행=36,143 distinct·중복 0)
-- 이므로 이 조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
with campaign_valid as (
    select CMPGN_CD from {{ ref('CRM_CAMPAIGN') }}
),

dev as (
    select
        COALESCE({{ date_sk("TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD')") }}, 0)  as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
        MBER_NO                                             as MEMBER_DK,
        'DEV'                                               as EVENT_TYPE,
        -- B3 해소(개발측 한정): CRM_MEMBER_DEV.CMPGN_CD 채움률 100%(3,594,843/3,594,843)·
        -- DIM_CAMPAIGN 매칭 99.9995%. 산식은 DIM_CAMPAIGN.CAMPAIGN_SK 와 동일(gold_sk(['CMPGN_CD'])).
        -- ⚠️ 중단측은 원천에 캠페인 컬럼 부재 → D1(귀속방식) 확정까지 0 센티넬 유지.
        case when c.CMPGN_CD is not null
             then {{ gold_sk(['d.CMPGN_CD']) }}
             else 0
        end                                                 as CAMPAIGN_SK,
        0 as SPONSORSHIP_SK, 0 as ORG_SK, 0 as REASON_SK,
        -- O24: BRONZE 원천 코드·라벨 무변환 노출
        d.DVLP_DIV_CD                                       as DVLP_DIV_CD,
        d.DVLP_DIV_NM                                       as DVLP_DIV_NM,
        d.SPNSR_AMT                                         as SPNSR_AMT,
        -- O24: 정본 공#121 개발구분 = 신규(1)·증액(2)·재후원(4). 감액(3)·후원중단(5) 제외.
        case when d.DVLP_DIV_CD in ('1','2','4') then 1 else 0 end as DEV_CNT,
        case when d.DVLP_DIV_CD in ('1','2','4') then 1 else 0 end as DEV_MEMBERS,
        0 as STOP_CNT, 0 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD')                  as JOIN_DATE,
        CAST(NULL AS DATE)                                  as STOP_DATE,
        CAST(NULL AS VARCHAR)                               as STOP_REASON,
        CAST(NULL AS VARCHAR)                               as STOP_CHANNEL,
        -- O25: 개발 사건에는 중단사유·중단경로 개념이 부재 → NULL (0/'' 로 채우지 않는다, P21)
        CAST(NULL AS VARCHAR)                               as STOP_REASON_NM,
        CAST(NULL AS VARCHAR)                               as STOP_CHANNEL_NM,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG
    from {{ ref('CRM_MEMBER_DEV') }} d
    left join campaign_valid c on d.CMPGN_CD = c.CMPGN_CD
),

stop as (
    select
        COALESCE({{ date_sk("TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD')") }}, 0) as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
        MBER_NO                                             as MEMBER_DK,
        'STOP'                                              as EVENT_TYPE,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK, 0 as ORG_SK,
        -- [2026-08-03 O25] REASON_SK 배선. 종전 전건 0(하드코딩) → DIM_REASON 실조인.
        --   DIM_REASON.REASON_SK = gold_sk(['CD_ID','DTL_CD_ID']) 이므로 (코드그룹, 코드) 복합키로 동일 산식을 재현한다.
        --   코드그룹은 MM005(중단사유) 고정 — FMM 처럼 SETLE_CD 자릿수 분기가 필요한 구조가 아니다.
        --   ⚠️ 사유 NULL 은 0(Unknown 멤버)으로 라우팅 — 해시하면 '∅' 로 고아 FK 가 된다.
        --   실측 근거(2026-08-03): STOP 1,038,262행 · DSCNTC_RSN_CD distinct 20 · MM005 사전 적중 20/20 · 사전부재 0.
        case when NULLIF(TRIM(DSCNTC_RSN_CD),'') is not null
             then {{ gold_sk(["'MM005'", "NULLIF(TRIM(DSCNTC_RSN_CD),'')"]) }}
             else 0
        end                                                 as REASON_SK,
        -- O24: 중단 원천(TM_MM_FDRM_MBER_SPNSR_DSCNTC)에는 개발구분·금액 컬럼이 구조적으로 부재 → NULL.
        --   ⚠️ 0 이 아니라 NULL 이다. 0 으로 채우면 "금액 0원 중단"으로 오독되고, P21(모집단 검증)이
        --      경고한 "개념 부재를 결측으로 오판" 유형을 되풀이한다.
        CAST(NULL AS VARCHAR)                               as DVLP_DIV_CD,
        CAST(NULL AS VARCHAR)                               as DVLP_DIV_NM,
        CAST(NULL AS NUMBER(18,0))                          as SPNSR_AMT,
        0 as DEV_CNT, 0 as DEV_MEMBERS,
        1 as STOP_CNT, 1 as STOP_MEMBERS, 0 as UNPAID_STOP_CNT, 0 as UNPAID_STOP_MEMBERS,
        CAST(NULL AS DATE)                                  as JOIN_DATE,
        TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD')             as STOP_DATE,
        DSCNTC_RSN_CD                                       as STOP_REASON,
        DSCNTC_PATH                                         as STOP_CHANNEL,
        -- O25: SILVER 가 이미 보유한 라벨을 전파. 계보 계약(04_컬럼계보매핑 §4)이 STOP_REASON 을
        --   "사유코드→라벨"로 명시했는데 실적재가 raw 코드여서 현업이 숫자만 보던 상태를 해소한다.
        DSCNTC_RSN_NM                                       as STOP_REASON_NM,
        DSCNTC_PATH_NM                                      as STOP_CHANNEL_NM,
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG
    from {{ ref('CRM_MEMBER_DISCONTINUE') }}
),

unioned as (
    select * from dev
    union all
    select * from stop
)

select
    DATE_SK, MEMBER_DK, EVENT_TYPE, CAMPAIGN_SK, SPONSORSHIP_SK, ORG_SK, REASON_SK,
    DVLP_DIV_CD, DVLP_DIV_NM, SPNSR_AMT,
    DEV_CNT, DEV_MEMBERS, STOP_CNT, STOP_MEMBERS, UNPAID_STOP_CNT, UNPAID_STOP_MEMBERS,
    JOIN_DATE, STOP_DATE, STOP_REASON, STOP_CHANNEL, STOP_REASON_NM, STOP_CHANNEL_NM, NEW_EXISTING_FLAG,
    {{ gold_meta('CRM') }}
from unioned
