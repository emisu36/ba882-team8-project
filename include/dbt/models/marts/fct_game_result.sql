{{ config(materialized='incremental', incremental_strategy='merge',
          unique_key=['league', 'game_date', 'matchup_code']) }}

with r as (
    select s.league, s.event_id, s.game_date, s.result, s.close_ts,
           coalesce(m.team_code, s.team_code) as team_code
    from {{ ref('stg_kalshi_results') }} s
    left join {{ ref('team_code_map') }} m
      on m.league = s.league and m.venue = 'kalshi' and m.venue_code = s.team_code
)
select
    league,
    game_date,
    concat(min(team_code), '-', max(team_code))   as matchup_code,
    max(if(result = 'yes', team_code, null))      as winner_code,
    max(close_ts)                                 as settled_ts,
    event_id                                      as kalshi_event_id
from r
group by league, game_date, event_id
having count(distinct team_code) = 2
   and max(if(result = 'yes', team_code, null)) is not null