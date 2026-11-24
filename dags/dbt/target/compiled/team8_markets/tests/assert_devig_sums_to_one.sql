
select snapshot_ts, event_id, sum(last_price) as total_prob
from `ba882-team8-fall26`.`staging`.`int_oddsapi_consensus`
group by snapshot_ts, event_id
having abs(sum(last_price) - 1) > 0.01