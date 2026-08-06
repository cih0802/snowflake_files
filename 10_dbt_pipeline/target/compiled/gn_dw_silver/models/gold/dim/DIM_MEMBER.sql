-- DIM_MEMBER: 회원 차원 SCD2 (CRM_MEMBER 현재값 + STATUS_HIST 이력, 부분적재)
-- Co-authored with CoCo
-- 【회원번호 체계】 CRM은 정식(FDRM)·일시(ONCE)를 별도 테이블로 분리 관리:
--   FDRM → TM_MM_FDRM_MBER_INFO: 번호 0000000~9999999 (7자리, leading-zero 보존)
--   ONCE → TM_MM_ONCE_MBER_INFO: 번호 S00000000~S09999999 (S접두+8자리=9자)
--   GA4 user_id는 이 둘을 단일 필드로 통합 표현 → 'S' 접두 유무로 FDRM/ONCE 판별.
--   MEMBER_DK=VARCHAR(10) 필수·NUMBER 캐스팅 절대 금지.
--
-- ============================================================================
-- [2026-08-03 O26] 명명 규칙 전환 — 코드 컬럼 = BRONZE 원천명 / 라벨 컬럼 = 분석 용어
--   근거: 현업이 아직 BRONZE 를 직접 조회한다(O24 확립). 원천이 이미 수식어 접두 관례를 쓴다
--         (`ACT_/ACMSLT_/REGIST_DEPT_CD` · `EMAIL_/MOBLPHON_/ETC_CTTPC_STAT_CD`) → 신개념 도입 아님.
--   개명: GENDER→SEX · MEMBER_STATUS→MBER_STAT_CD · MEMBER_TYPE→MBER_DIV_CD · ENROLL_PATH→JOIN_PATH_CD
--   유지: 라벨은 분석 용어 그대로 — GENDER_NAME · MEMBER_STATUS_NAME · MEMBER_TYPE_NAME · ENROLL_PATH_NAME
--   신설: SEX_NM(CM013 원천 라벨) — 국내/외국인 축 복구
--   🔴 하드코딩 라벨 폐기: 종전 `CASE ... '여성'/'남성'/'미상'` → CRM_CODE CM017 조인으로 대체.
-- ============================================================================
-- [2026-08-03 O27 / DEC-28] 미주입 컬럼 배선 — 결정 정본 = 문서30 §18 · 진단 정본 = 문서10 §14
--   ▶ 채움 4 : REGION·AGE_BAND(+코드 AREA_CD·AGE) · LAST_STOP_DATE · FIRST_SPONSORSHIP
--   ▶ 신설 2 : PREV_MBER_STAT_CD·PREV_MEMBER_STATUS_NAME (상태전이 축)
--   ▶ DROP 3: NEW_EXISTING_FLAG · LAST_CAMPAIGN · CURRENT_SPONSORSHIP
--
--   🔷 시점귀속(as-of) 채택 — 사용자 확정 + 설계 정본 일치
--     `08_silver의존.md §5-A` 가 REGION/AGE_BAND 를 *"개발·증감 **시점 AREA_CD/AGE 스냅샷**"* 으로
--     이미 규정하고 있었다(2026-07). 즉 시점귀속은 신규 발상이 아니라 **설계 정본의 복원**이다.
--     구현 = `ASOF JOIN` — 좌측 1행당 우측 최대 1행이 **구조적으로 보장**되어 fan-out 이 원리적으로 0.
--     실측(2026-08-03): 7,925,716 → 7,925,716 불변 · REGION/AGE_BAND 적중 97.63% · LAST_STOP_DATE 19.73%
--
--   🔷 AGE 는 연속형 나이가 아니라 **CM014 12종 코드**다 (DEC-28 §18-B 로 §17-C 판정 정정)
--     1=10대 미만·2=10대·3=20대·4=30대·5=40대·6=50대·7=60대·8=70대·9=70대 이상·10=단체·11=기업·12=기타
--     3원 대조: CRM_CODE CM014 12종 × 실적재 distinct 12종(채움 100%) = **12/12 일치**
--              × 지표용어사전 *"연령대 / 문자"* 와 모순 없음
--     🟢 독립 교차검증(P21): `AGE='10'`(단체) 21,920행 **전건 `SEX='6'`(단체)** ·
--        `AGE='11'`(기업) 64,581행 **전건 `SEX='7'`(기업)** → 우연 아님, 코드 해석 확정
--     ⚠️ BRONZE `TM_MM_FDRM_MBER_DVLP_AMT.AGE` COMMENT *"연령"*(NUMBER)은 **오류**다(실제 연령대 코드).
--        `SND_MEMBER_LIST.AGE` 는 *"연령대"* 로 정확. DEC-26(코드 관련 기술 = 참고본) 사례.
--     ⚠️ 생년월일(`MBER_BIRTHDAY`) 입고는 **AGE_BAND 의 선행조건이 아니다** — 시점정확 연령(과거 버전의
--        당시 나이·LTV 연령 코호트)에만 필요하다(문서40 사유 축소).
--
--   🔷 REGION = CM018 약칭축 (정본 공#131 *"서울/인천/경기/강원"* 이 약칭 → CM011 아님)
--     3원 대조: CM018 18종 × 실적재 18종 = **18/18 일치** + sentinel `'0'` 20,624행(라벨 NULL) + NULL 6
--     ⚠️ sentinel `'0'` 은 `USE_YN` 필터가 아니라 라벨 NULL 로 관측한다(DEC-26 §16-C).
--
--   🔷 원천 = `CRM_MEMBER_DEV` **단독**. `CRM_MEMBER_AMT_CHANGE` 는 실측 후 제외했다:
--     as-of 커버리지 **증가 0** · 값 차이 **7,925,716행 중 1행** → 복잡도만 늘고 이득이 없다.
--     ⇒ 종전 주석 *"개발·증감 AREA_CD/AGE 대기"* 의 '증감' 은 회수한다(P33 ③ 거짓 경고문 회수).
--
--   🔷 ONCE(일시회원) 175,722행은 REGION/AGE_BAND/FIRST_SPONSORSHIP 이 **NULL** 이다.
--     ⚠️ `(해당없음)` 이 아니다 — 회원상태·가입경로와 성질이 다르다.
--        상태·경로는 원천에 **컬럼 자체가 없다**(개념 부재) → `(해당없음)`
--        지역·연령대는 개념은 있으나 ONCE 가 개발약정(`CRM_MEMBER_DEV`)에 **행이 없다**(원천 미보유) → NULL
--        실측: `CRM_MEMBER_DEV`·`CRM_MEMBER_AMT_CHANGE` 양쪽 모두 **FDRM 전용**(ONCE 0행)
--     FDRM 결손은 0.15%(11,749/7,749,994) = 개발약정 이전 시점의 상태버전.
--
--   🔷 DROP 3건 사유 (문서30 §18-D 판정순서 ②grain 함수종속 에서 탈락)
--     NEW_EXISTING_FLAG  — 시점귀속(#113) 개념이라 차원 grain 부적합. 정소재지 = FACT_MEMBER_MONTHLY
--     LAST_CAMPAIGN      — 다중 캠페인 19.0%·최대 690 → 대표규칙이 **O8 현업 미결**(게이트 우회 금지)·소비처 0
--     CURRENT_SPONSORSHIP— 동시 다중 후원이 **정상**(14.2%·최대 14) → 단일값 불성립(O13 계열)
-- ============================================================================
-- 🔷 D2 SCD2 활성화(2026-07-16): 전용 소스 CRM_MEMBER_STATUS_HIST(7.5M행) 입고완료 → 시점조인 재배선.
--    • 회원상태(MBER_STAT_CD)만 SCD2. 성별·가입일·구분 등 마스터 속성은 SCD1(버전 간 동일값 반복).
--      ⚠️ [O27] REGION·AGE_BAND·LAST_STOP_DATE 는 **SCD2 축**이다(버전별로 값이 다를 수 있다).
--         실측: 다버전 회원 996,492명 중 AGE 변동 57,081(5.73%)·AREA 변동 23,031(2.31%).
--    • grain=회원상태 버전. MEMBER_SK=해시(MEMBER_DK, EFFECTIVE_FROM). 동일 시점(일자) 다중변경(3,151건)은
--      최종상태(max SER_NO)로 축약 후 LEAD 로 EFFECTIVE_TO 재계산 → MEMBER_SK 유일·구간 무중첩 보장.
--    • 이력 미보유(FDRM 무이력 + ONCE 전체)는 가입일 기준 단일버전(IS_CURRENT=TRUE)로 fallback.
--    • 이력 고아 37명(STATUS_HIST엔 있으나 마스터 부재)은 inner join 으로 제외.
--    • MEMBER_DK 는 더 이상 unique 아님(버전 반복) → 다운스트림은 IS_CURRENT 필터 또는 GOLD.DIM_MEMBER_CURRENT.
-- 순서9-D: fact 패턴 채택 — incremental + append + pre-hook TRUNCATE + full_refresh:false.
--    ※ 선행: 06_DDL 의 DIM_MEMBER 구조 존재 필요. O27 신규 4컬럼은 `ALTER TABLE ADD COLUMN` 선행 필수.


with m as (
    select * from GN_DW.SILVER.CRM_MEMBER
),

-- 상태이력(FDRM 전용): 동일 시점(일자) 중복은 최종상태(max SER_NO)로 축약
-- [O27] BF_STAT_CD 동반 전파 — 축약행(최종 전이)의 '이전상태'다. 동일자 내 전이 사슬의
--       중간 단계는 축약으로 소실되므로 "그 날의 최종 전이"로 해석한다(CHN_STAT_CD 와 동일 규약).
hist_collapsed as (
    select
        MBER_NO                                       as MBER_NO,
        EFFECTIVE_FROM::DATE                          as EFF_FROM,
        CHN_STAT_CD                                   as STATUS_CD,
        BF_STAT_CD                                    as PREV_STATUS_CD
    from GN_DW.SILVER.CRM_MEMBER_STATUS_HIST
    qualify row_number() over (partition by MBER_NO, EFFECTIVE_FROM::DATE order by SER_NO desc) = 1
),

-- 축약본에서 SCD2 구간(EFFECTIVE_TO)·현재플래그 재계산
hist_scd2 as (
    select
        MBER_NO,
        STATUS_CD,
        PREV_STATUS_CD,
        EFF_FROM,
        lead(EFF_FROM) over (partition by MBER_NO order by EFF_FROM)             as EFF_TO,
        (lead(EFF_FROM) over (partition by MBER_NO order by EFF_FROM) is null)   as IS_CUR
    from hist_collapsed
),

-- (A) 이력 보유 회원(FDRM) = 상태버전별 다중행
versioned as (
    select
        ABS(HASH(COALESCE(CAST(m.MEMBER_DK AS VARCHAR), '∅') || '‖' || COALESCE(CAST(h.EFF_FROM AS VARCHAR), '∅')))  as MEMBER_SK,
        m.MEMBER_DK, m.SEX, m.SEX_NM, m.MBER_DIV_CD, m.MEMBER_TYPE, m.JOIN_DT, m.CMPGN_CD, m.JOIN_PATH_CD,
        h.STATUS_CD                                   as MBER_STAT_CD,
        h.PREV_STATUS_CD                              as PREV_MBER_STAT_CD,
        h.EFF_FROM                                    as EFFECTIVE_FROM,
        h.EFF_TO                                      as EFFECTIVE_TO,
        h.IS_CUR                                      as IS_CURRENT
    from m
    join hist_scd2 h on m.MEMBER_DK = h.MBER_NO
),

-- (B) 이력 미보유(FDRM 무이력 + ONCE 전체) = 가입일 기준 단일버전
--     [O27] 이력이 없으므로 이전상태도 없다 → PREV_MBER_STAT_CD = NULL (결측이며 개념부재 아님)
single as (
    select
        ABS(HASH(COALESCE(CAST(m.MEMBER_DK AS VARCHAR), '∅') || '‖' || COALESCE(CAST(m.JOIN_DT AS VARCHAR), '∅')))   as MEMBER_SK,
        m.MEMBER_DK, m.SEX, m.SEX_NM, m.MBER_DIV_CD, m.MEMBER_TYPE, m.JOIN_DT, m.CMPGN_CD, m.JOIN_PATH_CD,
        m.MBER_STAT_CD                                as MBER_STAT_CD,
        CAST(NULL AS VARCHAR)                          as PREV_MBER_STAT_CD,
        m.JOIN_DT::DATE                               as EFFECTIVE_FROM,
        CAST(NULL AS DATE)                            as EFFECTIVE_TO,
        TRUE                                          as IS_CURRENT
    from m
    where m.MEMBER_DK not in (select MBER_NO from hist_scd2)
),

unioned as (
    select * from versioned
    union all
    select * from single
),

-- ── [O27] 개발약정 시점 스냅샷 (설계 정본 08_silver의존 §5-A) ──────────────────
-- 일자당 1행으로 축약(최종 SER_NO) 후 as-of 조인 대상으로 쓴다.
-- ⚠️ 센티넬 발생일 제외: '19000101' 88행 · '99991231' 2행 (실측, 전체 3,594,843 중 90행 = 0.0025%)
--    전자는 모든 버전에 오매칭되고 후자는 어떤 버전에도 매칭되지 않아 둘 다 왜곡원이다.
dev_snap as (
    select
        MBER_NO                                           as MBER_NO,
        try_to_date(OCCRRNC_DE, 'YYYYMMDD')               as DEV_DT,
        AREA_CD                                           as AREA_CD,
        AGE                                                as AGE
    from GN_DW.SILVER.CRM_MEMBER_DEV
    where OCCRRNC_DE not in ('19000101', '99991231')
      and try_to_date(OCCRRNC_DE, 'YYYYMMDD') is not null
    qualify row_number() over (
        partition by MBER_NO, try_to_date(OCCRRNC_DE, 'YYYYMMDD')
        order by SER_NO desc nulls last) = 1
),

-- 버전 시점(EFFECTIVE_FROM) 이하의 최근 개발약정 1건 → 지역·연령대 시점귀속.
-- 🟢 ASOF JOIN 은 좌측 1행당 우측 최대 1행이므로 fan-out 이 구조적으로 불가능하다.
--    미매칭 좌측 행은 보존되고 우측 컬럼만 NULL 이 된다(실측 확인: 7,925,716 → 7,925,716).
member_snap as (
    select
        u.MEMBER_SK                                       as MEMBER_SK,
        d.AREA_CD                                          as AREA_CD,
        d.AGE                                              as AGE
    from unioned u
    asof join dev_snap d
        match_condition (u.EFFECTIVE_FROM >= d.DEV_DT)
        on u.MEMBER_DK = d.MBER_NO
),

-- ── [O27] 최초 후원사업 (SCD1 — "최초"는 시점 불변이라 as-of 불요) ─────────────
first_biz as (
    select
        MBER_NO                                            as MBER_NO,
        SPNSR_BSNS_ID                                      as FIRST_SPONSORSHIP
    from GN_DW.SILVER.CRM_MEMBER_DEV
    where OCCRRNC_DE not in ('19000101', '99991231')
      and SPNSR_BSNS_ID is not null
    qualify row_number() over (partition by MBER_NO order by OCCRRNC_DE asc, SER_NO asc) = 1
),

-- ── [O27] 중단일 시점귀속 — "그 버전 시점까지의 최종 중단일" ───────────────────
-- ⚠️ 단순 max() 가 아니라 as-of max 다. 단순 max 는 **미래 정보를 과거 버전에 누설**해
--    예측 피처(LTV·유지기간 신4·6~8)를 오염시킨다. 실측 적중 19.73%(1,563,872/7,925,716).
stop_snap as (
    select
        MBER_NO                                            as MBER_NO,
        try_to_date(SPNSR_DSCNTC_DE, 'YYYYMMDD')           as STOP_DT
    from GN_DW.SILVER.CRM_MEMBER_DISCONTINUE
    where try_to_date(SPNSR_DSCNTC_DE, 'YYYYMMDD') is not null
    qualify row_number() over (
        partition by MBER_NO, try_to_date(SPNSR_DSCNTC_DE, 'YYYYMMDD')
        order by SER_NO desc nulls last) = 1
),

member_stop as (
    select
        u.MEMBER_SK                                        as MEMBER_SK,
        s.STOP_DT                                          as LAST_STOP_DATE
    from unioned u
    asof join stop_snap s
        match_condition (u.EFFECTIVE_FROM >= s.STOP_DT)
        on u.MEMBER_DK = s.MBER_NO
),

-- 코드→라벨 사전(빌드시점 lookup). SILVER.CRM_CODE 단일원천 — gold 복제 없이 차원에 비정규화.
-- (CD_ID,DTL_CD_ID) 복합PK → 1:1, fan-out 없음.
code_type as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'MM018'
),
code_status as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'MM010'
),
code_path as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'MM014'
),
-- [2026-08-03 O26] 성별 단일축 = CM017. CM013(원천 지정)과 **같은 코드값의 다른 라벨체계**다.
--   CM017: 1,3→남자 · 2,4→여자 · 5,8→기타 · 6→단체 · 7→기업 (5종) = 정본 공#130 과 정확히 일치.
--   ⚠️ CM017 은 정본 컬럼정의서가 **어떤 컬럼에도 지정하지 않은** 코드그룹이다(0건). 사용 근거는
--      "정본 지정"이 아니라 "정본 공#130 값 정의와 라벨 일치" — 현업 확인 대상(문서20 §H).
code_gender as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM017'
),
-- [2026-08-03 O27] 지역 = CM018 약칭축(정본 공#131 이 약칭이라 CM011 아님) · 실적재 18/18 일치
code_area as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM018'
),
-- [2026-08-03 O27] 연령대 = CM014 12종. 실적재 12/12 일치 · 교차검증 AGE=10↔SEX=6·AGE=11↔SEX=7 각 100%
code_ageband as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM014'
)

