-- [4-1. F-3] 이메일 오픈 데이터 부재 실측 (전건 0/NULL)
SELECT 'EMAIL 오픈 URL_OTHBC_CNT_CTNT' AS "항목",
    COUNT(*) AS "전체행수",
    COUNT(url_othbc_cnt_ctnt) AS "값있는행",
    COUNT(CASE WHEN TRY_TO_NUMBER(url_othbc_cnt_ctnt) > 0 THEN 1 END) AS "0초과행"
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG
UNION ALL
SELECT 'EMAIL 오픈율 URL_OTHBC_RT_CTNT',
    COUNT(*),
    COUNT(url_othbc_rt_ctnt),
    COUNT(CASE WHEN TRY_TO_NUMBER(url_othbc_rt_ctnt) > 0 THEN 1 END)
FROM GN_DW.BRONZE_CRM.TD_MS_EMAIL_LQY_SNDNG;