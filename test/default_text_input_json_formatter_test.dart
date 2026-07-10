import 'package:flutter/services.dart';
import 'package:flutter_jsonschema_builder/src/utils/default_text_input_json_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [TextEditingValue] with the caret collapsed at the end of [text].
TextEditingValue _value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  group('DefaultTextInputJsonFormatter without a pattern', () {
    late DefaultTextInputJsonFormatter formatter;

    setUp(() {
      formatter = DefaultTextInputJsonFormatter();
    });

    test('accepts appending a regular character', () {
      final result = formatter.formatEditUpdate(_value('ab'), _value('abc'));
      expect(result.text, 'abc');
    });

    test('places the caret at the end of the text', () {
      final result = formatter.formatEditUpdate(_value('ab'), _value('abc'));
      expect(result.selection.baseOffset, result.text.length);
    });

    test('rejects a lone newline character', () {
      // RegExp(r'.') does not match a line terminator.
      final result = formatter.formatEditUpdate(_value(''), _value('\n'));
      expect(result.text, '');
    });

    test('deletions pass through unchanged', () {
      final result = formatter.formatEditUpdate(_value('abc'), _value('ab'));
      expect(result.text, 'ab');
    });

    test('an equal-length replacement passes through unchanged', () {
      final result = formatter.formatEditUpdate(_value('ab'), _value('xy'));
      expect(result.text, 'xy');
    });
  });

  group('DefaultTextInputJsonFormatter with a pattern', () {
    test('accepts input matching the pattern', () {
      final formatter = DefaultTextInputJsonFormatter(pattern: r'^[a-z]+$');
      final result = formatter.formatEditUpdate(_value('ab'), _value('abc'));
      expect(result.text, 'abc');
    });

    test('rejects input that does not match the pattern', () {
      final formatter = DefaultTextInputJsonFormatter(pattern: r'^[a-z]+$');
      final result = formatter.formatEditUpdate(_value('ab'), _value('ab1'));
      expect(result.text, 'ab');
    });

    test('uses a partial (contains) match, not a full match', () {
      // The pattern only needs to match somewhere in the text.
      final formatter = DefaultTextInputJsonFormatter(pattern: r'[0-9]');
      final result = formatter.formatEditUpdate(_value('a'), _value('a1'));
      expect(result.text, 'a1');
    });

    test('deletions bypass the pattern check', () {
      final formatter = DefaultTextInputJsonFormatter(pattern: r'^[a-z]+$');
      // "ab1" would not match the pattern, but shrinking text is always kept.
      final result = formatter.formatEditUpdate(_value('ab12'), _value('ab1'));
      expect(result.text, 'ab1');
    });
  });
}
