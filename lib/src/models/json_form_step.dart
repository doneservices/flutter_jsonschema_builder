import '../models/models.dart';

/// A single screen of the stepped display mode.
class JsonFormStep {
  JsonFormStep({
    required this.id,
    required this.parent,
    required this.schemas,
    this.title,
    this.description,
    this.media,
  });

  /// unique per extraction; stable across re-extractions, used to keep the
  /// current position when dependencies mutate the schema tree
  final String id;

  /// the [SchemaObject] owning every schema on this step (needed to resolve
  /// dependencies while the step is displayed)
  final SchemaObject parent;

  final List<Schema> schemas;

  final String? title;
  final String? description;

  /// mutable: a later `ui:group` member can contribute the group's media
  JsonFormMedia? media;
}

/// Maps a plain JSON schema to a list of steps — no ui schema required:
///
/// * every scalar property and every array is its own step
/// * a nested object becomes a single step holding all its fields, titled
///   by the object's own `title`/`description` (the same ones classic mode
///   renders as a section header)
/// * fields sharing a `ui:group` value share one step (at the position of
///   the group's first field), keeping the data shape flat
/// * `ui:media` on a field or object attaches media to its step; for a
///   group, the first member carrying media wins
List<JsonFormStep> extractJsonFormSteps(SchemaObject root) {
  final steps = <JsonFormStep>[];
  final usedIds = <String, int>{};
  final groupSteps = <String, JsonFormStep>{};

  // dependency-added schemas can share an idKey (or lack one entirely);
  // suffix repeats so page keys and per-step form keys stay unique
  String uniqueId(String base) {
    final seen = usedIds[base] ?? 0;
    usedIds[base] = seen + 1;
    return seen == 0 ? base : '$base@$seen';
  }

  for (final child in root.properties ?? const <Schema>[]) {
    if (child is SchemaObject) {
      final schemas = child.properties ?? const <Schema>[];
      if (schemas.isEmpty) continue;

      steps.add(JsonFormStep(
        id: uniqueId(child.idKey),
        parent: child,
        schemas: List.of(schemas),
        title: child.title != kNoTitle ? child.title : null,
        description: child.description,
        media: child.uiMedia,
      ));
    } else {
      final group = child.uiGroup;
      final existing = group != null ? groupSteps[group] : null;
      if (existing != null) {
        existing.schemas.add(child);
        existing.media ??= child.uiMedia;
        continue;
      }

      final step = JsonFormStep(
        id: uniqueId(group != null ? 'group:$group' : child.idKey),
        parent: root,
        schemas: [child],
        media: child.uiMedia,
      );
      if (group != null) groupSteps[group] = step;
      steps.add(step);
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
