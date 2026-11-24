
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select is_home
from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where is_home is null



  
  
      
    ) dbt_internal_test