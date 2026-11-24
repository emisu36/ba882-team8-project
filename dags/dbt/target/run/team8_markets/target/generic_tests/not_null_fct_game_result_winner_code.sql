
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select winner_code
from `ba882-team8-fall26`.`mart`.`fct_game_result`
where winner_code is null



  
  
      
    ) dbt_internal_test