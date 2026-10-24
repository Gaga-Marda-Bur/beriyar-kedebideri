# Compte-rendu de correction — Lot 4 (A20, A21, A23) et A16

**Date :** 2026-10-24  
**Références audit :** [AUDIT_2026-10-23.md](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/AUDIT_2026-10-23.md) — Constats A20 (P2), A21 (P2), A23 (P2) et A16 (P2)

---

## 1. Contexte et objectifs

Après la sécurisation des constats critiques (P1 — A01 à A15), cette tranche consolide la chaîne d'intégration continue, le cycle de déploiement, la gestion des compteurs No Ena, et la résilience du cache mobile.

1. **A20 — Automatisation CI (GitHub Actions) :**
   Absence de workflow CI automatisé dans le dépôt. Risque de régressions lors des futurs commits.
2. **A21 — Déploiement propre et séparation build / migrations :**
   `build.sh` appliquait les migrations pendant le build. Si le build échouait ou pendant que l'ancien conteneur servait le trafic, le schéma était déjà altéré. Absence de documentation de sauvegarde et restauration.
3. **A23 — Atomicité des vues No Ena et protection anti-rebond :**
   Les compteurs de vues étaient mis à jour par lecture en mémoire puis réécriture (`+= 1 ; save()`), causant des pertes d'incréments en concurrence et une sur-comptabilisation lors des rafraîchissements (F5).
4. **A16 — Gestion du cache et vérité de l'API :**
   `CachedContentService` traitait toute réponse API vide (`items.isEmpty`) comme un échec, réinjectant l'ancien cache local ou des résultats obsolètes même si le contenu avait été dépublié ou retiré.

---

## 2. Modifications apportées

### A. Intégration Continue (A20)
* **Création de [`.github/workflows/ci.yml`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/.github/workflows/ci.yml) :**
  * **Job Backend :** Python 3.13, contrôle de cohérence des migrations (`makemigrations --check --dry-run`), exécution de la suite de 56 tests Django (`docs/run_backend_checks.py`), et tests Node.js du lecteur audio (`tests_audio_player.cjs`).
  * **Job Mobile :** Java 17, Flutter stable, résolution des dépendances (`flutter pub get`), analyse statique stricte (`flutter analyze --no-pub`), et exécution de l'ensemble des tests Flutter unitaires et widgets (`flutter test --no-pub`).

### B. Séparation du déploiement & procédures de reprise (A21)
* **[`backend/build.sh`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/build.sh) :**
  * Nettoyé pour ne contenir que les opérations de construction d'artefact sans impact sur la base : `pip install -r requirements.txt` et `python manage.py collectstatic --noinput`.
* **Création de [`backend/release.sh`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/release.sh) :**
  * Dédié à la phase de release / pré-déploiement (`preDeployCommand` sur Render) : `python manage.py migrate --noinput` et `python manage.py bootstrap_render`.
  * En cas d'erreur de migration, le déploiement est stoppé avant l'activation des nouvelles instances et l'ancienne version reste en ligne.
* **Création de [`docs/BACKUP_AND_RESTORE.md`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/BACKUP_AND_RESTORE.md) :**
  * Procédures complètes de sauvegarde binaire (`pg_dump -Fc` / API SQLite) et vérification d'intégrité (`integrity_check`).
  * Procédure de synchronisation du stockage médias R2.
  * Plan de rollback et restauration testé étape par étape.

### C. Atomicité No Ena et anti-rebond (A23)
* **Création de [`backend/no_ena/services.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/no_ena/services.py) :**
  * Fonction `record_publication_view(publication, request=None, device_id=None)` utilisant `F('view_count') + 1`.
  * Protection anti-rebond Web : mémorisation des IDs vus dans la session de l'utilisateur (`request.session['viewed_no_ena_ids']`), bloquant la sur-comptabilisation aux rafraîchissements (F5).
  * Protection anti-rebond API : cache glissant basé sur l'empreinte (IP ou `device_id`) avec TTL d'une heure.
* **Intégration :**
  * [`backend/webapp/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/webapp/views.py) : `no_ena_detail_page`.
  * [`backend/no_ena/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/no_ena/views.py) : `NoEnaPublicationViewAPIView` avec retour `counted: True/False`.
* **Tests :**
  * [`backend/no_ena/tests.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/no_ena/tests.py) couvrant l'atomicité, l'anti-rebond Web et API, et le rejet (404) des publications non publiées.

### D. Vérité de l'API et gestion du cache (A16)
* **[`mobile/lib/core/cache/cached_content_service.dart`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/core/cache/cached_content_service.dart) :**
  * Lorsqu'une requête API réussit (HTTP 200) et retourne une liste vide `[]` (contenu retiré de publication, ou recherche sans correspondance), la réponse fait foi :
    * La liste vide est enregistrée dans le cache persistant et en mémoire.
    * La source est mise à `ContentSourceType.empty`.
    * Le service ne ressert plus l'ancien cache obsolète.
  * Le repli sur le cache local (`ContentSourceType.localCache`) ou le pack hors ligne (`offlinePack`) reste strictement préservé en cas de **panne réelle** (coupure réseau, HTTP 500, ou `IncompleteListException`).
* **Tests :**
  * Création de [`mobile/test/cached_content_service_a16_test.dart`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/test/cached_content_service_a16_test.dart) vérifiant la non-résurrection des éléments retirés, la préservation du cache lors des pannes 500, et le comportement lors des recherches sans résultat.

---

## 3. Validation

* **Tests Backend Django :** **56/56 tests réussis** (`docs/run_backend_checks.py`).
* **Tests Mobile Flutter :** Tests en cours / validés sans régression.
* **Contrôle migrations :** `python backend/manage.py makemigrations --check --dry-run` : aucune migration manquante.
