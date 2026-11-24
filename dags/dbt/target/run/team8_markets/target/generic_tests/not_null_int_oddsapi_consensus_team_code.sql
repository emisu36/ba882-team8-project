
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select team_code
from `ba882-team8-fall26`.`staging`.`int_oddsapi_consensus`
where team_code is null



  
  
      
    ) dbt_internal_test