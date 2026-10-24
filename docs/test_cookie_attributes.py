"""Test de vérification des attributs des cookies (audit préproduction).

Vérifie rigoureusement les attributs attendus par cookie :
1. En configuration de développement :
   - sessionid : HttpOnly=True, SameSite=Lax, Secure=False
   - csrftoken : HttpOnly=False (accessible à JS), SameSite=Lax, Secure=False
2. En configuration de production (DJANGO_ENV=production) :
   - sessionid : HttpOnly=True, SameSite=Lax, Secure=True
   - csrftoken : HttpOnly=False (accessible à JS), SameSite=Lax, Secure=True
3. Sur requête HTTP réelle (émulateur client Django) :
   - Présence OBLIGATOIRE du cookie csrftoken sur `/feedback/` (échec strict si absent)
   - Vérification de l'absence du flag HttpOnly sur csrftoken
   - Vérification du flag SameSite=Lax sur csrftoken
   - Création de session et vérification de la présence du flag HttpOnly=True sur sessionid
   - Avec override_settings(CSRF_COOKIE_SECURE=True), vérification que Django positionne
     lui-même le flag `secure=True` sur le cookie émis.

Précision d'architecture :
- L'attribut `Secure` est fixé directement par les réglages de Django (SESSION_COOKIE_SECURE
  et CSRF_COOKIE_SECURE).
- Le proxy inverse ne détermine pas cet attribut : il assure la terminaison TLS / HTTPS
  permettant aux navigateurs et clients de recevoir et d'honorer ces cookies sécurisés.
"""
import os
import sys

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend'))
sys.path.insert(0, BACKEND_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'

import django
django.setup()

from config.security import build_security_settings
from django.test import Client, override_settings


def test_cookie_security_rules():
    print("=== TEST DES ATTRIBUTS DE COOKIES (SESSION & CSRF) ===")

    # 1. Analyse des réglages générés pour le développement
    print("\n1. Vérification des réglages de cookies en DÉVELOPPEMENT...")
    dev_env = {
        'DJANGO_ENV': 'development',
        'DEBUG': 'True',
    }
    dev_sec = build_security_settings(lambda k: dev_env.get(k))

    assert dev_sec['SESSION_COOKIE_HTTPONLY'] is True, "sessionid doit être HttpOnly"
    assert dev_sec['CSRF_COOKIE_HTTPONLY'] is False, "csrftoken ne doit PAS être HttpOnly (requis pour lecture JS)"
    assert dev_sec['SESSION_COOKIE_SAMESITE'] == 'Lax', "sessionid SameSite doit être Lax"
    assert dev_sec['CSRF_COOKIE_SAMESITE'] == 'Lax', "csrftoken SameSite doit être Lax"
    assert dev_sec['SESSION_COOKIE_SECURE'] is False, "sessionid Secure=False en local"
    assert dev_sec['CSRF_COOKIE_SECURE'] is False, "csrftoken Secure=False en local"
    print("   [OK] Session : HttpOnly=True, SameSite=Lax, Secure=False")
    print("   [OK] CSRF    : HttpOnly=False (accessible JS), SameSite=Lax, Secure=False")

    # 2. Analyse des réglages générés pour la PRODUCTION
    print("\n2. Vérification des réglages de cookies en PRODUCTION...")
    prod_env = {
        'DJANGO_ENV': 'production',
        'DEBUG': 'False',
        'SECRET_KEY': 'c3ec9a87d03f44199c049b4c09d571861788c03781c4e7ab68b0e774205f15f0',
        'ALLOWED_HOSTS': 'beriyarkedebideri.com',
        'TRUST_X_FORWARDED_PROTO': 'True',
        'NUM_PROXIES': '1',
    }
    prod_sec = build_security_settings(lambda k: prod_env.get(k))

    assert prod_sec['SESSION_COOKIE_HTTPONLY'] is True, "sessionid doit rester HttpOnly en prod"
    assert prod_sec['CSRF_COOKIE_HTTPONLY'] is False, "csrftoken doit rester accessible à JS en prod (X-CSRFToken)"
    assert prod_sec['SESSION_COOKIE_SAMESITE'] == 'Lax', "sessionid SameSite doit être Lax"
    assert prod_sec['CSRF_COOKIE_SAMESITE'] == 'Lax', "csrftoken SameSite doit être Lax"
    assert prod_sec['SESSION_COOKIE_SECURE'] is True, "sessionid Secure=True obligatoire en prod"
    assert prod_sec['CSRF_COOKIE_SECURE'] is True, "csrftoken Secure=True obligatoire en prod"
    print("   [OK] Session : HttpOnly=True, SameSite=Lax, Secure=True")
    print("   [OK] CSRF    : HttpOnly=False (accessible JS), SameSite=Lax, Secure=True")

    # 3. Test HTTP réel avec le client Django : émission et attributs des cookies
    print("\n3. Vérification des en-têtes Set-Cookie émis par les requêtes web...")
    client = Client(enforce_csrf_checks=True, SERVER_NAME='127.0.0.1')
    response = client.get('/feedback/', SERVER_NAME='127.0.0.1')

    # Exiger impérativement la présence du cookie CSRF (pas de passage silencieux)
    assert 'csrftoken' in response.cookies, "ÉCHEC : Le cookie csrftoken doit OBLIGATOIREMENT être émis par la vue web"
    csrf_cookie = response.cookies['csrftoken']
    print(f"   [OK] Cookie csrftoken émis : value={csrf_cookie.value[:8]}...")
    print(f"        httponly={csrf_cookie.get('httponly')!r} (doit être False ou vide)")
    print(f"        samesite={csrf_cookie.get('samesite')!r} (attendu: Lax)")
    assert not csrf_cookie.get('httponly'), "csrftoken ne doit pas avoir le flag HttpOnly"
    assert csrf_cookie.get('samesite') == 'Lax', "csrftoken doit avoir samesite=Lax"

    # Vérification du cookie sessionid lors d'une session active
    session = client.session
    session['test_auth_probe'] = True
    session.save()
    resp_session = client.get('/feedback/', SERVER_NAME='127.0.0.1')
    assert 'sessionid' in client.cookies, "ÉCHEC : Le cookie sessionid doit être présent dans la session client"
    session_cookie = client.cookies['sessionid']
    print(f"   [OK] Cookie sessionid émis : value={session_cookie.value[:8]}...")
    print(f"        httponly={session_cookie.get('httponly')!r} (doit être True)")
    print(f"        samesite={session_cookie.get('samesite')!r} (attendu: Lax)")
    assert session_cookie.get('httponly') is True, "sessionid doit impérativement avoir le flag HttpOnly=True"
    assert session_cookie.get('samesite') == 'Lax', "sessionid doit avoir samesite=Lax"

    # 4. Vérification que Django positionne lui-même le flag Secure=True lorsque les réglages l'ordonnent
    print("\n4. Vérification de l'attribut Secure émis par Django...")
    with override_settings(CSRF_COOKIE_SECURE=True, SESSION_COOKIE_SECURE=True):
        client_sec = Client(enforce_csrf_checks=True, SERVER_NAME='127.0.0.1')
        resp_sec = client_sec.get('/feedback/', SERVER_NAME='127.0.0.1', secure=True)
        assert 'csrftoken' in resp_sec.cookies, "csrftoken manquant sous SSL simulé"
        sec_cookie = resp_sec.cookies['csrftoken']
        print(f"   [OK] csrftoken avec CSRF_COOKIE_SECURE=True : secure={sec_cookie.get('secure')!r} (doit être True)")
        assert sec_cookie.get('secure') is True, "Django doit fixer lui-même l'attribut Secure"

    print("\n=== RÉSULTAT : CONTRÔLE DES ATTRIBUTS DE COOKIES VALIDÉ (AVEC RESTRICTIONS DOCUMENTÉES) ===")
    return True


if __name__ == '__main__':
    ok = test_cookie_security_rules()
    sys.exit(0 if ok else 1)
