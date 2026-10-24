# Compte-rendu de correction — A07 : Protection éditoriale des brouillons et relations imbriquées

**Date :** 2026-10-23  
**Branche Git :** `fix/a07-editorial-draft-protection`  
**Référence audit :** [AUDIT_2026-10-23.md](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/docs/AUDIT_2026-10-23.md) — Constat A07 (P1)

---

## 1. Contexte et objectifs

Avant cette correction :
- Les endpoints de l'API publique (`/api/learning/themes/`, `/api/learning/units/`, `/api/alphabet/characters/`, etc.) ne filtraient pas systématiquement par statut `published`, renvoyant par défaut des éléments au statut `draft` ou `review`.
- Les sérialiseurs imbriqués exposaient les relations (caractères, mots cibles, leçons) sans filtrer leur statut de validation.
- Les métadonnées internes des assets audio (`notes`, `speaker_name`, `recording_quality`) étaient exposées publiquement.
- Le générateur de packs hors ligne pouvait inclure des éléments au statut brouillon dans des packs marqués comme publiés.
- Aucune alerte n'indiquait dans l'administration si une unité publiée dépendait de ressources non validées.

### Directives strictes appliquées
1. **Aucune publication automatique :** Les lignes existantes en base (`draft`, `review`) n'ont pas été modifiées.
2. **`review` &ne; `published` :** Le statut `review` est strictement distinct de « validé / publié » et reste masqué pour le grand public.
3. **Prévisualisation staff préservée :** Les administrateurs et collaborateurs authentifiés (`is_staff=True`) conservent l'accès aux brouillons et à la prévisualisation.
4. **Signalement sans altération :** Les unités publiées dont les dépendances restent en brouillon sont clairement signalées par des badges et cartouches d'avertissement dans Django Admin sans altérer silencieusement les données.

---

## 2. Modifications apportées

### A. Contrôle d'accès et helper de prévisualisation staff
- **Fichier créé :** [`backend/core/permissions.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/core/permissions.py)
  - Fonction `is_staff_preview(request)` permettant d'identifier de manière fiable les requêtes de prévisualisation staff sans impacter le comportement pour les requêtes anonymes ou utilisateurs standards.

### B. Vues d'API publiques (Filtrage strict)
- [`backend/learning/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/views.py) :
  - `LearningThemeListAPIView` & `LearningThemeDetailAPIView` : réservés aux thèmes `status='published'` pour les non-staff.
  - `LearningUnitListAPIView`, `LearningUnitDetailAPIView` & `LearningUnitCoreFlowAPIView` : réservés aux unités `status='published'` pour les non-staff.
- [`backend/alphabet/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/alphabet/views.py) :
  - `CharacterListAPIView` & `CharacterDetailAPIView` : réservés à `validation_status='published'`.
- [`backend/vocabulary/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/vocabulary/views.py) :
  - `WordListAPIView` & `WordDetailAPIView` : réservés à `validation_status='published'`.
- [`backend/audio_assets/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/audio_assets/views.py) :
  - `AudioAssetListAPIView` & `AudioAssetDetailAPIView` : réservés à `validation_status='published'`.
- [`backend/lessons/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/lessons/views.py) :
  - Filtrage des leçons et éléments de leçons publiés.
- [`backend/quizzes/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/quizzes/views.py) :
  - Filtrage des questions publiées.
- [`backend/offline_packs/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/offline_packs/views.py) :
  - Filtrage des packs publiés.
- [`backend/webapp/views.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/webapp/views.py) :
  - Les pages web (accueil, alphabet, vocabulaire, parcours) filtrent strictement le contenu publié pour les visiteurs publics.

### C. Sérialiseurs et relations imbriquées
- [`backend/audio_assets/serializers.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/audio_assets/serializers.py) :
  - Retrait systématique des champs internes `notes`, `speaker_name`, et `recording_quality` pour les requêtes non-staff dans `to_representation`.
