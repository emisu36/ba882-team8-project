{{ config(materialized='table') }}

select
    league,
    game_date,
    matchup_code,
    split(matchup_code, '-')[safe_offset(0)]               as team_a,
    split(matchup_code, '-')[safe_offset(1)]               as team_b,
    logical_or(venue = 'oddsapi')                          as on_oddsapi,
    logical_or(venue = 'polymarket')                       as on_polymarket,
    max(if(venue = 'oddsapi', event_id, null))             as oddsapi_event_id,
    max(if(venue = 'polymarket', event_id, null))          as poly_event_id,
    min(snapshot_ts)                                       as first_seen_ts,
    max(snapshot_ts)                                       as last_seen_ts
from {{ ref('int_team_prices') }}
group by 1, 2, 3