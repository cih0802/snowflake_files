select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.warn_ga4_load_gap
    
      
    ) dbt_internal_test