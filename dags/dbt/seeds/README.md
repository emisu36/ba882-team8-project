<!--
team_code_map verification notes (2026-10-20)

Polymarket codes: verified for all 32 NFL / 30 NBA / 32 NHL teams by pulling moneyline
market slugs from gamma-api.polymarket.com/events (open + recently closed). The canonical
code is the slug code after the polymarket rows in this seed are applied
(NFL LA->LAR, NHL UTAH->UTA, MON->MTL, LAS->VGK, CAL->CGY). Every oddsapi row maps to
one of those codes, so there is nothing to verify on the Polymarket side.

Odds API names: verified against /v4/sports/{sport}/events (free endpoint) for all
NFL and NBA teams and 26 NHL teams. Note Odds API spellings "Montréal Canadiens"
(accent) and "St Louis Blues" (no period).

UNVERIFIED Odds API names (no NHL events listed for them at check time):
  - Calgary Flames, Chicago Blackhawks, Nashville Predators, New York Rangers,
    Pittsburgh Penguins
  - Utah: seeded as both "Utah Mammoth" and "Utah Hockey Club"; drop whichever
    the API never returns.
The not_null test on int_oddsapi_consensus.team_code fails if any name is wrong.
-->

# Seeds

`team_code_map.csv` maps each venue's team identifier (`venue_code`) to one canonical
3-letter-ish `team_code` per league, so the venues can be joined on `matchup_code`.

- `polymarket`: `venue_code` is the uppercased slug code; only codes that differ from
  the canonical code need a row.
- `oddsapi`: `venue_code` is the full team name exactly as The Odds API returns it;
  every team needs a row.
