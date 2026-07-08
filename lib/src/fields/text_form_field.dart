import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jsonschema_builder/src/builder/field_header_widget.dart';
import 'package:flutter_jsonschema_builder/src/builder/stepped_form_builder.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart';
import 'package:flutter_jsonschema_builder/src/fields/fields.dart';
import 'package:flutter_jsonschema_builder/src/utils/input_validation_json_schema.dart';

import '../utils/utils.dart';
import '../models/models.dart';

class TextJFormField extends PropertyFieldWidget<String> {
  const TextJFormField({
    super.key,
    required super.property,
    required super.onSaved,
    required ValueChanged<String?> super.onChanged,
    super.customValidator,
    super.decoration,
  });

  @override
  State<StatefulWidget> createState() => _TextJFormFieldState();
}

class _TextJFormFieldState extends State<TextJFormField> {
  Timer? _timer;

  @override
  void initState() {
    widget.triggetDefaultValue();
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiConfig = WidgetBuilderInherited.of(context).uiConfig;
    // in stepped mode the keyboard action button advances the form;
    // textareas keep the default action so enter inserts a newline
    final isTextArea = widget.property.widget == "textarea";
    final steppedScope = isTextArea ? null : SteppedFormScope.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldHeader(property: widget.property),
        AbsorbPointer(
          absorbing: widget.property.disabled ?? false,
          child: TextFormField(
            key: Key(widget.property.idKey),
            autofocus: (widget.property.autoFocus ?? false),
            keyboardType: getTextInputTypeFromFormat(widget.property.format),
            maxLines: isTextArea ? null : 1,
            textInputAction: steppedScope != null ? TextInputAction.next : null,
            // focus-driven auto-scroll must clear the floating controls
            scrollPadding:
                steppedScope != null
                    ? EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      steppedScope.controlsClearance + 20,
                    )
                    : const EdgeInsets.all(20),
            // onEditingComplete (not onFieldSubmitted) replaces the default
            // focus handling, so the scope decides where focus goes
            onEditingComplete: steppedScope?.onTextSubmitted,
            obscureText: widget.property.format == PropertyFormat.password,
            initialValue: widget.property.defaultValue ?? '',
            onSaved: widget.onSaved,
            maxLength: widget.property.maxLength,
            inputFormatters: [textInputCustomFormatter(widget.property.format)],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            readOnly: widget.property.readOnly,
            onChanged: (value) {
              if (_timer != null && _timer!.isActive) _timer!.cancel();

              _timer = Timer(const Duration(seconds: 1), () {
                if (widget.onChanged != null) widget.onChanged!(value);
              });
            },
            validator: (String? value) {
              if (widget.property.required && value != null) {
                final validated = inputValidationJsonSchema(
                  newValue: value,
                  property: widget.property,
                );
                if (validated == 'Required') {
                  return uiConfig.requiredText ?? validated;
                } else {
                  return validated;
                }
              }

              if (widget.customValidator != null)
                return widget.customValidator!(value);

              return null;
            },
            style:
                widget.property.readOnly
                    ? Theme.of(
                      context,
                    ).textTheme.titleMedium!.apply(color: Colors.grey)
                    : Theme.of(context).textTheme.titleMedium,
            decoration:
                widget.decoration ??
                InputDecoration(
                  helperText:
                      widget.property.help != null &&
                              widget.property.help!.isNotEmpty
                          ? widget.property.help
                          : null,
                  labelStyle: const TextStyle(color: Colors.blue),
                  errorStyle: Theme.of(context).textTheme.bodyMedium!.apply(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  TextInputType getTextInputTypeFromFormat(PropertyFormat format) {
    late TextInputType textInputType;

    switch (format) {
      case PropertyFormat.general:
        textInputType = TextInputType.text;
        break;
      case PropertyFormat.password:
        textInputType = TextInputType.visiblePassword;
        break;
      case PropertyFormat.date:
        textInputType = TextInputType.datetime;
        break;
      case PropertyFormat.datetime:
        textInputType = TextInputType.datetime;
        break;
      case PropertyFormat.email:
        textInputType = TextInputType.emailAddress;
        break;
      case PropertyFormat.dataurl:
        textInputType = TextInputType.text;
        break;
      case PropertyFormat.uri:
        textInputType = TextInputType.url;
        break;
    }

    return textInputType;
  }

  TextInputFormatter textInputCustomFormatter(PropertyFormat format) {
    late TextInputFormatter textInputFormatter;
    switch (format) {
      case PropertyFormat.email:
        textInputFormatter = EmailTextInputJsonFormatter();
        break;
      default:
        textInputFormatter = DefaultTextInputJsonFormatter(
          pattern: widget.property.pattern,
        );
        break;
    }
    return textInputFormatter;
  }
}
