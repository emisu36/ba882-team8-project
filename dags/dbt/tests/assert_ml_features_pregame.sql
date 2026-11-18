-- fails if any row was captured after tip-off (leakage)
select * from {{ ref('ml_features') }}
where snapshot_hour >= commence_ts