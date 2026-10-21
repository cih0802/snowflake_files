-- CRM_BIZ_TARGET: FTG-B 사업목표 — 원천=CRM 확정(2026-07-20, 구 ERP_BIZ_TARGET).
-- Co-authored with CoCo
-- 단위=GOAL_TYPE_NM 에 따른다(건·명·원·비율 · O190). TARGET_TYPE(당초/추경)로 GOLD ANNUAL/SUPP 분기.
-- 🆕 [2026-09-29 O188] 입고 배선 — `BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV`(월 12컬럼) 를 월로 풀어 적재.
--   · grain = 원천 1행 × 월 · DK 유일 실측(규모는 이슈원장 · 이전 계정 수치 인용 금지).
--   · ~~TARGET_TYPE = '당초' 고정~~ ➔ O190: BDGT_PRCD_NM 파생(아래).
--   · ORG_NM = TEAM_NM · SPONSOR_BIZ_NM = SPNSR_BSNS_DIV_NM(이름 조인은 GOLD 소관).
--   · 🔴 GOAL_TYPE_NM 은 **이중계상·단위 혼합 가드** — O190 기준 9종(후원사업·회원개발 = 같은 개발 목표의 다른 분해).
--   · 원천 `-` 는 값이 아니다 ⇒ NULL(`R2-7-1`).
--   · 🔴 source 는 `bronze_crm_ref` — dev2 의 BRONZE_CRM_2 에 이 테이블이 없다.
-- 🔴 [2026-09-30] 원천 **완전중복 행**(전 컬럼 동일)을 `SELECT DISTINCT` 로 제거한다(BRONZE 통제 불가 · 사용자 결정).
--   · 실측 = 438행 → DISTINCT 437행 · 키 중복 0 (중복 1행 = 사복/지역사회/기타/지역개발 · 12개월 전부 0).
--   · 🔴 완전중복만 제거한다 — 키가 같고 값이 다른 충돌은 그대로 남아 unique 테스트(error)가 잡는다.
-- 🆕 [2026-09-30 O190] 원천 정의 갱신 — 2번째 컬럼 `BDGT_PRCD_NM`('예산절차') 신설.
--   · 실측(bt97381) = '연사업' 1종 438행 · ERP 같은 축 = 연사업/추가경정 ⇒ 편성 차수 축.
--   · TARGET_TYPE = 연사업→'당초' · 추가경정→'추경' · 그 외 원천값 그대로(창작 0) · NULL→'당초'(종전 고정값 호환).
--   · DK 해시에 포함 — 추경 행이 입고되면 같은 키로 충돌하기 때문이다(ERP FACT_BUDGET_YEARLY 결함과 같은 축).
--   🔴 [O190 발견] 이 계정의 GOAL_TYPE_NM 은 「연사업/팀」 2종이 아니라 **지표 9종**(후원사업·회원개발·월말활동회원·
--      정기회비·활동율/납입율 5종)이다 — 단위가 섞인다(건·명·원·비율). 처분 = 사용자 결정 대기(GOLD·SV 소관).
WITH src AS (
    SELECT DISTINCT * FROM {{ source('bronze_crm_ref', 'TM_CM_MBER_DVLP_GOAL_DIV') }}
),
u AS (
    SELECT
        YEAR, BDGT_PRCD_NM, GOAL_TYPE_NM, CPR_DIV_NM, NEW_OLD_DIV_NM, ORG_DIV_NM, TEAM_NM, SPNSR_BSNS_DIV_NM, DTL_DIV_NM,
        TRY_TO_NUMBER(SUBSTR(MONTH_COL, 2, 2)) AS MONTH_NO,
        GOAL_CNT
    FROM src
    UNPIVOT INCLUDE NULLS (GOAL_CNT FOR MONTH_COL IN (
        M01_GOAL_CNT, M02_GOAL_CNT, M03_GOAL_CNT, M04_GOAL_CNT, M05_GOAL_CNT, M06_GOAL_CNT,
        M07_GOAL_CNT, M08_GOAL_CNT, M09_GOAL_CNT, M10_GOAL_CNT, M11_GOAL_CNT, M12_GOAL_CNT))
)
SELECT
  MD5(CONCAT_WS('|', YEAR, GOAL_TYPE_NM, CPR_DIV_NM, COALESCE(NEW_OLD_DIV_NM, ''), COALESCE(ORG_DIV_NM, ''),
                COALESCE(TEAM_NM, ''), COALESCE(SPNSR_BSNS_DIV_NM, ''), COALESCE(DTL_DIV_NM, ''), MONTH_NO,
                COALESCE(BDGT_PRCD_NM, '')))
                               AS BIZ_TARGET_DK,
  CAST(TRY_TO_NUMBER(YEAR) AS NUMBER(4,0))                      AS TARGET_YEAR,
  CAST(MONTH_NO AS NUMBER(2,0))                                 AS MONTH_NO,
  CAST(YEAR || LPAD(MONTH_NO, 2, '0') AS VARCHAR(6))            AS MONTH_KEY,
  CAST(NULL AS VARCHAR)        AS ORG_CD,                        -- 원천에 조직코드 없음(팀명만)
  NULLIF(TRIM(TEAM_NM), '-')   AS ORG_NM,
  NULLIF(TRIM(SPNSR_BSNS_DIV_NM), '-') AS SPONSOR_BIZ_NM,
  CAST(NULL AS VARCHAR)        AS CAMPAIGN_NM,                   -- 원천에 캠페인 축 없음
  CAST(CASE NULLIF(TRIM(BDGT_PRCD_NM), '-')
         WHEN '연사업'   THEN '당초'
         WHEN '추가경정' THEN '추경'                                  -- GOLD FTP `LIKE '추경%'` → SUPP
         ELSE COALESCE(NULLIF(TRIM(BDGT_PRCD_NM), '-'), '당초') END AS VARCHAR) AS TARGET_TYPE,
  CAST(GOAL_CNT AS NUMBER(18,4)) AS TARGET_CNT,
  CAST('CRM' AS VARCHAR)       AS DW_SOURCE_SYSTEM,
  CAST('BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV' AS VARCHAR) AS DW_SOURCE_TABLE,
  CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_LOAD_TS,
  CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS DW_UPDATE_TS,
  CAST('{{ invocation_id }}' AS VARCHAR) AS DW_BATCH_ID,
  NULLIF(TRIM(GOAL_TYPE_NM), '-')   AS GOAL_TYPE_NM,
  NULLIF(TRIM(CPR_DIV_NM), '-')     AS CPR_DIV_NM,
  NULLIF(TRIM(NEW_OLD_DIV_NM), '-') AS NEW_OLD_DIV_NM,
  NULLIF(TRIM(ORG_DIV_NM), '-')     AS ORG_DIV_NM,
  NULLIF(TRIM(DTL_DIV_NM), '-')     AS DTL_DIV_NM,
  NULLIF(TRIM(BDGT_PRCD_NM), '-')   AS BDGT_PRCD_NM
FROM u
