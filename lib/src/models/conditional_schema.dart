bool jsonSchemaMatches(dynamic schema, dynamic data) {
  if (schema is bool) return schema;
  if (schema is! Map) return true;

  // Number fields currently store their text input in formData. Coerce only
  // when the condition itself is numeric, preserving ordinary string rules.
  if (data is String && _usesNumericComparison(schema)) {
    final values = schema['enum'];
    final hasExactMatch =
        (schema.containsKey('const') && _jsonEquals(data, schema['const'])) ||
        (values is List && values.any((value) => _jsonEquals(data, value)));
    if (!hasExactMatch) {
      data = num.tryParse(data.replaceAll(',', '.')) ?? data;
    }
  }

  if (schema.containsKey('const') && !_jsonEquals(data, schema['const'])) {
    return false;
  }

  final values = schema['enum'];
  if (values is List && !values.any((value) => _jsonEquals(data, value))) {
    return false;
  }

  final type = schema['type'];
  if (type != null && !_matchesType(type, data)) return false;

  final required = schema['required'];
  if (required is List &&
      (data is! Map || required.any((key) => !data.containsKey(key)))) {
    return false;
  }

  final properties = schema['properties'];
  if (properties is Map && data is Map) {
    for (final entry in properties.entries) {
      if (data.containsKey(entry.key) &&
          !jsonSchemaMatches(entry.value, data[entry.key])) {
        return false;
      }
    }
  }

  final allOf = schema['allOf'];
  if (allOf is List && !allOf.every((item) => jsonSchemaMatches(item, data))) {
    return false;
  }

  final anyOf = schema['anyOf'];
  if (anyOf is List && !anyOf.any((item) => jsonSchemaMatches(item, data))) {
    return false;
  }

  final oneOf = schema['oneOf'];
  if (oneOf is List &&
      oneOf.where((item) => jsonSchemaMatches(item, data)).length != 1) {
    return false;
  }

  if (schema['not'] != null && jsonSchemaMatches(schema['not'], data)) {
    return false;
  }

  if (data is String) {
    final minLength = schema['minLength'];
    final maxLength = schema['maxLength'];
    if (minLength is num && data.length < minLength) return false;
    if (maxLength is num && data.length > maxLength) return false;
    if (schema['pattern'] case final String pattern) {
      try {
        if (!RegExp(pattern).hasMatch(data)) return false;
      } on FormatException {
        return false;
      }
    }
  }

  if (data is num) {
    final minimum = schema['minimum'];
    final maximum = schema['maximum'];
    final exclusiveMinimum = schema['exclusiveMinimum'];
    final exclusiveMaximum = schema['exclusiveMaximum'];
    if (minimum is num && data < minimum) return false;
    if (maximum is num && data > maximum) return false;
    if (exclusiveMinimum is num && data <= exclusiveMinimum) return false;
    if (exclusiveMaximum is num && data >= exclusiveMaximum) return false;
  }

  return true;
}

bool _usesNumericComparison(Map schema) {
  final type = schema['type'];
  if (type == 'number' ||
      type == 'integer' ||
      (type is List &&
          type.any((item) => item == 'number' || item == 'integer'))) {
    return true;
  }
  if (schema['const'] is num) return true;
  if (schema['enum'] is List && (schema['enum'] as List).any((v) => v is num)) {
    return true;
  }
  return const [
    'minimum',
    'maximum',
    'exclusiveMinimum',
    'exclusiveMaximum',
  ].any(schema.containsKey);
}

bool _matchesType(dynamic type, dynamic data) {
  if (type is List) return type.any((item) => _matchesType(item, data));

  return switch (type) {
    'null' => data == null,
    'boolean' => data is bool,
    'object' => data is Map,
    'array' => data is List,
    'number' => data is num,
    'integer' =>
      data is int || (data is double && data == data.roundToDouble()),
    'string' => data is String,
    _ => true,
  };
}

bool _jsonEquals(dynamic left, dynamic right) {
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_jsonEquals(left[i], right[i])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.entries.every(
          (entry) =>
              right.containsKey(entry.key) &&
              _jsonEquals(entry.value, right[entry.key]),
        );
  }
  return left == right;
}
