
    
    

with dbt_test__target as (

  select concat(league, '|', cast(game_date as string), '|', matchup_code) as unique_field
  from `ba882-team8-fall26`.`ai_datasets`.`ml_training_set`
  where concat(league, '|', cast(game_date as string), '|', matchup_code) is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


