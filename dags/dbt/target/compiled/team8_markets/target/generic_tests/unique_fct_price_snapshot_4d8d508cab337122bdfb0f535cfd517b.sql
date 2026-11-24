
    
    

with dbt_test__target as (

  select concat(venue, '|', market_id, '|', team_code, '|', cast(snapshot_ts as string)) as unique_field
  from `ba882-team8-fall26`.`mart`.`fct_price_snapshot`
  where concat(venue, '|', market_id, '|', team_code, '|', cast(snapshot_ts as string)) is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


