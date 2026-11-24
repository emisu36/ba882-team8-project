
select venue, market_id, team_code, snapshot_ts, bid, ask, spread
from `ba882-team8-fall26`.`mart`.`fct_price_snapshot`
where spread < 0