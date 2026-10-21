with src as (
    select ingested_at, league, payload
    from {{ source('raw', 'market_snapshots') }}
    where venue = 'oddsapi'
),
h2h as (
    select
        s.ingested_at,
        s.league,
        json_value(s.payload, '$.id')                                 as event_id,
        safe.timestamp(json_value(s.payload, '$.commence_time'))      as commence_ts,
        json_value(s.payload, '$.home_team')                          as home_team,
        json_value(s.payload, '$.away_team')                          as away_team,
        json_value(b, '$.key')                                        as bookmaker,
        mkt
    from src s,
        unnest(json_query_array(s.payload, '$.bookmakers')) as b,
        unnest(json_query_array(b, '$.markets')) as mkt
    where json_value(mkt, '$.key') = 'h2h'
)
-- one row per snapshot x event x bookmaker x team
select
    ingested_at                                                       as snapshot_ts,
    'oddsapi'                                                         as venue,
    league,
    event_id,
    bookmaker,
    commence_ts,
    date(commence_ts, 'America/New_York')                             as game_date,
    home_team,
    away_team,
    json_value(o, '$.name')                                           as team_name,
    json_value(o, '$.name') = home_team                               as is_home,
    safe_cast(json_value(o, '$.price') as numeric)                    as decimal_odds,
    safe_divide(1, safe_cast(json_value(o, '$.price') as numeric))    as implied_prob
from h2h, unnest(json_query_array(mkt, '$.outcomes')) as o
where json_value(o, '$.name') in (home_team, away_team)   -- teams only, no draw outcome
