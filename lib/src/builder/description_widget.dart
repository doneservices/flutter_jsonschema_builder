import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class Description extends StatelessWidget {
  const Description({required this.text, this.style, super.key});

  final String text;
  final TextStyle? style;

  Future<void> _openLink(BuildContext context, String? href) async {
    final uri = Uri.tryParse(href ?? '');
    if (uri != null &&
        const ['https', 'http', 'mailto', 'tel', 'sms'].contains(uri.scheme)) {
      try {
        if (await launchUrl(uri)) return;
      } on PlatformException catch (_) {
        // Show the same feedback as when no application can handle the link.
      } on MissingPluginException catch (_) {
        // A plugin added during development needs a fresh app run.
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: text,
    onTapLink: (_, href, _) => _openLink(context, href),
    styleSheet: MarkdownStyleSheet.fromTheme(
      Theme.of(context),
    ).copyWith(p: style, listBullet: style),
  );
}
