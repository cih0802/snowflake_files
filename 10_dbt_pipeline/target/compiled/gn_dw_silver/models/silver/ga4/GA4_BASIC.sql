-- GA4_BASIC: source(silver_external,BIGQUERY_REFINED_DATA) 재파생 기반 테이블. GA4_* 5종의 유일 입력.
-- Co-authored with CoCo
--
-- 🆕 [2026-08-21] 신설 배경 — `BIGQUERY_REFINED_DATA` 가 외부 Python 적재로 전환되며
--    118컬럼 평탄화만 남고 파생(EVENT_DT·EVENT_SEQ·ID_SCHEME·GA_SESSION_KEY·DEVICE_TYPE·
--    UTM/XCHAN 등)을 전부 잃었다. GA4_* 5종은 그 파생 컬럼을 전제하므로 dbt build 가
--    ERROR 9건으로 막혔다. 이 모델이 그 파생을 되살린다(종전 커밋아웃된 `BIGQUERY_REFINED_DATA`
--    dbt 모델 DDL 을 계승 — `04_silver_design/08_SILVER_테이블DDL_20260714.sql` GA4 0).
--
-- 🔴 EVENT_SEQ 결정성은 해소되지 않았다(`GA4-SEQ-1`, 정본 = `20_issue/90_해소완료_로그.md`).
--    `BATCH_EVENT_INDEX`+`EVENT_BUNDLE_SEQUENCE_ID` 타이브레이커는 2025-06 실측에서
--    3키 중복 8.66%(781,910/9,028,480)를 **전혀 줄이지 못했다**(두 컬럼 모두 100% 비NULL —
--    값 자체가 원천에서 중복). `ROW_NUMBER()` 는 그래도 각 파티션 내 유일 정수를 부여하므로
--    PK 4키 유일성(`assert_ga4_pk_unique`)은 성립하지만, 동일 정렬 튜플 내에서 어느 행이
--    몇 번을 받는지는 **재실행마다 바뀔 수 있다**(`20_issue/30_설계_의사결정-008.md:155`).
--    이 미결을 「손실 0」으로 되쓰지 말 것 — 접히는 중복은 의도된 dedup 으로 수용한다.
--
-- 🔴 USER_ID 는 원본 그대로 쓴다(`UP_MEMBER_ID` 금지) — `UP_MEMBER_ID` 는 선행 0 이 소실된다
--    (실측: USER_ID='0470071' ↔ UP_MEMBER_ID='470071') ⇒ `^[0-9]{7}$` 정규식이 깨진다.
--
-- 🔴 EVENT_DATE 범위 필터는 `TO_DATE()` 로 감싸지 않는다 — 원본이 TEXT(YYYYMMDD)이고
--    사전순=시간순이라 리터럴 문자열 비교라야 마이크로파티션 프루닝이 유지된다
--    (함수를 적용하면 프루닝이 깨진다 · `20_issue/02_...-007.md:102`). 파생 `EVENT_DT`(DATE)는
--    출력 컬럼일 뿐 필터에는 쓰지 않는다. `ga4_range_predicate` 매크로는 진짜 DATE 컬럼을
--    전제하므로 여기서는 재사용하지 않고 `ga4_dt_ranges` var 를 직접 문자열로 변환한다.
--
-- 🔴 pre-hook 은 `macros/silver_purge.sql` 이 분기한다(`RANGED_MODELS` 에 이 모델명 등재 필수).
--
-- 🔴 [P103-⑤ 계승] USER_PSEUDO_ID(PK 1번째 키·NOT NULL)가 원천에서 NULL 인 행 111건이 실측됐다
--    (기지 창 = EVENT_DT 2024-06-05~06-10 · 정본 = tests/warn_ga4_null_user_pseudo_id.sql).
--    그대로 두면 100072 로 모델 전체가 실패한다 ⇒ 필터로 제외한다. 그 필터가 삼키는 양이
--    커지는지는 `warn_ga4_null_user_pseudo_id` 가 기지 창 밖에서 감시한다.


