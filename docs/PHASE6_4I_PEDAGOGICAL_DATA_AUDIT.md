# BERIYAR KEDEBIDERI — AUDIT DE LA QUALITÉ ET DE LA PROVENANCE DES DONNÉES PÉDAGOGIQUES (LOT 6.4I)
## Assainissement Pédagogique et Préparation de la Validation Linguistique

**Date :** 11 novembre 2026  
**Branche Git :** `codex/phase6-4i-pedagogical-data-audit`  
**Référence parente :** `12013e2` (Lot 6.4H — Inventaire éditorial et dossier linguistique)  
**Auteurs :** Architecte Flutter / Django & Spécialiste Qualité Pédagogique  
**Base analysée :** `backend/db.sqlite3` en lecture seule stricte (SHA-256 : `8c1d4b1cf3a9415b17510fe5ce0b80c080ed056d7ca884730352214eadc65aef`)

---

## 1. Synthèse Exécutive & Règles d'Or

Le **Lot 6.4I** concrétise l'audit approfondi de la provenance, de l'intégrité et des dépendances des données linguistiques avant toute décision de publication.

### Règles d'Inviolabilité Appliquées
1. **Zéro altération linguistique :** Aucune traduction n'a été inventée, aucun phonème n'a été improvisé, aucun fichier audio n'a été synthétisé artificiellement.
2. **Préservation absolue de la base source :** Aucune requête d'écriture (`UPDATE`, `INSERT`, `DELETE`) n'a été portée sur la base source `db.sqlite3`.
3. **Traçabilité des données :** Chaque ressource pédagogique a été reliée à son script ou mécanisme d'injection d'origine, dissociant clairement le code technique de démonstration du patrimoine linguistique vérifié.
4. **Validation humaine obligatoire :** Les feuilles de validation produites sont prêtes pour l'arbitrage direct par l'autorité linguistique.

---

## 2. Tableau de Provenance des Données Pédagogiques

L'analyse de l'historique Git (notamment des commits `acd0880`, `3081aff`, `ce4b043`) et des scripts d'initialisation révèle la généalogie exacte des contenus :

| Ressource | Identifiants / Objets | Script / Origine Technique | Date Initiale | Nature de la Donnée | Niveau d'Authenticité Linguistique |
|---|---|---|---|---|---|
| **Alphabet Unicode (Plage 1)** | U+16EA0 à U+16EB8 (25 chars) | `seed_beriya_erfe_characters.py` | Juin 2026 | Injection séquentielle Unicode `chr(code_point)` | **Technique brute.** Statut initial `review`. Glyphes conformes à la proposition Unicode Erfe, mais sans métadonnées. |
| **Alphabet Unicode (Plage 2)** | U+16EBB à U+16ED3 (25 chars) | `seed_beriya_erfe_characters.py` | Juin 2026 | Injection séquentielle Unicode `chr(code_point)` | **Technique brute.** Statut initial `review`. Glyphes conformes, métadonnées vides. |
| **Enrichissement Méthodologique** | U+16EA0 (a), U+16EA1 (b), U+16EA2 (d), U+16EA3 (e), U+16EB5 (t) | `seed_learning_core.py` | Oct. 2026 | Ajout des phonèmes IPA, graphemes latins et tracés vectoriels | **Semi-authentifié.** Configuré pour animer les Unités 1, 2, 3 de la Méthode Active (Lot 4B). |
| **Placeholders IPA `À_VALIDER`** | 45 caractères Erfe (IDs 5-21, 23-50) | Migration / Script enrichissement Lot 4B | Oct. 2026 | Remplissage par défaut `phoneme_ipa='À_VALIDER'` | **Factice / Placeholder.** Champ technique destiné à forcer un arrêt lors d'un audit qualité. |
| **Mot `arkap` (ID 1)** | `𖺠` (symbole U+16EA0) | Script initial de recette (Phase 1) | Juin 2026 | Mot de test technique ("exemple test") | **Factice / Placeholder.** Créé uniquement pour valider l'affichage web et les serializers. |
| **Mots `be`, `ta`, `de` (IDs 2, 3, 4)** | `𖺡𖺣` (pays), `𖺵𖺠` (maison), `𖺢𖺣` (terre) | `seed_learning_core.py` | Oct. 2026 | Données lexicales réelles combinatoires | **Linguistique attestée.** Dérivé de corpus documentés beriya (Zaghawa), mais en attente de confirmation éditoriale. |
| **Audio `arkap.wav`** | ID `1bb9f0cc...` | Enregistrement réel locuteur ("Gaga") | Juin 2026 | Vocalisation du nom de la première lettre | **Authentique.** Enregistrement réel d'un locuteur, validé et publié. |
| **Audio `I.mp3`** | ID `35f83da1...` | Enregistrement réel locuteur ("Gaga") | Juin 2026 | Prompt oral court | **Authentique.** Enregistrement vocal réel pour prompt de quiz. |
| **Pack Hors Ligne** | `starter-beriya-erfe_v1` | `offline_pack_generator.py` | Oct. 2026 | Export automatisé ZIP pour validation QA Android | **Hybride.** ZIP techniquement intègre, mais dupliquant `arkap.wav` sur 4 rôles sonores. |

