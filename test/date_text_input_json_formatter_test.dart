import 'package:flutter/services.dart';
import 'package:flutter_jsonschema_builder/src/utils/date_text_input_json_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [TextEditingValue] with the caret collapsed at the end of [text].
TextEditingValue _value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  late DateTextInputJsonFormatter formatter;

  setUp(() {
    formatter = DateTextInputJsonFormatter();
  });

  group('DateTextInputJsonFormatter valid input', () {
    test('accepts a valid first day digit', () {
      final result = formatter.formatEditUpdate(_value(''), _value('1'));
      expect(result.text, '1');
    });

    test('appends the separator eagerly after the second digit', () {
      final result = formatter.formatEditUpdate(_value('1'), _value('12'));
      expect(result.text, '12-');
    });

    test('accepts the month tens digit', () {
      final result = formatter.formatEditUpdate(_value('12'), _value('120'));
      expect(result.text, '12-0');
    });

    test('places the caret at the end of the reformatted text', () {
      final result = formatter.formatEditUpdate(_value('12'), _value('120'));
      expect(result.selection.baseOffset, result.text.length);
    });

    test('appends the second separator after the fourth digit', () {
      final result =
          formatter.formatEditUpdate(_value('12-0'), _value('12-01'));
      expect(result.text, '12-01-');
    });

    test('accepts input that already contains separators', () {
      final result =
          formatter.formatEditUpdate(_value('12-'), _value('12-0'));
      expect(result.text, '12-0');
    });

    test('accepts a fully typed valid date', () {
      final result = formatter.formatEditUpdate(
        _value('31-12-202'),
        _value('31-12-2024'),
      );
      expect(result.text, '31-12-2024');
    });
  });

  group('DateTextInputJsonFormatter rejected input', () {
    test('rejects an out of range first day digit', () {
      final result = formatter.formatEditUpdate(_value(''), _value('5'));
      expect(result.text, '');
    });

    test('rejects an invalid month tens digit', () {
      // A third digit outside [0-1] cannot start a valid month.
      final result = formatter.formatEditUpdate(_value('12'), _value('123'));
      expect(result.text, '12');
    });

    test('rejects an invalid day once the month digit is typed', () {
      // Day "35" only fails validation at length 4, when the full day and the
      // month tens digit are present.
      final result =
          formatter.formatEditUpdate(_value('35-'), _value('35-0'));
      expect(result.text, '35-');
    });

    test('rejects input longer than 10 characters', () {
      final result = formatter.formatEditUpdate(
        _value('31-12-2024'),
        _value('31-12-20245'),
      );
      expect(result.text, '31-12-2024');
    });
  });

  group('DateTextInputJsonFormatter deletions', () {
    test('deleting a trailing character passes through unchanged', () {
      final result =
          formatter.formatEditUpdate(_value('12-3'), _value('12-'));
      expect(result.text, '12-');
    });

    test('clearing the field passes through', () {
      final result =
          formatter.formatEditUpdate(_value('12-01'), _value(''));
      expect(result.text, '');
    });

    test('an equal-length replacement passes through unchanged', () {
      // oldValue.text.length >= newValue.text.length returns newValue as-is,
      // bypassing reformatting and validation.
      final result = formatter.formatEditUpdate(_value('12'), _value('99'));
      expect(result.text, '99');
    });
  });
}
