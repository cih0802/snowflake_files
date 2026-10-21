-- CRM_PAYMENT_METHOD: 결제수단(현재상태, SETLE_KEY dedup) + 수단명(PM040) 라벨, 정본 09 STEP3.
-- Co-authored with CoCo
SELECT
  s.SETLE_KEY                      AS SETLE_KEY,
  NULLIF(TRIM(s.MBER_NO),'')       AS MBER_NO,
  NULLIF(TRIM(s.SETLE_CD),'')      AS SETLE_CD,
  pm.DTL_CD_NM                     AS SETLE_NM,
  NULLIF(TRIM(s.CARD_DIV_CD),'')   AS CARD_DIV_CD,
  NULLIF(TRIM(s.FNLT_CD),'')       AS FNLT_CD,
  s.WTDRW_STRT_DE                  AS WTDRW_STRT_DE,
  NULLIF(TRIM(s.SETLE_STAT_CD),'') AS SETLE_STAT_CD,
  -- [2026-08-03 G3] 정본 코드컬럼 raw 전파. 라벨은 수요 확인 후 별도 배선(스캐폴드 금지).
  NULLIF(TRIM(s.APPLCNT_MBER_REL_CD),'') AS APPLCNT_MBER_REL_CD,  -- CM009
  NULLIF(TRIM(s.CPR_DIV_CD),'')    AS CPR_DIV_CD,     -- CM019
  NULLIF(TRIM(s.CRTFC_MTH_CD),'')  AS CRTFC_MTH_CD,   -- MM014
  NULLIF(TRIM(s.FNLT_DIV_CD),'')   AS FNLT_DIV_CD,    -- PM050 (기관코드 원값은 FNLT_CD)
  NULLIF(TRIM(s.RCEPT_DIV_CD),'')  AS RCEPT_DIV_CD,   -- PM003
  NULLIF(TRIM(s.RQST_DIV_CD),'')   AS RQST_DIV_CD,    -- PM004
  'CRM'                            AS DW_SOURCE_SYSTEM,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID,
  -- 🆕 [2026-09-30 O191-E · 2차-B 2단] 누락 컬럼 13종(문서32 §3) — 🔴 개인정보(결제자명·연락처·카드유효기간·빌키·인증데이터) 제외
  s.WTDRW_ASMT_SQNC                      AS WTDRW_ASMT_SQNC,
  NULLIF(TRIM(s.SETLE_ENTRPS_CD),'')     AS SETLE_ENTRPS_CD,
  s.ACNUT_SER_NO                         AS ACNUT_SER_NO,
  NULLIF(TRIM(s.PAYER_MBER_REL_CD),'')   AS PAYER_MBER_REL_CD,
  NULLIF(TRIM(s.APRV_YN),'')             AS APRV_YN,
  s.FRST_BEGIN_DE                        AS FRST_BEGIN_DE,
  NULLIF(TRIM(s.RQEST_EXCL_YN),'')       AS RQEST_EXCL_YN,
  s.RQEST_EXCL_STRT_DE                   AS RQEST_EXCL_STRT_DE,
  s.RQEST_EXCL_END_DE                    AS RQEST_EXCL_END_DE,
  s.BF_SETLE_KEY                         AS BF_SETLE_KEY,
  NULLIF(TRIM(s.OPERT_DIV_CD),'')        AS OPERT_DIV_CD,
  NULLIF(TRIM(s.CRTFC_TY_CD),'')         AS CRTFC_TY_CD,
  NULLIF(TRIM(s.USE_YN),'')              AS USE_YN
FROM {{ source('bronze_crm','TM_PM_SETLE_INFO') }} s
LEFT JOIN {{ ref('CRM_CODE') }} pm ON pm.CD_ID='PM040' AND pm.DTL_CD_ID = NULLIF(TRIM(s.SETLE_CD),'')
WHERE s.SETLE_KEY IS NOT NULL
  -- 🔴 [2026-09-22 O179 · 이슈 B] 마스터 미실재 회원 제거 · 정의 = macros/gn_member_master_filter.sql
  --    📏 실측 = 고아 39행(회원 21명) / 2,589,005 ⇒ 적재 후 2,588,966행 예상.
  AND {{ gn_member_master_filter("NULLIF(TRIM(s.MBER_NO),'')") }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY s.SETLE_KEY ORDER BY s.WTDRW_STRT_DE DESC NULLS LAST)=1
