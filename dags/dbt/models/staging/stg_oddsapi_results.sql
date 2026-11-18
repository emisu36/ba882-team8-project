with latest as (
    select ingested_at, league, payload
    from {{ source('raw', 'game_scores') }}
    where safe_cast(json_value(payload, '$.completed') as bool)
    qualify row_number() over (
        partition by json_value(payload, '$.id') order by ingested_at desc) = 1
),
base as (
    select
        league,
        json_value(payload, '$.id')                                   as event_id,
        date(safe.timestamp(json_value(payload, '$.commence_time')), 'America/New_York') as game_date,
        json_value(payload, '$.home_team')                            as home_team,
        json_value(payload, '$.away_team')                            as away_team,
        json_query_array(payload, '$.scores')                         as scores,
        safe_cast(json_value(payload, '$.completed') as bool)         as completed,
        safe.timestamp(json_value(payload, '$.last_update'))          as last_update
    from latest
)
select
    league, event_id, game_date, home_team, away_team,
    (select safe_cast(json_value(s, '$.score') as int64) from unnest(scores) s
      where json_value(s, '$.name') = home_team)                      as home_score,
    (select safe_cast(json_value(s, '$.score') as int64) from unnest(scores) s
      where json_value(s, '$.name') = away_team)                      as away_score,
    completed,
    last_update
from base
