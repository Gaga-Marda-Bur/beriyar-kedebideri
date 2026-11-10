# BERIYAR KEDEBIDERI — LOT 4B.3
## Répétition espacée locale (SRS) et mémorisation audio-first

**Date** : 10 novembre 2026  
**Branche Git** : `feature/phase4-ux-ui-audio-first`  
**Référence socle Phase 3.1** : `ce4b043`  
**Référence Lot 4B.2** : `7756d42`

---

## 1. Audit des progressions existantes (Étape 1)

| Composant existant | Rôle actuel | Stratégie d'intégration Lot 4B.3 |
|---|---|---|
| `LearningSession` (`learning/engine/learning_session.dart`) | Calcule les scores d'une unité par catégorie (`recognition`, `tracing`, `encoding`), suit `answers[stepIndex]` (`attempts`, `successes`, `first_correct`) et l'état de complétion de la séance. | **Conservé intact.** `LearningCoreUnitScreen` observe le premier essai (`isFirstAttempt`) sur chaque étape d'évaluation et alimente `LocalSrsService` sans modifier le calcul du score de l'unité. |
| `UnitProgressLocalStorage` (`progress/services/unit_progress_local_storage.dart`) | Persiste l'avancement par unité (`unitSlug`), le meilleur score, le statut `completed`, la session en cours et l'indicateur `dirty` pour la synchronisation serveur. | **Conservé comme unique source de vérité de la progression d'unité.** Aucun système concurrent de progression d'unité n'a été créé. |
| `UnitProgressSyncService` (`progress/services/unit_progress_sync_service.dart`) | Synchronise les progressions d'unités (`UnitProgressLocalModel`) avec l'API backend (`/api/v1/progress/`). | **Inchangé.** Aucune nouvelle donnée sensible ou hors contrat API n'est envoyée au backend. |
| Identifiants des éléments pédagogiques (`CharacterModel`, `WordModel`, packs hors ligne) | Les ID numériques (`id`) peuvent varier entre l'API et les packs hors ligne (`0` ou réindexés), et les libellés français ou chemins audio changent lors des mises à jour. En revanche, la graphie Unicode Erfe (`symbol` / `beriyaText`) est invariante. | **Identité stable retenue** : `SrsItemRecord.buildStableId(itemType, erfeText)` produit `char:<erfe_normalisé>` (ex. `char:𖺡`) ou `word:<erfe_normalisé>` (ex. `word:𖺡𖺣`). |

---

## 2. Modèle et Service SRS local (Étape 2)

### Fichiers créés
- [`mobile/lib/features/learning/srs/srs_item_model.dart`](../mobile/lib/features/learning/srs/srs_item_model.dart) : Modèle immuable `SrsItemRecord`.
- [`mobile/lib/features/learning/srs/local_srs_service.dart`](../mobile/lib/features/learning/srs/local_srs_service.dart) : Service local indépendant `LocalSrsService`.

### Champs conservés par élément (`SrsItemRecord`)
- `stableId` : identifiant stable inter-versions (`char:<symbole>` ou `word:<mot>`).
- `lastReviewedAt` : date/heure UTC de dernière révision.
- `nextReviewAt` : date/heure UTC de prochaine révision programmée.
- `masteryLevel` : niveau de maîtrise de `0` à `5`.
- `successCount` : nombre total de réussites.
- `errorCount` : nombre total d'erreurs.
- `consecutiveSuccesses` : série de réussites consécutives.
- `intervalDays` : intervalle de révision actif en jours (`1`, `3`, `7`, `14`, `30`).
- `easeFactor` : facteur d'aisance SM-2 simplifié (`1.3` à `2.5`, initialisé à `2.5`).

### Algorithme d'adaptation des intervalles
- **Paliers de base** : `[1, 3, 7, 14, 30]` jours selon `masteryLevel` (`1..5`).
- **Réussite (`correct == true`)** :
  - `masteryLevel = (masteryLevel + 1).clamp(1, 5)`
  - `consecutiveSuccesses += 1`, `successCount += 1`
  - `easeFactor = (easeFactor + 0.1).clamp(1.3, 2.5)`
  - Si l'élément a connu de nombreuses erreurs passées (`easeFactor < 1.7`), la progression utilise le palier prudent inférieur.
