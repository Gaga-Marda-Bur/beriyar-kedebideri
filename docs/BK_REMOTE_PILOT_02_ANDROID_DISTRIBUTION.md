# BK-REMOTE-PILOT-02 — Distribution privée de l'application Android pilote

**Variante pilote :** `com.afrigama.beriyarkedebideri.pilot` (`Beřiyar Pilote`)  
**Statut :** Préparé — **Aucune publication ni distribution effectuée**

---

## Commande de compilation de l'APK pilote signé

```powershell
cd mobile
flutter build apk --release `
  --dart-define=API_FLAVOR=staging `
  --dart-define=API_BASE_URL=https://<domaine-pilote>/api `
  --dart-define=BK_PILOT=true
```

*(Pour Google Play App Bundle : remplacer `apk` par `appbundle`.)*

---

## Scénario A — Distribution via Google Play en test fermé (Closed Testing)

### Prérequis
- Compte développeur Google Play Console actif.
- Création d'une piste **Test fermé** (ou application interne dédiée si `applicationId` `.pilot` est distinct de l'application publique).
- Fichier AAB signé avec `beriyar-release-key.jks` (`flutter build appbundle --release ... --dart-define=BK_PILOT=true`).
- Liste des adresses Gmail des 5–10 testeurs autorisés.

### Avantages
- Installation et mises à jour automatiques via Google Play sans activer « Sources inconnues ».
- Distribution contrôlée uniquement aux e-mails inscrits sur la piste fermée.
- Vérification d'intégrité Play et gestion simplifiée des correctifs.

### Limites
- Délai de validation Google Play (de quelques heures à quelques jours pour la première soumission).
- Nécessite une fiche minimale et des déclarations de confidentialité dans Play Console.

### Procédure de mise à jour
1. Incrémenter `version` (`+versionCode`) dans `mobile/pubspec.yaml`.
2. Recompiler l'AAB signé avec les mêmes `--dart-define` (`API_FLAVOR`, `API_BASE_URL`, `BK_PILOT=true`).
3. Téléverser sur la piste de test fermé ; les testeurs reçoivent la mise à jour via le Play Store.

---

## Scénario B — Distribution d'un APK signé par canal privé

### Prérequis
- Fichier `app-release.apk` compilé avec `--dart-define=BK_PILOT=true`, `API_FLAVOR=staging`, `API_BASE_URL=https://<domaine-pilote>/api`, signé par `beriyar-release-key.jks`.
- Empreinte SHA-256 de l'APK calculée et communiquée séparément aux testeurs.
- Canal de transmission privé (lien temporaire authentifié ou messagerie chiffrée réservée aux 5–10 testeurs).

### Avantages
- Déploiement immédiat dès que le serveur pilote HTTPS est validé (aucun délai de revue Play Store).
- Idéal pour un pilote restreint de 5–10 appareils connus.

### Limites
- Chaque testeur doit autoriser l'installation depuis la source utilisée (navigateur ou gestionnaire de fichiers) la première fois.
- Pas de mise à jour automatique : chaque nouvelle version doit être renvoyée manuellement.

### Procédure de mise à jour
1. Incrémenter `versionCode` dans `mobile/pubspec.yaml`.
2. Recompiler l'APK signé (`BK_PILOT=true`) et vérifier son empreinte SHA-256.
3. Transmettre le nouvel APK aux testeurs via le canal privé : l'installation met à jour `com.afrigama.beriyarkedebideri.pilot` en conservant l'isolation par rapport à l'application publique (`com.afrigama.beriyarkedebideri`).
