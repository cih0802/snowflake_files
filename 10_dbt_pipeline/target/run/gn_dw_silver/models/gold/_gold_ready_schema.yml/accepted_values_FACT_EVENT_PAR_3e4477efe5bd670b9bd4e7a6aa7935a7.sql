select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.accepted_values_FACT_EVENT_PAR_3e4477efe5bd670b9bd4e7a6aa7935a7
    
      
    ) dbt_internal_test