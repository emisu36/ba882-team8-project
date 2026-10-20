import logging, os
from include.ingest.http import get

BASE = "https://api.the-odds-api.com/v4"
SPORT_KEYS = {"nfl": "americanfootball_nfl", "nba": "basketball_nba", "nhl": "icehockey_nhl"}

log = logging.getLogger(__name__)

def _call(path, params):
    r = get(f"{BASE}{path}", {**params, "apiKey": os.environ["ODDS_API_KEY"]}, return_response=True)
    # watch the monthly request budget
    log.info("odds-api %s: requests remaining=%s used=%s", path,
             r.headers.get("x-requests-remaining"), r.headers.get("x-requests-used"))
    return r.json()

def fetch_odds(league):
    return _call(f"/sports/{SPORT_KEYS[league]}/odds",
                 {"regions": "us", "markets": "h2h", "oddsFormat": "decimal"})

def fetch_scores(league, days_from=1):
    return _call(f"/sports/{SPORT_KEYS[league]}/scores", {"daysFrom": days_from})
