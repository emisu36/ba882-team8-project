
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        team_won as value_field,
        count(*) as n_records

    from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
    group by team_won

)

select *
from all_values
where value_field not in (
    0,1
)



  
  
      
    ) dbt_internal_test