import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/audio/audio_url_player.dart';
import 'package:mobile/core/audio/bk_audio_preferences.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/app_tokens.dart';
import 'package:mobile/core/widgets/bk_audio_hero_button.dart';
import 'package:mobile/core/widgets/bk_feedback_sheet.dart';
import 'package:mobile/core/widgets/bk_learning_node.dart';
import 'package:mobile/core/widgets/bk_option_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Lot 4B.1 — Tokens, Thèmes Clair/Sombre & Contraste WCAG', () {
    test('Les tokens Sahel Modern définissent les couleurs, rayons, élévations et typographies', () {
      expect(AppTokens.brandDark, const Color(0xFF061A14));
      expect(AppTokens.surfaceDark, const Color(0xFF0B251D));
      expect(AppTokens.brandNight, const Color(0xFF0F3227));
      expect(AppTokens.surfaceLight, const Color(0xFF133D30));
      expect(AppTokens.brandGreen, const Color(0xFF1B4D3E));
      expect(AppTokens.brandGold, const Color(0xFFD4AF37));
      expect(AppTokens.lightBackground, const Color(0xFFFAF7F0));
      expect(AppTokens.lightSurface, const Color(0xFFFFFFFF));

      expect(AppTokens.elevationNone, 0.0);
      expect(AppTokens.elevationLow, 2.0);
      expect(AppTokens.elevationMedium, 4.0);
      expect(AppTokens.elevationHigh, 8.0);

      expect(AppTokens.radiusControl, 12.0);
      expect(AppTokens.radiusCard, 20.0);
      expect(AppTokens.radiusSheet, 28.0);
      expect(AppTokens.radiusPill, 999.0);

      expect(AppTokens.minTouchTarget, greaterThanOrEqualTo(48.0));
      expect(AppTokens.audioHeroButtonSize, greaterThanOrEqualTo(48.0));
      expect(AppTokens.learningNodeSize, greaterThanOrEqualTo(48.0));
      expect(AppTokens.optionCardMinHeight, greaterThanOrEqualTo(48.0));
    });

    test('Contraste WCAG AA/AAA vérifié en Thème Sombre et en Thème Clair', () {
      const dark = BkThemePalette.dark;
      const light = BkThemePalette.light;

      // Thème sombre : texte primaire et glyphes Erfe sur fond et surfaces
      expect(
        AppColors.contrastRatio(dark.textPrimary, dark.background),
        greaterThanOrEqualTo(12.0),
        reason: 'Le texte blanc sur fond nuit #061A14 doit dépasser AAA (7:1)',
      );
      expect(
        AppColors.contrastRatio(dark.textSecondary, dark.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'Le texte secondaire #C2CDBE sur surface sombre doit respecter WCAG AA (4.5:1)',
      );
      expect(
        AppColors.contrastRatio(dark.erfeGlyphColor, dark.background),
        greaterThanOrEqualTo(7.0),
        reason: 'Les glyphes Erfe dorés sur fond nuit doivent dépasser AAA (7:1)',
      );
      expect(
        AppColors.contrastRatio(dark.accentGoldForeground, dark.accentGold),
        greaterThanOrEqualTo(7.0),
        reason: 'Le texte sur bouton Or primaire doit être hautement lisible',
      );

      // Thème clair : texte primaire et glyphes Erfe sur fond sable et surface ivoire
      expect(
        AppColors.contrastRatio(light.textPrimary, light.background),
        greaterThanOrEqualTo(12.0),
        reason: 'Le texte #061A14 sur sable clair #FAF7F0 doit dépasser AAA (7:1)',
      );
      expect(
        AppColors.contrastRatio(light.textSecondary, light.surface),
        greaterThanOrEqualTo(7.0),
        reason: 'Le texte secondaire sur surface ivoire doit dépasser AAA (7:1)',
      );
      expect(
        AppColors.contrastRatio(light.erfeGlyphColor, light.surface),
        greaterThanOrEqualTo(12.0),
        reason: 'Les glyphes Erfe en mode clair doivent offrir une netteté maximale',
      );
    });

    test('AppTheme.darkTheme et AppTheme.lightTheme exposent BkThemePalette et supportent lerp', () {
      final darkTheme = AppTheme.darkTheme();
      final lightTheme = AppTheme.lightTheme();

      expect(darkTheme.brightness, Brightness.dark);
      expect(lightTheme.brightness, Brightness.light);

      final darkExt = darkTheme.extension<BkThemePalette>();
      final lightExt = lightTheme.extension<BkThemePalette>();
      expect(darkExt, isNotNull);
      expect(lightExt, isNotNull);
      expect(darkExt!.background, AppTokens.brandDark);
      expect(lightExt!.background, AppTokens.lightBackground);

      final interpolated = darkExt.lerp(lightExt, 0.5);
      expect(interpolated.background, isNot(equals(darkExt.background)));
    });
  });

  group('Lot 4B.1 — Rendu Unicode Erfe & Police Kedebideri', () {
    testWidgets('Rendu exact des caractères Unicode Erfe du corpus (𖺠, 𖺡, 𖺣, 𖺵) avec la police Kedebideri', (tester) async {
      const erfeSample = '𖺠 𖺡 𖺣 𖺵';

      for (final theme in [AppTheme.darkTheme(), AppTheme.lightTheme()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    Text(erfeSample, key: const ValueKey('hero'), style: AppTextStyles.erfeDisplayHeroOf(context)),
                    Text(erfeSample, key: const ValueKey('word'), style: AppTextStyles.erfeWordTitleOf(context)),
                    Text(erfeSample, key: const ValueKey('opt'), style: AppTextStyles.erfeOptionTextOf(context)),
                  ],
                ),
              ),
            ),
          ),
        );

        final heroText = tester.widget<Text>(find.byKey(const ValueKey('hero')));
        final wordText = tester.widget<Text>(find.byKey(const ValueKey('word')));
        final optText = tester.widget<Text>(find.byKey(const ValueKey('opt')));

        expect(heroText.style!.fontFamily, 'Kedebideri');
        expect(heroText.style!.fontSize, 52.0);
        expect(heroText.style!.letterSpacing, 1.5);

        expect(wordText.style!.fontFamily, 'Kedebideri');
        expect(wordText.style!.fontSize, 34.0);

        expect(optText.style!.fontFamily, 'Kedebideri');
        expect(optText.style!.fontSize, 26.0);
      }
    });
  });

  group('Lot 4B.1 — Préférence auto-play audio & BkAudioHeroButton', () {
    test('BkAudioPreferencesService persiste et charge la préférence utilisateur', () async {
      // Valeur par défaut = true
      final initial = await BkAudioPreferencesService.load();
      expect(initial.autoPlayAudio, isTrue);

      await BkAudioPreferencesService.setAutoPlayAudio(false);
      expect(await BkAudioPreferencesService.isAutoPlayEnabled(), isFalse);

      await BkAudioPreferencesService.setAutoPlayAudio(true);
      expect(await BkAudioPreferencesService.isAutoPlayEnabled(), isTrue);
    });

    testWidgets('BkAudioHeroButton déclenche auto-play si activé, le bloque si désactivé, et garde le bouton Réécouter visible', (tester) async {
      int playCalls = 0;
      int slowCalls = 0;

      // 1. Auto-play activé par défaut
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: Center(
              child: BkAudioHeroButton(
                autoPlay: true,
                onPlay: () => playCalls++,
                onPlaySlow: () => slowCalls++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(playCalls, 1, reason: 'La lecture automatique doit se déclencher une fois au montage');

      // Vérifier que le bouton de réécoute et le bouton lent sont visibles et >= 48dp
      final replayFinder = find.byKey(const ValueKey('bk-audio-replay-button'));
      final slowFinder = find.byKey(const ValueKey('bk-audio-slow-button'));
      final heroCircleFinder = find.byKey(const ValueKey('bk-audio-hero-circle'));

      expect(replayFinder, findsOneWidget);
      expect(slowFinder, findsOneWidget);
      expect(tester.getSize(replayFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(slowFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(heroCircleFinder).width, greaterThanOrEqualTo(84.0));

      await tester.tap(replayFinder);
      await tester.pump();
      expect(playCalls, 2);

      await tester.tap(slowFinder);
      await tester.pump();
      expect(slowCalls, 1);

      // 2. Auto-play désactivé par l'utilisateur dans ses préférences
      await BkAudioPreferencesService.setAutoPlayAudio(false);
      int playCallsWhenDisabled = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: Center(
              child: BkAudioHeroButton(
                key: const ValueKey('second-hero'),
                autoPlay: true,
                onPlay: () => playCallsWhenDisabled++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        playCallsWhenDisabled,
        0,
        reason: 'Lorsque la préférence auto-play est désactivée, aucun son ne doit partir automatiquement',
      );

      // Le clic manuel sur Réécouter fonctionne toujours
      await tester.tap(find.byKey(const ValueKey('bk-audio-replay-button')));
      await tester.pump();
      expect(playCallsWhenDisabled, 1);
    });
  });

  group('Lot 4B.1 — Composants BkLearningNode, BkOptionCard, BkFeedbackSheet', () {
    testWidgets('BkLearningNode gère les états verrouillé, en cours, maîtrisé et à réviser', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: Column(
              children: [
                BkLearningNode(
                  key: const ValueKey('node-locked'),
                  title: 'Unité Verrouillée',
                  status: BkLearningNodeStatus.locked,
                  onTap: () => tapped = true,
                ),
                BkLearningNode(
                  key: const ValueKey('node-active'),
                  title: 'Unité 1',
                  subtitle: '3 min',
                  erfeSymbol: '𖺡',
                  status: BkLearningNodeStatus.inProgress,
                  progress: 0.5,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Clic sur nœud verrouillé ne déclenche rien
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('node-locked')),
          matching: find.byKey(const ValueKey('bk-learning-node-tap')),
        ),
      );
      expect(tapped, isFalse);

      // Clic sur nœud actif déclenche l'action
      final activeTap = find.descendant(
        of: find.byKey(const ValueKey('node-active')),
        matching: find.byKey(const ValueKey('bk-learning-node-tap')),
      );
      expect(tester.getSize(activeTap).height, greaterThanOrEqualTo(48.0));
      await tester.tap(activeTap);
      expect(tapped, isTrue);
      expect(find.text('𖺡'), findsOneWidget);
    });

    testWidgets('BkOptionCard affiche le glyphe Erfe, gère la sélection et l’écoute audio', (tester) async {
      bool cardTapped = false;
      bool audioTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: BkOptionCard(
                erfeText: '𖺠',
                label: 'Caractère 𖺠',
                subtitle: 'Option A',
                state: BkOptionCardState.selected,
                onTap: () => cardTapped = true,
                onPlayAudio: () => audioTapped = true,
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(BkOptionCard);
      expect(tester.getSize(cardFinder).height, greaterThanOrEqualTo(64.0));

      final audioBtn = find.byKey(const ValueKey('bk-option-audio-button'));
      expect(tester.getSize(audioBtn).width, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(audioBtn).height, greaterThanOrEqualTo(48.0));

      await tester.tap(audioBtn);
      expect(audioTapped, isTrue);

      await tester.tap(find.byKey(const ValueKey('bk-option-card-tap')));
      expect(cardTapped, isTrue);
    });

    testWidgets('BkFeedbackSheet affiche le feedback positif/encouragement et le bouton de réécoute', (tester) async {
      bool continued = false;
      bool replayed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: BkFeedbackSheet(
              type: BkFeedbackType.encouragement,
              title: 'Pas grave, écoute encore et continue.',
              message: 'Écoute bien la différence.',
              erfeText: '𖺡',
              onReplayAudio: () => replayed = true,
              onContinue: () => continued = true,
            ),
          ),
        ),
      );

      final replayBtn = find.byKey(const ValueKey('bk-feedback-replay-button'));
      final continueBtn = find.byKey(const ValueKey('bk-feedback-continue-button'));

      expect(replayBtn, findsOneWidget);
      expect(continueBtn, findsOneWidget);
      expect(tester.getSize(replayBtn).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(continueBtn).height, greaterThanOrEqualTo(48.0));

      await tester.tap(replayBtn);
      expect(replayed, isTrue);

      await tester.tap(continueBtn);
      expect(continued, isTrue);
    });
  });

  group('Lot 4B.1 — Multi-tailles d’écran (320x568, 360x800, 800x1280) & Thèmes', () {
    final screenSizes = <String, Size>{
      'Compact SE (320x568)': const Size(320, 568),
      'Samsung SM-A336E (360x800)': const Size(360, 800),
      'Tablette (800x1280)': const Size(800, 1280),
    };

    for (final entry in screenSizes.entries) {
      for (final isDark in [true, false]) {
        testWidgets(
          'Aucun overflow sur ${entry.key} en mode ${isDark ? "Sombre" : "Clair"}',
          (tester) async {
            tester.view.physicalSize = entry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              MaterialApp(
                theme: isDark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        BkAudioHeroButton(
                          status: AudioPlaybackStatus.playing,
                          onPlay: () {},
                          onPlaySlow: () {},
                        ),
                        const SizedBox(height: 16),
                        BkLearningNode(
                          title: 'Unité 1 — 𖺠 / 𖺡',
                          subtitle: '3 min',
                          erfeSymbol: '𖺠',
                          status: BkLearningNodeStatus.completed,
                          progress: 1.0,
                          onTap: () {},
                        ),
                        const SizedBox(height: 16),
                        BkOptionCard(
                          erfeText: '𖺠',
                          label: 'Caractère 𖺠',
                          state: BkOptionCardState.correct,
                          onTap: () {},
                          onPlayAudio: () {},
                        ),
                        const SizedBox(height: 16),
                        BkFeedbackSheet(
                          type: BkFeedbackType.positive,
                          title: 'Correct, très bien !',
                          erfeText: '𖺠',
                          onReplayAudio: () {},
                          onContinue: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
