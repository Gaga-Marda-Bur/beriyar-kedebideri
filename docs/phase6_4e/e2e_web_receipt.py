"""End-to-end browser session & HTTP receipt for Lot 6.4E."""
import http.cookiejar
import json
import re
import urllib.parse
import urllib.request

base = 'http://127.0.0.1:18770'
results = {}

# 1. Guest visitor journey
cj_guest = http.cookiejar.CookieJar()
opener_guest = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj_guest))

# 1.1 Home
req = urllib.request.Request(f'{base}/', headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
with opener_guest.open(req) as resp:
    home_html = resp.read().decode('utf-8')
    results['guest_home_status'] = resp.status
    results['guest_home_title_ok'] = 'Beřiyar Kedebideři' in home_html

# 1.2 Alphabet (Erfe script checking)
with opener_guest.open(f'{base}/alphabet/') as resp:
    alpha_html = resp.read().decode('utf-8')
    results['guest_alphabet_status'] = resp.status
    results['guest_erfe_char_present'] = '𖺠' in alpha_html
    results['guest_erfe_css_present'] = 'erfe' in alpha_html

# 1.3 Vocabulary
with opener_guest.open(f'{base}/vocabulaire/') as resp:
    vocab_html = resp.read().decode('utf-8')
    results['guest_vocab_status'] = resp.status
    results['guest_vocab_word_present'] = '𖺠𖺮' in vocab_html or 'Ber' in vocab_html

# 1.4 Lessons
with opener_guest.open(f'{base}/parcours/') as resp:
    results['guest_parcours_status'] = resp.status

# 2. Authenticated Journey: Login, CSRF, and Session rotation
cj_auth = http.cookiejar.CookieJar()
opener_auth = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj_auth))

# 2.1 Fetch CSRF bootstrap
with opener_auth.open(f'{base}/api/monetization/v1/session/csrf/') as resp:
    csrf_data = json.loads(resp.read().decode('utf-8'))
    csrf_token = csrf_data['csrf_token']
    results['csrf_bootstrap_ok'] = bool(csrf_token)

# 2.2 Login User A
login_payload = json.dumps({'username': 'web-customer-a', 'password': 'CustomerPassA2026!'}).encode('utf-8')
login_req = urllib.request.Request(
    f'{base}/api/monetization/v1/session/login/',
    data=login_payload,
    headers={
        'Content-Type': 'application/json',
        'X-CSRFToken': csrf_token,
        'Origin': base
    }
)
with opener_auth.open(login_req) as resp:
    login_data = json.loads(resp.read().decode('utf-8'))
    results['login_a_status'] = resp.status
    results['login_a_subject_ok'] = bool(login_data.get('subject'))
    session_cookies = [c.name for c in cj_auth]
    results['session_cookie_stored'] = 'sessionid' in session_cookies
    csrf_after_login = login_data.get('csrf_token')

# 2.3 Status for User A
status_req = urllib.request.Request(
    f'{base}/api/monetization/v1/session/',
    headers={'Origin': base}
)
with opener_auth.open(status_req) as resp:
    status_data = json.loads(resp.read().decode('utf-8'))
    results['status_a_match'] = status_data['subject'] == login_data['subject']

# 2.4 Logout User A
logout_req = urllib.request.Request(
    f'{base}/api/monetization/v1/session/logout/',
    data=b'{}',
    headers={
        'Content-Type': 'application/json',
        'X-CSRFToken': csrf_after_login or csrf_token,
        'Origin': base
    }
)
with opener_auth.open(logout_req) as resp:
    results['logout_a_status'] = resp.status

# 2.5 Verify session invalidated
try:
    with opener_auth.open(status_req) as resp:
        results['post_logout_status'] = resp.status
except urllib.error.HTTPError as e:
    results['post_logout_status'] = e.code  # Expected 401

# 3. Superadmin Admin UI verification
cj_admin = http.cookiejar.CookieJar()
opener_admin = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj_admin))

# 3.1 Get admin login page to extract CSRF
with opener_admin.open(f'{base}/admin-bk-secure-2026-panel/login/') as resp:
    admin_login_html = resp.read().decode('utf-8')
    admin_csrf_match = re.search(r'name="csrfmiddlewaretoken"\s+value="([^"]+)"', admin_login_html)
    admin_csrf = admin_csrf_match.group(1) if admin_csrf_match else ''

# 3.2 Post admin credentials
admin_payload = urllib.parse.urlencode({
    'username': 'web-superadmin',
    'password': 'WebPassword2026!',
    'csrfmiddlewaretoken': admin_csrf,
    'next': '/admin-bk-secure-2026-panel/'
}).encode('utf-8')

admin_req = urllib.request.Request(
    f'{base}/admin-bk-secure-2026-panel/login/',
    data=admin_payload,
    headers={'Content-Type': 'application/x-www-form-urlencoded', 'Referer': f'{base}/admin-bk-secure-2026-panel/login/'}
)
with opener_admin.open(admin_req) as resp:
    results['admin_login_status'] = resp.status
    results['admin_login_redirect'] = resp.url

# 3.3 Access Commercial Request Changelist
with opener_admin.open(f'{base}/admin-bk-secure-2026-panel/monetization/commercialrequest/') as resp:
    req_html = resp.read().decode('utf-8')
    results['admin_commercial_req_ok'] = 'commercial' in req_html.lower()

# 3.4 Access Entitlement Grants (Read Only Admin)
with opener_admin.open(f'{base}/admin-bk-secure-2026-panel/monetization/entitlementgrant/') as resp:
    grant_html = resp.read().decode('utf-8')
    results['admin_grants_view_ok'] = resp.status == 200

print(json.dumps(results, indent=2, ensure_ascii=False))
