{{ config(materialized='table', schema='ai_datasets') }}
-- One row per finished game: home side, last pre-game snapshot. Label = home team won.
select *
from {{ ref('ml_features') }}
where is_last_pregame and is_home and team_won is not null
