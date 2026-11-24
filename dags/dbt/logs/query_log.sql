-- created_at: 2026-11-24T13:42:25.163954094+00:00
-- finished_at: 2026-11-24T13:42:30.084836867+00:00
-- elapsed: 4.9s
-- outcome: success
-- dialect: bigquery
-- node_id: model.team8_markets.fct_cross_venue_gap
-- query_id: twWyKuc3pUOK2w0LPDEgMgYC2Re
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "model.team8_markets.fct_cross_venue_gap", "profile_name": "team8_markets", "target_name": "dev"} */
-- back compat for old kwarg name
  
  
        
            
                
                
            
                
                
            
                
                
            
                
                
            
                
                
            
        
    

    

    merge into `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap` as DBT_INTERNAL_DEST
        using (

with latest as (
    select *
    from `ba882-team8-fall26`.`mart`.`fct_price_snapshot`
    
    where snapshot_hour >= (select timestamp_sub(max(snapshot_hour), interval 1 hour) from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap`)
    
    qualify row_number() over (
        partition by venue, league, game_date, matchup_code, team_code, snapshot_hour
        order by snapshot_ts desc) = 1
),
o as (select * from latest where venue = 'oddsapi'),
p as (select * from latest where venue = 'polymarket')

select
    league, game_date, matchup_code, team_code, snapshot_hour,
    o.mid               as book_mid,
    p.mid               as poly_mid,
    o.spread            as book_spread,
    p.spread            as poly_spread,
    o.mid - p.mid       as gap,             -- positive: books higher than Polymarket
    abs(o.mid - p.mid)  as abs_gap,
    o.market_id         as oddsapi_event_id,
    p.market_id         as poly_market_id
from o
join p using (league, game_date, matchup_code, team_code, snapshot_hour)
where o.mid is not null and p.mid is not null   -- no quote on one venue = no comparable price
        ) as DBT_INTERNAL_SOURCE
        on (
                    DBT_INTERNAL_SOURCE.league = DBT_INTERNAL_DEST.league
                ) and (
                    DBT_INTERNAL_SOURCE.game_date = DBT_INTERNAL_DEST.game_date
                ) and (
                    DBT_INTERNAL_SOURCE.matchup_code = DBT_INTERNAL_DEST.matchup_code
                ) and (
                    DBT_INTERNAL_SOURCE.team_code = DBT_INTERNAL_DEST.team_code
                ) and (
                    DBT_INTERNAL_SOURCE.snapshot_hour = DBT_INTERNAL_DEST.snapshot_hour
                )

    
    when matched then update set
        `league` = DBT_INTERNAL_SOURCE.`league`,`game_date` = DBT_INTERNAL_SOURCE.`game_date`,`matchup_code` = DBT_INTERNAL_SOURCE.`matchup_code`,`team_code` = DBT_INTERNAL_SOURCE.`team_code`,`snapshot_hour` = DBT_INTERNAL_SOURCE.`snapshot_hour`,`book_mid` = DBT_INTERNAL_SOURCE.`book_mid`,`poly_mid` = DBT_INTERNAL_SOURCE.`poly_mid`,`book_spread` = DBT_INTERNAL_SOURCE.`book_spread`,`poly_spread` = DBT_INTERNAL_SOURCE.`poly_spread`,`gap` = DBT_INTERNAL_SOURCE.`gap`,`abs_gap` = DBT_INTERNAL_SOURCE.`abs_gap`,`oddsapi_event_id` = DBT_INTERNAL_SOURCE.`oddsapi_event_id`,`poly_market_id` = DBT_INTERNAL_SOURCE.`poly_market_id`
    

    when not matched then insert
        (`league`, `game_date`, `matchup_code`, `team_code`, `snapshot_hour`, `book_mid`, `poly_mid`, `book_spread`, `poly_spread`, `gap`, `abs_gap`, `oddsapi_event_id`, `poly_market_id`)
    values
        (`league`, `game_date`, `matchup_code`, `team_code`, `snapshot_hour`, `book_mid`, `poly_mid`, `book_spread`, `poly_spread`, `gap`, `abs_gap`, `oddsapi_event_id`, `poly_market_id`)


    ;
-- created_at: 2026-11-24T13:42:30.116380866+00:00
-- finished_at: 2026-11-24T13:42:31.640088864+00:00
-- elapsed: 1.5s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.not_null_fct_cross_venue_gap_abs_gap.42cfb801f2
-- query_id: mlPbbzt8MkQ9FqRoPVjXB8xNBuC
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.not_null_fct_cross_venue_gap_abs_gap.42cfb801f2", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select abs_gap
from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap`
where abs_gap is null



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:30.108560080+00:00
-- finished_at: 2026-11-24T13:42:31.743254890+00:00
-- elapsed: 1.6s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.assert_gap_between_minus1_and_1
-- query_id: n1ljI7xAMHaAUpDQ2NFR1O4oDOp
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.assert_gap_between_minus1_and_1", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
select *
from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap`
where gap < -1 or gap > 1
  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:30.103471585+00:00
-- finished_at: 2026-11-24T13:42:31.864719974+00:00
-- elapsed: 1.8s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.unique_fct_cross_venue_gap_concat_league_cast_game_date_as_string_matchup_code_team_code_cast_snapshot_hour_as_string_.e30d914369
-- query_id: prQcjDvTJykei7d7OQ32Q4bni0r
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.unique_fct_cross_venue_gap_concat_league_cast_game_date_as_string_matchup_code_team_code_cast_snapshot_hour_as_string_.e30d914369", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

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



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:32.621611514+00:00
-- finished_at: 2026-11-24T13:42:37.620619358+00:00
-- elapsed: 5.0s
-- outcome: success
-- dialect: bigquery
-- node_id: model.team8_markets.ml_features
-- query_id: xUarZQ2l5jfAhyV4JIIIG0wWuU2
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "model.team8_markets.ml_features", "profile_name": "team8_markets", "target_name": "dev"} */

  
    

    create or replace table `ba882-team8-fall26`.`ai_datasets`.`ml_features`
      
    
    

    
    OPTIONS()
    as (
      

-- One row per game x team x PRE-GAME snapshot, with the outcome once known.
-- Grain: league, game_date, matchup_code, team_code, snapshot_hour

with game_meta as (   -- tip-off time and home/away come from the Odds API rows
    select
        league, game_date, matchup_code, team_code,
        max(close_ts)                                                      as commence_ts,
        logical_or(team_name = split(market_title, ' @ ')[safe_offset(1)]) as is_home,
        avg(volume)                                                        as n_books
    from `ba882-team8-fall26`.`staging`.`int_team_prices`
    where venue = 'oddsapi'
    group by 1, 2, 3, 4
),
pregame as (
    select g.*, m.commence_ts, m.is_home, m.n_books
    from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap` g
    join game_meta m
      on m.league = g.league and m.game_date = g.game_date
     and m.matchup_code = g.matchup_code and m.team_code = g.team_code
    -- whole snapshot hour must end before tip-off: no in-game prices
    where timestamp_add(g.snapshot_hour, interval 1 hour) <= m.commence_ts
)
select
    p.league, p.game_date, p.matchup_code, p.team_code, p.snapshot_hour,
    p.commence_ts,
    p.is_home,
    timestamp_diff(p.commence_ts, p.snapshot_hour, minute) / 60.0           as hours_to_start,
    extract(dayofweek from p.commence_ts at time zone 'America/New_York')   as start_dow,
    p.book_mid, p.poly_mid, p.gap, p.abs_gap,
    p.book_spread                                                           as book_range,
    p.poly_spread,
    p.abs_gap > p.poly_spread / 2                                           as outside_spread,
    p.n_books,
    p.book_mid - lag(p.book_mid) over w                                     as book_move,
    p.poly_mid - lag(p.poly_mid) over w                                     as poly_move,
    row_number() over (partition by p.league, p.game_date, p.matchup_code, p.team_code
                       order by p.snapshot_hour desc) = 1                   as is_last_pregame,
    r.winner_code,
    case when r.winner_code is null then null
         when r.winner_code = p.team_code then 1 else 0 end                 as team_won
from pregame p
left join `ba882-team8-fall26`.`mart`.`fct_game_result` r
  on r.league = p.league and r.game_date = p.game_date and r.matchup_code = p.matchup_code
window w as (partition by p.league, p.game_date, p.matchup_code, p.team_code
             order by p.snapshot_hour)
    );
  ;
-- created_at: 2026-11-24T13:42:37.633081825+00:00
-- finished_at: 2026-11-24T13:42:39.242803709+00:00
-- elapsed: 1.6s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.unique_ml_features_concat_league_cast_game_date_as_string_matchup_code_team_code_cast_snapshot_hour_as_string_.0bd9657fd7
-- query_id: bNF9cbxKlf6txhv67EsWsumfkzg
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.unique_ml_features_concat_league_cast_game_date_as_string_matchup_code_team_code_cast_snapshot_hour_as_string_.0bd9657fd7", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with dbt_test__target as (

  select concat(league, '|', cast(game_date as string), '|', matchup_code, '|', team_code, '|', cast(snapshot_hour as string)) as unique_field
  from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
  where concat(league, '|', cast(game_date as string), '|', matchup_code, '|', team_code, '|', cast(snapshot_hour as string)) is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:37.632512563+00:00
-- finished_at: 2026-11-24T13:42:39.547992903+00:00
-- elapsed: 1.9s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.not_null_ml_features_is_home.d903cf872a
-- query_id: kfbYT67z5KXZWErD9QVInIWaad6
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.not_null_ml_features_is_home.d903cf872a", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select is_home
from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where is_home is null



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:37.638145923+00:00
-- finished_at: 2026-11-24T13:42:39.671100744+00:00
-- elapsed: 2.0s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.assert_ml_features_pregame
-- query_id: SU4Ae8O9nZdoPIRp2WVu1dCgSO4
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.assert_ml_features_pregame", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  -- fails if any row was captured after tip-off (leakage)
select * from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where snapshot_hour >= commence_ts
  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:39.247450304+00:00
-- finished_at: 2026-11-24T13:42:40.853439274+00:00
-- elapsed: 1.6s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.not_null_ml_features_commence_ts.f93e759b1d
-- query_id: fnqUWpLaHsfMXe4yqOWM3leiYAI
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.not_null_ml_features_commence_ts.f93e759b1d", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select commence_ts
from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where commence_ts is null



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:39.552381589+00:00
-- finished_at: 2026-11-24T13:42:41.389457326+00:00
-- elapsed: 1.8s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.accepted_values_ml_features_team_won__False__0__1.c660b8477a
-- query_id: NPgvl3fSjY7EU0cJcoXMB164qfC
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.accepted_values_ml_features_team_won__False__0__1.c660b8477a", "profile_name": "team8_markets", "target_name": "dev"} */

    
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



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:32.266789110+00:00
-- finished_at: 2026-11-24T13:42:47.375881389+00:00
-- elapsed: 15.1s
-- outcome: success
-- dialect: bigquery
-- node_id: model.team8_markets.rpt_game_gap
-- query_id: LeMth7N21hL89SFuZPfxiUqxdv4
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "model.team8_markets.rpt_game_gap", "profile_name": "team8_markets", "target_name": "dev"} */

  
    

    create or replace table `ba882-team8-fall26`.`mart`.`rpt_game_gap`
      
    
    

    
    OPTIONS()
    as (
      
-- one row per game per hour (first team in matchup_code), for the dashboard
select
    g.league, g.game_date, g.matchup_code, g.snapshot_hour,
    g.team_code                 as team,
    g.book_mid, g.poly_mid, g.gap, g.abs_gap,
    g.book_spread               as book_disagreement,
    g.poly_spread,
    r.winner_code,
    case when r.winner_code is null then null
         when r.winner_code = g.team_code then 1 else 0 end as team_won
from `ba882-team8-fall26`.`mart`.`fct_cross_venue_gap` g
left join `ba882-team8-fall26`.`mart`.`fct_game_result` r using (league, game_date, matchup_code)
where g.team_code = split(g.matchup_code, '-')[safe_offset(0)]
    );
  ;
