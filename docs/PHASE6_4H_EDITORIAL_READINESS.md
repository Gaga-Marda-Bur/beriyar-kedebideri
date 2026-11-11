# BERIYAR KEDEBIDERI — RAPPORT D'AUDIT ÉDITORIAL ET LINGUISTIQUE (LOT 6.4H)
## Validation des contenus Beřiya et Erfe — Préparation du Pilote Éducatif

**Date :** 11 novembre 2026  
**Branche Git :** `codex/phase6-4h-editorial-readiness`  
**Référence parente :** `d1a86c5` (Lot 6.4G — Qualification technique RC1 et gardes staging)  
**Auteurs :** Architecte Flutter / Django, Spécialiste Offline-First & Auditeur Linguistique  
**Base analysée :** `backend/db.sqlite3` en lecture seule stricte (SHA-256 : `8c1d4b1cf3a9415b17510fe5ce0b80c080ed056d7ca884730352214eadc65aef`)

---

## 1. Synthèse Exécutive & Principes Directeurs

Le **Lot 6.4H** a pour mission d'auditer et d'organiser l'ensemble des données linguistiques et pédagogiques réelles du projet **Beriyar Kedebideri** en vue du premier pilote avec apprenants.

### Principes Inviolables Appliqués
1. **Aucune invention linguistique :** Aucune traduction, aucun mot, aucun caractère ni aucun audio n'a été créé ou déduit artificiellement.
2. **Aucune publication automatique :** Aucun statut de publication (`draft` -> `published`, `review` -> `published`) n'a été modifié en base. Tous les statuts d'origine sont strictement préservés.
3. **Protection des données sources :** La base `db.sqlite3` a été ouverte exclusivement en mode lecture seule (`mode=ro`). Toutes les analyses et propositions sont documentées dans un dossier de validation sans toucher au schéma ni aux tables.
4. **Distinction formelle des statuts :** Séparation nette entre données de test technique, contenus en attente d'approbation humaine (`review`), contenus en brouillon (`draft`) et contenus publiés (`published`).

---

## 2. Inventaire Exhaustif des Contenus du Catalogue Réel

L'inspection de l'ensemble des tables métier de la base révèle l'état exact suivant :

| Type de Ressource | Total Existant | Publié (`published`) | En Revue (`review`) | Brouillon (`draft`) | Observations Pédagogiques & Techniques |
|---|---|---|---|---|---|
| **Caractères Erfe** | 50 | **2** (`𖺠` arkap, `𖺡` b) | **48** | 0 | Ordre canonique 1 à 50 (U+16EA0..U+16ED3). Tracés vectoriels configurés sur 3 caractères (`b`, `e`, `t`). |
| **Vocabulaire / Mots** | 4 | **1** (`arkap`) | 0 | **3** (`be`, `ta`, `de`) | Le mot publié porte un libellé français de test ("exemple test"). Les 3 mots en brouillon ont des traductions complètes (FR/EN/AR). |
| **Thèmes d'Apprentissage** | 2 | 0 | 0 | **2** | Thème 1 : `premiers-caracteres`, Thème 2 : `alphabetisation-active`. Tous deux en `draft`. |
| **Unités d'Apprentissage** | 4 | **4** | 0 | 0 | Unités 1, 2, 3, 4 publiées mais rattachées à des thèmes en brouillon (découverte publique bloquée). |
| **Leçons Structurées** | 1 | **1** | 0 | 0 | Leçon 1 (`ecoute-premier-caractere`) dans l'Unité 1, rattachée au Thème 1. |
| **Éléments de Leçon (Items)**| 1 | **1** | 0 | 0 | Item 1 lié au caractère `𖺠` et à l'audio `arkap.wav`. |
| **Exercices / Quiz** | 2 | **2** | 0 | 0 | Quiz 1 (`audio_to_character`, 4 options) et Quiz 2 dans l'Unité 1. |
| **Actifs Audio Réels** | 2 | **2** | 0 | 0 | `arkap.wav` (791 Ko, 4.48s) et `I.mp3` (9.6 Ko). Présents sur disque et vérifiés. |
| **Packs Hors Ligne** | 1 | **1** | 0 | 0 | `starter-beriya-erfe` (1.95 Mo, SHA-256 intègre), pack technique contenant 5 caractères dont 3 en revue. |

---

## 3. Dossier de Validation Linguistique (Fichier CSV Généré)

Un fichier structuré prêt pour l'analyse humaine et l'annotation par les linguistes locuteurs a été produit :
👉 [`docs/phase6_4h/validation_linguistique_erfe.csv`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/phase6_4h/validation_linguistique_erfe.csv)

