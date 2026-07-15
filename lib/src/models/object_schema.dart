import '../models/models.dart';
import 'conditional_schema.dart';

class SchemaObject extends Schema {
  SchemaObject({
    required super.id,
    this.required = const [],
    this.dependencies,
    String? title,
    super.description,
  }) : super(title: title ?? 'no-title', type: SchemaType.object);

  factory SchemaObject.fromJson(
    String id,
    Map<String, dynamic> json, {
    Schema? parent,
    Map<String, dynamic>? initialData,
  }) {
    final schema = SchemaObject(
      id: id,
      title: json['title'],
      description: json['description'],
      required: json["required"] != null
          ? List<String>.from(json["required"].map((x) => x))
          : [],
      dependencies: json['dependencies'],
    );
    schema._conditionalRules = _readConditionalRules(json);
    schema._basePropertySchemas = {
      for (final entry in (json['properties'] as Map? ?? const {}).entries)
        if (entry.value is Map)
          entry.key.toString(): Map<String, dynamic>.from(entry.value),
    };
    schema.parentIdKey = parent?.idKey;

    schema.dependentsAddedBy.addAll(parent?.dependentsAddedBy ?? []);

    if (json['properties'] != null) {
      schema.setProperties(json['properties'], schema, initialData);
    }
    if (json['oneOf'] != null) {
      schema.setOneOf(json['oneOf'], schema, initialData);
    }

    return schema;
  }

  void setUi(Map<String, dynamic> uiSchema) {
    uiSchema.forEach((key, data) {
      switch (key) {
        case "ui:order":
          order = List<String>.from(data);
          break;
        case "ui:title":
          title = data as String;
          break;
        case "ui:description":
          description = data as String;
          break;
        case "ui:media":
          if (data is Map) {
            uiMedia = JsonFormMedia.fromJson(Map<String, dynamic>.from(data));
          }
          break;
        default:
          break;
      }
    });
  }

  @override
  Schema copyWith({
    required String id,
    String? parentIdKey,
    List<String>? dependentsAddedBy,
  }) {
    var newSchema = SchemaObject(id: id, title: title, description: description)
      ..parentIdKey = parentIdKey ?? this.parentIdKey
      ..dependentsAddedBy = dependentsAddedBy ?? this.dependentsAddedBy
      ..type = type
      ..dependencies = dependencies
      ..oneOf = oneOf
      ..order = order
      ..required = required
      ..uiMedia = uiMedia;

    final otherProperties = properties!; //.map((p) => p.copyWith(id: p.id));

    newSchema.properties = otherProperties
        .map(
          (e) => e.copyWith(
            id: e.id,
            parentIdKey: newSchema.idKey,
            dependentsAddedBy: newSchema.dependentsAddedBy,
          ),
        )
        .toList();

    return newSchema;
  }

  // ! Getters
  bool get isGenesis => id == kGenesisIdKey;

  bool isOneOf = false;

  /// array of required keys
  List<String> required;
  List<Schema>? properties;
  List<String>? order;

  /// the dependencies keyword from an earlier draft of JSON Schema
  /// (note that this is not part of the latest JSON Schema spec, though).
  /// Dependencies can be used to create dynamic schemas that change fields based on what data is entered
  Map<String, dynamic>? dependencies;

  /// A [Schema] with [oneOf] is valid if exactly one of the subschemas is valid.
  List<Schema>? oneOf;

  List<Map<String, dynamic>> _conditionalRules = const [];
  List<int> _activeConditionalBranches = const [];
  List<Schema> _conditionalProperties = const [];
  Map<String, Map<String, dynamic>> _basePropertySchemas = const {};
  Map<String, Schema> _conditionalOverrides = const {};
  Map<String, dynamic>? _uiSchema;

