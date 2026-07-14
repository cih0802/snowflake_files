
  
    

        create or replace transient table GN_DW.SILVER.CRM_SPONSOR_RELATION
         as
        (-- CRM_SPONSOR_RELATION: 결연(아동) 정제 + Q15 NO→ID 크로스워크 (BRONZE → SILVER), 정본 09 STEP3.
-- Co-authored with CoCo
-- 교차참조: SPNSR_BSNS_ID 는 CRM_MEMBER_SPONSOR_BIZ 에서 조인 채움(단방향 BRONZE→SILVER 예외 아님, SILVER dim 참조).
SELECT
  r.RELATNSP_KEY                     AS RELATNSP_KEY,
  NULLIF(TRIM(r.SPNSR_NO),'')        AS SPNSR_NO,
  r.SPNSR_BSNS_NO                    AS SPNSR_BSNS_NO,
  biz.SPNSR_BSNS_ID                  AS SPNSR_BSNS_ID,
  r.CHILD_CD                         AS CHILD_CD,
  NULLIF(TRIM(r.MBER_NO),'')         AS MBER_NO,
  r.RELATNSP_STRT_DE                 AS RELATNSP_STRT_DE,
  r.RELATNSP_DSCNTC_DE               AS RELATNSP_DSCNTC_DE,
  NULLIF(TRIM(r.RELATNSP_DSCNTC_YN),'') AS RELATNSP_DSCNTC_YN,
  'CRM'                              AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()                AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()                AS DW_UPDATE_TS,
  NULL                               AS DW_BATCH_ID
FROM GN_DW.BRONZE_CRM.TM_RM_RELATNSP_MSTR_INFO r
LEFT JOIN GN_DW.SILVER.CRM_MEMBER_SPONSOR_BIZ biz
  ON biz.SPNSR_NO = NULLIF(TRIM(r.SPNSR_NO),'') AND biz.SPNSR_BSNS_NO = r.SPNSR_BSNS_NO
WHERE r.RELATNSP_KEY IS NOT NULL
        );
      
  