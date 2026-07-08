import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/builder/field_header_widget.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart'
    show WidgetBuilderInherited;
import 'package:flutter_jsonschema_builder/src/fields/fields.dart';
import 'package:flutter_jsonschema_builder/src/fields/shared.dart';

class CheckboxJFormField extends PropertyFieldWidget<bool> {
  const CheckboxJFormField({
    super.key,
    required super.property,
    required super.onSaved,
    super.onChanged,
    super.customValidator,
  });

  @override
  State<StatefulWidget> createState() => _CheckboxJFormFieldState();
}

class _CheckboxJFormFieldState extends State<CheckboxJFormField> {
  @override
  void initState() {
    widget.triggetDefaultValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // the tile carries the title as its label — the header would
        // otherwise show it a second time right above
        FieldHeader(property: widget.property, showTitle: false),
        FormField<bool>(
          key: Key(widget.property.idKey),
          initialValue: widget.property.defaultValue ?? false,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onSaved: (newValue) {
            widget.onSaved(newValue);
          },
          validator: (value) {
            if (widget.customValidator != null)
              return widget.customValidator!(value);

            // If the field is required and the value is false, fail validation
            if (widget.property.required && (value == null || value == false)) {
              return WidgetBuilderInherited.of(context).uiConfig.requiredText ??
                  'Required';
            }

            return null;
          },
          builder: (field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: (field.value == null) ? false : field.value,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    '${widget.property.title}'
                    '${widget.property.required ? " *" : ""}',
                    style:
                        widget.property.readOnly
                            ? Theme.of(
                              context,
                            ).textTheme.titleMedium!.apply(color: Colors.grey)
                            : Theme.of(context).textTheme.titleMedium,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged:
                      widget.property.readOnly
                          ? null
                          : (bool? value) {
                            field.didChange(value);
                            if (widget.onChanged != null && value != null) {
                              widget.onChanged!(value);
                            }
                          },
                ),
                if (field.hasError) CustomErrorText(text: field.errorText!),
              ],
            );
          },
        ),
      ],
    );
  }
}
