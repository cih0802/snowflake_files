-- FACT_DEV_ACHIEVEMENT: 회원개발 목표 대비 실적 (월 conform) — 구 GOLD.WIDE_DEV_ACHIEVEMENT [O53 개명·테이블화]
-- Co-authored with CoCo
--
-- ============================================================================
-- [2026-08-05 O38] 마케팅 장표 「1. 개발현황(목표, 실적)」 전용 소비뷰
-- ----------------------------------------------------------------------------
-- 왜 신설하는가: 목표(`FACT_TARGET_DEV`, 월 grain)와 실적(`FACT_MEMBER_EVENT`, 일 grain)이
--   서로 다른 팩트에 있어 달성율 계열 지표(정본 공#1·#2·#3)를 산출할 파생이 없었다.
--   `SEMANTIC_VIEW()` 는 단일 뷰 대상이고 SV metric 식은 자기 logical table 컬럼만 참조 가능하므로
--   (순서9-J 실측) 팩트 경계를 넘는 비율은 **pre-join helper 계층**이 필요하다.
--
-- 선행 조건 2건이 이번 세션에 해소됐다:
--   ① `FACT_TARGET_DEV.MONTH_KEY` 연도 복원(O38) — 종전 1~12 라 연도 conform 자체가 불가능했다
--   ② `FACT_MEMBER_EVENT.ORG_SK` 배선(O38/O10) — 종전 전건 센티넬이라 부서 축이 없었다
--
-- grain = `MONTH_KEY × ORG_SK × DEV_TYPE`. 목표 팩트의 grain 을 그대로 쓴다.
--   실적을 이 grain 으로 롤업해 맞춘다(일→월). conform 성립 근거(실측 2026-08-05):
--     · `DEV_TYPE` 목표 도메인 {1,2,4} = 정본 공#121 개발구분(신규·증액·재후원)과 **정확히 일치**
--       → `DEV_CNT` 의 모집단과 목표의 모집단이 같다(P18/P63 분모·분자 모집단 일치 요건 충족)
--     · 목표 조직 234종 **⊆** 실적 조직 349종 · 목표에만 있는 조직 **0**
--
-- 🔴 FULL OUTER JOIN 을 쓴다. 한쪽만 있는 월×부서×구분이 양방향으로 존재한다 —
--   목표는 미래월(202612)까지 편성돼 있고, 실적은 목표 편성 이전 기간(2012 이전)에도 있다.
--   INNER 로 묶으면 목표 미달 부서가 **집계에서 조용히 사라져** 달성율이 과대해진다.
--
-- 🔴 비율(달성율) 컬럼은 이 뷰에 두지 않는다 — WIDE 계층 선례(`WIDE_BUDGET` 이 집행율을
--   두지 않고 `SV_BUDGET` 이 산출)를 따른다. 이유는 편의가 아니라 정확성이다:
--   행 단위 비율을 저장하면 상위 집계에서 **비율의 평균**을 내게 되고 이는 항상 틀린다.
--   달성율은 반드시 `SUM(실적) / SUM(목표)` 로 재계산해야 한다 → SV metric 소관.
--
-- 🔴 일별 실적은 이 뷰에 담지 않는다. 월 목표를 일자에 반복 배치하면 일수만큼 목표가
--   부풀어 이중계상된다. 장표의 「일별 실적」축은 `WIDE_MEMBER_EVENT`(일 grain, 부서 축
--   O38 로 활성화됨)에서 조회하고, 목표 대비 비교는 월 단위인 이 뷰에서 한다.
--
-- ⚠️ 누계(YTD)·연 컬럼은 **월에 대해 비가산(semi-additive)** 이다.
--   조직·구분 축으로는 더해도 되지만 **월을 가로질러 더하면 안 된다**(같은 값이 반복 누적된다).
--   특정 월 하나를 골라 읽는 컬럼이다.
--
-- ============================================================================
-- 🔴 [2026-08-05 O38-D 후속] 목표값의 성격 — 「목표 행이 있다」 ≠ 「목표가 편성됐다」
-- ----------------------------------------------------------------------------
-- BRONZE `TM_CM_MBER_DVLP_GOAL` 을 재스캔해 확인한 사실이다(COMMENT 를 믿지 않고 원본을 봤다):
--   · `GOAL_CNT` 는 **0 인 행이 과반**이다. NULL 인 행도 소수 존재한다.
--   · 원인은 결측이 아니라 **원천의 행 생성 방식**이다 — 2020년부터 CRM 이
--     `부서 × 월 × 개발구분 3코드` 조합을 **전량 행으로 만들고 미편성분을 0 으로 채운다**
--     (2019년까지는 신규 코드만 sparse 하게 있었다. 2021년만 예외적으로 축소됐다).
--   · 그 결과 **개발목표는 사실상 「신규」에만 편성**된다. 증액·재후원은 15년 중
--     극소수 연도에만 소액 편성됐고 나머지는 전부 0 이다(O38-D 현업 확인 대기).
--
-- 🔴 **이것이 컬럼 설계를 규정한다.** 최초 판본은 플래그가 `HAS_GOAL`(목표 행 존재) 하나였고
--   내가 그것을 「목표 편성 여부」로 읽어 SV 달성율 분자에 썼다 → 목표 0 행의 실적이
--   분모 없이 분자에 들어가 **증액 537% · 재후원 1700%** 가 배포됐다.
--   → ① 이름을 `HAS_GOAL_ROW` 로 **개명**했다(COMMENT 만 고치면 이름이 계속 오해를 부른다)
--     ② 달성율 스코프 전용으로 **`HAS_POSITIVE_GOAL` 을 병설**했다
--     ③ 달성율은 `SV_DEV_ACHIEVEMENT.ACHIEVEMENT_RATE` 가 `GOAL_CNT > 0` 을 식에 못박아 둔다
--
-- ⚠️ **`GOAL_CNT` 의 `COALESCE(...,0)` 는 두 가지를 하나로 만든다** — FULL OUTER 미매칭(목표 행 없음)과
--   원천 `GOAL_CNT` NULL(목표 미입력)이 모두 0 이 된다. 전자는 `HAS_GOAL_ROW=FALSE` 로 구분되지만
--   후자는 「명시적 0」과 섞인다. 규모가 극소수이고 **달성율 산술 결과는 동일**하므로(0 과 NULL 모두
--   분모 기여 0) 별도 컬럼을 만들지 않았다 — 구분이 필요하면 `FACT_TARGET_DEV.GOAL_CNT IS NULL`
--   로 팩트에서 직접 본다(팩트는 NULL 을 보존한다). 창작하지 않고 경로를 남긴다(P21).
-- ============================================================================
--
-- ⚠️ `CAL_YEAR` 는 `FLOOR(MONTH_KEY/100)` 산술이다(DIM_DATE 조인 아님).
--   O38 이전에는 `MONTH_KEY` 가 1~12 였기 때문에 이 산술이 **전건 0** 을 만들었다 —
--   센티넬로 오해하기 쉬우나 조인 실패가 아니라 자릿수 부족이었다. 연도 복원으로 해소된다.
-- ============================================================================
-- 🔧 [2026-08-07 O51-B] 깨진 `ALTER VIEW ... ALTER COLUMN ... COMMENT` post_hook 제거.
--   Snowflake 에 없는 문법이라 이 모델이 build ERROR 를 냈고 컬럼 COMMENT 는 0 이었다(실측).
--   ✅ [2026-08-07 O51-D] 복구 완료 — materialized='gn_view_commented' 전환 + yml columns[] 전량 등재.
--     · 컬럼 COMMENT 정본 = schema.yml `columns[].description` (SELECT 전 컬럼·순서 일치 필수)
--     · 뷰   COMMENT 정본 = schema.yml `description` (매크로가 자동 적용) ⇒ post_hook **전량 제거**.
--     🔴 SELECT 컬럼 추가·삭제·순서 변경 시 yml columns[] 를 **동시에** 재생성할 것 — 불일치는 build ERROR 다.
-- 🔴🔴 [2026-08-10 O53] **개명 + 뷰 → 테이블 전환.**
--   ① 구명 = GOLD.WIDE_DEV_ACHIEVEMENT(뷰). 이 객체는 팩트 2종을 FULL OUTER 로 **재구성**하므로
--      소비 평탄화(WIDE_)가 아니라 팩트(FACT_)다 — 이름과 실질을 맞췄다.
--   ② 컬럼 COMMENT 정본이 `03_top-down_gold/06_DDL.sql` 인라인 COMMENT 로 이동했다(사용자 결정).
--      `_wide_schema.yml` 의 columns[] 19건은 제거하고 `_gold_ready_schema.yml` 로 모델 항목만 옮겼다.
--   ③ 머티리얼라이제이션 = fact 폴더 기본값 상속(`incremental` + `append` + `pre_hook TRUNCATE`).
--   ④ 감사컬럼 4종 신설(GOLD 테이블 전수 관례) · PK(정보성) = MONTH_KEY·ORG_SK·DEV_TYPE(grain 유일 실측).
--   🔴 **SV_DEV_ACHIEVEMENT 의 base 가 이 객체다** — 개명으로 구 이름이 사라지므로 그 SV 는
--      `CREATE OR ALTER SEMANTIC VIEW` 로 재배선해야 한다(O53 6단계 · GRANT 는 소비 역할로 판정 · P125·P126).


-- 목표: 이미 MONTH_KEY × ORG_SK × DEV_TYPE grain(O38 연도 복원 후 25,344행 유일 예상).
with goal as (
    select MONTH_KEY, ORG_SK, DEV_TYPE, SUM(GOAL_CNT) as GOAL_CNT
    from GN_DW.GOLD.FACT_TARGET_DEV
    group by MONTH_KEY, ORG_SK, DEV_TYPE
),

-- 실적: 일 grain 을 월로 롤업. 개발(DEV) 사건만 대상이다.
--   🔴 `DVLP_DIV_CD in ('1','2','4')` 필터는 **중복 필터가 아니라 grain 정의**다 — 이 컬럼이
--      group by 키이므로, 필터하지 않으면 감액(3)·후원중단(5) 코드가 `ACTUAL_CNT=0` 인
--      잉여 행으로 남아 목표 도메인 {1,2,4} 과 grain 이 어긋난다.
--      값 자체는 `DEV_CNT` 가 이미 코드 1·2·4 한정이므로(O24 교정) 어느 쪽이든 동일하다.
--   ⚠️ 월키는 사건일(`JOIN_DATE` = 원천 `OCCRRNC_DE`)에서 뽑는다. `DATE_SK` 는 캘린더 범위밖을
--      0 센티넬로 라우팅하므로 월 파생에 쓰면 0월이 생긴다.
--      범위밖 사건일은 목표가 없는 월키가 되어 `HAS_GOAL_ROW=FALSE` 로 분리된다(은폐되지 않는다).
actual as (
    select
        TRY_TO_NUMBER(TO_CHAR(f.JOIN_DATE, 'YYYYMM'))  as MONTH_KEY,
        f.ORG_SK                        as ORG_SK,
        f.DVLP_DIV_CD                   as DEV_TYPE,
        SUM(f.DEV_CNT)                  as ACTUAL_CNT
    from GN_DW.GOLD.FACT_MEMBER_EVENT f
    where f.EVENT_TYPE = 'DEV'
      and f.JOIN_DATE is not null
      and f.DVLP_DIV_CD in ('1', '2', '4')
    group by 1, 2, 3
),

-- 🔴 FULL OUTER — 목표만/실적만 있는 조합이 양방향으로 실재한다.
joined as (
    select
        COALESCE(g.MONTH_KEY, a.MONTH_KEY) as MONTH_KEY,
        COALESCE(g.ORG_SK,    a.ORG_SK)    as ORG_SK,
        COALESCE(g.DEV_TYPE,  a.DEV_TYPE)  as DEV_TYPE,
        COALESCE(g.GOAL_CNT,   0)          as GOAL_CNT,
        COALESCE(a.ACTUAL_CNT, 0)          as ACTUAL_CNT,
        -- 🔴 `HAS_GOAL_ROW` = 목표 **행**의 존재(값이 0·NULL 이어도 TRUE). 달성율 스코프 아님.
        g.MONTH_KEY is not null            as HAS_GOAL_ROW,
        -- 🟢 `HAS_POSITIVE_GOAL` = 실제로 목표가 편성됨. **달성율 스코프의 정본**이다.
        COALESCE(g.GOAL_CNT, 0) > 0        as HAS_POSITIVE_GOAL,
        a.MONTH_KEY is not null            as HAS_ACTUAL
    from goal g
    full outer join actual a
        on  g.MONTH_KEY = a.MONTH_KEY
        and g.ORG_SK    = a.ORG_SK
        and g.DEV_TYPE  = a.DEV_TYPE
),

-- 누계·연 파생. 정본 공#2(누계 목표 달성율)·#3(연 목표 달성율)의 분자·분모 입력이다.
--   연 목표를 별도 컬럼으로 입고받을 필요가 없다 — 월 목표의 연 합계가 정의 그대로다.
cumulated as (
    select
        j.*,
        FLOOR(j.MONTH_KEY / 100) as CAL_YEAR,
        MOD(j.MONTH_KEY, 100)    as CAL_MONTH,
        SUM(j.GOAL_CNT)   over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE
                                order by j.MONTH_KEY
                                rows between unbounded preceding and current row) as GOAL_CNT_YTD,
        SUM(j.ACTUAL_CNT) over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE
                                order by j.MONTH_KEY
                                rows between unbounded preceding and current row) as ACTUAL_CNT_YTD,
        SUM(j.GOAL_CNT)   over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE) as GOAL_CNT_YEAR,
        SUM(j.ACTUAL_CNT) over (partition by FLOOR(j.MONTH_KEY/100), j.ORG_SK, j.DEV_TYPE) as ACTUAL_CNT_YEAR
    from joined j
)

