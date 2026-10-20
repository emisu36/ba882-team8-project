import time, requests

KALSHI = "https://api.elections.kalshi.com/trade-api/v2"
POLY = "https://gamma-api.polymarket.com"

# Kalshi series tickers are placeholders: confirm with the validation script
LEAGUES = {
    "nba": {"kalshi_series": ["KXNBAGAME"], "poly_tag": "nba"},
    "nhl": {"kalshi_series": ["KXNHLGAME"], "poly_tag": "nhl"},
    "nfl": {"kalshi_series": ["KXNFLGAME"], "poly_tag": "nfl"},
}

def _get(url, params):
    for i in range(3):
        r = requests.get(url, params=params, timeout=30)
        if r.status_code == 429:
            time.sleep(2 ** i)
            continue
        r.raise_for_status()
        return r.json()
    r.raise_for_status()

def fetch_kalshi(league):
    rows = []
    for series in LEAGUES[league]["kalshi_series"]:
        cursor = None
        while True:
            p = {"series_ticker": series, "status": "open", "limit": 1000}
            if cursor:
                p["cursor"] = cursor
            d = _get(f"{KALSHI}/markets", p)
            rows += d.get("markets", [])
            cursor = d.get("cursor")
            if not cursor:
                break
    return rows

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
            m = {k: v for k, v in m.items() if k != "events"}
            m["_event"] = ev
            rows.append(m)
    return rows