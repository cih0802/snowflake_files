select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.dbt_test__audit.warn_ga4_base_row_reconciliation
    
      
    ) dbt_internal_test