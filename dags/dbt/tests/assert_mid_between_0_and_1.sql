{{ config(severity='warn') }}
select venue, market_id, team_code, snapshot_ts, bid, ask, mid
from {{ ref('fct_price_snapshot') }}
where mid < 0 or mid > 1
   or bid < 0 or bid > 1
   or ask < 0 or ask > 1