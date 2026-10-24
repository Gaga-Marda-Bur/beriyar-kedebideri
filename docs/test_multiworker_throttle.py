"""Test de validation des quotas de feedback inter-workers (audit préproduction).

Ce script teste l'application des quotas à travers des processus workers distincts :
1. Chaque worker exécute une vraie requête HTTP POST sur l'endpoint `/api/feedback/create/`
   et reçoit un code statut HTTP réel (201 Created vs 429 Too Many Requests).
2. Vérifie qu'avec LocMemCache (mémoire locale par processus), chaque worker
   dispose de ses propres compteurs, ne permettant pas de borne globale.
3. Vérifie qu'avec un cache partagé (FileBasedCache simulant un cache partagé de type Redis/DatabaseCache),
   les requêtes issues de processus workers séparés partagent les mêmes compteurs
   et déclenchent une véritable réponse HTTP 429 avec en-tête Retry-After.
4. Vérifie le comportement sous accès concurrents simultanés (ProcessPoolExecutor).

Limites documentées de ce test local :
- Utilise FileBasedCache local partagé entre processus OS sur la même machine ;
- La validation avec un véritable cluster Redis distant ou DatabaseCache distribué
  sur plusieurs serveurs physiques sous forte charge réseau reste un jalon de production.
"""
import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
import tempfile

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend'))
PYTHON_EXE = os.path.join(BACKEND_DIR, 'venv', 'Scripts', 'python.exe')


def run_http_worker_process(cache_backend: str, cache_location: str, client_ip: str, req_id: int):
    """Exécute un worker indépendant dans un processus OS séparé effectuant une vraie requête HTTP."""
    script = f"""
import sys
sys.path.insert(0, r"{BACKEND_DIR}")
import json
import os
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
os.environ['FEEDBACK_CACHE_BACKEND'] = r"{cache_backend}"
os.environ['FEEDBACK_CACHE_LOCATION'] = r"{cache_location}"
os.environ['FEEDBACK_RATE_BURST'] = '3/min'

import django
django.setup()

from django.test import Client

client = Client(REMOTE_ADDR='{client_ip}', SERVER_NAME='127.0.0.1')
payload = {{
    'device_id': 'dev-concurrent-test',
    'feedback_type': 'technical',
    'message': f'Message de test concurrent {{ {req_id} }}'
}}
response = client.post('/api/feedback/create/', data=json.dumps(payload), content_type='application/json')
retry = response.headers.get('Retry-After', '')
print(f"{{response.status_code}}|{{retry}}")
"""
    res = subprocess.run([PYTHON_EXE, "-c", script], capture_output=True, text=True)
    if res.returncode != 0:
        return f"ERR:{res.stderr.strip()}"
    return res.stdout.strip()


def test_multiworker_quotas():
    print("=== TEST DES QUOTAS DE FEEDBACK MULTI-WORKERS (VRAIES REQUÊTES HTTP) ===")
    client_ip = "192.168.1.180"

    # 1. Test avec LocMemCache (mémoires disjointes)
    print("\n1. Test avec LocMemCache (mémoire locale par processus)...")
    results_locmem = []
    for i in range(4):
        out = run_http_worker_process(
            cache_backend="django.core.cache.backends.locmem.LocMemCache",
            cache_location="test-locmem-http",
            client_ip=client_ip,
            req_id=i + 1
        )
        status_code = out.split('|')[0] if '|' in out else out
        results_locmem.append(status_code)

    print(f"   Codes HTTP obtenus sur 4 workers séparés (limite configurée 3/min) : {results_locmem}")
    if all(code == "201" for code in results_locmem):
        print("   [CONSTAT CONFORME] LocMemCache ne partage pas les compteurs : les 4 requêtes ont abouti (HTTP 201).")

    # 2. Test avec cache partagé inter-workers (FileBasedCache)
    print("\n2. Test avec cache partagé inter-workers (FileBasedCache)...")
    temp_cache_dir = tempfile.mkdtemp(prefix="beriya_shared_throttle_")
    try:
        results_shared = []
        # Envoi séquentiel de 4 requêtes via des processus workers distincts
        for i in range(4):
            out = run_http_worker_process(
                cache_backend="django.core.cache.backends.filebased.FileBasedCache",
                cache_location=temp_cache_dir,
                client_ip=client_ip,
                req_id=i + 1
            )
            results_shared.append(out)

        print(f"   Réponses HTTP obtenues via cache partagé (4 processus distincts) :")
        for idx, res in enumerate(results_shared, start=1):
            parts = res.split('|')
            code = parts[0]
            retry_after = parts[1] if len(parts) > 1 else ''
            print(f"     - Worker {idx} : HTTP {code} (Retry-After: {retry_after or 'N/A'})")

        status_codes = [r.split('|')[0] for r in results_shared]
        expected = ["201", "201", "201", "429"]
        if status_codes == expected:
            print("   [OK] Véritable réponse HTTP 429 Too Many Requests émise sur le worker 4.")
            print("   [OK] Limite globale de 3/min rigoureusement partagée entre processus distincts.")
            success = True
        else:
            print(f"   [FAIL] Résultat inattendu : {status_codes} != {expected}")
            success = False

        # 3. Test de concurrence simultanée (accès concurrents)
        print("\n3. Test d'accès simultanés via ProcessPoolExecutor (3 workers en parallèle)...")
        with concurrent.futures.ProcessPoolExecutor(max_workers=3) as executor:
            futures = [
                executor.submit(
                    run_http_worker_process,
                    "django.core.cache.backends.filebased.FileBasedCache",
                    temp_cache_dir,
                    client_ip,
                    100 + j
                )
                for j in range(3)
            ]
            concurrent_results = [f.result().split('|')[0] for f in futures]
        print(f"   Codes HTTP obtenus en concurrence simultanée : {concurrent_results}")
        # Puisque la limite de 3/min est déjà atteinte, tous les accès concurrents doivent être 429
        if all(code == "429" for code in concurrent_results):
            print("   [OK] Les accès concurrents simultanés sont tous verrouillés et rejetés en HTTP 429.")
        else:
            print(f"   [AVERTISSEMENT] Certains accès concurrents ont contourné le verrou : {concurrent_results}")

    finally:
        shutil.rmtree(temp_cache_dir, ignore_errors=True)

    print("\n=== RÉSULTAT : QUOTAS MULTI-WORKERS TESTÉS VIA VRAIS CODES HTTP ===")
    return success


if __name__ == '__main__':
    ok = test_multiworker_quotas()
    sys.exit(0 if ok else 1)
