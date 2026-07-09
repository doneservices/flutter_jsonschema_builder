import 'package:flutter/services.dart';

class EmailTextInputJsonFormatter extends TextInputFormatter {
  static const String _atomCharacters = "!#\$%&'*+-/=?^_`{|}~";

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Pure deletions (no characters inserted) always pass through so the user
    // can edit freely, e.g. delete a leading character to expose a special one.
    // Selection-replace and paste edits, even when they shrink the text, still
    // run through validation below.
    if (_isPureDeletion(oldValue.text, newValue.text)) {
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

  /// Whether [newText] is [oldText] with a contiguous range removed and nothing
  /// inserted — i.e. it shares a common prefix and suffix with [oldText].
  static bool _isPureDeletion(String oldText, String newText) {
    if (newText.length >= oldText.length) {
      return false;
    }
    var prefix = 0;
    while (prefix < newText.length && newText[prefix] == oldText[prefix]) {
      prefix++;
    }
    final suffix = newText.length - prefix;
    return newText.substring(prefix) ==
        oldText.substring(oldText.length - suffix);
  }
}
