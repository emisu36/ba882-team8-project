{{ config(materialized='table', schema='ai_datasets') }}

-- One row per game x team x PRE-GAME snapshot, with the outcome once known.
-- Grain: league, game_date, matchup_code, team_code, snapshot_hour

with game_meta as (   -- tip-off time and home/away come from the Odds API rows
    select
        league, game_date, matchup_code, team_code,
        max(close_ts)                                                      as commence_ts,
        logical_or(team_name = split(market_title, ' @ ')[safe_offset(1)]) as is_home,
        avg(volume)                                                        as n_books
    from {{ ref('int_team_prices') }}
    where venue = 'oddsapi'
    group by 1, 2, 3, 4
),
pregame as (
    select g.*, m.commence_ts, m.is_home, m.n_books
    from {{ ref('fct_cross_venue_gap') }} g
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
left join {{ ref('fct_game_result') }} r
  on r.league = p.league and r.game_date = p.game_date and r.matchup_code = p.matchup_code
window w as (partition by p.league, p.game_date, p.matchup_code, p.team_code
             order by p.snapshot_hour)