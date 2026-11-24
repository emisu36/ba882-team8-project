
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select commence_ts
from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where commence_ts is null



  
  
      
    ) dbt_internal_test