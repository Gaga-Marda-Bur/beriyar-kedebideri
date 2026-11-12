import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/beriya/transliteration.dart';
import 'package:mobile/shared/beriya/erfe_input_formatter.dart';
import 'package:mobile/shared/beriya/transliteration_dialog.dart';
import 'package:mobile/features/quiz/models/quiz_question_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/cache/cache_keys.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:mobile/core/network/backend_status_service.dart';
import 'package:mobile/features/editor/models/beriya_draft.dart';

class _OfflineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline search finds canonical and historical Erfe without rewriting cache',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cache = OnlineContentCacheService();
      await cache.saveList(
        key: CacheKeys.words,
        items: [
          {'id': 1, 'beriya_text': '𖺻𖺡'},
        ],
      );
      final service = CachedContentService(
        backendStatusService: _OfflineBackend(),
        cacheService: cache,
      );
      final words = await service.loadWords(search: '𖺠𖺡');
      expect(words.map((w) => w.id), [1]);
      expect(words.single.beriyaText, '𖺻𖺡');
      expect(
        (await cache.readList(key: CacheKeys.words)).single['beriya_text'],
        '𖺻𖺡',
      );
    },
  );
  test(
    'new draft serialization canonicalizes, historical import remains intact',
    () {
      final draft = BeriyaDraft.initial().copyWith(
        title: '𖺻',
        content: '𖺼\n😀',
      );
      expect(draft.toMap()['content'], '𖺡\n😀');
      final loaded = BeriyaDraft.fromMap({'title': '𖺻', 'content': '𖺼'});
      expect(loaded.content, '𖺼');
      expect(loaded.toMap()['content'], '𖺡');
    },
  );
  test('cross-platform reference vectors and round trips', () {
    final vectors =
        jsonDecode(
              File(
                '../shared/linguistics/transliteration_vectors.json',
              ).readAsStringSync(),
            )
            as List;
    for (final v in vectors) {
      expect(
        transliterate(
          v['input'] as String,
          WritingScript.values.byName(v['source'] as String),
          WritingScript.values.byName(v['target'] as String),
          latinLowercase: v['lowercase'] as bool,
        ).toJson(),
        v['expected'],
        reason: v['name'] as String,
      );
    }
    final ref =
        jsonDecode(
              File(
                '../shared/linguistics/beriya_erfe_transliteration_mapping.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final r in ref['letters'] as List) {
      expect(normalizeErfe(r['erfe_lower_alias'] as String), r['erfe']);
      for (final script in [WritingScript.latin, WritingScript.arabic]) {
        expect(
          transliterate(
            transliterate(r['erfe'] as String, WritingScript.erfe, script).text,
            script,
            WritingScript.erfe,
          ).text,
          r['erfe'],
        );
      }
    }
  });
  test('paste multiline, UTF16 selection and active composition', () {
    const formatter = ErfeInputFormatter();
    const pasted = TextEditingValue(
      text: '𖺻𖺼\n😀',
      selection: TextSelection(baseOffset: 2, extentOffset: 7),
    );
    final result = formatter.formatEditUpdate(TextEditingValue.empty, pasted);
    expect(result.text, '𖺠𖺡\n😀');
    expect(result.selection, pasted.selection);
    const composing = TextEditingValue(
      text: 'R\u030c',
      composing: TextRange(start: 0, end: 2),
    );
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, composing),
      composing,
    );
    final committed = formatter.formatEditUpdate(
      composing,
      composing.copyWith(
        composing: TextRange.empty,
        selection: const TextSelection.collapsed(offset: 2),
      ),
    );
    expect(committed.text, 'Ř');
    expect(committed.selection.extentOffset, 1);
  });
  test('learning accepts canonical input against historical lower Erfe', () {
    expect(
      QuizQuestionModel.evaluateTextAnswer(submitted: '𖺠𖺡', expected: '𖺻𖺼'),
      isTrue,
    );
    expect(
      QuizQuestionModel.evaluateTextAnswer(
        submitted: '𖺠',
        expected: '𖺻\u0304',
      ),
      isFalse,
    );
  });
  testWidgets('explicit conversion, selection, insertion and undo', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'ABD\nABD');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTransliterationDialog(context, controller),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<WritingScript>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latin').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<WritingScript>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erfe').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convertir'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget(find.byKey(const Key('conversion-output'))) as TextField)
          .controller!
          .text,
      '𖺠𖺡𖺢',
    );
    expect(controller.text, 'ABD\nABD');
    await tester.tap(find.text('Insérer'));
    await tester.pumpAndSettle();
    expect(controller.text, '𖺠𖺡𖺢\nABD');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(controller.text, 'ABD\nABD');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    await tester.pump(const Duration(seconds: 2));
    controller.dispose();
  });
}