### Structure du Fichier CSV
- **Colonnes d'inventaire technique :** Identifiant (ID), Code Unicode, Glyphe Erfe, Ordre Canonique, Transcription Latine Existante, Phonème IPA Existant, Type (Voyelle/Consonne), Nom FR Existant, Référence Audio Existante, Statut Actuel.
- **Colonnes de diagnostic :** Problème Éventuel Identifié (manque de transcription latine, absence d'enregistrement vocal, placeholder `À_VALIDER`).
- **Colonnes réservées à la décision humaine :** `Décision Humaine Requise`, `Commentaire Éditorial`, `Statut de Publication Proposé`.

### Synthèse des Anomalies Détectées dans les 50 Caractères
- **Caractères 1 et 2 (U+16EA0, U+16EA1) :** Publiés (`published`). Caractère 1 vocalisé par `arkap.wav`. Caractère 2 sans enregistrement audio direct.
- **Caractères 3, 4 et 22 (U+16EA2 /d/, U+16EA3 /e/, U+16EB5 /t/) :** En statut `review`. Possèdent une transcription latine, un phonème IPA et un nom français valide (issus du script d'alphabétisation active), mais **aucun enregistrement audio rattaché**.
- **Caractères 5 à 21 et 23 à 50 (45 caractères) :** En statut `review`. Possèdent leur glyphe Unicode et leur ordre canonique, mais portent le phonème temporaire `À_VALIDER`, n'ont pas de transcription latine renseignée et aucun audio.

---

## 4. Audit Critique du Dictionnaire et Données Provisoires

### Signalement Majeur : Entrée Provisoire Publiée
- **Mot ID 1 :**
  - **Texte Erfe :** `𖺠` (symbole unique correspondant au caractère U+16EA0)
  - **Transcription latine :** `arkap`
  - **Traduction française actuelle :** `"exemple test"`  ⚠️ **À CORRIGER IMPÉRATIVEMENT**
  - **Traduction anglaise :** `"test example"`
  - **Traduction arabe :** `"مثال تجريبي"`
  - **Statut :** `published`
  - **Constat :** Cette entrée, utilisée historiquement lors des premières étapes de développement pour valider la chaîne de rendu, est aujourd'hui publiée dans le dictionnaire public web. Elle doit être formellement remplacée par sa traduction sémantique authentique (ex: nom de la première lettre de l'alphabet, ou mot réel) validée par un locuteur natif.

### Entrées en Brouillon (`draft`) avec Valeurs Sémantiques Cohérentes
Les trois autres entrées de la base présentent des correspondances sémantiques réelles documentées :
1. **Mot ID 2 :** `𖺡𖺣` (`be`) -> Français : `"pays"`, Anglais : `"country"`, Arabe : `"بلد"`. Catégorie : Société et Territoire.
2. **Mot ID 3 :** `𖺵𖺠` (`ta`) -> Français : `"maison"`, Anglais : `"house"`, Arabe : `"بيت"`. Catégorie : Société et Territoire.
3. **Mot ID 4 :** `𖺢𖺣` (`de`) -> Français : `"terre"`, Anglais : `"land"`, Arabe : `"أرض"`. Catégorie : Société et Territoire.

*Recommandation :* Ces trois mots ne comportent pas encore d'enregistrements audio rattachés (`vocabulary_wordaudio`).

---

## 5. Audit Pédagogique des Deux Thèmes et des Quatre Unités

### Thème 1 : `premiers-caracteres` ("Premiers caractères") — Statut : `draft`
- **Objectif :** Découverte visuelle et auditive du premier caractère de l'alphabet.
- **Unité rattachée :** `premiers-5-caracteres` (Unité 1, `published`).
  - **Caractères déclarés :** 5 caractères (`𖺠` [publié], `𖺡` [publié], `𖺢` [review], `𖺣` [review], `𖺤` [review]).
  - **Mot lié :** `arkap` (publié, avec le libellé "exemple test").
  - **Leçon associée :** Leçon 1 (`ecoute-premier-caractere`, `published`).
  - **Audio associé :** `arkap.wav` (utilisé pour la leçon et le quiz 1).
  - **Quiz associé :** Quiz 1 (`audio_to_character`, 4 options : `𖺠`, `𖺡`, `𖺢`, `𖺣`).
  - **Incohérence identifiée :** Bien que l'unité soit publiée, 3 des 5 caractères associés et 2 des 4 options du quiz sont des caractères non encore validés linguistiquement (`review`).

### Thème 2 : `alphabetisation-active` ("Méthode Active Beriya Erfe") — Statut : `draft`
- **Objectif :** Méthode progressive audio-first de décodage/encodage (sons -> lettres -> syllabes -> mots).
- **Unités rattachées :**
  1. **Unité 1 (`unite-1-be`) :** Consonne `b` (𖺡) + Voyelle `e` (𖺣) -> Mot cible `"be"` (pays). Distracteur : `t` (𖺵).
  2. **Unité 2 (`unite-2-ta`) :** Consonne `t` (𖺵) + Voyelle `a` (𖺠) -> Mot cible `"ta"` (maison). Distracteurs : `b`, `e`.
  3. **Unité 3 (`unite-3-de`) :** Consonne `d` (𖺢) + Voyelle `e` (𖺣) -> Mot cible `"de"` (terre). Distracteurs : `a`, `t`.
- **Points forts pédagogiques :** Cohérence syllabique remarquable (combinaison consonne + voyelle produisant des mots signifiants réels).
- **Points bloquants pour diffusion immédiate :**
  - Aucun fichier audio n'est encore enregistré pour les sons `/b/`, `/e/`, `/t/`, `/d/` ni pour les mots `"be"`, `"ta"`, `"de"`.
  - Aucune leçon explicite ni quiz n'a été inséré dans les tables `lessons_lesson` et `quizzes_quizquestion` pour ces 3 unités (la logique repose pour l'instant sur le générateur de flux `generate_core_flow()`).

