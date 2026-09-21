
    
    

select
    PAYMENT_SK as unique_field,
    count(*) as n_records

from GN_DW.GOLD.DIM_PAYMENT
where PAYMENT_SK is not null
group by PAYMENT_SK
having count(*) > 1