- **Erreur (`correct == false` avec audio disponible)** :
  - `errorCount += 1`, `consecutiveSuccesses = 0`
  - `masteryLevel = (masteryLevel - 1).clamp(0, 5)`
  - `easeFactor = (easeFactor - 0.2).clamp(1.3, 2.5)`
  - `intervalDays = 1` (reprogrammation à J+1 et marquage `isDifficult == true`).
- **Audio absent (`audioMissing == true && !correct`)** :
  - **Aucune pénalité** : `errorCount`, `consecutiveSuccesses`, `masteryLevel` et `intervalDays` restent intacts.
- **Réponse vide (`submittedAnswer` vide après normalisation)** :
  - Ignorée sans pénalité ni création d'enregistrement parasite.

---

## 3. Intégration pédagogique et interface minimale de révision (Étape 3)

1. **Enregistrement en fin d'exercice (`LearningCoreUnitScreen`)** :
   - Lors du premier essai sur chaque exercice de reconnaissance (`discrimination`) ou de composition (`keyboard_encoding`), `_recordStepSrs` enregistre le résultat dans `LocalSrsService` en passant `audioMissing: !_stepHasAudio(step)`.
2. **Récapitulatif enrichi à l'étape 5 (`RÉVISER`)** :
   - Les puces des éléments réussis et des éléments à consolider affichent désormais l'intervalle SRS programmé (`+1 j`, `+3 j`, etc.) aux côtés du bouton de réécoute.
   - Le bouton `launch-srs-review-button` (« Séance de révision espacée ») permet de lancer immédiatement une séance SRS ciblée sur les éléments dus ou difficiles.
3. **Accès depuis le détail d'unité (`UnitDetailScreen`)** :
   - Lorsqu'une unité comporte des éléments arrivés à échéance ou difficiles, le bouton `unit-detail-srs-review-button` (« Révision espacée (X à revoir) ») s'affiche automatiquement.
4. **Interface minimale de révision (`SrsReviewSessionScreen`)** :
   - Fichier : [`mobile/lib/features/learning/screens/srs_review_session_screen.dart`](../mobile/lib/features/learning/screens/srs_review_session_screen.dart).
   - **Zéro révélation prématurée** : l'invite affiche uniquement l'instruction d'écoute (et le sens en français ou le phonème IPA), ainsi que `BkAudioHeroButton`. La graphie Erfe cible n'est révélée dans `BkFeedbackSheet` qu'après la sélection d'une carte `BkOptionCard`.
   - **Protection audio absent** : si un élément révisé n'a pas d'audio disponible, le bandeau `srs-audio-missing-banner` s'affiche et aucune erreur n'est pénalisée.

---

## 4. Fonctionnement hors ligne, réimport et isolation des données (Étape 4)

- **100 % hors ligne** : stockage JSON atomique dans `SharedPreferences` sous la clé `bk_srs_v1_<userScope>`, sans aucun appel réseau requis.
- **Survie aux fermetures, redémarrages et mises à jour de packs** :
  - `reconcileWithUnit(LearningUnitModel unit)` met à jour les métadonnées descriptives (`translationFr`, `phonemeIpa`, `latinTranscription`, `audioUrl` local issu du pack) en se basant sur `stableId` (`char:<symbole>` / `word:<mot>`), **sans jamais écraser** les compteurs SRS ni les dates d'échéance.
  - `getDueItems(allowedStableIds: ...)` filtre proprement les éléments qui auraient été supprimés d'une nouvelle version de pack sans provoquer d'erreur.
