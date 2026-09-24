import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_jsonschema_builder/src/models/schema.dart';
import 'package:flutter_jsonschema_builder/src/utils/input_validation_json_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const _schema = '''
{
  "type": "object",
  "properties": {
    "address": {"type": "string", "title": "Address", "minLength": 4}
  },
  "required": ["address"]
}
''';

void main() {
  test('minLength accepts the exact boundary', () {
    final property = SchemaProperty(
      id: 'address',
      type: SchemaType.string,
      minLength: 4,
    );

    String? validate(String value) =>
        inputValidationJsonSchema(newValue: value, property: property);

    expect(validate('abc'), isNotNull);
    expect(validate('abcd'), isNull);
    expect(validate('abcde'), isNull);
  });

  for (final mode in JsonFormDisplayMode.values) {
    testWidgets('custom field validates and saves in ${mode.name}', (
      tester,
    ) async {
      Map<String, dynamic>? changed;
      Map<String, dynamic>? saved;
      final form = JsonForm(
        jsonSchema: _schema,
        uiSchema: '{"address":{"ui:widget":"addressLookup"}}',
        displayMode: mode,
        fieldBuilders: {'addressLookup': _addressField},
        onChanged: (data) => changed = Map.of(data),
        onFormDataSaved: (data) => saved = Map.of(data),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mode == JsonFormDisplayMode.stepped
                ? SizedBox.expand(child: form)
                : form,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('custom-address')), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      expect(saved, isNull);

      await tester.tap(find.byKey(const Key('custom-address')));
      await tester.pump();
      expect(changed, {'address': 'Stockholm'});
      expect(find.text('Required'), findsNothing);

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(saved, {'address': 'Stockholm'});
    });
  }

  testWidgets('custom field rejects values outside the schema enum', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JsonForm(
            jsonSchema: '''
{"type":"object","properties":{"kind":{"type":"string","enum":["home","work"]}},"required":["kind"]}
''',
            uiSchema: '{"kind":{"ui:widget":"customChoice"}}',
            fieldBuilders: {
              'customChoice': (context, property, value, errorText, onChanged) {
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => onChanged('other'),
                      child: const Text('Other'),
                    ),
                    TextButton(
                      onPressed: () => onChanged('home'),
                      child: const Text('Home'),
                    ),
                    if (errorText != null) Text(errorText),
                  ],
                );
              },
            },
            onFormDataSaved: (data) => saved = Map.of(data),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Other'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(
      find.text('Value must be one of the allowed options'),
      findsOneWidget,
    );
    expect(saved, isNull);

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(saved, {'kind': 'home'});
  });
}

Widget _addressField(
  BuildContext context,
  SchemaProperty property,
  dynamic value,
  String? errorText,
  ValueChanged<dynamic> onChanged,
) {
  return Column(
    children: [
      TextButton(
        key: const Key('custom-address'),
        onPressed: () => onChanged('Stockholm'),
        child: Text(value?.toString() ?? property.title),
      ),
      if (errorText != null) Text(errorText),
    ],
  );
}
