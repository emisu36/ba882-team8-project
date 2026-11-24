
    
    

with dbt_test__target as (

  select concat(league, '|', cast(game_date as string), '|', matchup_code, '|', team_code, '|', cast(snapshot_hour as string)) as unique_field
  from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap`
  where concat(league, '|', cast(game_date as string), '|', matchup_code, '|', team_code, '|', cast(snapshot_hour as string)) is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


