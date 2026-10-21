-- =============================================================================
-- Purpose    : 발송 요청 차원 (SNDNG_KEY grain = 1행/발송요청) — CRM_SEND_REQUEST + CRM_SEND_RESULT(1:1)
-- Target     : GOLD.DIM_SEND_REQUEST (dbt model)
-- Run order  : dbt build (문서실행순서 dbt 단계)
-- Depends on : ref CRM_SEND_REQUEST, ref CRM_SEND_RESULT, ref CRM_CODE
-- Issue      : O196-D, DEC-58, O191-G, DEC-58-D 외 4
-- =============================================================================
-- DIM_SEND_REQUEST: 발송 요청 차원 (SNDNG_KEY grain = 1행/발송요청) — CRM_SEND_REQUEST + CRM_SEND_RESULT(1:1)
--  [2026-10-01 O196-D · DEC-58 #1] 신설 — O191-G 보류분 발송요청 16 · 발송결과 7 의 GOLD 반영.
--    실측 = SNDNG_KEY 전역 유일(1,722,090) · 결과는 요청과 1:1(채널+키 유일 · 고아 21행은 차원에 들어오지 않는다).
--   WARN: 이 차원의 속성을 FACT_MESSAGE_DISPATCH(발송×회원 grain)에 degen 으로 붙이지 마라 — FK(SEND_REQUEST_SK)로만 잇는다(DEC-58-D).


select
    ABS(HASH(COALESCE(CAST(q.SNDNG_KEY AS VARCHAR), '∅')))                 as SEND_REQUEST_SK,
    q.SNDNG_KEY, q.SEND_CHANNEL, q.SNDNG_TY_CD,
    q.SEND_GBN_TOP, q.SEND_GBN_TOP_NM, q.SEND_GBN_MID, q.SEND_GBN_MID_NM, q.SEND_GBN_BOT, q.SEND_GBN_BOT_NM,
    q.TIT, q.SNDNG_STDR_DE, q.REQ_SEQ_NO,
    -- 발송요청 16 (SILVER 2차-B · 채널별 비해당 NULL)
    q.SNDNG_CD_ID, q.SNDNG_DTL_CD_ID, q.PRCS_DE, q.PRCS_YN, q.TMPLAT_ID, q.ALTRTV_MSG_SNDNG_YN,
    q.LQY_YN, q.RE_SNDNG_YN, q.MSG_TYPE, q.REGULARLY, q.SEND_STATUS, q.SEND_ROUND,
    q.CONDITION_TITLE, q.MENU_CODE, q.SERVICE_MENU_CODE, q.USE_YN,
    -- 발송결과 7 (요청 1:1 · 결과 미적재 요청은 NULL)
    r.RECPTN_CNT, r.ALTRTV_SNDNG_CNT, r.SNDNG_STRT_DT, r.SNDNG_END_DT, r.RESVE_SNDNG_DE, r.SNDNG_SQNC, r.SNDNG_TIT,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID,
    --  [2026-10-08 O213-E · 7차 Y3-E] 요청 분류 축 라벨(감사 컬럼 뒤 · 코드그룹 실측 · 채널 비해당 NULL)
    q.MSG_DIV_CD,                                   -- MS010 · 알림톡 전용
    c_md.DTL_CD_NM                                  as MSG_DIV_NAME,
    q.SNDNG_TIME_DIV_CD,                            -- MS267 · 알림톡 전용
    c_tm.DTL_CD_NM                                  as SNDNG_TIME_DIV_NAME,
    q.PSTMTR_PRCS_STAT_CD,                          -- MS061 · 우편 전용
    c_ps.DTL_CD_NM                                  as PSTMTR_PRCS_STAT_NAME,
    q.CORP_TYPE,                                    -- CM019 · SND 전용
    c_cp.DTL_CD_NM                                  as CORP_TYPE_NAME,
    q.SEND_SPLIT_TYPE                               -- SND 전용 원천값 once / divide
from GN_DW.SILVER.CRM_SEND_REQUEST q
left join GN_DW.SILVER.CRM_SEND_RESULT r
    on r.SNDNG_KEY = q.SNDNG_KEY and r.SEND_CHANNEL = q.SEND_CHANNEL
left join GN_DW.SILVER.CRM_CODE c_md on c_md.CD_ID = 'MS010' and c_md.DTL_CD_ID = q.MSG_DIV_CD
left join GN_DW.SILVER.CRM_CODE c_tm on c_tm.CD_ID = 'MS267' and c_tm.DTL_CD_ID = q.SNDNG_TIME_DIV_CD
left join GN_DW.SILVER.CRM_CODE c_ps on c_ps.CD_ID = 'MS061' and c_ps.DTL_CD_ID = q.PSTMTR_PRCS_STAT_CD
left join GN_DW.SILVER.CRM_CODE c_cp on c_cp.CD_ID = 'CM019' and c_cp.DTL_CD_ID = q.CORP_TYPE

union all
--  [O249 · DR-31 · A8-29] unknown 멤버(SK=0): FACT_MESSAGE_DISPATCH.SEND_REQUEST_SK=0(요청 미매핑 3,001행 · SR61467 실측)
--   의 FK 고아 해소 · DIM_SERVICE 와 같은 센티넬 규약. 열 순서 = 라이브 49열(2 + 34 NULL + 감사 4 + 9 NULL).
--   WARN: SNDNG_KEY 는 NUMBER 다 ⇒ 센티넬 키 = 0(원천에 0 없음 · 2026-10-20 실측 · 문자 '(미매핑)' 은 100038 로 실패했다).
select 0, 0,
    '(미매핑)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    'b67f4402-58f8-4f78-bd36-31fecd4eb48e'                    AS DW_BATCH_ID,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL