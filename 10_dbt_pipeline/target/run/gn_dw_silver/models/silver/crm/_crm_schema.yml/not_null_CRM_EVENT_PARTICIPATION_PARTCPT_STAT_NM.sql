select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.not_null_CRM_EVENT_PARTICIPATION_PARTCPT_STAT_NM
    
      
    ) dbt_internal_test