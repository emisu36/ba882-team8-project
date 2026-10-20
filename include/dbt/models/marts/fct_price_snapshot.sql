{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['venue', 'market_id', 'team_code', 'snapshot_ts'],
    partition_by = {'field': 'game_date', 'data_type': 'date'}
) }}

select
    venue, league, market_id, event_id, game_date, matchup_code,
    team_code, team_name, bid, ask, mid, spread, last_price,
    volume, open_interest, status, snapshot_ts, snapshot_hour
from {{ ref('int_team_prices') }}
{% if is_incremental() %}
where snapshot_ts > (select max(snapshot_ts) from {{ this }})
{% endif %}