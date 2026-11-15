# BK-REMOTE-PILOT-03 — B2-B.2.1 : Stabilisation de GitHub Actions Flutter

**Branche :** `pilot/erfe-v1` (base `ab48464`)  
**Décision pour le deuxième push :** **GO POUR LE DEUXIÈME PUSH** (`git push origin pilot/erfe-v1`), en attente d'autorisation explicite du responsable.

---

## 1. Diagnostic des versions

| Source | Version observée | Détail |
|---|---|---|
| **Local (`flutter --version`)** | **Flutter `3.44.1`** (`channel stable`) | Revision `924134a44c`, **Dart `3.12.1`** |
| **`mobile/pubspec.yaml`** | `sdk: ^3.11.5` | Compatible Dart `3.12.1` |
| **`mobile/pubspec.lock`** | `flutter: ">=3.44.0"`, `dart: ">=3.12.0 <4.0.0"` | Verrouillé sur la série `3.44.x` / Dart `3.12.x` |
| **Runner GitHub Actions (`43724028532`)** | **Flutter `3.50.0`** | `channel: 'stable'` sans `flutter-version` épinglée ; déprécie `package:flutter/material.dart` après `v3.47.0-0.0.pre` (`90` diagnostics `info` -> échec `flutter analyze`). |

**Version retenue :** **`3.44.1`** — correspond exactement au SDK local ayant validé les 200 tests Flutter et respecte `pubspec.yaml`/`pubspec.lock` sans mise à jour massive des dépendances ni contournement `--no-fatal-infos`.

---

## 2. Modification appliquée

- **`.github/workflows/ci.yml`** : ajout de `flutter-version: '3.44.1'` dans `subosito/flutter-action@v2` (tout en conservant `channel: 'stable'`, `cache: true`, aucun job de déploiement).

---

## 3. Qualification locale (exécutée après modification)

- `flutter pub get` : réussi (exit `0`).
- `flutter analyze` : `No issues found!`, exit `0`.
- `flutter test` : `200` tests exécutés, `All tests passed!`, exit `0`.
- `git diff --check -- .github/workflows/ci.yml` : aucune erreur de formatage/conflit (exit `0`).
- **Avertissements historiques connus :** `git diff --check origin/dev...pilot/erfe-v1` signale des `trailing whitespace` dans d'anciens fichiers de documentation/scripts antérieurs (`docs/AR_*.md`, `docs/PHASE6_4*.md`, `docs/phase6_4*/*.py`). Ils ne sont volontairement pas retouchés dans cette phase pour ne pas polluer le diff CI.
- **Syntaxe YAML CI :** structure YAML vérifiée visuellement et par `git diff --check` ; l'exécution réelle du parser GitHub Actions interviendra lors du deuxième push (aucun `PyYAML` dans le venv Windows local).

---

## 4. Risques résiduels

1. Lors d'une future montée de version Flutter (> `3.47.0`), les imports `package:flutter/material.dart`, `GlobalMaterialLocalizations` et `GlobalCupertinoLocalizations` devront être migrés vers `package:material_ui` / `package:cupertino_ui`.
2. Aucune modification n'a été apportée à `fix/a07-editorial-draft-protection`, à la production Render, à PostgreSQL ou à Cloudflare.
