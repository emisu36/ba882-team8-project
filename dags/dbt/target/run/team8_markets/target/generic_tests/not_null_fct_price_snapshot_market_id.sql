
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select market_id
from `ba882-team8-fall26`.`mart`.`fct_price_snapshot`
where market_id is null



  
  
      
    ) dbt_internal_test