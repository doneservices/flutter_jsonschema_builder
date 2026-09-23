import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart';

class Description extends StatelessWidget {
  const Description({required this.text, this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: text,
    onTapLink: context
        .dependOnInheritedWidgetOfExactType<WidgetBuilderInherited>()
        ?.onLinkTap,
    styleSheet: MarkdownStyleSheet.fromTheme(
      Theme.of(context),
    ).copyWith(p: style, listBullet: style),
  );
}
