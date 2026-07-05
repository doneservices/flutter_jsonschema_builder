// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/builder/array_schema_builder.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart';
import 'package:flutter_jsonschema_builder/src/builder/object_schema_builder.dart';
import 'package:flutter_jsonschema_builder/src/builder/property_schema_builder.dart';
import 'package:flutter_jsonschema_builder/src/builder/stepped_form_builder.dart';
import 'package:flutter_jsonschema_builder/src/models/json_form_schema_style.dart';
import 'package:flutter_jsonschema_builder/src/models/stepped_form_config.dart';

import '../models/models.dart';

/// How [JsonForm] lays out the schema.
enum JsonFormDisplayMode {
  /// all fields on a single scrolling page with a submit button at the end
  fullForm,

  /// one step at a time with progress, back/next navigation and optional
  /// `ui:media` per step; see [JsonFormSteppedConfig]
  stepped,
}

typedef FileHandler = Map<String,
        Future<List<SchemaFormFile>?> Function(SchemaProperty property)?>
    Function();
typedef InitialFileValueHandler
    = Map<String, Future<List<SchemaFormFile>?> Function(dynamic defaultValue)?>
        Function();
typedef CustomPickerHandler
    = Map<String, Future<dynamic> Function(SchemaProperty data)> Function();

typedef CustomValidatorHandler = Map<String, String? Function(dynamic)?>
    Function();

class JsonForm extends StatefulWidget {
  const JsonForm({
    super.key,
    required this.jsonSchema,
    required this.onFormDataSaved,
    this.showDebugElements = true,
    this.uiSchema,
    this.fileHandler,
    this.initialFileValueHandler,
    this.jsonFormSchemaUiConfig,
    this.customPickerHandler,
    this.customValidatorHandler,
    this.onChanged,
    this.initialData,
    this.padding = const EdgeInsets.all(16),
    this.inputDecoration,
    this.displayMode = JsonFormDisplayMode.fullForm,
    this.steppedConfig = const JsonFormSteppedConfig(),
  });

  final String jsonSchema;
  final void Function(dynamic) onFormDataSaved;

  final String? uiSchema;
  final FileHandler? fileHandler;

  /// This handler is for getting the correct initial value for each file, as file is just represented as string sometimes,
  /// so we would need this handler to turn value into actual representable file field value
  final InitialFileValueHandler? initialFileValueHandler;

  final JsonFormSchemaUiConfig? jsonFormSchemaUiConfig;

  final CustomPickerHandler? customPickerHandler;

  final CustomValidatorHandler? customValidatorHandler;

  final ValueChanged<dynamic>? onChanged;

  final Map<String, dynamic>? initialData;

  final EdgeInsets padding;

  /// Whether to show debug elements like debug labels for each field and inspect button
  ///
  /// defaults to `true`,
  /// Debug labels only show when the app is built for debugging
  final bool showDebugElements;

  final InputDecoration? inputDecoration;

  /// [JsonFormDisplayMode.fullForm] renders every field on one page,
  /// [JsonFormDisplayMode.stepped] walks through the form one step at a time.
  ///
  /// Note: the stepped mode expands to fill its parent and needs a bounded
  /// height; don't place it inside an unconstrained scroll view.
  final JsonFormDisplayMode displayMode;

  /// customization of the stepped display mode; only used when [displayMode]
  /// is [JsonFormDisplayMode.stepped]
  final JsonFormSteppedConfig steppedConfig;

  @override
  _JsonFormState createState() => _JsonFormState();
}

class _JsonFormState extends State<JsonForm> {
  late SchemaObject mainSchema;

  final _formKey = GlobalKey<FormState>();

  /// owned by the state so entered data survives rebuilds of this widget —
  /// WidgetBuilderInherited is recreated on every build and must keep
  /// receiving the same map instance
  late final Map<String, dynamic> _formData;

  _JsonFormState();

