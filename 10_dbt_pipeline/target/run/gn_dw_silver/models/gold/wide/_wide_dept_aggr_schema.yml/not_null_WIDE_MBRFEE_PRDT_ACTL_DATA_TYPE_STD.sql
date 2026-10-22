select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.not_null_WIDE_MBRFEE_PRDT_ACTL_DATA_TYPE_STD
    
      
    ) dbt_internal_test