-- W4 회귀 방어: ML 파생 4종의 구조 불변량 검증 (행이 반환되면 위반).
-- Co-authored with CoCo
-- ① NULL 일관성: PAID_SPONSOR_BIZ_CNT·IS_MULTI_PAID_BIZ 는 HAS_BILLING=TRUE 일 때만 non-null.
--    (HAS_BILLING=FALSE 에 0 을 채우면 "납입 사업 0개"로 오독되어 완납률이 부풀려진다)
-- ② 플래그 정합: IS_MULTI_PAID_BIZ = (PAID_SPONSOR_BIZ_CNT > 1)
-- ③ 누적 음수 불가: 누적 횟수는 0 이상.
{{ config(severity='error') }}

select 'null_consistency' as violation, COUNT(*) as cnt
from {{ ref('FACT_MEMBER_MONTHLY') }}
where (HAS_BILLING = TRUE  and PAID_SPONSOR_BIZ_CNT is null)
   or (HAS_BILLING = FALSE and PAID_SPONSOR_BIZ_CNT is not null)
group by 1 having COUNT(*) > 0

union all

select 'flag_mismatch', COUNT(*)
from {{ ref('FACT_MEMBER_MONTHLY') }}
where PAID_SPONSOR_BIZ_CNT is not null
  and IS_MULTI_PAID_BIZ <> (PAID_SPONSOR_BIZ_CNT > 1)
group by 1 having COUNT(*) > 0

union all

select 'negative_cum', COUNT(*)
from {{ ref('FACT_MEMBER_MONTHLY') }}
where AMT_INCREASE_CUM_CNT < 0 or AMT_DECREASE_CUM_CNT < 0
group by 1 having COUNT(*) > 0
