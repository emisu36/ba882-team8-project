{{ config(severity='warn') }}
select venue, market_id, team_code, snapshot_ts, bid, ask, spread
from {{ ref('fct_price_snapshot') }}
where spread < 0