import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/editor/models/beriya_draft.dart';
import 'package:mobile/features/editor/services/beriya_draft_storage.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeriyaDraft Model Tests', () {
    test('Initial draft is empty and has sensible defaults', () {
      final draft = BeriyaDraft.initial();
      expect(draft.isEmpty, isTrue);
      expect(draft.title, isEmpty);
      expect(draft.content, isEmpty);
      expect(draft.fontSize, 22.0);
      expect(draft.alignment, 'left');
      expect(draft.theme, 'dark_forest');
    });

    test('Serialization to/from JSON roundtrips correctly', () {
      final now = DateTime.now();
      final draft = BeriyaDraft(
        id: 'draft_123',
        title: '𖺗𖺁𖺀 𖺠𖺡',
        content: '𖺀𖺁𖺂 𖺃𖺄𖺅\n𖺆𖺇𖺈',
        fontSize: 28.0,
        alignment: 'center',
        theme: 'golden',
        updatedAt: now,
      );

      final jsonStr = draft.toJson();
      final deserialized = BeriyaDraft.fromJson(jsonStr);

      expect(deserialized.id, 'draft_123');
      expect(deserialized.title, '𖺗𖺁𖺀 𖺠𖺡');
      expect(deserialized.content, '𖺀𖺁𖺂 𖺃𖺄𖺅\n𖺆𖺇𖺈');
      expect(deserialized.fontSize, 28.0);
      expect(deserialized.alignment, 'center');
      expect(deserialized.theme, 'golden');
      expect(deserialized.isEmpty, isFalse);
    });

    test('copyWith properly updates selective attributes', () {
      final draft = BeriyaDraft.initial();
      final updated = draft.copyWith(
        title: 'Nouveau titre',
        theme: 'cream',
        fontSize: 32.0,
      );

      expect(updated.title, 'Nouveau titre');
      expect(updated.theme, 'cream');
      expect(updated.fontSize, 32.0);
      expect(updated.alignment, 'left'); // unchanged
    });
  });

  group('BeriyaDraftStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadActiveDraft returns initial draft when empty', () async {
      final draft = await BeriyaDraftStorage.loadActiveDraft();
      expect(draft.isEmpty, isTrue);
    });

    test('saveDraft and loadActiveDraft persist state correctly', () async {
      final draft = BeriyaDraft(
        id: 'test_save',
        title: 'Texte test',
        content: '𖺠𖺡𖺢',
        updatedAt: DateTime.now(),
      );

      final saved = await BeriyaDraftStorage.saveDraft(draft);
      expect(saved, isTrue);

      final loaded = await BeriyaDraftStorage.loadActiveDraft();
      expect(loaded.title, 'Texte test');
      expect(loaded.content, '𖺠𖺡𖺢');
    });

    test('clearActiveDraft removes saved draft', () async {
      final draft = BeriyaDraft(
        id: 'test_clear',
        title: 'À supprimer',
        content: '...',
        updatedAt: DateTime.now(),
      );
      await BeriyaDraftStorage.saveDraft(draft);

      final cleared = await BeriyaDraftStorage.clearActiveDraft();
      expect(cleared, isTrue);

      final afterClear = await BeriyaDraftStorage.loadActiveDraft();
      expect(afterClear.isEmpty, isTrue);
    });
  });

  group('BeriyaPdfService Tests', () {
    test('generatePdfBytes produces valid PDF byte stream with header', () async {
      final draft = BeriyaDraft(
        id: 'pdf_test',
        title: 'Titre Document',
        content: 'Paragraphe 1\n\nParagraphe 2',
        fontSize: 24.0,
        alignment: 'left',
        theme: 'dark_forest',
        updatedAt: DateTime(2026, 9, 25),
      );

      final bytes = await BeriyaPdfService.generatePdfBytes(draft);

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);

      // Verify PDF magic header %PDF-
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });
}
