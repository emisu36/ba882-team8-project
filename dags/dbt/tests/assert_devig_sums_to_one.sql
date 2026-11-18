{{ config(severity='warn') }}
select snapshot_ts, event_id, sum(last_price) as total_prob
from {{ ref('int_oddsapi_consensus') }}
group by snapshot_ts, event_id
having abs(sum(last_price) - 1) > 0.01