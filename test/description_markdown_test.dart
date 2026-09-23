import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in JsonFormDisplayMode.values) {
    for (final (fieldType, useUiOverride) in [
      ('string', false),
      ('string', true),
      ('array', false),
      ('array', true),
    ]) {
      testWidgets(
        'Markdown $fieldType descriptions in $mode (UI: $useUiOverride)',
        (tester) async {
          const description =
              '**Bold** and *italic*.\n\n- First\n- Second\n\n'
              '[Learn more](app://help "Help title")';
          final taps = <(String, String?, String)>[];
          final theme = ThemeData();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: JsonForm(
                  displayMode: mode,
                  onLinkTap: (text, href, title) =>
                      taps.add((text, href, title)),
                  jsonSchema: jsonEncode({
                    'type': 'object',
                    'properties': {
                      'answer': {
                        'type': fieldType,
                        if (fieldType == 'array') 'items': {'type': 'string'},
                        'title': 'Question',
                        'description': useUiOverride ? 'Original' : description,
                      },
                    },
                  }),
                  uiSchema: useUiOverride
                      ? jsonEncode({
                          'answer': {'ui:description': description},
                        })
                      : null,
                  onFormDataSaved: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Bold and italic.', findRichText: true),
            findsOneWidget,
          );
          expect(find.text('First', findRichText: true), findsOneWidget);
          expect(find.text('Second', findRichText: true), findsOneWidget);
          expect(find.text('Original'), findsNothing);
          expect(
            tester
                    .getTopLeft(
                      fieldType == 'array'
                          ? find.widgetWithText(TextButton, 'Add Item')
                          : find.byType(TextFormField),
                    )
                    .dy -
                tester.getBottomLeft(find.byType(MarkdownBody)).dy,
            fieldType == 'string' && mode == JsonFormDisplayMode.stepped
                ? 20
                : 8,
          );
          await tester.tap(find.text('Learn more', findRichText: true));
          await tester.pump();
          expect(taps, [('Learn more', 'app://help', 'Help title')]);
          final markdown = tester.widget<MarkdownBody>(
            find.byType(MarkdownBody),
          );
          final textTheme = Theme.of(
            tester.element(find.byType(MarkdownBody)),
          ).textTheme;
          expect(
            markdown.styleSheet!.p,
            fieldType == 'string' && mode == JsonFormDisplayMode.stepped
                ? textTheme.bodyMedium
                : textTheme.bodySmall,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Links do nothing when no callback is registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JsonForm(
            jsonSchema: jsonEncode({
              'type': 'object',
              'properties': {
                'answer': {
                  'type': 'string',
                  'description': '[Learn more](https://flutter.dev)',
                },
              },
            }),
            onFormDataSaved: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Learn more', findRichText: true));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
