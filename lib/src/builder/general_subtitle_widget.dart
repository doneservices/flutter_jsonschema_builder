import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/builder/description_widget.dart';
import 'package:flutter_jsonschema_builder/src/models/models.dart';

class GeneralSubtitle extends StatelessWidget {
  const GeneralSubtitle({
    super.key,
    required this.title,
    this.description,
    this.mainSchemaTitle,
    this.nainSchemaDescription,
  });

  final String title;
  final String? description, mainSchemaTitle, nainSchemaDescription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        if (mainSchemaTitle != title && title != kNoTitle) ...[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const Divider(),
        ],
        if (description != null &&
            description!.isNotEmpty &&
            description != nainSchemaDescription) ...[
          Description(
            text: description!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
