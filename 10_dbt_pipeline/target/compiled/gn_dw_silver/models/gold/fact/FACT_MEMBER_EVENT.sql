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
--
-- ============================================================================
-- [2026-08-04 O35] 사건시점 연령대·지역 전파 (`_AT_EVENT` 4컬럼)
-- ----------------------------------------------------------------------------
-- 문제: "왜 10대 미만이 이렇게 많나?" 의 답(= 편지쓰기대회 계열 아동 모집 캠페인)을 Agent 가
--   스스로 계산해 보일 수 없었다. 연령대는 `SV_MEMBER_MONTHLY`(FMM × DIM_MEMBER_CURRENT)에,
--   캠페인은 `SV_MEMBER_EVENT`(FME)에 갈라져 있고 `SEMANTIC_VIEW()` 는 단일 뷰 대상이라
--   Agent 가 SV 끼리 행 단위 조인을 못 한다. FMM 의 CAMPAIGN_SK 는 센티넬 단일값이라 조인해도 무의미.
--
-- 채택안 = **사건시점 속성 전파**(대안 B multi-fact SV · C Agent 조인은 기각, 근거 = 이슈원장 O35):
--   · 속성이 **측정된 grain 에 놓인다** — 개발약정 이벤트에서 관측된 값이므로 사건 팩트의 속성이 맞다
--     (Kimball 트랜잭션 시점 속성). `DIM_MEMBER_CURRENT` 경유 스냅샷의 시점 왜곡이 원천 소멸한다(P60).
--   · 같은 SV 안에서 **연령대 × 캠페인 교차**가 성립한다.
--
-- 원천 실측(2026-08-04 BRONZE·SILVER 직접 스캔):
--   · `TM_MM_FDRM_MBER_DVLP_AMT.AGE` 채움 100% · distinct 12 = CM014 12/12 일치
--   · `.AREA_CD` = CM018 코드 + 라벨 없는 센티넬 `'0'` + 소수 NULL
--   · SILVER `CRM_MEMBER_DEV` 는 BRONZE 를 1:1 승계하며 `AREA_NM`(CM018 라벨)까지 이미 보유
--     → 지역 라벨은 추가 조인 불요, 연령대 라벨만 `CRM_CODE` CM014 조인
--   · 🔴 **스냅샷으로는 재현 불가**: 복수 개발사건 회원 중 AGE 가 변하는 회원·AREA_CD 가 변하는 회원이
--     실재한다(둘 다 측정 확인) → 사건행별 값과 최근 약정 스냅샷은 실제로 다르다
--   · 중단원천(`TM_MM_FDRM_MBER_SPNSR_DSCNTC`)은 컬럼 자체가 부재(전 9컬럼 확인) → NULL.
--     0 으로 채우지 않는다(P21 — 개념 부재를 결측/0 으로 오판 금지, DVLP_DIV_CD 와 동일 처리)
--
-- 🔴 `DIM_MEMBER` 의 `AGE`/`AREA_CD` 축(SV 차원명 `_AT_PLEDGE`)은 **제거하지 않는다**.
--    성격이 다르다(월 팩트 × 현재행 스냅샷 vs 사건 팩트 × 사건시점) → 이름으로 구분해 공존시킨다.
-- ============================================================================
--
-- ============================================================================
-- [2026-08-05 O37] 사건시점 성별 전파 + 캠페인 귀속 중단건
-- ----------------------------------------------------------------------------
-- 트리거: Agent 가 *"캠페인 축은 개발 사건에만 배선돼 있고 중단 사건에는 캠페인 정보가
--   원천에 없다 — 따라서 캠페인별 중단률은 구조적으로 산출 불가"* 라고 답했다.
--
-- 🔴 그 판정은 **틀렸다**. BRONZE 재스캔 결과:
--   · 중단원천 `TM_MM_FDRM_MBER_SPNSR_DSCNTC` 에는 확실히 캠페인 컬럼이 없다(전 9컬럼 확인).
--   · 그러나 개발원천 `TM_MM_FDRM_MBER_DVLP_AMT` 의 `DVLP_DIV_CD='5'`(MM015 후원중단) 행이
--     `CMPGN_CD` 를 **전건 보유**하며, 이 팩트에 이미 `CAMPAIGN_SK` 로 배선까지 끝나 있었다.
--     즉 축은 물리적으로 존재했고 **측정값(measure)만 없었다**.
--   · Agent 가 그렇게 답한 직접 원인은 SV COMMENT 의 *"캠페인별 중단건은 답이 나오지 않는다"* 다
--     → P61 재발(축이 활성인데 부정형 서술이 회수되지 않았다).
--
-- 조치: `CAMPAIGN_STOP_CNT` 신설 — 코드5 행에만 1. 이 행은 캠페인·연령대·지역·성별을 전부
--   보유하므로 **캠페인별 중단 사건 분해와 이탈자 특성 분석**이 이 팩트 안에서 성립한다.
--
-- 🔴 그러나 이 measure 로 「중단률」을 만들면 안 된다(설계 함정 2건):
--   ① 코드5 의 캠페인은 **중단 시점** 캠페인이다. 신규 건수로 나누면 분자·분모 모집단이
--      달라 비율이 100% 를 넘는다(기존회원 대상 캠페인에서 실증). 비율이 아니다.
--   ② 누적 이탈률은 **관측 기간**에 지배된다 — 획득이 이를수록 이탈률이 높은 단조 관계가
--      실측됐다. 캠페인은 실행 연도가 다르므로 누적률로 비교하면 오래된 캠페인이 자동으로
--      「중단률 높음」이 된다(P60 유형: 값은 정상인데 답이 틀린다).
--   → 캠페인별 중단률의 정본은 `FACT_MEMBER_COHORT` 의 **12개월 고정 이탈률**이다.
--
-- 🔴 `STOP_CNT` 와 `CAMPAIGN_STOP_CNT` 는 **합산 금지** — 같은 중단 사건이 두 원천에 있다(O24).
--
-- 성별: `_AT_EVENT` 계열 확장. 원천이 사건행별 성별을 보유하는데 전파되지 않아 성별은
--   `DIM_MEMBER_CURRENT` 현재 스냅샷만 쓸 수 있었다(P60 계열 잠복). 코드체계가 서로 다르다 —
--   개발원천은 CM013(국내/외국인 구분 포함), 회원 마스터 라벨은 CM017 계열이다. 합산 금지.
-- ============================================================================
--
-- ============================================================================
-- [2026-08-05 O38 / O10 해소] ORG_SK 배선 — 부서별 실적이 산출 불가였다
-- ----------------------------------------------------------------------------
-- 결함: `ORG_SK` 가 **전건 센티넬 0**(4,633,105/4,633,105 실측)이었다. 컬럼·FK·DIM_ORG 는
--   모두 존재하는데 값만 없는 P15 유형("설계 완료 ≠ 값 존재")이다.
--   `FACT_MEMBER_MONTHLY` 에는 `ORG_SK` 컬럼 자체가 없으므로 **GOLD 전체에 부서별 회원실적 축이
--   없었다** — measure(DEV_CNT·STOP_CNT)만 보면 "있다"로 오판하기 쉬운 형태다.
--
-- 소비측 요건: 마케팅 장표 「개발현황(목표,실적)」의 **첫 축이 부서명**이고
--   `20_현업확인_요청.md` 가 기획실 요건을 *"부서별 × 일자별 개발 건"* 으로 기재하고 있다.
--   즉 이 미배선 하나가 목표 대비 실적 장표 전체를 막고 있었다.
--
-- 채택 = **실적부서(`ACMSLT_DEPT_CD`)**. 근거 = O10/Q7 기확정(문서30 §4) — 재론 불요.
--   실측(2026-08-05, SILVER `CRM_MEMBER_DEV` 3,594,843행):
--     · `ACMSLT_DEPT_CD` 채움 3,594,835 · distinct 349 · DIM_ORG 매칭 **3,594,835(99.9998%)**
--     · 미매칭은 **8행**뿐 → 0(Unknown 멤버) 라우팅
--     · `ACT_DEPT_CD`(활동부서)도 366종 실재하나 O10 이 기본을 실적부서로 확정했으므로 쓰지 않는다
--   목표 팩트와의 conform 확인: `FACT_TARGET_DEV` 목표 조직 **234종 ⊆ 실적 349종**,
--     목표에만 있는 조직 **0** → 달성율 계산에서 분모 누락이 생기지 않는다.
--
-- 산식은 `FACT_TARGET_DEV` 와 동일하게 `DIM_ORG.ORG_DK = ABS(HASH(DEPT_ID))` 조인으로 맞춘다
--   (양 팩트가 같은 경로로 SK 를 얻어야 목표↔실적 조인이 성립한다).
--   ⚠️ `gold_sk(['ACMSLT_DEPT_CD'])` 로 직접 해시하면 안 된다 — `gold_sk` 는 `COALESCE+CAST` 를
--      감싸므로 `ORG_DK`(순수 `ABS(HASH())`)와 값이 다르고, 미매칭 부서가 고아 FK 로 새어나간다.
--   DIM_ORG 는 `ORG_DK` 유일(1,315/1,315 실측)이라 이 조인은 **fan-out 0** 이다.
--
-- 🔴 중단(STOP) 브랜치는 0 센티넬을 유지한다 — 축이 없어서가 아니라 **역할이 다르기 때문**이다.
--   중단원천 `CRM_MEMBER_DISCONTINUE` 는 `REGIST_DEPT_CD`(**등록부서**)를 보유한다
--   (채움 925,948/1,038,262 = 89.2% · distinct 54 · DIM_ORG 매칭 100%).
--   그러나 개발측은 **실적부서**(349종)이고 중단측은 **등록부서**(54종)로 카디널리티가 6배 다르다.
--   한 컬럼에 섞으면 O24(개발구분 뭉갬)·O28(한 컬럼 두 코드체계)와 **동일한 의미혼입**이 되고,
--   "부서별 중단건"이 조용히 틀린 집계를 낸다. → 등록부서 축의 배속은 별도 결정 사안으로 남긴다
--   (이슈 O38-B). 추론으로 채우지 않는다(P21).
-- ============================================================================
--
-- ============================================================================
-- [2026-08-25 설계부채 해소] 회원 개발이력 비정규화 9속성 — FME 자체 컬럼으로 직배선
-- ----------------------------------------------------------------------------
-- 배경: SILVER `CRM_MEMBER_DEV` 는 이미 이 9속성(코드+라벨 18컬럼)을 SILVER 빌드
--   시점(BRONZE `TM_CM_CMPGN_MNG` 값)으로 **동결**해 보유한다(현업 요청 — 캠페인
--   마스터가 나중에 정정돼도 과거 개발이력 사건은 재계산되지 않아야 함).
--   그런데 종전 SV(`SV_MEMBER_EVENT`)는 이 값을 `FME.CAMPAIGN_SK` → `DIM_CAMPAIGN`
--   **실시간 조인**으로 가져왔다 — SILVER 가 동결한 값이 GOLD/SV 에서 캠페인 마스터가
--   바뀌면 과거 사건 행도 조용히 따라 바뀌는 정합성 결함이 있었다.
--
-- 조치: 개발(DEV) 브랜치에 `CRM_MEMBER_DEV` 자신의 9속성을 그대로 실어 나른다(사건
--   grain 이므로 fan-out 없음). 중단(STOP) 브랜치는 원천에 이 속성이 없어 NULL(P21).
-- ============================================================================


