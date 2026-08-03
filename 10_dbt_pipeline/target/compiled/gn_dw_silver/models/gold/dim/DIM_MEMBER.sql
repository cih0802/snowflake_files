-- DIM_MEMBER: 회원 차원 SCD2 (CRM_MEMBER 현재값 + STATUS_HIST 이력, 부분적재)
-- Co-authored with CoCo
-- 【회원번호 체계】 CRM은 정식(FDRM)·일시(ONCE)를 별도 테이블로 분리 관리:
--   FDRM → TM_MM_FDRM_MBER_INFO: 번호 0000000~9999999 (7자리, leading-zero 보존)
--   ONCE → TM_MM_ONCE_MBER_INFO: 번호 S00000000~S09999999 (S접두+8자리=9자)
--   GA4 user_id는 이 둘을 단일 필드로 통합 표현 → 'S' 접두 유무로 FDRM/ONCE 판별.
--   MEMBER_DK=VARCHAR(10) 필수·NUMBER 캐스팅 절대 금지.
-- ⚠️ REGION/AGE_BAND=NULL(개발·증감 AREA_CD/AGE 대기), NEW_EXISTING/SPONSORSHIP/STOP 파생 대기.
--
-- ============================================================================
-- [2026-08-03 O26] 명명 규칙 전환 — 코드 컬럼 = BRONZE 원천명 / 라벨 컬럼 = 분석 용어
--   근거: 현업이 아직 BRONZE 를 직접 조회한다(O24 확립). 원천이 이미 수식어 접두 관례를 쓴다
--         (`ACT_/ACMSLT_/REGIST_DEPT_CD` · `EMAIL_/MOBLPHON_/ETC_CTTPC_STAT_CD`) → 신개념 도입 아님.
--   개명: GENDER→SEX · MEMBER_STATUS→MBER_STAT_CD · MEMBER_TYPE→MBER_DIV_CD · ENROLL_PATH→JOIN_PATH_CD
--   유지: 라벨은 분석 용어 그대로 — GENDER_NAME · MEMBER_STATUS_NAME · MEMBER_TYPE_NAME · ENROLL_PATH_NAME
--         REGION · AGE_BAND 도 라벨명이라 유지(미주입 상태. 채울 때 코드컬럼 AREA_CD/AGE 를 병설한다)
--   신설: SEX_NM(CM013 원천 라벨) — 국내/외국인 축 복구
--   🔴 하드코딩 라벨 폐기: 종전 `CASE ... '여성'/'남성'/'미상'` → CRM_CODE CM017 조인으로 대체.
--      라벨은 코드사전이 정본이며 사전이 바뀌면 자동 반영된다.
-- ============================================================================
-- 🔷 D2 SCD2 활성화(2026-07-16): 전용 소스 CRM_MEMBER_STATUS_HIST(7.5M행) 입고완료 → 시점조인 재배선.
--    • 회원상태(MEMBER_STATUS)만 SCD2. 성별·가입일·구분 등 마스터 속성은 SCD1(버전 간 동일값 반복).
--    • grain=회원상태 버전. MEMBER_SK=해시(MEMBER_DK, EFFECTIVE_FROM). 동일 시점(일자) 다중변경(3,151건)은
--      최종상태(max SER_NO)로 축약 후 LEAD 로 EFFECTIVE_TO 재계산 → MEMBER_SK 유일·구간 무중첩 보장.
--    • 이력 미보유(FDRM 무이력 + ONCE 전체)는 가입일 기준 단일버전(IS_CURRENT=TRUE)로 fallback.
--    • 이력 고아 37명(STATUS_HIST엔 있으나 마스터 부재)은 inner join 으로 제외(마스터 속성 없이 회원행 생성 불가).
--    • MEMBER_DK 는 더 이상 unique 아님(버전 반복) → schema.yml 에서 unique 제거, not_null 유지. 다운스트림은 IS_CURRENT 필터.
-- ⚠️ 순서9-D(2026-07-16): grain 이 단일버전→SCD2 로 바뀜. 최초 incremental(merge) 빌드가 옛 SK(hash(DK,JOIN_DT))와
--    새 SK(hash(DK,EFFECTIVE_FROM)) 불일치로 옛 행을 못 덮어써 잔존행(중복 IS_CURRENT 1,264,753) 발생 = R1(문서50 라인95).
--    → 프로젝트 GOLD 표준(dbt_project.yml) fact 패턴 채택: incremental + append + pre-hook TRUNCATE + full_refresh:false.
--      · 매 run TRUNCATE 로 잔존행 원천 차단(멱등·재현) · 06_DDL 구조(PK·타입·COMMENT) 보존(table CTAS 금지 = G-1/G-2 회귀 방지).
--      · grain 비유일(SCD2 버전)이라 merge 대신 append(unique_key 불요). MEMBER_SK 유일·현재행 유일은 schema.yml 테스트로 보증.
--    ※ 선행: 06_DDL 의 DIM_MEMBER CREATE OR REPLACE 로 구조 존재 필요(없으면 첫 run 이 CTAS 로 구조 없이 생성).


