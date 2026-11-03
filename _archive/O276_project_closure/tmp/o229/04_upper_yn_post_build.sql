-- O229 UPPER_CMPGN_YN → GOLD.DIM_CAMPAIGN.IS_PARENT_CAMPAIGN_YN 사후 단계 (👤 dbt build 이후 실행)
-- Co-authored with CoCo
-- 선행 = dbt build --select DIM_CAMPAIGN --project-dir 10_dbt_pipeline
--        (gold/dim on_schema_change = append_new_columns ⇒ 컬럼 추가 · 정본 dbt_project.yml:240)

-- ① 컬럼 실재 + 분포 (기대 = Y 1,483 · N 35,770 · SK=0 은 NULL)
SELECT IS_PARENT_CAMPAIGN_YN, COUNT(*) AS n
FROM GN_DW.GOLD.DIM_CAMPAIGN
GROUP BY 1
ORDER BY 2 DESC;

-- ② COMMENT (정본 = 03_top-down_gold/06_DDL.sql:277 · comment_drift_gate GOLD 테이블 축)
ALTER TABLE GN_DW.GOLD.DIM_CAMPAIGN MODIFY COLUMN IS_PARENT_CAMPAIGN_YN
    COMMENT '상위캠페인여부(Y = 그 자신이 상위캠페인 · N = 하위캠페인) [SILVER.CRM_CAMPAIGN 승계 · 원천 BRONZE_CRM.TM_CM_CMPGN_MNG.UPPER_CMPGN_YN]';

-- ③ 이후 에이전트 단계(다음 세션) = SV_SERVICE 차원 추가 → campaign_axis_gate 등재 camp_attr('IS_PARENT_CAMPAIGN_YN')
--    → python3 scripts/comment_drift_gate.py --surface table (드리프트 0)
