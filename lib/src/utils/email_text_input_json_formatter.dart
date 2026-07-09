import 'package:flutter/services.dart';

class EmailTextInputJsonFormatter extends TextInputFormatter {
  static const String _atomCharacters = "!#\$%&'*+-/=?^_`{|}~";

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    if (newValue.text.length >= 255) {
      return oldValue;
    }

    if (newValue.text.isNotEmpty &&
        _atomCharacters.contains(newValue.text[0])) {
      return oldValue;
    }

    if ('@'.allMatches(newValue.text).length > 1) {
      return oldValue;
    }

    return newValue;
  }
}
