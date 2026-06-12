import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../features/home/screens/home_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/theme/app_theme.dart';
import 'app_state.dart';

import '../features/alphabet/screens/alphabet_screen.dart';
import '../features/vocabulary/screens/vocabulary_screen.dart';
import '../features/learning/screens/learning_path_screen.dart';
import '../features/no_ena/screens/no_ena_screen.dart';
import '../features/offline_packs/screens/offline_packs_screen.dart';
import '../features/quiz/screens/quiz_screen.dart';
import '../features/offline_packs/screens/my_packs_screen.dart';
import '../features/content_hub/screens/content_hub_screen.dart';
import '../features/learning/screens/unit_practice_screen.dart';
import '../features/feedback/screens/feedback_screen.dart';

class BeriyarApp extends StatelessWidget {
  const BeriyarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Beřiyar Kedebideři',
      theme: AppTheme.darkTheme(),
      locale: state.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/alphabet': (_) => const AlphabetScreen(),
        '/vocabulary': (_) => const VocabularyScreen(),
        '/learning': (_) => const LearningPathScreen(),
        '/quiz': (_) => const QuizScreen(),
        '/no-ena': (_) => const NoEnaScreen(),
        '/offline-packs': (_) => const OfflinePacksScreen(),
        '/my-packs': (_) => const MyPacksScreen(),
        '/content': (_) => const ContentHubScreen(),
        '/feedback': (_) => const FeedbackScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/unit-practice') {
          final unitSlug = settings.arguments?.toString() ?? '';

          return MaterialPageRoute(
            builder: (_) => UnitPracticeScreen(unitSlug: unitSlug),
          );
        }

        return null;
      },
    );
  }
}