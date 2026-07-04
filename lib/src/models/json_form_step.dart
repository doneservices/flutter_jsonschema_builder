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

  /// the `ui:step` group name, or the schema's idKey for ungrouped steps.
  /// Stable across re-extractions, used to keep the current position when
  /// dependencies mutate the schema tree.
  final String id;

  final String? title;
  final String? description;
  final JsonFormMedia? media;
  final List<JsonFormStepEntry> entries;
}

/// Walks the schema tree and maps it to a list of steps:
///
/// * every leaf property and every array is its own step by default
/// * schemas sharing a `ui:step` group name are combined into one step,
///   placed where the group first occurs
/// * nested objects are flattened into the sequence, unless the object
///   itself declares `ui:step`, which keeps it together on a single step
/// * step title/description/media for groups come from the root `ui:steps`
///   block, falling back to the first `ui:media` found among the entries
List<JsonFormStep> extractJsonFormSteps(SchemaObject root) {
  final steps = <JsonFormStep>[];
  final stepIndexByGroup = <String, int>{};
  final uiSteps = root.uiSteps ?? const <String, dynamic>{};

  void add(Schema schema, SchemaObject parent) {
    final entry = JsonFormStepEntry(schema: schema, parent: parent);
    final group = schema.uiStep;

    final existingIndex = group != null ? stepIndexByGroup[group] : null;
    if (existingIndex != null) {
      final existing = steps[existingIndex];
      existing.entries.add(entry);
      if (existing.media == null && schema.uiMedia != null) {
        steps[existingIndex] = JsonFormStep(
          id: existing.id,
          title: existing.title,
          description: existing.description,
          media: schema.uiMedia,
          entries: existing.entries,
        );
      }
      return;
    }

    final groupConfig =
        group != null && uiSteps[group] is Map ? uiSteps[group] as Map : null;
    final groupMedia = groupConfig?['media'] is Map
        ? JsonFormMedia.fromJson(
            Map<String, dynamic>.from(groupConfig!['media']))
        : null;

    if (group != null) stepIndexByGroup[group] = steps.length;
    steps.add(JsonFormStep(
      // prefixed so a group name can never collide with a field's idKey
      id: group != null ? 'step-group:$group' : schema.idKey,
      title: groupConfig?['title'] as String?,
      description: groupConfig?['description'] as String?,
      media: groupMedia ?? schema.uiMedia,
      entries: [entry],
    ));
  }

  void walk(SchemaObject object) {
    for (final child in object.properties ?? const <Schema>[]) {
      if (child is SchemaObject && child.uiStep == null) {
        walk(child);
      } else {
        add(child, object);
      }
    }
  }

  walk(root);
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