  @override
  void initState() {
    _formData = widget.initialData ?? {};
    mainSchema = (Schema.fromJson(json.decode(widget.jsonSchema),
        id: kGenesisIdKey, initialData: widget.initialData) as SchemaObject)
      ..setUiSchema(
          widget.uiSchema != null ? json.decode(widget.uiSchema!) : null);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetBuilderInherited(
      mainSchema: mainSchema,
      fileHandler: widget.fileHandler,
      initialFileValueHandler: widget.initialFileValueHandler,
      customPickerHandler: widget.customPickerHandler,
      customValidatorHandler: widget.customValidatorHandler,
      onChanged: widget.onChanged,
      initialData: _formData,
      inputDecoration: widget.inputDecoration,
      child: Builder(builder: (context) {
        final widgetBuilderInherited = WidgetBuilderInherited.of(context);

        if (widget.displayMode == JsonFormDisplayMode.stepped) {
          return SteppedFormBuilder(
            mainSchema: mainSchema,
            config: widget.steppedConfig,
            showDebugElements: widget.showDebugElements,
            padding: widget.padding,
            onSubmit: () =>
                widget.onFormDataSaved(widgetBuilderInherited.data),
          );
        }

        return Form(
          key: _formKey,
          child: Container(
            padding: widget.padding,
            child: Column(
              children: <Widget>[
                if (!kReleaseMode && widget.showDebugElements)
                  TextButton(
                    onPressed: () {
                      inspect(mainSchema);
                    },
                    child: const Text('INSPECT'),
                  ),
                _buildHeaderTitle(context),
                FormFromSchemaBuilder(
                  mainSchema: mainSchema,
                  schema: mainSchema,
                  showDebugElements: widget.showDebugElements,
                ),
                const SizedBox(height: 20),
                widgetBuilderInherited.uiConfig.submitButtonBuilder == null
                    ? ElevatedButton(
                        onPressed: () => onSubmit(widgetBuilderInherited),
                        child: const Text('Submit'),
                      )
                    : widgetBuilderInherited.uiConfig.submitButtonBuilder!(
                        () => onSubmit(widgetBuilderInherited)),
              ],
            ),
          ),
        );
      }),
    )..setJsonFormSchemaStyle(context, widget.jsonFormSchemaUiConfig);
  }

  Widget _buildHeaderTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: Text(
            mainSchema.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: WidgetBuilderInherited.of(context).uiConfig.titleAlign,
          ),
        ),
        const Divider(),
        if (mainSchema.description != null)
          SizedBox(
            width: double.infinity,
            child: Text(
              mainSchema.description!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: WidgetBuilderInherited.of(context).uiConfig.titleAlign,
            ),
          ),
      ],
    );
  }

  //  Form methods
  bool onSubmit(WidgetBuilderInherited widgetBuilderInherited) {
    final isValid =
        _formKey.currentState != null && _formKey.currentState!.validate();
    if (isValid) {
      _formKey.currentState?.save();

      widget.onFormDataSaved(widgetBuilderInherited.data);
    }

    return isValid;
  }
}

class FormFromSchemaBuilder extends StatelessWidget {
  const FormFromSchemaBuilder({
    Key? key,
    required this.mainSchema,
    required this.schema,
    this.showDebugElements = true,
    this.schemaObject,
  }) : super(key: key);
  final Schema mainSchema;
  final Schema schema;
  final bool showDebugElements;
  final SchemaObject? schemaObject;

  @override
  Widget build(BuildContext context) {
    if (schema is SchemaProperty) {
      return PropertySchemaBuilder(
        mainSchema: mainSchema,
        schemaProperty: schema as SchemaProperty,
        showDebugElements: showDebugElements,
      );
    }
    if (schema is SchemaArray) {
      return ArraySchemaBuilder(
        mainSchema: mainSchema,
        schemaArray: schema as SchemaArray,
        showDebugElements: showDebugElements,
      );
    }

    if (schema is SchemaObject) {
      return ObjectSchemaBuilder(
        mainSchema: mainSchema,
        schemaObject: schema as SchemaObject,
        showDebugElements: showDebugElements,
      );
    }

    return const SizedBox.shrink();
  }
}
