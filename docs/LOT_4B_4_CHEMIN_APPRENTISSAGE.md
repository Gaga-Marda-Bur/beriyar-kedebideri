# BERIYAR KEDEBIDERI — LOT 4B.4
## Modernisation du chemin d'apprentissage (Parcours A & B)

**Date** : 10 novembre 2026  
**Branche Git** : `feature/phase4-ux-ui-audio-first`  
**Socle de référence Phase 3.1** : `ce4b043`  
**Lot 4B.3 précédent** : `5f6ab11`

---

## 1. Vérification préalable de la recette Android SRS

- **Vérification ADB du téléphone réel Samsung `SM-A336E` (`R6CT6003WRT`)** :
  - Commande exécutée : `adb.exe devices -l`
  - Statut retourné : `R6CT6003WRT authorizing product:a33xnsdtur model:SM_A336E`
  - **Conformément aux consignes du Lot 4B.4** : le téléphone réel demeurant inaccessible via ADB (`authorizing` / `unauthorized` en attente d'acceptation de l'invite RSA sur l'écran physique du Samsung), cette limite est explicitement signalée et **aucune validation sur téléphone physique n'est déclarée comme réalisée**. L'ensemble des vérifications d'intégration, de rendu multi-écrans (`320×568`, `360×800`, `412×915`), de thèmes clair/sombre et de répétition espacée est validé via la suite de tests automatisés Flutter.

---

## 2. Chemin d'apprentissage modernisé (`LearningPathScreen`)

L'écran [`mobile/lib/features/learning/screens/learning_path_screen.dart`](../mobile/lib/features/learning/screens/learning_path_screen.dart) a été modernisé selon le Design System **Sahel Modern** en réutilisant strictement `UnitProgressLocalStorage`, `LocalSrsService` et `BkLearningNode`, sans créer de nouveau moteur de progression ni dupliquer les données :

1. **Choix explicite entre Parcours A et Parcours B (`learning-track-selector`)** :
   - **Parcours A (`track-selector-a`)** : *« Je parle Beřiya, j'apprends l'Erfe »* — chemin audio-first guidé avec nœuds `BkLearningNode`, connecteurs visuels, mise en avant de la prochaine activité et intégration SRS.
   - **Parcours B (`track-selector-b`)** : *« J'apprends le Beřiya et l'Erfe »* — catalogue thématique libre préservant intégralement l'accès direct à toutes les unités, fiches de détail (`UnitDetailScreen`), vocabulaire, leçons et quiz classiques sans imposer le verrouillage séquentiel du Parcours A.
2. **Nœuds d'unités `BkLearningNode` et distinction des 5 états** :
   - `LearningPathScreen.resolveNodeStatus` détermine l'état de chaque unité à partir de `UnitProgressLocalModel` et des échéances `LocalSrsService` :
     - `locked` (`Verrouillé`) : unité non commencée dont l'unité précédente n'est pas encore validée.
     - `available` (`Disponible`) : première unité ou unité immédiatement débloquée après la validation de la précédente.
     - `inProgress` (`En cours`) : unité commencée (`currentStep > 0` ou `quizzesAnswered > 0`) mais non encore terminée, avec anneau de progression proportionnel (`resolveNodeProgress`).
     - `completed` (`Terminé`) : unité validée (`completed == true`) sans élément SRS arrivé à échéance.
     - `reviewDue` (`À réviser (N)`) : unité ayant un ou plusieurs éléments SRS arrivés à échéance ou marqués difficiles.
   - Extraction automatique du premier glyphe Unicode Erfe (`U+16EA0..U+16EDF`) via `extractErfeSymbol` pour l'afficher au cœur du nœud `BkLearningNode` en police `Kedebideri`.
3. **Mise en évidence de la prochaine activité recommandée (`recommended-next-activity-card`)** :
   - Carte prioritaire en tête du Parcours A mettant en avant :
     1. L'unité `inProgress` à reprendre en priorité,
     2. À défaut, l'unité `reviewDue` ayant des révisions SRS à effectuer,
     3. À défaut, la première unité `available` à démarrer,
     4. Ou la consolidation si toutes les unités sont terminées.
   - Remplace l'ancien encart statique qui mentionnait encore *« Tracé tactile guidé, fusion syllabique glisser-déposer »*.
4. **Compteur d'éléments à réviser et accès direct aux révisions SRS (`learning-path-srs-banner`)** :
   - Affiche en permanence le nombre exact d'éléments arrivés à échéance (`learning-path-srs-count`, ex. `1 élément(s) à réviser` ou `0 élément à réviser maintenant`).
   - Bouton direct `learning-path-srs-review-button` ouvrant `SrsReviewSessionScreen` en un clic et rafraîchissant automatiquement l'état du parcours au retour.
   - Bouton SRS individuel (`unit-srs-action-<slug>`) également présent sur chaque unité en état `reviewDue`.
5. **Conservation de l'accès aux packs installés hors ligne** :
   - Bouton d'action dans l'AppBar (`learning-path-offline-packs-action`) **et** carte dédiée (`learning-path-offline-packs-card` / `learning-path-offline-packs-button`) ouvrant `OfflinePacksScreen` en mode hors ligne comme en ligne.
6. **Indicateurs de réussite discrets (`discreet-progress-summary`)** :
   - Badges sobres affichant `X / Y unités validées`, `Z élément(s) mémorisé(s)` et le meilleur score en pourcentage sur les unités validées, sans mécanisme de récompense artificiel ou intrusif.

---

## 3. Comparaison Avant / Après

| Dimension | Avant (Phase 3.1 / Lot 4B.3) | Après (Lot 4B.4) |
|---|---|---|
| **Architecture visuelle du parcours** | Liste uniforme de tuiles `_UnitTile` sur fond sombre codé en dur (`Colors.white70`, `Colors.black`). | Chemin connecté vertical utilisant `BkLearningNode`, `BkThemePalette` (clair & sombre), `AppTokens` et `GlassCard`. |
| **États des unités** | Binaire uniquement (`isCompleted` oui/non). | **5 états distincts** par icône, anneau, badge et sémantique : `locked`, `available`, `inProgress`, `completed`, `reviewDue`. |
| **Carte d'appel principal** | Encart statique codé en dur mentionnant le tracé manuscrit (*« Tracé tactile guidé... »*). | Carte dynamique `recommended-next-activity-card` ciblant la prochaine activité réelle (reprise, révision SRS ou nouvelle unité audio-first). |
| **Répétition espacée (SRS)** | Accessible uniquement depuis la fin d'une leçon ou la fiche de détail d'une unité. | Bandeau dédié `learning-path-srs-banner` avec compteur global + lancement direct de `SrsReviewSessionScreen` + bouton par unité due. |
| **Distinction Parcours A / Parcours B** | Absente (un seul affichage mixte). | Sélecteur explicite **Parcours A** (audio-first guidé) / **Parcours B** (exploration thématique libre préservée sans verrouillage imposé). |
| **Accessibilité & Thèmes** | Couleurs blanches figées illisibles en thème clair ; risque de débordement à `TextScaler 1.3x`. | Compatible thèmes Clair et Sombre, `TextScaler 1.3x` et écrans étroits (`320×568`, `360×800`) sans aucun débordement. |

---

## 4. Liste des fichiers créés ou modifiés

| Fichier | Nature de l'intervention |
|---|---|
| [`mobile/lib/features/learning/screens/learning_path_screen.dart`](../mobile/lib/features/learning/screens/learning_path_screen.dart) | Modernisation complète du chemin d'apprentissage (sélecteur Parcours A/B, nœuds `BkLearningNode` 5 états, prochaine activité recommandée, bandeau SRS direct, accès packs hors ligne, indicateurs discrets, support clair/sombre et `TextScaler 1.3x`). |
| [`mobile/test/lot_4b_4_learning_path_test.dart`](../mobile/test/lot_4b_4_learning_path_test.dart) | Suite de tests unitaires et widgets dédiée au Lot 4B.4. |
| [`docs/LOT_4B_4_CHEMIN_APPRENTISSAGE.md`](LOT_4B_4_CHEMIN_APPRENTISSAGE.md) | Rapport de livraison, comparaison avant/après, non-régression et décision GO / NO-GO. |

---

## 5. Tests exécutés et rapport de non-régression

- **Tests ciblés Lot 4B.4 (`flutter test test/lot_4b_4_learning_path_test.dart`)** : **5 / 5 réussis** :
  1. Logique déterministe des 5 états `BkLearningNodeStatus` (`locked`, `available`, `inProgress`, `completed`, `reviewDue`) et calcul du ratio de progression.
  2. Extraction Unicode des caractères Erfe (`U+16EA0..U+16EDF`).
  3. Parcours A complet : affichage des nœuds `BkLearningNode` dans leurs différents états, carte de prochaine activité recommandée, compteur d'éléments SRS à réviser, lancement direct de `SrsReviewSessionScreen` et accès aux packs hors ligne.
  4. Sélecteur Parcours A / Parcours B : vérification que le Parcours B conserve l'accès libre à toutes les unités et à `UnitDetailScreen` sans verrouillage séquentiel.
  5. Accessibilité multi-tailles (`320×568`, `360×800`), thèmes Clair et Sombre et `TextScaler.linear(1.3)` sans aucun débordement (`RenderFlex`).
- **Suite globale Flutter (`flutter test`)** : **120 / 120 tests réussis** (incluant Phase 3.1, Lot 4B.1, Lot 4B.2, Lot 4B.3 et Lot 4B.4).
- **Analyse statique (`flutter analyze`)** : **0 anomalie** (`No issues found!`).

---

## 6. Risques résiduels et Décision GO / NO-GO pour le Lot 4B.5

### Risques résiduels
1. **Téléphone réel Samsung `SM-A336E` (`R6CT6003WRT`) en état ADB `authorizing`** : tant que la boîte de dialogue d'autorisation USB RSA n'est pas validée sur l'écran physique du téléphone, l'exécution sur ce périphérique réel reste en attente. Aucune validation physique non réalisée n'est déclarée.
2. **Accueil général (`HomeScreen`) non encore aligné** : conformément aux consignes du Lot 4B.4 (*« Ne pas commencer la refonte complète de l'accueil »*), `HomeScreen` n'a pas été modifié dans ce lot.

### Décision
- **Statut technique Lot 4B.4** : **GO pour le Lot 4B.5** (sous réserve de votre validation du chemin d'apprentissage).
- **Conformément à votre directive, nous attendons votre validation explicite avant de commencer le Lot 4B.5.**
