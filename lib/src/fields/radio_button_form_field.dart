import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/builder/field_header_widget.dart';
import 'package:flutter_jsonschema_builder/src/fields/fields.dart';
import 'package:flutter_jsonschema_builder/src/fields/shared.dart';
import '../models/models.dart';

class RadioButtonJFormField extends PropertyFieldWidget<dynamic> {
  const RadioButtonJFormField({
    super.key,
    required super.property,
    required super.onSaved,
    super.onChanged,
    super.customValidator,
    super.decoration,
  });

  @override
  State<RadioButtonJFormField> createState() => _RadioButtonJFormFieldState();
}

class _RadioButtonJFormFieldState extends State<RadioButtonJFormField> {
  bool booleanValue = false;

  dynamic groupValue;

  @override
  void initState() {
    print(widget.property.defaultValue);

    // fill enum property

    if (widget.property.enumm == null) {
      switch (widget.property.type) {
        case SchemaType.boolean:
          widget.property.enumm = [true, false];
          break;
        default:
          widget.property.enumm =
              widget.property.enumNames?.map((e) => e.toString()).toList() ??
                  [];
      }
    }

    // fill groupValue
    if (widget.property.type == SchemaType.boolean) {
      groupValue = widget.property.defaultValue;
    } else {
      groupValue = widget.property.defaultValue ?? 0;
    }

    widget.triggetDefaultValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.property.enumm != null, 'enum is required');
    assert(() {
      if (widget.property.enumNames != null) {
        return widget.property.enumNames!.length ==
            widget.property.enumm!.length;
      }
      return true;
    }(), '[enumNames] and [enum]  must be the same size ');

    inspect(widget.property);
    return FormField<dynamic>(
      key: Key(widget.property.idKey),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: groupValue,
      onSaved: (newValue) {
        widget.onSaved(newValue);
      },
      validator: (value) {
        if (widget.customValidator != null)
          return widget.customValidator!(value);

        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldHeader(property: widget.property),
            RadioGroup<dynamic>(
              groupValue: groupValue,
              onChanged: (dynamic value) {
                groupValue = value;
                if (value != null) {
                  field.didChange(groupValue);
                  if (widget.onChanged != null) {
                    widget.onChanged!(groupValue!);
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(
                    widget.property.enumNames?.length ??
                        widget.property.enumm?.length ??
                        0,
                    (int i) => RadioListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          enabled: !widget.property.readOnly,
                          value: widget.property.enumm != null
                              ? widget.property.enumm![i]
                              : i,
                          title: Text(
                              widget.property.enumNames?[i] ??
                                  widget.property.enumm![i].toString(),
                              style: widget.property.readOnly
                                  ? Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .apply(color: Colors.grey)
                                  : Theme.of(context).textTheme.titleMedium),
                        )),
              ),
            ),
            if (field.hasError) CustomErrorText(text: field.errorText!),
          ],
        );
      },
    );
  }
}
