-- Odds API books collapsed to one row per snapshot x event x team, with the same
-- columns (and order) as stg_polymarket_markets so it unions into int_team_prices.
with devig as (
    select *,
        implied_prob / sum(implied_prob) over w                       as p_devig
    from {{ ref('stg_oddsapi_book_prices') }}
    where implied_prob is not null
    qualify count(*) over w = 2           -- book must price both sides to devig
    window w as (partition by snapshot_ts, event_id, bookmaker)
),
consensus as (
    select
        snapshot_ts, league, event_id, commence_ts, game_date, home_team, away_team, team_name,
        min(p_devig)                                                  as bid,   -- low end of book range
        max(p_devig)                                                  as ask,   -- high end of book range
        avg(p_devig)                                                  as last_price,
        count(distinct bookmaker)                                     as n_books
    from devig
    group by 1, 2, 3, 4, 5, 6, 7, 8
),
coded as (
    select c.*, m.team_code
    from consensus c
    left join {{ ref('team_code_map') }} m
      on m.league = c.league and m.venue = 'oddsapi' and m.venue_code = c.team_name
)
select
    snapshot_ts,
    'oddsapi'                                                         as venue,
    league,
    event_id                                                          as market_id,
    event_id,
    concat(away_team, ' @ ', home_team)                               as market_title,
    team_name,
    team_code,
    game_date,
    concat(min(team_code) over e, '-', max(team_code) over e)         as matchup_code,
    bid,
    ask,
    last_price,
    cast(n_books as numeric)                                          as volume,
    cast(null as numeric)                                             as open_interest,
    commence_ts                                                       as close_ts,
    'open'                                                            as status,
    cast(null as string)                                              as rules_text
from coded
window e as (partition by snapshot_ts, event_id)
