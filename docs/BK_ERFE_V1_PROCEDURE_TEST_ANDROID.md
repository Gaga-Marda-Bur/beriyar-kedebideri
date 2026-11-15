# Procédure de test pilote sur appareil Android physique — Erfe V1

**Contexte :** Aucun appareil Android physique n'était connecté (`adb.exe devices -l` vide) lors de la préparation logicielle. Les vérifications ci-dessous doivent être exécutées dès qu'un téléphone Android (ex. Samsung `SM_A336E`) est branché en USB.

---

## 1. Préparation de l'environnement pilote (sans publication publique)
1. Importer le pack si la base cible est vide, puis enregistrer la validation linguistique :
   ```powershell
   .\backend\venv\Scripts\python.exe backend\manage.py validate_erfe_alphabet_v1 --validated-by "Responsable Linguistique"
   ```
2. Créer les 5 à 10 comptes apprenants pilotes (`is_staff=False`) et les ajouter **uniquement** au groupe Django `pilot_erfe_v1` (jamais `is_staff=True`) :
   - Ils accèdent ainsi uniquement aux leçons `ERF-01`..`ERF-05` (`validated`) et aux `25` quiz `TEXT_TO_CHARACTER`.
   - Les leçons `P01`..`P06` et `V01`..`V03` (`draft`) restent totalement invisibles.
   - Les utilisateurs publics non membres de `pilot_erfe_v1` ne voient aucun cours non publié.

---

## 2. Vérifications physiques sur Android
1. Connecter le téléphone et vérifier sa détection :
   ```powershell
   $env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe devices -l
   ```
2. Lancer l'application Flutter sur l'appareil connecté avec un compte pilote :
   - **Contrôle catalogue & droits :** vérifier que seules les 5 leçons `ERF-01` à `ERF-05` apparaissent (aucune leçon `P01`..`P06` ni `V01`..`V03`).
   - **Parcours `ERF-01` complet :**
     - Vérifier le rendu de la police Erfe sur les 5 lettres (`𖺠`, `𖺡`, `𖺢`, `𖺣`, `𖺤`).
     - Tester volontairement une **mauvaise réponse** en discrimination et au clavier Erfe (`BeriyaKeyboard`), vérifier le message d'encouragement, puis corriger.
     - Terminer la séance et vérifier le score (`< 100 %` si erreur au 1er essai).
   - **Révision SRS sans audio :**
     - Ouvrir l'activité de révision SRS depuis le bilan : vérifier l'affichage de la consigne latine (`Touchez l'écriture Erfe correspondant à « ... »`) et du bandeau d'absence d'audio sans pénalité.
   - **Reprise hors ligne après fermeture complète :**
     - Commencer `ERF-02`, couper Wi-Fi et données mobiles, fermer complètement l'application (swipe récent / `adb shell am force-stop`), rouvrir l'application hors ligne et vérifier la reprise exacte à l'étape sauvegardée.
   - **Contrôles essentiels sur `ERF-02` à `ERF-05` :** ouvrir chaque leçon, vérifier les 5 caractères, la discrimination et le clavier Erfe.
3. Remplir [BK_ERFE_V1_FICHE_RETOUR_PILOTE.md](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/BK_ERFE_V1_FICHE_RETOUR_PILOTE.md) avec chaque apprenant pilote.
