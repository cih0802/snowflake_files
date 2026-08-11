-- CRM_EVENT_PARTICIPATION: 행사 참여 = EVENT ∪ CRMN 참여자 (PK dedup), 정본 09 STEP3.
-- Co-authored with CoCo
-- [2026-08-11 O59-N · DEC-35 1단계] 코드→라벨 계층화. 정본 = 문서30 §23-J · 매핑 = 문서31 §3.
--   🔴 두 원천의 코드체계가 완전 분리된다(겹침 0) ⇒ 판별자(EVENT_KEY 접두)로 갈라 **각자의 코드군**에 조인한다.
--     · PART_STATUS  : EVENT → `MS304`(등급 B · 12/12 정확 일치) / CRMN → `MS006`(등급 A+B)
--       ⚠️ `MS304` 사전 라벨은 **영문**이다(`Success`·`1_step_right`…). §23-J 결정 4 로 **그대로 적재**한다 —
--         한글 표기는 현업 회신 대기(문서20 §M-1). 창작 금지.
--       🔴 두 원천의 「참여」 정의가 다르다: EVENT 는 **다단계 통과 여부**, CRMN 은 신청/참여/불참/대기/취소.
--     · PART_PATH    : EVENT → `MS303`(등급 C) / CRMN → `MS004`(등급 C · 원천 컬럼명이 RQST_PATH_CD 다)
--       🔴 **조건부 적용**(§23-J 결정 2) — 문서20 §M-3 회신이 다르면 이 리터럴과 라벨을 되돌린다.
--     · PART_CHANNEL : EVENT → `MS302`(등급 B · 8/8 정확 일치) / CRMN 은 원천 컬럼 부재 → NULL
--   ⚠️ 오염값 `)`(O28)은 사전에 없으므로 라벨 NULL 로 떨어진다 — 정상 동작이다(라벨 부여 금지 · 문서31 §6).
--   ⚠️ fan-out 안전: 대상 그룹 (CD_ID, DTL_CD_ID) 전건 유일(실측 2026-08-11).
WITH base AS (
  SELECT 'EVENT_'||EVENT_CD          AS EVENT_KEY,
    NULLIF(TRIM(MBER_NO),'')         AS MBER_NO,
    PARTCPT_SEQ                      AS PARTCPT_SEQ,
    NULLIF(TRIM(PARTCPT_STAT_CD),'') AS PARTCPT_STAT_CD,
    NULLIF(TRIM(PARTCPT_CHNNL_CD),'')AS PARTCPT_CHNNL_CD,
    NULLIF(TRIM(PARTCPT_PATH_CD),'') AS PARTCPT_PATH_CD,
    PRZWIN_CD                        AS PRZWIN_CD,
    NULL                             AS RCPMNY_AMT,
    PARTCPT_DT                       AS PARTCPT_DT,
    'EVENT'                          AS EVENT_SOURCE,
    'CRM'                            AS DW_SOURCE_SYSTEM,
    'BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL' AS DW_SOURCE_TABLE
  FROM GN_DW.BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL WHERE NULLIF(TRIM(MBER_NO),'') IS NOT NULL AND PARTCPT_SEQ IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY EVENT_CD, MBER_NO, PARTCPT_SEQ ORDER BY PARTCPT_DT DESC NULLS LAST)=1
  UNION ALL
  SELECT 'CRMN_'||CRMN_CD, NULLIF(TRIM(MBER_NO),''), PRTCPNT_KEY, NULLIF(TRIM(PARTCPT_STAT_CD),''),
    NULL, NULLIF(TRIM(RQST_PATH_CD),''), NULL, RCPMNY_AMT, TRY_TO_TIMESTAMP(PARTCPT_DATE),
    'CRMN',
    'CRM','BRONZE_CRM.TD_MS_CRMN_PRTCPNT'
  FROM GN_DW.BRONZE_CRM.TD_MS_CRMN_PRTCPNT WHERE NULLIF(TRIM(MBER_NO),'') IS NOT NULL AND PRTCPNT_KEY IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY CRMN_CD, MBER_NO, PRTCPNT_KEY ORDER BY TRY_TO_TIMESTAMP(PARTCPT_DATE) DESC NULLS LAST)=1
)
SELECT
  b.EVENT_KEY                      AS EVENT_KEY,
  b.MBER_NO                        AS MBER_NO,
  b.PARTCPT_SEQ                    AS PARTCPT_SEQ,
  b.PARTCPT_STAT_CD                AS PARTCPT_STAT_CD,
  b.PARTCPT_CHNNL_CD               AS PARTCPT_CHNNL_CD,
  b.PARTCPT_PATH_CD                AS PARTCPT_PATH_CD,
  b.PRZWIN_CD                      AS PRZWIN_CD,
  b.RCPMNY_AMT                     AS RCPMNY_AMT,
  b.PARTCPT_DT                     AS PARTCPT_DT,
  b.DW_SOURCE_SYSTEM               AS DW_SOURCE_SYSTEM,
  b.DW_SOURCE_TABLE                AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()              AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()              AS DW_UPDATE_TS,
  NULL                             AS DW_BATCH_ID,
  -- 🔴 신설 컬럼 = 감사컬럼 뒤(정본 DDL 규약 · 물리 ordinal 이 ALTER 로 맨 끝이 된다).
  --    코드군 리터럴은 문서31 §3 이 사람이 확정한 매핑이다(DEC-17 방식 · 추론 아님).
  CASE WHEN b.PARTCPT_STAT_CD IS NULL THEN NULL
       WHEN b.EVENT_SOURCE='EVENT' THEN 'MS304' ELSE 'MS006' END        AS PARTCPT_STAT_GROUP,
  st.DTL_CD_NM                     AS PARTCPT_STAT_NM,
  CASE WHEN b.PARTCPT_CHNNL_CD IS NOT NULL AND b.EVENT_SOURCE='EVENT' THEN 'MS302' END AS PARTCPT_CHNNL_GROUP,
  ch.DTL_CD_NM                     AS PARTCPT_CHNNL_NM,
  CASE WHEN b.PARTCPT_PATH_CD IS NULL THEN NULL
       WHEN b.EVENT_SOURCE='EVENT' THEN 'MS303' ELSE 'MS004' END        AS PARTCPT_PATH_GROUP,
  pt.DTL_CD_NM                     AS PARTCPT_PATH_NM
FROM base b
LEFT JOIN GN_DW.SILVER.CRM_CODE st
  ON st.CD_ID = CASE WHEN b.EVENT_SOURCE='EVENT' THEN 'MS304' ELSE 'MS006' END
 AND st.DTL_CD_ID = b.PARTCPT_STAT_CD
LEFT JOIN GN_DW.SILVER.CRM_CODE ch
  ON ch.CD_ID = 'MS302' AND b.EVENT_SOURCE='EVENT' AND ch.DTL_CD_ID = b.PARTCPT_CHNNL_CD
LEFT JOIN GN_DW.SILVER.CRM_CODE pt
  ON pt.CD_ID = CASE WHEN b.EVENT_SOURCE='EVENT' THEN 'MS303' ELSE 'MS004' END
 AND pt.DTL_CD_ID = b.PARTCPT_PATH_CD