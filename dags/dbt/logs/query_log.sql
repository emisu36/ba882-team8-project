-- created_at: 2026-11-24T18:07:25.165684451+00:00
-- finished_at: 2026-11-24T18:07:33.034463576+00:00
-- elapsed: 7.9s
-- outcome: success
-- dialect: bigquery
-- node_id: model.team8_markets.rpt_calibration
-- query_id: 4w3Qclj5r6c1iVGrq3qKZG4mNC3
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "model.team8_markets.rpt_calibration", "profile_name": "team8_markets", "target_name": "dev"} */

  
    

    create or replace table `ba882-team8-fall26`.`mart`.`rpt_calibration`
      
    
    

    
    OPTIONS()
    as (
      

-- Option A: is each venue well calibrated?
-- For finished games (home side, last pre-game price), group predictions into 10 bins
-- and compare the average predicted probability with how often the team actually won.
-- A perfectly calibrated venue has avg_predicted = actual_win_rate in every bin.
with preds as (
    select league, game_date, 'Sportsbooks' as venue, book_mid as p, team_won
    from `ba882-team8-fall26`.`ai_datasets`.`ml_training_set`
    union all
    select league, game_date, 'Polymarket', poly_mid, team_won
    from `ba882-team8-fall26`.`ai_datasets`.`ml_training_set`
)
select
    venue,
    least(cast(floor(p * 10) as int64), 9)      as prob_bin,          -- 0 = 0-10%, ..., 9 = 90-100%
    count(*)                                    as n_games,
    avg(p)                                      as avg_predicted,
    avg(team_won)                               as actual_win_rate,
    avg(team_won) - avg(p)                      as calibration_error,  -- + = venue too pessimistic
    avg(pow(p - team_won, 2))                   as brier_in_bin
from preds
group by 1, 2
    );
  ;
-- created_at: 2026-11-24T18:07:33.153079058+00:00
-- finished_at: 2026-11-24T18:07:35.317636149+00:00
-- elapsed: 2.2s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.accepted_values_rpt_calibration_prob_bin__False__0__1__2__3__4__5__6__7__8__9.f8fab60d9c
-- query_id: sbZxkmcOZHQay07PPFxFdLpelWA
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.accepted_values_rpt_calibration_prob_bin__False__0__1__2__3__4__5__6__7__8__9.f8fab60d9c", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        prob_bin as value_field,
        count(*) as n_records

    from `ba882-team8-fall26`.`mart`.`rpt_calibration`
    group by prob_bin

)

select *
from all_values
where value_field not in (
    0,1,2,3,4,5,6,7,8,9
)



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T18:07:33.147653120+00:00
-- finished_at: 2026-11-24T18:07:35.503424223+00:00
-- elapsed: 2.4s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.unique_rpt_calibration_concat_venue_cast_prob_bin_as_string_.5dcb466a41
-- query_id: nIAFlJBL895Hs8FeB293moGAYzC
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.unique_rpt_calibration_concat_venue_cast_prob_bin_as_string_.5dcb466a41", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

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



  
  
      
    ) dbt_internal_test;
