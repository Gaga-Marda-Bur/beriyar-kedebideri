# BERIYAR KEDEBIDERI — AUDIT DE RÉGRESSION DES OUTILS HISTORIQUES
## Diagnostic d'accessibilité et plan de restauration : No Ena, Studio Sticker, Éditeur Beriya

**Date :** 11 novembre 2026  
**Branche Git :** `audit/historical-tools-regression`  
**Auteurs :** Architecte Flutter / Django & Auditeur QA  
**Périmètre audité :**  
1. **No Ena** (Publications culturelles, patrimoniales et multimédias).  
2. **Studio Sticker** (Créateur et exportateur de stickers graphiques en Beriya Erfe).  
3. **Beriya Erfe Editor** (Éditeur de texte, mise en page et exportateur PDF multilingue).

---

## 1. Synthèse Exécutive du Diagnostic

> [!IMPORTANT]
> **CONCLUSION DU DIAGNOSTIC : AUCUNE DES TROIS FONCTIONNALITÉS N'A ÉTÉ SUPPRIMÉE DU CODE SOURCE.**  
> Le code Django, les templates HTML, les scripts JavaScript, les modèles de données, ainsi que **la totalité des implémentations Flutter mobile existent toujours intacts dans le dépôt**.  
>  
> Leur apparente disparition provient exclusivement de deux facteurs ergonomiques :
> 1. **Côté Mobile (Flutter) :** Lors de la refonte de l'écran d'accueil (`HomeScreen`) au commit `f6a27bc` (Lot 4B.5), la grille d'accès rapide a été remplacée par une liste d'accès secondaires où le lien vers le **ContentHub** (qui regroupe No Ena, Studio Sticker et Éditeur) a été relégué sur un **appui long (`onLongPress`) masqué** sur la tuile "Profil & réglages".
> 2. **Côté Web (Django) :** Les routes, vues et templates fonctionnent parfaitement (HTTP 200). Cependant, dans le bandeau de navigation sur petits écrans (mobile web), les boutons sont masqués sous le menu hamburger, donnant l'impression que la landing page s'est recentrée uniquement sur le parcours et l'alphabet.

---

## 2. Tableau Comparatif Avant / Après

| Outil Historique | Route Web Django | État Web Actuel | Implémentation Mobile (Flutter) | État Mobile Actuel | Cause de la Perte de Visibilité |
|---|---|---|---|---|---|
| **No Ena** | `/no-ena/` et `/no-ena/<slug>/` | **100% Fonctionnel** (HTTP 200, 1 publication active 'barikasit') | [`NoEnaScreen`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/no_ena/screens/no_ena_screen.dart), route `'/no-ena'` | **100% Fonctionnel** | Invisible depuis l'accueil : accessible uniquement via le ContentHub (appui long masqué sur réglages). |
| **Studio Sticker** | `/sticker-studio/` | **100% Fonctionnel** (HTTP 200, export image Canvas JS) | [`StickerStudioScreen`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/sticker_studio/presentation/sticker_studio_screen.dart) | **100% Fonctionnel** (Canvas Flutter, rendu glyphes, export PNG) | Route directe `'/sticker-studio'` manquante dans `MaterialApp.routes` ; accessible uniquement par le ContentHub masqué. |
| **Éditeur Beriya Erfe** | `/editeur/` | **100% Fonctionnel** (HTTP 200, `pdf-lib`, `fontkit`, clavier virtuel) | [`BeriyaEditorScreen`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/editor/screens/beriya_editor_screen.dart), route `'/editor'` | **100% Fonctionnel** (Brouillons locaux, export PDF multi-pages) | Absente de la grille d'accueil principale ; reléguée au ContentHub masqué. |

---

## 3. Analyse Détaillée par Fonctionnalité

### 3.1. No Ena (Publication Multimédia & Patrimoine)
- **Origine :** Introduit initialement au commit `44af620` (Juin 2026), enrichi lors des phases 2 et 3.
- **Backend Django :** Application `backend/no_ena/`, modèle `NoEnaPublication`, contrôleur `no_ena_list_page` et `no_ena_detail_page`.
- **Données réelles :** La publication `"Premier regard sur Beriya Erfe"` (slug `premier-regard-beriya-erfe`) avec l'image `barikasit.png` et l'audio `arkap.wav` est active et publiée (`status='published'`).
- **Web :** Navigation présente dans `base.html` (Desktop et Drawer mobile).
- **Mobile Flutter :** Écran complet avec lecture audio, cache hors ligne (`CachedContentService`), favoris et partage.
- **Point de blocage :** Aucun bouton dédié sur la page d'accueil mobile Flutter.

### 3.2. Studio Sticker (Création & Partage de Stickers)
- **Origine :** Introduit au commit `31dc637` (17 Juin 2026).
- **Web Django :** Template `sticker_studio.html`, script `sticker_studio.js`, styles `brand.css`. Permet la personnalisation de couleurs, textes en Erfe, bordures, badges et export PNG direct via l'élément `<canvas>`.
- **Mobile Flutter :** Composant [`StickerStudioScreen`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/sticker_studio/presentation/sticker_studio_screen.dart) (607 lignes), [`StickerBeriyaKeyboard`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/sticker_studio/widgets/sticker_beriya_keyboard.dart), palettes Sahel Modern, gestion des calques et export via `share_plus`.
- **Points de blocage :**
  1. La table de routage `MaterialApp.routes` dans `mobile/lib/app/app.dart` ne déclare pas `/sticker-studio`.
  2. L'accès mobile n'est possible qu'en naviguant via le `ContentHubScreen`.

