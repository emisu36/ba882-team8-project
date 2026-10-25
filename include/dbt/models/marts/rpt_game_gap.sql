{{ config(materialized='table') }}
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
from {{ ref('fct_cross_venue_gap') }} g
left join {{ ref('fct_game_result') }} r using (league, game_date, matchup_code)
where g.team_code = split(g.matchup_code, '-')[safe_offset(0)]