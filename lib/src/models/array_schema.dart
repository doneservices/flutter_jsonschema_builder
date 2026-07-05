import '../models/models.dart';

// extension SchemaArrayX on SchemaArray {
//   bool get isMultipleFile {
//     return items.isNotEmpty &&
//         items.first is SchemaProperty &&
//         (items.first as SchemaProperty).format == PropertyFormat.dataurl;
//   }
// }

class SchemaArray extends Schema {
  SchemaArray({
    required String id,
    required this.itemsBaseSchema,
    String? title,
    String? description,
    this.defaultValue,
    this.minItems,
    this.maxItems,
    this.uniqueItems = true,
    this.items = const [],
    this.required = false,
  }) : super(
          id: id,
          title: title ?? 'no-title',
          description: description,
          type: SchemaType.array,
        );

  factory SchemaArray.fromJson(
    String id,
    Map<String, dynamic> json, {
    Schema? parent,
    Map<String, dynamic>? initialData,
  }) {
    final schemaArray = SchemaArray(
      id: id,
      title: json['title'],
      description: json['description'],
      defaultValue: initialData?[id] ?? json['default'],
      minItems: json['minItems'],
      maxItems: json['maxItems'],
      uniqueItems: json['uniqueItems'] ?? true,
      itemsBaseSchema: json['items'],
    );

    schemaArray.parentIdKey = parent?.idKey;
    schemaArray.dependentsAddedBy.addAll(parent?.dependentsAddedBy ?? []);

    return schemaArray;
  }
  @override
  SchemaArray copyWith({
    required String id,
    String? parentIdKey,
    List<String>? dependentsAddedBy,
  }) {
    var newSchema = SchemaArray(
      id: id,
      title: title,
      description: description,
      maxItems: maxItems,
      minItems: minItems,
      uniqueItems: uniqueItems,
      itemsBaseSchema: itemsBaseSchema,
      defaultValue: defaultValue,
      required: required,
    )
      ..parentIdKey = parentIdKey ?? this.parentIdKey
      ..dependentsAddedBy = dependentsAddedBy ?? this.dependentsAddedBy
      ..uiMedia = uiMedia;

    newSchema.items = items
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

  void setUi(Map<String, dynamic> uiSchema) {
    uiSchema.forEach((key, data) {
      switch (key) {
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

  /// can be array of [Schema] or [Schema]
  List<Schema> items;

  // it allow us
  dynamic itemsBaseSchema;
  dynamic defaultValue;

  int? minItems;
  int? maxItems;
  bool uniqueItems;

  bool required;

  bool isArrayMultipleFile() {
    return (itemsBaseSchema is Map &&
        itemsBaseSchema.containsKey('format') &&
        itemsBaseSchema['format'] == 'data-url');
  }

  SchemaProperty toSchemaPropertyMultipleFiles() {
    return SchemaProperty(
      id: id,
      title: title,
      type: SchemaType.string,
      format: PropertyFormat.dataurl,
      required: required,
      description: description,
      defaultValue: defaultValue,
    )
      ..parentIdKey = parentIdKey
      ..dependentsAddedBy = dependentsAddedBy
      ..isMultipleFile = true;
  }
}
