
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with dbt_test__target as (

  select concat(league, '|', cast(game_date as string), '|', matchup_code, '|', cast(snapshot_hour as string)) as unique_field
  from `ba882-team8-fall26`.`mart`.`rpt_game_gap`
  where concat(league, '|', cast(game_date as string), '|', matchup_code, '|', cast(snapshot_hour as string)) is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1



  
  
      
    ) dbt_internal_test