---

## 3. Contrôle Détaillé des 50 Caractères Erfe et Cohérence Glyphes/Codes

### Clarification Définitive sur les Codes Unicode et Glyphes
Une divergence apparente de transcription et de glyphe avait été notée entre les rapports 6.4G et 6.4H :
- **U+16EA0 (ID 1) :** Glyphe `𖺠`, voyelle `/a/`. Nom français : "Voyelle A". Audio : `arkap.wav`.
- **U+16EA1 (ID 2) :** Glyphe `𖺡`, consonne `/b/`. Nom français : "Consonne B". Tracé vectoriel 4 traits.
- **U+16EA2 (ID 3) :** Glyphe `𖺢`, consonne `/d/`. Nom français : "Consonne D".
- **U+16EA3 (ID 4) :** Glyphe `𖺣`, voyelle `/e/`. Nom français : "Voyelle E". Tracé vectoriel 5 traits.
- **U+16EB5 (ID 22) :** Glyphe `𖺵`, consonne `/t/`. Nom français : "Consonne T". Tracé vectoriel 3 traits.

*Explication de l'écart :* Dans les tables Django, les colonnes `latin_transcription` étaient restées vides, tandis que la migration 0002 a introduit `latin_grapheme` et `phoneme_ipa`. L'audit 6.4I confirme que les colonnes ont été correctement consolidées dans le fichier de validation :
👉 [`docs/phase6_4i/validation_50_caracteres_erfe.csv`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/phase6_4i/validation_50_caracteres_erfe.csv)

### Signalement des 45 Valeurs `À_VALIDER`
Les 45 caractères suivants possèdent explicitement la mention technique `phoneme_ipa='À_VALIDER'` et aucun audio associé :
- U+16EA4 à U+16EB4 (17 caractères).
- U+16EB6 à U+16EB8 (3 caractères).
- U+16EBB à U+16ED3 (25 caractères).
Ces 45 caractères **ne doivent sous aucun prétexte être passés en statut `published`** tant qu'un linguiste n'a pas validé leur phonème et leur nom.

---

## 4. Audit des Fichiers Audio et Détection des Doublons

### Inventaire des Actifs Vocaux Réels sur Disque

| Fichier Disque | Taille | Format | Durée Réelle | Locuteur | Rôle Métier | Empreinte SHA-256 |
|---|---|---|---|---|---|---|
| `audio_assets/files/arkap.wav` | 791 192 octets | WAV PCM 44.1kHz | 4,48 s | "Gaga" | Caractère `𖺠` (Arkap) | `255e7121ad2d8de443aebad7781c3fa695b81a2425f1cce046420ee83f9db459` |
| `audio_assets/files/I.mp3` | 9 643 octets | MP3 44.1kHz | ~0,6 s | "Gaga" | Prompt Quiz (son /i/) | `1f2b39f0aec90930f2013556fd106d0e50cd34e0b1869e33978d85e2487e947b` |

### Détection Critique : Faux Multi-Enregistrements dans le Pack Hors Ligne
Dans l'archive `starter-beriya-erfe_v1_iMr8Evw.zip`, quatre fichiers audio distincts sont déclarés dans l'arborescence `audio/` :
1. `audio/character_1_normal.wav`
2. `audio/lesson_item_1_normal.wav`
3. `audio/quiz_1_question.wav`
4. `audio/word_1_normal.wav`

**Résultat du contrôle d'intégrité SHA-256 :**
Les 4 fichiers possèdent **rigoureusement la même empreinte SHA-256** (`255e7121ad2d8de443aebad7781c3fa695b81a2425f1cce046420ee83f9db459`) correspondant octet pour octet à `arkap.wav`.
*Conclusion :* Il ne s'agit pas de 4 enregistrements pédagogiques distincts mais du même son cloné 4 fois pour faire fonctionner le lecteur de pack hors ligne. Ces fichiers ne doivent pas être présentés aux apprenants comme des prononciations différenciées.

---

## 5. Audit des Mots et Traductions Existantes

