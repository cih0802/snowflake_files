select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    DATE_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_DATE
where DATE_SK is not null
group by DATE_SK
having count(*) > 1



      
    ) dbt_internal_test