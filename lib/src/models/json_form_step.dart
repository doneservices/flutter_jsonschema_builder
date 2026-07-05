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

  /// the schema's idKey, or the `ui:step` group name for grouped steps.
  /// Stable across re-extractions, used to keep the current position when
  /// dependencies mutate the schema tree.
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
/// * optionally, flat sibling fields sharing a `ui:step` group name are
///   combined onto one step (placed where the group first occurs) — for
///   grouping without changing the shape of the produced data
List<JsonFormStep> extractJsonFormSteps(SchemaObject root) {
  final steps = <JsonFormStep>[];
  final stepIndexByGroup = <String, int>{};

  void addToGroup(Schema schema, SchemaObject parent, String group) {
    final entry = JsonFormStepEntry(schema: schema, parent: parent);
    final existingIndex = stepIndexByGroup[group];

    if (existingIndex != null) {
      final existing = steps[existingIndex];
      existing.entries.add(entry);
      if (existing.media == null && schema.uiMedia != null) {
        steps[existingIndex] = JsonFormStep(
          id: existing.id,
          media: schema.uiMedia,
          entries: existing.entries,
        );
      }
      return;
    }

    stepIndexByGroup[group] = steps.length;
    steps.add(JsonFormStep(
      // prefixed so a group name can never collide with a field's idKey
      id: 'step-group:$group',
      media: schema.uiMedia,
      entries: [entry],
    ));
  }

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
    } else if (child.uiStep != null) {
      addToGroup(child, root, child.uiStep!);
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
    if (value is Map) {
      value = value[part];
    } else if (value is List) {
      final index = int.tryParse(part);
      value = index != null && index >= 0 && index < value.length
          ? value[index]
          : null;
    } else {
      return null;
    }
  }
  return value;
}
