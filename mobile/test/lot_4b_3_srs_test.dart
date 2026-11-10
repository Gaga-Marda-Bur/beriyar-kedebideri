import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/audio/audio_url_player.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/learning/screens/learning_core_unit_screen.dart';
import 'package:mobile/features/learning/screens/srs_review_session_screen.dart';
import 'package:mobile/features/learning/srs/local_srs_service.dart';
import 'package:mobile/features/learning/srs/srs_item_model.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/shared/beriya/beriya_keyboard.dart';

class _FakeAudioUrlPlayer extends AudioUrlPlayer {
  final List<String> playedUrls = <String>[];

  @override
  Future<void> playUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      status.value = AudioPlaybackStatus.idle;
      return;
    }
    playedUrls.add(url);
    status.value = AudioPlaybackStatus.playing;
  }

  @override
  Future<void> stop() async {
    status.value = AudioPlaybackStatus.idle;
  }

  @override
  Future<void> dispose() async {
    status.value = AudioPlaybackStatus.idle;
  }
}

LearningUnitModel _buildUnit({
  String charLabel = 'Lettre A',
  String charAudio = 'https://example.com/audio/char_a.mp3',
  String wordFr = 'Eau',
  String wordAudio = 'https://example.com/audio/word_yi.mp3',
  bool includeSecondChar = true,
}) {
  return LearningUnitModel.fromJson({
    'id': 403,
    'slug': 'unit-srs-pilot-a',
    'title_fr': 'Unité SRS Pilote A',
    'title_en': 'SRS Pilot Unit A',
    'title_ar': 'وحدة المراجعة المتباعدة',
    'description_fr': 'Séance audio-first avec SRS local',
    'description_en': 'Audio-first session with local SRS',
    'description_ar': 'جلسة سمعية مع مراجعة متباعدة',
    'level': 'beginner',
    'estimated_minutes': 5,
    'min_score_to_pass': 70,
    'weight_recognition': 50,
    'weight_tracing': 0,
    'weight_encoding': 50,
    'enable_tracing': false,
    'order_index': 1,
    'status': 'published',
    'is_active': true,
    'available_offline': true,
    'characters': [
      {
        'id': 1,
        'symbol': '𖺡',
        'name': charLabel,
        'name_fr': charLabel,
        'unicode_code': 'U+16EA1',
        'latin_transcription': 'b',
        'phoneme_ipa': 'b',
        'audio_url': charAudio,
      },
      if (includeSecondChar)
        {
          'id': 2,
          'symbol': '𖺢',
          'name': 'Mot B',
          'name_fr': 'Mot B',
          'unicode_code': 'U+16EA2',
          'latin_transcription': 'd',
          'phoneme_ipa': 'd',
          'audio_url': 'https://example.com/audio/char_b.mp3',
        },
    ],
    'words': [
      {
        'id': 10,
        'beriya_text': '𖺡𖺣',
        'latin_transcription': 'be',
        'french_translation': wordFr,
        'translation_fr': wordFr,
        'audio_url': wordAudio,
      },
    ],
    'core_flow': [
      {
        'index': 0,
        'step_type': 'discovery',
        'symbol': '𖺡',
        'label': charLabel,
        'phoneme_ipa': 'b',
        'audio_url': charAudio,
        'weight_category': 'recognition',
      },
      {
        'index': 1,
        'step_type': 'discrimination',
        'instruction': 'Touche le caractère entendu :',
        'target_symbol': '𖺡',
        'other_symbol': '𖺢',
        'audio_url': charAudio,
        'weight_category': 'recognition',
      },
      {
        'index': 2,
        'step_type': 'keyboard_encoding',
        'instruction': 'Compose le mot entendu :',
        'target_word': '𖺡𖺣',
        'french_translation': wordFr,
        'keyboard_keys': ['𖺡', '𖺢', '𖺣'],
        'audio_url': wordAudio,
        'weight_category': 'encoding',
      },
      {
        'index': 3,
        'step_type': 'celebration',
        'title': 'Bravo !',
        'message': 'Séance terminée',
        'target_word': '𖺡𖺣',
        'french_translation': wordFr,
      },
    ],
  });
}

