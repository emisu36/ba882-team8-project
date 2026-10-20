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
k as (select * from latest where venue = 'kalshi'),
p as (select * from latest where venue = 'polymarket')

select
    league, game_date, matchup_code, team_code, snapshot_hour,
    k.mid               as kalshi_mid,
    p.mid               as poly_mid,
    k.spread            as kalshi_spread,
    p.spread            as poly_spread,
    k.mid - p.mid       as gap,
    abs(k.mid - p.mid)  as abs_gap,
    k.market_id         as kalshi_market_id,
    p.market_id         as poly_market_id
from k
join p using (league, game_date, matchup_code, team_code, snapshot_hour)