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
--   ① 본 게이트는 **실행 검증 전**이었다(작성 시점에 `dbt build` 미실행 · 계정/순서 제약).
--   ② O42 의 교훈: 해소 경로를 확인하지 않은 하드 게이트는 파이프라인을 세운다.
--      `on_schema_change: fail` 이 타입 오탐으로 팩트 10종 ERROR·145 SKIP 을 냈고 교착이 됐다.
--   ③ 프로젝트 선례(순서9-C): 「알려진 미완전은 warn 관측 → 실측 후 error 승격」.
--
-- 🔴🔴 [2026-08-10 O53] **자동 승격 지시를 철회한다 — warn 을 유지한다(사용자 결정).**
--   종전 이 자리에는 *"첫 clean build 에서 WARN=0 이면 즉시 `severity='error'` 로 올리고
--   파일명을 `assert_` 접두로 바꿀 것"* 이라고 적혀 있었다. 그 트리거는 **이미 충족됐다** —
--   O51-F 완료 시점 실측 GOLD 뷰 컬럼 COMMENT 커버리지 = **전건 보유(위반 0)**.
--   그런데 사용자 결정(2026-08-10 · O51-F)은 **warn 유지**다. 근거:
--     · BRONZE 원천이 증량될 예정이고(문서40 CMP-1 캠페인 상위코드·공통코드 신설 예고),
--       새 뷰·새 컬럼이 들어오는 순간 error 게이트는 **파이프라인 전체를 세운다**.
--     · 문안 누락은 소비 품질 문제이지 구조 불변식 위반이 아니다 — error 는 구조 불변식만(순서9-C 방침).
--   ⇒ 🔴 **헤더의 지시와 사용자 결정이 어긋난 상태로 두지 않는다**(🆕 P130): 방치하면 다음 세션이
--      헤더를 따라 승격시키고, 원천 증량 첫날 build 가 선다. 승격은 **사용자가 명시적으로 지시할 때만** 한다.
--   ⚠️ 대신 warn 이 거짓 안전 신호가 되지 않도록(P16) **분모를 매 세션 실측**할 것 —
--      「위반 0」이 공집합 통과가 아님을 확인하는 유일한 방법이다(P106).

-- 의존성 고정: INFORMATION_SCHEMA 를 직접 읽으므로 ref() 가 없으면 dbt 가 순서를 모른다.
--   뷰 생성 이후에 실행되도록 GOLD view 모델 **14종 전량**을 depends_on 으로 묶는다.
--   ⚠️ 새 GOLD 뷰 모델을 추가하면 아래 목록에도 넣을 것(누락 시 그 뷰가 만들어지기 전에 검사할 수 있다).
--   🔴 [2026-08-10 O53] 3건 제거 + 1건 추가 = 16 → 14.
--      · 제거: `WIDE_DEV_ACHIEVEMENT`(→ FACT_DEV_ACHIEVEMENT 테이블 개명) ·
--              `DIM_MEMBER_CURRENT`·`DIM_MEMBER_ACQUISITION`(뷰→테이블 전환)
--        ⇒ 세 객체는 이제 **테이블**이라 본 게이트의 대상(INFORMATION_SCHEMA.VIEWS)에서 빠진다.
--          그 COMMENT 는 `06_DDL.sql` 이 소유하며 커버리지는 O53 2단계 스캔으로 판정했다.
--      · 추가: `WIDE_AD_COMBINED`(신설 · SV_AD 새 base)
--      ⚠️ 이 목록을 안 고치면 `dbt parse` 가 「존재하지 않는 노드」 **경고만** 내고 통과한다 —
--         경고는 게이트가 아니다(P105). O53 에서 실제로 이 경고로 잡았다.
-- depends_on: {{ ref('WIDE_MEMBER_MONTHLY') }}
-- depends_on: {{ ref('WIDE_MEMBER_EVENT') }}
-- depends_on: {{ ref('WIDE_MEMBER_FEE') }}
-- depends_on: {{ ref('WIDE_TARGET_DEV') }}
-- depends_on: {{ ref('WIDE_TARGET_BIZ') }}
-- depends_on: {{ ref('WIDE_SERVICE_EVENT') }}
-- depends_on: {{ ref('WIDE_GA_BEHAVIOR') }}
-- depends_on: {{ ref('WIDE_AD_PERFORMANCE') }}
-- depends_on: {{ ref('WIDE_AD_BROADCAST') }}
-- depends_on: {{ ref('WIDE_AD_DIGITAL') }}
-- depends_on: {{ ref('WIDE_AD_BROADCAST_CASE') }}
-- depends_on: {{ ref('WIDE_AD_COMBINED') }}
-- depends_on: {{ ref('WIDE_EVENT_PARTICIPATION') }}
-- depends_on: {{ ref('WIDE_BUDGET') }}
{{ config(severity='warn') }}


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