-- created_at: 2026-11-24T13:42:47.384132247+00:00
-- finished_at: 2026-11-24T13:42:48.951988241+00:00
-- elapsed: 1.6s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.unique_rpt_game_gap_concat_league_cast_game_date_as_string_matchup_code_cast_snapshot_hour_as_string_.58beaba6f6
-- query_id: oSx5DQfkCoD04PvRwF0oKG40XjI
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.unique_rpt_game_gap_concat_league_cast_game_date_as_string_matchup_code_cast_snapshot_hour_as_string_.58beaba6f6", "profile_name": "team8_markets", "target_name": "dev"} */

    
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



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:41.621915991+00:00
-- finished_at: 2026-11-24T13:42:51.980627332+00:00
-- elapsed: 10.4s
-- outcome: success
-- dialect: bigquery
-- node_id: model.team8_markets.ml_training_set
-- query_id: waMlmV4iDJGvSezvSP3p6diJgbm
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "model.team8_markets.ml_training_set", "profile_name": "team8_markets", "target_name": "dev"} */

  
    

    create or replace table `ba882-team8-fall26`.`ai_datasets`.`ml_training_set`
      
    
    

    
    OPTIONS()
    as (
      
-- One row per finished game: home side, last pre-game snapshot. Label = home team won.
select *
from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where is_last_pregame and is_home and team_won is not null
    );
  ;
