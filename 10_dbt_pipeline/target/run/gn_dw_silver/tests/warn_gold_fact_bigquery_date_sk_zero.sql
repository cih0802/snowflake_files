select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.warn_gold_fact_bigquery_date_sk_zero
    
      
    ) dbt_internal_test