select
    u.MEMBER_SK                                   as MEMBER_SK,
    u.MEMBER_DK                                   as MEMBER_DK,
    u.SEX                                         as SEX,           -- [O26] CM013 코드 raw(0~8) — BRONZE 원천명·원천값
    u.SEX_NM                                      as SEX_NM,        -- [O26] CM013 원천 라벨 — 국내·외국인 축 보존
    cg.DTL_CD_NM                                  as GENDER_NAME,   -- [O26] CM017 분석 라벨 = 정본 공#130. 미매칭은 NULL(DEC-17-B 창작금지)
    -- [O27] 지역 — 코드+라벨 병기(DEC-25). 시점귀속(as-of) · sentinel '0' 은 라벨 NULL 로 관측
    ms.AREA_CD                                    as AREA_CD,       -- CM018 코드 raw. 개발약정 시점 스냅샷
    ca.DTL_CD_NM                                  as REGION,        -- CM018 라벨(#131 약칭축)
    -- [O27] 연령대 — AGE 는 나이가 아니라 CM014 코드다(헤더 참조)
    ms.AGE                                        as AGE,           -- CM014 코드 raw(1~12). ⚠️연속형 나이 아님
    cab.DTL_CD_NM                                 as AGE_BAND,      -- CM014 라벨(10대 미만~70대 이상·단체·기업·기타)
    u.MBER_STAT_CD                                as MBER_STAT_CD,  -- MM010 코드 raw
    u.MBER_DIV_CD                                 as MBER_DIV_CD,   -- MM018 개인/기업/단체(코드 raw)
    ct.DTL_CD_NM                                  as MEMBER_TYPE_NAME,   -- MM018 라벨 ⚠️MEMBER_TYPE 의 라벨이 아니다(다른 축)
    -- [2026-08-03] '미상' 폐기 — 개념 부재와 결측을 분리한다(P21).
    --   일시회원(MEMBER_TYPE='ONCE')은 원천에 회원상태가 아예 없다 → '(해당없음)'
    --   정기회원('FDRM')인데 상태가 없으면 진짜 결측 → NULL (라벨 창작 금지, DEC-17-B)
    case when u.MBER_STAT_CD is not null then cs.DTL_CD_NM
         when u.MEMBER_TYPE = 'ONCE'     then '(해당없음)'
         else null end                            as MEMBER_STATUS_NAME, -- MM010 라벨
    CASE
        WHEN u.MBER_STAT_CD = '1'                                            THEN '정상'
        WHEN u.MBER_STAT_CD IN ('2','3','4','5','6','7','8','9','10','11')   THEN '미납'
        WHEN u.MBER_STAT_CD = '12'                                          THEN '중단'
        WHEN u.MEMBER_TYPE = 'ONCE'                                         THEN '(해당없음)'
        ELSE NULL
    END                                           as MEMBER_STATUS_GROUP, -- 대분류(파생)
    -- [O27] 상태전이 축 신설 — 이 SCD2 버전행이 곧 '전이 사건'이다(fan-out 0, 같은 행에서 파생).
    --   원천 `CRM_MEMBER_STATUS_HIST.BF_STAT_CD` 100% 채움(7,501,761)·12종 = **MM010 12/12 일치**.
    --   원천 라벨 `BF_STAT_NM` 도 MM010 과 100% 일치하나 라벨은 사전 조인으로 만든다(P31).
    --   ⚠️ 이력 미보유행(FDRM 무이력·ONCE)은 NULL — 이전상태가 '없다'가 아니라 '이력이 없다'.
    u.PREV_MBER_STAT_CD                           as PREV_MBER_STAT_CD,
    cps.DTL_CD_NM                                 as PREV_MEMBER_STATUS_NAME,
    u.JOIN_DT::DATE                               as FIRST_JOIN_DATE,
    u.CMPGN_CD                                    as FIRST_CAMPAIGN,
    u.JOIN_PATH_CD                                as JOIN_PATH_CD,
    case when u.JOIN_PATH_CD is not null then cp.DTL_CD_NM
         when u.MEMBER_TYPE = 'ONCE'     then '(해당없음)'
         else null end                            as ENROLL_PATH_NAME, -- MM014 가입경로 라벨. ONCE 는 개념 부재
    -- [O27] 최초 후원사업 — 최소 발생일의 SPNSR_BSNS_ID(규칙 불요). ONCE 는 개발약정 부재로 NULL
    fb.FIRST_SPONSORSHIP                          as FIRST_SPONSORSHIP,
    -- [O27] 최종 중단일 — **as-of max**(그 시점까지). 단순 max 는 미래정보 누설이라 금지
    st.LAST_STOP_DATE                             as LAST_STOP_DATE,
    u.EFFECTIVE_FROM                              as EFFECTIVE_FROM,
    u.EFFECTIVE_TO                                as EFFECTIVE_TO,
    u.IS_CURRENT                                  as IS_CURRENT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '884f2b90-c97e-401d-bdb2-d8d7cb6f0017'                    AS DW_BATCH_ID,
    -- [2026-08-03] SILVER 에 존재했으나 CTE 컬럼열거에서 탈락해 있던 컬럼 복원(G3 결손 유형).
    --   FDRM=정기(1,587,343) / ONCE=일시(175,722). ONCE 는 회원상태·가입경로 개념이 원천에 없다.
    --   ⚠️ MEMBER_TYPE_NAME(MM018 개인/기업/단체)은 이 컬럼의 라벨이 아니다 — 다른 축(코드=MBER_DIV_CD).
    u.MEMBER_TYPE                                 as MEMBER_TYPE
from unioned u
left join member_snap  ms  on u.MEMBER_SK       = ms.MEMBER_SK
left join member_stop  st  on u.MEMBER_SK       = st.MEMBER_SK
left join first_biz    fb  on u.MEMBER_DK       = fb.MBER_NO
left join code_type    ct  on u.MBER_DIV_CD     = ct.DTL_CD_ID
left join code_status  cs  on u.MBER_STAT_CD    = cs.DTL_CD_ID
left join code_status  cps on u.PREV_MBER_STAT_CD = cps.DTL_CD_ID
left join code_path    cp  on u.JOIN_PATH_CD    = cp.DTL_CD_ID
left join code_gender  cg  on u.SEX             = cg.DTL_CD_ID
left join code_area    ca  on ms.AREA_CD        = ca.DTL_CD_ID
left join code_ageband cab on to_varchar(ms.AGE) = cab.DTL_CD_ID