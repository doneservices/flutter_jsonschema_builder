import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_jsonschema_builder/src/builder/stepped_form_builder.dart';

class FieldHeader extends StatelessWidget {
  const FieldHeader({required this.property, this.showTitle = true, super.key});
  final SchemaProperty property;

  /// `false` when the field renders the title itself (e.g. as a checkbox
  /// label), so it isn't shown twice
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final description = property.description;
    // stepped mode breathes more: the header doubles as the step's heading
    final isStepped = SteppedFormScope.maybeOf(context) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          Text(
            '${property.title} ${property.required ? "*" : ""}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (isStepped) const SizedBox(height: 12),
      ],
    );
  }
}
