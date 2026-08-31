
    
    

select
    EVENT_BK || '|' || MEMBER_DK || '|' || PARTCPT_SEQ as unique_field,
    count(*) as n_records

from GN_DW.GOLD.FACT_EVENT_PARTICIPATION
where EVENT_BK || '|' || MEMBER_DK || '|' || PARTCPT_SEQ is not null
group by EVENT_BK || '|' || MEMBER_DK || '|' || PARTCPT_SEQ
having count(*) > 1