Le lexique de la base a été extrait dans une feuille de contrôle dédiée :
👉 [`docs/phase6_4i/validation_lexicale_mots.csv`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/phase6_4i/validation_lexicale_mots.csv)

### Analyse Individuelle des Entrées Lexicales

1. **Mot ID 1 : `𖺠` (`arkap`)**
   - *FR actuel :* `"exemple test"`  ⚠️ **Anomalie majeure** (libellé provisoire).
   - *EN actuel :* `"test example"`
   - *AR actuel :* `"مثال تجريبي"`
   - *Audio rattaché :* `arkap.wav` (vocalise le mot "arkap").
   - *Recommandation :* À arbitrer par l'autorité linguistique. `arkap` désigne traditionnellement la première lettre / voyelle de l'alphabet Erfe.
2. **Mot ID 2 : `𖺡𖺣` (`be`)**
   - *FR actuel :* `"pays"` | *EN :* `"country"` | *AR :* `"بلد"`
   - *Statut :* `draft` | *Audio :* Aucun.
   - *Cohérence didactique :* Syllabe de base consonne `b` (𖺡) + voyelle `e` (𖺣).
3. **Mot ID 3 : `𖺵𖺠` (`ta`)**
   - *FR actuel :* `"maison"` | *EN :* `"house"` | *AR :* `"بيت"`
   - *Statut :* `draft` | *Audio :* Aucun.
   - *Cohérence didactique :* Syllabe consonne `t` (𖺵) + voyelle `a` (𖺠).
4. **Mot ID 4 : `𖺢𖺣` (`de`)**
   - *FR actuel :* `"terre"` | *EN :* `"land"` | *AR :* `"أرض"`
   - *Statut :* `draft` | *Audio :* Aucun.
   - *Cohérence didactique :* Syllabe consonne `d` (𖺢) + voyelle `e` (𖺣).

---

## 6. Matrice des Dépendances Pédagogiques et Analyse des Blocages

L'exécution du script de contrôle de sécurité [`test_safety_rules.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/phase6_4i/test_safety_rules.py) a relevé **12 violations de cohérence** dans la base :

```
- [SAFETY_VIOLATION] Published word #1 '𖺠' contains test/placeholder translation: 'exemple test'
- [DEPENDENCY_VIOLATION] Published Unit #1 (premiers-5-caracteres) references unvalidated character U+16EA2 (status=review)
- [DEPENDENCY_VIOLATION] Published Unit #1 (premiers-5-caracteres) references unvalidated character U+16EA3 (status=review)
- [DEPENDENCY_VIOLATION] Published Unit #1 (premiers-5-caracteres) references unvalidated character U+16EA4 (status=review)
- [DEPENDENCY_VIOLATION] Published Unit #2 (unite-1-be) references unvalidated character U+16EA3 (status=review)
- [DEPENDENCY_VIOLATION] Published Unit #3 (unite-2-ta) references unvalidated character U+16EB5 (status=review)
- [DEPENDENCY_VIOLATION] Published Unit #4 (unite-3-de) references unvalidated character U+16EA2 (status=review)
- [DEPENDENCY_VIOLATION] Published Unit #4 (unite-3-de) references unvalidated character U+16EA3 (status=review)
- [DEPENDENCY_VIOLATION] Published Unit #2 (unite-1-be) references unvalidated word 'be' (status=draft)
- [DEPENDENCY_VIOLATION] Published Unit #3 (unite-2-ta) references unvalidated word 'ta' (status=draft)
- [DEPENDENCY_VIOLATION] Published Unit #4 (unite-3-de) references unvalidated word 'de' (status=draft)
- [PACK_DUPLICATE_AUDIO] Pack contains 4 audio files with identical content (sha256=255e7121ad2d)
```

### Synthèse des Dépendances Pédagogiques par Unité

| Unité Pédagogique | Statut Actuel | Caractères Liés | Mots Liés | Audios Liés | Blocages Identifiés |
|---|---|---|---|---|---|
| **Unité 1 : Premiers 5 caractères** (`premiers-5-caracteres`) | `published` | `𖺠` (publié), `𖺡` (publié), `𖺢` (review), `𖺣` (review), `𖺤` (review) | `arkap` (publié, avec libellé test) | `arkap.wav` | **Bloquée :** Dépend de 3 caractères non validés et d'un mot contenant un libellé de test. |
| **Unité 2 : Unité 1 - "be"** (`unite-1-be`) | `published` | `𖺡` (publié), `𖺣` (review), distracteur `𖺵` (review) | `be` (`draft`) | Aucun | **Bloquée :** Dépend du caractère `e` (review) et du mot `be` (draft). Aucun audio. |
| **Unité 3 : Unité 2 - "ta"** (`unite-2-ta`) | `published` | `𖺠` (publié), `𖺵` (review), distracteurs `𖺡`, `𖺣` | `ta` (`draft`) | Aucun | **Bloquée :** Dépend du caractère `t` (review) et du mot `ta` (draft). Aucun audio. |
| **Unité 4 : Unité 3 - "de"** (`unite-3-de`) | `published` | `𖺢` (review), `𖺣` (review), distracteurs `𖺠`, `𖺵` | `de` (`draft`) | Aucun | **Bloquée :** Dépend des caractères `d`, `e` (review) et du mot `de` (draft). Aucun audio. |

