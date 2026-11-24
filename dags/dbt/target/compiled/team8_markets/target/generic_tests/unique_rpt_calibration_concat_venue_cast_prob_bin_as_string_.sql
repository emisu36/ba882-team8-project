
    
    

with dbt_test__target as (

  select concat(venue, '|', cast(prob_bin as string)) as unique_field
  from `ba882-team8-fall26`.`mart`.`rpt_calibration`
  where concat(venue, '|', cast(prob_bin as string)) is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


