{{ config(materialized='incremental', incremental_strategy='merge',
          unique_key=['league', 'game_date', 'matchup_code']) }}

with r as (
    select s.*, h.team_code as home_code, a.team_code as away_code
    from {{ ref('stg_oddsapi_results') }} s
    left join {{ ref('team_code_map') }} h
      on h.league = s.league and h.venue = 'oddsapi' and h.venue_code = s.home_team
    left join {{ ref('team_code_map') }} a
      on a.league = s.league and a.venue = 'oddsapi' and a.venue_code = s.away_team
)
select
    league,
    game_date,
    concat(least(home_code, away_code), '-', greatest(home_code, away_code)) as matchup_code,
    if(home_score > away_score, home_code, away_code)                        as winner_code,
    last_update                                                              as settled_ts,
    event_id                                                                 as oddsapi_event_id
from r
where home_code is not null and away_code is not null
  and home_score is not null and away_score is not null
  and home_score != away_score          -- ties have no winner (as before)
