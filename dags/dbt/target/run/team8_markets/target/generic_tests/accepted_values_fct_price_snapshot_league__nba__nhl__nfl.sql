
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        league as value_field,
        count(*) as n_records

    from `ba882-team8-fall26`.`mart`.`fct_price_snapshot`
    group by league

)

select *
from all_values
where value_field not in (
    'nba','nhl','nfl'
)



  
  
      
    ) dbt_internal_test