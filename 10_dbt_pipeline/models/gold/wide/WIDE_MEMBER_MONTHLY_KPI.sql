-- WIDE_MEMBER_MONTHLY_KPI: 회원 월 지표 **모집단 집계** 뷰(월 × 신규기존) — 공45·46·47 분모 「누계개발(건)」 전용
-- Co-authored with CoCo
-- 🆕 [2026-10-03 O201-D · 사용자 확정] 누계개발(건) = **당해년도 1월 ~ 조회월의 개발(건) 합계**
--   🔴 왜 회원 행이 아니라 모집단 집계인가 = FMM 스파인은 billing ∪ 사건 이라 sparse 하다 ⇒
--      회원별 누계를 조회월 행에 실으면 그 달 행이 없는 회원(연중 중단 등)의 개발이 빠진다
--      (O201-D 실측: 2025-12 회원행 누계 합 / 2025 연간 개발 합 = 81.20%) ⇒ 월 합계를 먼저 내고 연내 누적한다.
--   🔴 「개발(건)」 단위가 두 가지라 둘 다 싣는다(현업 확인 대기 · 요청서 41번):
--      · DEV_CUM_CNT     = 사건 수(FMM.DEV_CNT · 프로젝트 정본 「개발(건) = 사건 수」)
--      · DEV_CUM_AMT_CNT = 금액 ÷ 10,000(FME 개발구분 신규·증액·재후원 · 활동(건)과 같은 단위)
--      ⇒ 공45·46·47 은 분모·분자에 활동(건)(금액 ÷ 10,000)과 섞이므로 **DEV_CUM_AMT_CNT** 를 쓴다
--        (사건 수로 계산하면 공45 가 100% 를 넘는 달이 생긴다 · O201-D 실측).
--   🔴 이 뷰의 행은 회원이 아니다 — 회원 속성(성별·상태 등)으로 쪼개지 않는다.
with m as (
    select
        MONTH_KEY,
        FLOOR(MONTH_KEY / 100)                 as CAL_YEAR,
        NEW_EXISTING_FLAG,
        SUM(DEV_CNT)                           as DEV_CNT,
        SUM(ACTIVE_CNT)                        as ACTIVE_CNT,
        SUM(MONTH_END_ACTIVE_CNT)              as MONTH_END_ACTIVE_CNT,
        SUM(YEAR_START_ACTIVE_CNT)             as YEAR_START_ACTIVE_CNT,
        SUM(PREV_MONTH_END_ACTIVE_CNT)         as PREV_MONTH_END_ACTIVE_CNT,
        SUM(STOP_CNT)                          as STOP_CNT
    from {{ ref('FACT_MEMBER_MONTHLY') }}
    where MONTH_KEY > 0
    group by 1, 2, 3
),
d as (
    select
        FLOOR(DATE_SK / 100)                   as MONTH_KEY,
        NEW_EXISTING_FLAG,
        SUM(IFF(DVLP_DIV_CD in ('1', '2', '4'), SPNSR_AMT, 0)) / 10000 as DEV_AMT_CNT
    from {{ ref('FACT_MEMBER_EVENT') }}
    where EVENT_TYPE = 'DEV' and DATE_SK > 0
    group by 1, 2
)
select
    m.*,
    COALESCE(d.DEV_AMT_CNT, 0)                                                as DEV_AMT_CNT,
    SUM(m.DEV_CNT) over (partition by m.CAL_YEAR, m.NEW_EXISTING_FLAG order by m.MONTH_KEY
                         rows between unbounded preceding and current row)    as DEV_CUM_CNT,
    SUM(COALESCE(d.DEV_AMT_CNT, 0)) over (partition by m.CAL_YEAR, m.NEW_EXISTING_FLAG order by m.MONTH_KEY
                         rows between unbounded preceding and current row)    as DEV_CUM_AMT_CNT
from m
left join d
  on d.MONTH_KEY = m.MONTH_KEY
 and d.NEW_EXISTING_FLAG is not distinct from m.NEW_EXISTING_FLAG
