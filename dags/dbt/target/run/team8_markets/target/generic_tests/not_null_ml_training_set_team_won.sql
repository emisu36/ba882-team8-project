
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select team_won
from `ba882-team8-fall26`.`ai_datasets`.`ml_training_set`
where team_won is null



  
  
      
    ) dbt_internal_test