- **Isolation par utilisateur et stratégie invité / compte** :
  - Chaque `userScope` (`guest` par défaut, ou identifiant de compte) dispose d'un espace de stockage isolé (`bk_srs_v1_<userScope>`).
  - La méthode `migrateGuestToAccount({guestScope, accountScope})` fusionne les révisions acquises en mode invité vers un compte utilisateur en conservant toujours l'enregistrement le plus récent (`lastReviewedAt`).
  - **Synchronisation distante** : conformément aux directives, aucune synchronisation serveur des compteurs SRS granulaires n'est activée tant qu'un contrat API dédié n'est pas validé.

---

## 5. Tests exécutés et résultats (Étape 5)

Suite dédiée créée dans [`mobile/test/lot_4b_3_srs_test.dart`](../mobile/test/lot_4b_3_srs_test.dart) couvrant les 11 cas exigés :

| # | Cas de test | Statut |
|---|---|---|
| 1 | Première réussite (`intervalDays = 1`, `masteryLevel = 1`, `successCount = 1`) | PASS |
| 2 | Réussites successives (progression sur les paliers `1, 3, 7, 14, 30` jours) | PASS |
| 3 | Réponse incorrecte (`errorCount` incrémenté, série remise à 0, intervalle ramené à `1 j`, `isDifficult = true`) | PASS |
| 4 | Réponse vide (`submittedAnswer: '   '` ignorée sans pénalité ni entrée fantôme) | PASS |
| 5 | Audio absent (`audioMissing: true, correct: false` n'applique aucune pénalité SRS) | PASS |
| 6 | Élément supprimé ou renommé (`reconcileWithUnit` met à jour le libellé/audio, `allowedStableIds` filtre l'élément supprimé) | PASS |
| 7 | Changement de date et recul d'horloge système (calcul d'échéance à J+1 et normalisation si horloge reculée) | PASS |
| 8 | Réimport d'un pack v2 (conservation intégrale des compteurs et échéances SRS) | PASS |
| 9 | Fonctionnement 100 % hors ligne | PASS |
| 10 | Persistance après redémarrage (nouvelle instance `LocalSrsService` relisant `SharedPreferences`) | PASS |
| 11 | Isolation entre utilisateurs (`user_a` vs `user_b`) et migration invité -> compte (`migrateGuestToAccount`) | PASS |
| 12 | Widget tests `SrsReviewSessionScreen` & `LearningCoreUnitScreen` (non-révélation prématurée, bandeau audio absent, bilan SRS) | PASS |

---

## 6. Recette Android (Étape 6)

- **Vérification ADB du téléphone réel Samsung `SM-A336E` (`R6CT6003WRT`)** :
  - Commande exécutée : `adb.exe devices -l`
  - Statut retourné par ADB : `R6CT6003WRT unauthorized transport_id:1`
  - **Conformément aux règles strictes de l'Étape 6** : le téléphone physique étant actuellement en état `unauthorized` (invite d'autorisation du débogage USB RSA non encore acceptée sur l'écran du téléphone), **la recette sur téléphone Android réel est déclarée EN ATTENTE (NON VALIDÉE)** jusqu'à l'acceptation de l'invite RSA sur le Samsung `SM-A336E`.

---

## 7. Risques, limites et décision GO / NO-GO

### Risques et limites résiduels
1. **Recette physique Samsung `SM-A336E` en attente d'autorisation ADB** : le code est prêt et vérifié par l'ensemble des tests automatisés et l'analyse statique, mais l'exécution interactive sur le téléphone réel requiert l'acceptation de la boîte de dialogue « Autoriser le débogage USB » sur l'appareil `R6CT6003WRT`.
2. **Synchronisation multi-appareils du SRS** : le SRS fonctionne 100 % en local (`SharedPreferences`) conformément à l'interdiction de modifier les contrats API sans validation préalable.

### Décision
- **Validation technique locale (Code, Tests unitaires/widgets, Analyse statique)** : **GO Technique**.
- **Validation recette téléphone physique Android (`SM-A336E`)** : **EN ATTENTE D'AUTORISATION ADB (`unauthorized`)** — nous attendons votre validation (et, si vous le souhaitez, l'acceptation de l'invite USB sur le Samsung) avant d'entamer la suite.
