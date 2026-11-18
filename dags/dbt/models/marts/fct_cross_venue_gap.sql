{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['league', 'game_date', 'matchup_code', 'team_code', 'snapshot_hour']
) }}

with latest as (
    select *
    from {{ ref('fct_price_snapshot') }}
    {% if is_incremental() %}
    where snapshot_hour >= (select timestamp_sub(max(snapshot_hour), interval 1 hour) from {{ this }})
    {% endif %}
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
