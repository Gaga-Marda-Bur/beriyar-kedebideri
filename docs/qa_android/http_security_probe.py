"""Real HTTP loopback QA only; synthetic credentials never printed."""
import base64
import json
from pathlib import Path
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

LAB = Path(__file__).resolve().parent / 'runtime'
lab = json.loads((LAB / 'lab.json').read_text(encoding='utf-8'))
credentials = json.loads((LAB / 'synthetic_accounts.json').read_text(encoding='utf-8'))
BASE = lab['base_url']
assert BASE == 'http://127.0.0.1:8765/api'
rows = []


def request(method, path, body=None, user=None, headers=None):
    hdr = {'Accept': 'application/json', **(headers or {})}
    if body is not None:
        hdr['Content-Type'] = 'application/json'
    if user:
        hdr['Authorization'] = 'Basic ' + base64.b64encode(f'{user}:{credentials[user]}'.encode()).decode()
    req = Request(BASE + path, data=json.dumps(body).encode() if body is not None else None,
                  headers=hdr, method=method)
    start = time.perf_counter()
    try:
        with urlopen(req, timeout=10) as response:
            status, data = response.status, json.load(response)
    except HTTPError as error:
        status, data = error.code, json.load(error)
    return status, data, round((time.perf_counter() - start) * 1000, 1)


def check(name, condition, **evidence):
    rows.append({'scenario': name, 'passed': bool(condition), **evidence})
    assert condition, name


def sync(item, user=None, headers=None):
    status, data, ms = request('POST', '/progress/unit-progress/sync/', {'items': [item]}, user, headers)
    assert status == 200
    return data


unit = lab['first_unit_slug']
a = 'qa_account_a'
b = 'qa_account_b'
status, data, ms = request('GET', '/alphabet/characters/')
check('real HTTP published alphabet', status == 200 and data['count'] == 2, http_status=status, elapsed_ms=ms)
status, data, _ = request('GET', '/progress/unit-progress/', user=a)
check('account A authenticates and reads its record', status == 200 and data['count'] == 1)
status, data, _ = request('GET', '/progress/unit-progress/?device_id=qa-account-a', user=b)
check('account B cannot read A by changing device_id', status == 200 and data['count'] == 0)
data = sync({'unit_slug': unit, 'lessons_seen': 8, 'score_percent': 80}, user=a)
check('A sync after simulated offline accumulation', data['synced_count'] == 1)
data = sync({'unit_slug': unit, 'device_id': 'qa-account-a', 'device_token': 'synthetic-old-token-a', 'lessons_seen': 99}, user=b)
check('B cannot overwrite A even with its old installation token', data['error_count'] == 1 and data['synced_count'] == 0)
status, data, _ = request('GET', '/progress/unit-progress/')
check('request without authentication cannot read private history', status == 403, http_status=status)
data = sync({'unit_slug': unit, 'lessons_seen': 1, 'user': 1}, user=b)
check('B creates its own record despite forged user field', data['synced_count'] == 1)
_, own_a, _ = request('GET', '/progress/unit-progress/', user=a)
_, own_b, _ = request('GET', '/progress/unit-progress/', user=b)
check('A and B remain isolated after both synchronizations', own_a['count'] == 1 and own_b['count'] == 1
      and own_a['results'][0]['user'] != own_b['results'][0]['user']
      and own_a['results'][0]['lessons_seen'] == 8 and own_b['results'][0]['lessons_seen'] == 1)
identity = {'device_id': 'qa-http-guest', 'device_token': 'synthetic-http-guest-secret', 'unit_slug': unit}
data = sync({**identity, 'lessons_seen': 10, 'score_percent': 70, 'updated_at': '2026-11-09T10:00:00Z'})
check('guest registers and synchronizes over real HTTP', data['synced_count'] == 1)
data = sync({**identity, 'device_token': 'synthetic-wrong-token', 'lessons_seen': 99})
check('invalid guest token refused', data['error_count'] == 1 and data['synced_count'] == 0)
data = sync({**identity, 'lessons_seen': 1, 'score_percent': 0, 'updated_at': '2000-01-01T00:00:00Z'})
check('stale synchronization handled without HTTP error', data['synced_count'] == 1)
status, data, _ = request('GET', '/progress/unit-progress/?device_id=qa-http-guest', headers={'X-Device-Token': identity['device_token']})
check('conflict preserves counters and best score', status == 200 and data['count'] == 1
      and data['results'][0]['lessons_seen'] == 10 and data['results'][0]['best_score_percent'] == 70)
data = sync({**identity, 'lessons_seen': 10})
check('valid retry after rejection succeeds', data['synced_count'] == 1)
data = sync({'unit_slug': unit, 'device_id': 'qa-legacy', 'device_token': 'invented'})
check('legacy history not claimed without proof', data['error_count'] == 1)
result = {'scope': 'real HTTP local Django, synthetic accounts; not Android login UI',
          'token_expiration': 'No expiring account-token implementation exists; invalid bearer tested instead',
          'scenarios': rows}
(LAB / 'http_results.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