  void setUiSchema(Map<String, dynamic>? uiSchema) {
    if (uiSchema == null) return;
    _uiSchema = uiSchema;
    if (properties != null && properties!.isEmpty) return;

    // set UI Schema to this ObjectSchema
    setUi(uiSchema);

    // set UI Schema to their properties; objects and arrays only receive
    // their own nested map — passing the parent's map would copy its
    // object-level keys (ui:title, ui:order, ...) onto them
    properties?.forEach((property) {
      final nestedUiSchema = uiSchema[property.id];

      if (property is SchemaObject) {
        if (nestedUiSchema is Map<String, dynamic>) {
          property.setUiSchema(nestedUiSchema);
        }
      } else if (property is SchemaProperty) {
        property.setUi(uiSchema);
      } else if (property is SchemaArray &&
          nestedUiSchema is Map<String, dynamic>) {
        property.setUi(nestedUiSchema);
      }
    });

    // order logic; ids missing from ui:order keep schema order, after the
    // listed ones. List.sort is not guaranteed stable, so tie-break on the
    // original position
    if (order != null) {
      int orderIndex(Schema schema) {
        final index = order!.indexOf(schema.id);
        return index == -1 ? order!.length : index;
      }

      final indexed = properties!.asMap().entries.toList()
        ..sort((a, b) {
          final byOrder = orderIndex(a.value) - orderIndex(b.value);
          return byOrder != 0 ? byOrder : a.key - b.key;
        });
      properties = [for (final entry in indexed) entry.value];
    }
  }

  /// Resolves JSON Schema `if`/`then`/`else` annotations against [data].
  /// RJSF commonly places these rules in `allOf`, which is supported too.
  bool resolveConditions(dynamic data) {
    var changed = false;
    if (_conditionalRules.isNotEmpty) {
      final activeBranches = [
        for (final rule in _conditionalRules)
          jsonSchemaMatches(rule['if'], data)
              ? (rule['then'] is Map ? 1 : 0)
              : (rule['else'] is Map ? -1 : 0),
      ];

      if (!_sameBranches(activeBranches, _activeConditionalBranches)) {
        changed = true;
        _activeConditionalBranches = activeBranches;
        for (final entry in _conditionalOverrides.entries) {
          final index = properties?.indexWhere(
            (property) => property.id == entry.key,
          );
          if (index != null && index >= 0) properties![index] = entry.value;
        }
        _conditionalOverrides = {};
        properties?.removeWhere(_conditionalProperties.contains);
        _conditionalProperties = [];

        final conditionalRequired = <String>{};
        final conditionalSchemas = <String, Map<String, dynamic>>{};

        for (var i = 0; i < _conditionalRules.length; i++) {
          final branchName = activeBranches[i] == 1
              ? 'then'
              : activeBranches[i] == -1
              ? 'else'
              : null;
          if (branchName == null) continue;

          final branch = _conditionalRules[i][branchName];
          if (branch is! Map) continue;
          final branchJson = Map<String, dynamic>.from(branch);
          conditionalRequired.addAll(
            (branchJson['required'] as List?)?.map((id) => id.toString()) ??
                const <String>[],
          );

          final branchProperties = branchJson['properties'];
          if (branchProperties is! Map) continue;
          for (final entry in branchProperties.entries) {
            if (entry.value is! Map) continue;
            final id = entry.key.toString();
            final propertyJson = Map<String, dynamic>.from(entry.value);
            conditionalSchemas[id] = conditionalSchemas.containsKey(id)
                ? _mergeJsonSchemas(conditionalSchemas[id]!, propertyJson)
                : propertyJson;
          }
        }

        properties ??= <Schema>[];
        final initialData = data is Map
            ? Map<String, dynamic>.from(data)
            : null;
        for (final entry in conditionalSchemas.entries) {
          final index = properties!.indexWhere(
            (property) => property.id == entry.key,
          );
          final baseJson = _basePropertySchemas[entry.key];
          final property = Schema.fromJson(
            baseJson == null
                ? entry.value
                : _mergeJsonSchemas(baseJson, entry.value),
            id: entry.key,
            parent: this,
            initialData: initialData,
          );
          if (property is SchemaProperty) property.setDependents(this);

          if (index >= 0 && baseJson != null) {
            final original = properties![index];
            if (property is SchemaProperty && original is SchemaProperty) {
              property.isDependentsActive = original.isDependentsActive;
            } else if (property is SchemaArray && original is SchemaArray) {
              property.items = original.items;
            }
            _conditionalOverrides[entry.key] = original;
            properties![index] = property;
          } else if (index < 0) {
            _conditionalProperties.add(property);
          }
        }
        properties!.addAll(_conditionalProperties);
        if (_uiSchema != null) setUiSchema(_uiSchema);
        final dependencyRequired = <String>{
          for (final property
              in properties?.whereType<SchemaProperty>() ??
                  const <SchemaProperty>[])
            if (property.isDependentsActive && property.dependents is List)
              ...(property.dependents as List).map((id) => id.toString()),
        };
        for (final property in properties ?? const <Schema>[]) {
          final isRequired =
              required.contains(property.id) ||
              conditionalRequired.contains(property.id) ||
              dependencyRequired.contains(property.id);
          if (property is SchemaProperty) {
            property.required = isRequired;
          } else if (property is SchemaArray) {
            property.required = isRequired;
          }
        }
      }
    }

    for (final child
        in properties?.whereType<SchemaObject>() ?? const <SchemaObject>[]) {
      final childData = data is Map ? data[child.id] : null;
      changed = child.resolveConditions(childData) || changed;
    }
    return changed;
  }

