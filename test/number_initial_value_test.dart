import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _schema = '''
{
  "type": "object",
  "properties": {
    "age": {"type": "integer", "title": "Age"},
    "height": {"type": "number", "title": "Height", "default": 1.8}
  }
}
''';

void main() {
  for (final mode in JsonFormDisplayMode.values) {
    testWidgets('numeric initial data and defaults render in $mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: SingleChildScrollView(
                child: SizedBox(
                  height: 600,
                  child: JsonForm(
                    jsonSchema: _schema,
                    initialData: const {'age': 30},
                    displayMode: mode,
                    showDebugElements: false,
                    onFormDataSaved: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('30'), findsOneWidget);
      if (mode == JsonFormDisplayMode.fullForm) {
        expect(find.text('1.8'), findsOneWidget);
      }
    });
  }
}
