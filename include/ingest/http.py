import time, requests

def get(url, params, return_response=False):
    """GET with retry/backoff on 429. Returns parsed JSON (or the Response if asked)."""
    for i in range(3):
        r = requests.get(url, params=params, timeout=30)
        if r.status_code == 429:
            time.sleep(2 ** i)
            continue
        r.raise_for_status()
        return r if return_response else r.json()
    r.raise_for_status()
