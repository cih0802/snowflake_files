-- DIM_MEMBER: 회원 차원 SCD2 (CRM_MEMBER 현재값 + STATUS_HIST 이력, 부분적재)
-- Co-authored with CoCo
-- 【회원번호 체계】 CRM은 정식(FDRM)·일시(ONCE)를 별도 테이블로 분리 관리:
--   FDRM → TM_MM_FDRM_MBER_INFO: 번호 0000000~9999999 (7자리, leading-zero 보존)
--   ONCE → TM_MM_ONCE_MBER_INFO: 번호 S00000000~S09999999 (S접두+8자리=9자)
--   GA4 user_id는 이 둘을 단일 필드로 통합 표현 → 'S' 접두 유무로 FDRM/ONCE 판별.
--   MEMBER_DK=VARCHAR(10) 필수·NUMBER 캐스팅 절대 금지.
-- ⚠️ REGION/AGE_BAND=NULL(개발·증감 AREA_CD/AGE 대기), 상태이력=STATUS_HIST 입고 후 SCD2 확장
--    현재: CRM_MEMBER 스냅샷 1버전(IS_CURRENT=TRUE)만. MEMBER_SK=해시(MEMBER_DK+EFFECTIVE_FROM)
-- 🔷 D2 결정(→33 레지스트리 §B): 실제 SCD2 방향 확정(회원상태 한정). 전용 소스 CRM_MEMBER_STATUS_HIST가
--    현재 0행(BRONZE TH_MM_FDRM_MBER_STNG_DTLS 미입고)이라 단일버전 유지 = 정상. 활성 전제조건 6종(소스입고·
--    MEMBER_SK=해시(MEMBER_DK,EFFECTIVE_FROM) 재정의·BF/CHN_STAT_CD↔MM010 매핑·SER_NO 정합·ONCE fallback·
--    다운스트림 시점조인) 충족 전까지 STATUS_HIST 조인 금지(미검증 소스에 대한 추정 로직 지양).


with m as (
    select * from GN_DW.SILVER.CRM_MEMBER
)

select
    ABS(HASH(COALESCE(CAST(MEMBER_DK AS VARCHAR), '∅') || '‖' || COALESCE(CAST(JOIN_DT AS VARCHAR), '∅')))       as MEMBER_SK,
    MEMBER_DK                                     as MEMBER_DK,
    SEX                                           as GENDER,       -- 코드 raw(라벨화는 CRM_CODE 조인 후)
    CAST(NULL AS VARCHAR)                          as REGION,       -- ⚠️ 개발·증감 AREA_CD 대기
    CAST(NULL AS VARCHAR)                          as AGE_BAND,     -- ⚠️ 개발·증감 AGE 대기
    MBER_STAT_CD                                  as MEMBER_STATUS, -- 정기만(일시 NULL)
    MBER_DIV_CD                                   as MEMBER_TYPE,   -- MM018 개인/기업/단체(코드 raw)
    CAST(NULL AS VARCHAR)                          as NEW_EXISTING_FLAG,  -- ⚠️ 파생규칙 미정
    JOIN_DT::DATE                                 as FIRST_JOIN_DATE,
    CMPGN_CD                                      as FIRST_CAMPAIGN,
    JOIN_PATH_CD                                  as ENROLL_PATH,
    CAST(NULL AS VARCHAR)                          as FIRST_SPONSORSHIP,   -- ⚠️ SPONSOR_BIZ 대기
    CAST(NULL AS DATE)                             as LAST_STOP_DATE,      -- ⚠️ DISCONTINUE 대기
    CAST(NULL AS VARCHAR)                          as LAST_CAMPAIGN,       -- ⚠️ 이력 대기
    CAST(NULL AS VARCHAR)                          as CURRENT_SPONSORSHIP, -- ⚠️ SPONSOR_BIZ 대기
    JOIN_DT::DATE                                 as EFFECTIVE_FROM,
    CAST(NULL AS DATE)                             as EFFECTIVE_TO,
    TRUE                                          as IS_CURRENT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'd4528355-3625-41c3-b3d2-8c3c022ddc03'                    AS DW_BATCH_ID
from m