-- [2026-08-05 O38] 실적부서 → ORG_SK. DIM_ORG.ORG_DK 유일이라 fan-out 0(행수 불변 검증 대상).
--   `FACT_TARGET_DEV` 와 동일 경로로 SK 를 얻어 목표↔실적 월×조직 conform 을 성립시킨다.
with org_lookup as (
    select ORG_DK, ORG_SK from GN_DW.GOLD.DIM_ORG
),
-- [2026-07-30 B3 개발측 해소] 유효 캠페인키 집합. 고아 CMPGN_CD(실측 18행)를 SK=0(unknown 멤버 R5)로
-- 흡수해 FK 고아를 만들지 않는다. CRM_CAMPAIGN 은 CMPGN_CD 유일(실측 36,143행=36,143 distinct·중복 0)
-- 이 므로 이 조인은 fan-out 을 만들지 않는다(행수 불변 검증 대상).
campaign_valid as (
    select CMPGN_CD from GN_DW.SILVER.CRM_CAMPAIGN
),

-- [2026-08-04 O35] 연령대 라벨 = CM014. 하드코딩 CASE 금지(P31 — 사전과 조용히 갈라진다).
--   `DTL_CD_ID` 유일이라 fan-out 없음. USE_YN 무필터(폐지코드가 실적재에 남아 필터 시 라벨 소실).
code_ageband as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM014'
),

