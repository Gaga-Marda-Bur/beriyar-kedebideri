import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/widgets/bk_learning_node.dart';
import 'package:mobile/core/widgets/bk_option_card.dart';

void main() {
  test('both themes provide Erfe fallback without replacing Latin', () {
    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      final style = theme.textTheme.bodyMedium!;
      expect(style.fontFamily, 'Roboto');
      expect(style.fontFamilyFallback, contains('Kedebideri'));
    }
  });
  test('explicit Latin styles retain Erfe fallback', () {
    for (final style in [
      AppTextStyles.latinHeading,
      AppTextStyles.latinInstruction,
      AppTextStyles.latinCaption,
    ]) {
      expect(style.fontFamilyFallback, contains('Kedebideri'));
    }
  });
  for (final dark in [false, true]) {
    testWidgets('compact mixed-script layout dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final glyphs = String.fromCharCodes([
        ...List.generate(25, (i) => 0x16ea0 + i),
        ...List.generate(25, (i) => 0x16ebb + i),
      ]);
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: ListView(
                  children: [
                    const BkLearningNode(
                      title: 'Unité 2 : La consonne Te (𖺵) et le mot "ta"',
                    ),
                    const BkOptionCard(
                      label: 'Beřiya العربية 𖺢',
                      erfeText: '𖺠̄',
                    ),
                    Text(glyphs),
                    const Text('𖺠̄ 𖺣̄ 𖺧̄ 𖺯̄ 𖺶̄'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(glyphs), findsOneWidget);
      }
    });
  }
}
