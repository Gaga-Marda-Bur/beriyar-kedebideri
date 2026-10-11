import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/beriya/utf16_safe.dart';

void main() {
  group('Utf16Safe tests for Beriya Erfe SMP characters', () {
    test('Beriya Erfe characters take 2 UTF-16 code units', () {
      const be = '𖺡';
      expect(be.length, equals(2));
      expect(be.runes.length, equals(1));
    });

    test('deleteBefore correctly deletes 2 code units for surrogate pairs', () {
      const word = '𖺡𖺣'; // two Beriya characters = 4 UTF-16 units
      expect(word.length, equals(4));

      final (afterOneDelete, offset1) = Utf16Safe.deleteBefore(word, 4);
      expect(afterOneDelete, equals('𖺡'));
      expect(offset1, equals(2));

      final (afterTwoDelete, offset2) = Utf16Safe.deleteBefore(afterOneDelete, offset1);
      expect(afterTwoDelete, equals(''));
      expect(offset2, equals(0));
    });

    test('dropLast removes the last surrogate pair cleanly', () {
      const text = '𖺵𖺠';
      final dropped = Utf16Safe.dropLast(text);
      expect(dropped, equals('𖺵'));
      expect(Utf16Safe.dropLast(dropped), equals(''));
      expect(Utf16Safe.dropLast(''), equals(''));
    });

    test('sanitize strips orphaned high and low surrogates', () {
      // Create broken surrogate by taking half of '𖺡' (\uD81B\uDEA1)
      final brokenHigh = String.fromCharCode(0xD81B);
      final brokenLow = String.fromCharCode(0xDEA1);

      expect(Utf16Safe.sanitize(brokenHigh), equals(''));
      expect(Utf16Safe.sanitize(brokenLow), equals(''));
      expect(Utf16Safe.sanitize(['abc', brokenHigh, 'def'].join()), equals('abcdef'));
      expect(Utf16Safe.sanitize(['𖺡', brokenLow, '𖺣'].join()), equals('𖺡𖺣'));
    });
  });
}
