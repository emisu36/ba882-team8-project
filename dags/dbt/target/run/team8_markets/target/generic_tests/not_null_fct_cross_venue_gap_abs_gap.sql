
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select abs_gap
from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap`
where abs_gap is null



  
  
      
    ) dbt_internal_test