### 3.3. Beriya Erfe Editor (Traitement de Texte & Export PDF)
- **Origine :** Développé au commit `acd0880` (Octobre 2026) et consolidé au commit `7998177` (Phase 6.2).
- **Web Django :** Route `/editeur/`, template `editor.html`, moteur `beriya_editor.js` embarquant les librairies `fontkit.umd.min.js` et `pdf-lib.min.js` pour générer des documents PDF côté client avec la typographie Kedebideri intégrée.
- **Mobile Flutter :** Écran [`BeriyaEditorScreen`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/editor/screens/beriya_editor_screen.dart) (778 lignes), stockage persistant des brouillons [`BeriyaDraftStorage`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/editor/services/beriya_draft_storage.dart) et génération PDF native [`BeriyaPdfService`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/editor/services/beriya_pdf_service.dart) validée par 7 tests unitaires (`beriya_editor_test.dart`).
- **Points de blocage :** L'outil est présent sous la route Flutter `'/editor'`, mais aucun bouton direct ne permettait à l'apprenant d'y accéder depuis l'écran principal sans connaître l'appui long masqué.

---

## 4. Identification du Commit Responsable de la "Disparition"

La rupture de visibilité ergonomique s'est produite au commit :
**`f6a27bc` ("feat(lot4b.5): modernisation de HomeScreen et rapport de validation finale Phase 4")**
- **Avant ce commit :** La `HomeScreen` comportait un bloc `_QuickAccessGrid` avec une tuile explicite `Content Hub` menant directement à No Ena, Studio Sticker, etc.
- **Dans ce commit :** La tuile a été transformée en `_SecondaryAccessItem` avec le code suivant :
  ```dart
  _SecondaryAccessItem(
    itemKey: const ValueKey('home-secondary-profile'),
    title: _localized(lang, 'Profil & réglages', 'Profile & settings', 'الملف والإعدادات'),
    subtitle: loc.settings,
    icon: Icons.tune_rounded,
    onTap: _openSettings,
    onLongPress: _openHub, // <-- L'accès au Hub a été masqué en appui long !
  ),
  ```
L'utilisateur moyen ne faisant pas d'appui long sur le bouton "Profil & réglages", ces 3 outils sont devenus invisibles.

---

## 5. Plan de Restauration Proposé

Pour restaurer une visibilité immédiate et ergonomique sans régresser sur le Design System Sahel Modern :

### Action 1 : Déclarer la route manquante dans l'application Mobile (`app.dart`)
Ajouter dans `MaterialApp.routes` :
```dart
'/sticker-studio': (_) => const StickerStudioScreen(),
```

### Action 2 : Rétablir un accès direct et visible sur `HomeScreen` (Mobile)
Dans la section des accès secondaires de [`home_screen.dart`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/mobile/lib/features/home/screens/home_screen.dart#L1160-L1185), ajouter explicitement une tuile visible dédiée aux **Outils & Création** ou directement aux fonctionnalités :
- **Option A (Recommandée) :** Ajouter une tuile "Centre de ressources & Outils" (`Icons.hub_rounded`) qui ouvre le `ContentHubScreen` sur un simple clic (`onTap: _openHub`).
- **Option B :** Étendre la grille des accès secondaires pour intégrer directement :
  1. Studio Sticker (`Icons.draw_rounded`)
  2. Éditeur Beriya (`Icons.article_rounded`)
  3. No Ena (`Icons.auto_awesome_rounded`)

### Action 3 : Vérifier et consolider le menu Web (`base.html` & `home.html`)
- Les liens existent déjà dans le menu de `base.html` (lignes 69, 87, 91).
- Ajouter une section visuelle claire sur la page d'accueil web (`home.html`) mettant en valeur ces trois outils d'expression culturelle (Studio Sticker, Éditeur et No Ena).

---

## 6. Tests de Validation de la Restauration

| Test à Exécuter | Périmètre | Comportement Attendu |
|---|---|---|
| **Test de Route Sticker** | Flutter (`routes_test.dart`) | `Navigator.pushNamed('/sticker-studio')` ouvre `StickerStudioScreen`. |
| **Test de Route Editor** | Flutter (`beriya_editor_test.dart`) | `Navigator.pushNamed('/editor')` ouvre `BeriyaEditorScreen`. |
| **Test d'Accessibilité Home** | Flutter Widget Tester | Vérifier la présence d'un bouton cliquable visible vers les outils. |
| **Recette Web HTTP** | Django Client (`test_historical_tools.py`) | `/no-ena/`, `/sticker-studio/`, `/editeur/` retournent HTTP 200. |
| **Export Canvas & PDF** | Navigateur réel | Vérifier l'intégrité de la génération d'image et du document PDF. |

---

## 7. Décision Attendue

Le diagnostic est formel : **le code est complet, opérationnel et préservé à 100%**.  
J'attends votre validation pour appliquer le plan de restauration (rétablissement d'un accès direct sur l'accueil mobile et déclaration de route).
