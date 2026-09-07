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