- [`backend/learning/serializers.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/serializers.py) :
  - `LearningThemeSerializer` : le champ `units` et le compteur `units_count` ne comptent et n'exposent que les unités publiées pour le public.
  - `LearningUnitSerializer` :
    - `characters` et `distractor_characters` ne contiennent que les glyphes validés (`published`).
    - `target_word` est mis à `None` si le mot cible n'est pas validé.
    - `words` ne contient que les mots validés.
    - `character_ids`, `distractor_character_ids`, `word_ids` sont alignés sur les listes filtrées.
- [`backend/learning/models.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/models.py) :
  - `generate_core_flow(request=None, only_published=None)` : si la requête est publique ou si `only_published=True`, la séquence exclut les caractères et mots cibles non validés.
- [`backend/lessons/serializers.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/lessons/serializers.py) :
  - `LessonItemSerializer` masque `character` et `word` non validés dans `to_representation`.

### D. Générateur de packs hors ligne
- [`backend/offline_packs/services/offline_pack_generator.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/offline_packs/services/offline_pack_generator.py) :
  - Lors de la génération d'un pack au statut `published`, les thèmes, unités, caractères, mots, leçons et quiz sont strictement filtrés sur `status='published'` ou `validation_status='published'`.
  - `unit.generate_core_flow(only_published=True)` garantit qu'aucun brouillon ne fuit dans l'archive ZIP publique.

### E. Signaux d'alerte dans Django Admin
- [`backend/learning/admin.py`](file:///c:/Users/MONSTER/Desktop/BeriyaClean/beriyar-kedebideri/backend/learning/admin.py) :
  - **`LearningUnitAdmin` :**
    - Ajout de la colonne `dependency_status_badge` dans `list_display` avec badge rouge `⚠️ Bloquantes (N)` si l'unité est publiée avec des dépendances non publiées, ou badge orange `⚠️ Non publiées (N)` si l'unité est en brouillon.
    - Ajout du champ `dependency_status_details` dans `fieldsets` (section *Publication & Dépendances*) listant précisément chaque dépendance non publiée (thème, mot cible, caractères en révision).
  - **`LearningThemeAdmin` :**
    - Ajout de la colonne `units_status_summary` affichant le ratio unités publiées / total.

---

## 3. Validation et tests

### Tests Django
Exécution de la suite de tests backend (`python manage.py test`) :
- **23 tests exécutés avec succès (0 échec)**
- 4 nouveaux tests éditoriaux dédiés dans `EditorialDraftProtectionTests` :
  1. `test_anonymous_cannot_see_draft_units_or_themes` : vérifie le masquage des unités/thèmes brouillons pour les anonymes.
  2. `test_staff_can_preview_drafts` : vérifie l'accès aux brouillons pour les utilisateurs staff.
  3. `test_anonymous_unit_detail_masks_unpublished_nested_relations` : vérifie qu'une unité publiée ayant un mot cible en brouillon et des caractères en révision masque ces éléments pour le public tout en restant valide.
  4. `test_audio_internal_fields_stripped_for_anonymous` : vérifie le masquage de `notes`, `speaker_name`, et `recording_quality` pour le public et leur présence pour le staff.
- 1 test dédié dans `OfflinePackGeneratorTests` (`test_published_pack_excludes_draft_items`) confirmant l'exclusion totale des brouillons lors de la génération d'un pack publié.

### Tests Flutter et analyse mobile
- **27 tests Flutter exécutés avec succès (0 échec).**
- **`flutter analyze --no-pub` : 0 anomalie.**

### Intégrité des données en base
Vérification par sonde sur la base locale :
- `LearningTheme` : 2 (`draft`)
- `LearningUnit` : 4 (`published`)
- `Character` : 50 (`review`)
- `Word` : 3 (`draft`), 1 (`published`)
- `AudioAsset` : 2 (`published`)
**Aucune modification ni écrasement de statut n'a été appliqué en base de données.**
