with src as (
    select ingested_at, league, payload
    from {{ source('raw', 'market_snapshots') }}
    where venue = 'polymarket'
      and json_value(payload, '$.sportsMarketType') = 'moneyline'
      and regexp_contains(json_value(payload, '$.slug'), r'^[a-z]+-[a-z]+-[a-z]+-\d{4}-\d{2}-\d{2}$')   -- single games only
      and safe.parse_date('%Y-%m-%d', regexp_extract(json_value(payload, '$.slug'), r'(\d{4}-\d{2}-\d{2})$'))
          >= date(ingested_at, 'America/New_York')                                                    -- drop past games
),
base as (
    select
        ingested_at                                                   as snapshot_ts,
        league,
        json_value(payload, '$.id')                                   as market_id,
        json_value(payload, '$.slug')                                 as event_id,
        json_value(payload, '$.question')                             as market_title,
        json_value_array(json_value(payload, '$.outcomes'))           as outcomes,
        json_value_array(json_value(payload, '$.outcomePrices'))      as prices,
        safe_cast(json_value(payload, '$.bestBid') as numeric)        as best_bid,
        safe_cast(json_value(payload, '$.bestAsk') as numeric)        as best_ask,
        safe_cast(json_value(payload, '$.volume') as numeric)         as volume,
        safe_cast(json_value(payload, '$.liquidity') as numeric)      as liquidity,
        safe.parse_date('%Y-%m-%d',
            regexp_extract(json_value(payload, '$.slug'), r'(\d{4}-\d{2}-\d{2})$'))       as game_date,
        regexp_extract(json_value(payload, '$.slug'), r'^[a-z]+-([a-z]+-[a-z]+)-\d{4}')   as matchup,
        safe.timestamp(json_value(payload, '$.endDate'))              as close_ts,
        json_value(payload, '$.closed')                               as closed,
        json_value(payload, '$.description')                          as rules_text
    from src
)
-- one row per team: outcome 0 uses best bid/ask; outcome 1 is the complement
select
    snapshot_ts,
    'polymarket'                                                      as venue,
    league,
    market_id,
    event_id,
    market_title,
    outcomes[safe_offset(i)]                                          as team_name,
    upper(split(matchup, '-')[safe_offset(i)])                        as team_code,
    game_date,
    upper(replace(matchup, '-', ''))                                  as matchup_code,
    if(i = 0, best_bid, 1 - best_ask)                                 as bid,
    if(i = 0, best_ask, 1 - best_bid)                                 as ask,
    safe_cast(prices[safe_offset(i)] as numeric)                      as last_price,
    volume,
    liquidity                                                         as open_interest,
    close_ts,
    if(closed = 'true', 'closed', 'active')                           as status,
    rules_text
from base, unnest([0, 1]) as i