-- 개발구분 라벨은 사전(MM015)에서 가져온다. 하드코딩 CASE 금지(P31 — 사전과 조용히 갈라진다).
--   `DTL_CD_ID` 유일이라 fan-out 없음. USE_YN 무필터(폐지코드가 실적재에 남아 필터 시 라벨 소실).
select
    c.MONTH_KEY, c.CAL_YEAR, c.CAL_MONTH,
    c.ORG_SK,
    o.DEPARTMENT as ORG_DEPARTMENT,
    o.DIVISION   as ORG_DIVISION,
    o.TEAM       as ORG_TEAM,
    o.CORP       as ORG_CORP,
    c.DEV_TYPE,
    cd.DTL_CD_NM as DEV_TYPE_NAME,
    c.GOAL_CNT, c.ACTUAL_CNT,
    c.GOAL_CNT_YTD, c.ACTUAL_CNT_YTD,
    c.GOAL_CNT_YEAR, c.ACTUAL_CNT_YEAR,
    c.HAS_GOAL_ROW, c.HAS_POSITIVE_GOAL, c.HAS_ACTUAL,
    -- [O53] 감사컬럼 — GOLD 테이블 전수 관례. 목표(CRM)·실적(CRM) 양쪽 다 CRM 계통이다.
    'CRM'                       AS DW_SOURCE_SYSTEM,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_LOAD_TS,
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ       AS DW_UPDATE_TS,
    '5480bee1-eeb7-40d8-9796-8ba5b55af8b6'                    AS DW_BATCH_ID
from cumulated c
left join GN_DW.GOLD.DIM_ORG o on c.ORG_SK = o.ORG_SK
left join (
    select DTL_CD_ID, DTL_CD_NM from GN_DW.SILVER.CRM_CODE where CD_ID = 'MM015'
) cd on c.DEV_TYPE = cd.DTL_CD_ID