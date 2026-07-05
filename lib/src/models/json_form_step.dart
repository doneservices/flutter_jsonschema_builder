import '../models/models.dart';

/// One schema rendered on a step, together with the [SchemaObject] that owns
/// it (needed to resolve dependencies while the step is displayed).
class JsonFormStepEntry {
  JsonFormStepEntry({required this.schema, required this.parent});

  final Schema schema;
  final SchemaObject parent;
}

/// A single screen of the stepped display mode.
class JsonFormStep {
  JsonFormStep({
    required this.id,
    this.title,
    this.description,
    this.media,
    required this.entries,
  });

  /// the schema's idKey; stable across re-extractions, used to keep the
  /// current position when dependencies mutate the schema tree
  final String id;

  final String? title;
  final String? description;
  final JsonFormMedia? media;
  final List<JsonFormStepEntry> entries;
}

/// Maps a plain JSON schema to a list of steps — no ui schema required:
///
/// * every scalar property and every array is its own step
/// * a nested object becomes a single step holding all its fields, titled
///   by the object's own `title`/`description` (the same ones classic mode
///   renders as a section header)
/// * `ui:media` on a field or object attaches media to its step
List<JsonFormStep> extractJsonFormSteps(SchemaObject root) {
  final steps = <JsonFormStep>[];

  for (final child in root.properties ?? const <Schema>[]) {
    if (child is SchemaObject) {
      final entries = (child.properties ?? const <Schema>[])
          .map((schema) => JsonFormStepEntry(schema: schema, parent: child))
          .toList();
      if (entries.isEmpty) continue;

      steps.add(JsonFormStep(
        id: child.idKey,
        title: child.title != kNoTitle ? child.title : null,
        description: child.description,
        media: child.uiMedia,
        entries: entries,
      ));
    } else {
      steps.add(JsonFormStep(
        id: child.idKey,
        media: child.uiMedia,
        entries: [JsonFormStepEntry(schema: child, parent: root)],
      ));
    }
  }

  return steps;
}

/// Resolves the value stored in the form [data] map for a (possibly nested)
/// [Schema.idKey] path like `address.street`.
dynamic jsonFormDataAtPath(dynamic data, String idKey) {
  dynamic value = data;
  for (final part in idKey.split('.')) {
    if (value is! Map) return null;
    value = value[part];
  }
  return value;
}
