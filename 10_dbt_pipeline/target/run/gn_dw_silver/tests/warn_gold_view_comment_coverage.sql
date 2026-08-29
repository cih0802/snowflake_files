select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
        select *
        from GN_DW.OPS.warn_gold_view_comment_coverage
    
      
    ) dbt_internal_test