-- [2026-08-05 O37] 성별 라벨 = CM013. 하드코딩 CASE 금지(P31). `DTL_CD_ID` 유일이라 fan-out 없음.
--   USE_YN 무필터(동일 사유). ⚠️ 원천에 사전 미등재 센티넬 `'0'` 이 소수 있어 라벨은 NULL 이 된다 —
--   '미상'으로 창작하지 않는다(P21).
code_sex as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM013'
),

-- [2026-08-06 O45] 후원사업 차원 조회. `SPONSORSHIP_BK`(=원천 SPNSR_BSNS_ID) 는 차원에서 유일하다.
spb_lookup as (
    select SPONSORSHIP_BK, SPONSORSHIP_SK from GN_DW.GOLD.DIM_SPONSORSHIP
),

dev as (
    select
        COALESCE(CASE WHEN TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD') BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(TRY_TO_DATE(OCCRRNC_DE,'YYYYMMDD'), 'YYYYMMDD')) END, 0)  as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
        MBER_NO                                             as MEMBER_DK,
        'DEV'                                               as EVENT_TYPE,
        -- B3 해소(개발측 한정): CRM_MEMBER_DEV.CMPGN_CD 채움률 100%(3,594,843/3,594,843)·
        -- DIM_CAMPAIGN 매칭 99.9995%. 산식은 DIM_CAMPAIGN.CAMPAIGN_SK 와 동일(gold_sk(['CMPGN_CD'])).
        -- ⚠️ 중단측은 원천에 캠페인 컬럼 부재 → D1(귀속방식) 확정까지 0 센티넬 유지.
        case when c.CMPGN_CD is not null
             then ABS(HASH(COALESCE(CAST(d.CMPGN_CD AS VARCHAR), '∅')))
             else 0
        end                                                 as CAMPAIGN_SK,
        -- [2026-08-06 O45] 🔴 **후원사업 축 실배선** — 종전 `0` 하드코딩은 **배선 누락**이었다.
        --   O8(다중귀속 규칙 미확정)과 무관하다: 사건 grain 에서는 그 사건의 후원사업이 하나로
        --   확정되므로 귀속 규칙이 필요 없다. 실측(SILVER `CRM_MEMBER_DEV` 3,594,843행):
        --     · `SPNSR_BSNS_ID` 채움 **100%** · distinct 29
        --     · `DIM_SPONSORSHIP`(50종) 대조 **고아 코드 0 · 고아 행 0** → 완전 정합
        --   산식은 DIM_SPONSORSHIP.SPONSORSHIP_SK 와 동일(`gold_sk(['SPNSR_BSNS_ID'])`).
        COALESCE(sp.SPONSORSHIP_SK, 0)                       as SPONSORSHIP_SK,
        -- [2026-08-05 O38] 실적부서(ACMSLT_DEPT_CD) → ORG_SK. O10/Q7 확정축.
        --   미매칭 8행(실측)은 COALESCE 로 0(Unknown 멤버) 라우팅 — 고아 FK 를 만들지 않는다.
        COALESCE(og.ORG_SK, 0)                              as ORG_SK,
        0 as REASON_SK,
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
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG,
        -- [2026-08-04 O35] 사건시점 연령대·지역. 사건행 자신의 값이므로 as-of 계산이 불요하다.
        d.AGE                                               as AGE_AT_EVENT,
        cab.DTL_CD_NM                                       as AGE_BAND_AT_EVENT,
        d.AREA_CD                                           as AREA_CD_AT_EVENT,
        d.AREA_NM                                           as REGION_AT_EVENT,
        -- [2026-08-05 O37] 사건시점 성별 + 캠페인 귀속 중단건.
        d.SEX                                               as SEX_AT_EVENT,
        csx.DTL_CD_NM                                       as GENDER_AT_EVENT,
        -- 코드5(후원중단) 행만 1. 이 행은 CAMPAIGN_SK 를 보유하므로 캠페인별 중단 분해가 성립한다.
        -- 🔴 STOP_CNT 와 합산 금지(동일 사건 이중계상, O24) · 개발건으로 나눠 중단률로 쓰지 말 것.
        case when d.DVLP_DIV_CD = '5' then 1 else 0 end      as CAMPAIGN_STOP_CNT,
        -- [2026-08-25 설계부채 해소] 회원 개발이력 비정규화 9속성 — SILVER CRM_MEMBER_DEV
        --   자신의 동결값을 그대로 승계한다(DIM_CAMPAIGN 실시간 조인 대신). 사건 grain 이므로
        --   d 자신의 컬럼이라 fan-out 없음.
        d.MBER_INFLOW_PATH_CD                                as MBER_INFLOW_PATH_CD_AT_EVENT,
        d.MBER_INFLOW_PATH_NM                                as MBER_INFLOW_PATH_NM_AT_EVENT,
        d.CMPGN_CTGR_CD                                      as CMPGN_CTGR_CD_AT_EVENT,
        d.CMPGN_CTGR_NM                                      as CMPGN_CTGR_NM_AT_EVENT,
        d.CMPGN_TYPE1_BSN                                    as CMPGN_TYPE1_BSN_AT_EVENT,
        d.CMPGN_TYPE1_NM                                     as CMPGN_TYPE1_NM_AT_EVENT,
        d.CMPGN_TYPE2_BSN                                    as CMPGN_TYPE2_BSN_AT_EVENT,
        d.CMPGN_TYPE2_NM                                     as CMPGN_TYPE2_NM_AT_EVENT,
        d.MKTG_CMPGN_NM                                      as MKTG_CMPGN_CD_AT_EVENT,
        d.MK_CMPGN_NM                                        as MKTG_CMPGN_NM_AT_EVENT,
        d.CMMN_BRND                                          as CMMN_BRND_AT_EVENT,
        d.CMMN_BRND_NM                                       as CMMN_BRND_NM_AT_EVENT,
        d.MKTG_UTM                                           as MKTG_UTM_AT_EVENT,
        d.MKTG_UTM_NM                                        as MKTG_UTM_NM_AT_EVENT,
        d.SPNSR_DIV_CD                                       as SPNSR_DIV_CD_AT_EVENT,
        d.SPNSR_DIV_NM                                       as SPNSR_DIV_NM_AT_EVENT,
        d.CPR_DIV_CD                                         as CPR_DIV_CD_AT_EVENT,
        d.CPR_DIV_NM                                         as CPR_DIV_NM_AT_EVENT,
        -- [DEC-42] 잔여 3속성(브랜드·상위캠페인명·홍보방법) 동결 전파. d 자신의 컬럼이라 fan-out 없음.
        d.BRND_NM                                            as BRAND_AT_EVENT,
        d.PARENT_CAMPAIGN_NAME                               as PARENT_CAMPAIGN_NAME_AT_EVENT,
        d.PROMO_METHOD_NAME                                  as PROMO_METHOD_NAME_AT_EVENT
    from GN_DW.SILVER.CRM_MEMBER_DEV d
    left join campaign_valid c on d.CMPGN_CD = c.CMPGN_CD
    left join code_ageband   cab on to_varchar(d.AGE) = cab.DTL_CD_ID
    left join code_sex       csx on d.SEX = csx.DTL_CD_ID
    -- [2026-08-05 O38] ORG_DK 유일(1,315/1,315)이라 fan-out 0.
    left join org_lookup     og on og.ORG_DK = ABS(HASH(d.ACMSLT_DEPT_CD))
    -- [2026-08-06 O45] 후원사업 축. SPONSORSHIP_BK 유일(51/51)이라 fan-out 0.
    left join spb_lookup     sp on sp.SPONSORSHIP_BK = d.SPNSR_BSNS_ID
),

stop as (
    select
        COALESCE(CASE WHEN TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD') BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(TRY_TO_DATE(SPNSR_DSCNTC_DE,'YYYYMMDD'), 'YYYYMMDD')) END, 0) as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
        MBER_NO                                             as MEMBER_DK,
        'STOP'                                              as EVENT_TYPE,
        0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK,
        -- [2026-08-05 O38] 🔴 중단측 0 센티넬 유지는 **축 부재가 아니라 역할 불일치** 때문이다.
        --   이 원천은 `REGIST_DEPT_CD`(등록부서, 채움 89.2%·54종·DIM_ORG 매칭 100%)를 보유하지만
        --   개발측 축은 **실적부서**(349종)다. 한 컬럼에 섞으면 "부서별 중단건"이 조용히 틀린다
        --   (O24·O28 의미혼입 유형). 등록부서 축 배속은 별도 결정(O38-B) — 추론으로 채우지 않는다.
        0 as ORG_SK,
        -- [2026-08-03 O25] REASON_SK 배선. 종전 전건 0(하드코딩) → DIM_REASON 실조인.
        --   DIM_REASON.REASON_SK = gold_sk(['CD_ID','DTL_CD_ID']) 이므로 (코드그룹, 코드) 복합키로 동일 산식을 재현한다.
        --   코드그룹은 MM005(중단사유) 고정 — FMM 처럼 SETLE_CD 자릿수 분기가 필요한 구조가 아니다.
        --   ⚠️ 사유 NULL 은 0(Unknown 멤버)으로 라우팅 — 해시하면 '∅' 로 고아 FK 가 된다.
        --   실측 근거(2026-08-03): STOP 1,038,262행 · DSCNTC_RSN_CD distinct 20 · MM005 사전 적중 20/20 · 사전부재 0.
        case when NULLIF(TRIM(DSCNTC_RSN_CD),'') is not null
             then ABS(HASH(COALESCE(CAST('MM005' AS VARCHAR), '∅') || '‖' || COALESCE(CAST(NULLIF(TRIM(DSCNTC_RSN_CD),'') AS VARCHAR), '∅')))
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
        CAST(NULL AS VARCHAR)                               as NEW_EXISTING_FLAG,
        -- [2026-08-04 O35] 중단원천에는 연령·지역 컬럼이 **구조적으로 부재**(전 9컬럼 실측 확인) → NULL.
        --   ⚠️ 0 이나 '미상' 으로 채우지 않는다 — 개념 부재를 결측으로 오판하는 P21 유형을 되풀이한다.
        CAST(NULL AS NUMBER(2,0))                           as AGE_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as AGE_BAND_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as AREA_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as REGION_AT_EVENT,
        -- [2026-08-05 O37] 성별도 중단원천에 컬럼이 부재하여 NULL(동일 사유). 캠페인 귀속 중단건은
        --   개발원천 코드5 행이 담당하므로 이 브랜치는 0 이다 — 두 축을 합산하면 이중계상된다(O24).
        CAST(NULL AS VARCHAR)                               as SEX_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as GENDER_AT_EVENT,
        0                                                   as CAMPAIGN_STOP_CNT,
        -- [2026-08-25 설계부채 해소] 중단원천에는 개발이력 비정규화 9속성 컬럼이 구조적으로
        --   부재(TM_MM_FDRM_MBER_SPNSR_DSCNTC) → NULL(0/'' 로 채우지 않는다, P21 동일 처리).
        CAST(NULL AS NUMBER(38,0))                          as MBER_INFLOW_PATH_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as MBER_INFLOW_PATH_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMPGN_CTGR_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMPGN_CTGR_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMPGN_TYPE1_BSN_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMPGN_TYPE1_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMPGN_TYPE2_BSN_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMPGN_TYPE2_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as MKTG_CMPGN_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as MKTG_CMPGN_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as CMMN_BRND_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CMMN_BRND_NM_AT_EVENT,
        CAST(NULL AS NUMBER(38,0))                          as MKTG_UTM_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as MKTG_UTM_NM_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as SPNSR_DIV_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as SPNSR_DIV_NM_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CPR_DIV_CD_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as CPR_DIV_NM_AT_EVENT,
        -- [DEC-42] 중단원천에는 이 3속성 컬럼도 구조적으로 부재 → NULL(동일 처리).
        CAST(NULL AS VARCHAR)                               as BRAND_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as PARENT_CAMPAIGN_NAME_AT_EVENT,
        CAST(NULL AS VARCHAR)                               as PROMO_METHOD_NAME_AT_EVENT
    from GN_DW.SILVER.CRM_MEMBER_DISCONTINUE
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
    -- [2026-08-04 O35] 사건시점 축. `_AT_PLEDGE`(DIM_MEMBER 스냅샷)와 이름으로 구분해 공존한다.
    AGE_AT_EVENT, AGE_BAND_AT_EVENT, AREA_CD_AT_EVENT, REGION_AT_EVENT,
    -- [2026-08-05 O37] 사건시점 성별 + 캠페인 귀속 중단건.
    SEX_AT_EVENT, GENDER_AT_EVENT, CAMPAIGN_STOP_CNT,
    -- [2026-08-25 설계부채 해소] 회원 개발이력 비정규화 9속성(SILVER 동결값 직배선).
    MBER_INFLOW_PATH_CD_AT_EVENT, MBER_INFLOW_PATH_NM_AT_EVENT,
    CMPGN_CTGR_CD_AT_EVENT, CMPGN_CTGR_NM_AT_EVENT,
    CMPGN_TYPE1_BSN_AT_EVENT, CMPGN_TYPE1_NM_AT_EVENT,
    CMPGN_TYPE2_BSN_AT_EVENT, CMPGN_TYPE2_NM_AT_EVENT,
    MKTG_CMPGN_CD_AT_EVENT, MKTG_CMPGN_NM_AT_EVENT,
    CMMN_BRND_AT_EVENT, CMMN_BRND_NM_AT_EVENT,
    MKTG_UTM_AT_EVENT, MKTG_UTM_NM_AT_EVENT,
    SPNSR_DIV_CD_AT_EVENT, SPNSR_DIV_NM_AT_EVENT,
    CPR_DIV_CD_AT_EVENT, CPR_DIV_NM_AT_EVENT,
    -- [DEC-42] 잔여 3속성(브랜드·상위캠페인명·홍보방법) — 물리 위치 = 맨 끝(ALTER ADD COLUMN 규약).
    BRAND_AT_EVENT, PARENT_CAMPAIGN_NAME_AT_EVENT, PROMO_METHOD_NAME_AT_EVENT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '8789911f-b3b3-4ce4-9925-e0ae615a3991'                    AS DW_BATCH_ID
from unioned