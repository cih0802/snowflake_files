select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.accepted_values_FACT_EVENT_ATT_a31e050516c23794739ccbd32aaa8c43
    
      
    ) dbt_internal_test