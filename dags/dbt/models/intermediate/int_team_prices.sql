with unioned as (
    select * from {{ ref('int_oddsapi_consensus') }}
    union all
    select * from {{ ref('stg_polymarket_markets') }}
),
mapped as (
    select u.* replace (coalesce(m.team_code, u.team_code) as team_code)
    from unioned u
    left join {{ ref('team_code_map') }} m
      on m.league = u.league and m.venue = u.venue and m.venue_code = u.team_code
),
keyed as (
    select *,
        min(team_code) over w as team_a,
        max(team_code) over w as team_b
    from mapped
    window w as (partition by venue, event_id, snapshot_ts)
)
select
    * except (matchup_code, team_a, team_b),
    concat(team_a, '-', team_b)          as matchup_code,   -- sorted, same on both venues
    if(venue = 'oddsapi', last_price, (bid + ask) / 2)   as mid,
    ask - bid                            as spread,
    timestamp_trunc(snapshot_ts, hour)   as snapshot_hour
from keyed
where game_date is not null
  and team_a != team_b                   -- drops events missing one side in a snapshot