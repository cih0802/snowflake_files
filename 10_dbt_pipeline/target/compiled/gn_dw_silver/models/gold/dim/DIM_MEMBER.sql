-- DIM_MEMBER: 회원 차원 SCD2 (CRM_MEMBER 현재값 + STATUS_HIST 이력, 부분적재)
-- Co-authored with CoCo
-- 【회원번호 체계】 CRM은 정식(FDRM)·일시(ONCE)를 별도 테이블로 분리 관리:
--   FDRM → TM_MM_FDRM_MBER_INFO: 번호 0000000~9999999 (7자리, leading-zero 보존)
--   ONCE → TM_MM_ONCE_MBER_INFO: 번호 S00000000~S09999999 (S접두+8자리=9자)
--   GA4 user_id는 이 둘을 단일 필드로 통합 표현 → 'S' 접두 유무로 FDRM/ONCE 판별.
--   MEMBER_DK=VARCHAR(10) 필수·NUMBER 캐스팅 절대 금지.
-- ⚠️ REGION/AGE_BAND=NULL(개발·증감 AREA_CD/AGE 대기), NEW_EXISTING/SPONSORSHIP/STOP 파생 대기.
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
        m.MEMBER_DK, m.SEX, m.MBER_DIV_CD, m.JOIN_DT, m.CMPGN_CD, m.JOIN_PATH_CD,
        h.STATUS_CD                                   as MEMBER_STATUS,
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
        m.MEMBER_DK, m.SEX, m.MBER_DIV_CD, m.JOIN_DT, m.CMPGN_CD, m.JOIN_PATH_CD,
        m.MBER_STAT_CD                                as MEMBER_STATUS,
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
)

select
    MEMBER_SK                                     as MEMBER_SK,
    MEMBER_DK                                     as MEMBER_DK,
    SEX                                           as GENDER,       -- 코드 raw(라벨화는 CRM_CODE 조인 후)
    CAST(NULL AS VARCHAR)                          as REGION,       -- ⚠️ 개발·증감 AREA_CD 대기
    CAST(NULL AS VARCHAR)                          as AGE_BAND,     -- ⚠️ 개발·증감 AGE 대기
    MEMBER_STATUS                                 as MEMBER_STATUS, -- MM010 코드 raw(버전=CHN_STAT_CD, 무이력=MBER_STAT_CD)
    MBER_DIV_CD                                   as MEMBER_TYPE,   -- MM018 개인/기업/단체(코드 raw)
    CAST(NULL AS VARCHAR)                          as NEW_EXISTING_FLAG,  -- ⚠️ 파생규칙 미정
    JOIN_DT::DATE                                 as FIRST_JOIN_DATE,
    CMPGN_CD                                      as FIRST_CAMPAIGN,
    JOIN_PATH_CD                                  as ENROLL_PATH,
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
    '50eaa2d8-6f32-46e5-ad87-91e23c3b74a4'                    AS DW_BATCH_ID
from unioned