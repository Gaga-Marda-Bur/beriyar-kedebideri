# Correction A02 — cache persistant Flutter

La lecture utilise maintenant la même clé préfixée `bk_online_cache_` que l’écriture et accepte les deux formats de contenu : enveloppe `{cached_at, items}` et liste JSON brute. Le défaut de préfixe, identifié pendant les tests de correction, s’ajoutait au défaut de décodage décrit dans l’audit initial.

Le format d’écriture et les clés stockées restent identiques. La lecture ne réécrit ni ne supprime les préférences ; un cache invalide est conservé pour récupération et renvoie une liste vide. Les progressions, brouillons et packs ne sont pas migrés ou effacés par cette correction.

## Vérification

Sept tests ajoutés à `mobile/test/online_content_cache_service_test.dart` couvrent la restitution après recréation des préférences simulées, les dates, Unicode Beriya/arabe et données imbriquées, les anciennes listes, le cache vide ou absent, les entrées corrompues et les listes mixtes. Ils vérifient aussi la conservation des préférences de progression et du brouillon.

`docs/audit_cache_probe.dart` vérifie désormais la restitution de l’élément sauvegardé, au lieu de constater une lecture vide. Le rapport du 23 octobre et les résultats JSON de l’audit restent des observations historiques, pas l’état de validation de cette correction.

Depuis `mobile/` :

```text
flutter test --no-pub test ../docs/audit_cache_probe.dart
flutter analyze --no-pub
```

Résultat : **24 tests réussis**, soit les 16 tests préexistants, 7 tests de cache et la sonde corrigée. Analyse Flutter : **aucun problème signalé**. Les tests utilisent exclusivement des préférences simulées ; aucune validation sur appareil réel ni déploiement n’a été effectué.

Cette correction traite A02. La gestion des réponses API vides, de la fraîcheur et du caractère complet ou partiel des collections (A16) reste un chantier distinct.
