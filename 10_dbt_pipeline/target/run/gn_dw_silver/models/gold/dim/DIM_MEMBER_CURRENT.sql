
  create or replace   view GN_DW.GOLD.DIM_MEMBER_CURRENT
  
   as (
    -- DIM_MEMBER_CURRENT: 회원 차원 현재행(SCD2 IS_CURRENT) 소비뷰 — 분석가 기본 진입점 (DEC-27 §17-A)
-- Co-authored with CoCo
--
-- 🔴 왜 필요한가 (실측 근거)
--   회원 FACT 4개(FMM·FME·FSE·FEP)가 전부 MEMBER_DK 로 조인하는데 DIM_MEMBER 는 SCD2다
--   — 회원 1명 = 평균 4.50행(최대 218 · 56.5%가 다버전). 순진한 조인은 **조용히** 팬아웃한다.
--   실측(202606 단월): FACT 734,521행 → join 후 2,645,714행(3.60배) · 납입회비 171.3억 → 507.5억(2.96배 과대).
--   에러도 경고도 없다. 그런데 GOLD 에는 비-WIDE 뷰가 0개여서 **안전한 기본값이 아예 없었다**.
--
-- ⚠️ 본 뷰는 DIM_MEMBER 의 **순수 투영**이다 — 파생·라벨 로직을 두지 않는다.
--   라벨 정의 단일 소유 = models/gold/dim/DIM_MEMBER.sql. 초판이 라벨 CASE 를 뷰에 중복
--   정의했다가 P33(정의 중복 → drift) 위반으로 제거했다.
--
-- ⚠️ 전건 NULL 7컬럼(REGION·AGE_BAND·NEW_EXISTING_FLAG·LAST_STOP_DATE·LAST_CAMPAIGN·
--   FIRST_SPONSORSHIP·CURRENT_SPONSORSHIP)은 **의도적으로 미노출** — 컬럼이 보이는데 항상 NULL 이면
--   분석가가 "값이 없다"로 오해하고 GROUP BY 한다(P15). 판정·근거 = 문서30 DEC-27 §17-C.
--
-- ⚠️ SERVING.DIM_MEMBER_CURRENT(SV 소비용, 02_SERVING_setup/08_After_Deploy 소관)와 동명이다.
--   양쪽 다 DIM_MEMBER 순수 투영이라 **값은 항상 일치**하나 컬럼 집합이 다르다
--   (SERVING 은 7여 포함·MEMBER_TYPE 미포함). SV 영향 점검 없이 통합하지 말 것.
--
-- ⚠️ GRANT 불요 — GOLD 스키마에 VIEW future grant(SELECT → ANALYST/VIEWER/SERVICE)가 이미 있어
--   매 build 시 자동 부여된다(실측 확인 2026-08-03).


select
    MEMBER_SK,
    MEMBER_DK,
    MEMBER_TYPE,
    SEX,
    SEX_NM,
    GENDER_NAME,
    MBER_STAT_CD,
    MEMBER_STATUS_NAME,
    MEMBER_STATUS_GROUP,
    MBER_DIV_CD,
    MEMBER_TYPE_NAME,
    JOIN_PATH_CD,
    ENROLL_PATH_NAME,
    FIRST_JOIN_DATE,
    FIRST_CAMPAIGN,
    EFFECTIVE_FROM,
    DW_SOURCE_SYSTEM,
    DW_LOAD_TS,
    DW_UPDATE_TS,
    DW_BATCH_ID
from GN_DW.GOLD.DIM_MEMBER
where IS_CURRENT
  );

