import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_jsonschema_builder/src/builder/field_header_widget.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart';
import 'package:flutter_jsonschema_builder/src/fields/fields.dart';
import 'package:flutter_jsonschema_builder/src/models/models.dart';

import './shared.dart';

class FileJFormField extends PropertyFieldWidget<dynamic> {
  const FileJFormField({
    super.key,
    required super.property,
    required super.onSaved,
    super.onChanged,
    required this.fileHandler,
    this.initialFileValueHandler,
    super.customValidator,
    super.decoration,
  });

  final Future<List<SchemaFormFile>?> Function(SchemaProperty property)
      fileHandler;
  final Future<List<SchemaFormFile>?> Function(dynamic initialValue)?
      initialFileValueHandler;

  @override
  _FileJFormFieldState createState() => _FileJFormFieldState();
}

class _FileJFormFieldState extends State<FileJFormField> {
  bool hasTriggeredInitialValue = false;
  final GlobalKey<FormFieldState<List<SchemaFormFile>>> _fieldKey =
      GlobalKey<FormFieldState<List<SchemaFormFile>>>();

  @override
  void initState() {
    widget.triggetDefaultValue();
    _triggerInitialValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final widgetBuilderInherited = WidgetBuilderInherited.of(context);

    return FormField<List<SchemaFormFile>>(
      key: _fieldKey,
      validator: (value) {
        if ((value == null || value.isEmpty) && widget.property.required) {
          return widgetBuilderInherited.uiConfig.requiredText ?? 'Required';
        }

        if (widget.customValidator != null)
          return widget.customValidator!(value);
        return null;
      },
      onSaved: (newValue) {
        if (newValue != null) {
          final response = widget.property.isMultipleFile
              ? newValue.map((f) => f.value).toList()
              : (newValue.first.value);

          widget.onSaved(response);
        }
      },
      builder: (field) {
        final filesBuilder = widgetBuilderInherited.uiConfig.filesBuilder;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldHeader(property: widget.property),
            const SizedBox(height: 10),
            if (filesBuilder != null)
              filesBuilder(
                field.value,
                onRemove: (name) => change(
                  field.value
                      ?.where((element) => !_matchesFile(element, name))
                      .toList(),
                ),
              ),
            _buildButton(widgetBuilderInherited),
            if (filesBuilder == null) ...[
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: field.value?.length ?? 0,
                itemBuilder: (context, index) {
                  final currentFile = field.value![index];
                  final name = currentFile.name;
                  return ListTile(
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.property.readOnly
                          ? Theme.of(
                              context,
                            ).textTheme.titleMedium!.apply(color: Colors.grey)
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () {
                        change(
                          field.value
                              ?.where((element) => !_matchesFile(element, name))
                              .toList(),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
            if (field.hasError) CustomErrorText(text: field.errorText!),
          ],
        );
      },
    );
  }

  Future<void> _triggerInitialValue() async {
    final shouldTrigger = !hasTriggeredInitialValue &&
        widget.initialFileValueHandler != null &&
        widget.property.defaultValue != null;
    if (shouldTrigger) {
      hasTriggeredInitialValue = true;
      final initialValue = await widget.initialFileValueHandler!(
        widget.property.defaultValue,
      );
      SchedulerBinding.instance.addPostFrameCallback((_) {
        change(initialValue);
      });
    }
  }

  void change(List<SchemaFormFile>? values) {
    _fieldKey.currentState!.didChange(values);

    if (widget.onChanged != null) {
      final response = widget.property.isMultipleFile
          ? values?.map((e) => e.value).toList()
          : (values != null && values.isNotEmpty ? values.first.value : null);
      widget.onChanged!(response);
    }
  }

  Future<void> _onTap() async {
    if (widget.property.readOnly) return;

    final result = await widget.fileHandler(widget.property);

    if (result != null) {
      final nextValue = widget.property.isMultipleFile
          ? [...?_fieldKey.currentState?.value, ...result]
          : result;
      change(nextValue);
    }
  }

  bool _matchesFile(SchemaFormFile file, String identifier) {
    return file.value == identifier || file.name == identifier;
  }

  Widget _buildButton(WidgetBuilderInherited widgetBuilderInherited) {
    final addFileButtonBuilder =
        widgetBuilderInherited.uiConfig.addFileButtonBuilder;

    if (addFileButtonBuilder != null &&
        addFileButtonBuilder(_onTap, widget.property) != null) {
      return addFileButtonBuilder(_onTap, widget.property)!;
    }

    return ElevatedButton(
      onPressed: _onTap,
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(double.infinity, 40)),
      ),
      child: const Text('Add File'),
    );
  }
}
