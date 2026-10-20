with src as (
    select ingested_at, league, payload
    from {{ source('raw', 'market_snapshots') }}
    where venue = 'kalshi'
)
select
    ingested_at                                                       as snapshot_ts,
    'kalshi'                                                          as venue,
    league,
    json_value(payload, '$.ticker')                                   as market_id,
    json_value(payload, '$.event_ticker')                             as event_id,
    json_value(payload, '$.title')                                    as market_title,
    coalesce(json_value(payload, '$.yes_sub_title'),
             regexp_replace(json_value(payload, '$.title'), r' wins$', '')) as team_name,
    regexp_extract(json_value(payload, '$.ticker'), r'-([A-Z]+)$')    as team_code,
    safe.parse_date('%y%b%d',
        regexp_extract(json_value(payload, '$.event_ticker'), r'-(\d{2}[A-Z]{3}\d{2})'))   as game_date,
    regexp_extract(json_value(payload, '$.event_ticker'), r'-\d{2}[A-Z]{3}\d{2}([A-Z]+)$') as matchup_code,
    safe_cast(json_value(payload, '$.yes_bid_dollars') as numeric)    as bid,
    safe_cast(json_value(payload, '$.yes_ask_dollars') as numeric)    as ask,
    safe_cast(json_value(payload, '$.last_price_dollars') as numeric) as last_price,
    safe_cast(json_value(payload, '$.volume_fp') as numeric)          as volume,
    safe_cast(json_value(payload, '$.open_interest_fp') as numeric)   as open_interest,
    safe.timestamp(json_value(payload, '$.close_time'))               as close_ts,
    json_value(payload, '$.status')                                   as status,
    json_value(payload, '$.rules_primary')                            as rules_text
from src