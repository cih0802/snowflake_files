select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    MEMBER_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_MEMBER
where MEMBER_SK is not null
group by MEMBER_SK
having count(*) > 1



      
    ) dbt_internal_test