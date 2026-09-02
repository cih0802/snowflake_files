
    
    

select
    BUDGET_ITEM_DK as unique_field,
    count(*) as n_records

from GN_DW.SILVER.ERP_BUDGET_ITEM
where BUDGET_ITEM_DK is not null
group by BUDGET_ITEM_DK
having count(*) > 1