-- created_at: 2026-11-24T13:42:51.990166499+00:00
-- finished_at: 2026-11-24T13:42:53.535992475+00:00
-- elapsed: 1.5s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.unique_ml_training_set_concat_league_cast_game_date_as_string_matchup_code_.400d86ea9a
-- query_id: 93zxLllVKNa0jKdao1LYgEHVr0o
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.unique_ml_training_set_concat_league_cast_game_date_as_string_matchup_code_.400d86ea9a", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

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



  
  
      
    ) dbt_internal_test;
-- created_at: 2026-11-24T13:42:51.990166781+00:00
-- finished_at: 2026-11-24T13:42:53.586254582+00:00
-- elapsed: 1.6s
-- outcome: success
-- dialect: bigquery
-- node_id: test.team8_markets.not_null_ml_training_set_team_won.0f8fb1149f
-- query_id: pq1ElBOqLLt4TJGsBS1rZOSOULk
-- desc: execute adapter call
/* {"app": "dbt", "dbt_version": "2.0.0", "node_id": "test.team8_markets.not_null_ml_training_set_team_won.0f8fb1149f", "profile_name": "team8_markets", "target_name": "dev"} */

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select team_won
from `ba882-team8-fall26`.`ai_datasets`.`ml_training_set`
where team_won is null



  
  
      
    ) dbt_internal_test;
