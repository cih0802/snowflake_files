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
{{ config(
    materialized='view',
    post_hook=[
      "COMMENT ON VIEW {{ this }} IS '🟢 GOLD 직접조회 분석가의 기본 진입점 — 회원 1명 = 1행. DIM_MEMBER 는 SCD2(평균 4.50버전·최대 218)이므로 FACT 와 MEMBER_DK 직접 조인 시 팬아웃한다(실측 202606 단월 3.60배 · 납입회비 2.96배 과대). 과거 시점 상태가 필요할 때만 DIM_MEMBER 를 EFFECTIVE_FROM/EFFECTIVE_TO 로 시점조인할 것 — 예측·피처 생성은 이 시점조인이 정답이며 현재값을 과거 행에 붙이면 정답 누설이다. 🔴 상태 기반 분포·이탈률·예측 모집단은 MEMBER_TYPE=''FDRM'' 으로 한정할 것(일시회원 ONCE 는 회원상태·가입경로 개념이 원천에 없다). 본 뷰는 순수 투영이며 라벨 정의는 DIM_MEMBER.sql 단일 소유. 전건 NULL 7컬럼은 오답 방지를 위해 미노출(문서30 DEC-27 §17-C).'",
      "ALTER VIEW {{ this }} ALTER COLUMN MEMBER_DK COMMENT '불변 회원키(조인용). 이 뷰에서 유일(1행/회원) — FACT 와 안전하게 조인 가능', COLUMN MEMBER_TYPE COMMENT '회원 등록계통 — FDRM=정기(1,587,343) / ONCE=일시(175,722). 🔴 일시회원은 회원상태(MM010)·가입경로(MM014) 개념이 원천에 없다 → 상태 기반 모집단은 FDRM 한정. ⚠️MEMBER_TYPE_NAME(개인/기업/단체 MM018)은 이 컬럼의 라벨이 아니다(다른 축·코드는 MBER_DIV_CD)', COLUMN MEMBER_STATUS_NAME COMMENT '회원상태 라벨(MM010). ''(해당없음)''=일시회원(개념 부재) · NULL=정기회원 중 결측. 종전 ''미상'' 175,723 교정분. ⚠️개발구분(MM015)은 다른 축 — FACT_MEMBER_EVENT.DVLP_DIV_NM', COLUMN GENDER_NAME COMMENT '성별 분석 라벨 — 정본 공#130 5종(CM017). NULL=SEX 미기재 421명', COLUMN EFFECTIVE_FROM COMMENT '현재 상태의 진입일. ⚠️1900-01-01 은 이력 부재 센티넬'"
    ]
) }}

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
from {{ ref('DIM_MEMBER') }}
where IS_CURRENT