---

## 6. Audit Critique du Pack Hors Ligne `starter-beriya-erfe`

- **Fichier réel :** `backend/media/offline_packs/files/starter-beriya-erfe_v1_iMr8Evw.zip` (1 951 973 octets).
- **Empreinte SHA-256 :** `1195e4c54f9ae0b16c246eea5189259e9f2502198ba8efe1edd694a2529bea9b`.
- **Contenu du ZIP :**
  - Métadonnées : `manifest.json`, `metadata.json`, `themes.json`, `units.json`, `lessons.json`, `quizzes.json`, `words.json`, `characters.json`.
  - Fichiers audio : 4 fichiers WAV internes (`character_1_normal.wav`, `lesson_item_1_normal.wav`, `quiz_1_question.wav`, `word_1_normal.wav`).
- **Anomalie de diffusion détectée :**
  1. Les 4 fichiers audio du pack sont en réalité des doublons exacts du même fichier source `arkap.wav` (même empreinte SHA-256 `255e7121ad2d8de443aebad7781c3fa695b81a2425f1cce046420ee83f9db459`).
  2. Le fichier `characters.json` du pack référence 5 caractères :
     - `U+16EA0` (`𖺠`) : Publié.
     - `U+16EA1` (`𖺡`) : Publié.
     - `U+16EA2` (`𖺢`), `U+16EA3` (`𖺣`), `U+16EA4` (`𖺤`) : **Encore en statut review dans la base**.
  3. Le mot embarqué porte la traduction `"exemple test"`.

*Conclusion sur le pack :* Ce pack est une excellente preuve de concept technique pour le moteur offline Android, mais il ne peut être distribué à des apprenants sans remplacer les audios dupliqués et sans valider formellement les 3 caractères en revue.

---

## 7. Structuration Pédagogique des Deux Parcours (A & B)

Pour préparer le futur pilote éducatif, deux parcours adaptés aux publics cibles sont formalisés :

### Parcours A : "Je parle Beřiya, j'apprends l'Erfe" (Locuteurs oraux natifs)
- **Public :** Personnes maîtrisant la langue beřiya à l'oral mais découvrant l'écriture Erfe.
- **Approche didactique :** **Audio-First & Reconnaissance Visuelle.**
  - **Étape 1 (Écoute & Ancrage) :** Écoute d'un mot ou d'un son familier sans texte (ex: prompt oral en beřiya).
  - **Étape 2 (Découverte du Glyphe) :** Association du son entendu au caractère Erfe correspondant.
  - **Étape 3 (Tracé vectoriel gestuel) :** Apprentissage kinesthésique du sens d'écriture du glyphe.
  - **Étape 4 (Discrimination auditive) :** QCM oral demandant de choisir parmi 3 caractères Erfe celui qui correspond au son joué.
  - **Étape 5 (Encodage actif) :** Saisie du caractère ou du mot au clavier Erfe.
