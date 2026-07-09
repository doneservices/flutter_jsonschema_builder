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
    final textTheme = Theme.of(context).textTheme;
    // stepped mode breathes more: the header doubles as the step's heading,
    // so the title is bold and both title and description are a size larger
    final isStepped = SteppedFormScope.maybeOf(context) != null;

    final titleStyle = isStepped
        ? textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : textTheme.bodyMedium;
    final descriptionStyle =
        isStepped ? textTheme.bodyMedium : textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          Text(
            '${property.title} ${property.required ? "*" : ""}',
            style: titleStyle,
          ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: descriptionStyle,
          ),
        ],
        if (isStepped) const SizedBox(height: 12),
      ],
    );
  }
}
