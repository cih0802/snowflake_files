select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.accepted_values_WIDE_MBRFEE_PRDT_ACTL_DATA_TYPE_NM____________
    
      
    ) dbt_internal_test