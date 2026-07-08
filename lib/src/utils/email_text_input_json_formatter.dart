import 'package:flutter/services.dart';

class EmailTextInputJsonFormatter extends TextInputFormatter {
  static const String _atomCharacters = "!#\$%&'*+-/=?^_`{|}~";

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text.length >= newValue.text.length) {
      return newValue;
    }

    if (newValue.text.length >= 255) {
      return oldValue;
    }

    if (_atomCharacters.contains(newValue.text)) {
      return oldValue;
    }

    if ('@'.allMatches(newValue.text).length > 1) {
      return oldValue;
    }

    return newValue;
  }
}
