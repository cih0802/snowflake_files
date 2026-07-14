-- FACT_SERVICE_EVENT: 발송 서비스 팩트 스캐폴드 (CRM_SEND_MEMBER, Bronze 입고 후 실행)
-- Co-authored with CoCo
-- ⚠️ 스캐폴드: 행당 SEND_MEMBERS=1. 성과지표(OPEN/성공/실패)·D5는 입고 후. SERVICE_SK/CAMPAIGN_SK=0 센티넬.
-- ❌ APP_PUSH_SEND_CNT/SUCCESS_CNT: 어드민 원천 ❌제외 확정(2026-07-09) → 컬럼 삭제. 내년 어드민 구현 시 컬럼 재추가(ADD COLUMN).
-- 🔴 D1 임시조치[삭제금지]: materialized=table 로 스캐폴드 행소실 방지. 프로젝트 마감 전 'incremental'(SERVICE_SK 등 실적재 시) 재전환 검토 필수. 이력/코드 정리 시에도 이 주석 보존.


with s as (
    select * from GN_DW.SILVER.CRM_SEND_MEMBER
)

select
    TRY_TO_NUMBER(TO_CHAR(s.SNDNG_DE::DATE, 'YYYYMMDD'))             as DATE_SK,
    s.MBER_NO                                     as MEMBER_DK,
    0                                             as SERVICE_SK,
    0                                             as CAMPAIGN_SK,
    1                                             as SEND_MEMBERS,
    0 as SUCCESS_MEMBERS, 0 as FAIL_MEMBERS, 0 as OPEN_MEMBERS,
    0 as LETTER_PART_MEMBERS, 0 as LETTER_PART_CNT, 0 as GIFT_PART_MEMBERS, 0 as GIFT_PART_AMT,
    0 as D5_LETTER_PART_MEMBERS, 0 as D5_LETTER_PART_CNT, 0 as D5_GIFT_PART_MEMBERS, 0 as D5_GIFT_PART_CNT,
    0 as D5_INCREASE_PART_MEMBERS, 0 as D5_INCREASE_PART_CNT, 0 as D5_STOP_MEMBERS, 0 as D5_STOP_CNT,
    0 as SERVICE_MEMBERS, 0 as SERVICE_CNT,
    CAST(NULL AS VARCHAR)                          as SEND_TITLE,
    s.SNDNG_RST_CD                                as SEND_STATUS,
    CAST(NULL AS VARCHAR)                          as SEND_STATUS2,
    s.SEND_CHANNEL                                as SEND_TYPE,
    CAST(NULL AS BOOLEAN)                          as MAIL_RECEIVE_FLAG,
    CAST(NULL AS BOOLEAN)                          as MEMBER_STOP_FLAG,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '24b70347-040a-40c6-b075-ccde404e290d'                    AS DW_BATCH_ID
from s