---

## 7. Proposition du Premier Module Minimal Rigoureusement Validé

Pour permettre un premier lancement pilote sans attendre l'enregistrement et la validation des 50 caractères, un **Module Pilote Minimal ("Éveil à l'Erfe")** est formalisé :

### Périmètre du Module Pilote Minimal
1. **Périmètre Caractères :** Limité strictement aux deux premiers caractères :
   - `𖺠` (U+16EA0) : Voyelle /a/ (publié, audio `arkap.wav` validé).
   - `𖺡` (U+16EA1) : Consonne /b/ (publié, tracé vectoriel 4 traits configuré).
2. **Périmètre Lexical :**
   - Correction préalable du mot `arkap` avec son libellé validé (remplacement de "exemple test").
3. **Périmètre Exercices :**
   - Leçon 1 (`ecoute-premier-caractere`) : Découverte et répétition audio d'`arkap`.
   - Quiz 1 adapté : Question audio-to-character n'utilisant comme options que `𖺠` et `𖺡` (en écartant les options distractrices non validées `𖺢` et `𖺣`).
4. **Périmètre Pack Hors Ligne :**
   - Reconstruire un pack allégé `starter-erfe-pilot_v1` contenant uniquement `𖺠` et `𖺡`, le mot corrigé, la leçon 1 et le quiz adapté, avec un seul fichier audio intègre sans clonage.

---

## 8. Liste Complète des Décisions Linguistiques Soumises à Validation

Les 6 arbitrages suivants sont préparés pour validation :

| Réf. | Objet de l'Arbitrage | Donnée Actuelle | Choix Soumis à Décision | Impact Pédagogique |
|---|---|---|---|---|
| **DEC-01** | Sémantique du mot `arkap` (ID 1) | `"exemple test"` | A) Traduction : *"Première lettre / Arkap"*<br>B) Autre traduction à spécifier par le linguiste | Élimine le libellé de test visible sur le Web et Android. |
| **DEC-02** | Validation des consonnes et voyelles de base | Statut `review` pour `𖺢` (d), `𖺣` (e), `𖺵` (t) | A) Approuver les phonèmes `/d/`, `/e/`, `/t/`<br>B) Corriger les transcriptions latines ou IPA associées | Débloque les unités syllabiques `be`, `ta`, `de`. |
| **DEC-03** | Validation des 3 mots de société/territoire | Statut `draft` pour `be` (pays), `ta` (maison), `de` (terre) | A) Valider les traductions FR/EN/AR existantes<br>B) Ajuster les sens | Permet la publication du Thème 2 de la méthode active. |
| **DEC-04** | Enregistrements audio prioritaires | 2 enregistrements existants (`arkap`, `i`) | A) Programmer la collecte vocale de 4 sons courts : `/b/`, `/e/`, `/t/`, `/d/`<br>B) Programmer la vocalisation des mots `be`, `ta`, `de` | Complète le parcours audio-first indispensable aux débutants. |
| **DEC-05** | Calendrier de validation des 45 caractères `À_VALIDER` | 45 caractères avec phonème placeholder | Traiter les caractères par paliers de 10 lors des sessions de collecte | Maintient la rigueur scientifique de l'alphabet. |
| **DEC-06** | Stratégie de publication du premier thème public | Thèmes 1 et 2 actuellement `draft` | A) Publier le Thème 1 avec le module pilote minimal validé (DEC-01)<br>B) Attendre l'audio du Thème 2 avant toute publication publique | Rend la page web `/parcours/` navigable pour les apprenants. |

---

## 9. Conclusion du Lot 6.4I

L'audit approfondi du Lot 6.4I fournit un état des lieux exhaustif, documenté et irréfutable des données linguistiques. Les deux fichiers CSV de validation ([50 caractères](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/phase6_4i/validation_50_caracteres_erfe.csv) et [mots](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/phase6_4i/validation_lexicale_mots.csv)) permettent une prise de décision éclairée.

**Aucune modification de données n'a été appliquée. Les fichiers sont prêts pour vos arbitrages.**
