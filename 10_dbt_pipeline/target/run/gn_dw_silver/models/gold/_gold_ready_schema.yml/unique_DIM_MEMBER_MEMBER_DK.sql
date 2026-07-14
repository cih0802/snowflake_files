select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    MEMBER_DK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_MEMBER
where MEMBER_DK is not null
group by MEMBER_DK
having count(*) > 1



      
    ) dbt_internal_test