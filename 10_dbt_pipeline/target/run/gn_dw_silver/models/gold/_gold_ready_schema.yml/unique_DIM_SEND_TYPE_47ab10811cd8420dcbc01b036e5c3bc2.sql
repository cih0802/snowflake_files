select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

select
    COALESCE(SEND_GBN_TOP,'~') || '|' || COALESCE(SEND_GBN_MID,'~') || '|' || COALESCE(SEND_GBN_BOT,'~') as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_SEND_TYPE
where COALESCE(SEND_GBN_TOP,'~') || '|' || COALESCE(SEND_GBN_MID,'~') || '|' || COALESCE(SEND_GBN_BOT,'~') is not null
group by COALESCE(SEND_GBN_TOP,'~') || '|' || COALESCE(SEND_GBN_MID,'~') || '|' || COALESCE(SEND_GBN_BOT,'~')
having count(*) > 1



      
    ) dbt_internal_test