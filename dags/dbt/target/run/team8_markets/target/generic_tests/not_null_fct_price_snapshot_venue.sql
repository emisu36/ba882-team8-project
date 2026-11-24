
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select venue
from `ba882-team8-fall26`.`mart`.`fct_price_snapshot`
where venue is null



  
  
      
    ) dbt_internal_test