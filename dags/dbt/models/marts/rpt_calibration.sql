{{ config(materialized='table') }}

-- Option A: is each venue well calibrated?
-- For finished games (home side, last pre-game price), group predictions into 10 bins
-- and compare the average predicted probability with how often the team actually won.
-- A perfectly calibrated venue has avg_predicted = actual_win_rate in every bin.
with preds as (
    select league, game_date, 'Sportsbooks' as venue, book_mid as p, team_won
    from {{ ref('ml_training_set') }}
    union all
    select league, game_date, 'Polymarket', poly_mid, team_won
    from {{ ref('ml_training_set') }}
)
select
    venue,
    least(cast(floor(p * 10) as int64), 9)      as prob_bin,          -- 0 = 0-10%, ..., 9 = 90-100%
    count(*)                                    as n_games,
    avg(p)                                      as avg_predicted,
    avg(team_won)                               as actual_win_rate,
    avg(team_won) - avg(p)                      as calibration_error,  -- + = venue too pessimistic
    avg(pow(p - team_won, 2))                   as brier_in_bin
from preds
group by 1, 2
