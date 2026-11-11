# Rapport de Restauration des Outils Historiques — Beřiyar Kedebideři

**Date :** 11 novembre 2026  
**Branche :** `feat/restore-historical-tools`  
**Base d'audit :** Commit `82e68df` (`docs/HISTORICAL_TOOLS_REGRESSION_AUDIT.md`)  
**Statut :** Restauration complète & validée par tests automatisés

---

## 1. Contexte & Objectif

L'audit de régression préalable (`HISTORICAL_TOOLS_REGRESSION_AUDIT.md`) a démontré que les trois fonctionnalités historiques :
1. **No Ena** (Publications culturelles, récits illustrés, archives médias)
2. **Studio Sticker** (Composition de stickers en caractères Erfe, export PNG et partage)
3. **Éditeur Beriya** (Éditeur de texte Erfe, gestion des brouillons locaux, export PDF)

étaient intégralement préservées dans le code source (Django et Flutter), mais étaient devenues invisibles pour les utilisateurs :
- **Sur mobile :** suppression de la grille d'accès rapide lors de la refonte au profit d'un appui long caché (`onLongPress: _openHub`) sur la tuile "Profil & réglages". De plus, la route nommée `/sticker-studio` manquait dans `mobile/lib/app/app.dart`.
- **Sur le Web :** présence des routes dans la barre de navigation et le footer, mais absence d'une section dédiée sur la page d'accueil (`backend/templates/webapp/home.html`).

---

## 2. Modifications Réalisées

### A. Navigation & Ergonomie Mobile (Flutter)
- **Fichier `mobile/lib/features/home/screens/home_screen.dart` :**
  - Ajout d'une section prioritaire clairement visible intitulée **« Outils & Création »** (`ValueKey('home-tools-creation-section')`) positionnée sur l'écran d'accueil entre les Packs hors ligne et les Accès secondaires.
  - Intégration de 3 cartes d'accès direct avec ouverture sur simple appui (`onTap`) :
    - **No Ena** (`ValueKey('home-tool-no-ena')`) : ouvre `NoEnaScreen`.
    - **Studio Sticker** (`ValueKey('home-tool-sticker-studio')`) : ouvre `StickerStudioScreen`.
    - **Éditeur Beriya** (`ValueKey('home-tool-editor')`) : ouvre `BeriyaEditorScreen`.
  - Bouton **« Tout voir »** (`ValueKey('home-tools-view-all-button')`) donnant un accès direct et explicite à `ContentHubScreen`.
  - **Suppression du geste caché :** l'appui long (`onLongPress: _openHub`) sur la tuile `home-secondary-profile` a été retiré. Le bouton "Profil & réglages" ne répond désormais qu'à son appui simple normal ouvrant `SettingsScreen`.
  - Conception responsive respectant les cibles tactiles minimales (>= 48 dp), le support RTL/arabe, et le redimensionnement d'écran / `TextScaler` 1.3x.
- **Fichier `mobile/lib/app/app.dart` :**
  - Ajout de l'import et de la route nommée manquante `'/sticker-studio': (_) => const StickerStudioScreen()`.
  - Vérification de la disponibilité des routes directes `'/no-ena'`, `'/editor'`, `'/content'`.

### B. Vitrine Web (Django)
- **Fichier `backend/templates/webapp/home.html` :**
  - Ajout d'une section `<section id="outils-creation" class="section">` reprenant les codes visuels Sahel Modern (cartes effet verre, typographie Kedebideri, palettes or #D4AF37 et sarcelle #2EC4B6).
  - Présentation des 3 cartes interactives pointant vers :
    - `/no-ena/` (No Ena)
    - `/sticker-studio/` (Studio Sticker)
    - `/editeur/` (Éditeur Beriya)
  - Internationalisation complète des titres, descriptions et boutons (Français, Anglais, Arabe avec support RTL).

---

## 3. Validation par Tests Automatisés

### Tests Unitaires & Widgets Flutter
- `mobile/test/historical_tools_navigation_test.dart` (**8/8 passés**) :
  1. Section *Outils & Création* visible sur l'accueil avec les 3 cartes et le bouton Hub.
  2. Simple appui sur No Ena ouvre `NoEnaScreen`.
  3. Simple appui sur Studio Sticker ouvre `StickerStudioScreen`.
  4. Simple appui sur Éditeur Beriya ouvre `BeriyaEditorScreen`.
  5. Bouton *Tout voir* ouvre `ContentHubScreen`.
  6. Vérification de l'absence de navigation cachée sur appui long du profil (ouvre `SettingsScreen` au tap).
  7. Route nommée `/sticker-studio` fonctionnelle.
  8. Route nommée `/editor` fonctionnelle.
- `mobile/test/beriya_editor_test.dart` (**7/7 passés**) :
  - Persistance des brouillons locaux (`BeriyaDraftStorage`).
  - Génération d'octets PDF valides avec en-têtes conformes (`BeriyaPdfService`).
- `mobile/test/sticker_studio_test.dart` (**1/1 passé**) :
  - Montage de l'écran, initialisation du clavier Erfe, choix des modes et boutons d'export.
- `mobile/test/lot_4b_5_home_screen_test.dart` (**6/6 passés**) :
  - Régression d'accessibilité validée (écrans étroits 320x568 & 360x800, TextScaler 1.3x, contrastes WCAG).
- **Suite complète Flutter :** **161 tests exécutés, 161 réussis (0 échec).**
- **Flutter Analyze :** **0 anomalie détectée** sur `lib` et `test`.

### Tests Web Django
- `backend/webapp/tests_historical_tools.py` (**3/3 passés**) :
  - Codes HTTP 200 sur `/no-ena/`, `/sticker-studio/`, `/editeur/`.
  - Présence de la section `#outils-creation` et des liens directs sur la page d'accueil.
  - Exactitude des traductions en anglais et en arabe.
- `backend/webapp/tests.py` (Tests d'accessibilité et de vues Web) : **6/6 passés**.

---

## 4. Respect des Engagements & Règles Pédagogiques
- **Données linguistiques :** aucune modification apportée aux 50 caractères Erfe, aux traductions du dictionnaire ou aux transcriptions.
- **Statuts éditoriaux :** aucun statut d'approbation ou de publication n'a été altéré.
- **Simulation commerciale :** aucune activation de paiement, abonnement ou monétisation réelle.
- **Périmètre existant :** l'ensemble des fonctionnalités éducatives existantes (Parcours, Audio-first, SRS, Packs hors ligne) reste intact et opérationnel.
