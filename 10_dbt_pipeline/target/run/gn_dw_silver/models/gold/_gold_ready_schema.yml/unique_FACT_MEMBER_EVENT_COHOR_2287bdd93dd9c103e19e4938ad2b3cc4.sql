select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    EVENT_MONTH_KEY || '|' || MEMBER_DK || '|' || DVLP_DIV_CD || '|' || MONTHS_AFTER as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_MEMBER_EVENT_COHORT
where EVENT_MONTH_KEY || '|' || MEMBER_DK || '|' || DVLP_DIV_CD || '|' || MONTHS_AFTER is not null
group by EVENT_MONTH_KEY || '|' || MEMBER_DK || '|' || DVLP_DIV_CD || '|' || MONTHS_AFTER
having count(*) > 1



      
    ) dbt_internal_test