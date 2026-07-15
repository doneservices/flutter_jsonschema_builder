import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_jsonschema_builder/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const conditionalSchema = '''
{
  "type": "object",
  "properties": {
    "pet": {
      "type": "string",
      "title": "Pet",
      "enum": ["none", "cat"]
    }
  },
  "allOf": [
    {
      "if": {
        "required": ["pet"],
        "properties": {"pet": {"const": "cat"}}
      },
      "then": {
        "properties": {
          "petName": {"type": "string", "title": "Pet name"}
        },
        "required": ["petName"]
      }
    }
  ]
}
''';

Widget testApp(JsonFormDisplayMode mode) {
  final form = JsonForm(
    jsonSchema: conditionalSchema,
    displayMode: mode,
    steppedConfig: const JsonFormSteppedConfig(autoAdvanceOnSelect: false),
    onFormDataSaved: (_) {},
  );
  return MaterialApp(
    home: Scaffold(
      body: mode == JsonFormDisplayMode.stepped
          ? SizedBox.expand(child: form)
          : form,
    ),
  );
}

void main() {
  test(
    'direct if/then/else switches object properties and required fields',
    () {
      final schema =
          Schema.fromJson(
                json.decode('''
      {
        "type": "object",
        "properties": {
          "enabled": {"type": "boolean"}
        },
        "if": {
          "required": ["enabled"],
          "properties": {"enabled": {"const": true}}
        },
        "then": {
          "properties": {"email": {"type": "string"}},
          "required": ["email"]
        },
        "else": {
          "properties": {"reason": {"type": "string"}}
        }
      }
      '''),
                id: kGenesisIdKey,
              )
              as SchemaObject;

      schema.resolveConditions({});
      expect(schema.properties!.map((property) => property.id), [
        'enabled',
        'reason',
      ]);

      schema.resolveConditions({'enabled': true});
      expect(schema.properties!.map((property) => property.id), [
        'enabled',
        'email',
      ]);
      expect((schema.properties!.last as SchemaProperty).required, isTrue);
    },
  );

  test('numeric conditions work with the form\'s text-backed number data', () {
    final schema =
        Schema.fromJson(
              json.decode('''
      {
        "type": "object",
        "properties": {"age": {"type": "integer"}},
        "if": {
          "required": ["age"],
          "properties": {"age": {"minimum": 18}}
        },
        "then": {
          "properties": {"adultName": {"type": "string"}}
        }
      }
      '''),
              id: kGenesisIdKey,
            )
            as SchemaObject;

    schema.resolveConditions({'age': '17'});
    expect(schema.properties!.map((property) => property.id), ['age']);

    schema.resolveConditions({'age': '18'});
    expect(schema.properties!.map((property) => property.id), [
      'age',
      'adultName',
    ]);
  });

  testWidgets('classic mode adds, validates, and removes a conditional field', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(JsonFormDisplayMode.fullForm));
    await tester.pump();

    expect(find.byKey(const Key('petName')), findsNothing);

    await tester.tap(find.byKey(const Key('pet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cat').last);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField && widget.key == const Key('petName'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('none').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('petName')), findsNothing);
  });

  testWidgets('nested changes can activate a root condition', (tester) async {
    const schema = '''
    {
      "type": "object",
      "properties": {
        "preferences": {
          "type": "object",
          "properties": {
            "wantsEmail": {"type": "boolean", "title": "Email me"}
          }
        }
      },
      "if": {
        "required": ["preferences"],
        "properties": {
          "preferences": {
            "required": ["wantsEmail"],
            "properties": {"wantsEmail": {"const": true}}
          }
        }
      },
      "then": {
        "properties": {
          "email": {"type": "string", "title": "Email"}
        }
      }
    }
    ''';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JsonForm(jsonSchema: schema, onFormDataSaved: (_) {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('email')), findsNothing);
    await tester.tap(find.byKey(const Key('preferences.wantsEmail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email')), findsOneWidget);
  });

  testWidgets('stepped mode inserts and removes a conditional step', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(JsonFormDisplayMode.stepped));
    await tester.pump();

    expect(find.text('1 / 1'), findsOneWidget);
    await tester.tap(find.text('cat').last);
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField && widget.key == const Key('petName'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('none').last);
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
  });
}
