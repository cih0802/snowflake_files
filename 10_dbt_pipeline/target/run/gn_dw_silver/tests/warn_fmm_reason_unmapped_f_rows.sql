select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      -- W3 회귀 방어: 미납(F) 행 중 코드그룹 매핑 실패로 REASON_SK=0이 된 비율 감시.
-- Co-authored with CoCo
-- 정상 범위: ~137,778건 (PAY_STAT_CD=NULL 수기처리 or SETLE_CD 미매핑). 이는 기대 gap.
-- 경보 조건: 미납 행(UNPAID_FLAG_EOM=TRUE AND HAS_BILLING=TRUE) 중 REASON_SK=0 비율이 5% 초과 시 warn.
--   현 baseline = 137,811 / 3,302,535 = 4.17%. 신규 SETLE_CD/코드계열 유입 시 증가 → 매핑 갱신 신호.


with fmm as (
    select REASON_SK, UNPAID_FLAG_EOM, HAS_BILLING
    from GN_DW.GOLD.FACT_MEMBER_MONTHLY
    where HAS_BILLING = TRUE and UNPAID_FLAG_EOM = TRUE
)
select
    COUNT(*) as unmapped_cnt,
    (select COUNT(*) from fmm) as total_unpaid,
    unmapped_cnt * 100.0 / NULLIF(total_unpaid, 0) as pct
from fmm
where REASON_SK = 0
having pct > 5.0
      
    ) dbt_internal_test