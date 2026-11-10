# Reprise limitée Phase 6 — 10 novembre 2026

Le rapport principal contient une section finale **CONSOLIDATION DE REPRISE** qui
rectifie le niveau de preuve des conclusions initiales. Lire cette section avant
de décider d’un lot. Aucun code métier, donnée linguistique, contrat API ou
réglage de production n’a été modifié pendant cette reprise.

## Fichiers récupérés

- Rapport initial : `../PHASE6_AUDIT_GLOBAL_ERFE_MONETISATION_PRODUCTION.md`,
  58 383 octets avant ajout, SHA-256
  `6b28712e56186c75302fc7d61da865362a025a64483d0e227b0bf8625bac0f39`.
  Copie intacte : `PHASE6_RAPPORT_ORIGINAL_2026-11-10.md`.
- HTML original retrouvé :
  `C:/Users/MONSTER/.gemini/antigravity/brain/fde59b94-5177-4924-a7f4-6b72bfc1f665/phase6_erfe_typography_diagnostic.html`.
  Copie identique ici : `phase6_erfe_typography_diagnostic.html`, 19 064 octets,
  SHA-256 `cdc198802c70960cca57a3155fa3755cfa0f15b9eacd6aca6159628d5cf6e797`.
  Ses huit références de fontes utilisent `file:///C:/...` : ce n’est pas un
  fichier autonome pour hébergement HTTP. Aucun rendu navigateur n’est revendiqué.

## Contrôles exécutés

Depuis la racine, PowerShell, avec `PYTHONDONTWRITEBYTECODE=1` :

```text
backend/venv/Scripts/python.exe docs/phase6_reprise/verify_evidence.py
backend/venv/Scripts/python.exe docs/run_backend_checks.py core.tests_security
```

Depuis `mobile`, avec `CI=true`, `FLUTTER_SUPPRESS_ANALYTICS=true` :

```text
flutter --no-version-check --suppress-analytics test --no-pub test/api_config_release_test.dart
```

Résultats constatés :

- Sonde : six polices, 50 glyphes Erfe distincts/non nuls par police, contours
  présents, checksum SFNT valide, fichiers web/mobile identiques. 300 glyphes
  rasterisés par Pillow/FreeType, grille PNG inspectée. Base SQLite lue en RO,
  empreinte inchangée. `staging` refusé et appel `format_html` sans argument rejeté.
- Django : **8 tests réussis**, runner 0,051 s, vérification système sans anomalie.
  Ce sont des SimpleTestCase ; aucune migration/base de test créée.
- Flutter : **6 tests réussis**, vérification de configuration en test hôte.
  Aucun build release, installation ou nouveau test physique.
- UTF-8 et parseur HTML : lecture réussie ; ce n’est pas un validateur visuel.
- Texte initial du rapport toujours présent en préfixe après normalisation des
  fins de ligne ; copie initiale conservée octet pour octet.

Les lectures ciblées du CSS, templates, styles Flutter, Admin et réglages sont
des preuves de structure, pas des tests de fonctionnement. Aucun GET du vrai
site de production, export PDF, test de débit ou contrôle fournisseur publicitaire
n’a été exécuté. Les suites historiques ne sont pas présentées comme rejouées.

## État Git et limites

Branche `feature/phase4-ux-ui-audio-first`, HEAD `0005693`.
Initialement : seul le rapport principal non suivi. Après reprise :

```text
?? docs/PHASE6_AUDIT_GLOBAL_ERFE_MONETISATION_PRODUCTION.md
?? docs/phase6_reprise/
```

Aucun fichier suivi modifié, aucun commit créé. La modification du Markdown est
un ajout documentaire ; les originaux sont préservés. La base actuelle porte
l’empreinte `2684f6ce3662fa7f3e771258887c3e48e76b72362a271598f25d1599f92b3543`
avant/après. L’empreinte historique `0e92…` n’est plus celle de cet état ; aucune
cause antérieure n’est présumée.

Pour annuler seulement cette reprise documentaire, conserver les preuves puis
reprendre la copie initiale du rapport et retirer uniquement les nouveaux fichiers
identifiés. Aucune migration inverse ni restauration de données n’est nécessaire.
Ne pas supprimer les documents préexistants. Toute implémentation attend une
validation distincte.
