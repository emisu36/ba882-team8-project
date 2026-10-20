select distinct
    league,
    json_value(payload, '$.event_ticker')                            as event_id,
    regexp_extract(json_value(payload, '$.ticker'), r'-([A-Z]+)$')   as team_code,
    safe.parse_date('%y%b%d',
        regexp_extract(json_value(payload, '$.event_ticker'), r'-(\d{2}[A-Z]{3}\d{2})')) as game_date,
    json_value(payload, '$.result')                                  as result,
    safe.timestamp(json_value(payload, '$.close_time'))              as close_ts
from {{ source('raw', 'market_snapshots') }}
where venue = 'kalshi_settled'