  void setProperties(
    dynamic properties,
    SchemaObject schema,
    Map<String, dynamic>? initialData,
  ) {
    if (properties == null) return;
    var props = <Schema>[];

    properties.forEach((key, propertyJson) {
      final isRequired = schema.required.contains(key);

      final property = Schema.fromJson(
        propertyJson,
        id: key,
        parent: schema,
        initialData: initialData,
      );

      if (property is SchemaProperty) {
        property.required = isRequired;
        // Asignamos las propiedades que dependen de este
        property.setDependents(schema);
      } else if (property is SchemaArray) {
        property.required = isRequired;
      }

      props.add(property);
    });

    this.properties = props;
  }

  void setOneOf(
    List<dynamic>? oneOf,
    SchemaObject schema,
    Map<String, dynamic>? initialData,
  ) {
    if (oneOf == null) return;
    oneOf.map((e) => Map<String, dynamic>.from(e));
    var oneOfs = <Schema>[];
    for (var element in oneOf) {
      print(element);
      oneOfs.add(
        Schema.fromJson(element, parent: schema, initialData: initialData),
      );
    }

    this.oneOf = oneOfs;
  }
}

List<Map<String, dynamic>> _readConditionalRules(Map<String, dynamic> json) {
  final rules = <Map<String, dynamic>>[];
  if (json['if'] is Map) rules.add(Map<String, dynamic>.from(json));

  final allOf = json['allOf'];
  if (allOf is List) {
    for (final item in allOf) {
      if (item is Map && item['if'] is Map) {
        rules.add(Map<String, dynamic>.from(item));
      }
    }
  }
  return rules;
}

bool _sameBranches(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

Map<String, dynamic> _mergeJsonSchemas(
  Map<String, dynamic> base,
  Map<String, dynamic> overlay,
) {
  final merged = Map<String, dynamic>.from(base);
  for (final entry in overlay.entries) {
    final current = merged[entry.key];
    if (entry.key == 'required' && current is List && entry.value is List) {
      merged[entry.key] = {...current, ...entry.value as List}.toList();
    } else if (current is Map && entry.value is Map) {
      merged[entry.key] = _mergeJsonSchemas(
        Map<String, dynamic>.from(current),
        Map<String, dynamic>.from(entry.value),
      );
    } else {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}
