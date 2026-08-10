create or replace view GN_DW.GOLD.WIDE_TARGET_DEV
    (
      MONTH_KEY COMMENT $$목표월 YYYYMM$$,
      CAL_YEAR COMMENT $$FLOOR(MONTH_KEY/100) — 연도$$,
      CAL_MONTH COMMENT $$MOD(MONTH_KEY,100) — 월$$,
      DEV_TYPE COMMENT $$개발구분 (#121 conform)$$,
      GOAL_CNT COMMENT $$회원개발목표(건) (CRM TM_CM_MBER_DVLP_GOAL)$$,
      DW_SOURCE_SYSTEM COMMENT $$원천 시스템 식별$$,
      ORG_CORP COMMENT $$DIM_ORG.CORP — 법인 (#114). 🔴DIM_ORG 는 **SCD1**(DEC-2)이라 as-was 가 아니다 — 조직 개편 시 과거 사건에도 **현재 조직명**이 붙는다(조직 변경이력 원천·as-was 요구가 없어 SCD1 로 확정). 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.CORP`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.$$,
      ORG_DIVISION COMMENT $$DIM_ORG.DIVISION — 본부/지부 (#115). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.DIVISION`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.$$,
      ORG_DEPARTMENT COMMENT $$DIM_ORG.DEPARTMENT — 부서 (#116). 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴「부서」는 축이 둘이다 — 이 컬럼은 **사건 부서**이고 획득 부서는 DIM_MEMBER_ACQUISITION.ACQ_DEPARTMENT 다(O34).$$,
      ORG_TEAM COMMENT $$DIM_ORG.TEAM — 팀. 🔴SCD1(DEC-2) — current-value 이며 as-was 가 아니다. 🔴🔴[O51-F 실측] **전건 NULL** — 원인은 팩트가 아니라 **차원 컬럼 자체가 비어 있다**: `DIM_ORG.TEAM`. `DIM_ORG` 는 DEPARTMENT 만 채워져 있고 상위 계층 유도 규칙이 미확정이다(CONF-4). 실측 규모는 이슈원장 §O51-F.$$
    )
    comment = $$회원개발 목표 팩트(FTG_D) 평탄화 — ORG. 월 grain=MONTH_KEY. [2026-08-05 O38] MONTH_KEY 연도 복원으로 CAL_YEAR 가 유효해졌다(종전 1~12 라 FLOOR(MONTH_KEY/100)=0 전건). 목표 대비 실적은 `WIDE_DEV_ACHIEVEMENT` 소관이다. 🔴[O51-F 실측] 조직 상위 계층(ORG_CORP·ORG_DIVISION·ORG_TEAM)은 차원 자체가 비어 있어 **부서 단위까지만 분해된다**(CONF-4).$$
    as (
      -- WIDE_TARGET_DEV: 회원개발 목표 팩트(FTG_D) 평탄화 소비뷰 — ref() 거버넌스 (정본 09_빅테이블 VIEW.md §3.3)
-- Co-authored with CoCo
--
-- 🔬 [2026-08-07 O51-C probe] 본 모델만 커스텀 머티리얼라이제이션 `gn_view_commented` 를 쓴다.
--   변경 이유: 종전 post_hook 의 `ALTER VIEW ... ALTER COLUMN ... COMMENT` 는 **Snowflake 에 없는 문법**이라
--     15/16 뷰 build ERROR 를 냈고 컬럼 COMMENT 는 520컬럼 전량 0 이었다(O51 실측).
--   뷰 컬럼 COMMENT 의 유일 경로 = `CREATE VIEW` 인라인 컬럼목록 → 그 생성문을 매크로가 만든다.
--   · 컬럼 COMMENT 정본  = `_wide_schema.yml` 의 `columns[].description` (10개, SELECT 순서 일치)
--   · 뷰   COMMENT 정본  = `_wide_schema.yml` 의 `description` (매크로가 자동 적용 → post_hook 불요)
--   ⇒ post_hook 2개 **모두 제거**. 사본이 사라지고 정본이 yml 한 곳으로 모인다.
--   ⚠️ probe 통과(10/10) 시 나머지 뷰로 확대, 실패 시 되돌리고 B(테이블화) 판단.


select
    f.MONTH_KEY,
    FLOOR(f.MONTH_KEY / 100) as CAL_YEAR,
    MOD(f.MONTH_KEY, 100)    as CAL_MONTH,
    f.DEV_TYPE, f.GOAL_CNT, f.DW_SOURCE_SYSTEM,
    o.CORP as ORG_CORP, o.DIVISION as ORG_DIVISION,
    o.DEPARTMENT as ORG_DEPARTMENT, o.TEAM as ORG_TEAM
from GN_DW.GOLD.FACT_TARGET_DEV f
left join GN_DW.GOLD.DIM_ORG o on f.ORG_SK = o.ORG_SK
    );