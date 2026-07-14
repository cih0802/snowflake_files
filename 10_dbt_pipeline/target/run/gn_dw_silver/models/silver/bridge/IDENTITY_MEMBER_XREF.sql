
  
    

        create or replace transient table GN_DW.SILVER.IDENTITY_MEMBER_XREF
         as
        (-- IDENTITY_MEMBER_XREF: GA 신원↔CRM 회원 브리지 (교차소스 유일 예외), 정본 09 STEP7.
-- Co-authored with CoCo
-- 의존성(7-C): ref 로 GA4_IDENTITY·CRM_MEMBER 후행 강제. LEFT JOIN(UNMATCHED 보존, C1). CHILD_CODE 제외.

SELECT
    g.USER_PSEUDO_ID    AS USER_PSEUDO_ID,
    g.GA_MEMBER_ID      AS GA_MEMBER_ID,
    g.MEMBER_TYPE       AS MEMBER_TYPE,
    m.MEMBER_DK         AS MEMBER_DK,
    m.HMPG_ID           AS HOMEPAGE_ID,
    g.ID_RESOLUTION     AS ID_RESOLUTION,
    IFF(m.MEMBER_DK IS NOT NULL, 'MEMBER_ID_EXACT', 'UNMATCHED')  AS MATCH_METHOD,
    CASE WHEN m.MEMBER_DK IS NULL        THEN 'NONE'
         WHEN g.ID_RESOLUTION = 'DIRECT' THEN 'HIGH'
         ELSE 'MEDIUM' END                                       AS MATCH_CONFIDENCE,
    'GA4+CRM'                       AS DW_SOURCE_SYSTEM,
    'SILVER.GA4_IDENTITY+CRM_MEMBER' AS DW_SOURCE_TABLE,
    CURRENT_TIMESTAMP()             AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()             AS DW_UPDATE_TS,
    NULL                            AS DW_BATCH_ID
FROM GN_DW.SILVER.GA4_IDENTITY g
LEFT JOIN GN_DW.SILVER.CRM_MEMBER m
    ON g.GA_MEMBER_ID = m.MEMBER_DK
        );
      
  