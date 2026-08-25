-- CRM_MEMBER_STATUS_HIST: 회원 상태이력 SCD2 (MM010 라벨, LEAD 기반 EFFECTIVE_TO/IS_CURRENT), 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  s.MBER_NO                        AS MBER_NO,
  s.SER_NO                         AS SER_NO,
  s.BF_STAT_CD                     AS BF_STAT_CD,
  bf.DTL_CD_NM                     AS BF_STAT_NM,
  s.CHN_STAT_CD                    AS CHN_STAT_CD,
  ch.DTL_CD_NM                     AS CHN_STAT_NM,
  s.FRST_REGIST_DT                 AS EFFECTIVE_FROM,
  LEAD(s.FRST_REGIST_DT) OVER (PARTITION BY s.MBER_NO ORDER BY s.SER_NO)               AS EFFECTIVE_TO,
  (LEAD(s.FRST_REGIST_DT) OVER (PARTITION BY s.MBER_NO ORDER BY s.SER_NO) IS NULL)     AS IS_CURRENT,
  'CRM'                            AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID
FROM (SELECT NULLIF(TRIM(MBER_NO),'') MBER_NO, SER_NO,
             NULLIF(TRIM(BF_STAT_CD),'') BF_STAT_CD, NULLIF(TRIM(CHN_STAT_CD),'') CHN_STAT_CD, FRST_REGIST_DT
      FROM {{ source('bronze_crm','TH_MM_FDRM_MBER_STNG_DTLS') }}
      WHERE MBER_NO IS NOT NULL AND SER_NO IS NOT NULL) s
LEFT JOIN {{ ref('CRM_CODE') }} bf ON bf.CD_ID='MM010' AND bf.DTL_CD_ID=s.BF_STAT_CD
LEFT JOIN {{ ref('CRM_CODE') }} ch ON ch.CD_ID='MM010' AND ch.DTL_CD_ID=s.CHN_STAT_CD
