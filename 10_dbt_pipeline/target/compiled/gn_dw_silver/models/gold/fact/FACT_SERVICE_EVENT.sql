-- FACT_SERVICE_EVENT: 발송 서비스 팩트 (CRM_SEND_MEMBER × CRM_SEND_REQUEST) — A3: SERVICE_SK·SEND_TITLE 실채움
-- Co-authored with CoCo
-- ✅ A3(2026-07-21): 발송요청 마스터(CRM_SEND_REQUEST) SNDNG_KEY 조인(커버 99.97%) → SERVICE_SK(DIM_SERVICE 동일 해시)·SEND_TITLE(TIT) 실채움. 요청 미매칭 → SERVICE_SK=0(Unknown).
-- ⚠️ 스캐폴드 잔여: 행당 SEND_MEMBERS=1. 성과지표(SUCCESS/FAIL/OPEN·D5)=0 은 B1(코드매핑)·CAMPAIGN_SK=0 은 B3(원천 캠페인 컬럼 부재).
-- ❌ APP_PUSH_SEND_CNT/SUCCESS_CNT: 어드민 원천 ❌제외 확정(2026-07-09) → 컬럼 삭제. 내년 어드민 구현 시 컬럼 재추가(ADD COLUMN).
-- 순서9(G-1/G-2 해소): table→incremental+append+pre-hook TRUNCATE(dbt_project.yml gold.fact). DDL 구조·타입·FK 보존, 데이터만 전체 갱신(멱등). append 라 unique_key 불요.


with s as (
    select * from GN_DW.SILVER.CRM_SEND_MEMBER
),
req as (
    -- 발송요청 마스터: SNDNG_KEY unique(1,614,397). SERVICE_SK 산식 컬럼(SEND_CHANNEL·SNDNG_TY_CD) + 제목(TIT).
    select SNDNG_KEY, SEND_CHANNEL, SNDNG_TY_CD, TIT
    from GN_DW.SILVER.CRM_SEND_REQUEST
)

select
    COALESCE(CASE WHEN s.SNDNG_DE::DATE BETWEEN '1991-01-01' AND '2035-12-31'
         THEN TRY_TO_NUMBER(TO_CHAR(s.SNDNG_DE::DATE, 'YYYYMMDD')) END, 0)  as DATE_SK,   -- 범위밖/NULL → 0 (순서9)
    s.MBER_NO                                     as MEMBER_DK,
    -- A3: DIM_SERVICE.SERVICE_SK = gold_sk([SEND_CHANNEL, SNDNG_TY_CD]) 와 동일 산식(요청 마스터 값 사용). 미매칭 → 0.
    CASE WHEN r.SNDNG_KEY IS NULL THEN 0
         ELSE ABS(HASH(COALESCE(CAST(r.SEND_CHANNEL AS VARCHAR), '∅') || '‖' || COALESCE(CAST(r.SNDNG_TY_CD AS VARCHAR), '∅'))) END  as SERVICE_SK,
    0                                             as CAMPAIGN_SK,   -- B3: 원천에 캠페인 컬럼 부재(요청 마스터에도 없음)
    1                                             as SEND_MEMBERS,
    0 as SUCCESS_MEMBERS, 0 as FAIL_MEMBERS, 0 as OPEN_MEMBERS,     -- B1: SNDNG_RST_CD→성공/실패 코드매핑 확정 후
    0 as LETTER_PART_MEMBERS, 0 as LETTER_PART_CNT, 0 as GIFT_PART_MEMBERS, 0 as GIFT_PART_AMT,
    0 as D5_LETTER_PART_MEMBERS, 0 as D5_LETTER_PART_CNT, 0 as D5_GIFT_PART_MEMBERS, 0 as D5_GIFT_PART_CNT,
    0 as D5_INCREASE_PART_MEMBERS, 0 as D5_INCREASE_PART_CNT, 0 as D5_STOP_MEMBERS, 0 as D5_STOP_CNT,
    0 as SERVICE_MEMBERS, 0 as SERVICE_CNT,
    r.TIT                                          as SEND_TITLE,    -- A3: 발송 제목 실채움(구 NULL)
    s.SNDNG_RST_CD                                as SEND_STATUS,
    CAST(NULL AS VARCHAR)                          as SEND_STATUS2,
    s.SEND_CHANNEL                                as SEND_TYPE,
    CAST(NULL AS BOOLEAN)                          as MAIL_RECEIVE_FLAG,
    CAST(NULL AS BOOLEAN)                          as MEMBER_STOP_FLAG,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b50d9005-0be3-463b-8b58-76f0c3a68e8a'                    AS DW_BATCH_ID
from s
left join req r on s.SNDNG_KEY = r.SNDNG_KEY      -- SNDNG_KEY unique → fan-out 없음
where s.MBER_NO is not null                       -- 순수 불량 745행 제외(NOT NULL MEMBER_DK)