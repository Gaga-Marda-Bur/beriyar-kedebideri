# Compte-rendu de correction — A09 & A10 : Suppression du fallback silencieux, écran d'indisponibilité pédagogique et pagination API

**Date :** 2026-10-24  
**Branche Git :** `fix/a07-editorial-draft-protection`  
**Références audit :** [AUDIT_2026-10-23.md](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/AUDIT_2026-10-23.md) — Constats A09 (P1) et A10 (P1)

---

## 1. Contexte et objectifs

### A09 — Suppression du remplacement silencieux et protection contre les unités dépourvues
Avant cette intervention :
- `mobile/lib/features/learning/screens/learning_core_unit_screen.dart` contenait une méthode `_createFallbackUnit1()` avec plus de 60 lignes de JSON et de mots codés en dur (en contradiction directe avec la charte du projet et le README interdisant les contenus codés en dur).
- Lorsque le slug demandé n'était pas trouvé dans le cache ou l'API, le composant basculait silencieusement sur `units.first` (`found ??= units.first`), modifiant arbitrairement l'identité de l'unité suivie par l'apprenant.
- Pire encore, si une unité publiée n'avait aucun exercice actionnable (par exemple parce que ses dépendances de caractères ou de mots cibles sont encore en `draft` ou `review` suite aux protections A07), l'écran présentait uniquement l'étape finale de célébration (`celebration`), validait un score automatique et appelait `completeUnit()` sans qu'aucun apprentissage n'ait eu lieu.

### A10 — Suivi de la pagination API (DRF)
Avant cette intervention :
- Django REST Framework pagine les listes à 50 éléments par page (`PAGE_SIZE = 50`).
- La méthode `ApiClient.getList()` dans `mobile/lib/core/api/api_client.dart` récupérait uniquement la première page (`response['results']`) et ignorait l'attribut `next`.
- Dès lors qu'un endpoint contenait plus de 50 éléments (ex. les 101 caractères du corpus complet), les éléments au-delà du 50ème étaient tronqués et inaccessibles sur mobile.

---

## 2. Modifications apportées

### A. Correction A09 (`mobile/lib/features/learning/screens/learning_core_unit_screen.dart`)
1. **Suppression intégrale du fallback codé en dur :**
   - Retrait de `_createFallbackUnit1()`.
   - Retrait du repli silencieux `found ??= units.first`.
2. **Gestion explicite du slug manquant / non trouvé :**
   - Si l'unité demandée par `widget.unitSlug` n'est pas trouvée, un écran d'indisponibilité clair et instructif s'affiche :
     > *« Cette unité n'est pas disponible actuellement sur cet appareil (slug : `<slug>`). Veuillez vérifier votre connexion ou télécharger un pack hors ligne. »*
3. **Protection contre les unités privées de contenu pédagogique validé :**
   - L'écran analyse les étapes actionnables (`steps.where((s) => s['step_type'] != 'celebration')`).
   - Si aucune étape pédagogique valide n'est disponible (ex. dépendances en attente de révision éditoriale), un écran explicite est affiché :
     > *« Cette unité est en cours de validation pédagogique. Ses exercices ne sont pas encore prêts pour la pratique. »*
   - Verrouillage strict de `_finishUnit()` : aucune célébration factice, aucun calcul de score, et aucun appel à `completeUnit()` n'est exécuté si le nombre d'étapes actionnables est nul.
4. **Injection de dépendance pour la testabilité :**
   - Ajout d'un paramètre optionnel `contentService` dans le constructeur de `LearningCoreUnitScreen`, permettant l'injection de mocks/fakes étanches sans dépendre des accès réseau ou stockage réels lors des tests unitaires et d'intégration.

### B. Correction A10 (`mobile/lib/core/api/api_client.dart`)
1. **Suivi automatique et contrôlé de la pagination :**
   - Ajout des paramètres `followPagination: true` et `maxPages: 50` à la méthode `getList()`.
   - Itération tant que la réponse fournit un lien `next` valide et non nul.
2. **Sécurité SSRF et validation d'autorité :**
   - Implémentation du helper privé `_resolveUri(String pathOrUrl, [Map<String, dynamic>? queryParameters])`.
   - Si une URL absolue est renvoyée dans `next`, le client vérifie strictement que son `host` et son `scheme` correspondent exactement à ceux de `ApiConfig.baseUrl`. Tout lien pointant vers un hôte tiers est immédiatement rejeté avec une exception sécurisée `FormatException`.
3. **Déduplication et stabilité de l'ordre :**
   - Conservation de l'ordre original des résultats renvoyés par l'API.
   - Déduplication au fil de l'eau basée sur la clé primaire `item['id']` via un `Set` d'identifiants vus.
4. **Résilience et rétention des caches partiels :**
   - En cas d'interruption réseau lors du chargement d'une page ultérieure (ex. coupure à la page 2), les éléments déjà collectés sur la page 1 sont conservés et retournés plutôt que de lever une exception bloquante détruisant toute la liste.

---

## 3. Audit pré-déploiement des archives R2 / CDN

Dans le cadre des vérifications pré-déploiement recommandées :
- **Constat sur les archives existantes :**
  L'archive physique présente en local `backend/media/offline_packs/files/starter-beriya-erfe_v1_iMr8Evw.zip` (pack publié id 1) a été analysée :
  - Elle contient `themes.json` qui inclut le thème 1 (`status: draft` en base).
  - Elle contient `characters.json` qui inclut le caractère 1 (`validation_status: review` en base).
- **Cause racine :**
  Cette archive a été générée avant l'application de la protection A07 dans le générateur de packs hors ligne.
- **Protocole de quarantaine et recommandation d'exploitation :**
  1. Les archives ZIP existantes générées avant A07 sur Cloudflare R2 / CDN doivent être mises en **quarantaine** (ou dépubliées / renommées en version brouillon).
  2. Aucun pack publié ne doit être régénéré automatiquement tant que les responsables du corpus n'ont pas explicitement validé éditorialement le Thème 1 et le Caractère 1.
  3. Dès validation éditoriale par l'équipe, une nouvelle version de pack (ex. `v2`) sera générée de manière étanche par le générateur corrigé A07.

---

## 4. Tests et validation

### Tests Flutter (33/33 tests réussis)
1. **Tests unitaires et widgets A09 (`mobile/test/learning_core_test.dart`) :**
   - `deprived unit without characters has zero actionable exercises` : vérifie qu'une unité sans caractères validés a 0 étape actionnable.
   - `displays unavailable state when unit has no actionable exercises (no auto-completion)` : vérifie l'affichage de l'écran d'indisponibilité et l'absence de validation automatique / faux score.
   - `displays not available state for unknown slug without silent fallback to unit 1` : vérifie que la demande d'un slug inexistant n'affiche jamais l'unité 1 en douce.
2. **Tests unitaires A10 (`mobile/test/api_client_pagination_test.dart`) :**
   - Pagination multi-pages (page 1 + page 2 totalisant 51 items).
   - Déduplication correcte en cas de doublon d'ID inter-pages.
   - Rétention des résultats de la première page si la page suivante renvoie une erreur HTTP 500.
   - Rejet immédiat par `_resolveUri` des URL `next` dirigées vers un hôte malveillant tiers (SSRF).

### Tests Django (23/23 tests réussis)
- L'ensemble des 23 tests de l'application Django (`learning`, `alphabet`, `progress`, `offline_packs`, `audio_assets`, `quizzes`) continuent de s'exécuter avec 100 % de succès.
