-- [2026-08-07 O50] GOLD 뷰 COMMENT 커버리지 게이트 — 뷰레벨·컬럼레벨 누락 감시.
-- Co-authored with CoCo
--
-- 무엇을 지키는가: `GN_DW.GOLD` 의 **모든 뷰**가 뷰 COMMENT 를 갖고, 그 뷰의 **모든 컬럼**이
--   컬럼 COMMENT 를 가져야 한다. 뷰·컬럼 COMMENT 는 Semantic View 의 `description` 으로
--   1:1 매핑되어 **Cortex Analyst 의 프롬프트 context 로 소비**된다(순서9-K (2) 실측).
--   즉 COMMENT 누락은 문서 흠결이 아니라 **소비 계층의 오답 경로**다 — 축의 의미를 모르는
--   Analyst 는 0행이나 잘못된 필터를 **에러 없이** 만든다(AD-4·P19 유형 = 무증상 오답).
--
-- 왜 이 테스트가 필요한가(실측 경위 · O50 → **O51 재정정**):
--   O50 당시 COMMENT 정본이 세 곳에 손으로 복제돼 있다고 보고 사본 커버리지를 셌다 —
--   `09`(12/16) · `10_...sql`(13/16) · dbt post_hook(16/16). **그 진단이 틀렸다.**
--   ⚠️ 사본 개수는 **파일에 문장이 있는지**만 세는 값이고 **효과를 세지 않는다**(P33 위반).
--   실측(2026-08-07): GOLD 뷰 **520컬럼 중 COMMENT 보유 0개(0.0%)** — 즉 **세 사본이 전부 0 을 반영**했다.
--   진짜 원인은 drift 가 아니라 **메커니즘 부재**였다: `ALTER VIEW ... ALTER COLUMN ... COMMENT` 는
--   Snowflake 에 없는 문법이고(4변형 전부 실패) 그 post_hook 이 15/16 뷰 build ERROR 를 냈다.
--   ⇒ 유일 경로 = `CREATE VIEW` 인라인 컬럼목록 → `macros/gn_view_commented.sql`.
--
--   🔴 이 테스트 자신에 대한 교훈: 최초 작성 시 실행해 **0행 PASS** 를 받고 "검증됨"으로 취급했으나,
--      그 시점 GOLD 뷰가 **0개**여서 **공집합 통과(vacuous pass)** 였다. 게이트를 무의미한 조건에서
--      돌려놓고 안심한 것이다 ⇒ **게이트는 「대상이 존재하는 상태」에서 돌려야 검증이다**(신규 교훈 P106).
--      현재는 실질 동작 확인됨: probe 후 WARN 15 → **14**(WIDE_TARGET_DEV 만 해소)로 감소.
--
-- 위반 조건: 뷰 COMMENT 가 비었거나, 컬럼 COMMENT 가 하나라도 빈 GOLD 뷰가 존재.
-- 판정: 0행이면 PASS.
--
-- 🟠 severity=warn 으로 시작한다(의도된 잠정) — 근거:
--   ① 본 게이트는 **실행 검증 전**이다(작성 시점에 `dbt build` 미실행 · 계정/순서 제약).
--   ② O42 의 교훈: 해소 경로를 확인하지 않은 하드 게이트는 파이프라인을 세운다.
--      `on_schema_change: fail` 이 타입 오탐으로 팩트 10종 ERROR·145 SKIP 을 냈고 교착이 됐다.
--   ③ 프로젝트 선례(순서9-C): 「알려진 미완전은 warn 관측 → 실측 후 error 승격」.
--   ⛔ **승격 트리거**: 첫 clean `dbt build` 에서 본 테스트 WARN=0 이 확인되면 즉시
--      `severity='error'` 로 올리고 파일명을 `assert_` 접두로 바꿀 것. WARN>0 이면 누락 컬럼을
--      해당 모델 post_hook 의 `ALTER VIEW ... ALTER COLUMN` 에 추가한 뒤 승격한다.
--      ⚠️ warn 으로 방치하면 이 파일 자체가 거짓 안전 신호가 된다(P16 — 미탐보다 오탐이 위험).


-- 의존성 고정: INFORMATION_SCHEMA 를 직접 읽으므로 ref() 가 없으면 dbt 가 순서를 모른다.
--   뷰 생성·post_hook 이후에 실행되도록 GOLD view 모델 16종 전량을 depends_on 으로 묶는다.
--   ⚠️ 새 GOLD 뷰 모델을 추가하면 아래 목록에도 넣을 것(누락 시 그 뷰가 만들어지기 전에 검사할 수 있다).
-- depends_on: GN_DW.GOLD.WIDE_MEMBER_MONTHLY
-- depends_on: GN_DW.GOLD.WIDE_MEMBER_EVENT
-- depends_on: GN_DW.GOLD.WIDE_MEMBER_FEE
-- depends_on: GN_DW.GOLD.WIDE_TARGET_DEV
-- depends_on: GN_DW.GOLD.WIDE_DEV_ACHIEVEMENT
-- depends_on: GN_DW.GOLD.WIDE_TARGET_BIZ
-- depends_on: GN_DW.GOLD.WIDE_SERVICE_EVENT
-- depends_on: GN_DW.GOLD.WIDE_GA_BEHAVIOR
-- depends_on: GN_DW.GOLD.WIDE_AD_PERFORMANCE
-- depends_on: GN_DW.GOLD.WIDE_AD_BROADCAST
-- depends_on: GN_DW.GOLD.WIDE_AD_DIGITAL
-- depends_on: GN_DW.GOLD.WIDE_AD_BROADCAST_CASE
-- depends_on: GN_DW.GOLD.WIDE_EVENT_PARTICIPATION
-- depends_on: GN_DW.GOLD.WIDE_BUDGET
-- depends_on: GN_DW.GOLD.DIM_MEMBER_CURRENT
-- depends_on: GN_DW.GOLD.DIM_MEMBER_ACQUISITION

with gold_views as (
    select TABLE_SCHEMA, TABLE_NAME, COMMENT as VIEW_COMMENT
    from GN_DW.INFORMATION_SCHEMA.VIEWS
    where TABLE_SCHEMA = 'GOLD'
),
col_cov as (
    select
        c.TABLE_NAME,
        COUNT(*)                                                          as COLS,
        COUNT_IF(c.COMMENT is null or TRIM(c.COMMENT) = '')               as COLS_NO_COMMENT
    from GN_DW.INFORMATION_SCHEMA.COLUMNS c
    join gold_views v
      on v.TABLE_SCHEMA = c.TABLE_SCHEMA and v.TABLE_NAME = c.TABLE_NAME
    group by c.TABLE_NAME
)
select
    v.TABLE_NAME,
    case when v.VIEW_COMMENT is null or TRIM(v.VIEW_COMMENT) = ''
         then 'MISSING' else 'OK' end                                     as VIEW_COMMENT_STATUS,
    COALESCE(c.COLS, 0)                                                   as COLS,
    COALESCE(c.COLS_NO_COMMENT, 0)                                        as COLS_NO_COMMENT
from gold_views v
left join col_cov c on c.TABLE_NAME = v.TABLE_NAME
where v.VIEW_COMMENT is null
   or TRIM(v.VIEW_COMMENT) = ''
   or COALESCE(c.COLS_NO_COMMENT, 0) > 0
order by COLS_NO_COMMENT desc, v.TABLE_NAME