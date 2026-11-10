# Recette Android isolée — Phase 3

Ces scripts servent à valider l’application existante. Ils ne déploient rien et
ne modifient pas le corpus source ni l’application Flutter d’origine.

## Isolation

- `runtime/` est ignoré par Git : bases, sauvegardes, clone, comptes synthétiques,
  APK et preuves brutes. Ne pas commiter ce dossier.
- `prepare_lab.py prepare` crée une **nouvelle** SQLite QA. Il refuse de remplacer
  une base QA existante. Le corpus source est lu en SQLite `mode=ro` ; seuls les
  contenus nécessaires et leurs parents sont copiés avec leurs statuts conservés.
  Aucun compte, session, feedback ou historique utilisateur source n’est copié.
  Les noms de locuteurs et notes AudioAsset sont anonymisés dans la copie.
- La sauvegarde QA précède la migration 0004. Sa restauration est comparée sur
  toutes les tables, avec contrôles SQLite et clés étrangères. La migration est
  ensuite appliquée à **QA uniquement**.
- Le serveur écoute uniquement `127.0.0.1:8765`. Les identifiants A/B sont
  synthétiques, stockés dans `runtime/synthetic_accounts.json`, jamais imprimés.
- Le clone utilise `com.afrigama.beriyarkedebideri.qa`, label « BK QA Phase 3 ».
  Les fichiers de signature de production ne sont pas copiés. Les dépendances
  `integration_test` du SDK sont ajoutées uniquement au clone.

## Préparation et contrôles HTTP

Depuis la racine du dépôt, PowerShell :

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
backend/venv/Scripts/python.exe docs/qa_android/prepare_lab.py prepare
backend/venv/Scripts/python.exe docs/qa_android/prepare_lab.py clone-mobile
backend/venv/Scripts/python.exe docs/qa_android/prepare_lab.py serve
```

Dans un autre terminal, une fois le serveur démarré :

```powershell
backend/venv/Scripts/python.exe docs/qa_android/http_security_probe.py
```

Les privilèges nécessaires aux dossiers temporaires/SDK, au serveur local et à
ADB dépendent du bac à sable Windows. Une erreur de permissions ne doit pas être
présentée comme un échec métier. Ne jamais remplacer DATABASE_URL par une URL de
production pour contourner un problème de recette.

## Android

Le harnais `phase3_android_test.dart` est copié dans le clone. Les préférences,
fichiers, décodeur audio et requêtes HTTP y sont **natifs**, sans mocks. Les
réponses de test sont choisies depuis le contenu existant ; aucune traduction ou
correspondance phonétique nouvelle n’est créée.

Dans `runtime/mobile`, après `flutter pub get --offline`, utiliser un appareil
identifié par `adb devices -l` et un tunnel `adb -s DEVICE reverse tcp:8765 tcp:8765`.
La commande suivante illustre le premier scénario, avec DEVICE remplacé par la
cible de test vérifiée :

```text
flutter test integration_test/phase3_android_test.dart -d DEVICE --no-pub --no-uninstall --dart-define=API_FLAVOR=local --dart-define=API_BASE_URL=http://127.0.0.1:8765/api --dart-define=QA_STAGE=online
```

**Toujours conserver `--no-uninstall`.** Le SDK installé désinstalle autrement
l’application d’intégration à la fin, ce qui invaliderait le test de persistance.
Le clone fixe l’applicationId complet ; un simple suffixe debug n’était pas
correctement reconnu par la logique de nettoyage de ce SDK.

Étapes successives, sans effacement de données :

1. `QA_STAGE=online` : installation initiale QA, téléchargement, lecture WAV native,
   écrans packs/quiz, deux premières étapes d’une unité et sauvegarde.
2. Arrêter le processus QA, activer le mode avion de la cible de test et retirer
   **uniquement** son tunnel API. `QA_STAGE=offline` avec `--plain-name "phase3 native offline"`
   vérifie la reprise, la fin de séance et le refus de sync sans perte locale.
3. Toujours hors ligne, les tests `downloaded audio`, `cached quiz` et `installed packs`
   reproduisent les anomalies de cache/catalogue. Ils doivent actuellement échouer.
4. Rétablir l’état réseau initial et le tunnel. `QA_STAGE=resync` vérifie la sync,
   le refus d’une preuve invalide et la fusion d’une mise à jour ancienne.
5. `QA_STAGE=quiz-check` vérifie le feedback après une bonne réponse et relève la
   remise à zéro du quiz autonome à sa réouverture. Le feedback échoue actuellement.

Le mode avion seul ne coupe pas un tunnel USB vers localhost. Le retrait du
tunnel fait donc partie de la simulation de serveur inaccessible. Ce n’est pas
une mesure de débit Internet mobile ou Render.

La sélection de routes par le harnais ouvre les vrais écrans, mais ne mesure pas
leur découvrabilité depuis le menu ni un parcours humain sans assistance.
L’ouverture du mode développeur ne signifie pas que le débogage USB est activé :
une cible physique doit réellement apparaître en état `device` dans ADB.

## Résultats et nettoyage

Les JSON de résultats sont écrits dans `app_flutter/qa_*.json` de l’application QA.
`collect_evidence.py` collecte les résultats de **notre émulateur** et produit
`PHASE3_RESULTS.json` sans jetons, mots de passe ou données du téléphone. Les
mesures shell ponctuelles consignées dans le rapport viennent des commandes ADB
exécutées pendant la recette ; elles ne constituent pas un profil release.

Après les sept scénarios sur un téléphone physique autorisé, restaurer ses
réglages réseau puis exécuter depuis la racine :

```text
backend/venv/Scripts/python.exe docs/qa_android/collect_phone.py --device DEVICE
```

Ce collecteur vérifie la cible physique et la restauration des réglages consignés
dans `runtime/phone_state_before.json`, puis ajoute les résultats à la synthèse.
Ne pas relancer ensuite le collecteur émulateur, qui recrée la synthèse. Le numéro
de série USB n’est pas inclus dans les preuves consolidées. Le Samsung SM-A336E
a effectivement exécuté la recette ; la confirmation humaine d’audibilité est
distincte des assertions du décodeur et d’une validation linguistique.

Restaurer le réseau initial de la cible. Arrêter seulement le serveur de recette
et l’émulateur lancé pour ce travail, après collecte. Conserver les sauvegardes
et preuves le temps de la revue. Ne pas désinstaller l’application habituelle,
effacer ses données, inverser une migration de production ou supprimer un registre
de propriété pour rétablir artificiellement une synchronisation.