with raw as (
    select *
    from GN_DW.SILVER.BIGQUERY_REFINED_DATA
    where USER_PSEUDO_ID is not null
      and (
        (EVENT_DATE between '20240601' and '20240630')
        OR (EVENT_DATE between '20250601' and '20250630')
        OR (EVENT_DATE between '20260601' and '20260630')
    )
),
seq as (
    select
        *,
        row_number() over (
            partition by USER_PSEUDO_ID, EVENT_TIMESTAMP, EVENT_NAME
            order by BATCH_EVENT_INDEX nulls last, EVENT_BUNDLE_SEQUENCE_ID nulls last
        ) as EVENT_SEQ
    from raw
)
select
    USER_PSEUDO_ID                                               as USER_PSEUDO_ID,
    EVENT_TIMESTAMP                                               as EVENT_TIMESTAMP,
    EVENT_NAME                                                   as EVENT_NAME,
    EVENT_SEQ                                                    as EVENT_SEQ,
    EVENT_DATE                                                   as EVENT_DATE,
    TO_DATE(EVENT_DATE, 'YYYYMMDD')                              as EVENT_DT,
    TO_TIMESTAMP_NTZ(EVENT_TIMESTAMP / 1000000)                  as EVENT_TS,
    USER_ID                                                      as USER_ID,
    case
        when USER_ID rlike '^[0-9]{7}$'          then 'MBER_NO'
        when USER_ID rlike '^S[0-9]{8}$'         then 'ONCE_MBER_NO'
        when startswith(USER_ID, 'app-')         then 'APP'
        when position('@', USER_ID) > 0          then 'EMAIL'
        when lower(USER_ID) in ('null','undefined') then 'INVALID'
        when USER_ID is not null                 then 'UNCLASSIFIED'
        else null end                                             as ID_SCHEME,
    try_cast(EP_GA_SESSION_ID as number)                         as GA_SESSION_ID,
    try_cast(EP_GA_SESSION_NUMBER as number)                     as GA_SESSION_NUMBER,
    case when EP_GA_SESSION_ID is not null
         then USER_PSEUDO_ID || '-' || EP_GA_SESSION_ID
         else null end                                            as GA_SESSION_KEY,
    EP_SESSION_ENGAGED                                           as SESSION_ENGAGED,
    try_cast(EP_ENGAGEMENT_TIME_MSEC as number)                  as ENGAGEMENT_TIME_MSEC,
    EP_PAGE_LOCATION                                             as PAGE_LOCATION,
    EP_PAGE_TITLE                                                as PAGE_TITLE,
    EP_PAGE_REFERRER                                             as PAGE_REFERRER,
    nullif(nullif(EP_EVENT_CATEGORY, '(not set)'), 'None')       as EVENT_CATEGORY,
    nullif(nullif(EP_EVENT_ACTION, '(not set)'), 'None')         as EVENT_ACTION,
    nullif(nullif(EP_EVENT_LABEL, '(not set)'), 'None')          as EVENT_LABEL,
    try_cast(EP_PERCENT_SCROLLED as number)                      as PERCENT_SCROLLED,
    EP_LINK_URL                                                  as LINK_URL,
    EP_LINK_TEXT                                                 as LINK_TEXT,
    case
        when PLATFORM = 'WEB' and DEVICE_CATEGORY = 'desktop'    then 'PC'
        when DEVICE_CATEGORY in ('mobile','tablet')              then 'M'
        when PLATFORM in ('ANDROID','IOS')                       then 'APP'
        else '(unknown)' end                                     as DEVICE_TYPE,
    DEVICE_CATEGORY                                              as DEVICE_CATEGORY,
    DEVICE_OPERATING_SYSTEM                                      as OS,
    DEVICE_WEB_INFO_BROWSER                                      as BROWSER,
    DEVICE_LANGUAGE                                              as LANGUAGE,
    PLATFORM                                                     as PLATFORM,
    IS_ACTIVE_USER                                               as IS_ACTIVE_USER,
    GEO_COUNTRY                                                  as GEO_COUNTRY,
    GEO_CITY                                                     as GEO_CITY,
    nullif(nullif(STSLC_MC_SOURCE, '(not set)'), 'None')         as UTM_SOURCE,
    nullif(nullif(STSLC_MC_MEDIUM, '(not set)'), 'None')         as UTM_MEDIUM,
    STSLC_MC_CAMPAIGN_NAME                                       as UTM_CAMPAIGN,
    STSLC_MC_CONTENT                                             as UTM_CONTENT,
    STSLC_MC_TERM                                                as UTM_TERM,
    case when STSLC_CRC_SOURCE is not null or STSLC_CRC_MEDIUM is not null
         then coalesce(STSLC_CRC_SOURCE, '') || ' / ' || coalesce(STSLC_CRC_MEDIUM, '')
         else null end                                            as SOURCE_MEDIUM,
    nullif(nullif(STSLC_CRC_SOURCE, '(not set)'), 'None')        as XCHAN_SOURCE,
    nullif(nullif(STSLC_CRC_MEDIUM, '(not set)'), 'None')        as XCHAN_MEDIUM,
    STSLC_CRC_CAMPAIGN_NAME                                      as XCHAN_CAMPAIGN,
    STSLC_CRC_DEFAULT_CHANNEL_GROUP                              as DEFAULT_CHANNEL_GROUP,
    STSLC_GAC_AD_GROUP_ID                                        as GAC_AD_GROUP_ID,
    STSLC_GAC_AD_GROUP_NAME                                      as GAC_AD_GROUP_NAME,
    STSLC_GAC_CAMPAIGN_NAME                                      as GAC_CAMPAIGN_NAME,
    BATCH_EVENT_INDEX                                            as BATCH_ORDERING_ID,
    'GA4'                                                        as DW_SOURCE_SYSTEM,
    'SILVER.BIGQUERY_REFINED_DATA'                               as DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()                                          as DW_LOAD_TS,
    CURRENT_TIMESTAMP()                                          as DW_UPDATE_TS,
    NULL                                                         as DW_BATCH_ID
from seq