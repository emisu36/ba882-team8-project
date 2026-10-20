import time
from include.ingest.http import get as _get

POLY = "https://gamma-api.polymarket.com"

LEAGUES = {
    "nba": {"poly_tag": "nba"},
    "nhl": {"poly_tag": "nhl"},
    "nfl": {"poly_tag": "nfl"},
}

EVENT_FIELDS = ["id", "title", "slug", "startDate", "endDate"]

def fetch_polymarket(league):
    events, offset = [], 0
    while True:
        d = _get(f"{POLY}/events", {"tag_slug": LEAGUES[league]["poly_tag"],
                 "active": "true", "closed": "false", "limit": 100, "offset": offset})
        events += d
        if len(d) < 100:
            break
        offset += 100
        time.sleep(0.5)                      # be polite to the API
    rows = []
    for e in events:                         # one row per market, with slim event context
        ev = {k: e.get(k) for k in EVENT_FIELDS}
        for m in e.get("markets", []):
            if m.get("sportsMarketType") != "moneyline":
                continue
            m = {k: v for k, v in m.items() if k != "events"}
            m["_event"] = ev
            rows.append(m)
    return rows