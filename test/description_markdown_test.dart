import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_jsonschema_builder/src/builder/field_header_widget.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

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
              '[Learn more](https://flutter.dev)';
          final launches = <String>[];
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                expect(call.method, 'launch');
                launches.add(call.arguments['url'] as String);
                return true;
              });
          final theme = ThemeData();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: JsonForm(
                  displayMode: mode,
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
          expect(launches, ['https://flutter.dev']);
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

  for (final failure in [
    'unavailable',
    'platform error',
    'missing plugin',
    'unsupported scheme',
  ]) {
    testWidgets('Link feedback for $failure', (tester) async {
      var launches = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            launches++;
            if (failure == 'missing plugin') {
              throw MissingPluginException();
            }
            if (failure == 'platform error') {
              throw PlatformException(code: 'launch_failed');
            }
            return false;
          });
      final url = failure == 'unsupported scheme'
          ? 'file:///tmp/example.txt'
          : 'https://flutter.dev';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FieldHeader(
              property: SchemaProperty.fromJson('answer', {
                'type': 'string',
                'title': 'Question',
                'description': '[Learn more]($url)',
              }),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Learn more', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Could not open this link.'), findsOneWidget);
      expect(launches, failure == 'unsupported scheme' ? 0 : 1);
      expect(tester.takeException(), isNull);
    });
  }
}