with m as (
    select * from GN_DW.SILVER.CRM_MEMBER
),

-- 상태이력(FDRM 전용): 동일 시점(일자) 중복은 최종상태(max SER_NO)로 축약
hist_collapsed as (
    select
        MBER_NO                                       as MBER_NO,
        EFFECTIVE_FROM::DATE                          as EFF_FROM,
        CHN_STAT_CD                                   as STATUS_CD
    from GN_DW.SILVER.CRM_MEMBER_STATUS_HIST
    qualify row_number() over (partition by MBER_NO, EFFECTIVE_FROM::DATE order by SER_NO desc) = 1
),

-- 축약본에서 SCD2 구간(EFFECTIVE_TO)·현재플래그 재계산
hist_scd2 as (
    select
        MBER_NO,
        STATUS_CD,
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
        h.EFF_FROM                                    as EFFECTIVE_FROM,
        h.EFF_TO                                      as EFFECTIVE_TO,
        h.IS_CUR                                      as IS_CURRENT
    from m
    join hist_scd2 h on m.MEMBER_DK = h.MBER_NO
),

-- (B) 이력 미보유(FDRM 무이력 + ONCE 전체) = 가입일 기준 단일버전
single as (
    select
        ABS(HASH(COALESCE(CAST(m.MEMBER_DK AS VARCHAR), '∅') || '‖' || COALESCE(CAST(m.JOIN_DT AS VARCHAR), '∅')))   as MEMBER_SK,
        m.MEMBER_DK, m.SEX, m.SEX_NM, m.MBER_DIV_CD, m.MEMBER_TYPE, m.JOIN_DT, m.CMPGN_CD, m.JOIN_PATH_CD,
        m.MBER_STAT_CD                                as MBER_STAT_CD,
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
--   CM017: 1,3→남자 · 2,4→여자 · 5,8→기타 · 6→단체 · 7→기업 (5종)
--   ⇒ 정본 지표 공#130 성별 정의 "남 / 여 / 기업 / 단체 / 기타" 와 정확히 일치한다.
--   종전 하드코딩 `CASE UPPER(SEX) WHEN 'F' THEN '여성' WHEN 'M' THEN '남성' ELSE '미상' END` 는
--   ① 정본 5종을 3종으로 축약 ② 정본에 없는 '미상'을 창작 ③ 법인·단체(성별 개념 부재)를 '미상'으로 오라벨
--   했다(실측: SEX='U' 115,358명 중 기업 40,003 + 단체 14,989 = 54,992명 = 47.7%).
--   ⚠️ CM017 은 정본 컬럼정의서가 **어떤 컬럼에도 지정하지 않은** 코드그룹이다(0건). 사용 근거는
--      "정본 지정"이 아니라 "정본 공#130 값 정의와 라벨 일치" — 현업 확인 대상.
--   ⚠️ (CD_ID,DTL_CD_ID) PK 라 fan-out 없음(실측 8행=8 distinct).
code_gender as (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'CM017'
)

select
    MEMBER_SK                                     as MEMBER_SK,
    MEMBER_DK                                     as MEMBER_DK,
    SEX                                           as SEX,           -- [O26] CM013 코드 raw(0~8) — BRONZE 원천명·원천값
    SEX_NM                                        as SEX_NM,        -- [O26] CM013 원천 라벨(국내(남자)/외국인(여자)/단체/기업 …) — 국내·외국인 축 보존
    cg.DTL_CD_NM                                  as GENDER_NAME,   -- [O26] CM017 분석 라벨(남자/여자/기타/단체/기업) = 정본 공#130. [2026-08-03] COALESCE('미상') 폐기 → 미매칭은 NULL(DEC-17-B 창작금지)
    CAST(NULL AS VARCHAR)                          as REGION,       -- ⚠️ 개발·증감 AREA_CD 대기. 채울 때 코드컬럼 `AREA_CD`(CM018) 병설
    CAST(NULL AS VARCHAR)                          as AGE_BAND,     -- ⚠️ 개발·증감 AGE 대기. 채울 때 코드컬럼 `AGE`(CM014) 병설
    MBER_STAT_CD                                  as MBER_STAT_CD,  -- MM010 코드 raw. 버전행=CHN_STAT_CD(변경상태코드)·무이력행=MBER_STAT_CD(회원상태코드). 정본 명칭은 후자
    MBER_DIV_CD                                   as MBER_DIV_CD,   -- MM018 개인/기업/단체(코드 raw)
    ct.DTL_CD_NM                                  as MEMBER_TYPE_NAME,   -- MM018 라벨(1개인/2기업/3단체) ⚠️MEMBER_TYPE 의 라벨이 아니다(다른 축)
    -- [2026-08-03] '미상' 폐기 — 개념 부재와 결측을 분리한다(P21).
    --   일시회원(MEMBER_TYPE='ONCE')은 원천에 회원상태가 아예 없다 → '(해당없음)'
    --   정기회원('FDRM')인데 상태가 없으면 진짜 결측 → NULL (라벨 창작 금지, DEC-17-B)
    --   실측 2026-08-03: ONCE 175,722 전건 상태 NULL · FDRM 1,587,343 중 NULL 1명
    --   표기 선례: DIM_DEVICE.sql 5~6행 — '(해당없음)'=확정된 정상 멤버 / 0·(unknown)=진짜 미상
    case when u.MBER_STAT_CD is not null then cs.DTL_CD_NM
         when u.MEMBER_TYPE = 'ONCE'     then '(해당없음)'
         else null end                            as MEMBER_STATUS_NAME, -- MM010 라벨(활동/신규미납/장기미납/후원중단)
    CASE
        WHEN MBER_STAT_CD = '1'                                            THEN '정상'
        WHEN MBER_STAT_CD IN ('2','3','4','5','6','7','8','9','10','11')   THEN '미납'
        WHEN MBER_STAT_CD = '12'                                          THEN '중단'
        WHEN u.MEMBER_TYPE = 'ONCE'                                       THEN '(해당없음)'
        ELSE NULL
    END                                           as MEMBER_STATUS_GROUP, -- 대분류(파생)
    CAST(NULL AS VARCHAR)                          as NEW_EXISTING_FLAG,  -- ⚠️ 파생규칙 미정. 채울 때 코드컬럼 `RELATNSP_DIV_CD`(MM019) 병설
    JOIN_DT::DATE                                 as FIRST_JOIN_DATE,
    CMPGN_CD                                      as FIRST_CAMPAIGN,
    JOIN_PATH_CD                                  as JOIN_PATH_CD,
    case when u.JOIN_PATH_CD is not null then cp.DTL_CD_NM
         when u.MEMBER_TYPE = 'ONCE'     then '(해당없음)'
         else null end                            as ENROLL_PATH_NAME, -- MM014 가입경로 라벨. ONCE 는 가입경로 개념 부재
    CAST(NULL AS VARCHAR)                          as FIRST_SPONSORSHIP,   -- ⚠️ SPONSOR_BIZ 대기
    CAST(NULL AS DATE)                             as LAST_STOP_DATE,      -- ⚠️ DISCONTINUE 대기
    CAST(NULL AS VARCHAR)                          as LAST_CAMPAIGN,       -- ⚠️ 이력 대기
    CAST(NULL AS VARCHAR)                          as CURRENT_SPONSORSHIP, -- ⚠️ SPONSOR_BIZ 대기
    EFFECTIVE_FROM                                as EFFECTIVE_FROM,
    EFFECTIVE_TO                                  as EFFECTIVE_TO,
    IS_CURRENT                                    as IS_CURRENT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'caf0ed7e-1e99-4c1d-b479-e0fc6272f462'                    AS DW_BATCH_ID,
    -- [2026-08-03] SILVER 에 존재했으나 CTE 컬럼열거에서 탈락해 있던 컬럼 복원(G3 결손 유형).
    --   FDRM=정기(1,587,343) / ONCE=일시(175,722). ONCE 는 회원상태·가입경로 개념이 원천에 없다.
    --   ⚠️ MEMBER_TYPE_NAME(MM018 개인/기업/단체)은 이 컬럼의 라벨이 아니다 — 다른 축(코드=MBER_DIV_CD).
    MEMBER_TYPE                                   as MEMBER_TYPE
from unioned u
left join code_type   ct on u.MBER_DIV_CD   = ct.DTL_CD_ID
left join code_status cs on u.MBER_STAT_CD  = cs.DTL_CD_ID
left join code_path   cp on u.JOIN_PATH_CD  = cp.DTL_CD_ID
left join code_gender cg on u.SEX           = cg.DTL_CD_ID