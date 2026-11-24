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


    