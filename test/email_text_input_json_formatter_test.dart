import 'package:flutter/services.dart';
import 'package:flutter_jsonschema_builder/src/utils/email_text_input_json_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [TextEditingValue] with the caret collapsed at the end of [text].
TextEditingValue _value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  late EmailTextInputJsonFormatter formatter;

  setUp(() {
    formatter = EmailTextInputJsonFormatter();
  });

  group('EmailTextInputJsonFormatter valid input', () {
    test('accepts appending a regular character', () {
      final result = formatter.formatEditUpdate(_value('a'), _value('ab'));
      expect(result.text, 'ab');
    });

    test('accepts building a full valid email character by character', () {
      const email = 'john.doe@example.com';
      var current = '';
      for (var i = 0; i < email.length; i++) {
        final next = email.substring(0, i + 1);
        final result =
            formatter.formatEditUpdate(_value(current), _value(next));
        expect(result.text, next,
            reason: 'expected "$next" to be accepted while typing');
        current = result.text;
      }
    });

    test('accepts a single @', () {
      final result =
          formatter.formatEditUpdate(_value('john'), _value('john@'));
      expect(result.text, 'john@');
    });

    test('accepts a special atom character when it is not the first char', () {
      final result = formatter.formatEditUpdate(_value('a'), _value('a!'));
      expect(result.text, 'a!');
    });

    test('accepts text just under the 255 character limit', () {
      final old = 'a' * 253;
      final next = 'a' * 254;
      final result = formatter.formatEditUpdate(_value(old), _value(next));
      expect(result.text, next);
    });
  });

  group('EmailTextInputJsonFormatter rejected input', () {
    test('rejects a leading special atom character', () {
      final result = formatter.formatEditUpdate(_value(''), _value('!'));
      expect(result.text, '');
    });

    test('rejects extending text that starts with an atom character', () {
      // Even though "!a" is longer, the leading atom char is re-checked.
      final result = formatter.formatEditUpdate(_value('!'), _value('!a'));
      expect(result.text, '!');
    });

    test('rejects a second @', () {
      final result =
          formatter.formatEditUpdate(_value('a@b'), _value('a@b@'));
      expect(result.text, 'a@b');
    });

    test('rejects reaching the 255 character limit', () {
      final old = 'a' * 254;
      final next = 'a' * 255;
      final result = formatter.formatEditUpdate(_value(old), _value(next));
      expect(result.text, old);
    });

    test('rejects a paste longer than the limit', () {
      final next = 'a' * 300;
      final result = formatter.formatEditUpdate(_value(''), _value(next));
      expect(result.text, '');
    });
  });

  group('EmailTextInputJsonFormatter deletions', () {
    test('pure deletion of a trailing character passes through', () {
      final result = formatter.formatEditUpdate(_value('abc'), _value('ab'));
      expect(result.text, 'ab');
    });

    test('pure deletion of a middle range passes through', () {
      final result =
          formatter.formatEditUpdate(_value('abcde'), _value('ae'));
      expect(result.text, 'ae');
    });

    test('clearing the whole field passes through', () {
      final result = formatter.formatEditUpdate(_value('abc'), _value(''));
      expect(result.text, '');
    });

    test('deleting a leading char to expose an atom char is allowed', () {
      // Deleting the "a" leaves "!b" which starts with an atom char, but a
      // pure deletion is always permitted.
      final result = formatter.formatEditUpdate(_value('a!b'), _value('!b'));
      expect(result.text, '!b');
    });

    test('a shrinking selection-replace is still validated', () {
      // Replacing all of "abcdef" with "@@" shrinks the text but is not a
      // pure deletion, so the two-@ rule still rejects it.
      final result =
          formatter.formatEditUpdate(_value('abcdef'), _value('@@'));
      expect(result.text, 'abcdef');
    });
  });
}
