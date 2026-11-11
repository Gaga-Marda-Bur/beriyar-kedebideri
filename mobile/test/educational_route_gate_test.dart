import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/app_state.dart';
import 'package:mobile/features/home/screens/home_screen.dart';

void main() {
  testWidgets(
    'educational direct Premium route resolves to free home, not a hidden commercial screen',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: Builder(
            builder: (context) {
              final app = const BeriyarApp().build(context) as MaterialApp;
              expect(app.routes!['/premium']!(context), isA<HomeScreen>());
              return const SizedBox();
            },
          ),
        ),
      );
    },
  );
}
