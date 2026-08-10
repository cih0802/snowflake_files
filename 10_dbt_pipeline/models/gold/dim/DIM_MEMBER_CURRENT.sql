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
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--
-- 🔴🔴 [2026-08-10 O53] **뷰 → 테이블 전환.** 위 O51-D 기술은 뷰 시절 것이며 아래로 갱신된다.
--   ① COMMENT 정본이 **`03_top-down_gold/06_DDL.sql` 인라인 COMMENT** 로 이동했다(사용자 결정).
--      schema.yml 의 `columns[]` 는 제거했다 — 같은 사실을 두 곳에 두면 갈라진다(P85).
--      재구축 시 06_DDL 이 replay 스크립트이므로 그 파일이 COMMENT 의 유일 복원 경로다.
--   ② 머티리얼라이제이션 = `incremental` + `append` + `pre_hook TRUNCATE`(구조·COMMENT 보존).
--      🔴 **merge 를 쓰면 안 된다**: 본 모델은 `IS_CURRENT` 필터라 회원의 현재행이 이동하면
--      merge 는 **구 현재행을 삭제하지 않는다** → 회원 1명이 2행이 되어 이 객체의 존재 이유인
--      팬아웃 차단이 무너진다. 근거 = `20_issue/50_dbt_파이프라인_미결조치.md` §300 R1(선례:
--      DIM_GA_EVENT 잔재) · `DIM_MEMBER` 가 같은 이유로 이미 이 패턴이다. 🆕 P131.
--   ③ 신규 4컬럼(REGION·AGE_BAND·FIRST_SPONSORSHIP·LAST_STOP_DATE) 노출 — 종전 미노출 근거
--      「전건 NULL 7컬럼」은 stale 이다(3컬럼은 DIM_MEMBER 에 부재 · 4컬럼은 채움 · DEC-28 §18-B 가 이미 정정).
--   🔴 SELECT 컬럼 추가·삭제·순서 변경 시 **06_DDL.sql 블록을 동시에 재생성**할 것
--      (생성기 `scripts/gen_o53_gold_ddl.py` · 손 편집 금지). 불일치는 append 단계에서 발화한다.
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook='TRUNCATE TABLE IF EXISTS {{ this }}',
    tags=['gold_ready']
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
    -- [2026-08-10 O53] 신규 4컬럼. 종전 미노출 근거였던 「전건 NULL」은 stale 이다(DEC-28 §18-B 가 이미 정정).
    --   ⚠️ 네 컬럼 전부 개발약정 시점 스냅샷이고 SCD2 축이며 일시회원(ONCE)에는 원천이 없다 — 상세는 06_DDL COMMENT.
    REGION,
    AGE_BAND,
    FIRST_SPONSORSHIP,
    LAST_STOP_DATE,
    EFFECTIVE_FROM,
    DW_SOURCE_SYSTEM,
    DW_LOAD_TS,
    DW_UPDATE_TS,
    DW_BATCH_ID
from {{ ref('DIM_MEMBER') }}
where IS_CURRENT