Widget _wrapWithApp(Widget home) {
  return MaterialApp(
    theme: AppTheme.darkTheme(),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lot 4B.3 — Modèle et service SRS local (Étapes 2, 4, 5)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Première réussite : crée un enregistrement avec intervalle 1 jour et maîtrise 1', () async {
      final t0 = DateTime.utc(2026, 11, 10, 12, 0);
      final srs = LocalSrsService(userScope: 'pilot_a', clock: () => t0);

      final record = await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
        label: 'Lettre A',
        audioUrl: 'file:///local/audio/char_a.mp3',
      );

      expect(record, isNotNull);
      expect(record!.stableId, 'char:𖺡');
      expect(record.successCount, 1);
      expect(record.errorCount, 0);
      expect(record.consecutiveSuccesses, 1);
      expect(record.masteryLevel, 1);
      expect(record.intervalDays, 1);
      expect(record.lastReviewedAt, t0);
      expect(record.nextReviewAt, t0.add(const Duration(days: 1)));
      expect(record.isDifficult, isFalse);
    });

    test('2. Réussites successives : progresse sur les paliers 1, 3, 7, 14, 30 jours', () async {
      var now = DateTime.utc(2026, 11, 10, 8, 0);
      final srs = LocalSrsService(userScope: 'pilot_a', clock: () => now);

      final expectedIntervals = [1, 3, 7, 14, 30];
      for (var i = 0; i < expectedIntervals.length; i++) {
        final record = await srs.recordOutcome(
          unitSlug: 'unit-srs-pilot-a',
          itemType: 'word',
          erfeText: '𖺡𖺣',
          correct: true,
        );
        expect(record!.consecutiveSuccesses, i + 1);
        expect(record.masteryLevel, (i + 1).clamp(0, 5));
        expect(record.intervalDays, greaterThanOrEqualTo(expectedIntervals[i]));
        now = record.nextReviewAt;
      }
    });

    test('3. Réponse incorrecte : incrémente errorCount, réinitialise la série et ramène l’intervalle à 1 jour', () async {
      var now = DateTime.utc(2026, 11, 10, 9, 0);
      final srs = LocalSrsService(userScope: 'pilot_a', clock: () => now);

      await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
      );
      now = now.add(const Duration(days: 1));
      await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
      );

      now = now.add(const Duration(days: 3));
      final afterWrong = await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: false,
      );

      expect(afterWrong!.successCount, 2);
      expect(afterWrong.errorCount, 1);
      expect(afterWrong.consecutiveSuccesses, 0);
      expect(afterWrong.intervalDays, 1);
      expect(afterWrong.isDifficult, isTrue);
      expect(afterWrong.nextReviewAt, now.add(const Duration(days: 1)));
    });

    test('4. Réponse vide : ignorée sans pénalité ni création parasite', () async {
      final srs = LocalSrsService(
        userScope: 'pilot_a',
        clock: () => DateTime.utc(2026, 11, 10, 10, 0),
      );

      final result = await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'word',
        erfeText: '𖺡𖺣',
        correct: false,
        submittedAnswer: '   ',
      );

      expect(result, isNull);
      final all = await srs.loadAllMap();
      expect(all, isEmpty);
    });

    test('5. Audio absent : aucune pénalité SRS en cas de réponse incorrecte sans audio', () async {
      final t0 = DateTime.utc(2026, 11, 10, 10, 0);
      final srs = LocalSrsService(userScope: 'pilot_a', clock: () => t0);

      // L'élément a déjà été réussi 2 fois (intervalle 3 jours, maîtrise 2).
      await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
      );
      final before = await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
      );
      expect(before!.masteryLevel, 2);
      expect(before.intervalDays, 3);

      // Exercice avec audio absent et mauvaise réponse -> ne doit PAS pénaliser.
      final afterMissingAudio = await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: false,
        audioMissing: true,
      );

      expect(afterMissingAudio!.errorCount, 0);
      expect(afterMissingAudio.consecutiveSuccesses, 2);
      expect(afterMissingAudio.masteryLevel, 2);
      expect(afterMissingAudio.intervalDays, 3);
    });

    test('6 & 8. Élément renommé, supprimé et réimport de pack : préserve l’identité stable et les compteurs SRS', () async {
      final t0 = DateTime.utc(2026, 11, 10, 11, 0);
      final srs = LocalSrsService(userScope: 'pilot_a', clock: () => t0);

      // Avant réimport : on enregistre des révisions sur 𖺡 et 𖺢.
      await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
        label: 'Ancien libellé A',
        audioUrl: 'https://old.example.com/a.mp3',
      );
      await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺢',
        correct: false,
        label: 'Lettre B supprimée dans v2',
      );

      // Réimport d'une nouvelle version du pack :
      // - 𖺡 a un nouveau libellé et un nouveau chemin audio local.
      // - 𖺢 a été retiré de l'unité v2.
      final reimportedUnit = _buildUnit(
        charLabel: 'Nouveau libellé A v2',
        charAudio: 'file:///local/packs/v2/char_a.mp3',
        includeSecondChar: false,
      );
      await srs.reconcileWithUnit(reimportedUnit);

      final recordA = await srs.getRecord('char:𖺡');
      expect(recordA, isNotNull);
      expect(recordA!.successCount, 1);
      expect(recordA.intervalDays, 1);
      expect(recordA.label, 'Nouveau libellé A v2');
      expect(recordA.audioUrl, 'file:///local/packs/v2/char_a.mp3');

      // Filtrage des éléments supprimés lors de la récupération des échéances de l'unité v2 :
      final allowedIds = <String>{
        for (final c in reimportedUnit.characters)
          SrsItemRecord.buildStableId(itemType: 'char', erfeText: c.symbol),
        for (final w in reimportedUnit.words)
          SrsItemRecord.buildStableId(itemType: 'word', erfeText: w.beriyaText),
      };
      final dueInV2 = await srs.getDueItems(
        unitSlug: 'unit-srs-pilot-a',
        now: t0.add(const Duration(days: 2)),
        allowedStableIds: allowedIds,
      );
      expect(dueInV2.map((e) => e.stableId).toList(), ['char:𖺡']);
    });

    test('7. Changement de date / horloge système reculée : recalcule les échéances sans blocage', () async {
      var now = DateTime.utc(2026, 11, 10, 12, 0);
      final srs = LocalSrsService(userScope: 'pilot_a', clock: () => now);

      await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
      );

      // Avant l'échéance (+12h) : pas encore dû.
      expect(
        await srs.getDueItems(
          now: now.add(const Duration(hours: 12)),
          includeDifficult: false,
        ),
        isEmpty,
      );

      // À l'échéance (+24h) : l'élément arrive à échéance.
      final dueAtDay1 = await srs.getDueItems(
        now: now.add(const Duration(days: 1)),
        includeDifficult: false,
      );
      expect(dueAtDay1, hasLength(1));
      expect(dueAtDay1.first.stableId, 'char:𖺡');

      // Horloge système reculée dans le passé (ex. pile déchargée -> 2025) :
      now = DateTime.utc(2025, 1, 1, 0, 0);
      final afterClockShift = await srs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
      );
      expect(afterClockShift!.lastReviewedAt, now);
      expect(afterClockShift.nextReviewAt, now.add(const Duration(days: 3)));
    });

    test('9 & 10. Fonctionnement hors ligne et persistance après redémarrage', () async {
      final t0 = DateTime.utc(2026, 11, 10, 15, 0);
      final srsBeforeRestart = LocalSrsService(
        userScope: 'offline_learner',
        clock: () => t0,
      );

      await srsBeforeRestart.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'word',
        erfeText: '𖺡𖺣',
        correct: true,
        label: 'Eau',
      );

      // Simulation d'un redémarrage complet de l'application (nouvelle instance).
      final srsAfterRestart = LocalSrsService(
        userScope: 'offline_learner',
        clock: () => t0.add(const Duration(days: 1)),
      );

      final persisted = await srsAfterRestart.getRecord('word:𖺡𖺣');
      expect(persisted, isNotNull);
      expect(persisted!.successCount, 1);
      expect(persisted.intervalDays, 1);
      expect(persisted.label, 'Eau');
    });

    test('11. Isolation entre utilisateurs et migration invité -> compte authentifié', () async {
      final t0 = DateTime.utc(2026, 11, 10, 16, 0);
      final userA = LocalSrsService(userScope: 'user_a', clock: () => t0);
      final userB = LocalSrsService(userScope: 'user_b', clock: () => t0);

      await userA.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'char',
        erfeText: '𖺡',
        correct: true,
      );

      // user_b ne voit pas les données de user_a.
      expect(await userB.loadAllMap(), isEmpty);

      // Migration d'une session invitée vers un compte authentifié :
      final guestSrs = LocalSrsService(
        userScope: 'guest_device_123',
        clock: () => t0,
      );
      await guestSrs.recordOutcome(
        unitSlug: 'unit-srs-pilot-a',
        itemType: 'word',
        erfeText: '𖺡𖺣',
        correct: true,
      );

      await guestSrs.migrateGuestToAccount(
        guestScope: 'guest_device_123',
        accountScope: 'user_a',
      );

      final mergedA = await userA.loadAllMap();
      expect(mergedA.keys, containsAll(['char:𖺡', 'word:𖺡𖺣']));
    });
  });

  group('Lot 4B.3 — Intégration UI : Séance SRS et LearningCoreUnitScreen (Étape 3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'bk_audio_auto_play_v1': false});
    });

    testWidgets(
      'SrsReviewSessionScreen : ne révèle pas la réponse avant essai, ne pénalise pas l’audio absent et affiche le bilan SRS',
      (tester) async {
        final t0 = DateTime.utc(2026, 11, 10, 12, 0);
        final srs = LocalSrsService(userScope: 'ui_test', clock: () => t0);

        final itemWithAudio = (await srs.recordOutcome(
          unitSlug: 'unit-srs-pilot-a',
          itemType: 'char',
          erfeText: '𖺡',
          correct: true,
          label: 'Lettre A',
          audioUrl: 'https://example.com/audio/char_a.mp3',
        ))!;

        final itemMissingAudio = SrsItemRecord(
          stableId: 'word:𖺡𖺣',
          unitSlug: 'unit-srs-pilot-a',
          itemType: 'word',
          erfeText: '𖺡𖺣',
          translationFr: 'Eau',
          audioUrl: '',
          lastReviewedAt: t0,
          nextReviewAt: t0,
          masteryLevel: 2,
          successCount: 2,
          errorCount: 0,
          consecutiveSuccesses: 2,
          intervalDays: 3,
        );
        await srs.saveAllMap({
          itemWithAudio.stableId: itemWithAudio,
          itemMissingAudio.stableId: itemMissingAudio,
        });

        await tester.pumpWidget(
          _wrapWithApp(
            SrsReviewSessionScreen(
              items: [itemWithAudio, itemMissingAudio],
              srsService: srs,
              distractorPool: const ['𖺡', '𖺢', '𖺡𖺣'],
              audioPlayer: _FakeAudioUrlPlayer(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Carte 1 (avec audio) : les options sont affichées sans révéler laquelle est correcte.
        expect(find.byKey(const ValueKey('srs-option-char:𖺡-𖺡')), findsOneWidget);
        expect(find.text('Mémorisation consolidée !'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('srs-option-char:𖺡-𖺡')));
        await tester.pumpAndSettle();
        expect(find.text('Mémorisation consolidée !'), findsOneWidget);

        await tester.ensureVisible(find.text('Continuer'));
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();

        // Carte 2 (audio absent) : bandeau non pénalisant affiché.
        expect(find.byKey(const ValueKey('srs-audio-missing-banner')), findsOneWidget);

        // Même si l'utilisateur touche le distracteur lorsque l'audio est absent,
        // le SRS ne doit pas pénaliser son niveau de maîtrise.
        await tester.tap(find.byKey(const ValueKey('srs-option-word:𖺡𖺣-𖺡')));
        await tester.pumpAndSettle();
        expect(find.text('Audio absent — aucune pénalité'), findsOneWidget);

        await tester.ensureVisible(find.text('Continuer'));
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();

        // Bilan de fin de révision SRS affiché.
        expect(find.byKey(const ValueKey('srs-summary-card')), findsOneWidget);

        final updatedMissingAudio = await srs.getRecord('word:𖺡𖺣');
        expect(updatedMissingAudio!.errorCount, 0);
        expect(updatedMissingAudio.masteryLevel, 2);
      },
    );

    testWidgets(
      'LearningCoreUnitScreen : enregistre les résultats SRS à la fin des exercices et propose la séance de révision',
      (tester) async {
        final t0 = DateTime.utc(2026, 11, 10, 12, 0);
        final srs = LocalSrsService(userScope: 'lesson_srs_test', clock: () => t0);
        final unit = _buildUnit();

        await tester.pumpWidget(
          _wrapWithApp(
            LearningCoreUnitScreen(
              unit: unit,
              srsService: srs,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Étape 1 : Présentation (discovery) -> Continuer
        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        // Étape 2 : Discrimination -> Bonne réponse du 1er coup sur 𖺡
        await tester.tap(find.byKey(const ValueKey('answer-1-𖺡')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        // Étape 3 : Encodage -> Saisie de 𖺡𖺣 et validation
        final keyboard = tester.widget<BeriyaKeyboard>(
          find.byType(BeriyaKeyboard),
        );
        keyboard.onInsert('𖺡');
        keyboard.onInsert('𖺣');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('validate-encoding')));
        await tester.tap(find.byKey(const ValueKey('validate-encoding')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        // Étape Finale : Bilan de la session avec badges SRS (+1 j) et bouton de révision espacée.
        expect(find.byKey(const ValueKey('review-mastered-section')), findsOneWidget);
        expect(find.text('+1 j'), findsWidgets);
        expect(find.byKey(const ValueKey('launch-srs-review-button')), findsOneWidget);

        final records = await srs.loadAllMap();
        expect(records['char:𖺡']?.intervalDays, 1);
        expect(records['word:𖺡𖺣']?.intervalDays, 1);
      },
    );
  });
}
