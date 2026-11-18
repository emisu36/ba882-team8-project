{{ config(severity='warn') }}
select *
from {{ ref('fct_cross_venue_gap') }}
where gap < -1 or gap > 1