- **Ressources nécessaires :** Prompts oraux natifs en beřiya pour les consignes ; enregistrements audio de haute fidélité pour chaque consonne/voyelle.

### Parcours B : "J'apprends le Beřiya et l'Erfe" (Non-locuteurs / Débutants complets)
- **Public :** Apprenants de la diaspora, enfants ou personnes ne parlant pas la langue.
- **Approche didactique :** **Bilingue & Méthode Active (Consonne + Voyelle = Mot).**
  - **Étape 1 (Sensibilisation sémantique) :** Présentation du mot avec sa traduction (Français / Arabe / Anglais) et image illustrative.
  - **Étape 2 (Décomposition phonétique) :** Découpage du mot en syllabes et identification des lettres Erfe composantes.
  - **Étape 3 (Mémorisation lexicale) :** Répétition espacée (SRS) du vocabulaire avec flashcards bilingues.
  - **Étape 4 (Reconnaissance orthographique) :** Lecture guidée de mots courts (`be`, `ta`, `de`).
  - **Étape 5 (Vérification multilingue) :** Quiz associant le mot Erfe à sa traduction française/arabe.
- **Ressources nécessaires :** Validations sémantiques des traductions ; enrichissement des catégories de vocabulaire.

---

## 8. Proposition pour un Premier Thème Publiable

Afin de permettre l'ouverture d'un **pilote éducatif restreint mais authentique et irréprochable**, la séquence suivante est soumise à approbation :

### Option Recommandée : Validation Prioritaire du "Micro-Module Alpha" (4 caractères, 3 mots)
Plutôt que d'attendre la validation des 50 caractères de l'alphabet, focaliser l'effort de validation humaine sur un ensemble restreint et parfaitement cohérent :
1. **Valider linguistiquement 4 caractères :**
   - `𖺠` (A - voyelle)
   - `𖺡` (B - consonne)
   - `𖺣` (E - voyelle)
   - `𖺵` (T - consonne)
2. **Corriger l'entrée dictionnaire `arkap` :**
   - Remplacer `"exemple test"` par la désignation linguistique exacte validée.
3. **Valider les 2 mots résultants :**
   - `be` (`𖺡𖺣` - pays)
   - `ta` (`𖺵𖺠` - maison)
4. **Enregistrer 4 sons vocaux natifs courts :**
   - Son `/a/`, son `/b/`, son `/e/`, son `/t/`.
5. **Action de publication :**
   - Passer le Thème `alphabetisation-active` en statut `published`.
   - Activer publiquement les Unités 1 (`unite-1-be`) et 2 (`unite-2-ta`).
   - Mettre à jour le pack hors ligne avec ces 4 caractères validés uniquement.

---

## 9. Liste des Décisions Éditoriales Nécessitant Approbation

Conformément aux directives de non-intervention sans accord préalable, les arbitrages suivants sont soumis à validation :

| # | Objet de la Décision | Statut Actuel | Proposition Soumise à Validation | Action Technique Requise après Accord |
|---|---|---|---|---|
| **D1** | Traduction de `arkap` (Word ID 1) | `"exemple test"` | Remplacer par la traduction réelle approuvée par le linguiste. | `UPDATE vocabulary_word SET french_translation=...` |
| **D2** | Publication des Caractères de base | `review` | Promouvoir `U+16EA2` (d), `U+16EA3` (e), `U+16EB5` (t) en `published`. | `UPDATE alphabet_character SET validation_status='published'` |
| **D3** | Statut du Thème 2 (`alphabetisation-active`) | `draft` | Passer en `published` pour rendre l'Unité 1 visible publiquement. | `UPDATE learning_learningtheme SET status='published'` |
| **D4** | Statut des Mots 2 et 3 (`be`, `ta`) | `draft` | Passer en `published` après confirmation des traductions "pays" et "maison". | `UPDATE vocabulary_word SET validation_status='published'` |
| **D5** | Régénération du Pack Hors Ligne | Contient 3 caractères review et 1 libellé test | Reconstruire `starter-beriya-erfe.zip` en n'incluant que les éléments validés D1-D4. | Script de build de pack propre avec nouveaux checksums |

---

## 10. Conclusion et Clôture du Lot 6.4H

Toutes les analyses ont été réalisées sans altérer la base source. Le dossier de validation linguistique [`docs/phase6_4h/validation_linguistique_erfe.csv`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/phase6_4h/validation_linguistique_erfe.csv) est disponible pour les experts et aucune modification de données n'a été effectuée de manière prématurée.

**Le projet est prêt pour les décisions éditoriales et attend vos instructions d'arbitrage.**
