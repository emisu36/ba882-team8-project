
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
select *
from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap`
where gap < -1 or gap > 1
  
  
      
    ) dbt_internal_test