import 'package:flutter_jsonschema_builder/src/helpers/is_url.dart';
import 'package:flutter_jsonschema_builder/src/models/property_schema.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? inputValidationJsonSchema({
  required String newValue,
  required SchemaProperty property,
}) {
  if (newValue.isEmpty) {
    return property.required ? 'Required' : null;
  }

  if ((newValue.length <= (property.minLength?.toInt() ?? 0)) &&
      property.minLength != null) {
    return 'should NOT be shorter than ${property.minLength} characters';
  }

  if ((property.format == PropertyFormat.uri)) {
    if (!(isURL(newValue))) {
      return 'you should enter a uri';
    }
  }

  if (property.format == PropertyFormat.email &&
      !_emailPattern.hasMatch(newValue)) {
    return 'Enter a valid email address';
  }

  return null;
}
