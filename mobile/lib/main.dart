import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/api/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A13 : filet de sécurité si une release a contourné la vérification Gradle
  // (ex. build iOS). On refuse de parler à une API locale ou HTTP.
  final configIssues = ApiConfig.releaseConfigurationIssues();
  if (configIssues.isNotEmpty) {
    runApp(InvalidBuildConfigurationApp(issues: configIssues));
    return;
  }

  final appState = AppState();
  await appState.load();

  runApp(
    ChangeNotifierProvider.value(value: appState, child: const BeriyarApp()),
  );
}

class InvalidBuildConfigurationApp extends StatelessWidget {
  final List<String> issues;

  const InvalidBuildConfigurationApp({super.key, required this.issues});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF061A14),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFD4AF37),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Version indisponible\n'
                  'Version unavailable\n'
                  'النسخة غير متاحة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Installe une version à jour ou contacte le projet.\n'
                  'Install an updated version or contact the project.\n'
                  'ثبّت نسخة محدّثة أو تواصل مع المشروع.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
